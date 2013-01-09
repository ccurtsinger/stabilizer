package Mail::SpamAssassin::CmdLearn;

use strict;
use bytes;

use Mail::SpamAssassin;
use Mail::SpamAssassin::ArchiveIterator;
use Mail::SpamAssassin::NoMailAudit;
use Mail::SpamAssassin::PerMsgLearner;

use Getopt::Long;
use Pod::Usage;

use vars qw(
  $spamtest %opt $isspam $forget
  $messagecount $learnedcount $messagelimit
  $rebuildonly $learnprob @targets $bayes_override_path
);

###########################################################################

sub cmdline_run {
  my ($opts) = shift;

  %opt = ( 'force-expire' => 0,
  	   'norebuild'    => 0,
	 );

  Getopt::Long::Configure(qw(bundling no_getopt_compat
                         permute no_auto_abbrev no_ignore_case));

  GetOptions(
	     'spam'				=> sub { $isspam = 1; },
	     'ham|nonspam'			=> sub { $isspam = 0; },
	     'rebuild'				=> \$rebuildonly,
	     'forget'				=> \$forget,

             'configpath|config-file|config-dir|c|C=s' => \$opt{'configpath'},
             'prefspath|prefs-file|p=s'          => \$opt{'prefspath'},
             'siteconfigpath=s'                  => \$opt{'siteconfigpath'},

	     'folders|f=s'			=> \$opt{'folders'},
             'showdots'                         => \$opt{'showdots'},
	     'no-rebuild|norebuild'		=> \$opt{'norebuild'},
	     'local|L'				=> \$opt{'local'},
	     'force-expire'			=> \$opt{'force-expire'},

             'stopafter=i'                      => \$opt{'stopafter'},
	     'learnprob=f'			=> \$opt{'learnprob'},
	     'randseed=i'			=> \$opt{'randseed'},

             'debug-level|D:s'                  => \$opt{'debug-level'},
             'version|V'                        => \$opt{'version'},
             'help|h|?'                         => \$opt{'help'},

	     'dump:s'			=> \$opt{'dump'},
	     'import'			=> \$opt{'import'},

	     'dir'			=> sub { $opt{'old_format'} = 'dir'; },
	     'file'			=> sub { $opt{'old_format'} = 'file'; },
	     'mbox'			=> sub { $opt{'format'} = 'mbox'; },
	     'single'			=> sub { $opt{'old_format'} = 'single'; },

	     'db|dbpath=s'		=> \$bayes_override_path,
	     're|regexp=s'		=> \$opt{'regexp'},

	     '<>'			=> \&target,
  ) or usage(0, "Unknown option!");

  if (defined $opt{'help'}) { usage(0, "For more information read the manual page"); }
  if (defined $opt{'version'}) {
    print "SpamAssassin version " . Mail::SpamAssassin::Version() . "\n";
    exit 0;
  }

  if ($opt{'force-expire'}) {
    $rebuildonly=1;
  }

  if ( !defined $isspam && !defined $rebuildonly && !defined $forget && !defined $opt{'dump'} && !defined $opt{'import'} && !defined $opt{'folders'} ) {
    usage(0, "Please select either --spam, --ham, --folders, --forget, --rebuild, --import or --dump");
  }

  # We need to make sure the journal syncs pre-forget...
  if ( defined $forget && $opt{'norebuild'} ) {
    $opt{'norebuild'} = 0;
    warn "sa-learn warning: --forget requires read/write access to the database, and is incompatible with --no-rebuild\n";
  }

  if (defined $opt{'old_format'}) {
    #Format specified in the 2.5x form of --dir, --file, --mbox or --single.
    #Convert it to the new behavior:
    if($opt{'old_format'} eq 'single') {
      push (@ARGV, '-');
    }
  }

  # create the tester factory
  $spamtest = new Mail::SpamAssassin ({
    rules_filename      => $opt{'configpath'},
    site_rules_filename => $opt{'siteconfigpath'},
    userprefs_filename  => $opt{'prefspath'},
    debug               => defined($opt{'debug-level'}),
    local_tests_only    => 1,
    dont_copy_prefs     => 1,
    PREFIX              => $main::PREFIX,
    DEF_RULES_DIR       => $main::DEF_RULES_DIR,
    LOCAL_RULES_DIR     => $main::LOCAL_RULES_DIR,
  });

  $spamtest->init (1);

  # Add a default prefix if the path is a directory
  if (defined $bayes_override_path && -d $bayes_override_path) {
    $bayes_override_path = File::Spec->catfile($bayes_override_path, 'bayes');
  }

  if (defined $opt{'dump'}) {
    my($magic, $toks);

    if ($opt{'dump'} eq 'all' || $opt{'dump'} eq '') {	# show us all tokens!
      ($magic, $toks) = (1,1);
    }
    elsif ($opt{'dump'} eq 'magic') {		# show us magic tokens only
      ($magic, $toks) = (1,0);
    }
    elsif ($opt{'dump'} eq 'data') {		# show us data tokens only
      ($magic, $toks) = (0,1);
    }
    else {					# unknown option
      warn "Unknown dump option '".$opt{'dump'}."'\n";
      $spamtest->finish_learner();
      return 1;
    }

    # kluge to support old check_bayes_db operation
    if ( defined $bayes_override_path ) {
      # init() above ties to the db r/o and leaves it that way
      # so we need to untie before dumping (it'll reopen)
      $spamtest->finish_learner();
      $spamtest->{conf}->{bayes_path} = $bayes_override_path;
    }

    $spamtest->dump_bayes_db($magic, $toks, $opt{'regexp'});
    $spamtest->finish_learner();
    return 0;
  }

  if (defined $opt{'import'}) {
    if ( defined $bayes_override_path ) {
      # init() above ties to the db r/o and leaves it that way
      # so we need to untie before dumping (it'll reopen)
      $spamtest->finish_learner();
      $spamtest->{conf}->{bayes_path} = $bayes_override_path;
    }

    my $ret = $spamtest->{bayes_scanner}->{store}->upgrade_old_dbm_files();
    $spamtest->finish_learner();
    return (!(defined $ret && $ret == 2));
  }

  $spamtest->init_learner({
      force_expire	=> $opt{'force-expire'},
      learn_to_journal	=> $opt{'norebuild'},
      wait_for_lock	=> 1,
      caller_will_untie	=> 1
  });

  if ($rebuildonly) {
    $spamtest->rebuild_learner_caches({
		verbose => 1,
		showdots => \$opt{'showdots'}
    });
    $spamtest->finish_learner();
    return 0;
  }

  $messagelimit = $opt{'stopafter'};
  $learnprob = $opt{'learnprob'};

  if (defined $opt{'randseed'}) {
    srand ($opt{'randseed'});
  }

  # sync the journal first if we're going to go r/w so we make sure to
  # learn everything before doing anything else.
  #
  if (!$opt{norebuild}) {
    $spamtest->rebuild_learner_caches();
  }

  # run this lot in an eval block, so we can catch die's and clear
  # up the dbs.
  eval {
    $SIG{INT} = \&killed;
    $SIG{TERM} = \&killed;

    if ($opt{folders}) {
# CPU2006
#      open (F, $opt{folders}) || die $!;
#      while (<F>) {
      my $ifh = new IO::File $opt{folders};
      while (defined($_ = $ifh->read())) {
	chomp;
	if (/^(?:ham|spam):/) {
	  push(@targets, $_);
	}
	target($_);
      }
#      close (F);
      $ifh->close();
    }

    # add leftover args as targets
    foreach (@ARGV) { target($_); }

    #No arguments means they want stdin:
    if($#targets < 0) {
      target('-');
    }

    my $iter = new Mail::SpamAssassin::ArchiveIterator ({
	'opt_j' => 1,
	'opt_n' => 1,
	'opt_all' => 1,
    });

    $iter->set_functions(\&wanted, sub { });
    $messagecount = 0;
    $learnedcount = 0;

    eval {
      $iter->run (@targets);
    };
    if ($@) { die $@ unless ($@ =~ /HITLIMIT/); }

    print STDERR "\n" if ($opt{showdots});
    print "Learned from $learnedcount message(s) ($messagecount message(s) examined).\n";
  };

  if ($@) {
    my $failure = $@;
    $spamtest->finish_learner();
    die $failure;
  }

  $spamtest->finish_learner();
  return 0;
}

sub killed {
  $spamtest->finish_learner();
  die "interrupted";
}

sub target  {
  my ($target) = @_;

  my $class = ($isspam ? "spam" : "ham");
  my $format = (defined($opt{'format'}) ? $opt{'format'} : "detect");

  push (@targets, "$class:$format:$target");
}

###########################################################################

sub wanted {
  my ($id, $time, $dataref) = @_;

  if (defined($learnprob)) {
    if (int (rand (1/$learnprob)) != 0) {
      print STDERR '_' if ($opt{showdots});
      return;
    }
  }

  if (defined($messagelimit) && $learnedcount > $messagelimit)
					{ die 'HITLIMIT'; }

  $messagecount++;
  my $ma = Mail::SpamAssassin::NoMailAudit->new ('data' => $dataref);

  if ($ma->get ("X-Spam-Checker-Version")) {
    my $newtext = $spamtest->remove_spamassassin_markup($ma);
    my @newtext = split (/^/m, $newtext);
    $dataref = \@newtext;
    $ma = Mail::SpamAssassin::NoMailAudit->new ('data' => $dataref);
  }

  $ma->{noexit} = 1;
  my $status = $spamtest->learn ($ma, undef, $isspam, $forget);

  if ($status->did_learn()) {
    $learnedcount++;
  }

  $status->finish();
  undef $ma;            # clean 'em up
  undef $status;

  print STDERR '.' if ($opt{showdots});
}

###########################################################################

sub usage {
    my ($verbose, $message) = @_;
    my $ver = Mail::SpamAssassin::Version();
    print "SpamAssassin version $ver\n";
    pod2usage(-verbose => $verbose, -message => $message, -exitval => 64);
}

1;
