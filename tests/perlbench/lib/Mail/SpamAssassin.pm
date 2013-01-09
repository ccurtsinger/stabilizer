=head1 NAME

Mail::SpamAssassin - Mail::Audit spam detector plugin

=head1 SYNOPSIS

  my $mail = Mail::SpamAssassin::NoMailAudit->new();

  my $spamtest = Mail::SpamAssassin->new();
  my $status = $spamtest->check ($mail);

  if ($status->is_spam ()) {
    $status->rewrite_mail ();
    $mail->accept("spamfolder");

  } else {
    $mail->accept();		# to default incoming mailbox
  }
  ...


=head1 DESCRIPTION

Mail::SpamAssassin is a module to identify spam using text analysis and several
internet-based realtime blacklists.

Using its rule base, it uses a wide range of heuristic tests on mail headers
and body text to identify "spam", also known as unsolicited commercial email.

Once identified, the mail can then be optionally tagged as spam for later
filtering using the user's own mail user-agent application.

This module also implements a Mail::Audit plugin, allowing SpamAssassin to be
used in a Mail::Audit filter.  If you wish to use a command-line filter tool,
try the C<spamassassin> or C<spamd> tools provided.

Note that, if you're using Mail::Audit, the constructor for the Mail::Audit
object must use the C<nomime> option, like so:

        my $ma = new Mail::Audit ( nomime => 1 );

SpamAssassin also includes support for reporting spam messages to collaborative
filtering databases, such as Vipul's Razor ( http://razor.sourceforge.net/ ).

=head1 METHODS

=over 4

=cut

package Mail::SpamAssassin;
use strict;
use bytes;

# We do our best to make SA run with any Perl downto 5.005. You might want to
# read <http://www.perldoc.com/perl5.8.0/pod/perl56delta.html> if you plan to
# hack SA and are used to Perl 5.6+.
use 5.005;

use Mail::SpamAssassin::Conf;
# No SQL in CPU2006
#use Mail::SpamAssassin::ConfSourceSQL;
use Mail::SpamAssassin::PerMsgStatus;
use Mail::SpamAssassin::NoMailAudit;
use Mail::SpamAssassin::Bayes;

use File::Basename;
use File::Path;
use File::Spec 0.8;
use File::Copy;
use Cwd;
use Config;

# Load Time::HiRes if it's available
BEGIN {
# CPU2006 -- Time::HiRes is not available
#  eval { require Time::HiRes };
  eval { die };
  Time::HiRes->import( qw(time) ) unless $@;
}


use vars qw{
  @ISA $VERSION $SUB_VERSION @EXTRA_VERSION $IS_DEVEL_BUILD $HOME_URL
  $DEBUG
  @default_rules_path @default_prefs_path
  @default_userprefs_path @default_userstate_dir
  @site_rules_path
};

$VERSION = "2.61";              # update after release
#$IS_DEVEL_BUILD = 1;            # change for release versions

@ISA = qw();

# SUB_VERSION is now <revision>-<yyyy>-<mm>-<dd>-<state>
$SUB_VERSION = lc(join('-', (split(/[ \/]/, '$Id: SpamAssassin.pm,v 1.212.2.1 2003/12/09 06:30:29 jmason Exp $'))[2 .. 5, 8]));

# If you hacked up your SA, add a token to identify it here. Eg.: I use
# "mss<number>", <number> increasing with every hack.
@EXTRA_VERSION = qw();

if (defined $IS_DEVEL_BUILD && $IS_DEVEL_BUILD) {
  push(@EXTRA_VERSION, 'cvs');
}

sub Version { join('-', $VERSION, @EXTRA_VERSION) }

$HOME_URL = "http://www.spec.org/cpu2006/";

# note that the CWD takes priority.  This is required in case a user
# is testing a new version of SpamAssassin on a machine with an older
# version installed.  Unless you can come up with a fix for this that
# allows "make test" to work, don't change this.
@default_rules_path = (
	'./rules',
);

# first 3 are BSDish, latter 2 Linuxish
@site_rules_path = (
	'./rules',
);

@default_prefs_path = (
	'./rules',
);

@default_userprefs_path = (
        './spamassassin/user_prefs',
);

@default_userstate_dir = (
        './spamassassin',
);

###########################################################################

=item $f = new Mail::SpamAssassin( [ { opt => val, ... } ] )

Constructs a new C<Mail::SpamAssassin> object.  You may pass the
following attribute-value pairs to the constructor.

=over 4

=item rules_filename

The filename to load spam-identifying rules from. (optional)

=item site_rules_filename

The filename to load site-specific spam-identifying rules from. (optional)

=item userprefs_filename

The filename to load preferences from. (optional)

=item userstate_dir

The directory user state is stored in. (optional)

=item config_text

The text of all rules and preferences.  If you prefer not to load the rules
from files, read them in yourself and set this instead.  As a result, this will
override the settings for C<rules_filename>, C<site_rules_filename>,
and C<userprefs_filename>.

=item languages_filename

If you want to be able to use the language-guessing rule
C<UNWANTED_LANGUAGE_BODY>, and are using C<config_text> instead of
C<rules_filename>, C<site_rules_filename>, and C<userprefs_filename>, you will
need to set this.  It should be the path to the B<languages> file normally
found in the SpamAssassin B<rules> directory.

=item local_tests_only

If set to 1, no tests that require internet access will be performed. (default:
0)

=item dont_copy_prefs

If set to 1, the user preferences file will not be created if it doesn't
already exist. (default: 0)

=item save_pattern_hits

If set to 1, the patterns hit can be retrieved from the
C<Mail::SpamAssassin::PerMsgStatus> object.  Used for debugging.

=item home_dir_for_helpers

If set, the B<HOME> environment variable will be set to this value
when using test applications that require their configuration data,
such as Razor, Pyzor and DCC.

=item username

If set, the C<username> attribute will use this as the current user's name.
Otherwise, the default is taken from the runtime environment (ie. this process'
effective UID under UNIX).

=back

If none of C<rules_filename>, C<site_rules_filename>, C<userprefs_filename>, or
C<config_text> is set, the C<Mail::SpamAssassin> module will search for the
configuration files in the usual installed locations.

=cut

sub new {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = shift;
  if (!defined $self) { $self = { }; }
  bless ($self, $class);

  $DEBUG->{enabled} = 0;
  if (defined $self->{debug} && $self->{debug} > 0) { $DEBUG->{enabled} = 1; }

  # if the libs are installed in an alternate location, and the caller
  # didn't set PREFIX, we should have an estimated guess ready ...
  $self->{PREFIX} ||= '@@PREFIX@@';  # substituted at 'make' time

  # This should be moved elsewhere, I know, but SA really needs debug sets 
  # I'm putting the intialization here for now, move it if you want

  # For each part of the code, you can set debug levels. If the level is
  # progressive, use negative numbers (the more negative, the move debug info
  # is put out), and if you want to use bit fields, use positive numbers
  # All code path debug codes should be listed here with a value of 0 if you
  # want them disabled -- Marc

  $DEBUG->{datediff}=-1;
  $DEBUG->{razor}=0;
  $DEBUG->{dcc}=0;
  $DEBUG->{pyzor}=0;
  $DEBUG->{rbl}=0;
  $DEBUG->{dnsavailable}=0;
  $DEBUG->{bayes}=-1;
  # Bitfield:
  # header regex: 1 | body-text: 2 | uri tests: 4 | raw-body-text: 8
  # full-text regexp: 16 | run_eval_tests: 32 | run_rbl_eval_tests: 64
  $DEBUG->{rulesrun}=63;

  $self->{conf} ||= new Mail::SpamAssassin::Conf ($self);

  $self->{save_pattern_hits} ||= 0;

  # Make sure that we clean $PATH if we're tainted
  Mail::SpamAssassin::Util::clean_path_in_taint_mode();

# CPU2006 -- no locking; it's all serial
use Mail::SpamAssassin::NoLocker;
#  # this could probably be made a little faster; for now I'm going
#  # for slow but safe, by keeping in quotes
#  if (Mail::SpamAssassin::Util::am_running_on_windows()) {
#    eval '
#      use Mail::SpamAssassin::Win32Locker;
#      $self->{locker} = new Mail::SpamAssassin::Win32Locker ($self);
#    '; ($@) and die $@;
#  } else {
#    eval '
#      use Mail::SpamAssassin::UnixLocker;
#      $self->{locker} = new Mail::SpamAssassin::UnixLocker ($self);
#    '; ($@) and die $@;
#  }

  $self->{encapsulated_content_description} = 'original message before SpamAssassin';

  if (!defined $self->{username}) {
    $self->{username} = (Mail::SpamAssassin::Util::portable_getpwuid ($>))[0];
  }

  $self;
}

###########################################################################

=item $f->trim_rules ($regexp)

Remove all rules that don't match the given regexp (or are sub-rules of
meta-tests that match the regexp).

=cut

my @rule_types = ("body_tests", "uri_tests", "uri_evals",
                  "head_tests", "head_evals", "body_evals", "full_tests",
                  "full_evals", "rawbody_tests", "rawbody_evals",
                  "meta_tests");

sub trim_rules {
  my ($self, $regexp) = @_;

  my @all_rules;

  foreach my $rule_type (@rule_types) {
    push(@all_rules, keys(%{$self->{conf}->{$rule_type}}));
  }

  my @rules_to_keep = grep(/$regexp/, @all_rules);

  if (@rules_to_keep == 0) {
    die "trim_rules(): All rules excluded, nothing to test.\n";
  }

  my @meta_tests    = grep(/$regexp/, keys(%{$self->{conf}->{meta_tests}}));
  foreach my $meta (@meta_tests) {
    push(@rules_to_keep, add_meta_depends($self->{conf}, $meta))
  }

  my %rules_to_keep_hash = ();

  foreach my $rule (@rules_to_keep) {
    $rules_to_keep_hash{$rule} = 1;
  }

  foreach my $rule_type (@rule_types) {
    foreach my $rule (keys(%{$self->{conf}->{$rule_type}})) {
      delete $self->{conf}->{$rule_type}->{$rule}
        if (!$rules_to_keep_hash{$rule});
    }
  }
} # trim_rules()

sub add_meta_depends {
  my ($conf, $meta) = @_;

  my @rules = ();

  my @tokens = $conf->{meta_tests}->{$meta} =~ m/(\w+)/g;

  @tokens = grep(!/^\d+$/, @tokens);
  # @tokens now only consists of sub-rules

  foreach my $token (@tokens) {
    push(@rules, $token);

    # If the sub-rule is a meta-test, recurse
    if ($conf->{meta_tests}->{$token}) {
      push(@rules, add_meta_depends($conf, $token));
    }
  } # foreach my $token (@tokens)

  return @rules;
} # add_meta_depends()

###########################################################################

=item $status = $f->check ($mail)

Check a mail, encapsulated in a C<Mail::Audit> or
C<Mail::SpamAssassin::Message> object, to determine if it is spam or not.

Returns a C<Mail::SpamAssassin::PerMsgStatus> object which can be
used to test or manipulate the mail message.

Note that the C<Mail::SpamAssassin> object can be re-used for further messages
without affecting this check; in OO terminology, the C<Mail::SpamAssassin>
object is a "factory".   However, if you do this, be sure to call the
C<finish()> method on the status objects when you're done with them.

=cut

sub check {
  my ($self, $mail_obj) = @_;
  local ($_);

  $self->init(1);
  my $mail = $self->encapsulate_mail_object ($mail_obj);
  my $msg = Mail::SpamAssassin::PerMsgStatus->new($self, $mail);
  # Message-Id is used for a filename on disk, so we can't have '/' in it.
  $msg->check();
  $msg;
}

###########################################################################

=item $status = $f->learn ($mail, $id, $isspam, $forget)

Learn from a mail, encapsulated in a C<Mail::Audit> or
C<Mail::SpamAssassin::Message> object.

If C<$isspam> is set, the mail is assumed to be spam, otherwise it will
be learnt as non-spam.

If C<$forget> is set, the attributes of the mail will be removed from
both the non-spam and spam learning databases.

C<$id> is an optional message-identification string, used internally
to tag the message.  If it is C<undef>, the Message-Id of the message
will be used.  It should be unique to that message.

Returns a C<Mail::SpamAssassin::PerMsgLearner> object which can be used to
manipulate the learning process for each mail.

Note that the C<Mail::SpamAssassin> object can be re-used for further messages
without affecting this check; in OO terminology, the C<Mail::SpamAssassin>
object is a "factory".   However, if you do this, be sure to call the
C<finish()> method on the learner objects when you're done with them.

C<learn()> and C<check()> can be run using the same factory.  C<init_learner()>
must be called before using this method.

=cut

sub learn {
  my ($self, $mail_obj, $id, $isspam, $forget) = @_;
  local ($_);

  require Mail::SpamAssassin::PerMsgLearner;
  $self->init(1);
  my $mail = $self->encapsulate_mail_object ($mail_obj);
  my $msg = Mail::SpamAssassin::PerMsgLearner->new($self, $mail);

  if ($forget) {
    $msg->forget($id);
  } elsif ($isspam) {
    dbg("Learning Spam");
    $msg->learn_spam($id);
  } else {
    dbg("Learning Ham");
    $msg->learn_ham($id);
  }

  $msg;
}

###########################################################################

=item $f->init_learner ( [ { opt => val, ... } ] )

Initialise learning.  You may pass the following attribute-value pairs to this
method.

=over 4

=item caller_will_untie

Whether or not the code calling this method will take care of untie'ing
from the Bayes databases (by calling C<finish_learner()>) (optional, default 0).

=item force_expire

Should an expiration run be forced to occur immediately? (optional, default 0).

=item learn_to_journal

Should learning data be written to the journal, instead of directly to the
databases? (optional, default 0).

=item wait_for_lock

Whether or not to wait a long time for locks to complete (optional, default 0).

=back

=cut

sub init_learner {
  my $self = shift;
  my $opts = shift;
  dbg ("Initialising learner");
  if (defined $opts->{force_expire}) { $self->{learn_force_expire} = $opts->{force_expire}; }
  if (defined $opts->{learn_to_journal}) { $self->{learn_to_journal} = $opts->{learn_to_journal}; }
  if (defined $opts->{caller_will_untie}) { $self->{learn_caller_will_untie} = $opts->{caller_will_untie}; }
  if (defined $opts->{wait_for_lock}) { $self->{learn_wait_for_lock} = $opts->{wait_for_lock}; }
  1;
}

###########################################################################

=item $f->rebuild_learner_caches ({ opt => val })

Rebuild any cache databases; should be called after the learning process.
Options include: C<verbose>, which will output diagnostics to C<stdout>
if set to 1.

=cut

sub rebuild_learner_caches {
  my $self = shift;
  my $opts = shift;
  $self->{bayes_scanner}->sync(1,1,$opts);
  1;
}

=item $f->finish_learner ()

Finish learning.

=cut

sub finish_learner {
  my $self = shift;
  $self->{bayes_scanner}->finish();
  1;
}

=item $f->dump_bayes_db()

Dump the contents of the Bayes DB

=cut

sub dump_bayes_db {
  my($self,@opts) = @_;
  $self->{bayes_scanner}->dump_bayes_db(@opts);
  1;
}

=item $f->signal_user_changed ( [ { opt => val, ... } ] )

Signals that the current user has changed (possibly using C<setuid>), meaning
that SpamAssassin should close any per-user databases it has open, and re-open
using ones appropriate for the new user.

Note that this should be called I<after> reading any per-user configuration, as
that data may override some paths opened in this method.  You may pass the
following attribute-value pairs:

=over 4

=item username

The username of the user.  This will be used for the C<username> attribute.

=item user_dir

A directory to use as a 'home directory' for the current user's data,
overriding the system default.  This directory must be readable and writable by
the process.

=back

=cut

sub signal_user_changed {
  my $self = shift;
  my $opts = shift;
  my $set = 0;

  dbg ("user has changed");

  if (defined $opts && $opts->{username}) {
    $self->{username} = $opts->{username};
  }
  if (defined $opts && $opts->{user_dir}) {
    $self->{user_dir} = $opts->{user_dir};
  }

  # reopen bayes dbs for this user
  $self->{bayes_scanner}->finish();
  $self->{bayes_scanner} = new Mail::SpamAssassin::Bayes ($self);

  $set |= 1 unless $self->{local_tests_only};
  $set |= 2 if $self->{bayes_scanner}->is_scan_available();

  $self->{conf}->set_score_set ($set);

  1;
}

###########################################################################

=item $status = $f->check_message_text ($mailtext)

Check a mail, encapsulated in a plain string, to determine if it is spam or
not.

Otherwise identical to C<$f->check()> above.

=cut

sub check_message_text {
  my $self = shift;
  my @lines = split (/^/m, $_[0]);
  my $mail_obj = Mail::SpamAssassin::NoMailAudit->new ('data' => \@lines);
  return $self->check ($mail_obj);
}

###########################################################################

=item $f->report_as_spam ($mail, $options)

Report a mail, encapsulated in a C<Mail::Audit> object, as human-verified spam.
This will submit the mail message to live, collaborative, spam-blocker
databases, allowing other users to block this message.

It will also submit the mail to SpamAssassin's Bayesian learner.

Options is an optional reference to a hash of options.  Currently these
can be:

=over 4

=item dont_report_to_razor

Inhibits reporting of the spam to Razor; useful if you know it's already
been listed there.

=item dont_report_to_dcc

Inhibits reporting of the spam to DCC; useful if you know it's already
been listed there.

=item dont_report_to_pyzor

Inhibits reporting of the spam to Pyzor; useful if you know it's already
been listed there.

=back

=cut

sub report_as_spam {
  my ($self, $mail, $options) = @_;
  local ($_);

  $self->init(1);

  $mail = $self->encapsulate_mail_object ($mail);

  # learn as spam if enabled
  if ( $self->{conf}->{bayes_learn_during_report} ) {
    $self->learn ($mail, undef, 1, 0);
  }

  # Reporting is disabled for use with CPU2006
  #require Mail::SpamAssassin::Reporter;
  #$mail = Mail::SpamAssassin::Reporter->new($self, $mail, $options);
  #$mail->report ();
}

###########################################################################

=item $f->revoke_as_spam ($mail, $options)

Revoke a mail, encapsulated in a C<Mail::Audit> object, as human-verified ham
(non-spam).  This will revoke the mail message from live, collaborative,
spam-blocker databases, allowing other users to block this message.

It will also submit the mail to SpamAssassin's Bayesian learner as nonspam.

Options is an optional reference to a hash of options.  Currently these
can be:

=over 4

=item dont_report_to_razor

Inhibits revoking of the spam to Razor.


=back

=cut

sub revoke_as_spam {
  my ($self, $mail, $options) = @_;
  local ($_);

  $self->init(1);

  $mail = $self->encapsulate_mail_object ($mail);

  # learn as nonspam
  $self->learn ($mail, undef, 0, 0);

  require Mail::SpamAssassin::Reporter;
  $mail = Mail::SpamAssassin::Reporter->new($self, $mail, $options);
  $mail->revoke ();
}

###########################################################################

=item $f->add_address_to_whitelist ($addr)

Given a string containing an email address, add it to the automatic
whitelist database.

=cut

sub add_address_to_whitelist {
  my ($self, $addr) = @_;
  my $list = Mail::SpamAssassin::AutoWhitelist->new($self);
  if ($list->add_known_good_address ($addr)) {
    print "SpamAssassin auto-whitelist: adding address: $addr\n";
  }
  $list->finish();
}

=item $f->add_all_addresses_to_whitelist ($mail)

Given a mail message, find as many addresses in the usual headers (To, Cc, From
etc.), and the message body, and add them to the automatic whitelist database.

=cut

sub add_all_addresses_to_whitelist {
  my ($self, $mail_obj) = @_;

  my $list = Mail::SpamAssassin::AutoWhitelist->new($self);
  foreach my $addr ($self->find_all_addrs_in_mail ($mail_obj)) {
    if ($list->add_known_good_address ($addr)) {
      print "SpamAssassin auto-whitelist: adding address: $addr\n";
    }
  }
  $list->finish();
}

###########################################################################

=item $f->remove_address_from_whitelist ($addr)

Given a string containing an email address, remove it from the automatic
whitelist database.

=cut

sub remove_address_from_whitelist {
  my ($self, $addr) = @_;
  my $list = Mail::SpamAssassin::AutoWhitelist->new($self);
  if ($list->remove_address ($addr)) {
    print "SpamAssassin auto-whitelist: removing address: $addr\n";
  }
  $list->finish();
}

=item $f->remove_all_addresses_from_whitelist ($mail)

Given a mail message, find as many addresses in the usual headers (To, Cc, From
etc.), and the message body, and remove them from the automatic whitelist
database.

=cut

sub remove_all_addresses_from_whitelist {
  my ($self, $mail_obj) = @_;

  my $list = Mail::SpamAssassin::AutoWhitelist->new($self);
  foreach my $addr ($self->find_all_addrs_in_mail ($mail_obj)) {
    if ($list->remove_address ($addr)) {
      print "SpamAssassin auto-whitelist: removing address: $addr\n";
    }
  }
  $list->finish();
}

###########################################################################

=item $f->add_address_to_blacklist ($addr)

Given a string containing an email address, add it to the automatic
whitelist database with a high score, effectively blacklisting them.

=cut

sub add_address_to_blacklist {
  my ($self, $addr) = @_;
  my $list = Mail::SpamAssassin::AutoWhitelist->new($self);
  if ($list->add_known_bad_address ($addr)) {
    print "SpamAssassin auto-whitelist: blacklisting address: $addr\n";
  }
  $list->finish();
}

=item $f->add_all_addresses_to_blacklist ($mail)

Given a mail message, find addresses in the From headers and add them to the
automatic whitelist database with a high score, effectively blacklisting them.

Note that To and Cc addresses are not used.

=cut

sub add_all_addresses_to_blacklist {
  my ($self, $mail_obj) = @_;

  my $list = Mail::SpamAssassin::AutoWhitelist->new($self);

  $self->init(1);
  my $mail = $self->encapsulate_mail_object ($mail_obj);

  my @addrlist = ();
  my @hdrs = $mail->get_header ('From');
  if ($#hdrs >= 0) {
    push (@addrlist, $self->find_all_addrs_in_line (join (" ", @hdrs)));
  }

  foreach my $addr (@addrlist) {
    if ($list->add_known_bad_address ($addr)) {
      print "SpamAssassin auto-whitelist: blacklisting address: $addr\n";
    }
  }

  $list->finish();
}

###########################################################################

=item $f->reply_with_warning ($mail, $replysender)

Reply to the sender of a mail, encapsulated in a C<Mail::Audit> object,
explaining that their message has been added to spam-tracking databases
and deleted.  To be used in conjunction with C<report_as_spam>.  The
C<$replysender> argument should contain an email address to use as the
sender of the reply message.

=cut

sub reply_with_warning {
  my ($self, $mail, $replysender) = @_;
  $self->init(1);
  $mail = $self->encapsulate_mail_object ($mail);

  # Replies are disabled for CPU2006
  #require Mail::SpamAssassin::Replier;
  #$mail = Mail::SpamAssassin::Replier->new ($self, $mail);
  #$mail->reply ($replysender);
}

###########################################################################

=item $text = $f->remove_spamassassin_markup ($mail)

Returns the text of the message, with any SpamAssassin-added text (such
as the report, or X-Spam-Status headers) stripped.

Note that the B<$mail> object is not modified.

=cut

sub remove_spamassassin_markup {
  my ($self, $mail_obj) = @_;
  local ($_);

  dbg("Removing Markup");
  $self->init(1);
  my $ct = $mail_obj->get_header("Content-Type") || '';
  if ( $ct
    && $ct =~ m!^\s*multipart/mixed;\s+boundary\s*=\s*["']?(.+?)["']?(?:;|$)!i )
  {

    # Ok, this is a possible encapsulated message, search for the
    # appropriate mime part and deal with it if necessary.
    my $boundary = "\Q$1\E";
    my @msg = split(/^/,$mail_obj->get_pristine());

    my $flag = 0;
    $ct   = '';
    my $cd = '';
    for ( my $i = 0 ; $i <= $#msg ; $i++ ) {
      next
        unless ( $msg[$i] =~ /^--$boundary$/ || $flag )
        ;    # only look at mime headers
      if ( $msg[$i] =~ /^\s*$/ ) {    # end of mime header

        # Ok, we found the encapsulated piece ...
	if ($ct =~ m@(?:message/rfc822|text/plain);\s+x-spam-type=original@ ||
	    ($ct eq "message/rfc822" &&
	     $cd eq $self->{'encapsulated_content_description'}))
        {
          splice @msg, 1, $i;
            ;    # remove the front part, leave the 'From ' header.
	  splice @msg, 0, 1 if ( $msg[0] !~ /^From / ); # not From?  remove it.
          # find the end and chop it off
          for ( $i = 0 ; $i <= $#msg ; $i++ ) {
            if ( $msg[$i] =~ /^--$boundary/ ) {
              splice @msg, ($msg[$i-1] =~ /\S/ ? $i : $i-1);
	      # will remove the blank line (not sure it'll always be
	      # there) and everything below.  don't worry, the splice
	      # guarantees the for will stop ...
            }
          }

	  # Ok, we're done.  Return the message.
	  return join('',@msg);
        }

        $flag = 0;
        $ct   = '';
        $cd   = '';
        next;
      }

      # Ok, we're in the mime header ...  Capture the appropriate headers...
      $flag = 1;
      if ( $msg[$i] =~ /^Content-Type:\s+(.+?)\s*$/i ) {
        $ct = $1;
      }
      elsif ( $msg[$i] =~ /^Content-Description:\s+(.+?)\s*$/i ) {
        $cd = $1;
      }
    }
  }

  my $mail = $self->encapsulate_mail_object ($mail_obj);
  my $hdrs = $mail->get_all_headers();

  # remove DOS line endings
  $hdrs =~ s/\r//gs;

  # de-break lines on SpamAssassin-modified headers.
  1 while $hdrs =~ s/(\n(?:X-Spam|Subject)[^\n]+?)\n[ \t]+/$1 /gs;

  # reinstate the old content type
  if ($hdrs =~ /^X-Spam-Prev-Content-Type: /m) {
    $hdrs =~ s/\nContent-Type: [^\n]*?\n/\n/gs;
    $hdrs =~ s/\nX-Spam-Prev-(Content-Type: [^\n]*\n)/\n$1/gs;

    # remove embedded spaces where they shouldn't be; a common problem
    $hdrs =~ s/(Content-Type: .*?boundary=\".*?) (.*?\".*?\n)/$1$2/gs;
  }

  # reinstate the old content transfer encoding
  if ($hdrs =~ /^X-Spam-Prev-Content-Transfer-Encoding: /m) {
    $hdrs =~ s/\nContent-Transfer-Encoding: [^\n]*?\n/\n/gs;
    $hdrs =~ s/\nX-Spam-Prev-(Content-Transfer-Encoding: [^\n]*\n)/\n$1/gs;
  }

  # reinstate the return-receipt-to header
  if ($hdrs =~ /^X-Spam-Prev-Return-Receipt-To: /m) {
    $hdrs =~ s/\nX-Spam-Prev-(Return-Receipt-To: [^\n]*\n)/\n$1/gs;
  }

  # remove the headers we added
  1 while $hdrs =~ s/\nX-Spam-[^\n]*?\n/\n/gs;

  my $tag = $self->{conf}->{subject_tag};

  while ( $tag =~ /(_HITS_|_REQD_)/g ) {
       my $typeoftag = $1;
       $hdrs =~ s/^Subject: (\D*)\d\d\.\d\d/Subject: $1$typeoftag/m;
  } # Wow. Very Hackish.

  1 while $hdrs =~ s/^Subject: \Q${tag}\E /Subject: /gm;

  # ok, next, the report.
  # This is a little tricky since we can have either 0, 1 or 2 reports;
  # 0 for the non-spam case, 1 for normal filtering, and 2 for -t (where
  # an extra report is appended at the end of the mail).

  my @newbody = ();
  my $inreport = 0;
  foreach $_ (@{$mail->get_body()})
  {
    s/\r?$//;	# DOS line endings

    if (/^SPAM: ----/ && $inreport == 0) {
      # we've just entered a report.  If there's a blank line before the
      # report, get rid of it...
      if ($#newbody > 0 && $newbody[$#newbody-1] =~ /^$/) {
	pop (@newbody);
      }
      # and skip on to the next line...
      $inreport = 1; next;
    }

    if ($inreport && /^$/) {
      # blank line at end of report; skip it.  Also note that we're
      # now out of the report.
      $inreport = 0; next;
    }

    # finally, if we're not in the report, add it to the body array
    if (!$inreport) {
      push (@newbody, $_);
    }
  }

  return $hdrs."\n".join ('', @newbody);
}

###########################################################################

=item $f->read_scoreonly_config ($filename)

Read a configuration file and parse only scores from it.  This is used
to safely allow multi-user daemons to read per-user config files
without having to use C<setuid()>.

=cut

sub read_scoreonly_config {
  my ($self, $filename) = @_;

  if (!open(IN,"<$filename")) {
    # the file may not exist; this should not be verbose
    dbg ("read_scoreonly_config: cannot open \"$filename\": $!");
    return;
  }
  my $text = join ('',<IN>);
  close IN;

  $self->{conf}->parse_scores_only ($text);
  if ($self->{conf}->{allow_user_rules}) {
      dbg("finishing parsing!");
      $self->{conf}->finish_parsing();
  }
}

# There is no SQL in CPU2006
############################################################################
#
#=item $f->load_scoreonly_sql ($username)
#
#Read configuration paramaters from SQL database and parse scores from it.  This
#will only take effect if the perl C<DBI> module is installed, and the
#configuration parameters C<user_scores_dsn>, C<user_scores_sql_username>, and
#C<user_scores_sql_password> are set correctly.
#
#The username in C<$username> will also be used for the C<username> attribute of
#the Mail::SpamAssassin object.
#
#=cut
#
#sub load_scoreonly_sql {
#  my ($self, $username) = @_;
#
#  my $src = Mail::SpamAssassin::ConfSourceSQL->new ($self);
#  $self->{username} = $username;
#  $src->load($username);
#}
#
#
###########################################################################

=item $f->set_persistent_address_list_factory ($factoryobj)

Set the persistent address list factory, used to create objects for the
automatic whitelist algorithm's persistent-storage back-end.  See
C<Mail::SpamAssassin::PersistentAddrList> for the API these factory objects
must implement, and the API the objects they produce must implement.

=cut

sub set_persistent_address_list_factory {
  my ($self, $fac) = @_;
  $self->{pers_addr_list_factory} = $fac;
}

###########################################################################

=item $f->compile_now ($use_user_prefs)

Compile all patterns, load all configuration files, and load all
possibly-required Perl modules.

Normally, Mail::SpamAssassin uses lazy evaluation where possible, but if you
plan to fork() or start a new perl interpreter thread to process a message,
this is suboptimal, as each process/thread will have to perform these actions.

Call this function in the master thread or process to perform the actions
straightaway, so that the sub-processes will not have to.

If C<$use_user_prefs> is 0, this will initialise the SpamAssassin
configuration without reading the per-user configuration file and it will
assume that you will call C<read_scoreonly_config> at a later point.

=cut

sub compile_now {
  my ($self, $use_user_prefs) = @_;

  # note: this may incur network access. Good.  We want to make sure
  # as much as possible is preloaded!
  my @testmsg = ("From: ignore\@compiling.spamassassin.taint.org\n", 
# CPU2006 -- do not let time slip past us even in this place where it will
#            never be output.  Vigilance is the watchword!
#    "Message-Id:  <".time."\@spamassassin_spamd_init>\n", "\n",
    "Message-Id:  <930315742\@spamassassin_spamd_init>\n", "\n",
    "I need to make this message body somewhat long so TextCat preloads\n"x20);

  dbg ("ignore: test message to precompile patterns and load modules");
  $self->init($use_user_prefs);

  my $mail = Mail::SpamAssassin::NoMailAudit->new(data => \@testmsg);
  my $encapped = $self->encapsulate_mail_object ($mail);
  my $status = Mail::SpamAssassin::PerMsgStatus->new($self, $encapped,
                        { disable_auto_learning => 1 } );
  $status->word_is_in_dictionary("aba"); # load triplets.txt into memory
  $status->check();
  $status->finish();

  # There is no SQL in CPU2006
#  # load SQL modules now as well
#  my $dsn = $self->{conf}->{user_scores_dsn};
#  if ($dsn ne '') {
#    Mail::SpamAssassin::ConfSourceSQL::load_modules();
#  }

  $self->{bayes_scanner}->sanity_check_is_untied();

  1;
}

###########################################################################

=item $failed = $f->lint_rules ()

Syntax-check the current set of rules.  Returns the number of 
syntax errors discovered, or 0 if the configuration is valid.

=cut

sub lint_rules {
  my ($self) = @_;

  dbg ("ignore: using a test message to lint rules");
  my @testmsg = ("From: ignore\@compiling.spamassassin.taint.org\n", 
    "Subject: \n",
# CPU2006 -- see above
#    "Message-Id:  <".CORE::time()."\@lint_rules>\n", "\n",
    "Message-Id:  <930315742\@lint_rules>\n", "\n",
    "I need to make this message body somewhat long so TextCat preloads\n"x20);

  $self->{lint_rules} = $self->{conf}->{lint_rules} = 1;
  $self->{syntax_errors} = 0;
  $self->{rule_errors} = 0;

  $self->init(1);
  $self->{syntax_errors} += $self->{conf}->{errors};

  my $mail = Mail::SpamAssassin::NoMailAudit->new(data => \@testmsg);
  my $encapped = $self->encapsulate_mail_object ($mail);
  my $status = Mail::SpamAssassin::PerMsgStatus->new($self, $encapped,
                        { disable_auto_learning => 1 } );
  $status->check();

  $self->{syntax_errors} += $status->{rule_errors};
  $status->finish();

  return ($self->{syntax_errors});
}

###########################################################################
# non-public methods.

sub init {
  my ($self, $use_user_pref) = @_;

  if (defined $self->{_initted}) {
    # seed PRNG whenever the process id changes
    if ($self->{_initted} != $$) {
      $self->{_initted} = $$;
      srand;
    }
    return;
  }

  $self->{_initted} = $$;

  #fix spamd reading root prefs file
  unless (defined $use_user_pref) {
    $use_user_pref = 1;
  }

  if (!defined $self->{config_text}) {
    $self->{config_text} = '';

    my $fname = $self->{rules_filename};
    $fname ||= $self->first_existing_path (@default_rules_path);
    if ($fname) {
      $self->{config_text} .= $self->read_cf ($fname, 'default rules dir');

      if (-f "$fname/languages") {
	$self->{languages_filename} = "$fname/languages";
      }
    }

    $fname = $self->{site_rules_filename};
    $fname ||= $self->first_existing_path (@site_rules_path);
    if ($fname) {
      $self->{config_text} .= $self->read_cf ($fname, 'site rules dir');
    }

    if ( $use_user_pref != 0 ) {
      $self->get_and_create_userstate_dir();

      # user prefs file
      $fname = $self->{userprefs_filename};
      $fname ||= $self->first_existing_path (@default_userprefs_path);

      if (defined $fname) {
        if (!-f $fname && !$self->{dont_copy_prefs} && !$self->create_default_prefs($fname)) {
          warn "Failed to create default user preference file $fname\n";
        }
      }

      $self->{config_text} .= $self->read_cf ($fname, 'user prefs file');
    }
  }

  if ($self->{config_text} !~ /\S/) {
    warn "No configuration text or files found! Please check your setup.\n";
  }

  $self->{conf}->parse_rules ($self->{config_text});
  $self->{conf}->finish_parsing ();

  delete $self->{config_text};

  $self->{bayes_scanner} = new Mail::SpamAssassin::Bayes ($self);

  my $set = 0;
  $set |= 1 unless $self->{local_tests_only};
  $set |= 2 if $self->{bayes_scanner}->is_scan_available();

  $self->{conf}->set_score_set ($set);

  $self->init_learner({ 'learn_to_journal' => $self->{conf}->{bayes_learn_to_journal} });

  if ($self->{only_these_rules}) {
    $self->trim_rules($self->{only_these_rules});
  }

  # TODO -- open DNS cache etc. if necessary
}

sub read_cf {
  my ($self, $path, $desc) = @_;

  return '' unless defined ($path);

  dbg ("using \"$path\" for $desc");
  my $txt = '';

  if (-d $path) {
    foreach my $file ($self->get_cf_files_in_dir ($path)) {
      open (IN, "<".$file) or warn "cannot open \"$file\": $!\n", next;
      $txt .= "file start $file\n";     # let Conf know
      $txt .= join ('', <IN>);
      # add an extra \n in case file did not end in one.
      $txt .= "\nfile end $file\n";     
      close IN;
    }

  } elsif (-f $path && -s _ && -r _) {
    open (IN, "<".$path) or warn "cannot open \"$path\": $!\n";
    $txt .= "file start $path\n";
    $txt = join ('', <IN>);
    $txt .= "file end $path\n";
    close IN;
  }

  return $txt;
}

sub get_and_create_userstate_dir {
  my ($self) = @_;

  # user state directory
  my $fname = $self->{userstate_dir};
  $fname ||= $self->first_existing_path (@default_userstate_dir);

  # If vpopmail is enabled then set fname to virtual homedir
  #
  if (defined $self->{user_dir}) {
    # Changed to non-hidden for CPU2006
    $fname = File::Spec->catdir ($self->{user_dir}, "spamassassin");
  }

  if (defined $fname && !$self->{dont_copy_prefs}) {
    dbg ("using \"$fname\" for user state dir");
  }

  if (!-d $fname) {
    # not being able to create the *dir* is not worth a warning at all times
    eval { mkpath ($fname, 0, 0700) } or dbg ("mkdir $fname failed: $@ $!\n");
  }
  $fname;
}

=item $f->create_default_prefs ($filename, $username [ , $userdir ] )

Copy default preferences file into home directory for later use and
modification, if it does not already exist and C<dont_copy_prefs> is
not set.

=cut

sub create_default_prefs {
  # $userdir will only exist if vpopmail config is enabled thru spamd
  # Its value will be the virtual user's maildir
  #
  my ($self, $fname, $user, $userdir) = @_;

  if ($self->{dont_copy_prefs}) {
    return(0);
  }

  if ($userdir && $userdir ne $self->{user_dir}) {
    warn "Oops! user_dirs don't match! '$userdir' vs '$self->{user_dir}'\n";
  }

  if (!-f $fname)
  {
    # Pass on the value of $userdir for virtual users in vpopmail
    # otherwise it is empty and the user's normal homedir is used
    $self->get_and_create_userstate_dir();

    # copy in the default one for later editing
    my $defprefs = $self->first_existing_path (@Mail::SpamAssassin::default_prefs_path);

    if (open (IN, "<$defprefs")) {
      $fname = Mail::SpamAssassin::Util::untaint_file_path($fname);
      if (open (OUT, ">$fname")) {
        while (<IN>) {
          /^\#\* / and next;
          print OUT;
        }
        close OUT;
        close IN;

        if (($< == 0) && ($> == 0) && defined($user)) { # chown it
          my ($uid,$gid) = (getpwnam($user))[2,3];
          unless (chown($uid, $gid, $fname)) {
            warn "Couldn't chown $fname to $uid:$gid for $user: $!\n";
          }
        }
        warn "Created user preferences file: $fname\n";
        return(1);
      }
      else {
        warn "Cannot write to $fname: $!\n";
      }
    }
    else {
      warn "Cannot open $defprefs: $!\n";
    }
  }

  return(0);
}

###########################################################################

sub expand_name ($) {
  my ($self, $name) = @_;

# For CPU2006, the home directory is always '.'
return '.';

  my $home = $self->{user_dir} || $ENV{HOME} || '';

  if (Mail::SpamAssassin::Util::am_running_on_windows()) {
    my $userprofile = $ENV{USERPROFILE} || '';

    return $userprofile if ($userprofile && $userprofile =~ m/^[a-z]\:[\/\\]/oi);
    return $userprofile if ($userprofile =~ m/^\\\\/o);

    return $home if ($home && $home =~ m/^[a-z]\:[\/\\]/oi);
    return $home if ($home =~ m/^\\\\/o);

    return '';
  } else {
    return $home if ($home && $home =~ /\//o);
    return (getpwnam($name))[7] if ($name ne '');
    return (getpwuid($>))[7];
  }
}

sub sed_path {
  my ($self, $path) = @_;
  return undef if (!defined $path);

  $path =~ s/__local_rules_dir__/$self->{LOCAL_RULES_DIR} || ''/ges;
  $path =~ s/__def_rules_dir__/$self->{DEF_RULES_DIR} || ''/ges;
  $path =~ s{__prefix__}{$self->{PREFIX} || $Config{prefix} || '/usr'}ges;
  $path =~ s{__userstate__}{$self->get_and_create_userstate_dir()}ges;
  $path =~ s/^\~([^\/]*)/$self->expand_name($1)/es;

  return Mail::SpamAssassin::Util::untaint_file_path ($path);
}

sub first_existing_path {
  my $self = shift;
  my $path;
  foreach my $p (@_) {
    $path = $self->sed_path ($p);
    if (defined $path && -e $path) { return $path; }
  }
  $path;
}

sub get_cf_files_in_dir {
  my ($self, $dir) = @_;

# CPU2006 -- hack it because there's no opendir
my @cfs = ();
if ($dir eq './rules') {
@cfs = qw(10_misc.cf
20_anti_ratware.cf
20_body_tests.cf
20_fake_helo_tests.cf
20_head_tests.cf
20_html_tests.cf
20_meta_tests.cf
20_phrases.cf
20_porn.cf
20_ratware.cf
20_uri_tests.cf
23_bayes.cf
25_body_tests_es.cf
25_body_tests_pl.cf
25_head_tests_es.cf
25_head_tests_pl.cf
30_text_de.cf
30_text_es.cf
30_text_fr.cf
30_text_it.cf
30_text_pl.cf
30_text_sk.cf
50_scores.cf
60_whitelist.cf
local.cf
regression_tests.cf);
}
#  opendir(SA_CF_DIR, $dir) or warn "cannot opendir $dir: $!\n";
#  my @cfs = grep { /\.cf$/ && -f "$dir/$_" } readdir(SA_CF_DIR);
#  closedir SA_CF_DIR;

  return map { "$dir/$_" } sort { $a cmp $b } @cfs;	# sort numerically
}

###########################################################################

sub encapsulate_mail_object {
  my ($self, $mail_obj) = @_;

  # first, check to see if this is not actually a Mail::Audit object;
  # it could also be an already-encapsulated Mail::Audit wrapped inside
  # a Mail::SpamAssassin::Message.
  if ($mail_obj->{is_spamassassin_wrapper_object}) {
    return $mail_obj;
  }
  
  # For CPU2006, there is no "my_mail_class" :)
#  if ($self->{use_my_mail_class}) {
#    my $class = $self->{use_my_mail_class};
#    (my $file = $class) =~ s/::/\//g;
#    require "$file.pm";
#    return $class->new($mail_obj);
#  }

  # new versions of Mail::Audit can have one of 2 different base classes. URGH.
  # we can tell which class, by querying the is_mime() method.  Support for
  # MIME::Entity contributed by Andrew Wilson <andrew@rivendale.net>.
  #
  my $ismime = 0;
  if ($mail_obj->can ("is_mime")) { $ismime = $mail_obj->is_mime(); }

  if ($ismime) {
    require Mail::SpamAssassin::EncappedMIME;
    return  Mail::SpamAssassin::EncappedMIME->new($mail_obj);
  } else {
    require Mail::SpamAssassin::EncappedMessage;
    return  Mail::SpamAssassin::EncappedMessage->new($mail_obj);
  }
}

sub find_all_addrs_in_mail {
  my ($self, $mail_obj) = @_;

  $self->init(1);
  my $mail = $self->encapsulate_mail_object ($mail_obj);

  my @addrlist = ();
  foreach my $header (qw(To From Cc Reply-To Sender
  				Errors-To Mail-Followup-To))
  {
    my @hdrs = $mail->get_header ($header);
    if ($#hdrs < 0) { next; }
    push (@addrlist, $self->find_all_addrs_in_line (join (" ", @hdrs)));
  }

  # find addrs in body, too
  foreach my $line (@{$mail->get_body()}) {
    push (@addrlist, $self->find_all_addrs_in_line ($line));
  }

  my @ret = ();
  my %done = ();

  foreach $_ (@addrlist) {
    s/^mailto://;       # from Outlook "forwarded" message
    next if defined ($done{$_}); $done{$_} = 1;
    push (@ret, $_);
  }

  @ret;
}

sub find_all_addrs_in_line {
  my ($self, $line) = @_;

  my $ID_PATTERN   = '[-a-z0-9_\+\:\/\.]+';
  my $HOST_PATTERN = '[-a-z0-9_\+\:\/]+';

  my @addrs = ();
  my %seen = ();
  while ($line =~ s/(?:mailto:)?\s*
	      ($ID_PATTERN \@
	      $HOST_PATTERN(?:\.$HOST_PATTERN)+)//oix) 
  {
    my $addr = $1;
    $addr =~ s/^mailto://;
    next if (defined ($seen{$addr})); $seen{$addr} = 1;
    push (@addrs, $addr);
  }

  return @addrs;
}

# Only the first argument is needed, and it can be a reference to a list if
# you want
sub dbg {
  my $dbg=$Mail::SpamAssassin::DEBUG;

  return unless $dbg->{enabled};

  my ($msg, $codepath, $level) = @_;

  $msg=join('',@{$msg}) if (ref $msg);

  if (defined $codepath) {
    if (not defined $dbg->{$codepath}) {
      warn("dbg called with codepath $codepath, but it's not defined, skipping (message was \"$msg\"\n");
      return 0;
    } elsif (not defined $level) {
      warn("dbg called with codepath $codepath, but no level threshold (message was \"$msg\"\n");
    }
  }
  # Negative levels are just level numbers, the more negative, the more debug
  return if (defined $level and $level<0 and not $dbg->{$codepath} <= $level);
  # Positive levels are bit fields
  return if (defined $level and $level>0 and not $dbg->{$codepath} & $level);

  warn "debug: $msg\n";
}

# sa_die -- used to die with a useful exit code.

sub sa_die {
  my $exitcode = shift;
  warn @_;
  exit $exitcode;
}

1;
__END__

###########################################################################

=back

=head1 PREREQUISITES

C<Mail::Audit>
C<Mail::Internet>

=head1 COREQUISITES

C<Net::DNS>

=head1 MORE DOCUMENTATION

See also http://spamassassin.org/ for more information.

=head1 SEE ALSO

C<Mail::SpamAssassin::Conf>
C<Mail::SpamAssassin::PerMsgStatus>
C<spamassassin>

=head1 BUGS

http://bugzilla.spamassassin.org/

=head1 AUTHOR

Justin Mason E<lt>jm /at/ jmason.orgE<gt>

=head1 COPYRIGHT

SpamAssassin is distributed under Perl's Artistic license.

=head1 AVAILABILITY

The latest version of this library is likely to be available from CPAN
as well as:

  http://spamassassin.org/

=cut



