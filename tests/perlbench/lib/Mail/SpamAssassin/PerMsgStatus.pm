=head1 NAME

Mail::SpamAssassin::PerMsgStatus - per-message status (spam or not-spam)

=head1 SYNOPSIS

  my $spamtest = new Mail::SpamAssassin ({
    'rules_filename'      => '/etc/spamassassin.rules',
    'userprefs_filename'  => $ENV{HOME}.'/.spamassassin.cf'
  });
  my $mail = Mail::SpamAssassin::NoMailAudit->new();

  my $status = $spamtest->check ($mail);
  if ($status->is_spam()) {
    $status->rewrite_mail ();
    $mail->accept("caught_spam");
  }
  ...


=head1 DESCRIPTION

The Mail::SpamAssassin C<check()> method returns an object of this
class.  This object encapsulates all the per-message state.

=head1 METHODS

=over 4

=cut

package Mail::SpamAssassin::PerMsgStatus;

use strict;
use bytes;
use Carp;

use Text::Wrap ();

use Mail::SpamAssassin::EvalTests;
use Mail::SpamAssassin::AutoWhitelist;
use Mail::SpamAssassin::HTML;
use Mail::SpamAssassin::Conf;
use Mail::SpamAssassin::Received;
use Mail::SpamAssassin::Util;

use constant HAS_MIME_BASE64 =>		eval { require MIME::Base64; };

use constant MAX_BODY_LINE_LENGTH =>	2048;

use vars qw{
  @ISA $base64alphabet
};

@ISA = qw();

###########################################################################

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my ($main, $msg, $opts) = @_;

  my $self = {
    'main'              => $main,
    'msg'               => $msg,
    'hits'              => 0,
    'test_logs'         => '',
    'test_names_hit'    => [ ],
    'subtest_names_hit' => [ ],
    'tests_already_hit' => { },
    'hdr_cache'         => { },
    'rule_errors'       => 0,
    'disable_auto_learning' => 0,
    'auto_learn_status' => undef,
    'conf'		=> $main->{conf},
  };

  if (defined $opts && $opts->{disable_auto_learning}) {
    $self->{disable_auto_learning} = 1;
  }

  # used with "mass-check --loghits"
  if ($self->{main}->{save_pattern_hits}) {
    $self->{save_pattern_hits} = 1;
    $self->{pattern_hits} = { };
  }

  bless ($self, $class);
  $self;
}

###########################################################################

sub check {
  my ($self) = @_;
  local ($_);

  # in order of slowness; fastest first, slowest last.
  # we do ALL the tests, even if a spam triggers lots of them early on.
  # this lets us see ludicrously spammish mails (score: 40) etc., which
  # we can then immediately submit to spamblocking services.
  #
  # TODO: change this to do whitelist/blacklists first? probably a plan
  # NOTE: definitely need AWL stuff last, for regression-to-mean of score

  $self->clean_spamassassin_headers();
  $self->{learned_hits} = 0;
  $self->{body_only_hits} = 0;
  $self->{head_only_hits} = 0;
  $self->{hits} = 0;

  # Resident Mail::SpamAssassin code will possibly never change score
  # sets, even if bayes becomes available.  So we should do a quick check
  # to see if we should go from {0,1} to {2,3}.  We of course don't need
  # to do this switch if we're already using bayes ... ;)
  my $set = $self->{conf}->get_score_set();
  if ( ($set & 2) == 0 && $self->{main}->{bayes_scanner}->is_scan_available() ) {
    dbg("debug: Scoreset $set but Bayes is available, switching scoresets");
    $self->{conf}->set_score_set ($set|2);
  }

  # pre-chew Received headers
  $self->parse_received_headers();

  # and identify the language (if we're going to do that), before we
  # run any Bayes tests, so they can use that as a token
  {
    my $decoded = $self->get_decoded_stripped_body_text_array();
    $self->_check_language ($decoded);
    undef $decoded;		# this is cached anyway for the main set
  }

  {
    # Here, we launch all the DNS RBL queries and let them run while we
    # inspect the message
    $self->run_rbl_eval_tests ($self->{conf}->{rbl_evals});

    # do head tests
    $self->do_head_tests();

    # do body tests with decoded portions
    {
      my $decoded = $self->get_decoded_stripped_body_text_array();
      # warn "dbg ". join ("", @{$decoded}). "\n";
      $self->do_body_tests($decoded);
      $self->do_body_eval_tests($decoded);
      undef $decoded;
    }

    # do rawbody tests with raw text portions
    {
      my $bodytext = $self->get_decoded_body_text_array();
      $self->do_rawbody_tests($bodytext);
      $self->do_rawbody_eval_tests($bodytext);
      # NB: URI tests are here because "strip" removes too much
      $self->do_body_uri_tests($bodytext);
      undef $bodytext;
    }

    # and do full tests: first with entire, full, undecoded message
    # still skip application/image attachments though
    {
      my $fulltext = join ('', $self->{msg}->get_all_headers(), "\n",
                                @{$self->get_raw_body_text_array()});
      $self->do_full_tests(\$fulltext);
      $self->do_full_eval_tests(\$fulltext);
      undef $fulltext;
    }

    $self->do_head_eval_tests();

    # harvest the DNS results
    $self->harvest_dnsbl_queries();

    # finish the DNS results
    $self->rbl_finish();

    # Do meta rules second-to-last
    $self->do_meta_tests();

    # auto-learning
    $self->learn();

    # add points from Bayes, before adjusting the AWL
    $self->{hits} += $self->{learned_hits};

    # Do AWL tests last, since these need the score to have already been
    # calculated
    $self->do_awl_tests();
  }

  $self->delete_fulltext_tmpfile();

  # Round the hits to 3 decimal places to avoid rounding issues
  # We assume required_hits to be properly rounded already.
  # add 0 to force it back to numeric representation instead of string.
  #$self->{hits} = (sprintf "%0.3f", $self->{hits}) + 0;
  # In CPU2006 let's truncate them instead, in order to avoid rounding issues
  $self->{hits} = int($self->{hits} + 0);
  
  dbg ("is spam? score=".$self->{hits}.
                        " required=".$self->{conf}->{required_hits}.
                        " tests=".$self->get_names_of_tests_hit());
  $self->{is_spam} = $self->is_spam();

  my $report;
  $report = $self->{conf}->{report_template};
  $report ||= '(no report template found)';

  $report = $self->_replace_tags($report);

  # now that we've finished checking the mail, clear out this cache
  # to avoid unforeseen side-effects.
  $self->{hdr_cache} = { };

  $report =~ s/\n*$/\n\n/s;
  $self->{report} = $report;

}

###########################################################################

=item $status->learn()

After a mail message has been checked, this method can be called.  If the score
is outside a certain range around the threshold, ie. if the message is judged
more-or-less definitely spam or definitely non-spam, it will be fed into
SpamAssassin's learning systems (currently the naive Bayesian classifier),
so that future similar mails will be caught.

=cut

sub learn {
  my ($self) = @_;

  if (!$self->{conf}->{bayes_auto_learn}) { return; }
  if (!$self->{conf}->{use_bayes}) { return; }
  if ($self->{disable_auto_learning}) { return; }

  # Figure out min/max for autolearning.
  # Default to specified auto_learn_threshold settings
  my $min = $self->{conf}->{bayes_auto_learn_threshold_nonspam};
  my $max = $self->{conf}->{bayes_auto_learn_threshold_spam};

  dbg ("auto-learn? ham=$min, spam=$max, ".
		"body-hits=".$self->{body_only_hits}.", ".
		"head-hits=".$self->{head_only_hits});

  my $isspam;

  # This section should use sum($score[scoreset % 2]) not just {hits}.  otherwise we shift what we
  # autolearn on and it gets really wierd.  - tvd
  my $hits = 0;
  my $orig_scoreset = $self->{conf}->get_score_set();
  if ( ($orig_scoreset & 2) == 0 ) { # we don't need to recompute
    dbg ("auto-learn: currently using scoreset $orig_scoreset.  no need to recompute.");
    $hits = $self->{hits};
  }
  else {
    my $new_scoreset = $orig_scoreset & ~2;
    dbg ("auto-learn: currently using scoreset $orig_scoreset.  recomputing score based on scoreset $new_scoreset.");
    $self->{conf}->set_score_set($new_scoreset); # reduce to autolearning scores
    foreach my $test ( @{$self->{test_names_hit}} ) {
      # ignore tests with 0 score in this scoreset or if the test is a learning or userconf test
      next if ( $self->{conf}->{scores}->{$test} == 0 );
      next if ( exists $self->{conf}->{tflags}->{$test} && $self->{conf}->{tflags}->{$test} =~ /\b(?:learn|userconf)\b/ );

      $hits += $self->{conf}->{scores}->{$test};
    }
    # CPU2006
    #$hits = (sprintf "%0.3f", $hits) + 0;
    $hits = int($hits) + 0;
    dbg ("auto-learn: original score: ".$self->{hits}.", recomputed score: $hits");
    $self->{conf}->set_score_set($orig_scoreset); # return to appropriate scoreset
  }

  if ($hits < $min) {
    $isspam = 0;
  } elsif ($hits >= $max) {
    $isspam = 1;
  } else {
    dbg ("auto-learn? no: inside auto-learn thresholds");
    return;
  }

  my $learner_said_ham_hits = -1.0;
  my $learner_said_spam_hits = 1.0;

  if ($isspam) {
    # CPU2006
    #my $required_body_hits = 3;
    #my $required_head_hits = 3;
    my $required_body_hits = 3000;
    my $required_head_hits = 3000;

    if ($self->{body_only_hits} < $required_body_hits) {
      dbg ("auto-learn? no: too few body hits (".
		  $self->{body_only_hits}." < ".$required_body_hits.")");
      return;
    }
    if ($self->{head_only_hits} < $required_head_hits) {
      dbg ("auto-learn? no: too few head hits (".
		  $self->{head_only_hits}." < ".$required_head_hits.")");
      return;
    }
    if ($self->{learned_hits} < $learner_said_ham_hits) {
      dbg ("auto-learn? no: learner indicated ham (".
		  $self->{learned_hits}." < ".$learner_said_ham_hits.")");
      return;
    }

  } else {
    if ($self->{learned_hits} > $learner_said_spam_hits) {
      dbg ("auto-learn? no: learner indicated spam (".
		  $self->{learned_hits}." > ".$learner_said_spam_hits.")");
      return;
    }
  }

  dbg ("auto-learn? yes, ".($isspam?"spam ($hits > $max)":"ham ($hits < $min)"));
  eval {
    my $learnstatus = $self->{main}->learn ($self->{msg}, undef, $isspam, 0);
    $learnstatus->finish();
    if ( $learnstatus->did_learn() ) {
      $self->{auto_learn_status} = $isspam;
    }
    $self->{main}->finish_learner();	# for now

    if (exists $self->{main}->{bayes_scanner}) {
      $self->{main}->{bayes_scanner}->sanity_check_is_untied();
    }
  };

  if ($@) {
    dbg ("auto-learning failed: $@");
  }
}

###########################################################################

=item $isspam = $status->is_spam ()

After a mail message has been checked, this method can be called.  It will
return 1 for mail determined likely to be spam, 0 if it does not seem
spam-like.

=cut

sub is_spam {
  my ($self) = @_;
  # changed to test this so sub-tests can ask "is_spam" during a run
  return ($self->{hits} >= $self->{conf}->{required_hits});
}

###########################################################################

=item $list = $status->get_names_of_tests_hit ()

After a mail message has been checked, this method can be called. It will
return a comma-separated string, listing all the symbolic test names
of the tests which were trigged by the mail.

=cut

sub get_names_of_tests_hit {
  my ($self) = @_;

  return join(',', sort(@{$self->{test_names_hit}}));
}

###########################################################################

=item $list = $status->get_names_of_subtests_hit ()

After a mail message has been checked, this method can be called.  It will
return a comma-separated string, listing all the symbolic test names of the
meta-rule sub-tests which were trigged by the mail.  Sub-tests are the
normally-hidden rules, which score 0 and have names beginning with two
underscores, used in meta rules.

=cut

sub get_names_of_subtests_hit {
  my ($self) = @_;

  return join(',', sort(@{$self->{subtest_names_hit}}));
}

###########################################################################

=item $num = $status->get_hits ()

After a mail message has been checked, this method can be called.  It will
return the number of hits this message incurred.

=cut

sub get_hits {
  my ($self) = @_;
  return $self->{hits};
}

###########################################################################

=item $num = $status->get_required_hits ()

After a mail message has been checked, this method can be called.  It will
return the number of hits required for a mail to be considered spam.

=cut

sub get_required_hits {
  my ($self) = @_;
  return $self->{conf}->{required_hits};
}

###########################################################################

=item $report = $status->get_report ()

Deliver a "spam report" on the checked mail message.  This contains details of
how many spam detection rules it triggered.

The report is returned as a multi-line string, with the lines separated by
C<\n> characters.

=cut

sub get_report {
  my ($self) = @_;
  return $self->{report};
}

###########################################################################

=item $preview = $status->get_content_preview ()

Give a "preview" of the content.

This is returned as a multi-line string, with the lines separated by C<\n>
characters, containing a fully-decoded, safe, plain-text sample of the first
few lines of the message body.

=cut

sub get_content_preview {
  my ($self) = @_;

  $Text::Wrap::columns   = 74;
  $Text::Wrap::huge      = 'overflow';

  my $str = '';
  my $ary = $self->get_decoded_stripped_body_text_array();
  shift @{$ary};		# drop the subject line

  my $numlines = 3;
  while (length ($str) < 200 && @{$ary} && $numlines-- > 0) {
    $str .= shift @{$ary};
  }
  undef $ary;
  chomp ($str); $str .= " [...]\n";

  # in case the last line was huge, trim it back to around 200 chars
  $str =~ s/^(.{,200}).*$/$1/gs;

  # now, some tidy-ups that make things look a bit prettier
  $str =~ s/-----Original Message-----.*$//gs;
  $str =~ s/This is a multi-part message in MIME format\.//gs;
  $str =~ s/[-_\*\.]{10,}//gs;
  $str =~ s/\s+/ /gs;

  # be paranoid -- there's a die() in there
  my $wrapped;
  eval {
    # add "Content preview:" ourselves, so that the text aligns
    # correctly with the template -- then trim it off.  We don't
    # have to get this *exactly* right, but it's nicer if we
    # make a bit of an effort ;)
    $wrapped = Text::Wrap::wrap ("Content preview:  ", "  ", $str);
    if (defined $wrapped) {
      $wrapped =~ s/^Content preview:\s+//gs;
      $str = $wrapped;
    }
  };

  $str;
}

###########################################################################

=item $status->rewrite_mail ()

Rewrite the mail message.  This will at minimum add headers, and at
maximum MIME-encapsulate the message text, to reflect its spam or
not-spam status.

The possible modifications are as follows:

=over 4

=item Subject: header for spam mails

The string C<*****SPAM*****> (changeable with C<subject_tag> config option) is
prepended to the subject, unless the C<rewrite_subject 0> configuration option
is given.

=item X-Spam-Status: header for spam mails

A string, C<Yes, hits=nn required=nn tests=...> is set in this header to
reflect the filter status.  The keys in this string are as follows:

=over 4

=item hits=nn The number of hits the message triggered.

=item required=nn The threshold at which a mail is marked as spam.

=item tests=... The symbolic names of tests which were triggered.

=item version=... The version of SpamAssassin which made the change

=back

=item X-Spam-Status: header for non-spam mails

A string, C<No, hits=nn required=nn tests=...> is set in this header to reflect
the filter status.  The keys in this string are the same as for spam mails (see
above).

=item X-Spam-Flag: header for spam mails

Set to C<YES>.

=item X-Spam-Checker-Version: header for all mails

Set to the version number of the SpamAssassin checker which tested the mail.

=item spam message with report_safe

If report_safe is set to true (1), then spam messages are encapsulated
into their own message/rfc822 MIME attachment without any modifications
being made.

If report_safe is set to false (0), then the message will only have the
above headers added/modified.

=back

=cut

sub rewrite_mail {
  my ($self) = @_;

  if ($self->{is_spam} && $self->{conf}->{report_safe}) {
    $self->rewrite_as_spam();
  }
  else {
    $self->rewrite_headers();
  }

  # invalidate the header cache, we've changed some of them.
  $self->{hdr_cache} = { };
}

# rewrite the entire message as spam (headers and body)
sub rewrite_as_spam {
  my ($self) = @_;

  # This is the original message.  We do not want to make any modifications so
  # we may recover it if necessary.  It will be put into the new message as a
  # message/rfc822 MIME part.
  my $original = $self->{msg}->get_pristine();

  # This is the new message.
  my $newmsg = '';

  # remove first line if it is "From "
  if ($original =~ s/^(From (.*?)\n)//s) {
    # jm: surely do not add it again? we wind up with a bad header
    #$newmsg .= $1;
  }

  # the report charset
  my $report_charset = "";
  if ($self->{conf}->{report_charset}) {
    $report_charset = "; charset=" . $self->{conf}->{report_charset};
  }

  # the SpamAssassin report
  my $report = $self->{report};

  # get original headers, "pristine" if we can do it
  my $from = $self->{msg}->get_pristine_header("From");
  my $to = $self->{msg}->get_pristine_header("To");
  my $cc = $self->{msg}->get_pristine_header("Cc");
  my $subject = $self->{msg}->get_pristine_header("Subject");
  my $msgid = $self->{msg}->get_pristine_header('Message-Id');
  my $date = $self->{msg}->get_pristine_header("Date");

  if ($self->{conf}->{rewrite_subject}) {
    $subject ||= '';
    my $tag = $self->{conf}->{subject_tag};
    # CPU2006
    #$tag =~ s/_HITS_/sprintf("%05.2f", $self->{hits})/e;
    #$tag =~ s/_REQD_/sprintf("%05.2f", $self->{conf}->{required_hits})/e;
    $tag =~ s/_HITS_/sprintf("%4d", int($self->{hits}))/e;
    $tag =~ s/_REQD_/sprintf("%4d", int($self->{conf}->{required_hits}))/e;
    $subject =~ s/^(?:\Q${tag}\E |)/${tag} /g;
    $subject =~ s/\n*$/\n/s;
  }

  # add report headers to message
  $newmsg .= "From: $from" if $from;
  $newmsg .= "To: $to" if $to;
  $newmsg .= "Cc: $cc" if $cc;
  $newmsg .= "Subject: $subject" if $subject;
  $newmsg .= "Date: $date" if $date;
  $newmsg .= "Message-Id: $msgid" if $msgid;

  foreach my $header (keys %{$self->{conf}->{headers_spam}} ) {
    my $data = $self->{conf}->{headers_spam}->{$header};
    my $line = $self->_process_header($header,$data) || "";
    $newmsg .= "X-Spam-$header: $line\n" # add even if empty
  }

  if (defined $self->{conf}->{report_safe_copy_headers}) {
    my %already_added = map { $_ => 1 } qw/from to cc subject date message-id/;

    foreach my $hdr ( @{$self->{conf}->{report_safe_copy_headers}} ) {
      next if ( exists $already_added{lc $hdr} );
      my @hdrtext = $self->{msg}->get_pristine_header($hdr);
      $already_added{lc $hdr}++;
      foreach ( @hdrtext ) {
	if ( lc $hdr eq "received" ) { # add Received at the top ...
          $newmsg = "$hdr: $_$newmsg";
	}
	else { # if not Received, add at the bottom ...
          $newmsg .= "$hdr: $_";
	}
      }
    }
  }

  # jm: add a SpamAssassin Received header to note markup time etc.
  # emulates the fetchmail style.
  # tvd: do this after report_safe_copy_headers so Received will be done correctly
  $newmsg = "Received: from localhost [127.0.0.1] by " .
	    Mail::SpamAssassin::Util::fq_hostname() . "\n" .
	"\twith SpamAssassin (" . Mail::SpamAssassin::Version() . " " .
	    $Mail::SpamAssassin::SUB_VERSION . ");\n" .
# CPU2006 -- now is never the time. :)
#	"\t" . Mail::SpamAssassin::Util::time_to_rfc822_date() . "\n" .
	"\t" . Mail::SpamAssassin::Util::time_to_rfc822_date(83273400) . "\n" .
	    $newmsg;

  # MIME boundary
# CPU2006 -- fix this so that folks will be able to validate in the future
#  my $boundary = "----------=_" . sprintf("%08X.%08X",time,int(rand(2 ** 32)));
  my $boundary = "----------=_" . sprintf("%08X.%08X",85377600,int(rand(2 ** 32)));

  # ensure it's unique, so we can't be attacked this way
  while ($original =~ /^\Q${boundary}\E$/m) {
    $boundary .= "/".sprintf("%08X",int(rand(2 ** 32)));
  }

  # determine whether Content-Disposition should be "attachment" or "inline"
  my $disposition;
  my $ct = $self->{msg}->get_header("Content-Type");
  if (defined $ct && $ct ne '' && $ct !~ m{text/plain}i) {
    $disposition = "attachment";
    $report .= $self->_replace_tags($self->{conf}->{unsafe_report_template});
    # if we wanted to defang the attachment, this would be the place
  }
  else {
    $disposition = "inline";
  }

  my $type = "message/rfc822";
  $type = "text/plain" if $self->{conf}->{report_safe} > 1;

  my $description = $self->{main}->{'encapsulated_content_description'};

  # Note: the message should end in blank line since mbox format wants
  # blank line at end and messages may be concatenated!  In addition, the
  # x-spam-type parameter is fixed since we will use it later to recognize
  # original messages that can be extracted.
  $newmsg .= <<"EOM";
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="$boundary"

This is a multi-part message in MIME format.

--$boundary
Content-Type: text/plain$report_charset
Content-Disposition: inline
Content-Transfer-Encoding: 8bit

$report

--$boundary
Content-Type: $type; x-spam-type=original
Content-Description: $description
Content-Disposition: $disposition
Content-Transfer-Encoding: 8bit

$original
--$boundary--

EOM
  
  my @lines = split (/^/m,  $newmsg);
  $self->{msg}->replace_original_message(\@lines);

  $self->{msg}->get_mail_object;
}

sub rewrite_headers {
  my ($self) = @_;

  if($self->{is_spam}) {

    if ($self->{conf}->{rewrite_subject}) {
      my $subject = $self->{msg}->get_header("Subject") || '';
      my $tag = $self->{conf}->{subject_tag};
      # CPU2006
      #$tag =~ s/_HITS_/sprintf("%05.2f", $self->{hits})/e;
      #$tag =~ s/_REQD_/sprintf("%05.2f", $self->{conf}->{required_hits})/e;
      $tag =~ s/_HITS_/sprintf("%4d", int($self->{hits}))/e;
      $tag =~ s/_REQD_/sprintf("%4d", int($self->{conf}->{required_hits}))/e;
      $subject =~ s/^(?:\Q${tag}\E |)/${tag} /g;
      $subject =~ s/\n*$/\n/s;
      $self->{msg}->replace_header("Subject", $subject);
    }

    foreach my $header (keys %{$self->{conf}->{headers_spam}} ) {
      my $data = $self->{conf}->{headers_spam}->{$header};
      my $line = $self->_process_header($header,$data) || "";
      $self->{msg}->put_header ("X-Spam-$header", $line);
    }


  } else {

    foreach my $header (keys %{$self->{conf}->{headers_ham}} ) {
      my $data = $self->{conf}->{headers_ham}->{$header};
      my $line = $self->_process_header($header,$data) || "";
      $self->{msg}->put_header ("X-Spam-$header", $line);
    }


  }
  $self->{msg}->get_mail_object;
}


sub _process_header {

  my ($self, $hdr_name, $hdr_data) = @_;

  $hdr_data = $self->_replace_tags($hdr_data);
  $hdr_data =~ s/(?:\r?\n)+$//; # make sure there are no trailing newlines ...

  if ($self->{conf}->{fold_headers} ) {
    if ($hdr_data =~ /\n/) {
      $hdr_data =~ s/\s*\n\s*/\n\t/g;
      return $hdr_data;
    } else {
      my $hdr = "X-Spam-$hdr_name!!$hdr_data";
      # use '!!' instead of ': ' so it doesn't wrap on the space
      $Text::Wrap::columns = 79;
      $Text::Wrap::huge = 'wrap';
      $Text::Wrap::break = '(?<=[\s,])';
      $hdr = Text::Wrap::wrap('',"\t",$hdr);
      return (split (/!!/, $hdr, 2))[1]; # just return the data part
    }
  } else {
    $hdr_data =~ s/\n/ /g; # Can't have newlines in headers, unless folded
    return $hdr_data;
  }
}

sub _replace_tags {
  my $self = shift;
  my $text = shift;

  $text =~ s/_(\w+?)(?:\((.*?)\)|)_/${\($self->_get_tag($1,$2 || ""))}/g;
  return $text;
}

sub _get_tag {
  my $self = shift;
  my $tag = shift;
  my %tags;

  # tag data also comes from $self->{tag_data}->{TAG}

  %tags = ( YESNOCAPS => sub { $self->{is_spam} ? "YES" : "NO"; },

	    YESNO => sub { $self->{is_spam} ? "Yes" : "No"; },

            # CPU2006 changes here -- I forgot to save the previous lines
	    HITS => sub { sprintf ("%d", int($self->{hits})); },

	    REQD => sub { sprintf ("%d", int($self->{conf}->{required_hits})); },

	    VERSION => sub { return Mail::SpamAssassin::Version()},

	    SUBVERSION => sub { $Mail::SpamAssassin::SUB_VERSION },

	    HOSTNAME => sub { Mail::SpamAssassin::Util::fq_hostname(); },

	    CONTACTADDRESS => sub { $self->{conf}->{report_contact}; },

	    BAYES => sub {
	      exists($self->{bayes_score}) ?
			sprintf("%3.4f", $self->{bayes_score}) : "0.5"
	    },

	    DATE => sub {
# CPU2006 -- make this constant, too
#	      Mail::SpamAssassin::Util::time_to_rfc822_date();
	      Mail::SpamAssassin::Util::time_to_rfc822_date(1012698140);
	    },

	    STARS => sub {
	      my $arg = (shift || "*");
	      my $length = int($self->{hits});
	      $length = 50 if $length > 50;
	      return $arg x $length;
	    },

	    AUTOLEARN => sub {
	      return "no" if !defined $self->{auto_learn_status};
	      return "spam" if $self->{auto_learn_status};
	      return "ham";
	    },

	    TESTS => sub {
	      my $arg = (shift || ',');
	      return (join($arg, sort(@{$self->{test_names_hit}})) || "none");
	    },

	    TESTSSCORES => sub {
	      my $arg = (shift || ",");
	      my $line = '';
	      foreach my $test (sort @{$self->{test_names_hit}}) {
		if (!$line) {
		  $line .= $test . "=" . $self->{conf}->{scores}->{$test};
		} else {
		  $line .= $arg . $test . "=" . $self->{conf}->{scores}->{$test};
		}
	      }
	      return $line;
	    },

	    PREVIEW => sub { $self->get_content_preview() },

	    REPORT => sub {
	      return "\n" . ($self->{tag_data}->{REPORT} || "");
	    },

	  );

  if (exists $tags{$tag}) {
      return $tags{$tag}->(@_);
  } elsif ($self->{tag_data}->{$tag}) {
    return $self->{tag_data}->{$tag};
  } else {
    return "";
  }
}

###########################################################################

=item $messagestring = $status->get_full_message_as_text ()

Returns the mail message as a string, including headers and raw body text.

If the message has been rewritten using C<rewrite_mail()>, these changes
will be reflected in the string.

Note: this is simply a helper method which calls methods on the mail message
object.  It is provided because Mail::Audit uses an unusual (ie. not quite
intuitive) interface to do this, and it has been a common stumbling block for
authors of scripts which use SpamAssassin.

=cut

sub get_full_message_as_text {
  my ($self) = @_;
  return join ("", $self->{msg}->get_all_headers(), "\n",
			@{$self->{msg}->get_body()});
}

###########################################################################

=item $status->finish ()

Indicate that this C<$status> object is finished with, and can be destroyed.

If you are using SpamAssassin in a persistent environment, or checking many
mail messages from one L<Mail::SpamAssassin> factory, this method should be
called to ensure Perl's garbage collection will clean up old status objects.

=cut

sub finish {
  my ($self) = @_;

  delete $self->{body_text_array};
  delete $self->{main};
  delete $self->{msg};
  delete $self->{conf};
  delete $self->{res};
  delete $self->{hits};
  delete $self->{test_names_hit};
  delete $self->{subtest_names_hit};
  delete $self->{test_logs};
  delete $self->{replacelines};

  $self = { };
}

###########################################################################
# Non-public methods from here on.

sub get_raw_body_text_array {
  my ($self) = @_;
  local ($_);

  if (defined $self->{body_text_array}) { return $self->{body_text_array}; }

  $self->{found_encoding_base64} = 0;
  $self->{found_encoding_quoted_printable} = 0;

  my $cte = $self->{msg}->get_header ('Content-Transfer-Encoding');
  if (defined $cte && $cte =~ /quoted-printable/i) {
    $self->{found_encoding_quoted_printable} = 1;
  }
  elsif (defined $cte && $cte =~ /base64/i) {
    $self->{found_encoding_base64} = 1;
  }

  my $ctype = $self->{msg}->get_header ('Content-Type');
  $ctype = '' unless ( defined $ctype );

  # if it's non-text, just return an empty body rather than the base64-encoded
  # data.  If spammers start using images to spam, we'll block 'em then!
  if ($ctype =~ /^(?:image\/|application\/|video\/)/i) {
    $self->{body_text_array} = [ ];
    return $self->{body_text_array};
  }

  # if it's a multipart MIME message, skip non-text parts and
  # just assemble the body array from the text bits.
  my $multipart_boundary;
  my $end_boundary;
  if ( $ctype =~ /\bboundary\s*=\s*["']?(.*?)["']?(?:;|$)/i ) {
    $multipart_boundary = "--$1\n";
    $end_boundary = "--$1--\n";
  }

  my $ctypeistext = 1;

  # we build up our own copy from the Mail::Audit message-body array
  # reference, skipping MIME parts. this should help keep down in-memory
  # text size.
  my $bodyref = $self->{msg}->get_body();
  $self->{body_text_array} = [ ];

  my $line;
  my $uu_region = 0;
  for ($line = 0; defined($_ = $bodyref->[$line]); $line++)
  {
    # we run into a perl bug if the lines are astronomically long (probably due
    # to lots of regexp backtracking); so cut short any individual line over
    # MAX_BODY_LINE_LENGTH bytes in length.  This can wreck HTML totally -- but
    # IMHO the only reason a luser would use MAX_BODY_LINE_LENGTH-byte lines is
    # to crash filters, anyway.

    while (length ($_) > MAX_BODY_LINE_LENGTH) {
      push (@{$self->{body_text_array}}, substr($_, 0, MAX_BODY_LINE_LENGTH));
      substr($_, 0, MAX_BODY_LINE_LENGTH) = '';
    }

    # Note that all the parsing code below will, as a result, not operate on
    # lines > MAX_BODY_LINE_LENGTH bytes; but that should be OK, given that
    # lines of that length are not RFC-compliant anyway!

    # look for uuencoded text
    if ($uu_region == 0 && /^begin [0-7]{3} .*/) {
      $uu_region = 1;
    }
    elsif ($uu_region == 1 && /^[\x21-\x60]{1,61}$/) {
      $uu_region = 2;
    }
    elsif ($uu_region == 2 && /^end$/) {
      $uu_region = 0;
      $self->{found_encoding_uuencode} = 1;
    }

    # This all breaks if you don't strip off carriage returns.
    # Both here and below.
    # (http://bugzilla.spamassassin.org/show_bug.cgi?id=516)
    s/\r$//;

    push(@{$self->{body_text_array}}, $_);

    next unless defined ($multipart_boundary);
    # MIME-only from here on.

    if (/^Content-Transfer-Encoding: /i) {
      if (/quoted-printable/i) {
	$self->{found_encoding_quoted_printable} = 1;
      }
      elsif (/base64/i) {
	$self->{found_encoding_base64} = 1;
      }
    }

    if ($multipart_boundary eq $_) {
      my $starting_line = $line;
      for ($line++; defined($_ = $bodyref->[$line]); $line++) {
        s/\r//;

	if (/^$/) { last; }

	if (/^Content-Type: (\S+?\/\S+?)(?:\;|\s|$)/i) {
	  $ctype = $1;
	  if ($ctype =~ /^(text\/\S+|message\/\S+|multipart\/alternative|multipart\/related)/i)
	  {
	    $ctypeistext = 1; next;
	  } else {
	    $ctypeistext = 0; next;
	  }
	}
      }

      $line = $starting_line;

      last unless defined $_;

      if (!$ctypeistext) {
	# skip this attachment, it's non-text.
	push (@{$self->{body_text_array}}, "[skipped $ctype attachment]\n");

	for ($line++; defined($_ = $bodyref->[$line]); $line++) {
	  if ($end_boundary eq $_) { last; }
	  if ($multipart_boundary eq $_) { $line--; last; }
	}
      }
    }
  }

  #print "dbg ".join ("", @{$self->{body_text_array}})."\n\n\n";
  return $self->{body_text_array};
}

###########################################################################

sub get_decoded_body_text_array {
  my ($self) = @_;
  local ($_);
  my $textary = $self->get_raw_body_text_array();

  # TODO: doesn't yet handle checking multiple-attachment messages,
  # where one part is qp and another is b64.  Instead the qp will
  # be simply stripped.

  if ($self->{found_encoding_base64}) {
    $_ = '';
    my $foundb64 = 0;
    my $lastlinelength = 0;
    my $b64lines = 0;
    my @decoded = ();
    foreach my $line (@{$textary}) {
      # base64 can't have whitespace on the line or start --
      if ($line =~ /[ \t]/ or $line =~ /^--/) {
	# decode what we have so far
	push (@decoded, $self->split_b64_decode ($_), $line);
	$_ = '';
        $foundb64 = 0;
        next;
      }
      # This line is a different length from the last one
      if (length($line) != $lastlinelength && !$foundb64) {
	push (@decoded, $self->split_b64_decode ($_));
        $_ = $line;	# Could be the first line of a base 64 part
        $lastlinelength = length($line);
        next;
      }
      # Same length as the last line.  Starting to look like a base64 encoding
      if ($lastlinelength == length ($line)) {
	# Three lines the same length, with no spaces in them
        if ($b64lines++ == 3 && length ($line) > 3) {
	  # Sounds like base64 to me!
          $foundb64 = 1;
        }
        $_ .= $line;
        next;
      }
      # Last line is shorter, so we are done.
      if ($foundb64) {
        $_ .= $line;
        last;
      }
    }
    push (@decoded, $self->split_b64_decode ($_));
    return \@decoded;
  }
  elsif ($self->{found_encoding_quoted_printable}) {
    $_ = join ('', @{$textary});
    s/\=\r?\n//gs;
    s/\=([0-9A-F]{2})/chr(hex($1))/ge;
    my @ary = $self->split_into_array_of_short_lines ($_);
    return \@ary;
  }
  elsif ($self->{found_encoding_uuencode}) {
    # remove uuencoded regions
    my $uu_region = 0;
    $_ = '';
    foreach my $line (@{$textary}) {
      if ($uu_region == 0 && $line =~ /^begin [0-7]{3} .*/) {
	$uu_region = 1;
	next;
      }
      if ($uu_region) {
	if ($line =~ /^[\x21-\x60]{1,61}$/) {
	  # here is where we could uudecode text if we had a use for it
	  # $decoded = unpack("%u", $line);
	  next;
	}
	elsif ($line =~ /^end$/) {
	  $uu_region = 0;
	  next;
	}
	# any malformed lines get passed through
      }
      $_ .= $line;
    }
    s/\r//;
    my @ary = $self->split_into_array_of_short_lines ($_);
    return \@ary;
  }
  else {
    return $textary;
  }
}

sub split_into_array_of_short_lines {
  my $self = shift;

  my @result = ();
  foreach my $line (split (/^/m, $_[0])) {
    while (length ($line) > MAX_BODY_LINE_LENGTH) {
      push (@result, substr($line, 0, MAX_BODY_LINE_LENGTH));
      substr($line, 0, MAX_BODY_LINE_LENGTH) = '';
    }
    push (@result, $line);
  }
  @result;
}

sub split_b64_decode {
  my ($self) = shift;
  return $self->split_into_array_of_short_lines
		  ($self->generic_base64_decode ($_[0]));
}

###########################################################################

sub get_decoded_stripped_body_text_array {
  my ($self) = @_;
  local ($_);

  my $bodytext = $self->get_decoded_body_text_array();

   my $ctype = $self->{msg}->get_header ('Content-Type');
   $ctype = '' unless ( defined $ctype );

   # if it's a multipart MIME message, skip the MIME-definition stuff
   my $boundary;
   if ( $ctype =~ /\bboundary\s*=\s*["']?(.*?)["']?(?:;|$)/i ) {
     $boundary = $1;
   }

  my $text = $self->get('subject', '') . "\n\n";
  my $lastwasmime = 0;
  foreach $_ (@{$bodytext}) {
    /^SPAM: / and next;         # SpamAssassin markup

    defined $boundary and $_ eq "--$boundary\n" and $lastwasmime=1 and next;           # MIME start
    defined $boundary and $_ eq "--$boundary--\n" and next;                            # MIME end

    if ($lastwasmime) {
      /^$/ and $lastwasmime=0;
      /Content-.*: /i and next;
      /^\s/ and next;
    }

    $text .= $_;
  }

  # Convert =xx and =\n into chars
  $text =~ s/=([A-F0-9]{2})/chr(hex($1))/ge;
  $text =~ s/=\n//g;

  # reset variables used in HTML tests
  $self->{html} = {};
  $self->{html_inside} = {};
  $self->{html}{ratio} = 0;
  $self->{html}{image_area} = 0;
  $self->{html}{shouting} = 0;
  $self->{html}{max_shouting} = 0;
  $self->{html}{total_comment_ratio} = 0;

  # do HTML conversions if necessary
  if ($text =~ m/<(?:$re_strict|$re_loose|!--|!doctype)(?:\s|>)/ois) {
    my $raw = length($text);

    # NOTE: do another match instead of using $-[0]; not supported
    # under old perls
    $text =~ m/^(.*?)<(?:$re_strict|$re_loose|!--|!doctype)(?:\s|>)/ois;
    my $before = substr($text, 0, length($1));
    $text = substr($text, length($1));

    # NOTE: We *only* need to fix the rendering when we verify that it
    # differs from what people see in their MUA.  Testing is best done with
    # the most common MUAs and browsers, if you catch my drift.

    # NOTE: HTML::Parser can cope with: <?xml pis>, <? with space>, so we
    # don't need to fix them here.

    # bug #1551: HTML declarations, like <!foo>, are being used by spammers
    # for obfuscation, and they aren't stripped out by HTML::Parser prior to
    # version 3.28.  We have to modify these out *before* the parser is
    # invoked, because otherwise a spammer could do "&lt;! body of message
    # &gt;", which would get turned into "<! body of message >" by the
    # parser, and then the whole body message would be stripped.

    # convert <!foo> to <!--foo-->
    if ($HTML::Parser::VERSION < 3.28) { 
      $text =~ s/<!((?!--|doctype)[^>]*)>/<!--$1-->/gsi;
    }

    # remove empty close tags: </>, </ >, </ foo>
    if ($HTML::Parser::VERSION < 3.29) { 
      $text =~ s/<\/(?:\s.*?)?>//gs;
    }

    $self->{html_text} = [];
    $self->{html_last_tag} = 0;
    my $hp = HTML::Parser->new(
		api_version => 3,
		handlers => [
		  start_document => [sub { $self->html_init(@_) }],
		  start => [sub { $self->html_tag(@_) }, "tagname,attr,'+1'"],
		  end => [sub { $self->html_tag(@_) }, "tagname,attr,'-1'"],
		  text => [sub { $self->html_text(@_) }, "dtext"],
		  comment => [sub { $self->html_comment(@_) }, "text"],
		  declaration => [sub { $self->html_declaration(@_) }, "text"],
		],
		marked_sections => 1);

    # ALWAYS pack it into byte-representation, even if we're using 'use bytes',
    # since the HTML::Parser object may use Unicode internally.
    # (bug 1417, maybe)
    $hp->parse(pack ('C0A*', $text));
    $hp->eof;

    $text = join('', $before, @{$self->{html_text}});

    if ($raw > 0) {
      my $space = ($before =~ tr/ \t\n\r\x0b\xa0/ \t\n\r\x0b\xa0/);
      $self->{html}{non_uri_len} = length($before);
      for my $line (@{$self->{html_text}}) {
	$line = pack ('C0A*', $line);
	$space += ($line =~ tr/ \t\n\r\x0b\xa0/ \t\n\r\x0b\xa0/);
	$self->{html}{non_uri_len} += length($line);
        for my $uri ($line =~ m/\b(URI:\S+)/g) {
	  $self->{html}{non_uri_len} -= length($uri);
	}
      }
      $self->{html}{non_space_len} = $self->{html}{non_uri_len} - $space;
      $self->{html}{ratio} = int(1000 * ($raw - $self->{html}{non_uri_len}) / $raw);
      if (exists $self->{html}{total_comment_length} && $self->{html}{non_uri_len} > 0) {
        $self->{html}{total_comment_ratio} = int(1000 * $self->{html}{total_comment_length} / $self->{html}{non_uri_len});
      }
    } # if ($raw > 0)
    delete $self->{html_last_tag};

  } # if HTML

  # whitespace handling (warning: small changes have large effects!)
  $text =~ s/\n+\s*\n+/\f/gs;		# double newlines => form feed
  $text =~ tr/ \t\n\r\x0b\xa0/ /s;	# whitespace => space
  $text =~ tr/\f/\n/;			# form feeds => newline

  my @textary = $self->split_into_array_of_short_lines ($text);

  return \@textary;
}

###########################################################################

sub get {
  my ($self, $request, $defval) = @_;
  local ($_);

  if (exists $self->{hdr_cache}->{$request}) {
    $_ = $self->{hdr_cache}->{$request};
  }
  else {
    my $hdrname = $request;
    my $getaddr = ($hdrname =~ s/:addr$//);
    my $getname = ($hdrname =~ s/:name$//);
    my $getraw = ($hdrname eq 'ALL' || $hdrname =~ s/:raw$//);

    if ($hdrname eq 'ALL') {
      $_ = $self->{msg}->get_all_headers();
    }
    # ToCc: the combined recipients list
    elsif ($hdrname eq 'ToCc') {
      $_ = join ("\n", $self->{msg}->get_header ('To'));
      if ($_ ne '') {
	chop $_;
	$_ .= ", " if /\S/;
      }
      $_ .= join ("\n", $self->{msg}->get_header ('Cc'));
      undef $_ if $_ eq '';
    }
    # MESSAGEID: handle lists which move the real message-id to another
    # header for resending.
    elsif ($hdrname eq 'MESSAGEID') {
      $_ = join ("\n", grep { defined($_) && length($_) > 0 }
		$self->{msg}->get_header ('X-Message-Id'),
		$self->{msg}->get_header ('Resent-Message-Id'),
		$self->{msg}->get_header ('X-Original-Message-ID'), # bug 2122
		$self->{msg}->get_header ('Message-Id'));
    }
    # a conventional header
    else {
      my @hdrs = $self->{msg}->get_header ($hdrname);
      if ($#hdrs >= 0) {
	$_ = join ("\n", @hdrs);
      }
      else {
	$_ = undef;
      }
    }

    if (defined) {
      if ($getaddr) {
	chomp; s/\r?\n//gs;
	s/\s*\(.*?\)//g;            # strip out the (comments)
	s/^[^<]*?<(.*?)>.*$/$1/;    # "Foo Blah" <jm@foo> or <jm@foo>
	s/, .*$//gs;                # multiple addrs on one line: return 1st
	s/ ;$//gs;                  # 'undisclosed-recipients: ;'
      }
      elsif ($getname) {
	chomp; s/\r?\n//gs;
	s/^[\'\"]*(.*?)[\'\"]*\s*<.+>\s*$/$1/g # Foo Blah <jm@foo>
	    or s/^.+\s\((.*?)\)\s*$/$1/g;	   # jm@foo (Foo Blah)
      }
      elsif (!$getraw) {
	$_ = $self->mime_decode_header ($_);
      }
    }
    $self->{hdr_cache}->{$request} = $_;
  }

  if (!defined) {
    $defval ||= '';
    $_ = $defval;
  }

  $_;
}

###########################################################################

# This function will decode MIME-encoded headers.  Note that it is ONLY
# used from test functions, so destructive or mildly inaccurate results
# will not have serious consequences.  Do not replace the original message
# contents with anything decoded using this!
#
sub mime_decode_header {
  my ($self, $enc) = @_;

  # cf. http://www.nacs.uci.edu/indiv/ehood/MHonArc/doc/resources/charsetconverters.html

  # quoted-printable encoded headers.
  # ASCII:  =?US-ASCII?Q?Keith_Moore?= <moore@cs.utk.edu>
  # Latin1: =?ISO-8859-1?Q?Keld_J=F8rn_Simonsen?= <keld@dkuug.dk>
  # Latin1: =?ISO-8859-1?Q?Andr=E9_?= Pirard <PIRARD@vm1.ulg.ac.be>

  if ($enc =~ s{\s*=\?([^\?]+)\?[Qq]\?([^\?]+)\?=}{
    		$self->decode_mime_bit ($1, $2);
	      }eg)
  {
    my $rawenc = $enc;

    # Sitck lines back together when the encoded header wraps a line eg:
    #
    # Subject: =?iso-2022-jp?B?WxskQjsoM1gyI0N6GyhCIBskQk4iREwkahsoQiAy?=
    #   =?iso-2022-jp?B?MDAyLzAzLzE5GyRCOWYbKEJd?=

    $enc = "";
    my $splitenc;

    foreach $splitenc (split (/\n/, $rawenc)) {
      $enc .= $splitenc;
    }
    dbg ("decoded MIME header: \"$enc\"");
  }

  # handle base64-encoded headers. eg:
  # =?UTF-8?B?Rlc6IFBhc3NpbmcgcGFyYW1ldGVycyBiZXR3ZWVuIHhtbHMgdXNp?=
  # =?UTF-8?B?bmcgY29jb29uIC0gcmVzZW50IA==?=   (yuck)

  if ($enc =~ s{\s*=\?([^\?]+)\?[Bb]\?([^\?]+)\?=}{
    		$self->generic_base64_decode ($2);
	      }eg)
  {
    my $rawenc = $enc;

    # Sitck lines back together when the encoded header wraps a line

    $enc = "";
    my $splitenc;

    foreach $splitenc (split (/\n/, $rawenc)) {
      $enc .= $splitenc;
    }
    dbg ("decoded MIME header: \"$enc\"");
  }

  return $enc;
}

sub decode_mime_bit {
  my ($self, $encoding, $text) = @_;
  local ($_) = $text;

  $encoding = lc($encoding);

  if ($encoding eq 'utf-16') {
    # we just dump the high bits and keep the 8-bit characters
    s/_/ /g;
    s/=00//g;
    s/\=([0-9A-F]{2})/chr(hex($1))/ge;
  }
  else {
    # keep 8-bit stuff, forget mapping charsets though
    s/_/ /g;
    s/\=([0-9A-F]{2})/chr(hex($1))/ge;
  }

  return $_;
}

sub ran_rule_debug_code {
  my ($self, $rulename, $ruletype, $bit) = @_;

  return '' if (!$Mail::SpamAssassin::DEBUG->{enabled}
                && !$self->{save_pattern_hits});

  my $log_hits_code = '';
  my $save_hits_code = '';

  if ($Mail::SpamAssassin::DEBUG->{enabled} &&
      ($Mail::SpamAssassin::DEBUG->{rulesrun} & $bit) != 0)
  {
    # note: keep this in 'single quotes' to avoid the $ & performance hit,
    # unless specifically requested by the caller.
    $log_hits_code = ': match=\'$&\'';
  }

  if ($self->{save_pattern_hits}) {
    $save_hits_code = '
        $self->{pattern_hits}->{q{'.$rulename.'}} = $&;
    ';
  }

  return '
    dbg ("Ran '.$ruletype.' rule '.$rulename.' ======> got hit'.
        $log_hits_code.'", "rulesrun", '.$bit.');
    '.$save_hits_code.'
  ';

  # do we really need to see when we *don't* get a hit?  If so, it should be a
  # separate level as it's *very* noisy.
  #} else {
  #  dbg ("Ran '.$ruletype.' rule '.$rulename.' but did not get hit", "rulesrun", '.
  #      $bit.');
}

sub hash_line_for_rule {
  my ($self, $rulename) = @_;
  return "\n".'#line 1 "'.
	$self->{conf}->{source_file}->{$rulename}.
	', rule '.$rulename.',"';
}

###########################################################################

sub do_head_tests {
  my ($self) = @_;
  local ($_);

  # note: we do this only once for all head pattern tests.  Only
  # eval tests need to use stuff in here.
  $self->{test_log_msgs} = ();	# clear test state

  dbg ("running header regexp tests; score so far=".$self->{hits});

  my $doing_user_rules = 
    $self->{conf}->{user_rules_to_compile}->{Mail::SpamAssassin::Conf::TYPE_HEAD_TESTS};

  # speedup code provided by Matt Sergeant
  if (defined &Mail::SpamAssassin::PerMsgStatus::_head_tests && !$doing_user_rules) {
    Mail::SpamAssassin::PerMsgStatus::_head_tests($self);
    return;
  }

  my $evalstr = '';
  my $evalstr2 = '';

  while (my($rulename, $rule) = each %{$self->{conf}{head_tests}}) {
    my $def = '';
    my ($hdrname, $testtype, $pat) =
        $rule =~ /^\s*(\S+)\s*(\=|\!)\~\s*(\S.*?\S)\s*$/;

    if (!defined $pat) {
      warn "invalid rule: $rulename\n";
      $self->{rule_errors}++;
      next;
    }

    if ($pat =~ s/\s+\[if-unset:\s+(.+)\]\s*$//) { $def = $1; }

    $hdrname =~ s/#/[HASH]/g;		# avoid probs with eval below
    $def =~ s/#/[HASH]/g;

    $evalstr .= '
      if ($self->{conf}->{scores}->{q#'.$rulename.'#}) {
         '.$rulename.'_head_test($self, $_); # no need for OO calling here (its faster this way)
      }
    ';

    if ($doing_user_rules) {
      next if (!$self->is_user_rule_sub ($rulename.'_head_test'));
    }

    $evalstr2 .= '
      sub '.$rulename.'_head_test {
        my $self = shift;
        $_ = shift;
	'.$self->hash_line_for_rule($rulename).'
        if ($self->get(q#'.$hdrname.'#, q#'.$def.'#) '.$testtype.'~ '.$pat.') {
          $self->got_hit (q#'.$rulename.'#, q{});
          '. $self->ran_rule_debug_code ($rulename,"header regex", 1) . '
        }
      }';

  }

  # clear out a previous version of this fn, if already defined
  if (defined &_head_tests) { undef &_head_tests; }

  $evalstr = <<"EOT";
{
    package Mail::SpamAssassin::PerMsgStatus;

    $evalstr2

    sub _head_tests {
        my (\$self) = \@_;

        $evalstr;
    }

    1;
}
EOT

  eval $evalstr;

  if ($@) {
    warn "Failed to run header SpamAssassin tests, skipping some: $@\n";
    $self->{rule_errors}++;
  }
  else {
    Mail::SpamAssassin::PerMsgStatus::_head_tests($self);
  }
}

sub do_body_tests {
  my ($self, $textary) = @_;
  local ($_);

  dbg ("running body-text per-line regexp tests; score so far=".$self->{hits});

  my $doing_user_rules = 
    $self->{conf}->{user_rules_to_compile}->{Mail::SpamAssassin::Conf::TYPE_BODY_TESTS};

  $self->{test_log_msgs} = ();	# clear test state
  if ( defined &Mail::SpamAssassin::PerMsgStatus::_body_tests && !$doing_user_rules) {
    Mail::SpamAssassin::PerMsgStatus::_body_tests($self, @$textary);
    return;
  }

  # build up the eval string...
  my $evalstr = '';
  my $evalstr2 = '';

  while (my($rulename, $pat) = each %{$self->{conf}{body_tests}}) {
    $evalstr .= '
      if ($self->{conf}->{scores}->{q{'.$rulename.'}}) {
        # call procedurally as it is faster.
        '.$rulename.'_body_test($self,@_);
      }
    ';

    if ($doing_user_rules) {
      next if (!$self->is_user_rule_sub ($rulename.'_body_test'));
    }

    $evalstr2 .= '
    sub '.$rulename.'_body_test {
           my $self = shift;
           foreach ( @_ ) {
	     '.$self->hash_line_for_rule($rulename).'
             if ('.$pat.') { 
	        $self->got_body_pattern_hit (q{'.$rulename.'}); 
                '. $self->ran_rule_debug_code ($rulename,"body-text regex", 2) . '
	     }
	   }
    }
    ';
  }

  # clear out a previous version of this fn, if already defined
  if (defined &_body_tests) { undef &_body_tests; }

  # generate the loop that goes through each line...
  $evalstr = <<"EOT";
{
  package Mail::SpamAssassin::PerMsgStatus;

  $evalstr2

  sub _body_tests {
    my \$self = shift;
    $evalstr;
  }

  1;
}
EOT

  # and run it.
  eval $evalstr;
  if ($@) {
    warn("Failed to compile body SpamAssassin tests, skipping:\n".
	      "\t($@)\n");
    $self->{rule_errors}++;
  }
  else {
    Mail::SpamAssassin::PerMsgStatus::_body_tests($self, @$textary);
  }
}

sub is_user_rule_sub {
  my ($self, $subname) = @_;
  return 0 if (eval 'defined &Mail::SpamAssassin::PerMsgStatus::'.$subname);
  1;
}

# Taken from URI and URI::Find
my $reserved   = q(;/?:@&=+$,[]\#|);
my $mark       = q(-_.!~*'());                                    #'; emacs
my $unreserved = "A-Za-z0-9\Q$mark\E\x00-\x08\x0b\x0c\x0e-\x1f";
my $uricSet = quotemeta($reserved) . $unreserved . "%";

my $schemeRE = qr/(?:https?|ftp|mailto|javascript|file)/;

my $uricCheat = $uricSet;
$uricCheat =~ tr/://d;

my $schemelessRE = qr/(?<![.=])(?:www\.|ftp\.)/;
my $uriRe = qr/\b(?:$schemeRE:[$uricCheat]|$schemelessRE)[$uricSet#]*/o;

# Taken from Email::Find (thanks Tatso!)
# This is the BNF from RFC 822
my $esc         = '\\\\';
my $period      = '\.';
my $space       = '\040';
my $open_br     = '\[';
my $close_br    = '\]';
my $nonASCII    = '\x80-\xff';
my $ctrl        = '\000-\037';
my $cr_list     = '\n\015';
my $qtext       = qq/[^$esc$nonASCII$cr_list\"]/; #"
my $dtext       = qq/[^$esc$nonASCII$cr_list$open_br$close_br]/;
my $quoted_pair = qq<$esc>.qq<[^$nonASCII]>;
my $atom_char   = qq/[^($space)<>\@,;:\".$esc$open_br$close_br$ctrl$nonASCII]/;
#"
my $atom        = qq{(?>$atom_char+)};
my $quoted_str  = qq<\"$qtext*(?:$quoted_pair$qtext*)*\">; #"
my $word        = qq<(?:$atom|$quoted_str)>;
my $local_part  = qq<$word(?:$period$word)*>;

# This is a combination of the domain name BNF from RFC 1035 plus the
# domain literal definition from RFC 822, but allowing domains starting
# with numbers.
my $label       = q/[A-Za-z\d](?:[A-Za-z\d-]*[A-Za-z\d])?/;
my $domain_ref  = qq<$label(?:$period$label)*>;
my $domain_lit  = qq<$open_br(?:$dtext|$quoted_pair)*$close_br>;
my $domain      = qq<(?:$domain_ref|$domain_lit)>;

# Finally, the address-spec regex (more or less)
my $Addr_spec_re   = qr<$local_part\s*\@\s*$domain>o;

# Discard all but one of identical successive entries in an array.
# The input must be sorted if you want the returned array to be
# without identical entries.
sub _uniq {
  my $previous;
  my @uniq;
  if (@_) {
    push(@uniq, ($previous = shift(@_)));
  }
  foreach my $current (@_) {
    next if ($current eq $previous);
    push(@uniq, ($previous = $current));
  }
  return @uniq;
}

sub get_uri_list {
  my ($self) = @_;

  my $textary = $self->get_decoded_body_text_array();
  my ($rulename, $pat, @uris);
  local ($_);

  my $base_uri = $self->{html}{base_href} || "http://";
  my $text;

  for (@$textary) {
    # NOTE: do not modify $_ in this loop
    while (/($uriRe)/go) {
      my $uri = $1;

      $uri =~ s/^<(.*)>$/$1/;
      $uri =~ s/[\]\)>#]$//;
      $uri =~ s/^URI://i;

      # Does the uri start with "http://", "mailto:", "javascript:" or
      # such?  If not, we probably need to put the base URI in front
      # of it.
      if ($uri !~ /^${schemeRE}:/io) {
        # If it's a hostname that was just sitting out in the
        # open, without a protocol, and not inside of an HTML tag,
        # the we should add the proper protocol in front, rather
        # than using the base URI.
        if ($uri =~ /^www\d*\./i) {
          # some spammers are using unschemed URIs to escape filters
          push (@uris, $uri);
          $uri = "http://$uri";
        }
        elsif ($uri =~ /^ftp\./i) {
          push (@uris, $uri);
          $uri = "ftp://$uri";
        }
        else {
          $uri = "${base_uri}$uri";
        }
      }

      # warn("Got URI: $uri\n");
      push @uris, $uri;
    }
    while (/($Addr_spec_re)/go) {
      my $uri = $1;

      $uri =~ s/^URI://i;
      $uri = "mailto:$uri";

      #warn("Got URI: $uri\n");
      push @uris, $uri;
    }
  }

  # remove duplicates
  @uris = _uniq(sort(@uris));

  $self->{uri_list} = \@uris;
  dbg("uri tests: Done uriRE");
  return @{$self->{uri_list}};
}

sub do_body_uri_tests {
  my ($self, $textary) = @_;
  local ($_);

  dbg ("running uri tests; score so far=".$self->{hits});
  my @uris = $self->get_uri_list();

  my $doing_user_rules = 
    $self->{conf}->{user_rules_to_compile}->{Mail::SpamAssassin::Conf::TYPE_URI_TESTS};

  $self->{test_log_msgs} = ();	# clear test state
  if (defined &Mail::SpamAssassin::PerMsgStatus::_body_uri_tests && !$doing_user_rules) {
    Mail::SpamAssassin::PerMsgStatus::_body_uri_tests($self, @uris);
    return;
  }

  # otherwise build up the eval string...
  my $evalstr = '';
  my $evalstr2 = '';

  while (my($rulename, $pat) = each %{$self->{conf}{uri_tests}}) {

    $evalstr .= '
      if ($self->{conf}->{scores}->{q{'.$rulename.'}}) {
        '.$rulename.'_uri_test($self, @_); # call procedurally for speed
      }
    ';

    if ($doing_user_rules) {
      next if (!$self->is_user_rule_sub ($rulename.'_uri_test'));
    }

    $evalstr2 .= '
    sub '.$rulename.'_uri_test {
       my $self = shift;
       foreach ( @_ ) {
	 '.$self->hash_line_for_rule($rulename).'
         if ('.$pat.') { 
            $self->got_uri_pattern_hit (q{'.$rulename.'});
            '. $self->ran_rule_debug_code ($rulename,"uri test", 4) . '
         }
       }
    }
    ';
  }

  # clear out a previous version of this fn, if already defined
  if (defined &_body_uri_tests) { undef &_body_uri_tests; }

  # generate the loop that goes through each line...
  $evalstr = <<"EOT";
{
  package Mail::SpamAssassin::PerMsgStatus;

  $evalstr2

  sub _body_uri_tests {
    my \$self = shift;
    $evalstr;
  }

  1;
}
EOT

  # and run it.
  eval $evalstr;
  if ($@) {
    warn("Failed to compile URI SpamAssassin tests, skipping:\n".
          "\t($@)\n");
    $self->{rule_errors}++;
  }
  else {
    Mail::SpamAssassin::PerMsgStatus::_body_uri_tests($self, @uris);
  }
}

sub do_rawbody_tests {
  my ($self, $textary) = @_;
  local ($_);

  dbg ("running raw-body-text per-line regexp tests; score so far=".$self->{hits});

  my $doing_user_rules = 
    $self->{conf}->{user_rules_to_compile}->{Mail::SpamAssassin::Conf::TYPE_RAWBODY_TESTS};

  $self->{test_log_msgs} = ();	# clear test state
  if (defined &Mail::SpamAssassin::PerMsgStatus::_rawbody_tests && !$doing_user_rules) {
    Mail::SpamAssassin::PerMsgStatus::_rawbody_tests($self, @$textary);
    return;
  }

  # build up the eval string...
  my $evalstr = '';
  my $evalstr2 = '';

  while (my($rulename, $pat) = each %{$self->{conf}{rawbody_tests}}) {

    $evalstr .= '
      if ($self->{conf}->{scores}->{q{'.$rulename.'}}) {
         '.$rulename.'_rawbody_test($self, @_); # call procedurally for speed
      }
    ';

    if ($doing_user_rules) {
      next if (!$self->is_user_rule_sub ($rulename.'_rawbody_test'));
    }

    $evalstr2 .= '
    sub '.$rulename.'_rawbody_test {
       my $self = shift;
       foreach ( @_ ) {
	 '.$self->hash_line_for_rule($rulename).'
         if ('.$pat.') { 
            $self->got_body_pattern_hit (q{'.$rulename.'});
            '. $self->ran_rule_debug_code ($rulename,"body_pattern_hit", 8) . '
         }
       }
    }
    ';
  }

  # clear out a previous version of this fn, if already defined
  if (defined &_rawbody_tests) { undef &_rawbody_tests; }

  # generate the loop that goes through each line...
  $evalstr = <<"EOT";
{
  package Mail::SpamAssassin::PerMsgStatus;

  $evalstr2

  sub _rawbody_tests {
    my \$self = shift;
    $evalstr;
  }

  1;
}
EOT

  # and run it.
  eval $evalstr;
  if ($@) {
    warn("Failed to compile body SpamAssassin tests, skipping:\n".
	      "\t($@)\n");
    $self->{rule_errors}++;
  }
  else {
    Mail::SpamAssassin::PerMsgStatus::_rawbody_tests($self, @$textary);
  }
}

sub do_full_tests {
  my ($self, $fullmsgref) = @_;
  local ($_);
  
  dbg ("running full-text regexp tests; score so far=".$self->{hits});

  my $doing_user_rules = 
    $self->{conf}->{user_rules_to_compile}->{Mail::SpamAssassin::Conf::TYPE_FULL_TESTS};

  $self->{test_log_msgs} = ();	# clear test state

  if (defined &Mail::SpamAssassin::PerMsgStatus::_full_tests && !$doing_user_rules) {
    Mail::SpamAssassin::PerMsgStatus::_full_tests($self, $fullmsgref);
    return;
  }

  # build up the eval string...
  my $evalstr = '';

  while (my($rulename, $pat) = each %{$self->{conf}{full_tests}}) {
    $evalstr .= '
      if ($self->{conf}->{scores}->{q{'.$rulename.'}}) {
	'.$self->hash_line_for_rule($rulename).'
	if ($$fullmsgref =~ '.$pat.') {
	  $self->got_body_pattern_hit (q{'.$rulename.'});
          '. $self->ran_rule_debug_code ($rulename,"full-text regex", 16) . '
	}
      }
    ';
  }

  if (defined &_full_tests) { undef &_full_tests; }

  # and compile it.
  $evalstr = <<"EOT";
  {
    package Mail::SpamAssassin::PerMsgStatus;

    sub _full_tests {
	my (\$self, \$fullmsgref) = \@_;
	study \$\$fullmsgref;
	$evalstr
    }

    1;
  }
EOT
  eval $evalstr;

  if ($@) {
    warn "Failed to compile full SpamAssassin tests, skipping:\n".
	      "\t($@)\n";
    $self->{rule_errors}++;
  } else {
    Mail::SpamAssassin::PerMsgStatus::_full_tests($self, $fullmsgref);
  }
}

###########################################################################

sub do_head_eval_tests {
  my ($self) = @_;
  $self->run_eval_tests ($self->{conf}->{head_evals}, '');
}

sub do_body_eval_tests {
  my ($self, $bodystring) = @_;
  $self->run_eval_tests ($self->{conf}->{body_evals}, 'BODY: ', $bodystring);
}

sub do_rawbody_eval_tests {
  my ($self, $bodystring) = @_;
  $self->run_eval_tests ($self->{conf}->{rawbody_evals}, 'RAW: ', $bodystring);
}

sub do_full_eval_tests {
  my ($self, $fullmsgref) = @_;
  $self->run_eval_tests ($self->{conf}->{full_evals}, '', $fullmsgref);
}

###########################################################################

sub do_awl_tests {
    my($self) = @_;

    return unless (defined $self->{main}->{pers_addr_list_factory});

    local $_ = lc $self->get('From:addr');
    return 0 unless /\S/;

    # find the earliest usable "originating IP".  ignore reserved nets
    my $origip;
    foreach my $rly (reverse (@{$self->{relays_trusted}}, @{$self->{relays_untrusted}}))
    {
      next if ($rly->{ip_is_reserved});
      if ($rly->{ip}) {
	$origip = $rly->{ip}; last;
      }
    }

    # Create the AWL object, catching 'die's
    my $whitelist;
    my $evalok = eval {
      $whitelist = Mail::SpamAssassin::AutoWhitelist->new($self->{main});

      # check
      my $meanscore = $whitelist->check_address($_, $origip);
      my $delta = 0;

      dbg("AWL active, pre-score: ".$self->{hits}.", mean: ".($meanscore||'undef').
                          ", originating-ip: ".($origip||'undef'));

      if(defined($meanscore))
      {
          $delta = ($meanscore - $self->{hits}) * $self->{main}->{conf}->{auto_whitelist_factor};
	  $self->{tag_data}->{AWL} = sprintf("%2.1f",$delta);
	  # Save this for _AWL_ tag
      }

      # Update the AWL *before* adding the new score, otherwise
      # early high-scoring messages are reinforced compared to
      # later ones.  See
      # http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=159704
      #
      if (!$self->{disable_auto_learning}) {
        $whitelist->add_score($self->{hits});
      }

      # current AWL score changes with each hit
      for my $set (0..3) {
	$self->{conf}->{scoreset}->[$set]->{"AWL"} = sprintf("%0.3f", $delta);
      }

      if ($delta != 0) {
	$self->_handle_hit("AWL",$delta,"AWL: ","Auto-whitelist adjustment");
      }

      dbg("Post AWL score: ".$self->{hits});
      $whitelist->finish();
      1;
    };

    if (!$evalok) {
      dbg ("open of AWL file failed: $@");
      # try an unlock, in case we got that far
      eval { $whitelist->finish(); };
    }
}

###########################################################################

sub do_meta_tests {
  my ($self) = @_;
  local ($_);

  dbg( "running meta tests; score so far=" . $self->{hits} );

  my $doing_user_rules = 
    $self->{conf}->{user_rules_to_compile}->{Mail::SpamAssassin::Conf::TYPE_META_TESTS};

  # speedup code provided by Matt Sergeant
  if ( defined &Mail::SpamAssassin::PerMsgStatus::_meta_tests && !$doing_user_rules) {
    Mail::SpamAssassin::PerMsgStatus::_meta_tests($self);
    return;
  }

  my ( %rule_deps, %setup_rules, %meta, $rulename );
  my $evalstr = '';

  # Get the list of meta tests
  my @metas = keys %{ $self->{conf}{meta_tests} };

  # Go through each rule and figure out what we need to do
  foreach $rulename (@metas) {
    my $rule   = $self->{conf}->{meta_tests}->{$rulename};
    my @tokens =
      $rule =~ m/([\w\.\[][\w\.\*\?\+\[\^\]]+|[\(\)]|\|\||\&\&|>=?|<=?|==|!=|!|[\+\-\*\/]|\d+)/g;
    my $token;

    # Set the rule blank to start
    $meta{$rulename} = "";

    # By default, there are no dependencies for a rule
    @{ $rule_deps{$rulename} } = ();

    # Go through each token in the meta rule
    foreach $token (@tokens) {

      # Numbers can't be rule names
      if ( $token =~ /^(?:\W+|\d+)$/ ) {
        $meta{$rulename} .= "$token ";
      }
      else {
        $meta{$rulename} .= "\$self->{'tests_already_hit'}->{'$token'} ";
	$setup_rules{$token}=1;

	# If the token is another meta rule, add it as a dependency
        push ( @{ $rule_deps{$rulename} }, $token )
          if ( exists $self->{conf}{meta_tests}->{$token} );
      }
    }
  }

  # avoid "undefined" warnings by providing a default value for needed rules
  $evalstr .= join("\n", (map { "\$self->{'tests_already_hit'}->{'$_'} ||= 0;" } keys %setup_rules), "");

  # Sort by length of dependencies list.  It's more likely we'll get
  # the dependencies worked out this way.
  @metas = sort { @{ $rule_deps{$a} } <=> @{ $rule_deps{$b} } } @metas;

  my $count;

  # Now go ahead and setup the eval string
  do {
    $count = $#metas;
    my %metas = map { $_ => 1 } @metas; # keep a small cache for fast lookups

    # Go through each meta rule we haven't done yet
    for ( my $i = 0 ; $i <= $#metas ; $i++ ) {

      # If we depend on meta rules that haven't run yet, skip it
      next if ( grep( $metas{$_}, @{ $rule_deps{ $metas[$i] } } ) );

      # Add this meta rule to the eval line
      $evalstr .= '  if ('.$meta{$metas[$i]}.') { $self->got_hit (q#'.$metas[$i].'#, ""); }'."\n";
      splice @metas, $i--, 1;    # remove this rule from our list
    }
  } while ( $#metas != $count && $#metas > -1 ); # run until we can't go anymore

  # If there are any rules left, we can't solve the dependencies so complain
  my %metas = map { $_ => 1 } @metas; # keep a small cache for fast lookups
  foreach $rulename (@metas) {
    dbg( "Excluding meta test $rulename; unsolved meta dependencies: "
        . join ( ", ", grep($metas{$_},@{ $rule_deps{$rulename} }) ) );
  }

  if (defined &_meta_tests) { undef &_meta_tests; }

  # setup the environment for meta tests
  $evalstr = <<"EOT";
{
    package Mail::SpamAssassin::PerMsgStatus;

    sub _meta_tests {
        # note: cannot set \$^W here on perl 5.6.1 at least, it
        # crashes meta tests.

        my (\$self) = \@_;

        $evalstr;
    }

    1;
}
EOT

  eval $evalstr;

  if ($@) {
    warn "Failed to run header SpamAssassin tests, skipping some: $@\n";
    $self->{rule_errors}++;
  }
  else {
    Mail::SpamAssassin::PerMsgStatus::_meta_tests($self);
  }
}    # do_meta_tests()

###########################################################################

sub run_eval_tests {
  my ($self, $evalhash, $prepend2desc, @extraevalargs) = @_;
  local ($_);
  
  my $debugenabled = $Mail::SpamAssassin::DEBUG->{enabled};

  my $scoreset = $self->{conf}->get_score_set();
  while (my ($rulename, $test) = each %{$evalhash}) {
    # Score of 0, skip it.
    next unless ($self->{conf}->{scores}->{$rulename});

    # If the rule is a net rule, and we're in a non-net enabled scoreset, skip it.
    next if (exists $self->{conf}->{tflags}->{$rulename} &&
      (($scoreset & 1) == 0) && $self->{conf}->{tflags}->{$rulename} =~ /\bnet\b/);

    # If the rule is a learn rule, and we're in a non-learn enabled scoreset, skip it.
    next if (exists $self->{conf}->{tflags}->{$rulename} &&
      (($scoreset & 2) == 0) && $self->{conf}->{tflags}->{$rulename} =~ /\blearn\b/);

    my $score = $self->{conf}{scores}{$rulename};
    my $result;

    $self->{test_log_msgs} = ();	# clear test state

    my ($function, @args) = @{$test};
    unshift(@args, @extraevalargs);

    eval {
      $result = $self->$function(@args);
    };

    if ($@) {
      warn "Failed to run $rulename SpamAssassin test, skipping:\n".
      		"\t($@)\n";
      $self->{rule_errors}++;
      next;
    }

    if ($result) {
	$self->got_hit ($rulename, $prepend2desc);
	dbg("Ran run_eval_test rule $rulename ======> got hit", "rulesrun", 32) if $debugenabled;
    } else {
        #dbg("Ran run_eval_test rule $rulename but did not get hit", "rulesrun", 32) if $debugenabled;
    }
  }
}

###########################################################################

sub run_rbl_eval_tests {
  my ($self, $evalhash) = @_;
  my ($rulename, $pat, @args);
  local ($_);

# CPU2006 -- just to be sure
return 0;

  if ($self->{main}->{local_tests_only}) {
    dbg ("local tests only, ignoring RBL eval", "rulesrun", 32);
    return 0;
  }
  
  my $debugenabled = $Mail::SpamAssassin::DEBUG->{enabled};

  while (my ($rulename, $test) = each %{$evalhash}) {
    my $score = $self->{conf}->{scores}->{$rulename};
    next unless $score;

    $self->{test_log_msgs} = ();	# clear test state

    my ($function, @args) = @{$test};

    my $result;
    eval {
       $result = $self->$function($rulename, @args);
    };

    if ($@) {
      warn "Failed to run $rulename RBL SpamAssassin test, skipping:\n".
		"\t($@)\n";
      $self->{rule_errors}++;
      next;
    }
  }
}

###########################################################################

sub got_body_pattern_hit {
  my ($self, $rulename) = @_;

  # only allow each test to hit once per mail
  return if (defined $self->{tests_already_hit}->{$rulename});

  $self->got_hit ($rulename, 'BODY: ');
}

sub got_uri_pattern_hit {
  my ($self, $rulename) = @_;

  # only allow each test to hit once per mail
  # TODO: Move this into the rule matcher
  return if (defined $self->{tests_already_hit}->{$rulename});

  $self->got_hit ($rulename, 'URI: ');
}

###########################################################################

# note: only eval tests should store state in $self->{test_log_msgs};
# pattern tests do not.
#
# the clearing of the test state is now inlined as:
#
# $self->{test_log_msgs} = ();	# clear test state

sub _handle_hit {
    my ($self, $rule, $score, $area, $desc) = @_;

    # ignore meta-match sub-rules.
    if ($rule =~ /^__/) { push(@{$self->{subtest_names_hit}}, $rule); return; }

    my $tflags = $self->{conf}->{tflags}->{$rule}; $tflags ||= '';

    # ignore 'learn' or 'userconf' rules, when considering score for
    # Bayesian auto-learning
    if ($tflags =~ /\b(?:learn|userconf)\b/i) {
      $self->{learned_hits} += $score;
    }
    else {
      $self->{hits} += $score;
      if (!$self->{conf}->maybe_header_only ($rule)) {
	$self->{body_only_hits} += $score;
      }
      if (!$self->{conf}->maybe_body_only ($rule)) {
	$self->{head_only_hits} += $score;
      }
    }

    push(@{$self->{test_names_hit}}, $rule);
    $area ||= '';

# CPU2006
#    if ($score >= 10 || $score <= -10) {
#      $score = sprintf("%4.0f", $score);
#    }
#    else {
#      $score = sprintf("%4.1f", $score);
#    }
    $score = sprintf("%4d", $score);

    # save both summaries
    $self->{tag_data}->{REPORT} .= sprintf ("* %s %s %s%s\n%s",
				       $score, $rule, $area, $desc,
				       ($self->{test_log_msgs}->{TERSE} ?
				        "*      " . $self->{test_log_msgs}->{TERSE} : '')
				   );
    $self->{tag_data}->{SUMMARY} .= sprintf ("%s %-22s %s%s\n%s",
				       $score, $rule, $area, $desc,
				       ($self->{test_log_msgs}->{LONG} || ''));
    $self->{test_log_msgs} = ();	# clear test logs
}

sub handle_hit {
  my ($self, $rule, $area, $deffallbackdesc) = @_;

  my $desc = $self->{conf}->{descriptions}->{$rule};
  $desc ||= $deffallbackdesc;
  $desc ||= $rule;

  my $score = $self->{conf}->{scores}->{$rule};

  $self->_handle_hit($rule, $score, $area, $desc);
}

sub got_hit {
  my ($self, $rule, $prepend2desc) = @_;

  $self->{tests_already_hit}->{$rule} = 1;

  my $txt = $self->{conf}->{full_tests}->{$rule};
  $txt ||= $self->{conf}->{full_evals}->{$rule};
  $txt ||= $self->{conf}->{head_tests}->{$rule};
  $txt ||= $self->{conf}->{body_tests}->{$rule};
  $self->handle_hit ($rule, $prepend2desc, $txt);
}

sub test_log {
  my ($self, $msg) = @_;
  while ($msg =~ s/^(.{30,48})\s//) {
    $self->_test_log_line ($1);
  }
  $self->_test_log_line ($msg);
}

sub _test_log_line {
  my ($self, $msg) = @_;

  $self->{test_log_msgs}->{TERSE} .= sprintf ("[%s]\n", $msg);
  if (length($msg) > 47) {
    $self->{test_log_msgs}->{LONG} .= sprintf ("%78s\n", "[$msg]");
  } else {
    $self->{test_log_msgs}->{LONG} .= sprintf ("%27s [%s]\n", "", $msg);
  }
}

###########################################################################
# Rather than add a requirement for MIME::Base64, use a slower but
# built-in base64 decode mechanism.
#
# original credit for this code:
# b64decode -- decode a raw BASE64 message
# A P Barrett <barrett@ee.und.ac.za>, October 1993
# Minor mods by jm@jmason.org for spamassassin and "use strict"

sub slow_base64_decode {
  my $self = shift;
  local $_ = shift;

  $base64alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
		    'abcdefghijklmnopqrstuvwxyz'.
		    '0123456789+/'; # and '='

  my $leftover = '';

  # ignore illegal characters
  s/[^$base64alphabet]//go;
  # insert the leftover stuff from last time
  $_ = $leftover . $_;
  # if there are not a multiple of 4 bytes, keep the leftovers for later
  m/^((?:....)*)(.*)/ ; $_ = $1 ; $leftover = $2 ;
  # turn each group of 4 values into 3 bytes
  s/(....)/&b64decodesub($1)/eg;
  # special processing at EOF for last few bytes
  if (eof) {
      $_ .= &b64decodesub($leftover); $leftover = '';
  }
  # output it
  return $_;
}

# b64decodesub -- takes some characters in the base64 alphabet and
# returns the raw bytes that they represent.
sub b64decodesub
{
  local ($_) = $_[0];
	   
  # translate each char to a value in the range 0 to 63
  eval qq{ tr!$base64alphabet!\0-\77!; };
  # keep 6 bits out of every 8, and pack them together
  $_ = unpack('B*', $_); # look at the bits
  s/(..)(......)/$2/g;   # keep 6 bits of every 8
  s/((........)*)(.*)/$1/; # throw away spare bits (not multiple of 8)
  $_ = pack('B*', $_);   # turn the bits back into bytes
  $_; # return
}

# contributed by Matt: a wrapper for slow_base64_decode() which uses
# MIME::Base64 if it's installed.
sub generic_base64_decode {
    my ($self, $to_decode) = @_;

    $to_decode =~ s/\r//;
    if (HAS_MIME_BASE64) {
	my $retval;
        # base64 decoding can produce cruddy warnings we don't care
        # about.  suppress them here.
        my $prevwarn = $SIG{__WARN__}; local $SIG{__WARN__} = sub { };

        $retval = MIME::Base64::decode_base64($to_decode);
        $SIG{__WARN__} = $prevwarn;
        return $retval;
    }
    else {
        return $self->slow_base64_decode($to_decode);
    }
}

###########################################################################

sub dbg { Mail::SpamAssassin::dbg (@_); }
sub sa_die { Mail::SpamAssassin::sa_die (@_); }

###########################################################################

sub clean_spamassassin_headers {
  my ($self) = @_;

  # attempt to restore original headers
  for my $hdr (('Content-Transfer-Encoding', 'Content-Type', 'Return-Receipt-To')) {
    my $prev = $self->{msg}->get_header ("X-Spam-Prev-$hdr");
    if (defined $prev && $prev ne '') {
      $self->{msg}->replace_header ($hdr, $prev);
    }
  }
  # delete the SpamAssassin-added headers
  $self->{msg}->delete_header ("X-Spam-Checker-Version");
  $self->{msg}->delete_header ("X-Spam-Flag");
  $self->{msg}->delete_header ("X-Spam-Level");
  $self->{msg}->delete_header ("X-Spam-Prev-Content-Transfer-Encoding");
  $self->{msg}->delete_header ("X-Spam-Prev-Content-Type");
  $self->{msg}->delete_header ("X-Spam-Report");
  $self->{msg}->delete_header ("X-Spam-Status");
  foreach my $header (keys %{$self->{conf}->{headers_spam}} ) {
    $self->{msg}->delete_header ("X-Spam-$header");
  }
  foreach my $header (keys %{$self->{conf}->{headers_ham}} ) {
    $self->{msg}->delete_header ("X-Spam-$header");
  }
}

###########################################################################

# this is a lazily-written temporary file containing the full text
# of the message, for use with external programs like pyzor and
# dccproc, to avoid hangs due to buffering issues.   Methods that
# need this, should call $self->create_fulltext_tmpfile($fulltext)
# to retrieve the temporary filename; it will be created if it has
# not already been.
#
# (SpamAssassin3 note: we should use tmp files to hold the message
# for 3.0 anyway, as noted by Matt previously; this will then
# be obsolete.)
#
sub create_fulltext_tmpfile {
  my ($self, $fulltext) = @_;

# CPU2006 -- this shouldn't get called, but just in case...
return undef;

  if (defined $self->{fulltext_tmpfile}) {
    return $self->{fulltext_tmpfile};
  }

  my ($tmpf, $tmpfh) = secure_tmpfile();
  print $tmpfh $$fulltext;
  close $tmpfh;

  $self->{fulltext_tmpfile} = $tmpf;

  return $self->{fulltext_tmpfile};
}

sub delete_fulltext_tmpfile {
  my ($self) = @_;

# CPU2006 -- this shouldn't get called, but just in case...
return undef;

  if (defined $self->{fulltext_tmpfile}) {
    unlink $self->{fulltext_tmpfile};
    $self->{fulltext_tmpfile} = undef;
  }
}

use Fcntl;

# thanks to http://www2.picante.com:81/~gtaylor/autobuse/ for this
# code.
sub secure_tmpfile {
  my $tmpdir = File::Spec->tmpdir();
  if (!$tmpdir) {
    die "cannot write to a temporary directory! set TMP or TMPDIR in env";
  }

  $tmpdir = Mail::SpamAssassin::Util::untaint_file_path ($tmpdir);
  my $template = $tmpdir."/sa.$$.";

  my $reportfile;
  my $umask = 0;
  do {
      # we do not rely on the obscurity of this name for security...
      # we use a average-quality PRG since this is all we need
      my $suffix = join ('',
                         (0..9, 'A'..'Z','a'..'z')[rand 62,
                                                   rand 62,
                                                   rand 62,
                                                   rand 62,
                                                   rand 62,
                                                   rand 62]);
      $reportfile = $template . $suffix;

      # ...rather, we require O_EXCL|O_CREAT to guarantee us proper
      # ownership of our file; read the open(2) man page.
  } while (! sysopen (TMPFILE, $reportfile, O_WRONLY|O_CREAT|O_EXCL, 0600));
  umask $umask;

  return ($reportfile, \*TMPFILE);
}

###########################################################################

1;
__END__

=back

=head1 SEE ALSO

C<Mail::SpamAssassin>
C<spamassassin>

