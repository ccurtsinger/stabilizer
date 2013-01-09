##---------------------------------------------------------------------------##
##  File:
##      $Id: mhopt.pl,v 2.54 2003/08/02 06:15:37 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      Routines to set options for MHonArc.
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1997-2002	Earl Hood, mhonarc@mhonarc.org
##
##    This program is free software; you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation; either version 2 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with this program; if not, write to the Free Software
##    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
##    02111-1307, USA
##---------------------------------------------------------------------------##

package mhonarc;

use Getopt::Long;
use Time::Local;

##---------------------------------------------------------------------------
##	get_resources() is responsible for grabbing resource settings from
##	the command-line and resource file(s).
##
sub get_resources {
    my($tmp);
    my(%opt) = ();
    local($_);

    die(qq{Try "$PROG -help" for usage information\n}) unless
    GetOptions(\%opt,
	'add',		# Add a message to archive
	'afs',		# Bypass file permission checks
	'addressmodifycode=s',
			# Perl expression for modifying displayed addresses
	'annotate',	# Add a note to message(s)
	'authsort',	# Sort by author
	'archive',	# Create an archive (the default)
	'conlen',	# Honor Content-Length fields
	'checknoarchive',
			# Check for 'no archive' flag in messages
	'datefields=s', # Fields that contains the date of a message
	'dbfile=s',	# Database/state filename for mhonarc archive
	'dbfileperms=i',# Octal permission to set DBFILE
	'decodeheads',	# Decode all 1522 encoded data in message headers
	'definevar|definevars=s@',
			# Define custom resource variables
	'doc',		# Print link to doc at end of index page
	'docurl=s',	# URL to mhonarc documentation
	'editidx',	# Change index page layout only
	'expiredate=s',	# Message cut-off date
	'expireage=i',	# Time in seconds from current if message expires
	'fasttempfiles',# Do not use random filenames for temporary files
	'fileperms=i',	# Octal permission to create files
	'folrefs',	# Print links to explicit follow-ups/references
	'footer=s',	# File containing user text for bottom of index page
			# 	(option no longer applicable)
	'force',	# Perform archive operation even if unable to lock
	'fromfields=s', # Fields that contains the 'from' of a message
	'genidx',	# Generate an index based upon archive contents
	'gmtdatefmt=s',	# Date specification for GMT date
	'gzipexe=s',	# Pathname of Gzip executable
	'gzipfiles',	# Gzip files
	'gziplinks',	# Add ".gz" extensions to files
	'header=s',	# File containing user text for top of index page
			# 	(option no longer applicable)
	'htmlext=s',	# Extension for HTML files
	'iconurlprefix=s',
			# Prefix for icon urls
	'idxfname=s',	# Filename of index page
	'idxprefix=s',	# Filename prefix for multi-page main index
	'idxsize=i',	# Maximum number of messages shown in indexes
	'keeponrmm',	# Do not delete message files on archive remove
	'lang=s',	# Set locale/language
	'localdatefmt=s',
			# Date specification for local date
	'lock',		# Do archive locking (default)
	'lockdelay=i',	# Time delay in seconds between lock tries
	'lockmethod=s',	# Set the method of locking
	'locktries=i',	# Number of tries in locking an archive
	'mailtourl=s',	# URL to use for e-mail address hyperlinks
	'main',		# Create a main index
	'maxsize=i',	# Maximum number of messages allowed in archive
	'mbox',		# Use mailbox format		(ignored now)
	'mh',		# Use MH mail folders format	(ignored now)
	'mhpattern=s',	# Regular expression for message files in a directory
	'modifybodyaddresses',
			# addressmodifycode applies to text entities
	'modtime',	# Set modification time on files to message date
	'months=s',	# Month names
	'monthsabr=s',	# Abbreviated month names
	'msgexcfilter=s',
			# Perl expression(s) for selective message exclusion
	'msgpgs',	# Create message pages
	'msgsep=s',	# Message separator for mailbox files
	'msgprefix=s',	# Filename prefix for message files
	'multipg',	# Generate multi-page indexes
	'news',		# Add links to newsgroups
	'noauthsort',	# Do not sort by author
	'noarchive',	# Do not create an archive
	'nochecknoarchive',
			# Do not check for 'no archive' flag in messages
	'noconlen',	# Ignore Content-Length fields
	'nodecodeheads',
			# Do not decode 1522 encoded data in message headers
	'nodoc',	# Do not print link to doc at end of index page
	'nofasttempfiles',
			# Use random filenames for temporary files
	'nofolrefs',	# Do not print links to explicit follow-ups/references
	'nogzipfiles',	# Do not Gzip files
	'nogziplinks',	# Do not add '.gz' extensions to files
	'nokeeponrmm',	# Delete message files on archive remove
	'nolock',	# Do no archive locking
	'nomailto',	# Do not add in mailto links for e-mail addresses
	'nomain',	# Do not create a main index
	'nomsgpgs',	# Do not create message pages
	'nomodtime',	# Do no set modification time on files to message date
	'nomultipg',	# Do not generate multi-page indexes
	'nonews',	# Do not add links to newsgroups
	'noposixstrftime',
			# Use own implementation for time format process
	'noreverse',	# List messages in normal order
	'nosaveresources',
			# Do not save resource values in db
	'nosort',	# Do not sort
	'nospammode',	# Do not run in (anti)spam mode
	'nosubsort',	# Do not sort by subject
	'nosubjectthreads',
			# Do not do subject based threading
	'nosubjecttxt=s',
			# Text to use if message has no subject
	'notedir',	# Location of notes
	'notetext=s@',	# Text data of note
	'nothread',	# Do not create threaded index
	'notreverse',	# List oldest thread first
	'notsubsort|tnosubsort',
			# Do not list threads by subject
	'notsort|tnosort',
			# List threads by ordered processed
	'nourl',	# Do not make URL hyperlinks
	'otherindex|otherindexes=s@',
			# List of other rcfiles for extra indexes
	'outdir=s',	# Destination of HTML files
	'pagenum=s',	# Page to output if -genidx
	'perlinc=s@',	# List of paths to search for MIME filters
	'posixstrftime',
			# Use POSIX strftime()
	'quiet',	# No status messages while running
	'rcfile=s@',	# Resource file for mhonarc
	'reconvert!',	# Reconvert existing messages
	'varregex=s',	# Regex matching resource variables
	'reverse',	# List messages in reverse order
	'rmm',		# Remove messages from an archive
	'savemem',	# Write message data while processing
	'saveresources',
			# Save resource values in db
	'scan',		# List out archive contents to terminal
	'single',	# Convert a single message to HTML
	'sort',		# Sort messages in increasing date order
	'spammode',	# Run in (anti)spam mode
	'stderr=s',	# Set file for stderr
	'stdin=s',	# Set file for stdin
	'stdout=s',	# Set file for stdout
	'subjectarticlerxp=s',
			# Regex for leading articles in subjects
	'subjectreplyrxp=s',
			# Regex for leading reply string in subjects
	'subjectstripcode=s',
			# Perl expression for modifying subjects
	'subjectthreads',
			# Check subjects for threads
	'subsort',	# Sort message by subject
	'tidxfname=s',	# File name of threaded index page
	'tidxprefix=s',	# Filename prefix for multi-page thread index
	'time',		# Print processing time
	'title=s',	# Title of index page
	'ttitle=s',	# Title of threaded index page
	'thread',	# Create threaded index
	'tlevels=i',	# Maximum # of nested lists in threaded index
	'treverse',	# Reverse order of thread listing
	'tslice=s',	# Set size of thread slice listing
	'tslicelevels=i',
			# Maximum # of nested lists in thread slices
	'tsort',	# List threads by date
	'tsubsort',	# List threads by subject
	'umask=i',	# Set umask of process
	'url',		# Make URL hyperlinks
	'weekdays=s',	# Weekday names
	'weekdaysabr=s',
			# Abbreviated weekday names

	## API (only?) options
	'noarg', 	# Just load code
	'readdb',	# Just read db

	'v',		# Version information
	'help'		# A brief usage message
    );

    ## Check for help/version options (nothing to do)
    if ($opt{'help'}) 	{ &usage();   return 0; }
    if ($opt{'v'}) 	{ &version(); return 0; }

    ## Check std{in,out,err} options
    DUP: {
	$MhaStdin  = \*STDIN;
	#$MhaStdout = \*STDOUT;
	#$MhaStderr = \*STDERR;
	STDOUTERR: {
	    if (defined($opt{'stdout'}) && !ref($opt{'stdout'})) {
		open(STDOUT, ">>$opt{'stdout'}") ||
		    die qq/ERROR: Unable to create "$opt{'stdout'}": $!\n/;
		if ($opt{'stderr'} eq $opt{'stdout'}) {
		    open(STDERR, ">&STDOUT") ||
			die qq/ERROR: Unable to dup STDOUT: $!\n/;
		    last STDOUTERR;
		}
	    }
	    if (defined($opt{'stderr'}) && !ref($opt{'stderr'})) {
		open(STDERR, ">>$opt{'stderr'}") ||
		    die qq/ERROR: Unable to create "$opt{'stderr'}": $!\n/;
	    }
	}
	if (defined($opt{'stdin'})) {
	    if (ref($opt{'stdin'})) {
		$MhaStdin = $opt{'stdin'};
	    } else {
		open(STDIN, "<$opt{'stdin'}") ||
		    die qq/ERROR: Unable to open "$opt{'stdin'}": $!\n/;
		$MhaStdin = \*STDIN;
	    }
	}
	my $curfh = select(STDOUT);  $| = 1;
		    select(STDERR);  $| = 1;
	select($curfh);
    }

    ## Initialize variables
    require 'mhinit.pl';   &mhinit_vars();

    ## These options have NO resource file equivalent.
    $NoArg   = $opt{'noarg'};
    $ReadDB  = $opt{'readdb'};

    $ADD     = $opt{'add'};
    $RMM     = $opt{'rmm'};
    $SCAN    = $opt{'scan'};
    $QUIET   = $opt{'quiet'};
    $EDITIDX = $opt{'editidx'};
    $ANNOTATE= $opt{'annotate'};
    $AFS     = $opt{'afs'};
    if ($opt{'genidx'}) {
	$IDXONLY  = 1;  $QUIET = 1;  $ADD = 0;
    } else {
	$IDXONLY  = 0;
    }
    if ($opt{'single'} && !$RMM && !$ANNOTATE) {
	$SINGLE  = 1;  $QUIET = 1;
    } else {
	$SINGLE = 0;
    }
    $ReadDB  	= 1  if ($ADD || $EDITIDX || $RMM || $ANNOTATE || $SCAN ||
			 $IDXONLY);
    $DoArchive	= 1  if $opt{'archive'};
    $DoArchive	= 0  if $opt{'noarchive'};

    $Reconvert  = $opt{'reconvert'}  if defined($opt{'reconvert'});

    my $dolock	= !$NoArg && !$opt{'nolock'};

    ## Check argv
    unless (($#ARGV >= 0) || $ADD || $SINGLE || $EDITIDX || $SCAN ||
    	    $IDXONLY || $ReadDB || !$DoArchive || $NoArg) {
	usage();
	return -1;
    }

    ## Require needed libraries
    require 'ewhutil.pl';
    require 'mhtime.pl';
    require 'mhfile.pl';
    require 'mhutil.pl';
    require 'mhrcfile.pl';
    require 'mhscan.pl'  	if $SCAN;
    require 'mhsingle.pl'  	if $SINGLE;
    require 'mhrmm.pl'  	if $RMM;
    require 'mhnote.pl'  	if $ANNOTATE;

    print STDOUT "This is MHonArc v$VERSION, Perl $] $^O\n"  unless $QUIET;

    ## Check for locale/lang setting
    $Lang = $opt{'lang'}  if defined($opt{'lang'});

    ## Evaluate site local initialization
    delete($INC{'mhasiteinit.pl'});      # force re-evaluation
    eval { require 'mhasiteinit.pl'; };  # ignore status

    ## Read default resource file
    DEFRCFILE: {
	if ($DefRcFile) {
	    last DEFRCFILE  if read_resource_file($DefRcFile);
	}
# CPU2006 - our home directory is always '.'
#	my $home_dir = $ENV{'HOME'};
	my $home_dir = '.';
	if (defined $home_dir) {
	    # check if in home directory
	    last DEFRCFILE
		if read_resource_file(join($DIRSEP, $home_dir, $DefRcName), 1);
	}
	local $_;
	foreach (@INC) {
	    next if ($_ eq $home_dir);
	    last DEFRCFILE
		if read_resource_file(join($DIRSEP, $_, $DefRcName), 1);
	}
    }

    ## Grab a few options
    @FMTFILE   = @{$opt{'rcfile'}}  if defined($opt{'rcfile'});
    $LOCKTRIES = $opt{'locktries'}  if defined($opt{'locktries'}) &&
					($opt{'locktries'} > 0);
    $LOCKDELAY = $opt{'lockdelay'}  if defined($opt{'lockdelay'}) &&
					($opt{'lockdelay'} > 0);
    $FORCELOCK = $opt{'force'};

    $LockMethod = &set_lock_mode($opt{'lockmethod'})
		  if defined($opt{'lockmethod'});

    ## These options must be grabbed before reading the database file
    ## since these options may tells us where the database file is.
    $OUTDIR  = $opt{'outdir'}    if $opt{'outdir'};
# CPU2006 - there really isn't any OUTDIR
#    if (!$NoArg && !($SCAN || $IDXONLY || $SINGLE)) {
#	die qq/ERROR: "$OUTDIR" does not exist\n/    unless -e $OUTDIR;
#	if (!$AFS) {
#	    die qq/ERROR: "$OUTDIR" is not readable\n/   unless -r $OUTDIR;
#	    die qq/ERROR: "$OUTDIR" is not writable\n/   unless -w $OUTDIR;
#	    die qq/ERROR: "$OUTDIR" is not executable\n/ unless -x $OUTDIR;
#	}
#    }
    $DBFILE  = $opt{'dbfile'}    if $opt{'dbfile'};

    ## Create lock
    $LOCKFILE  = join($DIRSEP, $OUTDIR, $LOCKFILE);
    if ($dolock && $DoArchive && !$SINGLE) {
	if (!&$LockFunc($LOCKFILE, $LOCKTRIES, $LOCKDELAY, $FORCELOCK)) {
	    $! = 75; # EX_TEMPFAIL (for sendmail)
	    die("ERROR: Unable to lock $OUTDIR after $LOCKTRIES tries\n");
	}
    }

    ## Check if we need to access database file
    if ($ReadDB) {
# CPU2006
#	$DBPathName = OSis_absolute_path($DBFILE) ?
#	    $DBFILE : join($DIRSEP, $OUTDIR, $DBFILE);
        $DBPathName = join($DIRSEP, $OUTDIR, $DBFILE);

	## Invoke preload callback
	if (defined($CBDbPreLoad) && defined(&$CBDbPreLoad)) {
	    &$CBDbPreLoad($DBPathName);
	}
# CPU2006
	#if (-e $DBPathName) {
	if (file_exists($DBPathName)) {
	    print STDOUT "Reading database ...\n"  unless $QUIET;

# CPU2006
#	    ## Just perform a require.  Delete %INC entry to force
#	    ## evaluation.
#	    delete $INC{$DBPathName};
#	    require($DBPathName) ||
#		die("ERROR: Database read error of $DBPathName\n");
          eval $mhonarc_files{$DBPathName};
          die "MHonArc DB read: $@\nStopped" if ($@);

	    ## Check db version with program version
	    if ($VERSION ne $DbVERSION) {
		warn "Warning: Database ($DbVERSION) != ",
		     "program ($VERSION) version.\n";
	    }

	    ## Check for 1.x archive, and update data as needed
	    if ($DbVERSION =~ /^1\./) {
		print STDOUT "Updating database $DbVERSION data ...\n"
		    unless $QUIET;
		&update_data_1_to_2();
		&update_data_2_1_to_later();
		&update_data_2_4_to_later();

	    ## Check for 2.[0-4] archive
	    } elsif ($DbVERSION =~ /^2\.[0-4]\./) {
		print STDOUT "Updating database $DbVERSION data ...\n"
		    unless $QUIET;
		if ($DbVERSION =~ /^2\.[01]\./) {
		    &update_data_2_1_to_later();
		}
		&update_data_2_4_to_later();
	    }

	    ## Set %Follow here just incase it does not get recomputed
	    %Follow = %FollowOld;
	}
	if (!$IDXONLY) {
	    if ($#ARGV < 0) { $ADDSINGLE = 1; }	# See if adding single mesg
	    else { $ADDSINGLE = 0; }
	    $ADD = $MhaStdin;
	}
    }
    my($OldMULTIIDX) = $MULTIIDX;

    ## Remove lock if db not going to be changed
    if ($SCAN || $IDXONLY) {
	&$UnlockFunc();
    }

    ## Clear thread flag if genidx, must be explicitly set
    $THREAD = 0  if $IDXONLY;

    ## Set mail parsing variables.
    if (!$SCAN) {
	# require readmail library
	require 'readmail.pl';
	mhinit_readmail_vars();
	$readmail::FormatHeaderFunc = \&mhonarc::htmlize_header;
	$MHeadCnvFunc = \&readmail::MAILdecode_1522_str;
    }

    ##	Read resource file(s)
    ##	Look for resource in outdir unless existing according to
    ##  current value.
    foreach (@FMTFILE) {
# CPU2006
	#$_ = join($DIRSEP, $OUTDIR, $_) unless -e $_;
	$_ = join($DIRSEP, $OUTDIR, $_) unless file_exists($_);
	&read_resource_file($_);
    }

# CPU2006 - do not set the locale
#    ## Set locale
#    eval {
#	require POSIX;
#	if ($Lang) {
#	    POSIX::setlocal(&POSIX::LC_ALL, $Lang);
#	} else {
#	    POSIX::setlocal(&POSIX::LC_ALL, '');
#	}
#    };
#    if ($@ && $Lang) {
#	qq/Warning: Setting locale appears to be not supported:\n$@\n/;
#    }

    ##	Re-check readmail settings
    if (!$SCAN) {
	# If text encoding has been specified, change $MHeadCnvFunc.
	if (defined(readmail::load_textencoder())) {
	    $MHeadCnvFunc = \&htmlize_enc_head;
	}
    }

    ## Check if extension for HTML files defined on the command-line
    $HtmlExt = $opt{'htmlext'}  if defined($opt{'htmlext'});

    ## Other indexes resource files
    if (defined($opt{'otherindex'})) {
	my @array = ();
	local($_);
	foreach (@{$opt{'otherindex'}}) {
	    push(@array, split(/$PATHSEP/o, $_));
	}
	unshift(@OtherIdxs, @array);
    }

    ## Perl INC paths
    if (defined($opt{'perlinc'})) {
	my @array = ();
	local($_);
	foreach (@{$opt{'perlinc'}}) {
	    push(@array, split(/$PATHSEP/o, $_));
	}
	unshift(@PerlINC, @array);
    }

    @OtherIdxs = remove_dups(\@OtherIdxs);
    @PerlINC   = remove_dups(\@PerlINC);
# CPU2006
#    unshift(@INC, @PerlINC);

    ## Set alternative prefs
    if (!$SCAN) {
	readmail::MAILset_alternative_prefs(@MIMEAltPrefs);
	$IsDefault{'MIMEALTPREFS'} = !scalar(@MIMEAltPrefs);
    }

    ## Get other command-line options
    $DBFILE	= $opt{'dbfile'}     if $opt{'dbfile'}; # Override db
    $DBPathName = OSis_absolute_path($DBFILE) ?
	$DBFILE : join($DIRSEP, $OUTDIR, $DBFILE);

    $DOCURL	= $opt{'docurl'}     if $opt{'docurl'};
    $FROM	= $opt{'msgsep'}     if $opt{'msgsep'};
    $IDXPREFIX	= $opt{'idxprefix'}  if $opt{'idxprefix'};
    $IDXSIZE	= $opt{'idxsize'}    if defined($opt{'idxsize'});
	$IDXSIZE *= -1  if $IDXSIZE < 0;
    $OUTDIR	= $opt{'outdir'}     if $opt{'outdir'}; # Override db
    $MAILTOURL	= $opt{'mailtourl'}  if $opt{'mailtourl'};
    $MAXSIZE	= $opt{'maxsize'}    if defined($opt{'maxsize'});
	$MAXSIZE = 0  if $MAXSIZE < 0;
    $MHPATTERN	= $opt{'mhpattern'}  if $opt{'mhpattern'};
    $TIDXPREFIX	= $opt{'tidxprefix'} if $opt{'tidxprefix'};
    $TITLE	= $opt{'title'}      if $opt{'title'};
    $TLEVELS	= $opt{'tlevels'}    if $opt{'tlevels'};
    $TTITLE	= $opt{'ttitle'}     if $opt{'ttitle'};
    $MsgPrefix	= $opt{'msgprefix'}  if defined($opt{'msgprefix'});
    $GzipExe	= $opt{'gzipexe'}    if $opt{'gzipexe'};
    $VarExp	= $opt{'varregex'}   if $opt{'varregex'} &&
				        ($opt{'varregex'} =~ /\S/);
    $TSLICELEVELS = $opt{'tslicelevels'}  if $opt{'tslicelevels'};
    $IconURLPrefix = $opt{'iconurlprefix'}  if $opt{'iconurlprefix'};

    $IDXNAME	= $opt{'idxfname'} || $IDXNAME || $ENV{'M2H_IDXFNAME'} ||
		  "maillist.$HtmlExt";
    $TIDXNAME	= $opt{'tidxfname'} || $TIDXNAME || $ENV{'M2H_TIDXFNAME'} ||
		  "threads.$HtmlExt";

    $ExpireDate	= $opt{'expiredate'} if $opt{'expiredate'};
    $ExpireTime	= $opt{'expireage'}  if $opt{'expireage'};
	$ExpireTime *= -1  if $ExpireTime < 0;

    $GMTDateFmt	= $opt{'gmtdatefmt'}  	  if $opt{'gmtdatefmt'};
    $LocalDateFmt = $opt{'localdatefmt'}  if $opt{'localdatefmt'};

    $AddressModify = $opt{'addressmodifycode'}  if $opt{'addressmodifycode'};
    $SubArtRxp     = $opt{'subjectarticlerxp'}  if $opt{'subjectarticlerxp'};
    $SubReplyRxp   = $opt{'subjectreplyrxp'}    if $opt{'subjectreplyrxp'};
    $SubStripCode  = $opt{'subjectstripcode'}   if $opt{'subjectstripcode'};
    $MsgExcFilter  = $opt{'msgexcfilter'}    if defined($opt{'msgexcfilter'});

    $NoSubjectTxt  = $opt{'nosubjecttxt'}	if $opt{'nosubjecttxt'};

    $IdxPageNum  = $opt{'pagenum'}   if defined($opt{'pagenum'});

    ## Determine location of message note files
    $NoteDir = $opt{'notedir'}	if $opt{'notedir'};

    ## See if note text defined on command-line
    if (defined $opt{'notetext'}) {
	$NoteText = join(" ", @{$opt{'notetext'}});
    } else {
	$NoteText = undef;
    }

    ## Parse any rc variable definition from command-line
    if (defined($opt{'definevar'})) {
	my @array = ();
	foreach (@{$opt{'definevar'}}) {
	    push(@array, &parse_vardef_str($_));
	}
	%CustomRcVars = (%CustomRcVars, @array);
    }

    $CONLEN	= 1  if $opt{'conlen'};
    $CONLEN	= 0  if $opt{'noconlen'};
    $MAIN	= 1  if $opt{'main'};
    $MAIN	= 0  if $opt{'nomain'};
    $MODTIME	= 1  if $opt{'modtime'};
    $MODTIME	= 0  if $opt{'nomodtime'};
    $MULTIIDX	= 1  if $opt{'multipg'};
    $MULTIIDX	= 0  if $opt{'nomultipg'};
    $NODOC	= 0  if $opt{'doc'};
    $NODOC	= 1  if $opt{'nodoc'};
    $NOMAILTO	= 1  if $opt{'nomailto'};
    $NONEWS	= 0  if $opt{'news'};
    $NONEWS	= 1  if $opt{'nonews'};
    $NOURL	= 0  if $opt{'url'};
    $NOURL	= 1  if $opt{'nourl'};
    $SLOW	= 1  if $opt{'savemem'};
    $THREAD	= 1  if $opt{'thread'};
    $THREAD	= 0  if $opt{'nothread'};
    $TREVERSE	= 1  if $opt{'treverse'};
    $TREVERSE	= 0  if $opt{'notreverse'};
    $DoFolRefs	= 1  if $opt{'folrefs'};
    $DoFolRefs	= 0  if $opt{'nofolrefs'};
    $GzipFiles	= 1  if $opt{'gzipfiles'};
    $GzipFiles	= 0  if $opt{'nogzipfiles'};
    $GzipLinks	= 1  if $opt{'gziplinks'};
    $GzipLinks	= 0  if $opt{'nogziplinks'};
    $NoMsgPgs	= 0  if $opt{'msgpgs'};
    $NoMsgPgs	= 1  if $opt{'nomsgpgs'};
    $SaveRsrcs	= 1  if $opt{'saveresources'};
    $SaveRsrcs	= 0  if $opt{'nosaveresources'};
    $SpamMode	= 1  if $opt{'spammode'};
    $SpamMode	= 0  if $opt{'nospammode'};
    $KeepOnRmm	= 1  if $opt{'keeponrmm'};
    $KeepOnRmm	= 0  if $opt{'nokeeponrmm'};

    $CheckNoArchive = 1  if $opt{'checknoarchive'};
    $CheckNoArchive = 0  if $opt{'nochecknoarchive'};
    $FastTempFiles  = 1  if $opt{'fasttempfiles'};
    $FastTempFiles  = 0  if $opt{'nofasttempfiles'};
    $POSIXstrftime  = 1  if $opt{'posixstrftime'};
    $POSIXstrftime  = 0  if $opt{'noposixstrftime'};

    $AddrModifyBodies = 1  if $opt{'modifybodyaddresses'};
    $AddrModifyBodies = 0  if $opt{'nomodifybodyaddresses'};

    $DecodeHeads = 1 if $opt{'decodeheads'};
    $DecodeHeads = 0 if $opt{'nodecodeheads'};
	$readmail::DecodeHeader = $DecodeHeads;

    ## Clear main flag if genidx and thread specified
    $MAIN = 0  if $IDXONLY && $THREAD;

    @DateFields	 = split(/[:;]/, $opt{'datefields'})  if $opt{'datefields'};
    @FromFields	 = split(/[:;]/, $opt{'fromfields'})  if $opt{'fromfields'};
    foreach (@FromFields) { s/\s//g; tr/A-Z/a-z/; }

    ($TSliceNBefore, $TSliceNAfter, $TSliceInclusive) =
	split(/[:;]/, $opt{'tslice'})  if $opt{'tslice'};

    @Months   = split(/:/, $opt{'months'}) 	if defined($opt{'months'});
    @months   = split(/:/, $opt{'monthsabr'})  	if defined($opt{'monthsabr'});
    @Weekdays = split(/:/, $opt{'weekdays'})  	if defined($opt{'weekdays'});
    @weekdays = split(/:/, $opt{'weekdaysabr'}) if defined($opt{'weekdaysabr'});

    $MULTIIDX	= 0  if !$IDXSIZE;

    ##	Set umask
    if ($UNIX) {
	$UMASK = $opt{'umask'}      if defined($opt{'umask'});
	eval { umask oct($UMASK); };
    }
    $FilePerms      = $opt{'fileperms'}  if defined($opt{'fileperms'});
    $FilePermsOct   = oct($FilePerms);
    $DbFilePerms    = $opt{'dbfileperms'}  if defined($opt{'dbfileperms'});
    $DbFilePermsOct = oct($DbFilePerms);

    ##	Get sort method
    $AUTHSORT = 1  if $opt{'authsort'};
    $AUTHSORT = 0  if $opt{'noauthsort'};
    $SUBSORT  = 1  if $opt{'subsort'};
    $SUBSORT  = 0  if $opt{'nosubsort'};
    $NOSORT   = 1  if $opt{'nosort'};
    $NOSORT   = 0  if $opt{'sort'};
    $REVSORT  = 1  if $opt{'reverse'};
    $REVSORT  = 0  if $opt{'noreverse'};
    if ($NOSORT) {
	$SUBSORT = 0;  $AUTHSORT = 0;
    } elsif ($SUBSORT) {
	$AUTHSORT = 0;
    }

    ## Check for thread listing order
    $TSUBSORT = 1  if $opt{'tsubsort'};
    $TSUBSORT = 0  if $opt{'notsubsort'};
    $TNOSORT  = 1  if $opt{'notsort'};
    $TNOSORT  = 0  if $opt{'tsort'};
    $TREVERSE = 1  if $opt{'treverse'};
    $TREVERSE = 0  if $opt{'notreverse'};
    if ($TNOSORT) {
	$TSUBSORT = 0;
    }
    $NoSubjectThreads  = 1  if $opt{'nosubjectthreads'};
    $NoSubjectThreads  = 0  if $opt{'subjectthreads'};

    ## Check if all messages must be updated (this has been simplified;
    ## any serious change should be done via editidx).
    if ($EDITIDX || ($OldMULTIIDX != $MULTIIDX)) {
	$UPDATE_ALL = 1;
    } else {
	$UPDATE_ALL = 0;
    }

    ## Set date names
    &set_date_names(\@weekdays, \@Weekdays, \@months, \@Months);

    ## Set %Zone with user-specified timezones
    while (($zone, $offset) = each(%ZoneUD)) {
	$Zone{$zone} = $offset;
    }

    ## Require some more libaries
    require 'mhidxrc.pl';   &mhidxrc_set_vars();
    require 'mhdysub.pl';   &create_routines();
    require 'mhrcvars.pl';
    require 'mhindex.pl';
    require 'mhthread.pl';
    require 'mhdb.pl'	    unless $SCAN || $IDXONLY || !$DoArchive;

    ## Load text clipping function
    if (defined($TextClipSrc)) {
	eval { require $TextClipSrc; };
	if ($@) { warn qq/Warning: $@\n/; }
    }
    if (!defined($TextClipFunc) || !defined(&$TextClipFunc)) {
	$TextClipFunc = \&clip_text;
	$TextClipSrc  = undef;
	$IsDefault{'TEXTCLIPFUNC'} = 1;
    } else {
	$IsDefault{'TEXTCLIPFUNC'} = 0;
    }

    ## Check if rewriting addresses in bodies
    if ($AddrModifyBodies) {
	$readmail::TextPreFilter = sub {
	    my $fields = shift;
	    my $data_r = shift;
	    $$data_r =~ s/($AddrExp)/rewrite_raw_address($1)/geo;
	}
    }

    ## Predefine %Index2TLoc in case of message deletion
    if (@TListOrder) {
	@Index2TLoc{@TListOrder} = (0 .. $#TListOrder);
    }

    ## Define %Index2MsgId hash
    foreach (keys %MsgId) {
	$Index2MsgId{$MsgId{$_}} = $_;
    }

    ## Set $ExpireDateTime from $ExpireDate
    if ($ExpireDate) {
	my @array = ();
	if (@array = &parse_date($ExpireDate)) {
	    $ExpireDateTime = &get_time_from_date(@array[1..$#array]);
	} else {
	    warn qq|Warning: Unable to parse EXPIREDATE, "$ExpireDate"\n|;
	}
    }

    ## Get highest message number
    if ($ADD) {
	$LastMsgNum = &get_last_msg_num();
    } else {
	$LastMsgNum = -1;
    }

    ## Delete bogus empty entries in hashes due to bug in earlier
    ## versions to avoid any future problems.
    delete($IndexNum{''});
    delete($Subject{''});
    delete($From{''});
    delete($MsgId{''});
    delete($FollowOld{''});
    delete($ContentType{''});
    delete($Refs{''});

    # update DOCURL if default old value
    if ($DOCURL eq 'http://www.oac.uci.edu/indiv/ehood/mhonarc.html') {
	$DOCURL = 'http://www.mhonarc.org/';
    }

    ## Check if printing process time
    $TIME = $opt{'time'};

    1;
}

##---------------------------------------------------------------------------
##	Version routine
##
sub version {
    select(STDOUT);
    print $VINFO;
}

##---------------------------------------------------------------------------
##	Usage routine
##
sub usage {
    require 'mhusage.pl';
    &mhusage();
}

##---------------------------------------------------------------------------
##	Routine to update 1.x data structures to 2.0.
##
sub update_data_1_to_2 {
    local(%EntName2Char) = (
	'lt',       '<',
	'gt',       '>',
	'amp',      '&',
    );
    #--------------------------------------
    sub entname_to_char {
	my($name) = shift;
	my($ret) = $EntName2Char{$name};
	if (!$ret) {
	    $ret = "&$name;";
	}
	$ret;
    }
    #--------------------------------------
    my($index);
    foreach $index (keys %From) {
	$From{$index} =~ s/\&([\w\-.]+);/&entname_to_char($1)/ge;
    }
    foreach $index (keys %Subject) {
	$Subject{$index} =~ s/\&([\w\-.]+);/&entname_to_char($1)/ge;
    }
    delete $IndexNum{''};
    $TLITXT = '<li>' . $TLITXT  unless ($TLITXT) && ($TLITXT =~ /<li>/i);
    $THEAD .= "<ul>\n"   unless ($THEAD) && ($THEAD =~ m%<ul>\s*$%i);
    $TFOOT  = "</ul>\n"  unless ($TFOOT) && ($TFOOT =~ m%^\s*</ul>%i);
}

##---------------------------------------------------------------------------
##	Update 2.1, or earlier, data.
##
sub update_data_2_1_to_later {
    # we can preserve filter arguments
    if (defined(%main::MIMEFiltersArgs)) {
	warn qq/         preserving MIMEARGS...\n/;
	%readmail::MIMEFiltersArgs = %main::MIMEFiltersArgs;
	$IsDefault{'MIMEARGS'} = 0;
    }
}

##---------------------------------------------------------------------------
##	Update 2.4, or earlier, data.
##
sub update_data_2_4_to_later {
    # convert Perl 4 style data to Perl 5 style
    my($index, $value);
    while (($index, $value) = each(%Refs)) {
	next  if ref($value);
	$Refs{$index} = [ split(/$X/o, $value) ];
    }
    while (($index, $value) = each(%FollowOld)) {
	next  if ref($value);
	$FollowOld{$index} = [ split(/$bs/o, $value) ];
    }
    while (($index, $value) = each(%Derived)) {
	next  if ref($value);
	$Derived{$index} = [ split(/$X/o, $value) ];
    }
}

##---------------------------------------------------------------------------
##	Initialize readmail.pl variables
##
sub mhinit_readmail_vars {
    ##	Default decoders
    unless (%readmail::MIMEDecoders) {
	%readmail::MIMEDecoders = (
	    '7bit'	       => 'as-is',
	    '8bit'             => 'as-is',
	    'binary'           => 'as-is',
	    'base64'           => 'base64::b64decode',
	    'quoted-printable' => 'quoted_printable::qprdecode',
	    'x-uuencode'       => 'base64::uudecode',
	    'x-uue'            => 'base64::uudecode',
	    'uuencode'         => 'base64::uudecode',
	);
	%readmail::MIMEDecodersSrc = (
	    'base64'           => 'base64.pl',
	    'quoted-printable' => 'qprint.pl',
	    'x-uuencode'       => 'base64.pl',
	    'x-uue'            => 'base64.pl',
	    'uuencode'         => 'base64.pl',
	);
	$IsDefault{'MIMEDECODERS'} = 1;
    }

    ##	Default filters
    unless (%readmail::MIMEFilters) {
	%readmail::MIMEFilters = (
	    # Content-type			Filter
	    #-----------------------------------------------------------------
	    "application/ms-tnef",		"m2h_null::filter",
	    "application/octet-stream",		"m2h_external::filter",
	    "application/x-patch",		"m2h_text_plain::filter",
	    "message/delivery-status",  	"m2h_text_plain::filter",
	    "message/external-body",		"m2h_msg_extbody::filter",
	    "message/partial",   		"m2h_text_plain::filter",
	    "text/enriched",    		"m2h_text_enriched::filter",
	    "text/html",			"m2h_text_html::filter",
	    "text/plain",			"m2h_text_plain::filter",
	    "text/richtext",    		"m2h_text_enriched::filter",
	    "text/tab-separated-values",	"m2h_text_tsv::filter",
	    "text/x-html",			"m2h_text_html::filter",

	    "application/*",			"m2h_external::filter",
	    "audio/*",				"m2h_external::filter",
	    "chemical/*",  			"m2h_external::filter",
	    "image/*",  			"m2h_external::filter",
	    "model/*",  			"m2h_external::filter",
	    "text/*",   			"m2h_text_plain::filter",
	    "video/*",  			"m2h_external::filter",

	    "x-sun-attachment",			"m2h_text_plain::filter",
	);

	%readmail::MIMEFiltersSrc = (
	    # Content-type			Filter
	    #-----------------------------------------------------------------
	    "application/ms-tnef",		"mhnull.pl",
	    "application/octet-stream",		"mhexternal.pl",
	    "application/x-patch",		"mhtxtplain.pl",
	    "message/delivery-status",  	"mhtxtplain.pl",
	    "message/external-body",		"mhmsgextbody.pl",
	    "message/partial",   		"mhtxtplain.pl",
	    "text/enriched",    		"mhtxtenrich.pl",
	    "text/html",			"mhtxthtml.pl",
	    "text/plain",			"mhtxtplain.pl",
	    "text/richtext",    		"mhtxtenrich.pl",
	    "text/tab-separated-values",	"mhtxttsv.pl",
	    "text/x-html",			"mhtxthtml.pl",

	    "application/*",			"mhexternal.pl",
	    "audio/*",				"mhexternal.pl",
	    "chemical/*",  			"mhexternal.pl",
	    "image/*",  			"mhexternal.pl",
	    "model/*",  			"mhexternal.pl",
	    "text/*",   			"mhtxtplain.pl",
	    "video/*",  			"mhexternal.pl",

	    "x-sun-attachment",			"mhtxtplain.pl",
	);
	$IsDefault{'MIMEFILTERS'} = 1;
    }

    ##  Default filter arguments
    unless (%readmail::MIMEFiltersArgs) {
	%readmail::MIMEFiltersArgs = (
	    # Content-type			Arguments
	    #-----------------------------------------------------------------
	    'm2h_external::filter',		'inline',
	);
	$IsDefault{'MIMEARGS'} = 1;
    }

    ##  Charset filters
    unless (%readmail::MIMECharSetConverters) {
	%readmail::MIMECharSetConverters = (
	    # Character set		Converter Function
	    #-----------------------------------------------------------------
	    'plain',     		'mhonarc::htmlize',
	    'us-ascii',   		'mhonarc::htmlize',
	    'iso-8859-1',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-2',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-3',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-4',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-5',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-6',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-7',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-8',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-9',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-10',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-11',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-13',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-14',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-15',   		'MHonArc::CharEnt::str2sgml',
	    'iso-8859-16',   		'MHonArc::CharEnt::str2sgml',
	    'iso-2022-jp',   		'MHonArc::CharEnt::str2sgml',
	    'iso-2022-kr',    		'MHonArc::CharEnt::str2sgml',
	    'euc-jp',    		'MHonArc::CharEnt::str2sgml',
	    'utf-8',    		'MHonArc::CharEnt::str2sgml',
	    'cp866',    		'MHonArc::CharEnt::str2sgml',
	    'cp932',    		'MHonArc::CharEnt::str2sgml',
	    'cp936',    		'MHonArc::CharEnt::str2sgml',
	    'cp949',    		'MHonArc::CharEnt::str2sgml',
	    'cp950',    		'MHonArc::CharEnt::str2sgml',
	    'cp1250',   		'MHonArc::CharEnt::str2sgml',
	    'cp1251',   		'MHonArc::CharEnt::str2sgml',
	    'cp1252',   		'MHonArc::CharEnt::str2sgml',
	    'cp1253',   		'MHonArc::CharEnt::str2sgml',
	    'cp1254',   		'MHonArc::CharEnt::str2sgml',
	    'cp1255',   		'MHonArc::CharEnt::str2sgml',
	    'cp1256',   		'MHonArc::CharEnt::str2sgml',
	    'cp1257',   		'MHonArc::CharEnt::str2sgml',
	    'cp1258',   		'MHonArc::CharEnt::str2sgml',
	    'koi-0',            	'MHonArc::CharEnt::str2sgml',
	    'koi-7',            	'MHonArc::CharEnt::str2sgml',
	    'koi8-a',            	'MHonArc::CharEnt::str2sgml',
	    'koi8-b',            	'MHonArc::CharEnt::str2sgml',
	    'koi8-e',            	'MHonArc::CharEnt::str2sgml',
	    'koi8-f',            	'MHonArc::CharEnt::str2sgml',
	    'koi8-r',            	'MHonArc::CharEnt::str2sgml',
	    'koi8-u',            	'MHonArc::CharEnt::str2sgml',
	    'gost19768-87',            	'MHonArc::CharEnt::str2sgml',
	    'viscii',            	'MHonArc::CharEnt::str2sgml',
	    'big5-eten',		'MHonArc::CharEnt::str2sgml',
	    'big5-hkscs',		'MHonArc::CharEnt::str2sgml',
	    'gb2312',    		'MHonArc::CharEnt::str2sgml',
	    'macarabic',		'MHonArc::CharEnt::str2sgml',
	    'maccentraleurroman',	'MHonArc::CharEnt::str2sgml',
	    'maccroatian',		'MHonArc::CharEnt::str2sgml',
	    'maccyrillic',		'MHonArc::CharEnt::str2sgml',
	    'macgreek',		        'MHonArc::CharEnt::str2sgml',
	    'machebrew',		'MHonArc::CharEnt::str2sgml',
	    'macicelandic',		'MHonArc::CharEnt::str2sgml',
	    'macromanian',		'MHonArc::CharEnt::str2sgml',
	    'macroman',		        'MHonArc::CharEnt::str2sgml',
	    'macthai',		        'MHonArc::CharEnt::str2sgml',
	    'macturkish',		'MHonArc::CharEnt::str2sgml',
	    'hp-roman8',		'MHonArc::CharEnt::str2sgml',
	    'default',     		'-ignore-',
	);
	%readmail::MIMECharSetConvertersSrc = (
	    # Character set		Converter Function
	    #-----------------------------------------------------------------
	    'plain',     		undef,
	    'us-ascii',   		undef,
	    'iso-8859-1',   		'MHonArc/CharEnt.pm',
	    'iso-8859-2',   		'MHonArc/CharEnt.pm',
	    'iso-8859-3',   		'MHonArc/CharEnt.pm',
	    'iso-8859-4',   		'MHonArc/CharEnt.pm',
	    'iso-8859-5',   		'MHonArc/CharEnt.pm',
	    'iso-8859-6',   		'MHonArc/CharEnt.pm',
	    'iso-8859-7',   		'MHonArc/CharEnt.pm',
	    'iso-8859-8',   		'MHonArc/CharEnt.pm',
	    'iso-8859-9',   		'MHonArc/CharEnt.pm',
	    'iso-8859-10',   		'MHonArc/CharEnt.pm',
	    'iso-8859-11',   		'MHonArc/CharEnt.pm',
	    'iso-8859-13',   		'MHonArc/CharEnt.pm',
	    'iso-8859-14',   		'MHonArc/CharEnt.pm',
	    'iso-8859-15',   		'MHonArc/CharEnt.pm',
	    'iso-8859-16',   		'MHonArc/CharEnt.pm',
	    'iso-2022-jp',   		'MHonArc/CharEnt.pm',
	    'iso-2022-kr',    		'MHonArc/CharEnt.pm',
	    'euc-jp',    		'MHonArc/CharEnt.pm',
	    'utf-8',    		'MHonArc/CharEnt.pm',
	    'cp866',    		'MHonArc/CharEnt.pm',
	    'cp932',    		'MHonArc/CharEnt.pm',
	    'cp936',    		'MHonArc/CharEnt.pm',
	    'cp949',    		'MHonArc/CharEnt.pm',
	    'cp950',    		'MHonArc/CharEnt.pm',
	    'cp1250',   		'MHonArc/CharEnt.pm',
	    'cp1251',   		'MHonArc/CharEnt.pm',
	    'cp1252',   		'MHonArc/CharEnt.pm',
	    'cp1253',   		'MHonArc/CharEnt.pm',
	    'cp1254',   		'MHonArc/CharEnt.pm',
	    'cp1255',   		'MHonArc/CharEnt.pm',
	    'cp1256',   		'MHonArc/CharEnt.pm',
	    'cp1257',   		'MHonArc/CharEnt.pm',
	    'cp1258',   		'MHonArc/CharEnt.pm',
	    'koi-0',            	'MHonArc/CharEnt.pm',
	    'koi-7',            	'MHonArc/CharEnt.pm',
	    'koi8-a',            	'MHonArc/CharEnt.pm',
	    'koi8-b',            	'MHonArc/CharEnt.pm',
	    'koi8-e',            	'MHonArc/CharEnt.pm',
	    'koi8-f',            	'MHonArc/CharEnt.pm',
	    'koi8-r',            	'MHonArc/CharEnt.pm',
	    'koi8-u',            	'MHonArc/CharEnt.pm',
	    'gost19768-87',            	'MHonArc/CharEnt.pm',
	    'viscii',            	'MHonArc/CharEnt.pm',
	    'big5-eten',		'MHonArc/CharEnt.pm',
	    'big5-hkscs',		'MHonArc/CharEnt.pm',
	    'gb2312',    		'MHonArc/CharEnt.pm',
	    'macarabic',		'MHonArc/CharEnt.pm',
	    'maccentraleurroman',	'MHonArc/CharEnt.pm',
	    'maccroatian',		'MHonArc/CharEnt.pm',
	    'maccyrillic',		'MHonArc/CharEnt.pm',
	    'macgreek',		        'MHonArc/CharEnt.pm',
	    'machebrew',		'MHonArc/CharEnt.pm',
	    'macicelandic',		'MHonArc/CharEnt.pm',
	    'macromanian',		'MHonArc/CharEnt.pm',
	    'macroman',		        'MHonArc/CharEnt.pm',
	    'macthai',		        'MHonArc/CharEnt.pm',
	    'macturkish',		'MHonArc/CharEnt.pm',
	    'hp-roman8',		'MHonArc/CharEnt.pm',
	    'default',     		undef,
	);
	$IsDefault{'CHARSETCONVERTERS'} = 1;
    }

    ##	Default charset aliases
    unless (%readmail::MIMECharsetAliases) {
	readmail::MAILset_charset_aliases({ 
	    'us-ascii'     => [ 'ascii',
				'ansi_x3.4-1968',
				'iso646', 'iso646-us', 'iso646.irv:1991',
				'cp367', 'ibm367',
				'csascii',
				'iso-ir-6',
				'us' ],
	    'iso-8859-1'   => [ 'latin1', 'l1',
				'iso_8859_1', 'iso_8859-1:1987',
			        'iso8859-1', 'iso8859_1', '8859-1', '8859_1',
				'cp819', 'ibm819',
				'x-mac-latin1',
				'iso-ir-100' ],
	    'iso-8859-2'   => [ 'latin2', 'l2',
				'iso_8859_2', 'iso_8859-2:1987',
			        'iso8859-2', 'iso8859_2', '8859-2', '8859_2',
				'iso-ir-101' ],
	    'iso-8859-3'   => [ 'latin3', 'l3',
				'iso_8859_3', 'iso_8859-3:1988',
			        'iso8859-3', 'iso8859_3', '8859-3', '8859_3',
				'iso-ir-109' ],
	    'iso-8859-4'   => [ 'latin4', 'l4',
				'iso_8859_4', 'iso_8859-4:1988',
			        'iso8859-4', 'iso8859_4', '8859-4', '8859_4',
				'iso-ir-110' ],
	    'iso-8859-5'   => [ 'iso_8859-5:1988',
				'cyrillic',
				'iso-ir-144' ],
	    'iso-8859-6'   => [ 'iso_8859-6:1987',
				'arabic',
				'asmo-708',
				'ecma-114',
				'iso-ir-127' ],
	    'iso-8859-7'   => [ 'iso_8859-7:1987',
				'greek', 'greek8',
				'ecma-118',
				'elot_928',
				'iso-ir-126' ],
	    'iso-8859-8'   => [ 'iso-8859-8-i', 'iso_8859-8:1988',
				'hebrew',
				'iso-ir-138' ],
	    'iso-8859-9'   => [ 'latin5', 'l5',
				'iso_8859_9', 'iso-8859_9:1989',
			        'iso8859-9', 'iso8859_9', '8859-9', '8859_9',
				'iso-ir-148' ],
	    'iso-8859-10'  => [ 'latin6', 'l6',
				'iso_8859_10', 'iso_8859-10:1993',
			        'iso8859-10', 'iso8859_10',
				'8859-10', '8859_10',
				'iso-ir-157' ],
	    'iso-8859-13'  => [ 'latin7' ,'l7' ],
	    'iso-8859-14'  => [ 'latin8' ,'l8' ],
	    'iso-8859-15'  => [ 'latin9', 'latin0', 'l9', 'l0',
				'iso_8859_15',
				'iso8859-15', 'iso8859_15',
				'8859-15', '8859_15' ],
	    'iso-2022-jp'  => [ 'iso-2022-jp-1' ],
	    'utf-8'        => [ 'utf8' ],
	    'cp932'        => [ 'shiftjis', 'shift_jis', 'shift-jis',
				'x-sjis',
				'ms_kanji',
				'csshiftjis' ],
	    'cp936'        => [ 'gbk',
				'ms936',
				'windows-936' ],
	    'cp949'        => [ 'euc-kr',
				'ks_c_5601-1987', 'ks_c_5601-1989',
				'ksc_5601',
				'iso-ir-149',
				'windows-949', 'ms949',
				'korean' ],
	    'cp950'        => [ 'windows-950' ],
	    'cp1250'       => [ 'windows-1250' ],
	    'cp1251'       => [ 'windows-1251' ],
	    'cp1252'       => [ 'windows-1252' ],
	    'cp1253'       => [ 'windows-1253' ],
	    'cp1254'       => [ 'windows-1254' ],
	    'cp1255'       => [ 'windows-1255' ],
	    'cp1256'       => [ 'windows-1256' ],
	    'cp1257'       => [ 'windows-1257' ],
	    'cp1258'       => [ 'windows-1258' ],
	    'koi-0'          => [ 'gost-13052' ],
	    'koi8-e'         => [ 'iso-ir-111',
				  'ecma-113:1986' ],
	    'koi8-r'         => [ 'cp878' ],
	    'gost-19768-87'  => [ 'ecma-cyrillic',
				  'ecma-113', 'ecma-113:1988' ],
	    'big5-eten'      => [ 'big5', 'csbig5',
				  'tcs-big5', 'tcsbig5' ],
	    'big5-hkscs'     => [ 'big5hkscs', 'big5hk',
				  'hkscs-big5', 'hk-big5' ],
	    'gb2312'	     => [ 'gb_2312-80', 'csgb2312', 'hz-gb-2312',
				  'iso-ir-58',
				  'euc-cn',
				  'chinese',
				  'csiso58gb231280' ],
	    'macarabic'	         => [ 'apple-arabic',
				      'x-mac-arabic' ],
	    'maccentraleurroman' => [ 'apple-centeuro',
				      'x-mac-centraleurroman' ],
	    'maccroatian'        => [ 'apple-croatian',
				      'x-mac-croatian' ],
	    'maccyrillic'        => [ 'apple-cyrillic',
				      'x-mac-cyrillic' ],
	    'macgreek'	         => [ 'apple-greek',
				      'x-mac-greek' ],
	    'machebrew'	         => [ 'apple-hebrew',
				      'x-mac-hebrew' ],
	    'macicelandic'       => [ 'apple-iceland',
				      'x-mac-icelandic' ],
	    'macromanian'        => [ 'apple-romanian',
				      'x-mac-romanian' ],
	    'macroman'	         => [ 'apple-roman',
				      'mac', 'macintosh',
				      'x-mac-roman' ],
	    'macthai'	         => [ 'apple-thai',
				      'x-mac-thai' ],
	    'macturkish'         => [ 'apple-turkish',
				      'x-mac-turkish' ],
	});
	$IsDefault{'CHARSETALIASES'} = 1;
    }

    ##  Content-Types to exclude:
    ##    Nothing is excluded by default.
    unless (%readmail::MIMEExcs) {
	$IsDefault{'MIMEEXCS'} = 1;
    }

    ##  Content-type multipart/alternative preferences
    ##    Note: The variable is not a readmail package variable, but it
    ##	    is used to set readmail package properties.
    unless (@MIMEAltPrefs) {
	$IsDefault{'MIMEALTPREFS'} = 1;
    }

    ##	Text encoding
    unless ($readmail::TextEncode) {
	$IsDefault{'TEXTENCODE'} = 1;
    }
}

##---------------------------------------------------------------------------
1;
