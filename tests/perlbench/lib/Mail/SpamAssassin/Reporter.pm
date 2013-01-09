# Mail::SpamAssassin::Reporter - report a message as spam

package Mail::SpamAssassin::Reporter;

use strict;
use bytes;
# CPU2006 -- we don't have these
#use Carp;
#use POSIX ":sys_wait_h";

use vars qw{
  @ISA $VERSION
};

@ISA = qw();
$VERSION = 'bogus';	# avoid CPAN.pm picking up razor ver

###########################################################################

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my ($main, $msg, $options) = @_;

  my $self = {
    'main'		=> $main,
    'msg'		=> $msg,
    'options'		=> $options,
  };

  $self->{conf} = $self->{main}->{conf};

  bless ($self, $class);
  $self;
}

###########################################################################

sub report {
  my ($self) = @_;
  my $return = 1;
  my $available = 0;

# CPU2006 -- don't do reports
return 1;

  my $text = $self->{main}->remove_spamassassin_markup ($self->{msg});

  if (!$self->{options}->{dont_report_to_razor} && $self->is_razor_available()) {
    if ($self->razor_report($text)) {
      $available = 1;
      dbg ("SpamAssassin: spam reported to Razor.");
      $return = 0;
    }
    else {
      dbg ("SpamAssassin: could not report spam to Razor.");
    }
  }
  if (!$self->{options}->{dont_report_to_dcc} && $self->is_dcc_available()) {
    if ($self->dcc_report($text)) {
      $available = 1;
      dbg ("SpamAssassin: spam reported to DCC.");
      $return = 0;
    }
    else {
      dbg ("SpamAssassin: could not report spam to DCC.");
    }
  }
  if (!$self->{options}->{dont_report_to_pyzor} && $self->is_pyzor_available()) {
    if ($self->pyzor_report($text)) {
      $available = 1;
      dbg ("SpamAssassin: spam reported to Pyzor.");
      $return = 0;
    }
    else {
      dbg ("SpamAssassin: could not report spam to Pyzor.");
    }
  }

  $self->delete_fulltext_tmpfile();

  if ( $available == 0 ) {
    warn "SpamAssassin: no Internet hashing methods available, so couldn't report.\n";
  }

  return $return;
}

###########################################################################

sub revoke {
  my ($self) = @_;
  my $return = 1;

# CPU2006 -- also don't revoke
return 1;

  my $text = $self->{main}->remove_spamassassin_markup ($self->{msg});

  if (!$self->{main}->{local_tests_only}
      && !$self->{options}->{dont_report_to_razor}
      && $self->is_razor_available()) # we only work with Razor2
  {
    if ($self->razor_revoke($text)) {
      dbg ("SpamAssassin: spam revoked from Razor.");
      $return = 0;
    }
    else {
      dbg ("SpamAssassin: could not revoke spam from Razor.");
    }
  }

  # This is where you would revoke from DCC and Pyzor but I was unable
  # to find where they supported revoke

  return $return;
}

###########################################################################
# non-public methods.

# This is to reset the alarm before dieing - spamd can die of a stray alarm!

sub adie {
  my $msg = shift;
  alarm 0;
  die $msg;
}

# Close an fh piped to a process, possibly exiting if the process returned nonzero.
# thanks to nix /at/ esperi.demon.co.uk for this.
sub close_pipe_fh {
  my ($self, $fh) = @_;

  return if close ($fh);

  my $exitstatus = $?;
  dbg ("raw exit code: $exitstatus");

  if (WIFEXITED ($exitstatus) && (WEXITSTATUS ($exitstatus))) {
    die "Exited with non-zero exit code " . WEXITSTATUS ($exitstatus) . "\n";
  }

  if (WIFSIGNALED ($exitstatus)) {
    die "Exited due to signal " . WTERMSIG ($exitstatus) . "\n";
  }
}

sub razor_report {
  my ($self, $fulltext, $revoke) = @_;
  my $timeout=$self->{conf}->{razor_timeout};
  my $response;

# CPU2006 -- don't report
return 1;

  # If we passed in a true value for $revoke then we must be revoking
  my $type = (defined($revoke) && $revoke) ? 'revoke' : 'report';

  # razor also debugs to stdout. argh. fix it to stderr...
  if ($Mail::SpamAssassin::DEBUG->{enabled}) {
    open (OLDOUT, ">&STDOUT");
    open (STDOUT, ">&STDERR");
  }

  $self->enter_helper_run_mode();

  # Use Razor2 if it's available
  eval { require Razor2::Client::Agent; };
  if ( !$@ ) {
    eval {
      local ($^W) = 0;    # argh, warnings in Razor

      local $SIG{ALRM} = sub { die "alarm\n" };
      alarm $timeout;

      # everything's in the module!
      my $rc = Razor2::Client::Agent->new("razor-$type");

      if ($rc) {
        my %opt = (
          debug      => $Mail::SpamAssassin::DEBUG->{enabled},
          foreground => 1,
          config     => $self->{conf}->{razor_config}
        );
        $rc->{opt} = \%opt;
        $rc->do_conf() or adie($rc->errstr);

        # Razor2 requires authentication for reporting
        my $ident = $rc->get_ident
          or adie ("Razor2 $type requires authentication");

	my @msg = (\$fulltext);
        my $objects = $rc->prepare_objects( \@msg )
          or adie ("error in prepare_objects");
        $rc->get_server_info() or adie $rc->errprefix("reportit");

	# let's reset the alarm since get_server_info() calls
	# nextserver() which calls discover() which very likely will
	# reset the alarm for us ... how polite.  :(  
	alarm $timeout;

        my $sigs = $rc->compute_sigs($objects)
          or adie ("error in compute_sigs");

        $rc->connect() or adie ($rc->errprefix("reportit"));
        $rc->authenticate($ident) or adie ($rc->errprefix("reportit"));
        $rc->report($objects)     or adie ($rc->errprefix("reportit"));
        $rc->disconnect() or adie ($rc->errprefix("reportit"));
        $response = 1; # Razor 2.14 says that if we get here, we did ok.
      }
      else {
        warn "undefined Razor2::Client::Agent\n";
      }

      alarm 0;
      dbg("Razor2: spam $type, response is \"$response\".");
    };

    alarm 0;

    if ($@) {
      if ( $@ =~ /alarm/ ) {
        dbg("razor2 $type timed out after $timeout secs.");
      } elsif ($@ =~ /could not connect/) {
        dbg("razor2 $type could not connect to any servers");
      } elsif ($@ =~ /timeout/i) {
        dbg("razor2 $type timed out connecting to razor servers");
      } else {
        warn "razor2 $type failed: $! $@";
      }
      undef $response;
    }
  }

  # work around serious brain damage in Razor2 (constant seed)
  srand;

  $self->leave_helper_run_mode();

  if ($Mail::SpamAssassin::DEBUG->{enabled}) {
    open (STDOUT, ">&OLDOUT");
    close OLDOUT;
  }

  if (defined($response) && $response+0) {
    return 1;
  } else {
    return 0;
  }
}

sub razor_revoke {
  my ($self, $fulltext) = @_;

# CPU2006 -- don't
return 1;

  return $self->razor_report($fulltext, 1);
}

sub dcc_report {
  my ($self, $fulltext) = @_;
  my $timeout=$self->{conf}->{dcc_timeout};

# CPU2006 -- don't do reports
return 1;

  $self->enter_helper_run_mode();

  # use a temp file here -- open2() is unreliable, buffering-wise,
  # under spamd. :(
  my $tmpf = $self->create_fulltext_tmpfile(\$fulltext);

  eval {
    local $SIG{ALRM} = sub { die "__alarm__\n" };
    local $SIG{PIPE} = sub { die "__brokenpipe__\n" };

    alarm $timeout;

    # Note: not really tainted, these both come from system conf file.
    my $path = Mail::SpamAssassin::Util::untaint_file_path ($self->{conf}->{dcc_path});

    my $opts = '';
    if ( $self->{conf}->{dcc_options} =~ /^([^\;\'\"\0]+)$/ ) {
      $opts = $1;
    }

    my $pid = open(DCC, join(' ', $path, "-t many", $opts, "< '$tmpf'", ">/dev/null 2>&1", '|')) || die "$!\n";
    $self->close_pipe_fh (\*DCC);

    alarm(0);
    waitpid ($pid, 0);
  };

  alarm 0;
  $self->leave_helper_run_mode();
 
  if ($@) {
    if ($@ =~ /^__alarm__$/) {
      dbg ("DCC -> report timed out after $timeout secs.");
   } elsif ($@ =~ /^__brokenpipe__$/) {
      dbg ("DCC -> report failed: Broken pipe.");
    } else {
      warn ("DCC -> report failed: $@\n");
    }
    return 0;
  }

  return 1;
}

sub pyzor_report {
  my ($self, $fulltext) = @_;
  my $timeout=$self->{conf}->{pyzor_timeout};

# CPU2006 -- don't do reports
return 1;

  $self->enter_helper_run_mode();

  # use a temp file here -- open2() is unreliable, buffering-wise,
  # under spamd. :(
  my $tmpf = $self->create_fulltext_tmpfile(\$fulltext);

  eval {
    local $SIG{ALRM} = sub { die "__alarm__\n" };
    local $SIG{PIPE} = sub { die "__brokenpipe__\n" };

    alarm $timeout;

    # Note: not really tainted, this comes from system conf file.
    my $path = Mail::SpamAssassin::Util::untaint_file_path ($self->{conf}->{pyzor_path});

    my $opts = '';
    if ( $self->{conf}->{pyzor_options} =~ /^([^\;\'\"\0]+)$/ ) {
      $opts = $1;
    }

    my $pid = open(PYZOR, join(' ', $path, $opts, "report", "< '$tmpf'", ">/dev/null 2>&1", '|')) || die "$!\n";
    $self->close_pipe_fh (\*PYZOR);

    alarm(0);
    waitpid ($pid, 0);
  };

  alarm 0;
  $self->leave_helper_run_mode();

  if ($@) {
    if ($@ =~ /^__alarm__$/) {
      dbg ("Pyzor -> report timed out after $timeout secs.");
    } elsif ($@ =~ /^__brokenpipe__$/) {
      dbg ("Pyzor -> report failed: Broken pipe.");
    } else {
      warn ("Pyzor -> report failed: $@\n");
    }
    return 0;
  }

  return 1;
}
###########################################################################

sub dbg { Mail::SpamAssassin::dbg (@_); }
sub create_fulltext_tmpfile { Mail::SpamAssassin::PerMsgStatus::create_fulltext_tmpfile(@_) }
sub delete_fulltext_tmpfile { Mail::SpamAssassin::PerMsgStatus::delete_fulltext_tmpfile(@_) }

# Use the Dns versions ...  At least something only needs 1 copy of code ...
sub is_pyzor_available { Mail::SpamAssassin::PerMsgStatus::is_pyzor_available(@_); }
sub is_dcc_available { Mail::SpamAssassin::PerMsgStatus::is_dcc_available(@_); }
sub is_razor_available {
  Mail::SpamAssassin::PerMsgStatus::is_razor2_available(@_);
}

sub enter_helper_run_mode { Mail::SpamAssassin::PerMsgStatus::enter_helper_run_mode(@_); }
sub leave_helper_run_mode { Mail::SpamAssassin::PerMsgStatus::leave_helper_run_mode(@_); }

1;
