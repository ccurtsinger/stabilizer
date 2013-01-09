package Mail::SpamAssassin::BayesStore;

use strict;
use bytes;
use Fcntl;
# CPU2006
use IO::File;

use Mail::SpamAssassin;
use Mail::SpamAssassin::Util;
use File::Basename;
use File::Spec;
use File::Path;

use constant HAS_DB_FILE => eval { require DB_File; };

use vars qw{
  @ISA
  @DBNAMES @DB_EXTENSIONS
  $NSPAM_MAGIC_TOKEN $NHAM_MAGIC_TOKEN $LAST_EXPIRE_MAGIC_TOKEN $LAST_JOURNAL_SYNC_MAGIC_TOKEN
  $NTOKENS_MAGIC_TOKEN $OLDEST_TOKEN_AGE_MAGIC_TOKEN $LAST_EXPIRE_REDUCE_MAGIC_TOKEN
  $RUNNING_EXPIRE_MAGIC_TOKEN $DB_VERSION_MAGIC_TOKEN $LAST_ATIME_DELTA_MAGIC_TOKEN
  $NEWEST_TOKEN_AGE_MAGIC_TOKEN
};

@ISA = qw();

# db layout (quoting Matt):
#
# > need five db files though to make it real fast:
# [probs] 1. ngood and nbad (two entries, so could be a flat file rather 
# than a db file).	(now 2 entries in db_toks)
# [toks]  2. good token -> number seen
# [toks]  3. bad token -> number seen (both are packed into 1 entry in 1 db)
# [probs]  4. Consolidated good token -> probability
# [probs]  5. Consolidated bad token -> probability
# > As you add new mails, you update the entry in 2 or 3, then regenerate
# > the entry for that token in 4 or 5.
# > Then as you test a new mail, you just need to pull the probability
# > direct from 4 and 5, and generate the overall probability. A simple and
# > very fast operation. 
#
# jm: we use probs as overall probability. <0.5 = ham, >0.5 = spam
#
# update: probs is no longer maintained as a db, to keep on-disk and in-core
# usage down.
#
# also, added a new one to support forgetting, auto-learning, and
# auto-forgetting for refiled mails:
# [seen]  6. a list of Message-IDs of messages already learnt from. values
# are 's' for learnt-as-spam, 'h' for learnt-as-ham.
#
# and another, called [scancount] to model the scan-count for expiry.
# This is not a database.  Instead it increases by one byte for each
# message scanned (note: scanned, not learned).

@DBNAMES = qw(toks seen);

# Possible file extensions used by the kinds of database files DB_File
# might create.  We need these so we can create a new file and rename
# it into place.
@DB_EXTENSIONS = ('', '.db');

# These are the magic tokens we use to track stuff in the DB.
# The format is '^M^A^G^I^C' followed by any string you want.
# None of the control chars will be in a real token.
$DB_VERSION_MAGIC_TOKEN		= "\015\001\007\011\003DBVERSION";
$LAST_ATIME_DELTA_MAGIC_TOKEN	= "\015\001\007\011\003LASTATIMEDELTA";
$LAST_EXPIRE_MAGIC_TOKEN	= "\015\001\007\011\003LASTEXPIRE";
$LAST_EXPIRE_REDUCE_MAGIC_TOKEN	= "\015\001\007\011\003LASTEXPIREREDUCE";
$LAST_JOURNAL_SYNC_MAGIC_TOKEN	= "\015\001\007\011\003LASTJOURNALSYNC";
$NEWEST_TOKEN_AGE_MAGIC_TOKEN	= "\015\001\007\011\003NEWESTAGE";
$NHAM_MAGIC_TOKEN		= "\015\001\007\011\003NHAM";
$NSPAM_MAGIC_TOKEN		= "\015\001\007\011\003NSPAM";
$NTOKENS_MAGIC_TOKEN		= "\015\001\007\011\003NTOKENS";
$OLDEST_TOKEN_AGE_MAGIC_TOKEN	= "\015\001\007\011\003OLDESTAGE";
$RUNNING_EXPIRE_MAGIC_TOKEN	= "\015\001\007\011\003RUNNINGEXPIRE";

use constant DB_VERSION => 2;	# what version of DB do we use?

###########################################################################

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my ($bayes) = @_;
  my $self = {
    'bayes'             => $bayes,
    'already_tied'	=> 0,
    'is_locked'		=> 0,
    'string_to_journal' => '',
    'db_version'	=> undef,
  };
  bless ($self, $class);

  $self;
}

###########################################################################

sub read_db_configs {
  my ($self) = @_;

  # TODO: at some stage, this may be useful to read config items which
  # control database bloat, like
  #
  # - use of hapaxes
  # - use of case-sensitivity
  # - more midrange-hapax-avoidance tactics when parsing headers (future)
  # 
  # for now, we just set these settings statically.
  my $conf = $self->{bayes}->{main}->{conf};

  # Minimum desired database size?  Expiry will not shrink the
  # database below this number of entries.  100k entries is roughly
  # equivalent to a 5Mb database file.
  $self->{expiry_max_db_size} = $conf->{bayes_expiry_max_db_size};

  $self->{bayes}->read_db_configs();
}

###########################################################################

sub tie_db_readonly {
  my ($self) = @_;
  my $main = $self->{bayes}->{main};

  # return if we've already tied to the db's, using the same mode
  # (locked/unlocked) as before.
  return 1 if ($self->{already_tied} && $self->{is_locked} == 0);
  $self->{already_tied} = 1;

  $self->read_db_configs();

  if (!defined($main->{conf}->{bayes_path})) {
    dbg ("bayes_path not defined");
    return 0;
  }
  if (!HAS_DB_FILE) {
    dbg ("bayes: DB_File module not installed, cannot use Bayes");
    return 0;
  }

  my $path = $main->sed_path ($main->{conf}->{bayes_path});

  my $found=0;
# CPU2006
#  for my $ext (@DB_EXTENSIONS) { if (-f $path.'_toks'.$ext) { $found=1; last; } }
  for my $ext (@DB_EXTENSIONS) { if (DB_File::ftest($path.'_toks'.$ext)) { $found=1; last; } }

  if (!$found) {
    dbg ("bayes: no dbs present, cannot scan: ${path}_toks");
    return 0;
  }

  foreach my $dbname (@DBNAMES) {
    my $name = $path.'_'.$dbname;
    my $db_var = 'db_'.$dbname;
    dbg("bayes: $$ tie-ing to DB file R/O $name");
    # untie %{$self->{$db_var}} if (tied %{$self->{$db_var}});
    tie %{$self->{$db_var}},"DB_File",$name, O_RDONLY,
		 (oct ($main->{conf}->{bayes_file_mode}) & 0666)
       or goto failed_to_tie;
  }

  $self->{db_version} = ($self->get_magic_tokens())[6];
  dbg("bayes: found bayes db version ".$self->{db_version});

  # If the DB version is one we don't understand, abort!
  if ( $self->check_db_version() ) {
    dbg("bayes: bayes db version ".$self->{db_version}." is newer than we understand, aborting!");
    $self->untie_db();
    return 0;
  }

  if ( $self->{db_version} < 2 ) { # older versions use scancount
    $self->{scan_count_little_file} = $path.'_msgcount';
  }
  return 1;

failed_to_tie:
  warn "Cannot open bayes databases ${path}_* R/O: tie failed: $!\n";
  return 0;
}

# tie() to the databases, read-write and locked.  Any callers of
# this should ensure they call untie_db() afterwards!
#
sub tie_db_writable {
  my ($self) = @_;
  my $main = $self->{bayes}->{main};

  # return if we've already tied to the db's, using the same mode
  # (locked/unlocked) as before.
  return 1 if ($self->{already_tied} && $self->{is_locked} == 1);
  $self->{already_tied} = 1;

  $self->read_db_configs();

  if (!defined($main->{conf}->{bayes_path})) {
    dbg ("bayes_path not defined");
    return 0;
  }
  if (!HAS_DB_FILE) {
    dbg ("bayes: DB_File module not installed, cannot use Bayes");
    return 0;
  }

  my $path = $main->sed_path ($main->{conf}->{bayes_path});

  my $found=0;
# CPU2006
#  for my $ext (@DB_EXTENSIONS) { if (-f $path.'_toks'.$ext) { $found=1; last; } }
  for my $ext (@DB_EXTENSIONS) { if (DB_File::ftest($path.'_toks'.$ext)) { $found=1; last; } }

# CPU2006 -- no need to make directories
#  my $parentdir = dirname ($path);
#  if (!-d $parentdir) {
#    # run in an eval(); if mkpath has no perms, it calls die()
#    eval {
#      mkpath ($parentdir, 0, (oct ($main->{conf}->{bayes_file_mode}) & 0777));
#    };
#  }

  my $tout;
  if ($main->{learn_wait_for_lock}) {
    $tout = 300;       # TODO: Dan to write better lock code
  } else {
    $tout = 10;
  }
  if ($main->{locker}->safe_lock ($path, $tout)) {
    $self->{locked_file} = $path;
    $self->{is_locked} = 1;
  } else {
    warn "Cannot open bayes databases ${path}_* R/W: lock failed: $!\n";
    return 0;
  }

  my $umask = umask 0;
  foreach my $dbname (@DBNAMES) {
    my $name = $path.'_'.$dbname;
    my $db_var = 'db_'.$dbname;
    dbg("bayes: $$ tie-ing to DB file R/W $name");
    tie %{$self->{$db_var}},"DB_File",$name, O_RDWR|O_CREAT,
		 (oct ($main->{conf}->{bayes_file_mode}) & 0666)
       or goto failed_to_tie;
  }
  umask $umask;

  # set our cache to what version DB we're using
  $self->{db_version} = ($self->get_magic_tokens())[6];
  dbg("bayes: found bayes db version ".$self->{db_version});

  # figure out if we can read the current DB and if we need to do a
  # DB version update and do it if necessary if either has a problem,
  # fail immediately
  #
  if ( $found && $self->upgrade_db() ) {
    $self->untie_db();
    return 0;
  }
  elsif ( !$found ) { # new DB, make sure we know that ...
    $self->{db_version} = $self->{db_toks}->{$DB_VERSION_MAGIC_TOKEN} = DB_VERSION;
    $self->{db_toks}->{$NTOKENS_MAGIC_TOKEN} = 0; # no tokens in the db ...
    dbg("bayes: new db, set db version ".$self->{db_version}." and 0 tokens");
  }

  return 1;

failed_to_tie:
  my $err = $!;
  umask $umask;
  if ($self->{is_locked}) {
    $self->{bayes}->{main}->{locker}->safe_unlock ($self->{locked_file});
    $self->{is_locked} = 0;
  }
  warn "Cannot open bayes databases ${path}_* R/W: tie failed: $err\n";
  return 0;
}

# Do we understand how to deal with this DB version?
sub check_db_version {
  my ($self) = @_;
  my $db_ver = ($self->get_magic_tokens())[6];

  if ( $db_ver > DB_VERSION ) { # current DB is newer, ignore the DB!
    warn "bayes: Found DB Version $db_ver, but can only handle up to version ".DB_VERSION."\n";
    return 1;
  }

  return 0;
}

# Check to see if we need to upgrade the DB, and do so if necessary
sub upgrade_db {
  my ($self) = @_;

  return 0 if ( $self->{db_version} == DB_VERSION );
  if ( $self->check_db_version() ) {
    dbg("bayes: bayes db version ".$self->{db_version}." is newer than we understand, aborting!");
    return 1;
  }

  # If the current DB version is lower than the new version, upgrade!
  # Do conversions in order so we can go 1 -> 3, make sure to update $self->{db_version}

  dbg("bayes: detected bayes db format ".$self->{db_version}.", upgrading");

  # since DB_File will not shrink a database (!!), we need to *create*
  # a new one instead.
  my $main = $self->{bayes}->{main};
  my $path = $main->sed_path ($main->{conf}->{bayes_path});
  my $name = $path.'_toks';

  # older version's journal files are likely not in the same format as the new ones, so remove it.
# CPU2006
#  my $jpath = $self->get_journal_filename();
#  if ( -f $jpath ) {
#    dbg("bayes: old journal file found, removing.");
#    warn "Couldn't remove $jpath: $!" if ( !unlink $jpath );
#  }

  if ( $self->{db_version} < 2 ) {
    dbg ("bayes: upgrading database format from v".$self->{db_version}." to v2");

    my($DB_NSPAM_MAGIC_TOKEN, $DB_NHAM_MAGIC_TOKEN, $DB_NTOKENS_MAGIC_TOKEN);
    my($DB_OLDEST_TOKEN_AGE_MAGIC_TOKEN, $DB_LAST_EXPIRE_MAGIC_TOKEN);

    # Magic tokens for version 0, defined as '**[A-Z]+'
    if ( $self->{db_version} == 0 ) {
      $DB_NSPAM_MAGIC_TOKEN			= '**NSPAM';
      $DB_NHAM_MAGIC_TOKEN			= '**NHAM';
      $DB_NTOKENS_MAGIC_TOKEN			= '**NTOKENS';
      #$DB_OLDEST_TOKEN_AGE_MAGIC_TOKEN		= '**OLDESTAGE';
      #$DB_LAST_EXPIRE_MAGIC_TOKEN		= '**LASTEXPIRE';
      #$DB_SCANCOUNT_BASE_MAGIC_TOKEN		= '**SCANBASE';
      #$DB_RUNNING_EXPIRE_MAGIC_TOKEN		= '**RUNNINGEXPIRE';
    }
    else {
      $DB_NSPAM_MAGIC_TOKEN			= "\015\001\007\011\003NSPAM";
      $DB_NHAM_MAGIC_TOKEN			= "\015\001\007\011\003NHAM";
      $DB_NTOKENS_MAGIC_TOKEN			= "\015\001\007\011\003NTOKENS";
      #$DB_OLDEST_TOKEN_AGE_MAGIC_TOKEN		= "\015\001\007\011\003OLDESTAGE";
      #$DB_LAST_EXPIRE_MAGIC_TOKEN		= "\015\001\007\011\003LASTEXPIRE";
      #$DB_SCANCOUNT_BASE_MAGIC_TOKEN		= "\015\001\007\011\003SCANBASE";
      #$DB_RUNNING_EXPIRE_MAGIC_TOKEN		= "\015\001\007\011\003RUNNINGEXPIRE";
    }

    # remember when we started ...
# CPU2006 -- we started a long time ago
#    my $started = time;
    my $started = 879170400;
    my $newatime = $started;

    # use O_EXCL to avoid races (bonus paranoia, since we should be locked
    # anyway)
    my %new_toks;
    my $umask = umask 0;
    tie %new_toks, "DB_File", "${name}.new", O_RDWR|O_CREAT|O_EXCL,
          (oct ($main->{conf}->{bayes_file_mode}) & 0666) or return 1;
    umask $umask;

    # add the magic tokens to the new db.
    $new_toks{$NSPAM_MAGIC_TOKEN} = $self->{db_toks}->{$DB_NSPAM_MAGIC_TOKEN};
    $new_toks{$NHAM_MAGIC_TOKEN} = $self->{db_toks}->{$DB_NHAM_MAGIC_TOKEN};
    $new_toks{$NTOKENS_MAGIC_TOKEN} = $self->{db_toks}->{$DB_NTOKENS_MAGIC_TOKEN};
    $new_toks{$DB_VERSION_MAGIC_TOKEN} = 2; # we're now a DB version 2 file
    $new_toks{$OLDEST_TOKEN_AGE_MAGIC_TOKEN} = $newatime;
    $new_toks{$LAST_EXPIRE_MAGIC_TOKEN} = $newatime;
    $new_toks{$NEWEST_TOKEN_AGE_MAGIC_TOKEN} = $newatime;
    $new_toks{$LAST_JOURNAL_SYNC_MAGIC_TOKEN} = $newatime;
    $new_toks{$LAST_ATIME_DELTA_MAGIC_TOKEN} = 0;
    $new_toks{$LAST_EXPIRE_REDUCE_MAGIC_TOKEN} = 0;

    my $magic_re = $self->get_magic_re($self->{db_version});

    # deal with the data tokens
    my ($tok, $packed);
    while (($tok, $packed) = each %{$self->{db_toks}}) {
      next if ($tok =~ /$magic_re/); # skip magic tokens

      my ($ts, $th, $atime) = $self->tok_unpack ($packed);
      $new_toks{$tok} = $self->tok_pack ($ts, $th, $newatime);
    }


    # now untie so we can do renames
    untie %{$self->{db_toks}};
    untie %new_toks;

    # This is the critical phase (moving files around), so don't allow
    # it to be interrupted.
    local $SIG{'INT'} = 'IGNORE';
    local $SIG{'HUP'} = 'IGNORE';
    local $SIG{'TERM'} = 'IGNORE';

    # older versions used scancount, so kill the stupid little file ...
# CPU2006
#    my $msgc = $path.'_msgcount';
#    if ( -f $msgc ) {
#      dbg("bayes: old msgcount file found, removing.");
#      if ( !unlink $msgc ) {
#        warn "Couldn't remove $msgc: $!";
#      }
#    }

    # now rename in the new one.  Try several extensions
    for my $ext (@DB_EXTENSIONS) {
      my $newf = $name.'.new'.$ext;
      my $oldf = $name.$ext;
# CPU2006
#      next unless (-f $newf);
#      if (!rename ($newf, $oldf)) {
      next unless (DB_File::ftest($newf));
      if (!DB_File::rename ($newf, $oldf)) {
        warn "rename $newf to $oldf failed: $!\n";
        return 1;
      }
    }

    # re-tie to the new db in read-write mode ...
    tie %{$self->{db_toks}},"DB_File", $name, O_RDWR|O_CREAT,
	 (oct ($main->{conf}->{bayes_file_mode}) & 0666) or return 1;

# CPU2006 - not now
#    dbg ("bayes: upgraded database format from v".$self->{db_version}." to v2 in ".(time - $started)." seconds");
    dbg ("bayes: upgraded database format from v".$self->{db_version}." to v2 in a very short period of time");
    $self->{db_version} = 2; # need this for other functions which check
  }

  # if ( $self->{db_version} == 2 ) {
  #   ...
  #   $self->{db_version} = 3; # need this for other functions which check
  # }
  # ... and so on.

  return 0;
}

###########################################################################

sub untie_db {
  my $self = shift;
  dbg("bayes: $$ untie-ing");

  foreach my $dbname (@DBNAMES) {
    my $db_var = 'db_'.$dbname;

    if (exists $self->{$db_var}) {
      dbg ("bayes: $$ untie-ing $db_var");
      untie %{$self->{$db_var}};
      delete $self->{$db_var};
    }
  }

  if ($self->{is_locked}) {
    dbg ("bayes: files locked, now unlocking lock");
    $self->{bayes}->{main}->{locker}->safe_unlock ($self->{locked_file});
    $self->{is_locked} = 0;
  }

  $self->{already_tied} = 0;
  $self->{db_version} = undef;
}

###########################################################################

# Do an expiry run.
sub expire_old_tokens {
  my ($self, $opts) = @_;
  my $ret;

  eval {
    local $SIG{'__DIE__'};	# do not run user die() traps in here
    if ($self->tie_db_writable()) {
      $ret = $self->expire_old_tokens_trapped ($opts);
    }
  };
  my $err = $@;

  if (!$self->{bayes}->{main}->{learn_caller_will_untie}) {
    $self->untie_db();
  }

  if ($err) {		# if we died, untie the dbs.
    warn "bayes expire_old_tokens: $err\n";
    return 0;
  }
  $ret;
}

sub expire_old_tokens_trapped {
  my ($self, $opts) = @_;

  # Flag that we're doing work
  $self->set_running_expire_tok();

  # We don't need to do an expire, so why were we called?  Oh well.
  if (!$self->expiry_due()) {
    $self->remove_running_expire_tok();
    return 0;
  }

  my $deleted = 0;
  my $kept = 0;
  my $num_lowfreq = 0;
  my $num_hapaxes = 0;
# CPU2006 - started a long time ago
#  my $started = time();
  my $started = 831646800;
  my @magic = $self->get_magic_tokens();

  # since DB_File will not shrink a database (!!), we need to *create*
  # a new one instead.
  my $main = $self->{bayes}->{main};
  my $path = $main->sed_path ($main->{conf}->{bayes_path});
  my $name = $path.'_toks.new';

  my $magic_re = $self->get_magic_re(DB_VERSION);

  # Figure out atime delta as necessary
  my $too_old = 0;

  # How many tokens do we want to keep?
  my $goal_reduction = int($self->{expiry_max_db_size} * 0.75); # expire to 75% of max_db
  dbg("bayes: expiry check keep size, 75% of max: $goal_reduction");
  # Make sure we keep at least 100000 tokens in the DB
  if ( $goal_reduction < 100000 ) {
    $goal_reduction = 100000;
    dbg("bayes: expiry keep size too small, resetting to 100,000 tokens");
  }
  # Now turn goal_reduction into how many to expire.
  $goal_reduction = $magic[3] - $goal_reduction;
  dbg("bayes: token count: ".$magic[3].", final goal reduction size: $goal_reduction");

  if ( $goal_reduction < 1000 ) { # too few tokens to expire, abort.
    dbg("bayes: reduction goal of $goal_reduction is under 1,000 tokens.  skipping expire.");
    $self->{db_toks}->{$LAST_EXPIRE_MAGIC_TOKEN} = time();
    $self->remove_running_expire_tok(); # this won't be cleaned up, so do it now.
    return 1; # we want to indicate things ran as expected
  }

  # Estimate new atime delta based on the last atime delta
  my $newdelta = 0;
  if ( $magic[9] > 0 ) {
    # newdelta = olddelta * old / goal;
    # this may seem backwards, but since we're talking delta here,
    # not actual atime, we want smaller atimes to expire more tokens,
    # and visa versa.
    #
    $newdelta = int($magic[8] * $magic[9] / $goal_reduction);
  }

  # Calculate size difference between last expiration token removal
  # count and the current goal removal count.
  my $ratio = ($magic[9] == 0 || $magic[9] > $goal_reduction) ? $magic[9]/$goal_reduction : $goal_reduction/$magic[9];

# CPU2006 -- just in case
#  dbg("bayes: First pass?  Current: ".time().", Last: ".$magic[4].", atime: ".$magic[8].", count: ".$magic[9].", newdelta: $newdelta, ratio: $ratio");
  dbg("bayes: First pass?  Current: now, Last: ".$magic[4].", atime: ".$magic[8].", count: ".$magic[9].", newdelta: $newdelta, ratio: $ratio");

  ## ESTIMATION PHASE
  #
  # Do this for the first expire or "odd" looking results cause a first pass to determine atime:
  #
  # - last expire was more than 30 days ago
  #   assume mail flow stays roughly the same month to month, recompute if it's > 1 month
  # - last atime delta was under 12hrs
  #   if we're expiring often max_db_size should go up, but let's recompute just to check
  # - last reduction count was < 1000 tokens
  #   ditto
  # - new estimated atime delta is under 12hrs
  #   ditto
  # - difference of last reduction to current goal reduction is > 50%
  #   if the two values are out of balance, estimating atime is going to be funky, recompute
  #
  if ( (time() - $magic[4] > 86400*30) || ($magic[8] < 43200) || ($magic[9] < 1000) || ($newdelta < 43200) || ($ratio > 1.5) ) {
    dbg("bayes: something fishy, calculating atime (first pass)");
    my $start = 43200; # exponential search starting at ...?  1/2 day, 1, 2, 4, 8, 16, ...
    my %delta = (); # use a hash since an array is going to be very sparse
    my $max_expire_mult = 512; # $max_expire_mult * $start = max expire time (256 days), power of 2.

    # do the first pass, figure out atime delta
    my ($tok, $packed);
    while (($tok, $packed) = each %{$self->{db_toks}}) {
      next if ($tok =~ /$magic_re/); # skip magic tokens

      my ($ts, $th, $atime) = $self->tok_unpack ($packed);

      # Go through from $start * 1 to $start * 512, mark how many tokens we would expire
      my $token_age = $magic[10] - $atime;
      for( my $i = 1; $i <= $max_expire_mult; $i<<=1 ) {
        if ( $token_age >= $start * $i ) {
          $delta{$i}++;
	}
	else {
	  # If the token age is less than the expire delta, it'll be
	  # less for all upcoming checks too, so abort early.
	  last;
	}
      }
    }

    # Now figure out which max_expire_mult value gives the closest results to goal_reduction, without
    # going over ...  Go from the largest delta backwards so the reduction size increases
    # (tokens that expire at 4 also expire at 3, 2, and 1, so 1 will always be the largest expiry...)
    #
    for( ; $max_expire_mult > 0; $max_expire_mult>>=1 ) {
      next unless exists $delta{$max_expire_mult};
      if ($delta{$max_expire_mult} > $goal_reduction) {
        $max_expire_mult<<=1; # the max expire is actually the next power of 2 out
	last;
      }
    }

    # if max_expire_mult gets to 0, either we can't expire anything, or 1 is <= $goal_reduction
    $max_expire_mult ||= 1;

    # $max_expire_mult is now equal to the value we should use ...
    # Check to see if the atime value we found is really good.
    # It's not good if:
    # - $max_expire_mult would not expire any tokens.  This means that the majority of
    #   tokens are old or new, and more activity is required before an expiry can occur.
    # - reduction count < 1000, not enough tokens to be worth doing an expire.
    #
    if ( !exists $delta{$max_expire_mult} || $delta{$max_expire_mult} < 1000 ) {
      dbg("bayes: couldn't find a good delta atime, need more token difference, skipping expire.");
      $self->{db_toks}->{$LAST_EXPIRE_MAGIC_TOKEN} = time();
      $self->remove_running_expire_tok(); # this won't be cleaned up, so do it now.
      return 1; # we want to indicate things ran as expected
    }

    $newdelta = $start * $max_expire_mult;
  }
  else { # use the estimation method
    dbg("bayes: Can do estimation method for expiry, skipping first pass.");
  }

  # use O_EXCL to avoid races (bonus paranoia, since we should be locked
  # anyway)
  my %new_toks;
  my $umask = umask 0;
  tie %new_toks, "DB_File", $name, O_RDWR|O_CREAT|O_EXCL,
	       (oct ($main->{conf}->{bayes_file_mode}) & 0666);
  umask $umask;
  my $oldest;

  my $showdots = $opts->{showdots};
  if ($showdots) { print STDERR "\n"; }

  # We've chosen a new atime delta if we've gotten here, so record it for posterity.
  $new_toks{$LAST_ATIME_DELTA_MAGIC_TOKEN} = $newdelta;

  # Figure out how old is too old...
  $too_old = $magic[10] - $newdelta; # tooold = newest - delta

  # Go ahead and do the move to new db/expire run now ...
  my ($tok, $packed);
  while (($tok, $packed) = each %{$self->{db_toks}}) {
    next if ($tok =~ /$magic_re/); # skip magic tokens

    my ($ts, $th, $atime) = $self->tok_unpack ($packed);

    if ($atime < $too_old) {
      $deleted++;
    } else {
      $new_toks{$tok} = $self->tok_pack ($ts, $th, $atime); $kept++;
      if (!defined($oldest) || $atime < $oldest) { $oldest = $atime; }
      if ($ts + $th == 1) {
	$num_hapaxes++;
      } elsif ($ts < 8 && $th < 8) {
	$num_lowfreq++;
      }
    }

    if ((($kept + $deleted) % 1000) == 0) {
      if ($showdots) { print STDERR "."; }
      $self->set_running_expire_tok();
    }
  }

  # and add the magic tokens.  don't add the expire_running token.
  $new_toks{$DB_VERSION_MAGIC_TOKEN} = DB_VERSION;

  # We haven't changed messages of each type seen, so just copy over.
  $new_toks{$NSPAM_MAGIC_TOKEN} = $magic[1];
  $new_toks{$NHAM_MAGIC_TOKEN} = $magic[2];

  # We magically haven't removed the newest token, so just copy that value over.
  $new_toks{$NEWEST_TOKEN_AGE_MAGIC_TOKEN} = $magic[10];

  # The rest of these have been modified, so replace as necessary.
  $new_toks{$NTOKENS_MAGIC_TOKEN} = $kept;
  $new_toks{$LAST_EXPIRE_MAGIC_TOKEN} = time();
  $new_toks{$OLDEST_TOKEN_AGE_MAGIC_TOKEN} = $oldest;
  $new_toks{$LAST_EXPIRE_REDUCE_MAGIC_TOKEN} = $deleted;

  # now untie so we can do renames
  untie %{$self->{db_toks}};
  untie %new_toks;

  # This is the critical phase (moving files around), so don't allow
  # it to be interrupted.  Scope the signal changes.
  {
    local $SIG{'INT'} = 'IGNORE';
    local $SIG{'HUP'} = 'IGNORE';
    local $SIG{'TERM'} = 'IGNORE';

    # now rename in the new one.  Try several extensions
    for my $ext (@DB_EXTENSIONS) {
      my $newf = $path.'_toks.new'.$ext;
      my $oldf = $path.'_toks'.$ext;
# CPU2006
#      next unless (-f $newf);
#      if (!rename ($newf, $oldf)) {
      next unless (DB_File::ftest($newf));
      if (!DB_File::rename ($newf, $oldf)) {
	warn "rename $newf to $oldf failed: $!\n";
      }
    }
  }

  # Call untie_db() so we unlock correctly.
  $self->untie_db();

  my $done = time();

# CPU2006 -- just in the interest of validation
#  my $msg = "expired old Bayes database entries in ".($done - $started)." seconds";
  my $msg = "expired old Bayes database entries in not too many seconds";
  my $msg2 = "$kept entries kept, $deleted deleted";

  if ($opts->{verbose}) {
    my $hapax_pc = ($num_hapaxes * 100) / $kept;
    my $lowfreq_pc = ($num_lowfreq * 100) / $kept;
    print "$msg\n$msg2\n";
    printf "token frequency: 1-occurence tokens: %3.2f%%\n", $hapax_pc;
    printf "token frequency: less than 8 occurrences: %3.2f%%\n", $lowfreq_pc;
  } else {
    dbg ("$msg: $msg2");
  }

  1;
}

###########################################################################

# Is a journal sync due?
sub journal_sync_due {
  my ($self) = @_;

# CPU2006 -- never sync
return 0;

  return 0 if ( $self->{db_version} < DB_VERSION ); # don't bother doing old db versions

  my $conf = $self->{bayes}->{main}->{conf};
  return 0 if ( $conf->{bayes_journal_max_size} == 0 );

  my @magic = $self->get_magic_tokens();
  dbg("Bayes DB journal sync: last sync: ".$magic[7],'bayes','-1');

  ## Ok, should we do a sync?

  # Not if the journal file doesn't exist, it's not a file, or it's 0 bytes long.
  return 0 unless (stat($self->get_journal_filename()) && -f _);

  # Yes if the file size is larger than the specified maximum size.
  return 1 if (-s _ > $conf->{bayes_journal_max_size});

  # Yes if it's been at least a day since the last sync.
  return 1 if (time - $magic[7] > 86400);

  # No, I guess not.
  return 0;
}

# Is an expiry run due to occur?
sub expiry_due {
  my ($self) = @_;

# CPU2006 -- never expire
return 0;

  $self->read_db_configs();	# make sure this has happened here

  # is the database too small for expiry?  (Do *not* use "scalar keys",
  # as this will iterate through the entire db counting them!)
  my @magic = $self->get_magic_tokens();
  my $ntoks = $magic[3];

  # If force expire was called, do the expire no matter what.
  return 1 if ($self->{bayes}->{main}->{learn_force_expire});

  my $last_expire = time() - $magic[4];
  if (!$self->{bayes}->{main}->{ignore_safety_expire_timeout}) {
    # if we're not ignoring the safety timeout, don't run an expire more
    # than once every 12 hours.
    return 0 if ($last_expire < 43200);
  }
  else {
    # if we are ignoring the safety timeout (e.g.: mass-check), still
    # limit the expiry to only one every 5 minutes.
    return 0 if ($last_expire < 300);
  }

  dbg("Bayes DB expiry: Tokens in DB: $ntoks, Expiry max size: ".$self->{expiry_max_db_size}.", Oldest atime: ".$magic[5].", Newest atime: ".$magic[10].", Last expire: ".$magic[4].", Current time: ".time(),'bayes','-1');

  my $conf = $self->{bayes}->{main}->{conf};
  if ($ntoks <= 100000 ||			# keep at least 100k tokens
      $conf->{bayes_auto_expire} == 0 ||	# config says don't expire
      $self->{expiry_max_db_size} > $ntoks ||	# not enough tokens to cause an expire
      $magic[10]-$magic[5] < 43200 ||		# delta between oldest and newest < 12h
      $self->{db_version} < DB_VERSION		# ignore old db formats
      ) {
    return 0;
  }

  return 1;
}

###########################################################################
# db_seen reading APIs

sub seen_get {
  my ($self, $msgid) = @_;
  $self->{db_seen}->{$msgid};
}

sub seen_put {
  my ($self, $msgid, $seen) = @_;

  if ($self->{bayes}->{main}->{learn_to_journal}) {
    $self->defer_update ("m $seen $msgid");
  }
  else {
    $self->{db_seen}->{$msgid} = $seen;
  }
}

sub seen_delete {
  my ($self, $msgid) = @_;

  if ($self->{bayes}->{main}->{learn_to_journal}) {
    $self->defer_update ("m f $msgid");
  }
  else {
    delete $self->{db_seen}->{$msgid};
  }
}

###########################################################################
# db reading APIs

sub tok_get {
  my ($self, $tok) = @_;
  $self->tok_unpack ($self->{db_toks}->{$tok});
}
 
sub nspam_nham_get {
  my ($self) = @_;
  my @magic = $self->get_magic_tokens();
  ($magic[1], $magic[2]);
}

# return the magic tokens in a specific order:
# 0: scan count base
# 1: number of spam
# 2: number of ham
# 3: number of tokens in db
# 4: last expire atime
# 5: oldest token in db atime
# 6: db version value
# 7: last journal sync
# 8: last atime delta
# 9: last expire reduction count
# 10: newest token in db atime
#
sub get_magic_tokens {
  my ($self) = @_;
  my @values;

  my $db_ver = $self->{db_toks}->{$DB_VERSION_MAGIC_TOKEN};
  if ( !$db_ver || $db_ver =~ /\D/ ) { $db_ver = 0; }

  if ( $db_ver == 0 ) {
    my $DB0_NSPAM_MAGIC_TOKEN = '**NSPAM';
    my $DB0_NHAM_MAGIC_TOKEN = '**NHAM';
    my $DB0_OLDEST_TOKEN_AGE_MAGIC_TOKEN = '**OLDESTAGE';
    my $DB0_LAST_EXPIRE_MAGIC_TOKEN = '**LASTEXPIRE';
    my $DB0_NTOKENS_MAGIC_TOKEN = '**NTOKENS';
    my $DB0_SCANCOUNT_BASE_MAGIC_TOKEN = '**SCANBASE';

    @values = (
      $self->{db_toks}->{$DB0_SCANCOUNT_BASE_MAGIC_TOKEN},
      $self->{db_toks}->{$DB0_NSPAM_MAGIC_TOKEN},
      $self->{db_toks}->{$DB0_NHAM_MAGIC_TOKEN},
      $self->{db_toks}->{$DB0_NTOKENS_MAGIC_TOKEN},
      $self->{db_toks}->{$DB0_LAST_EXPIRE_MAGIC_TOKEN},
      $self->{db_toks}->{$DB0_OLDEST_TOKEN_AGE_MAGIC_TOKEN},
      0,
      0,
      0,
      0,
      0,
    );
  }
  elsif ( $db_ver == 1 ) {
    my $DB1_NSPAM_MAGIC_TOKEN			= "\015\001\007\011\003NSPAM";
    my $DB1_NHAM_MAGIC_TOKEN			= "\015\001\007\011\003NHAM";
    my $DB1_OLDEST_TOKEN_AGE_MAGIC_TOKEN	= "\015\001\007\011\003OLDESTAGE";
    my $DB1_LAST_EXPIRE_MAGIC_TOKEN		= "\015\001\007\011\003LASTEXPIRE";
    my $DB1_NTOKENS_MAGIC_TOKEN			= "\015\001\007\011\003NTOKENS";
    my $DB1_SCANCOUNT_BASE_MAGIC_TOKEN		= "\015\001\007\011\003SCANBASE";

    @values = (
      $self->{db_toks}->{$DB1_SCANCOUNT_BASE_MAGIC_TOKEN},
      $self->{db_toks}->{$DB1_NSPAM_MAGIC_TOKEN},
      $self->{db_toks}->{$DB1_NHAM_MAGIC_TOKEN},
      $self->{db_toks}->{$DB1_NTOKENS_MAGIC_TOKEN},
      $self->{db_toks}->{$DB1_LAST_EXPIRE_MAGIC_TOKEN},
      $self->{db_toks}->{$DB1_OLDEST_TOKEN_AGE_MAGIC_TOKEN},
      1,
      0,
      0,
      0,
      0,
    );
  }
  elsif ( $db_ver == 2 ) {
    my $DB2_LAST_ATIME_DELTA_MAGIC_TOKEN	= "\015\001\007\011\003LASTATIMEDELTA";
    my $DB2_LAST_EXPIRE_MAGIC_TOKEN		= "\015\001\007\011\003LASTEXPIRE";
    my $DB2_LAST_EXPIRE_REDUCE_MAGIC_TOKEN	= "\015\001\007\011\003LASTEXPIREREDUCE";
    my $DB2_LAST_JOURNAL_SYNC_MAGIC_TOKEN	= "\015\001\007\011\003LASTJOURNALSYNC";
    my $DB2_NEWEST_TOKEN_AGE_MAGIC_TOKEN	= "\015\001\007\011\003NEWESTAGE";
    my $DB2_NHAM_MAGIC_TOKEN			= "\015\001\007\011\003NHAM";
    my $DB2_NSPAM_MAGIC_TOKEN			= "\015\001\007\011\003NSPAM";
    my $DB2_NTOKENS_MAGIC_TOKEN			= "\015\001\007\011\003NTOKENS";
    my $DB2_OLDEST_TOKEN_AGE_MAGIC_TOKEN	= "\015\001\007\011\003OLDESTAGE";
    my $DB2_RUNNING_EXPIRE_MAGIC_TOKEN		= "\015\001\007\011\003RUNNINGEXPIRE";

    @values = (
      0,
      $self->{db_toks}->{$DB2_NSPAM_MAGIC_TOKEN},
      $self->{db_toks}->{$DB2_NHAM_MAGIC_TOKEN},
      $self->{db_toks}->{$DB2_NTOKENS_MAGIC_TOKEN},
      $self->{db_toks}->{$DB2_LAST_EXPIRE_MAGIC_TOKEN},
      $self->{db_toks}->{$DB2_OLDEST_TOKEN_AGE_MAGIC_TOKEN},
      2,
      $self->{db_toks}->{$DB2_LAST_JOURNAL_SYNC_MAGIC_TOKEN},
      $self->{db_toks}->{$DB2_LAST_ATIME_DELTA_MAGIC_TOKEN},
      $self->{db_toks}->{$DB2_LAST_EXPIRE_REDUCE_MAGIC_TOKEN},
      $self->{db_toks}->{$DB2_NEWEST_TOKEN_AGE_MAGIC_TOKEN},
    );
  }


  foreach ( @values ) {
    if ( !$_ || $_ =~ /\D/ ) { $_ = 0; }
  }

  return @values;
}


## Don't bother using get_magic_tokens here.  This token should only
## ever exist when we're running expire, so we don't want to convert it if
## it's there and we're not expiring ...
sub get_running_expire_tok {
  my ($self) = @_;
  my $running = $self->{db_toks}->{$RUNNING_EXPIRE_MAGIC_TOKEN};
  if (!$running || $running =~ /\D/) { return undef; }
  return $running;
}

sub set_running_expire_tok {
  my ($self) = @_;
  $self->{db_toks}->{$RUNNING_EXPIRE_MAGIC_TOKEN} = time();
}

sub remove_running_expire_tok {
  my ($self) = @_;
  delete $self->{db_toks}->{$RUNNING_EXPIRE_MAGIC_TOKEN};
}

###########################################################################

# db abstraction: allow deferred writes, since we will be frequently
# writing while checking.

sub tok_count_change {
  my ($self, $ds, $dh, $tok, $atime) = @_;

  $atime = 0 unless defined $atime;

  if ($self->{bayes}->{main}->{learn_to_journal}) {
    $self->defer_update ("c $ds $dh $atime $tok");
  } else {
    $self->tok_sync_counters ($ds, $dh, $atime, $tok);
  }
}
 
sub nspam_nham_change {
  my ($self, $ds, $dh) = @_;

  if ($self->{bayes}->{main}->{learn_to_journal}) {
    $self->defer_update ("n $ds $dh");
  } else {
    $self->tok_sync_nspam_nham ($ds, $dh);
  }
}

sub tok_touch {
  my ($self, $tok, $atime) = @_;
  $self->defer_update ("t $atime $tok");
}

sub defer_update {
  my ($self, $str) = @_;
  $self->{string_to_journal} .= "$str\n";
}

###########################################################################

sub add_touches_to_journal {
  my ($self) = @_;

# CPU2006
# This has been heavily hacked to use in-memory files

  my $nbytes = length ($self->{string_to_journal});
  return if ($nbytes == 0);

  my $path = $self->get_journal_filename();

  # use append mode, write atomically, then close, so simultaneous updates are
  # not lost
  my $conf = $self->{bayes}->{main}->{conf};
  my $umask = umask(0777 - (oct ($conf->{bayes_file_mode}) & 0666));
# CPU2006
  my $ofh = new IO::File ">>".$path;
#  if (!open (OUT, ">>".$path)) {
#    warn "cannot write to $path, Bayes db update ignored\n";
#    umask $umask; # reset umask
#    return;
#  }
#
#  # do not use print() here, it will break up the buffer if it's >8192 bytes,
#  # which could result in two sets of tokens getting mixed up and their
#  # touches missed.
#  my $writ = 0;
#  while ($writ < $nbytes) {
#    my $len = syswrite (OUT, $self->{string_to_journal}, $nbytes-$writ);
#
#    if (!defined $len || $len < 0) {
#      # argh, write failure, give up
#      $len = 0 unless ( defined $len );
#      warn "write failed to Bayes journal $path ($len of $nbytes)!\n";
#      last;
#    }
#
#    $writ += $len;
#    if ($len < $nbytes) {
#      # this should not happen on filesystem writes!  Still, try to recover
#      # anyway, but be noisy about it so the admin knows
#      warn "partial write to Bayes journal $path ($len of $nbytes), recovering.\n";
#      $self->{string_to_journal} = substr ($self->{string_to_journal}, $len);
#    }
#  }
  $ofh->print($self->{string_to_journal});

# CPU2006
  $ofh->close();
#  if (!close OUT) {
#    warn "cannot write to $path, Bayes db update ignored\n";
#  }
  umask $umask; # reset umask

  $self->{string_to_journal} = '';
}

# Return a qr'd RE to match a token with the correct format's magic token
sub get_magic_re {
  my ($self, $db_ver) = @_;

  if ( $db_ver >= 1 ) {
    return qr/^\015\001\007\011\003/;
  }

  # When in doubt, assume v0
  return qr/^\*\*[A-Z]+$/;
}

###########################################################################
# And this method reads the journal and applies the changes in one
# (locked) transaction.

sub sync_journal {
  my ($self, $opts) = @_;
  my $ret = 0;

  my $path = $self->get_journal_filename();

  # if $path doesn't exist, or it's not a file, or is 0 bytes in length, return
# CPU2006
#  if ( !stat($path) || !-f _ || -z _ ) { return 0; }
   return 0 unless IO::File::ftest($path);

  eval {
    local $SIG{'__DIE__'};	# do not run user die() traps in here
    if ($self->tie_db_writable()) {
      $ret = $self->sync_journal_trapped($opts, $path);
    }
  };
  my $err = $@;

  # ok, untie from write-mode if we can
  if (!$self->{bayes}->{main}->{learn_caller_will_untie}) {
    $self->untie_db();
  }

  # handle any errors that may have occurred
  if ($err) {
    warn "bayes: $err\n";
    return 0;
  }

  $ret;
}

sub sync_journal_trapped {
  my ($self, $opts, $path) = @_;

  # Flag that we're doing work
  $self->set_running_expire_tok();

  my $started = time();
  my $count = 0;
  my $total_count = 0;
  my %tokens = ();
  my $showdots = $opts->{showdots};
  my $retirepath = $path.".old";

  # if $path doesn't exist, or it's not a file, or is 0 bytes in length, return
  # we have to check again since the file may have been removed by a recent bayes db upgrade ...
# CPU2006
#  if ( !stat($path) || !-f _ || -z _ ) { return 0; }
   return 0 unless IO::File::ftest($path);

# CPU2006
#  if (!-r $path) { # will we be able to read the file?
#    warn "bayes: bad permissions on journal, can't read: $path\n";
#    return 0;
#  }

  # This is the critical phase (moving files around), so don't allow
  # it to be interrupted.
  {
    local $SIG{'INT'} = 'IGNORE';
    local $SIG{'HUP'} = 'IGNORE';
    local $SIG{'TERM'} = 'IGNORE';

    # retire the journal, so we can update the db files from it in peace.
    # TODO: use locking here
# CPU2006
#    if (!rename ($path, $retirepath)) {
    if (!IO::File::rename ($path, $retirepath)) {
      warn "bayes: failed rename $path to $retirepath\n";
      return 0;
    }

    # now read the retired journal
# CPU2006
#    if (!open (JOURNAL, "<$retirepath")) {
    my $ifh = new IO::File "<$retirepath";
    if (!defined($ifh)) {
      warn "bayes: cannot open read $retirepath\n";
      return 0;
    }


    # Read the journal
# CPU2006
#    while (<JOURNAL>) {
    while (defined($_ = $ifh->read())) {
      $total_count++;

      if (/^t (\d+) (.*)$/) { # Token timestamp update, cache resultant entries
	$tokens{$2} = $1+0 if ( !exists $tokens{$2} || $1+0 > $tokens{$2} );
      } elsif (/^c (-?\d+) (-?\d+) (\d+) (.*)$/) { # Add/full token update
	$self->tok_sync_counters ($1+0, $2+0, $3+0, $4);
	$count++;
      } elsif (/^n (-?\d+) (-?\d+)$/) { # update ham/spam count
	$self->tok_sync_nspam_nham ($1+0, $2+0);
	$count++;
      } elsif (/^m ([hsf]) (.+)$/) { # update msgid seen database
	if ( $1 eq "f" ) {
	  $self->seen_delete($2);
	}
	else {
	  $self->seen_put($2,$1);
	}
	$count++;
      } else {
	warn "Bayes journal: gibberish entry found: $_";
      }
    }
# CPU2006
#    close JOURNAL;
    $ifh->close();

    # Now that we've determined what tokens we need to update and their
    # final values, update the DB.  Should be much smaller than the full
    # journal entries.
    while( my($k,$v) = each %tokens ) {
      $self->tok_touch_token ($v, $k);

      if ((++$count % 1000) == 0) {
	if ($showdots) { print STDERR "."; }
	$self->set_running_expire_tok();
      }
    }

    if ($showdots) { print STDERR "\n"; }

    # we're all done, so unlink the old journal file
# CPU2006
#    unlink ($retirepath) || warn "bayes: can't unlink $retirepath: $!\n";
    IO::File::unlink ($retirepath) || warn "bayes: can't unlink $retirepath: $!\n";

    $self->{db_toks}->{$LAST_JOURNAL_SYNC_MAGIC_TOKEN} = $started;

    my $done = time();
    my $msg = ("synced Bayes databases from journal in ".($done - $started).
	  " seconds: $count unique entries ($total_count total entries)");

    if ($opts->{verbose}) {
      print $msg,"\n";
    } else {
      dbg ($msg);
    }
  }

  # else, that's the lot, we're synced.  return
  1;
}

sub tok_touch_token {
  my ($self, $atime, $tok) = @_;
  my ($ts, $th, $oldatime) = $self->tok_get ($tok);

  # If the new atime is < the old atime, ignore the update
  # We figure that we'll never want to lower a token atime, so abort if
  # we try.  (journal out of sync, etc.)
  return if ( $oldatime >= $atime );

  $self->tok_put ($tok, $ts, $th, $atime);
}

sub tok_sync_counters {
  my ($self, $ds, $dh, $atime, $tok) = @_;
  my ($ts, $th, $oldatime) = $self->tok_get ($tok);
  $ts += $ds; if ($ts < 0) { $ts = 0; }
  $th += $dh; if ($th < 0) { $th = 0; }

  # Don't roll the atime of tokens backwards ...
  $atime = $oldatime if ( $oldatime > $atime );

  $self->tok_put ($tok, $ts, $th, $atime);
}

sub tok_put {
  my ($self, $tok, $ts, $th, $atime) = @_;
  $ts ||= 0;
  $th ||= 0;

  if ( $tok =~ /^\015\001\007\011\003/ ) { # magic token?  Ignore it!
    return;
  }

  # use defined() rather than exists(); the latter is not supported
  # by NDBM_File, believe it or not.  Using defined() did not
  # indicate any noticeable speed hit in my testing. (Mar 31 2003 jm)
  my $exists_already = defined $self->{db_toks}->{$tok};

  if ($ts == 0 && $th == 0) {
    return if (!$exists_already); # If the token doesn't exist, just return
    $self->{db_toks}->{$NTOKENS_MAGIC_TOKEN}--;
    delete $self->{db_toks}->{$tok};
  } else {
    if (!$exists_already) { # If the token doesn't exist, raise the token count
      $self->{db_toks}->{$NTOKENS_MAGIC_TOKEN}++;
    }

    $self->{db_toks}->{$tok} = $self->tok_pack ($ts, $th, $atime);

    my $newmagic = $self->{db_toks}->{$NEWEST_TOKEN_AGE_MAGIC_TOKEN};
    if (!defined ($newmagic) || $atime > $newmagic) {
      $self->{db_toks}->{$NEWEST_TOKEN_AGE_MAGIC_TOKEN} = $atime;
    }

    my $oldmagic = $self->{db_toks}->{$OLDEST_TOKEN_AGE_MAGIC_TOKEN};
    if (!defined ($oldmagic) || $atime < $oldmagic) {
      $self->{db_toks}->{$OLDEST_TOKEN_AGE_MAGIC_TOKEN} = $atime;
    }
  }
}

sub tok_sync_nspam_nham {
  my ($self, $ds, $dh) = @_;
  my ($ns, $nh) = ($self->get_magic_tokens())[1,2];
  if ($ds) { $ns += $ds; } if ($ns < 0) { $ns = 0; }
  if ($dh) { $nh += $dh; } if ($nh < 0) { $nh = 0; }
  $self->{db_toks}->{$NSPAM_MAGIC_TOKEN} = $ns;
  $self->{db_toks}->{$NHAM_MAGIC_TOKEN} = $nh;
}

###########################################################################

sub get_journal_filename {
  my ($self) = @_;

  if (defined $self->{journal_live_path}) {
    return $self->{journal_live_path};
  }

  my $main = $self->{bayes}->{main};
  my $fname = $main->sed_path ($main->{conf}->{bayes_path}."_journal");

  $self->{journal_live_path} = $fname;
  return $self->{journal_live_path};
}

###########################################################################

sub scan_count_get {
  my ($self) = @_;

  if ( $self->{db_version} < 2 ) {
    my ($count) = $self->get_magic_tokens();
    my $path = $self->{scan_count_little_file};
    $count += (defined $path && -e $path ? -s _ : 0);
    return $count;
  }

  0;
}

###########################################################################

# this is called directly from sa-learn(1).
sub upgrade_old_dbm_files {
  my ($self, $opts) = @_;
  my $ret = 0;

# CPU2006 -- there will never be pre-existing Bayes DBs that need upgrading
return 0;
#
#  eval {
#    local $SIG{'__DIE__'};	# do not run user die() traps in here
#
#    use File::Basename;
#    use File::Copy;
#
#    # bayes directory
#    my $main = $self->{bayes}->{main};
#    my $path = $main->sed_path($main->{conf}->{bayes_path});
#    my $dir = dirname($path);
#
#    # make temporary copy since old dbm and new dbm may have same name
#    opendir(DIR, $dir) || die "can't opendir $dir: $!";
#    my @files = grep { /^bayes_(?:seen|toks)(?:\.\w+)?$/ } readdir(DIR);
#    closedir(DIR);
#    if (@files < 2 || !grep(/bayes_seen/,@files) || !grep(/bayes_toks/,@files))
#    {
#      die "unable to find bayes_toks and bayes_seen, stopping\n";
#    }
#    # untaint @files (already safe after grep)
#    @files = map { /(.*)/, $1 } @files;
#
#    for (@files) {
#      my $src = "$dir/$_";
#      my $dst = "$dir/old_$_";
#      copy($src, $dst) || die "can't copy $src to $dst: $!\n";
#    }
#
#    # delete previous to make way for import
#    for (@files) { unlink("$dir/$_"); }
#
#    # import
#    if ($self->tie_db_writable()) {
#      $ret += $self->upgrade_old_dbm_files_trapped("$dir/old_bayes_seen",
#						   $self->{db_seen});
#      $ret += $self->upgrade_old_dbm_files_trapped("$dir/old_bayes_toks",
#						   $self->{db_toks});
#    }
#
#    if ($ret == 2) {
#      print "import successful, original files saved with \"old\" prefix\n";
#    }
#    else {
#      print "import failed, original files saved with \"old\" prefix\n";
#    }
#  };
#  my $err = $@;
#
#  $self->untie_db();
#
#  # if we died, untie the dbm files
#  if ($err) {
#    warn "bayes upgrade_old_dbm_files: $err\n";
#    return 0;
#  }
#  $ret;
}

sub upgrade_old_dbm_files_trapped {
  my ($self, $filename, $output) = @_;

# CPU2006 -- there will never be pre-existing Bayes DBs that need upgrading
#
#  my $count;
#  my %in;
#
#  print "upgrading to DB_File, please be patient: $filename\n";
#
#  # try each type of file until we find one with > 0 entries
#  for my $dbm ('DB_File', 'GDBM_File', 'NDBM_File', 'SDBM_File') {
#    $count = 0;
#    # wrap in eval so it doesn't run in general use.  This accesses db
#    # modules directly.
#    # Note: (bug 2390), the 'use' needs to be on the same line as the eval
#    # for RPM dependency checks to work properly.  It's lame, but...
#    eval 'use ' . $dbm . ';
#      tie %in, "' . $dbm . '", $filename, O_RDONLY, 0600;
#      %{ $output } = %in;
#      $count = scalar keys %{ $output };
#      untie %in;
#    ';
#    if ($@) {
#      print "$dbm: $dbm module not installed, nothing copied.\n";
#      dbg("error was: $@");
#    }
#    elsif ($count == 0) {
#      print "$dbm: no database of that kind found, nothing copied.\n";
#    }
#    else {
#      print "$dbm: copied $count entries.\n";
#      return 1;
#    }
#  }

  return 0;
}

###########################################################################

# token marshalling format for db_toks.

# Since we may have many entries with few hits, especially thousands of hapaxes
# (1-occurrence entries), use a flexible entry format, instead of simply "2
# packed ints", to keep the memory and disk space usage down.  In my
# 18k-message test corpus, only 8.9% have >= 8 hits in either counter, so we
# can use a 1-byte representation for the other 91% of low-hitting entries
# and save masses of space.

# This looks like: XXSSSHHH (XX = format bits, SSS = 3 spam-count bits, HHH = 3
# ham-count bits).  If XX in the first byte is 11, it's packed as this 1-byte
# representation; otherwise, if XX in the first byte is 00, it's packed as
# "CLL", ie. 1 byte and 2 32-bit "longs" in perl pack format.

# Savings: roughly halves size of toks db, at the cost of a ~10% slowdown.

use constant FORMAT_FLAG	=> 0xc0;	# 11000000
use constant ONE_BYTE_FORMAT	=> 0xc0;	# 11000000
use constant TWO_LONGS_FORMAT	=> 0x00;	# 00000000

use constant ONE_BYTE_SSS_BITS	=> 0x38;	# 00111000
use constant ONE_BYTE_HHH_BITS	=> 0x07;	# 00000111

sub tok_unpack {
  my ($self, $value) = @_;
  $value ||= 0;

  my ($packed, $atime);
  if ( $self->{db_version} == 0 ) {
    ($packed, $atime) = unpack("CS", $value);
  }
  elsif ( $self->{db_version} == 1 || $self->{db_version} == 2 ) {
    ($packed, $atime) = unpack("CV", $value);
  }

  if (($packed & FORMAT_FLAG) == ONE_BYTE_FORMAT) {
    return (($packed & ONE_BYTE_SSS_BITS) >> 3,
		$packed & ONE_BYTE_HHH_BITS,
		$atime || 0);
  }
  elsif (($packed & FORMAT_FLAG) == TWO_LONGS_FORMAT) {
    my ($packed, $ts, $th, $atime);
    if ( $self->{db_version} == 0 ) {
      ($packed, $ts, $th, $atime) = unpack("CLLS", $value);
    }
    elsif ( $self->{db_version} == 1 ) {
      ($packed, $ts, $th, $atime) = unpack("CVVV", $value);
    }
    elsif ( $self->{db_version} == 2 ) {
      ($packed, $ts, $th, $atime) = unpack("CVVV", $value);
    }
    return ($ts || 0, $th || 0, $atime || 0);
  }
  # other formats would go here...
  else {
    warn "unknown packing format for Bayes db, please re-learn: $packed";
    return (0, 0, 0);
  }
}

sub tok_pack {
  my ($self, $ts, $th, $atime) = @_;
  $ts ||= 0; $th ||= 0; $atime ||= 0;
  if ($ts < 8 && $th < 8) {
    return pack ("CV", ONE_BYTE_FORMAT | ($ts << 3) | $th, $atime);
  } else {
    return pack ("CVVV", TWO_LONGS_FORMAT, $ts, $th, $atime);
  }
}

###########################################################################

sub dbg { Mail::SpamAssassin::dbg (@_); }
sub sa_die { Mail::SpamAssassin::sa_die (@_); }

1;
