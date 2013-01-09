package Mail::SpamAssassin::Dns;
1;

package Mail::SpamAssassin::PerMsgStatus;

use Mail::SpamAssassin::Conf;
use Mail::SpamAssassin::PerMsgStatus;
use File::Spec;
# CPU2006 -- no IPC
#use IO::Socket;
#use IPC::Open2;
#use POSIX ":sys_wait_h";        # sorry Craig ;)

use strict;
use bytes;
use Carp;

use vars qw{
  $KNOWN_BAD_DIALUP_RANGES $IP_IN_RESERVED_RANGE
  @EXISTING_DOMAINS $IS_DNS_AVAILABLE $VERSION
};

# don't lookup SpamAssassin.org -- use better-connected sites
# instead ;)
@EXISTING_DOMAINS = qw{
  kernel.org
  slashdot.org
  google.com
  google.de
  microsoft.com
  yahoo.com
  yahoo.de
  amazon.com
  amazon.de
  nytimes.com
  leo.org
  gwdg.de
};

# Initialize a regexp for reserved IPs, i.e. ones that could be
# used inside a company and be the first or second relay hit by
# a message. Some companies use these internally and translate
# them using a NAT firewall. These are listed in the RBL as invalid
# originators -- which is true, if you receive the mail directly
# from them; however we do not, so we should ignore them.
# cf. <http://www.iana.org/assignments/ipv4-address-space>,
#     <http://duxcw.com/faq/network/privip.htm>,
#     <http://duxcw.com/faq/network/autoip.htm>,
#     <ftp://ftp.rfc-editor.org/in-notes/rfc3330.txt>
#
# Last update
#   2003-04-15 Updated - bug 1784
#   2003-04-07 Justin Mason - removed some now-assigned nets
#   2002-08-24 Malte S. Stretz - added 172.16/12, 169.254/16
#   2002-08-23 Justin Mason - added 192.168/16
#   2002-08-12 Matt Kettler - mail to SpamAssassin-devel
#              msgid:<5.1.0.14.0.20020812211512.00a33cc0@192.168.50.2>
#
$IP_IN_RESERVED_RANGE = qr{^(?:
  10|                              # 10.0.0.0/8:          Private-Use Networks (see RFC3330) 
  127|                             # 127/8:               Loopback (see RFC3330) 
  128\.0|                          # 128.0/16:            Reserved (subject to allocation) (see RFC3330) 
  169\.254|                        # 169.254/16:          Link Local (APIPA) (see RFC3330) 
  172\.(?:1[6-9]|2[0-9]|3[01])|    # 172.16-172.31/16:    Private-Use Networks (see RFC3330) 
  191\.255|                        # 191.255/16:          Reserved (subject to allocation) (see RFC3330) 
  192\.0\.0|                       # 192.0.0/24:          Reserved (subject to allocation) (see RFC3330) 
  192\.0\.2|                       # 192.0.2/24:          Test-Net (see RFC3330) 
  192\.88\.99|                     # 192.88.99/24:        6to4 Relay Anycast (see RFC3330) 
  192\.168|                        # 192.168.0.0/16:      Private-Use Networks (see RFC3330) 
  198\.1[89]|                      # 198.18.0.0/15:       Device Benchmark Testing (see RFC3330) 
  223\.255\.255|                   # 223.255.255.0/24:    Reserved (subject to allocation) (see RFC3330) 
  [01257]|                         # 0/8:                 "This" Network (see RFC3330) 
                                   # 1-2/8, 5/8, 7/8:     IANA Reserved 

  2[37]|                           # 23/8, 27/8:          IANA Reserved 
  3[1679]|                         # 31/8, 36/8, 37/8:    IANA Reserved 
                                   # 39/8:                Reserved (subject to allocation) (see RFC3330) 
  4[12]|                           # 41/8, 42/8:          IANA Reserved   
  5[89]|                           # 58/8, 59/8:          IANA Reserved   
  7[0-9]|                          # 70-79/8:             IANA Reserved    
  8[3-9]|                          # 83-89/8:             IANA Reserved   
  9[0-9]|                          # 90-99/8:             IANA Reserved   
  1[01][0-9]|                      # 100-119/8:           IANA Reserved   
  12[0-6]|                         # 120-126/8:           IANA Reserved   
  17[3-9]|                         # 173-179/8:           IANA Reserved   
  18[0-7]|                         # 180-187/8:           IANA Reserved   
  189|                             # 189/8:               IANA Reserved   
  19[07]|                          # 190/8, 197/8:        IANA Reserved   
  223|                             # 223/8:               IANA Reserved   
  22[4-9]|                         # 224-229/8:           Multicast (see RFC3330)  
  23[0-9]|                         # 230-239/8:           Multicast (see RFC3330)  
  24[0-9]|                         # 240-249/8:           Reserved for Future Use (see RFC3330) 
  25[0-5]                          # 250-255/8:           Reserved for Future Use (see RFC3330) 

)\.}x;

# CPU2006
#$IS_DNS_AVAILABLE = undef;
$IS_DNS_AVAILABLE = 0;

$VERSION = 'bogus';     # avoid CPAN.pm picking up razor ver

###########################################################################

BEGIN {
  # some trickery. Load these modules right here, if possible; that way, if
  # the module exists, we'll get it loaded now.  Very useful to avoid attempted
  # loads later (which will happen).  If we do a fork(), we could wind up
  # attempting to load these modules in *every* subprocess.
  #
  # We turn off strict and warnings, because Net::DNS and Razor both contain
  # crud that -w complains about (perl 5.6.0).  Not that this seems to work,
  # mind ;)

  no strict;
  local ($^W) = 0;

# CPU2006
#  eval {
#    require Net::DNS;
#    require Net::DNS::Resolver;
#  };
#  eval {
#    require Razor2::Client::Agent;
#  };
  eval {
    require MIME::Base64;
  };
# CPU2006
#  eval {
#	require IO::Socket::UNIX;
#  };
};

###########################################################################

# DNS query array constants
use constant BGSOCK => 0;
use constant RULES => 1;
use constant SETS => 2;

# TODO: $server is currently unused
sub do_rbl_lookup {
  my ($self, $rule, $set, $type, $server, $host, $subtest) = @_;

  # only make a specific query once
  if (!defined $self->{dnscache}->{$type}->{$host}->[BGSOCK]) {
    dbg("rbl: launching DNS $type query for $host in background", "rbl", -1);
    $self->{rbl_launch} = time;
    $self->{dnscache}->{$type}->{$host}->[BGSOCK] =
	$self->{res}->bgsend($host, $type);
  }

  # always add set
  push @{$self->{dnscache}->{$type}->{$host}->[SETS]}, $set;

  # sometimes match or always match
  if (defined $subtest) {
    $self->{dnspost}->{$set}->{$subtest} = $rule;
  }
  else {
    push @{$self->{dnscache}->{$type}->{$host}->[RULES]}, $rule;
  }
}

# TODO: these are constant so they should only be added once at startup
sub register_rbl_subtest {
  my ($self, $rule, $set, $subtest) = @_;
  $self->{dnspost}->{$set}->{$subtest} = $rule;
}

###########################################################################

sub dnsbl_hit {
  my ($self, $rule, $question, $answer) = @_;

  my $log = "";
  if (substr($rule, 0, 2) ne "__") {
    if ($answer->type eq 'TXT') {
      $log = $answer->rdatastr;
      $log =~ s/^"(.*)"$/$1/;
      $log =~ s/(http:\/\/\S+)/<$1>/g;
    }
    elsif ($question->string =~ m/^(\d+)\.(\d+)\.(\d+)\.(\d+)\.(\S+\w)/) {
      $log = "$4.$3.$2.$1 listed in $5";
    }
  }
  $self->{dnsresult}->{$rule}->{$log} = 1;
}

sub dnsbl_uri {
  my ($self, $question, $answer) = @_;

  my $qname = $question->qname;
  my $rdatastr = $answer->rdatastr;

  if (defined $qname && defined $rdatastr) {
    my $qclass = $question->qclass;
    my $qtype = $question->qtype;
    my @vals;
    push(@vals, "class=$qclass") if $qclass ne "IN";
    push(@vals, "type=$qtype") if $qtype ne "A";
    my $uri = "dns:$qname" . (@vals ? "?" . join(";", @vals) : "");
    push @{ $self->{dnsuri}->{$uri} }, $rdatastr;
  }
}

sub process_dnsbl_result {
  my ($self, $query) = @_;

# CPU2006
return;

  my $packet = $self->{res}->bgread($query->[BGSOCK]);
  undef $query->[BGSOCK];

  return if !defined $packet;

  my $question = ($packet->question)[0];
  foreach my $answer ($packet->answer) {
    # track all responses
    $self->dnsbl_uri($question, $answer);
    # TODO: there are some CNAME returns that might be useful
    next if ($answer->type ne 'A' && $answer->type ne 'TXT');
    # skip any A record that isn't on 127/8
    next if ($answer->type eq 'A' && $answer->rdatastr !~ /^127\./);
    for my $rule (@{$query->[RULES]}) {
      $self->dnsbl_hit($rule, $question, $answer);
    }
    for my $set (@{$query->[SETS]}) {
      if ($self->{dnspost}->{$set}) {
	$self->process_dnsbl_set($set, $question, $answer);
      }
    }
  }
}

sub process_dnsbl_set {
  my ($self, $set, $question, $answer) = @_;

  my $rdatastr = $answer->rdatastr;
  while (my ($subtest, $rule) = each %{ $self->{dnspost}->{$set} }) {
    next if defined $self->{tests_already_hit}->{$rule};

    # exact substr (usually IP address)
    if ($subtest eq $rdatastr) {
      $self->dnsbl_hit($rule, $question, $answer);
    }
    # senderbase
    elsif ($set =~ /^senderbase/) {
      $rdatastr =~ s/^"?\d+-//;
      $rdatastr =~ s/"$//;
      my %sb = ($rdatastr =~ m/(?:^|\|)(\d+)=([^|]+)/g);
      while ($subtest =~ m/\bS(\d+)\b/g) {
	$subtest =~ s/\bS(\d+)\b/\$sb{$1}/;
      }
      #print STDERR "$subtest\n";
      #print STDERR "$rdatastr\n";
      $self->got_hit($rule, "SenderBase: ") if eval "$subtest";
    }
    # bitmask
    elsif ($subtest =~ /^\d+$/) {
      if ($rdatastr =~ m/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ &&
	  Mail::SpamAssassin::Util::my_inet_aton($rdatastr) & $subtest)
      {
	$self->dnsbl_hit($rule, $question, $answer);
      }
    }
    # regular expression
    elsif ($rdatastr =~ /\Q$subtest\E/) {
      $self->dnsbl_hit($rule, $question, $answer);
    }
  }
}

sub harvest_dnsbl_queries {
  my ($self) = @_;

  return if !defined $self->{rbl_launch};

  my $timeout = $self->{conf}->{rbl_timeout} + $self->{rbl_launch};
  my @waiting = (values %{ $self->{dnscache}->{A} },
		 values %{ $self->{dnscache}->{TXT} });
  my @left;
  my $total;

  @waiting = grep { defined $_->[BGSOCK] } @waiting;
  $total = scalar @waiting;

  while (@waiting) {
    @left = ();
    for my $query (@waiting) {
      if ($self->{res}->bgisready($query->[BGSOCK])) {
	$self->process_dnsbl_result($query);
      }
      else {
	push(@left, $query);
      }
    }
    last unless @left;
    last if time >= $timeout;
    @waiting = @left;
    # dynamic timeout
    my $dynamic = (int($self->{conf}->{rbl_timeout}
		       * (1 - (($total - @left) / $total) ** 2) + 0.5)
		   + $self->{rbl_launch});
    $timeout = $dynamic if ($dynamic < $timeout);
    sleep 1;
  }
  dbg("RBL: success for " . ($total - @left) . " of $total queries", "rbl", 0);
  # timeouts
  for my $query (@left) {
    my $sets = join(",", @{$query->[SETS]});
    my $delay = time - $self->{rbl_launch};
    dbg("RBL: timeout for $sets after $delay seconds", "rbl", 0);
    undef $query->[BGSOCK];
  }
  # register hits
  while (my ($rule, $logs) = each %{ $self->{dnsresult} }) {
    for my $log (keys %{$logs}) {
      $self->test_log($log) if $log;
    }
    if (!defined $self->{tests_already_hit}->{$rule}) {
      $self->got_hit($rule, "RBL: ");
    }
  }
  # DNS URIs
  while (my ($dnsuri, $answers) = each %{ $self->{dnsuri} }) {
    # when parsing, look for elements of \".*?\" or \S+ with ", " as separator
    $self->{tag_data}->{RBL} .= "<$dnsuri>" .
	" [" . join(", ", @{ $answers }) . "]\n";
  }
  chomp $self->{tag_data}->{RBL} if defined $self->{tag_data}->{RBL};
}

###########################################################################

sub rbl_finish {
  my ($self) = @_;

  delete $self->{rbl_launch};
  delete $self->{dnscache};
  # TODO: do not remove this since it can be retained!
  delete $self->{dnspost};
  delete $self->{dnsresult};
  delete $self->{dnsuri};
}

###########################################################################

sub is_razor2_available {
  my ($self) = @_;

# CPU2006
return 0;

  if ($self->{main}->{local_tests_only}) {
    dbg ("local tests only, ignoring Razor2", "razor", -1);
    return 0;
  }
  if (!$self->{conf}->{use_razor2}) { return 0; }

  # Use Razor2 if it's available
  if (eval { require Razor2::Client::Agent; }) {
    dbg("Razor2 is available", "razor", -1);
    return 1;
  }
  else {
    dbg("Razor2 is not available", "razor", -1);
    return 0;
  }
}

sub razor2_lookup {
  my ($self, $fulltext) = @_;
  my $timeout=$self->{conf}->{razor_timeout};

  # Set the score for the ranged checks
  $self->{razor2_cf_score} = 0;
  return $self->{razor2_result} if ( defined $self->{razor2_result} );
  $self->{razor2_result} = 0;

  # this test covers all aspects of availability
  if (!$self->is_razor2_available()) { return 0; }
  
  # razor also debugs to stdout. argh. fix it to stderr...
  if ($Mail::SpamAssassin::DEBUG->{enabled}) {
    open (OLDOUT, ">&STDOUT");
    open (STDOUT, ">&STDERR");
  }

  $self->enter_helper_run_mode();

    eval {
      local ($^W) = 0;    # argh, warnings in Razor

      require Razor2::Client::Agent;

      local $SIG{ALRM} = sub { die "alarm\n" };
      alarm $timeout;

      # everything's in the module!
      my $rc = Razor2::Client::Agent->new('razor-check');

      if ($rc) {
        my %opt = (
            debug      => ($Mail::SpamAssassin::DEBUG->{enabled} and
                 $Mail::SpamAssassin::DEBUG->{razor} < -2), 
	    foreground => 1,
            config     => $self->{conf}->{razor_config}
        );
        $rc->{opt} = \%opt;
        $rc->do_conf() or die $rc->errstr;

	my $tmptext = $$fulltext;
	my @msg = (\$tmptext);

        my $objects = $rc->prepare_objects( \@msg )
          or die "error in prepare_objects";
        $rc->get_server_info() or die $rc->errprefix("checkit");

	# let's reset the alarm since get_server_info() calls
	# nextserver() which calls discover() which very likely will
	# reset the alarm for us ... how polite.  :(  
	alarm $timeout;

        my $sigs = $rc->compute_sigs($objects)
          or die "error in compute_sigs";

        # 
        # if mail isn't whitelisted, check it out
        #   
        if ( ! $rc->local_check( $objects->[0] ) ) {
          if (!$rc->connect()) {
            # provide a better error message when servers are unavailable,
            # than "Bad file descriptor Died".
            die "could not connect to any servers\n";
          }
          $rc->check($objects) or die $rc->errprefix("checkit");
          $rc->disconnect() or die $rc->errprefix("checkit");

	  # if we got here, we're done doing remote stuff, abort the alert
	  alarm 0;

	  dbg("Using results from Razor v".$Razor2::Client::Version::VERSION);

	  # so $objects->[0] is the first (only) message, and ->{spam} is a general yes/no
          $self->{razor2_result} = $objects->[0]->{spam} || 0;

	  # great for debugging, but leave this off!
	  #use Data::Dumper;
	  #print Dumper($objects),"\n";

	  # ->{p} is for each part of the message
	  # so go through each part, taking the highest cf we find
	  # of any part that isn't contested (ct).  This helps avoid false
	  # positives.  equals logic_method 4.
	  #
	  # razor-agents < 2.14 have a different object format, so we now support both.
	  # $objects->[0]->{resp} vs $objects->[0]->{p}->[part #]->{resp}
	  my $part = 0;
	  my $arrayref = $objects->[0]->{p} || $objects;
	  if ( defined $arrayref ) {
	    foreach my $cf ( @{$arrayref} ) {
	      if ( exists $cf->{resp} ) {
	        for (my $response=0;$response<@{$cf->{resp}};$response++) {
	          my $tmp = $cf->{resp}->[$response];
	      	  my $tmpcf = $tmp->{cf} || 0; # Part confidence
	      	  my $tmpct = $tmp->{ct} || 0; # Part contested?
		  my $engine = $cf->{sent}->[$response]->{e};
	          dbg("Found Razor2 part: part=$part engine=$engine ct=$tmpct cf=$tmpcf");
	          $self->{razor2_cf_score} = $tmpcf if ( !$tmpct && $tmpcf > $self->{razor2_cf_score} );
	        }
	      }
	      else {
		my $text = "part=$part noresponse";
		$text .= " skipme=1" if ( $cf->{skipme} );
	        dbg("Found Razor2 part: $text");
	      }
	      $part++;
	    }
	  }
	  else {
	    # If we have some new $objects format that isn't close to
	    # the current razor-agents 2.x version, we won't FP but we
	    # should alert in debug.
	    dbg("It looks like the internal Razor object has changed format!  Tell spamassassin-devel!");
	  }
        }
      }
      else {
        warn "undefined Razor2::Client::Agent\n";
      }
  
      alarm 0;
    };

    alarm 0;    # just in case
  
    if ($@) {
      if ( $@ =~ /alarm/ ) {
          dbg("razor2 check timed out after $timeout secs.");
        } elsif ($@ =~ /(?:could not connect|network is unreachable)/) {
          # make this a dbg(); SpamAssassin will still continue,
          # but without Razor checking.  otherwise there may be
          # DSNs and errors in syslog etc., yuck
          dbg("razor2 check could not connect to any servers");
        } else {
          warn("razor2 check skipped: $! $@");
        }
      }

  # work around serious brain damage in Razor2 (constant seed)
  srand;

  $self->leave_helper_run_mode();

  # razor also debugs to stdout. argh. fix it to stderr...
  if ($Mail::SpamAssassin::DEBUG->{enabled}) {
    open (STDOUT, ">&OLDOUT");
    close OLDOUT;
  }

  dbg("Razor2 results: spam? ".$self->{razor2_result}."  highest cf score: ".$self->{razor2_cf_score});

  if ($self->{razor2_result} > 0) {
      return 1;
  }
  return 0;
}

###########################################################################

sub is_dccifd_available {
  my ($self) = @_;

# CPU2006
return 0;

  if ($self->{main}->{local_tests_only}) {
    dbg ("local tests only, ignoring DCCifd");
    return 0;
  }

  my $dcchome = $self->{conf}->{dcc_home}        || '';
  my $dccifd  = $self->{conf}->{dcc_dccifd_path} || '';

  if (!$dccifd && ($dcchome && -S "$dcchome/dccifd")) {
    $dccifd   = "$dcchome/dccifd";
  }

  unless ($dccifd && -S $dccifd && -w _ && -r _ ) {
    dbg ("DCCifd is not available: no r/w dccifd socket found.");
    return 0;
  }

  # Remember any found dccifd socket
  $self->{conf}->{dcc_dccifd_path} = $dccifd;

  dbg ("DCCifd is available: ".$self->{conf}->{dcc_dccifd_path});
  return 1;
}

sub is_dcc_available {
  my ($self) = @_;

# CPU2006
return 0;

  if ($self->{main}->{local_tests_only}) {
    dbg ("local tests only, ignoring DCC");
    return 0;
  }
  if (!$self->{conf}->{use_dcc}) { return 0; }

  my $dcchome = $self->{conf}->{dcc_home} || '';
  my $dccproc = $self->{conf}->{dcc_path} || '';

  if (!$dccproc && ($dcchome && -x "$dcchome/bin/dccproc")) {
    $dccproc  = "$dcchome/bin/dccproc";
  }
  unless ($dccproc) {
    $dccproc  = Mail::SpamAssassin::Util::find_executable_in_env_path('dccproc');
  }

  unless ($dccproc && -x $dccproc) {
    dbg ("DCC is not available: no executable dccproc found.");
    return 0;
  }

  # Remember any found dccproc
  $self->{conf}->{dcc_path} = $dccproc;

  dbg ("DCC is available: ".$self->{conf}->{dcc_path});
  return 1;
}

sub dccifd_lookup {
  my ($self, $fulltext) = @_;
  my $response = "";
  my %count;
  my $left;
  my $right;
  my $timeout=$self->{conf}->{dcc_timeout};
  my $sockpath;

  $count{body} = 0;
  $count{fuz1} = 0;
  $count{fuz2} = 0;

  if ($self->{main}->{local_tests_only}) {
    dbg ("local tests only, ignoring DCCifd");
    return 0;
  }

  if ( ! $self->{conf}->{dcc_home} ) {
	dbg ("dcc_home not defined, should not get here");
    return 0;
  }

  $sockpath = $self->{conf}->{dcc_dccifd_path};
  if ( ! -S $sockpath || ! -w _ || ! -r _ ) {
	dbg ("dccifd not a socket, should not get here");
    return 0;
  }

  $self->enter_helper_run_mode();

  eval {
    local $SIG{ALRM} = sub { die "alarm\n" };

    alarm($timeout);

# CPU2006 -- no socket constants (but we're not using it anyway)
#    my $sock = IO::Socket::UNIX->new(Type => SOCK_STREAM,
#      Peer => $sockpath) || dbg("failed to open socket") && die;
    my $sock;

    # send the options and other parameters to the daemon
    $sock->print("header\n") || dbg("failed write") && die; # options
    $sock->print("0.0.0.0\n") || dbg("failed write") && die; #client
    $sock->print("\n") || dbg("failed write") && die; #HELO value
    $sock->print("\n") || dbg("failed write") && die; #sender
    $sock->print("unknown\r\n") || dbg("failed write") && die; # recipients
    $sock->print("\n") || dbg("failed write") && die; # recipients

    $sock->print($$fulltext);

    $sock->shutdown(1) || dbg("failed socket shutdown: $!") && die;
	
    $sock->getline() || dbg("failed read status") && die;
    $sock->getline() || dbg("failed read multistatus") && die;

    my @null = $sock->getlines();
    if ( $#null == -1 ) {
      dbg("failed read header");
      die;
    }

    # The first line will be the header we want to look at
    chomp($response = shift @null);
    # but newer versions of DCC fold the header if it's too long...
    while ( my $v = shift @null ) {
      last unless ( $v =~ s/^\s+/ / );  # if this line wasn't folded, stop.
      chomp $v;
      $response .= $v;
    }

    dbg("DCCifd: got response: $response");
  };
  alarm(0); # if we die'd above, need to reset here

  $self->leave_helper_run_mode();

  if ($@) {
    $response = undef;
    if ($@ =~ /alarm/) {
      dbg ("DCCifd check timed out after $timeout secs.");
      return 0;
    } else {
      warn ("DCCifd -> check skipped: $! $@");
      return 0;
    }
  }

  if (!defined $response || $response !~ /^X-DCC/) {
    dbg ("DCCifd -> check failed - no X-DCC returned: $response");
    return 0;
  }

  if ($response =~ /^X-DCC-(.*)-Metrics: (.*)$/) {
    $self->{tag_data}->{DCCB} = $1;
    $self->{tag_data}->{DCCR} = $2;
  }
 
  $response =~ s/many/999999/ig;
  $response =~ s/ok\d?/0/ig;

  if ($response =~ /Body=(\d+)/) {
    $count{body} = $1+0;
  }
  if ($response =~ /Fuz1=(\d+)/) {
    $count{fuz1} = $1+0;
  }
  if ($response =~ /Fuz2=(\d+)/) {
    $count{fuz2} = $1+0;
  }

  if ($count{body} >= $self->{conf}->{dcc_body_max} || $count{fuz1} >= $self->{conf}->{dcc_fuz1_max} || $count{fuz2} >= $self->{conf}->{dcc_fuz2_max}) {
    dbg ("DCCifd: Listed! BODY: $count{body} of $self->{conf}->{dcc_body_max} FUZ1: $count{fuz1} of $self->{conf}->{dcc_fuz1_max} FUZ2: $count{fuz2} of $self->{conf}->{dcc_fuz2_max}");
    return 1;
  }
  
  return 0;
}

sub dcc_lookup {
  my ($self, $fulltext) = @_;
  my $response = undef;
  my %count;
  my $timeout=$self->{conf}->{dcc_timeout};

  $count{body} = 0;
  $count{fuz1} = 0;
  $count{fuz2} = 0;

# CPU2006 -- just to be safe
return 0;

  if ($self->{main}->{local_tests_only}) {
    dbg ("local tests only, ignoring DCC");
    return 0;
  }
  if (!$self->{conf}->{use_dcc}) { return 0; }

  $self->enter_helper_run_mode();

  # use a temp file here -- open2() is unreliable, buffering-wise,
  # under spamd. :(
  my $tmpf = $self->create_fulltext_tmpfile($fulltext);

  eval {
    local $SIG{ALRM} = sub { die "__alarm__\n" };
    local $SIG{PIPE} = sub { die "__brokenpipe__\n" };

    alarm($timeout);

    # Note: not really tainted, these both come from system conf file.
    my $path = Mail::SpamAssassin::Util::untaint_file_path ($self->{conf}->{dcc_path});

    my $opts = '';
    if ( $self->{conf}->{dcc_options} =~ /^([^\;\'\"\0]+)$/ ) {
      $opts = $1;
    }

    dbg("DCC command: ".join(' ', $path, "-H", $opts, "< '$tmpf'", "2>&1"),'dcc',-1);
    my $pid = open(DCC, join(' ', $path, "-H", $opts, "< '$tmpf'", "2>&1", '|')) || die "$!\n";
    my @null = <DCC>;
    close DCC;

    if ( $#null == -1 ) {
      dbg("failed read header");
      die;
    }

    # The first line will be the header we want to look at
    chomp($response = shift @null);
    # but newer versions of DCC fold the header if it's too long...
    while ( my $v = shift @null ) {
      last unless ( $v =~ s/^\s+/ / );  # if this line wasn't folded, stop.
      chomp $v;
      $response .= $v;
    }

    unless (defined($response)) {
      die ("no response\n");	# yes, this is possible
    }

    dbg("DCC: got response: $response");

    alarm(0);
    $self->cleanup_kids($pid);
  };

  alarm 0;
  $self->leave_helper_run_mode();

  if ($@) {
    if ($@ =~ /^__alarm__$/) {
      dbg ("DCC -> check timed out after $timeout secs.");
    } elsif ($@ =~ /^__brokenpipe__$/) {
      dbg ("DCC -> check failed: Broken pipe.");
    } elsif ($@ eq "no response\n") {
      dbg ("DCC -> check failed: no response");
    } else {
      warn ("DCC -> check failed: $@\n");
    }
    return 0;
  }

  if (!defined($response) || $response !~ /^X-DCC/) {
    dbg ("DCC -> check failed: no X-DCC returned (did you create a map file?): $response");
    return 0;
  }

  if ($response =~ /^X-DCC-(.*)-Metrics: (.*)$/) {
    $self->{tag_data}->{DCCB} = $1;
    $self->{tag_data}->{DCCR} = $2;
  }
 
  $response =~ s/many/999999/ig;
  $response =~ s/ok\d?/0/ig;

  if ($response =~ /Body=(\d+)/) {
    $count{body} = $1+0;
  }
  if ($response =~ /Fuz1=(\d+)/) {
    $count{fuz1} = $1+0;
  }
  if ($response =~ /Fuz2=(\d+)/) {
    $count{fuz2} = $1+0;
  }

  if ($count{body} >= $self->{conf}->{dcc_body_max} || $count{fuz1} >= $self->{conf}->{dcc_fuz1_max} || $count{fuz2} >= $self->{conf}->{dcc_fuz2_max}) {
    dbg ("DCC: Listed! BODY: $count{body} of $self->{conf}->{dcc_body_max} FUZ1: $count{fuz1} of $self->{conf}->{dcc_fuz1_max} FUZ2: $count{fuz2} of $self->{conf}->{dcc_fuz2_max}");
    return 1;
  }
  
  return 0;
}

sub is_pyzor_available {
  my ($self) = @_;

# CPU2006
return 0;

  if ($self->{main}->{local_tests_only}) {
    dbg ("local tests only, ignoring Pyzor");
    return 0;
  }
  if (!$self->{conf}->{use_pyzor}) { return 0; }

  my $pyzor = $self->{conf}->{pyzor_path} || '';
  unless ($pyzor) {
    $pyzor = Mail::SpamAssassin::Util::find_executable_in_env_path('pyzor');
    if ($pyzor) { $self->{conf}->{pyzor_path} = $pyzor; }
  }
  unless ($pyzor && -x $pyzor) {
    dbg ("Pyzor is not available: pyzor not found");
    return 0;
  }

  dbg ("Pyzor is available: ".$self->{conf}->{pyzor_path});
  return 1;
}

sub pyzor_lookup {
  my ($self, $fulltext) = @_;
  my $response = undef;
  my $pyzor_count;
  my $pyzor_whitelisted;
  my $timeout=$self->{conf}->{pyzor_timeout};

  $pyzor_count = 0;
  $pyzor_whitelisted = 0;

# CPU2006 -- just to be safe
return 0;

  if ($self->{main}->{local_tests_only}) {
    dbg ("local tests only, ignoring Pyzor");
    return 0;
  }
  if (!$self->{conf}->{use_pyzor}) { return 0; }

  $self->enter_helper_run_mode();

  # use a temp file here -- open2() is unreliable, buffering-wise,
  # under spamd. :(
  my $tmpf = $self->create_fulltext_tmpfile($fulltext);

  eval {
    local $SIG{ALRM} = sub { die "__alarm__\n" };
    local $SIG{PIPE} = sub { die "__brokenpipe__\n" };

    alarm($timeout);

    # Note: not really tainted, this comes from system conf file.
    my $path = Mail::SpamAssassin::Util::untaint_file_path ($self->{conf}->{pyzor_path});

    my $opts = '';
    if ( $self->{conf}->{pyzor_options} =~ /^([^\;\'\"\0]+)$/ ) {
      $opts = $1;
    }
 
    dbg("Pyzor command: ".join(' ', $path, $opts, "check", "< '$tmpf'", "2>&1"),'pyzor',-1);
    my $pid = open(PYZOR, join(' ', $path, $opts, "check", "< '$tmpf'", "2>&1", '|')) || die "$!\n";
    $response = <PYZOR>;
    close PYZOR;

    unless (defined($response)) {
      die ("no response\n");	# yes, this is possible
    }

    chomp $response;

    dbg("Pyzor: got response: $response");

    alarm(0);
    $self->cleanup_kids($pid);
  };

  alarm 0;
  $self->leave_helper_run_mode();

  if ($@) {
    if ($@ =~ /^__alarm__$/) {
      dbg ("Pyzor -> check timed out after $timeout secs.");
    } elsif ($@ =~ /^__brokenpipe__$/) {
      dbg ("Pyzor -> check failed: Broken pipe.");
    } elsif ($@ eq "no response\n") {
      dbg ("Pyzor -> check failed: no response");
    } else {
      warn ("Pyzor -> check failed: $@\n");
    }
    return 0;
  }

  # made regexp a little more forgiving (jm)
  if ($response =~ /^\S+\t.*?\t(\d+)\t(\d+)\s*$/) {
    $pyzor_whitelisted = $2+0;
    if ($pyzor_whitelisted == 0) {
      $pyzor_count = $1+0;
    }

  } else {
    # warn on failures to parse (jm)
    dbg ("Pyzor: couldn't grok response \"$response\"");
  }

  # moved this around a bit; no point in testing RE twice (jm)
  if ($pyzor_whitelisted) {
    $self->{tag_data}->{PYZOR} = "Whitelisted.";
  } else {
    $self->{tag_data}->{PYZOR} = "Reported $pyzor_count times.";
  }

  if ($pyzor_count >= $self->{conf}->{pyzor_max}) {
    dbg ("Pyzor: Listed! $pyzor_count of $self->{conf}->{pyzor_max} and whitelist is $pyzor_whitelisted");
    return 1;
  }

  return 0;
}


###########################################################################

sub load_resolver {
  my ($self) = @_;

  if (defined $self->{res}) { return 1; }
  $self->{no_resolver} = 1;

# CPU2006
return 0;

  eval {
    require Net::DNS;
    $self->{res} = Net::DNS::Resolver->new;
    if (defined $self->{res}) {
      $self->{no_resolver} = 0;
      $self->{res}->retry(1);		# If it fails, it fails
      $self->{res}->dnsrch(0);		# ignore domain search-list
      $self->{res}->defnames(0);	# don't append stuff to end of query
    }
    1;
  };   #  or warn "eval failed: $@ $!\n";

  dbg ("is Net::DNS::Resolver available? " .
       ($self->{no_resolver} ? "no" : "yes"));

  return (!$self->{no_resolver});
}

sub lookup_mx {
  my ($self, $dom) = @_;

  return 0 unless $self->load_resolver();
  my $ret = 0;

  dbg ("looking up MX for '$dom'");

  eval {
    my @mxrecords = Net::DNS::mx($self->{res}, $dom);
    $ret = 1 if @mxrecords;
  };
  if ($@) {
    dbg ("MX lookup failed horribly, perhaps bad resolv.conf setting?");
    return undef;
  }

  dbg ("MX for '$dom' exists? $ret");
  return $ret;
}

sub lookup_ptr {
  my ($self, $dom) = @_;

  return undef unless $self->load_resolver();
  if ($self->{main}->{local_tests_only}) {
    dbg ("local tests only, not looking up PTR");
    return undef;
  }

  if ($dom =~ /^${IP_IN_RESERVED_RANGE}/) {
    dbg ("IP is reserved, not looking up PTR");
    return undef;
  }

  dbg ("looking up PTR record for '$dom'");
  my $name = '';

  eval {
        my $query = $self->{res}->search($dom);
        if ($query) {
	  foreach my $rr ($query->answer) {
	    if ($rr->type eq "PTR") {
	      $name = $rr->ptrdname; last;
	    }
	  }
        }

  };
  if ($@) {
    dbg ("PTR lookup failed horribly, perhaps bad resolv.conf setting?");
    return undef;
  }

  dbg ("PTR for '$dom': '$name'");

  # note: undef is never returned, unless DNS is unavailable.
  return $name;
}

sub is_dns_available {
  my ($self) = @_;
  my $dnsopt = $self->{conf}->{dns_available};
  my @domains;

  return $IS_DNS_AVAILABLE if (defined $IS_DNS_AVAILABLE);

  $IS_DNS_AVAILABLE = 0;
  if ($dnsopt eq "no") {
    dbg ("dns_available set to no in config file, skipping test", "dnsavailable", -1);
    return $IS_DNS_AVAILABLE;
  }

  # Even if "dns_available" is explicitly set to "yes", we want to ignore
  # DNS if we're only supposed to be looking at local tests.
  goto done if ($self->{main}->{local_tests_only});

  if ($dnsopt eq "yes") {
    $IS_DNS_AVAILABLE = 1;
    dbg ("dns_available set to yes in config file, skipping test", "dnsavailable", -1);
    return $IS_DNS_AVAILABLE;
  }
  
  goto done unless $self->load_resolver();

  if ($dnsopt =~ /test:\s+(.+)$/) {
    my $servers=$1;
    dbg("servers: $servers");
    @domains = split (/\s+/, $servers);
    dbg("Looking up MX records for user specified servers: ".join(", ", @domains), "dnsavailable", -1);
  } else {
    @domains = @EXISTING_DOMAINS;
  }

  # TODO: retry every now and again if we get this far, but the
  # next test fails?  could be because the ethernet cable has
  # simply fallen out ;)
  for(my $retry = 3; $retry > 0 and $#domains>-1; $retry--) {
    my $domain = splice(@domains, rand(@domains), 1);
    dbg ("trying ($retry) $domain...", "dnsavailable", -2);
    my $result = $self->lookup_mx($domain);
    if(defined $result) {
      if ( $result ) {
        dbg ("MX lookup of $domain succeeded => Dns available (set dns_available to hardcode)", "dnsavailable", -1);
        $IS_DNS_AVAILABLE = 1;
        last;
      }
    }
    else {
      dbg ("MX lookup of $domain failed horribly => Perhaps your resolv.conf isn't pointing at a valid server?", "dnsavailable", -1);
      $IS_DNS_AVAILABLE = 0; # should already be 0, but let's be sure.
      last; 
    }
  }

  dbg ("All MX queries failed => DNS unavailable (set dns_available to override)", "dnsavailable", -1) if ($IS_DNS_AVAILABLE == 0);

done:
  # jm: leaving this in!
  dbg ("is DNS available? $IS_DNS_AVAILABLE");
  return $IS_DNS_AVAILABLE;
}

###########################################################################

sub enter_helper_run_mode {
  my ($self) = @_;

# CPU2006
return;

  dbg ("entering helper-app run mode");
  $self->{old_slash} = $/;              # Razor pollutes this
  %{$self->{old_env}} = ();
  if ( defined %ENV ) {
    # undefined values in %ENV can result due to autovivification elsewhere,
    # this prevents later possible warnings when we restore %ENV
    while (my ($key, $value) = each %ENV) {
      $self->{old_env}->{$key} = $value if defined $value;
    }
  }

  Mail::SpamAssassin::Util::clean_path_in_taint_mode();

  my $newhome;
  if ($self->{main}->{home_dir_for_helpers}) {
    $newhome = $self->{main}->{home_dir_for_helpers};
  } else {
    # use spamd -u user's home dir
    $newhome = (Mail::SpamAssassin::Util::portable_getpwuid ($>))[7];
  }

  if ($newhome) {
    $ENV{'HOME'} = Mail::SpamAssassin::Util::untaint_file_path ($newhome);
  }
}

sub leave_helper_run_mode {
  my ($self) = @_;

# CPU2006
return;

  dbg ("leaving helper-app run mode");
  $/ = $self->{old_slash};
  %ENV = %{$self->{old_env}};
}

sub cleanup_kids {
  my ($self, $pid) = @_;

# CPU2006
return;

  if ($SIG{CHLD} && $SIG{CHLD} ne 'IGNORE') {	# running from spamd
    waitpid ($pid, 0);
  }
}

###########################################################################

1;
