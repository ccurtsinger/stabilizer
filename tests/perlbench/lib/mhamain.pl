##---------------------------------------------------------------------------##
##  File:
##	$Id: mhamain.pl,v 2.71 2003/08/13 03:03:17 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##	Main library for MHonArc.
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1995-2003	Earl Hood, mhonarc@mhonarc.org
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

require 5;

$VERSION = '2.6.8-CPU2006';
$VINFO =<<EndOfInfo;
  MHonArc v$VERSION (Perl $] $^O)
  Copyright (C) 1995-2003  Earl Hood, mhonarc\@mhonarc.org
  MHonArc comes with ABSOLUTELY NO WARRANTY and MHonArc may be copied only
  under the terms of the GNU General Public License, which may be found in
  the MHonArc distribution.
EndOfInfo

###############################################################################
BEGIN {
    ## Check what system we are executing under
    require 'osinit.pl';  &OSinit();

    ## Check if running setuid/setgid
    $TaintMode = 0;
    if ($UNIX && (( $< != $> ) || ( $( != $) ))) {
	## We do not support setuid since there are too many
	## security problems to handle, and if we did, mhonarc
	## would probably not be very useful.
	die "ERROR: setuid/setgid execution not supported!\n";

	#$TaintMode = 1;
	#$ENV{'PATH'}  = '/bin:/usr/bin';
	#$ENV{'SHELL'} = '/bin/sh'  if exists $ENV{'SHELL'};
	#delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
    }
}
###############################################################################

$CODE		= 0;
$ERROR  	= "";
@OrgARGV	= ();
$ArchiveOpen	= 0;

$_msgid_cnt	= 0;

my %_sig_org	= ();
my @_term_sigs	= qw(
    ABRT ALRM BUS FPE HUP ILL INT IOT PIPE POLL PROF QUIT SEGV
    TERM TRAP USR1 USR2 VTALRM XCPU XFSZ
);

###############################################################################
##	Public routines
###############################################################################

##---------------------------------------------------------------------------
##	initialize() does some initialization stuff.  Should be called
##	right after mhamain.pl is called.
##
sub initialize {
    ##	Turn off buffered I/O to terminal
    my($curfh) = select(STDOUT);  $| = 1;  select($curfh);

    ##	Require essential libraries
    require 'mhlock.pl';
    require 'mhopt.pl';

    ##	Init some variables
    $ISLOCK     = 0;	# Database lock flag

    $StartTime	= 0;	# CPU start time of processing
    $EndTime	= 0;	# CPU end time of processing
}

##---------------------------------------------------------------------------
##	open_archive opens the archive
##
sub open_archive {
    eval { $StartTime = (times)[0]; };

    ## Set @ARGV if options passed in
    if (@_) { @OrgARGV = @ARGV; @ARGV = @_; }

    ## Get options
    my($optstatus);
    eval {
	set_handler();
	$optstatus = get_resources();
    };

    ## Check for error
    if ($@ || $optstatus <= 0) {
	if ($@) {
	    if ($@ =~ /signal caught/) {
		$CODE = 0;
	    } else {
		$CODE = int($!) ? int($!) : 255;
	    }
	    $ERROR = $@;
	    warn "\n", $ERROR;

	} else {
	    if ($optstatus < 0) {
		$CODE = $! = 255;
		$ERROR = "ERROR: Problem loading resources\n";
	    } else {
		$CODE = 0;
	    }
	}
	close_archive();
	return 0;
    }
    $ArchiveOpen = 1;
    1;
}

##---------------------------------------------------------------------------
##	close_archive closes the archive.
##
sub close_archive {
    my $reset_sigs = shift;

    ## Remove lock
    &$UnlockFunc()  if defined(&$UnlockFunc);

    ## Reset signal handlers
    reset_handler()  if $reset_sigs;

    ## Stop timing
    eval { $EndTime = (times)[0]; };
    my $cputime = $EndTime - $StartTime;

    ## Output time (if specified)
    if ($TIME) {
	printf(STDERR "\nTime: %.2f CPU seconds\n", $cputime);
    }

    ## Restore @ARGV
    if (@OrgARGV) { @ARGV = @OrgARGV; }

    $ArchiveOpen = 0;

    ## Return time
    $cputime;
}

##---------------------------------------------------------------------------
##	Routine to process input.  If no errors, routine returns the
##	CPU time taken.  If an error, returns undef.
##
sub process_input {

    ## Do processing
    if ($ArchiveOpen) {
	# archive already open, so doit
	eval { doit(); };

    } else {
	# open archive first (implictely pass @_ to open_archive)
	if (&open_archive) {
	    eval { doit(); };
	} else {
	    return undef;
	}
    }

    # check for error
    if ($@) {
	if ($@ =~ /signal caught/) {
	    $CODE = 0  unless $CODE;
	} else {
	    $CODE = (int($!) ? int($!) : 255)  unless $CODE;
	}
	$ERROR = $@;
	close_archive();
	warn "\n", $ERROR;
	return undef;
    }

    ## Cleanup
    close_archive();
}

###############################################################################
##	Private routines
###############################################################################

##---------------------------------------------------------------------------
##	Routine that does the work
##
sub doit {

    ## Check for non-archive modification modes.

    ## Just converting a single message to HTML
    if ($SINGLE) {
	single();
	return 1;
    }

    ## Text message listing of archive to standard output.
    if ($SCAN) {
	scan();
	return 1;
    }

    ## Annotating messages
    if ($ANNOTATE) {
	print STDOUT "Annotating messages in $OUTDIR ...\n"  unless $QUIET;

	if (!defined($NoteText)) {
	    print STDOUT "Please enter note text (terminated with EOF char):\n"
		unless $QUIET;
	    $NoteText = join("", <$MhaStdin>);
	}
	return annotate(@ARGV, $NoteText);
    }

    ## Removing messages
    if ($RMM) {
	print STDOUT "Removing messages from $OUTDIR ...\n"
	    unless $QUIET;
	return rmm(@ARGV);
    }

    ## HTML message listing to standard output.
    if ($IDXONLY) {
	IDXPAGE: {
	    compute_page_total();
	    if ($IdxPageNum && $MULTIIDX) {
		if ($IdxPageNum =~ /first/i) {
		    $IdxPageNum = 1;
		    last IDXPAGE;
		} 
		if ($IdxPageNum =~ /last/i) {
		    $IdxPageNum = $NumOfPages;
		    last IDXPAGE;
		}
		$IdxPageNum = int($IdxPageNum);
		last IDXPAGE  if $IdxPageNum;
	    }
	    $MULTIIDX   = 0;
	    $IdxPageNum = 1;
	    $NumOfPages = 1;
	}
	if ($THREAD) {
	    compute_threads();
	    write_thread_index($IdxPageNum);
	} else {
	    write_main_index($IdxPageNum);
	}
	return 1;
    }

    ## Get here, we are processing mail folders
    my($index, $fields, $fh, $cur_msg_cnt);

    $cur_msg_cnt = $NumOfMsgs;
    ##-------------------##
    ## Read mail folders ##
    ##-------------------##
    ## Just editing pages
    if ($EDITIDX) {
	print STDOUT "Editing $OUTDIR layout ...\n"  unless $QUIET;

    ## Adding a single message
    } elsif ($ADDSINGLE) {
	print STDOUT "Adding message to $OUTDIR\n"  unless $QUIET;
	$handle = $ADD;

	## Read mail head
	($index, $fields) = read_mail_header($handle);

	if ($index) {
	    $AddIndex{$index} = 1;
	    read_mail_body($handle, $index, $fields, $NoMsgPgs);
	}

    ## Adding/converting mail{boxes,folders}
    } else {
	print STDOUT ($ADD ? "Adding" : "Converting"), " messages to $OUTDIR"
	    unless $QUIET;
	my($mbox, $mesgfile, @files);

	MAILFOLDER: foreach $mbox (@ARGV) {

	    ## MH mail folder (a directory)
	    if (-d $mbox) {
		if (!opendir(MAILDIR, $mbox)) {
		    warn "\nWarning: Unable to open $mbox\n";
		    next;
		}
		$MBOX = 0;  $MH = 1;
		print STDOUT "\nReading $mbox "  unless $QUIET;
		@files = sort { $a <=> $b } grep(/$MHPATTERN/o,
						 readdir(MAILDIR));
		closedir(MAILDIR);

		local($_);
		MHFILE: foreach (@files) {
		    $mesgfile = "${mbox}${DIRSEP}${_}";
		    eval {
			$fh = file_open($mesgfile);
		    };
		    if ($@) {
			warn $@,
			     qq/...Skipping "$mesgfile"\n/;
			next MHFILE;
		    }
		    print STDOUT "."  unless $QUIET;
		    ($index, $fields) = read_mail_header($fh);

		    #  Process message if valid
		    if ($index) {
			if ($ADD && !$SLOW) { $AddIndex{$index} = 1; }
			read_mail_body($fh, $index, $fields, $NoMsgPgs);

			#  Check if conserving memory
			if ($SLOW && $DoArchive) {
			    output_mail($index, 1, 1);
			    $Update{$IndexNum{$index}} = 1;
			}
			if ($SLOW || !$DoArchive) {
			    delete $MsgHead{$index};
			    delete $Message{$index};
			}
		    }
		    close($fh);
		}

	    ## UUCP mail box file
	    } else {
		if ($mbox eq "-") {
		    $fh = $MhaStdin;
		} else {
		    eval {
			$fh = file_open($mbox);
		    };
		    if ($@) {
			warn $@,
			     qq/...Skipping "$mbox"\n/;
			next MAILFOLDER;
		    }
		}

		$MBOX = 1;  $MH = 0;
		print STDOUT "\nReading $mbox "  unless $QUIET;
		# while (<$fh>) { last if /$FROM/o; }
# CPU2006
#		MBOX: while (!eof($fh)) {
		MBOX: while ($#{@$fh} >= 0) {
		    print STDOUT "."  unless $QUIET;
		    ($index, $fields) = read_mail_header($fh);

		    if ($index) {
			if ($ADD && !$SLOW) { $AddIndex{$index} = 1; }
			read_mail_body($fh, $index, $fields, $NoMsgPgs);

			if ($SLOW && $DoArchive) {
			    output_mail($index, 1, 1);
			    $Update{$IndexNum{$index}} = 1;
			}
			if ($SLOW || !$DoArchive) {
			    delete $MsgHead{$index};
			    delete $Message{$index};
			}

		    } else {
			read_mail_body($fh, $index, $fields, 1);
		    }
		}
# CPU2006 - it was never opened
#		close($fh);

	    } # END: else UUCP mailbox
	} # END: foreach $mbox
    } # END: Else converting mailboxes
    print "\n"  unless $QUIET;

    ## All done if not creating an archive
    if (!$DoArchive) {
	return 1;
    }

    ## Check if there are any new messages
    if (!$EDITIDX && ($cur_msg_cnt > 0) &&
	    !scalar(%AddIndex) && !scalar(%Update)) {
	print STDOUT "No new messages\n"  unless $QUIET;
	return 1;
    }
    $NewMsgCnt = $NumOfMsgs - $cur_msg_cnt;

    ## Write pages
    &write_pages();
    1;
}

##---------------------------------------------------------------------------
##	write_pages writes out all archive pages and db
##
sub write_pages {
    my($i, $j, $key, $index, $tmp, $tmp2);
    my(@array2);
    my($mloc, $tloc);

    ## Remove old message if hit maximum size or expiration
    if (($MAXSIZE && ($NumOfMsgs > $MAXSIZE)) ||
	$ExpireTime ||
	$ExpireDateTime) {

	## Set @MListOrder and %Index2MLoc for properly marking messages
	## to be updated when a related messages are removed.  Thread
	## data should be around from db.

	@MListOrder = sort_messages();
	@Index2MLoc{@MListOrder} = (0 .. $#MListOrder);

	# Ignore termination signals
	&ign_signals();

	## Expiration based upon time
	foreach $index (sort_messages(0,0,0,0)) {
	    last  unless
		    ($MAXSIZE && ($NumOfMsgs > $MAXSIZE)) ||
		    (&expired_time(&get_time_from_index($index)));

	    &delmsg($index);

	    # Mark messages that need to be updated
	    if (!$NoMsgPgs) {
		$mloc = $Index2MLoc{$index};  $tloc = $Index2TLoc{$index};
		$Update{$IndexNum{$MListOrder[$mloc-1]}} = 1
		    if $mloc-1 >= 0;
		$Update{$IndexNum{$MListOrder[$mloc+1]}} = 1
		    if $mloc+1 <= $#MListOrder;
		$Update{$IndexNum{$TListOrder[$tloc-1]}} = 1
		    if $tloc-1 >= 0;
		$Update{$IndexNum{$TListOrder[$tloc+1]}} = 1
		    if $tloc+1 <= $#TListOrder;
		for ($i=2; $i <= $TSliceNBefore; ++$i) {
		    $Update{$IndexNum{$TListOrder[$tloc-$i]}} = 1
			if $tloc-$i >= 0;
		}
		for ($i=2; $i <= $TSliceNAfter; ++$i) {
		    $Update{$IndexNum{$TListOrder[$tloc+$i]}} = 1
			if $tloc-$i >= $#TListOrder;
		}
		foreach (@{$FollowOld{$index}}) {
		    $Update{$IndexNum{$_}} = 1;
		}
	    }

	    # Mark where index page updates start
	    if ($MULTIIDX) {
		$tmp = int($Index2MLoc{$index}/$IDXSIZE)+1;
		$IdxMinPg = $tmp
		    if ($tmp < $IdxMinPg || $IdxMinPg < 0);
		$tmp = int($Index2TLoc{$index}/$IDXSIZE)+1;
		$TIdxMinPg = $tmp
		    if ($tmp < $TIdxMinPg || $TIdxMinPg < 0);
	    }
	}
    }

    ## Reset MListOrder
    @MListOrder = sort_messages();
    @Index2MLoc{@MListOrder} = (0 .. $#MListOrder);

    ## Compute follow up messages
    compute_follow_ups(\@MListOrder);

    ## Compute thread information (sets ThreadList, TListOrder, Index2TLoc)
    compute_threads();

    ## Check for which messages to update when adding to archive
    if ($ADD) {
	if ($UPDATE_ALL) {
	    foreach $index (@MListOrder) { $Update{$IndexNum{$index}} = 1; }
	    $IdxMinPg = 0;
	    $TIdxMinPg = 0;

	} else {
	    $i = 0;
	    foreach $index (@MListOrder) {
		## Check for New follow-up links
		if (is_follow_ups_diff($index)) {
		    $Update{$IndexNum{$index}} = 1;
		}
		## Check if new message; must update links in prev/next msgs
		if ($AddIndex{$index}) {

		    # Mark where main index page updates start
		    if ($MULTIIDX) {
			$tmp = int($Index2MLoc{$index}/$IDXSIZE)+1;
			$IdxMinPg = $tmp
			    if ($tmp < $IdxMinPg || $IdxMinPg < 0);
		    }

		    # Mark previous/next messages
		    $Update{$IndexNum{$MListOrder[$i-1]}} = 1
			if $i > 0;
		    $Update{$IndexNum{$MListOrder[$i+1]}} = 1
			if $i < $#MListOrder;
		}
		## Check for New reference links
		foreach (@{$Refs{$index}}) {
		    $tmp = $MsgId{$_};
		    if (defined($IndexNum{$tmp}) && $AddIndex{$tmp}) {
			$Update{$IndexNum{$index}} = 1;
		    }
		}
		$i++;
	    }
	    $i = 0;
	    foreach $index (@TListOrder) {
		## Check if new message; must update links in prev/next msgs
		if ($AddIndex{$index}) {

		    # Mark where thread index page updates start
		    if ($MULTIIDX) {
			$tmp = int($Index2TLoc{$index}/$IDXSIZE)+1;
			$TIdxMinPg = $tmp
			    if ($tmp < $TIdxMinPg || $TIdxMinPg < 0);
		    }

		    # Mark previous/next message in thread
		    $Update{$IndexNum{$TListOrder[$i-1]}} = 1
			if $i > 0;
		    $Update{$IndexNum{$TListOrder[$i+1]}} = 1
			if $i < $#TListOrder;

		    $tloc = $Index2TLoc{$index};
		    for ($j=2; $j <= $TSliceNBefore; ++$j) {
			$Update{$IndexNum{$TListOrder[$tloc-$j]}} = 1
			    if $tloc-$j >= 0;
		    }
		    for ($j=2; $j <= $TSliceNAfter; ++$j) {
			$Update{$IndexNum{$TListOrder[$tloc+$j]}} = 1
			    if $tloc-$j >= $#TListOrder;
		    }
		}
		$i++;
	    }
	}
    }

    ##	Compute total number of pages
    $i = $NumOfPages;
    compute_page_total();

    ## Update all pages for $LASTPG$
    if ($UsingLASTPG && ($i != $NumOfPages)) {
	$IdxMinPg = 0;
	$TIdxMinPg = 0;
    }

    ##------------##
    ## Write Data ##
    ##------------##
    ign_signals();		# Ignore termination signals
    print STDOUT "\n"  unless $QUIET;

    ## Write indexes and mail
    write_mail()		unless $NoMsgPgs;
    write_main_index()  	if $MAIN;
    write_thread_index()	if $THREAD;

    ## Write database
    print STDOUT "Writing database ...\n"  unless $QUIET;
    output_db($DBPathName);

    ## Write any alternate indexes
    $IdxMinPg = 0; $TIdxMinPg = 0;
    my($rc, $rcfile);
    OTHERIDX: foreach $rc (@OtherIdxs) {
	$THREAD = 0;

	## find other index resource file
	IDXFIND: {
# CPU2006
#	    if (-e $rc) {
	    if (file_exists($rc)) {
		# in current working directory
		$rcfile = $rc;
		last IDXFIND;
	    }
	    if (defined $MainRcDir) {
		# check if located with main resource file
		$rcfile = join($DIRSEP, $MainRcDir, $rc);
# CPU2006
#		last IDXFIND  if -e $rcfile;
		last IDXFIND  if file_exists($rcfile);
	    }
	    if (defined $ENV{'HOME'}) {
		# check if in home directory
		$rcfile = join($DIRSEP, $ENV{'HOME'}, $rc);
# CPU2006
#		last IDXFIND  if -e $rcfile;
		last IDXFIND  if file_exists($rcfile);
	    }

	    # check if in archive directory
	    $rcfile = join($DIRSEP, $OUTDIR, $rc);
# CPU2006
#	    last IDXFIND  if -e $rcfile;
	    last IDXFIND  if file_exists($rcfile);

	    # look thru @INC to find file
	    local($_);
	    foreach (@INC) {
		$rcfile = join($DIRSEP, $_, $rc);
# CPU2006
#		if (-e $rcfile) {
		if (file_exists($rcfile)) {
		    last IDXFIND;
		}
	    }
	    warn qq/Warning: Unable to find resource file "$rc"\n/;
	    next OTHERIDX;
	}
	    
	## read resource file and print index
	if (read_resource_file($rcfile)) {
	    if ($THREAD) {
		@TListOrder = ();
		write_thread_index();
	    } else {
		@MListOrder = ();
		write_main_index();
	    }
	}
    }

    unless ($QUIET) {
	print STDOUT "$NewMsgCnt new messages\n"  if $NewMsgCnt > 0;
	print STDOUT "$NumOfMsgs total messages\n";
    }

} ## End: write_pages()

##---------------------------------------------------------------------------
##	Compute follow-ups
##
sub compute_follow_ups {
    my $idxlst = shift;
    my($index, $tmp, $tmp2);

    %Follow = ();
    foreach $index (@$idxlst) {
	$FolCnt{$index} = 0  unless $FolCnt{$index};
	if (defined($Refs{$index}) && scalar(@{$Refs{$index}})) {
	    $tmp2 = $Refs{$index}->[-1];
	    next  unless defined($MsgId{$tmp2}) &&
			 defined($IndexNum{$MsgId{$tmp2}});
	    $tmp = $MsgId{$tmp2};
	    if ($Follow{$tmp}) { push(@{$Follow{$tmp}}, $index); }
	    else { $Follow{$tmp} = [ $index ]; }
	    ++$FolCnt{$tmp};
	}
    }
}

##---------------------------------------------------------------------------
##	Compute total number of pages
##
sub compute_page_total {
    if ($MULTIIDX && $IDXSIZE) {
	$NumOfPages   = int($NumOfMsgs/$IDXSIZE);
	++$NumOfPages      if ($NumOfMsgs/$IDXSIZE) > $NumOfPages;
	$NumOfPages   = 1  if $NumOfPages == 0;
    } else {
	$NumOfPages = 1;
    }
}

##---------------------------------------------------------------------------
##	write_mail outputs converted mail.  It takes a reference to an
##	array containing indexes of messages to output.
##
sub write_mail {
    my($hack) = (0);
    print STDOUT "Writing mail "  unless $QUIET;

    if ($SLOW && !$ADD) {
	$ADD = 1;
	$hack = 1;
    }

    foreach $index (@MListOrder) {
	print STDOUT "."  unless $QUIET;
	output_mail($index, $AddIndex{$index}, 0);
    }

    if ($hack) {
	$ADD = 0;
    }

    print STDOUT "\n"  unless $QUIET;
}

##---------------------------------------------------------------------------
##	read_mail_header() is responsible for parsing the header of
##	a mail message and loading message information into hash
##	structures.
##
##	($index, $header_fields_ref) = read_mail_header($filehandle);
##
sub read_mail_header {
    my $handle = shift;
    my($date, $tmp, $i, $field, $value);
    my($from, $sub, $msgid, $ctype);
    local($_);

    my $index  = undef;
    my $msgnum = undef;
    my @refs   = ();
    my @array  = ();
    my($fields, $header) = readmail::MAILread_file_header($handle);

    ##---------------------------##
    ## Check for no archive flag ##
    ##---------------------------##
    if ( $CheckNoArchive &&
	 ((defined($fields->{'restrict'}) &&
	  grep { /no-external-archive/i } @{$fields->{'restrict'}}) ||
	  (defined($fields->{'x-no-archive'}) &&
	   grep { /yes/i } @{$fields->{'x-no-archive'}})) ) {
	return undef;
    }

    ##----------------------------------##
    ## Check for user-defined exclusion ##
    ##----------------------------------##
    if ($MsgExcFilter) {
	return undef  if mhonarc::message_exclude($header);
    }

    ##------------##
    ## Get Msg-ID ##
    ##------------##
    $msgid = $fields->{'message-id'}[0] || $fields->{'msg-id'}[0] || 
	     $fields->{'content-id'}[0];
    if (defined($msgid)) {
	if ($msgid =~ /<([^>]*)>/) {
	    $msgid = $1;
	} else {
	    $msgid =~ s/^\s+//;
	    $msgid =~ s/\s+$//;
	}
    } else {
        # create bogus ID if none exists
	eval {
	    # create message-id using md5 digest of header;
	    # can potentially skip over already archived messages w/o id
	    require Digest::MD5;
	    $msgid = join("", Digest::MD5::md5_hex($header),
			      '@NO-ID-FOUND.mhonarc.org');
	};
	if ($@) {
	    # unable to require, so create arbitary message-id
	    $msgid = join("", $$,'.',time,'.',$_msgid_cnt++,
			      '@NO-ID-FOUND.mhonarc.org');
	}
    }

    ## Return if message already exists in archive
    if ($msgid && defined($index = $MsgId{$msgid})) {
	if ($Reconvert) {
	    $msgnum = $IndexNum{$index};
	    delmsg($index);
	    $index = undef;
	} else {
	    return undef;
	}
    }

    ##----------##
    ## Get date ##
    ##----------##
    $date = "";
    foreach (@_DateFields) {
	($field, $i) = @{$_}[0,1];
	next  unless defined($fields->{$field}) &&
		     defined($value = $fields->{$field}[$i]);

	## Treat received field specially
	if ($field eq 'received') {
	    @array = split(/;/, $value);
#	    if ((scalar(@array) <= 1) || (scalar(@array) > 2)) {
#		warn qq/\nWarning: Received header field looks improper:\n/,
#		       qq/         Received: $value\n/,
#		       qq/         Message-Id: <$msgid>\n/;
#	    }
	    $date = pop @array;
	## Any other field should just be a date
	} else {
	    $date = $value;
	}
	$date =~ s/^\s+//;  $date =~ s/\s+$//;

	## See if time_t can be determined.
	if (($date =~ /\w/) && (@array = parse_date($date))) {
	    $index = get_time_from_date(@array[1..$#array]);
	    last;
	}
    }
    if (!$index) {
	warn qq/\nWarning: Could not parse date for message\n/,
	       qq/         Message-Id: <$msgid>\n/;
	# Use current time
	$index = time;
	# Set date string to local date if not defined
	$date  = &time2str("", $index, 1)  unless $date =~ /\S/;
    }

    ## Return if message too old to add (note, $index just contains time).
    if (&expired_time($index)) {
	return undef;
    }

    ##-------------##
    ## Get Subject ##
    ##-------------##
    if (defined($fields->{'subject'}) && ($fields->{'subject'}[0] =~ /\S/)) {
	($sub = $fields->{'subject'}[0]) =~ s/\s+$//;
	$sub = subject_strip($sub)  if $SubStripCode;
    } else {
	$sub = '';
    }

    ##----------##
    ## Get From ##
    ##----------##
    $from = "";
    foreach (@FromFields) {
	next  unless defined $fields->{$_};
	$from = $fields->{$_}[0];
	last;
    }
    $from = 'Unknown'  unless $from;

    ##----------------##
    ## Get References ##
    ##----------------##
    if (defined($fields->{'references'})) {
	$tmp = $fields->{'references'}[0];
	while ($tmp =~ s/<([^<>]+)>//) {
	    push(@refs, $1);
	}
    }
    if (defined($fields->{'in-reply-to'})) {
	my $irtoid;
	foreach (@{$fields->{'in-reply-to'}}) {
	    $tmp = $_;
	    $irtoid = "";
	    while ($tmp =~ s/<([^<>]+)>//) { $irtoid = $1 };
	    push(@refs, $irtoid)  if $irtoid;
	}
    }
    @refs = remove_dups(\@refs);        # Remove duplicate msg-ids

    ##------------------##
    ## Get Content-Type ##
    ##------------------##
    if (defined($fields->{'content-type'})) {
	($ctype = $fields->{'content-type'}[0]) =~ m%^\s*([\w\-\./]+)%;
	$ctype = lc ($1 || 'text/plain');
    } else {
	$ctype = 'text/plain';
    }

    ## Insure uniqueness of index
    $index .= $X . sprintf('%d',(defined($msgnum)?$msgnum:($LastMsgNum+1)));

    ## Set mhonarc fields.  Note how values are NOT arrays.
    $fields->{'x-mha-index'} = $index;
    $fields->{'x-mha-message-id'} = $msgid;
    $fields->{'x-mha-from'} = $from;
    $fields->{'x-mha-subject'} = $sub;
    $fields->{'x-mha-content-type'} = $ctype;

    ## Invoke callback if defined
    if (defined($CBMessageHeadRead) && defined(&$CBMessageHeadRead)) {
	return undef  unless &$CBMessageHeadRead($fields, $header);
    }

    $From{$index} = $from;
    $Date{$index} = $date;
    $Subject{$index} = $sub;
    $MsgHead{$index} = htmlize_header($fields);
    $ContentType{$index} = $ctype;
    if ($msgid) {
	$MsgId{$msgid} = $index;
	$NewMsgId{$msgid} = $index;	# Track new message-ids
	$Index2MsgId{$index} = $msgid;
    }
    if (defined($msgnum)) {
	$IndexNum{$index} = $msgnum;
	++$NumOfMsgs; # Counteract decrement by delmsg
    } else {
	$IndexNum{$index} = getNewMsgNum();
    }

    $Refs{$index} = [ @refs ]  if (@refs);

    ## Grab any extra fields to store
    foreach $field (@ExtraHFields) {
	next  unless $fields->{$field};
	if (!defined($tmp = $ExtraHFields{$index})) {
	    $tmp = $ExtraHFields{$index} = { };
	}
	if ($HFieldsAddr{$field}) {
	    $tmp->{$field} = join(', ', @{$fields->{$field}});
	} else {
	    $tmp->{$field} = join(' ', @{$fields->{$field}});
	}
    }

    ($index, $fields);
}

##---------------------------------------------------------------------------
##	read_mail_body() reads in the body of a message.  The returned
##	filtered body is in $ret.
##
##	$html = read_mail_body($fh, $index, $fields_hash_ref,
##			       $skipConversion);
##
sub read_mail_body {
    my($handle, $index, $fields, $skip) = @_;
    my($ret, $data) = ('', '');
    my(@files);
    local($_);

    ## Slurp up message body
    ##	UUCP mailbox
    if ($MBOX) {
	if ($CONLEN && defined($fields->{"content-length"})) {
	    my($len, $cnt) = ($fields->{"content-length"}[0], 0);
	    if ($len) {
# CPU2006
#		while (<$handle>) {
		while (defined($_ = shift(@$handle))) {
		    $cnt += length($_);		# Increment byte count
		    $data .= $_  unless $skip;  # Save data
		    last  if $cnt >= $len	# Last if hit length
		}
	    }
	    # Slurp up bogus data if required (should I do this?)
# CPU2006
#	    while (!/$FROM/o && !eof($handle)) {
#		$_ = <$handle>;
#	    }
	    while (!/$FROM/o && $#{@$$handle} >= 0) {
		$_ = shift(@$handle);
	    }

	} else {				# No content-length
# CPU2006
#	    while (<$handle>) {
            while (defined($_ = shift(@$handle))) {
		last  if /$FROM/o;
		$data .= $_  unless $skip;
	    }
	}

    ##	MH message file
    } elsif (!$skip) {
	local $/ = undef;
	$data = <$handle>;
    }

    return ''  if $skip;

    ## Invoke callback if defined
    if (defined($CBRawMessageBodyRead) && defined(&$CBRawMessageBodyRead)) {
	&$CBRawMessageBodyRead($fields, \$data);
    }

    ## Define "globals" for use by filters
    ##	NOTE: This stuff can be handled better, and will be done
    ##	      when/if I get around to rewriting mhonarc in (OO) Perl 5.
    $MHAindex  = $index;
    $MHAmsgnum = &fmt_msgnum($IndexNum{$index});
    $MHAmsgid  = $Index2MsgId{$index};

    ## Filter data
    ($ret, @files) = &readmail::MAILread_body($fields, \$data);
    $ret = ''     unless defined $ret;
    @files = ( )  unless @files;

    ## Invoke callback if defined
    if (defined($CBMessageBodyRead) && defined(&$CBMessageBodyRead)) {
	&$CBMessageBodyRead($fields, \$ret, \@files);
	$Message{$index} = $ret;
    } else {
	$Message{$index} = $ret;
    }

    if (!defined($ret) || $ret eq '') {
	warn qq/\n/,
	     qq/Warning: Empty body data generated:\n/,
	     qq/         Message-Id: $MHAmsgid\n/,
	     qq/         Message Number: $MHAmsgnum\n/,
	     qq/         Content-Type/,
			 ($fields->{'content-type'}[0] || 'text/plain'),
			 qq/\n/;
	$ret = '';
    }
    if (@files) {
	$Derived{$index} = [ @files ];
    }
    $ret;
}

##---------------------------------------------------------------------------
##	Output/edit a mail message.
##	    $index	=> current index (== $array[$i])
##	    $force	=> flag if mail is written and not editted, regardless
##	    $nocustom	=> ignore sections with user customization
##
##	This function returns ($msgnum, $filename) if everything went
##	okay, but no calls to this routine check the return values.
##
sub output_mail {
    my($index, $force, $nocustom) = @_;
    my($msgi, $tmp, $tmp2, $template, @array2);
    my($msghandle, $msginfh);

    my $msgnum	     = $IndexNum{$index};
    if (!$SINGLE && !defined($msgnum)) {
      # Something bad must have happened to message, so we just
      # quietly return.
      return;
    }

    my $adding	     = ($ADD && !$force && !$SINGLE);
    my $i_p0 	     = fmt_msgnum($msgnum);
    my $filename     = msgnum_filename($msgnum);
    my $filepathname = join($DIRSEP, $OUTDIR, $filename);
    my $tmppathname;

    if ($adding) {
	return ($i_p0, $filename)  unless $Update{$msgnum};
	#&file_rename($filepathname, $tmppathname);
	eval {
	  $msginfh = file_open($filepathname);
	};
	if ($@) {
	  # Something is screwed up with archive: We try to delete
	  # message from database since message file appears to have
	  # disappeared
	  warn $@,
	       qq/...Will attempt to remove message and continue on\n/;
	  delmsg($index);

	  # Nothing else to do, so return.
	  return;
	}
    }
    if ($SINGLE) {
	$msghandle = \*STDOUT;
    } else {
	($msghandle, $tmppathname) =
	    file_temp('tmsg'.$i_p0.'_XXXXXXXXXX', $OUTDIR);
    }

    ## Output HTML header
    if ($adding) {
# CPU2006
#	while (<$msginfh>) {
	while (defined($_ = shift(@$msginfh))) {
	    last  if /<!--X-Body-Begin/;
	}
    }
    if (!$nocustom) {
	#&defineIndex2MsgId();

	$template = ($MSGPGSSMARKUP ne '') ? $MSGPGSSMARKUP : $SSMARKUP;
	if ($template ne '') {
	    $template =~ s/$VarExp/&replace_li_var($1,$index)/geo;
	    print $msghandle $template;
	}

	# Output comments -- more informative, but can be used for
	#		     error recovering.
# CPU2006
#	print $msghandle 
#	    "<!-- ", commentize("MHonArc v$VERSION"), " -->\n",
#	    "<!--X-Subject: ",      commentize($Subject{$index}), " -->\n",
#	    "<!--X-From-R13: ",	    commentize(mrot13($From{$index})), " -->\n",
#	    "<!--X-Date: ", 	    commentize($Date{$index}), " -->\n",
#	    "<!--X-Message-Id: ",   commentize($Index2MsgId{$index}), " -->\n",
#	    "<!--X-Content-Type: ", commentize($ContentType{$index}), " -->\n";
	push @$msghandle , (
	    "<!-- ". commentize("MHonArc v$VERSION"). " -->\n",
	    "<!--X-Subject: ".      commentize($Subject{$index}). " -->\n",
	    "<!--X-From-R13: ".	    commentize(mrot13($From{$index})). " -->\n",
	    "<!--X-Date: ". 	    commentize($Date{$index}). " -->\n",
	    "<!--X-Message-Id: ".   commentize($Index2MsgId{$index}). " -->\n",
	    "<!--X-Content-Type: ". commentize($ContentType{$index}). " -->\n");
		  #ContentType

	if (defined($Refs{$index})) {
	    foreach (@{$Refs{$index}}) {
# CPU2006
#		print $msghandle
#		    "<!--X-Reference: ", commentize($_), " -->\n";
		push @$msghandle,
		    "<!--X-Reference: ". commentize($_). " -->\n";
			  #Reference-Id
	    }
	}
	if (defined($Derived{$index})) {
	    foreach (@{$Derived{$index}}) {
# CPU2006
#		print $msghandle "<!--X-Derived: ", commentize($_), " -->\n";
		push @$msghandle, "<!--X-Derived: ". commentize($_). " -->\n";
	    }
	}
# CPU2006
#	print $msghandle "<!--X-Head-End-->\n";
	push @$msghandle, "<!--X-Head-End-->\n";

	# Add in user defined markup
	($template = $MSGPGBEG) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
#	print $msghandle $template;
	push @$msghandle, $template;
    }
# CPU2006
#    print $msghandle "<!--X-Body-Begin-->\n";
    push @$msghandle, "<!--X-Body-Begin-->\n";

    ## Output header
    if ($adding) {
# CPU2006
#	while (<$msginfh>) {
	while (defined($_ = shift(@$msginfh))) {
	    last  if /<!--X-User-Header-End/ || /<!--X-TopPNI--/;
	}
    }
# CPU2006
    #print $msghandle "<!--X-User-Header-->\n";
    push @$msghandle, "<!--X-User-Header-->\n";
    if (!$nocustom) {
	($template = $MSGHEAD) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
	#print $msghandle $template;
	push @$msghandle, $template;
    }
# CPU2006
    #print $msghandle "<!--X-User-Header-End-->\n";
    push @$msghandle, "<!--X-User-Header-End-->\n";

    ## Output Prev/Next/Index links at top
    if ($adding) {
# CPU2006
	#while (<$msginfh>) { last  if /<!--X-TopPNI-End/; }
	while (defined($_ = shift(@$msginfh))) { last  if /<!--X-TopPNI-End/; }
    }
# CPU2006
    #print $msghandle "<!--X-TopPNI-->\n";
    push @$msghandle, "<!--X-TopPNI-->\n";
    if (!$nocustom && !$SINGLE) {
	($template = $TOPLINKS) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
	#print $msghandle $template;
	push @$msghandle, $template;
    }
# CPU2006
    #print $msghandle "\n<!--X-TopPNI-End-->\n";
    push @$msghandle, "\n<!--X-TopPNI-End-->\n";

    ## Output message data
    if ($adding) {
	$tmp2 = "";
# CPU2006
	#while (<$msginfh>) {
	while (defined($_ = shift(@$msginfh))) {
	    # check if subject header delimited
	    if (/<!--X-Subject-Header-Begin/) {
		$tmp2 =~ s/($HAddrExp)/&link_refmsgid($1,1)/geo;
  # CPU2006
		#print $msghandle $tmp2;
		push @$msghandle, $tmp2;
		$tmp2 = "";

# CPU2006
#		while (<$msginfh>) { last  if /<!--X-Subject-Header-End/; }
#		print $msghandle "<!--X-Subject-Header-Begin-->\n";
		while (defined($_ = shift(@$msginfh))) { last  if /<!--X-Subject-Header-End/; }
		push @$msghandle, "<!--X-Subject-Header-Begin-->\n";
		if (!$nocustom) {
		    ($template = $SUBJECTHEADER) =~
			s/$VarExp/&replace_li_var($1,$index)/geo;
      # CPU2006
		    #print $msghandle $template;
		    push @$msghandle, $template;
		}
  # CPU2006
		#print $msghandle "<!--X-Subject-Header-End-->\n";
		push @$msghandle, "<!--X-Subject-Header-End-->\n";
		next;
	    }
	    # check if head/body separator delimited
	    if (/<!--X-Head-Body-Sep-Begin/) {
		$tmp2 =~ s/($HAddrExp)/&link_refmsgid($1,1)/geo;
  # CPU2006
		#print $msghandle $tmp2;
		push @$msghandle, $tmp2;
		$tmp2 = "";

# CPU2006
#		while (<$msginfh>) { last  if /<!--X-Head-Body-Sep-End/; }
#		print $msghandle "<!--X-Head-Body-Sep-Begin-->\n";
		while (defined($_ = shift(@$msginfh))) { last  if /<!--X-Head-Body-Sep-End/; }
		push @$msghandle, "<!--X-Head-Body-Sep-Begin-->\n";
		if (!$nocustom) {
		    ($template = $HEADBODYSEP) =~
			s/$VarExp/&replace_li_var($1,$index)/geo;
      # CPU2006
		    #print $msghandle $template;
		    push @$msghandle, $template;
		}
  # CPU2006
		#print $msghandle "<!--X-Head-Body-Sep-End-->\n";
		push @$msghandle, "<!--X-Head-Body-Sep-End-->\n";
		next;
	    }

	    $tmp2 .= $_;
	    last  if /<!--X-MsgBody-End/;
	}
	$tmp2 =~ s/($HAddrExp)/&link_refmsgid($1,1)/geo;
# CPU2006
	#print $msghandle $tmp2;
	push @$msghandle, $tmp2;

    } else {
# CPU2006
#	print $msghandle "<!--X-MsgBody-->\n";
#	print $msghandle "<!--X-Subject-Header-Begin-->\n";
	push @$msghandle, "<!--X-MsgBody-->\n",
	                  "<!--X-Subject-Header-Begin-->\n";
	($template = $SUBJECTHEADER) =~
	    s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
#	print $msghandle $template;
#	print $msghandle "<!--X-Subject-Header-End-->\n";
	push @$msghandle, $template,
	                 "<!--X-Subject-Header-End-->\n";

	$MsgHead{$index} =~ s/($HAddrExp)/&link_refmsgid($1)/geo;
	$Message{$index} =~ s/($HAddrExp)/&link_refmsgid($1)/geo;

# CPU2006
#	print $msghandle "<!--X-Head-of-Message-->\n";
#	print $msghandle $MsgHead{$index};
#	print $msghandle "<!--X-Head-of-Message-End-->\n";
#	print $msghandle "<!--X-Head-Body-Sep-Begin-->\n";
	push @$msghandle, "<!--X-Head-of-Message-->\n",
	                 $MsgHead{$index},
	                 "<!--X-Head-of-Message-End-->\n",
	                 "<!--X-Head-Body-Sep-Begin-->\n";
	($template = $HEADBODYSEP) =~
	    s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
#	print $msghandle $template;
#	print $msghandle "<!--X-Head-Body-Sep-End-->\n";
#	print $msghandle "<!--X-Body-of-Message-->\n";
#	print $msghandle $Message{$index}, "\n";
#	print $msghandle "<!--X-Body-of-Message-End-->\n";
#	print $msghandle "<!--X-MsgBody-End-->\n";
	push @$msghandle, $template,
	                 "<!--X-Head-Body-Sep-End-->\n",
	                 "<!--X-Body-of-Message-->\n",
	                 $Message{$index}, "\n",
	                 "<!--X-Body-of-Message-End-->\n",
	                 "<!--X-MsgBody-End-->\n";
    }

    ## Output any followup messages
    if ($adding) {
# CPU2006
	#while (<$msginfh>) { last  if /<!--X-Follow-Ups-End/; }
	while (defined($_ = shift(@$msginfh))) { last  if /<!--X-Follow-Ups-End/; }
    }
# CPU2006
    #print $msghandle "<!--X-Follow-Ups-->\n";
    push @$msghandle, "<!--X-Follow-Ups-->\n";
    ($template = $MSGBODYEND) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
    #print $msghandle $template;
    push @$msghandle, $template;
    if (!$nocustom && $DoFolRefs && defined($Follow{$index})) {
	if (scalar(@{$Follow{$index}})) {
	    ($template = $FOLUPBEGIN) =~
		s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
	    #print $msghandle $template;
	    push @$msghandle, $template;
	    foreach (@{$Follow{$index}}) {
		($template = $FOLUPLITXT) =~
		    s/$VarExp/&replace_li_var($1,$_)/geo;
  # CPU2006
		#print $msghandle $template;
		push @$msghandle, $template;
	    }
	    ($template = $FOLUPEND) =~
		s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
	    #print $msghandle $template;
	    push @$msghandle, $template;
	}
    }
# CPU2006
    #print $msghandle "<!--X-Follow-Ups-End-->\n";
    push @$msghandle, "<!--X-Follow-Ups-End-->\n";

    ## Output any references
    if ($adding) {
# CPU2006
	#while (<$msginfh>) { last  if /<!--X-References-End/; }
	while (defined($_ = shift(@$msginfh))) { last  if /<!--X-References-End/; }
    }
# CPU2006
    #print $msghandle "<!--X-References-->\n";
    push @$msghandle, "<!--X-References-->\n";
    if (!$nocustom && $DoFolRefs && defined($Refs{$index})) {
	$tmp2 = 0;	# flag for when first ref printed
	if (scalar(@{$Refs{$index}})) {
	    my($ref_msgid, $ref_index, $ref_num);
	    foreach $ref_msgid (@{$Refs{$index}}) {
		next  unless defined($ref_index = $MsgId{$ref_msgid});
		next  unless defined($ref_num = $IndexNum{$ref_index});
		if (!$tmp2) {
		    ($template = $REFSBEGIN) =~
			s/$VarExp/&replace_li_var($1,$index)/geo;
      # CPU2006
		    #print $msghandle $template;
		    push @$msghandle, $template;
		    $tmp2 = 1;
		}
		($template = $REFSLITXT) =~
		    s/$VarExp/&replace_li_var($1,$ref_index)/geo;
  # CPU2006
		#print $msghandle $template;
		push @$msghandle, $template;
	    }

	    if ($tmp2) {
		($template = $REFSEND) =~
		    s/$VarExp/&replace_li_var($1,$index)/geo;
  # CPU2006
		#print $msghandle $template;
		push @$msghandle, $template;
	    }
	}
    }
# CPU2006
    #print $msghandle "<!--X-References-End-->\n";
    push @$msghandle, "<!--X-References-End-->\n";

    ## Output verbose links to prev/next message in list
    if ($adding) {
# CPU2006
	#while (<$msginfh>) { last  if /<!--X-BotPNI-End/; }
	while (defined($_ = shift(@$msginfh))) { last  if /<!--X-BotPNI-End/; }
    }
# CPU2006
    #print $msghandle "<!--X-BotPNI-->\n";
    push @$msghandle, "<!--X-BotPNI-->\n";
    if (!$nocustom && !$SINGLE) {
	($template = $BOTLINKS) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
	#print $msghandle $template;
	push @$msghandle, $template;
    }
# CPU2006
    #print $msghandle "\n<!--X-BotPNI-End-->\n";
    push @$msghandle, "\n<!--X-BotPNI-End-->\n";

    ## Output footer
    if ($adding) {
# CPU2006
	#while (<$msginfh>) {
	while (defined($_ = shift(@$msginfh))) {
	    last  if /<!--X-User-Footer-End/;
	}
    }
# CPU2006
    #print $msghandle "<!--X-User-Footer-->\n";
    push @$msghandle, "<!--X-User-Footer-->\n";
    if (!$nocustom) {
	($template = $MSGFOOT) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
	#print $msghandle $template;
	push @$msghandle, $template;
    }
# CPU2006
    #print $msghandle "<!--X-User-Footer-End-->\n";
    push @$msghandle, "<!--X-User-Footer-End-->\n";

    if (!$nocustom) {
	($template = $MSGPGEND) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
	#print $msghandle $template;
	push @$msghandle, $template;
    }

# CPU2006
    #close($msghandle)  if (!$SINGLE);
    if ($adding) {
# CPU2006
	#close($msginfh);
	#&file_remove($tmppathname);
    }
    if (!$SINGLE) {
	file_gzip($tmppathname)  if $GzipFiles;
	file_chmod(file_rename($tmppathname, $filepathname));
    }

    ## Create user defined files
    my($drvfh);
    foreach (keys %UDerivedFile) {
	($tmp = $_) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
	($drvfh, $tmppathname) = file_temp('drvXXXXXXXXXX', $OUTDIR);
	($template = $UDerivedFile{$_}) =~
	    s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
	#print $drvfh $template;
	#close($drvfh);
	#file_gzip($tmppathname)  if $GzipFiles;
	#file_chmod(file_rename($tmppathname, join($DIRSEP, $OUTDIR, $tmp)));
	push @$drvfh, $template;

	if (defined($Derived{$index})) {
	    push(@{$Derived{$index}}, $tmp);
	} else {
	    $Derived{$index} = [ $tmp ];
	}
    }
    if (defined($Derived{$index})) {
	$Derived{$index} = [ remove_dups($Derived{$index}) ];
    }

    ## Set modification times -- Use eval incase OS does not support utime.
    if ($MODTIME && !$SINGLE) {
	eval {
	    $tmp = get_time_from_index($index);
	    if (defined($Derived{$index})) {
	      @array2 = @{$Derived{$index}};
	      grep($_ = $OUTDIR . $DIRSEP . $_, @array2);
	    } else {
	      @array2 = ( );
	    }
	    unshift(@array2, $filepathname);
	    file_utime($tmp, $tmp, @array2);
	};
	if ($@) {
	    warn qq/\nWarning: Your platform does not support setting file/,
		   qq/         modification times\n/;
	    $MODTIME = 0;
	}
    }

    ($i_p0, $filename);
}

#############################################################################
## Miscellaneous routines
#############################################################################

##---------------------------------------------------------------------------
##	delmsg delets a message from the archive.
##
sub delmsg {
    my $key = shift;
    my($pathname);

    #&defineIndex2MsgId();
    my $msgnum = $IndexNum{$key};  return 0  if ($msgnum eq '');
    my $filename = join($DIRSEP, $OUTDIR, &msgnum_filename($msgnum));
    delete $ContentType{$key};
    delete $Date{$key};
    delete $From{$key};
    delete $IndexNum{$key};
    delete $Refs{$key};
    delete $Subject{$key};
    delete $MsgId{$Index2MsgId{$key}};
    file_remove($filename)  unless $KeepOnRmm;
    foreach $filename (@{$Derived{$key}}) {
	$pathname = (OSis_absolute_path($filename)) ?
			$filename : join($DIRSEP, $OUTDIR, $filename);
# CPU2006
#	if (-d $pathname) {
#	    dir_remove($pathname)  unless $KeepOnRmm;
#	} else {
	    file_remove($pathname)  unless $KeepOnRmm;
#	}
    }
    delete $Derived{$key};
    $NumOfMsgs--;
    1;
}

##---------------------------------------------------------------------------
##	Routine to convert a msgid to an anchor
##
sub link_refmsgid {
    my $refmsgid = dehtmlize(shift);
    my $onlynew  = shift;

    if (defined($MsgId{$refmsgid}) &&
	    defined($IndexNum{$MsgId{$refmsgid}}) &&
	    (!$onlynew || $NewMsgId{$refmsgid})) {
	my($lreftmpl) = $MSGIDLINK;
	$lreftmpl =~ s/$VarExp/&replace_li_var($1,$MsgId{$refmsgid})/geo;
	return $lreftmpl;
    }
    htmlize($refmsgid);
}

##---------------------------------------------------------------------------
##	Retrieve next available message number.  Should only be used
##	when an archive is locked.
##
sub getNewMsgNum {
    $NumOfMsgs++; $LastMsgNum++;
    $LastMsgNum;
}

##---------------------------------------------------------------------------
##	ign_signals() sets mhonarc to ignore termination signals.  This
##	routine is called right before an archive is written/edited to
##	help prevent archive corruption.
##
sub ign_signals {
# CPU2006 - do not ignore signals
return;
    @SIG{@_term_sigs} = ('IGNORE') x scalar(@_term_sigs);
}

##---------------------------------------------------------------------------
##	set_handler() sets up the signal_catch() routine to be called when
##	termination signals are sent to mhonarc.
##
sub set_handler {
# CPU2006 - do not change signal handlers
return;
    %_sig_org = ( );
    @_sig_org{@_term_sigs} = @SIG{@_term_sigs};
    @SIG{@_term_sigs} = (\&mhonarc::signal_catch) x scalar(@_term_sigs);
}

##---------------------------------------------------------------------------
##	reset_handler() resets the original signal handlers.
##
sub reset_handler {
# CPU2006 - do not change signal handlers
return;
    @SIG{@_term_sigs} = @_sig_org{@_term_sigs};
}

##---------------------------------------------------------------------------
##	signal_catch(): Function for handling signals that would cause
##	termination.
##
sub signal_catch {
# CPU2006 - do not catch signals
return;
    my $signame = shift;
    close_archive(1);
    &{$_sig_org{$signame}}($signame)  if defined(&{$_sig_org{$signame}});
    reset_handler();
    die qq/Processing stopped, signal caught: SIG$signame\n/;
}

##---------------------------------------------------------------------------
##	Create Index2MsgId if not defined
##
sub defineIndex2MsgId {
    if (!defined(%Index2MsgId)) {
	foreach (keys %MsgId) {
	    $Index2MsgId{$MsgId{$_}} = $_;
	}
    }
}

##---------------------------------------------------------------------------
1;
