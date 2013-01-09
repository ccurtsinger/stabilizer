#
# util.pl
#
# Copyright (C) 1999-2000 Standard Performance Evaluation Corporation
#  All Rights Reserved
#
# $Id: util.pl,v 1.4 2002/02/26 22:26:36 cloyce Exp $

use strict;
use IO::Scalar;

my $logged_vars = 0;

sub md5filedigest {
    my ($file) = @_;
    # This hackery will go away after kit 14
    my $md5 = new Digest::MD5;
    my $fh  = new IO::File "<$file";
    if (!defined($fh)) {
	Log(0, "md5filedigest: can't open '$file' for reading.\n  The error message was '$!'\n");
    } else {
	$md5->addfile($fh);
	$fh->close();
    }
    return $md5->hexdigest();
}

sub jp { joinpaths(@_); };
sub joinpaths {	
    my @dirs;
    for my $tmp (@_) {
	# Replace all backslashes with forward slashes (for NT)
	my $a = $tmp;
	$a =~ s|\\|/|go;
	next if $a eq '';
	# If this is the start of an absolute path, nuke what we've already got
	@dirs = () if ($a=~m/^([^:\[]*):?\[(\S*)\]/o || $a =~ m|^/|o || $a =~ m|^[a-zA-Z]:|o);

	if ($a=~m/^([^:\[]*):?\[(\S*)\]/o) { # VMS path - make it a UNIX-alike
	    push (@dirs, $1, split('.', $2));
	} else { # Unix PATH
	    push (@dirs, $a);
	}
    }
    my $result = join('/',@dirs);
    return $result;
}

sub istrue {
    my $val = shift @_;
    return 0 unless defined($val);
    $val = lc($val);
    return ($val eq 'y' || $val eq 'yes' || $val eq 't' || $val eq 'true' || 
           $val eq 'o' || $val eq 'on'  || $val != 0) ? 1 : 0;
}

sub find_biggest_ext {		## find the file with the highest suffix
    my $dir = shift;
    my $ext = shift;
    $ext = '' unless defined($ext);
    my $dh = new IO::Dir $dir;
    my $num = 0;
    if (!defined $dh) {
	Log(0, "find_biggest_num: Can't open directory '$dir': $!\n");
    } else {
	while (defined($_ = $dh->read)) { 
	    $num = $1 if m/\.(\d+)${ext}$/ && $1 > $num;
	}
    }
    return $num;
}

sub choose_string {
    my($string, @choices) = @_;
    my($match);
    for (@choices) {
	return $_ if ($_ eq $string);
	if (m/^$string/) {
	    return undef if defined $match;
	    $match = $_;
	}
    }
    return $match if defined $match;
    undef;
}

sub choose_strings {
    my ($name, $string, @choices) = @_;
    my %seen;
    my @results = ();
    my @temp = split(/\s*[,\s]\s*/, $string);

    for (@temp) {
	my $selection = &choose_string ($_, @choices, "all");
	if (!defined $selection) {
	    Log(0, "$name does not support '$_'\n");
	} elsif ($selection eq "all") {
	    for (@choices) {
		if (!$seen{$_}++) {
		    push (@results, $_);
		}
	    }
	} else {
	    if (!$seen{$_}++) {
		push (@results, $_);
	    }
	}
    }
    @results;
}

# List files in a directory.
# Note that the directory handle is closed upon exit from the subroutine
sub list_files {
    my $dir = new IO::Dir "$_[0]";
    return sort grep { !/^\.\.?$/ && ($_[0] eq '.' || s%^%$_[0]/%) } $dir->read() if (defined $dir);
    return undef;
}

sub build_tree_hash {
    my ($os, @absdirs) = @_;
    my ($files, $dirs) = ({}, {});

    $os = $os->OS if (ref($os) ne '');
    my @work;
    for my $dir (@absdirs) {
	push (@work, [$dir, '', ''])
    }

    while (@work) {
	my ($absdir, $absroot, @paths) = @{shift @work};
	while (@paths) {
	    my $path    = shift(@paths);
	    my $root    = jp($absroot, $path);
	    my $dir     = jp($absdir, $path);
	    my $dh = new IO::Dir $dir;
	    my $file;

	    if (! defined $dh ) {
		Log(0, "Can't open path '$dir: $!\n");
	        exit 1;
	    }
	    while (defined($file = $dh->read)) {
		my $dh = new IO::Dir $dir;
		my $absfile = jp($dir, $file);
		my $relfile = jp($root, $file);
		if (-d $absfile) {
		    if ($file eq '.' || $file eq '..' || $file eq 'CVS') {
		    } elsif ($file =~ m/^OS_(.*)(-|$)/i) {
			if ($1 eq $os) {
			    push (@work, [ $absfile, $root, '' ]);
			}
		    } else {
			$dirs->{$relfile} = '';
			push (@paths, $relfile);
		    }
		} elsif (-f $absfile) {
		    $files->{$relfile} = $absfile;
		} else {
		    Log(0, "build_tree_hash: Can't tell what $absfile is!\n");
		}
	    }
	}
    }
    return ($files, $dirs);
}

# Run a command and log the action
sub log_system {
    log_system_raw(1,@_);
}
sub log_system_noexpand {
    log_system_raw(0,@_);
}
sub log_system_raw {
    my ($expand, $cmd, $outn, @repl) = @_;
    ## $cmd   -- initially, the unexpanded command string; eventually the whole
    ## $outn  -- basename for output and errors files
    ## $ses   -- session data
    ## $repl  -- the array of replacement variables and values

    my $errname = "$outn.err";
    my $outname = "$outn.out";
    my $config  = $main::global_config;
    my $rc;
    my $desc;

    $desc = " $outn" if $outn ne '';

    #$cmd = command_expand($cmd, @repl) if $expand;
    if ($outn ne '') {
	$cmd = redirect_cmd($cmd, $outname, $errname, $config);
	unlink $errname, $outname;
    }

    ## ready -- make a log entry if required
    Log (120, "Issuing$desc command '$cmd'\n");

    ## give user some indication of what is happening if she is
    ## is about to get some tee output
    print $cmd, "\n" if (istrue($config->teeout));

    my %oldENV = %ENV;
    main::munge_environment(@repl) if $config->env_vars;
    ## go -- this is it.. issue the command and grab the result
    my $start = time;
    Log (125, "Start$desc command: ", ctime($start), " ($start)\n");
    $rc = system $cmd;
    my $stop = time;
    my $elapsed = $stop-$start;
    Log (125, "Stop$desc command: ", ctime($stop), " ($stop)\n");
    Log (125, "Elapsed time for$desc command: ", to_hms($elapsed), " ($elapsed)\n");
    %ENV=%oldENV if $config->env_vars;

    ## if an output basename is specified
    if ($outn ne '') {
	if (-s $outname > 0) { ## and if the output file exists
                               ## put the contents into the log file
	    Log(180, "Output from$desc '$cmd':\n", &read_file($outname));
	}
	if (-s $errname > 0) { ## and if the error file already exists
                               ## put the contents into the log file
	    Log(180, "Error from$desc '$cmd':\n", &read_file($errname));

	    ## and if there is a tee involved, display the contents of the
            ## error file
	    print &read_file($errname) if istrue($config->teeout);
	}
    }

    if ($rc) { ## if there is a non-zero result from the $cmd
	if ($rc == $config->sigint && !$config->ignore_sigint) { ## the command was interrupted
	    Log(0, "Exit on SIGINT\n"); 
	    exit 1;
	}

	## $temp holds the path for the error file
	my $temp = cwd() . '/' . $errname;
	Log(0, "Error with$desc '$cmd': check file '$temp'\n");
    }
    return $rc;
}

sub munge_environment {
    no strict 'refs';

    while (@_ && ref($_[0]) ne '') {
	my $ref = shift @_;
	my $reftype = ref($ref);
	if ($reftype->isa('Spec::Config')) {
	    for ($ref->list_keys) {
		$ENV{$1} = $ref->accessor($_) if m/^ENV_(.*)/;
	    }
	} elsif ($reftype eq 'HASH') {
	    for (keys %$ref) {
		$ENV{$1} = $ref->{$_} if m/^ENV_(.*)/;
	    }
	}
    }
    while (@_ > 1) {
	my $name = shift @_;
	my $val = shift @_;
	if ($name =~ m/^ENV_(.*)$/o) {
	    $name = $1;
	    $ENV{$name} = $val;
	}
    }
}

# Munge the command to redirect the output correctly for the OS
# also handle teeout
sub redirect_cmd {
    my ($cmd, $out, $err, $config) = @_;
    if ($config->OS eq 'VMS') {
	# Dunno how to append on VMS... it'll probably never come up, though.
	$cmd = "\@redirect:redirect $out $err $cmd"; 
    } else {
	my @cmds = split(/[\r\n]+/, $cmd);
	# Split the $cmd string on CR or LF because it's important that *all*
	# of the commands have the redirection applied to them.
	if (istrue($config->teeout)) {
	    $cmd = "$cmds[0] 2> $err | tee $out";
	    if (@cmds+0 > 1) {
		$cmd .= '; '.join(" 2>> $err | tee -a $out; ", @cmds[1..$#cmds]).
		    " 2>> $err | tee -a $out";
	    }
	} else {
	    $cmd = "$cmds[0] > $out 2> $err";
	    if (@cmds+0 > 1) {
		$cmd .= '; '.join(" >> $out 2>> $err; ", @cmds[1..$#cmds]).
		    " >> $out 2>> $err";
	    }
	}
    }
    return $cmd;
}

## ############
## SUB                   FROM_HMS
## ############

## takes strings of hh:mm:ss (or mm:ss) and returns number of seconds

sub from_hms {
    my ($time) = @_;
    my (@vals) = split (":", $time);
    $time = 0;
    for (@vals) {
        $time *= 60;
        $time += $_;
    }
    $time;
}

## ############
## SUB                   TO_HMS
## ############

## takes seconds and returns a string of hh:mm:ss
## optionally can take a second argument of decimal seconds

sub to_hms {
    my ($t, $t2) = @_;
    my ($h,$m,$s);
    $s = $t % 60;
    $t = int($t/60);
    $m = $t % 60;
    $h = int($t/60);
    if ($t2) {
	sprintf ("%02d:%02d:%02d.%06d", $h, $m, $s, $t2);
    } else {
	sprintf ("%02d:%02d:%02d", $h, $m, $s);
    }
}

## ############
## SUB                   READ_FILE
## ############
# IO::File will close the file when $fh goes out of scope

sub read_file {
    my($name) = @_;
    my (@temp);
    my $fh = undef;
    if (ref($::sd_files{$name}) eq 'SCALAR') {
      $fh = new IO::Scalar $::sd_files{$name};
    } else {
      $fh = new IO::Scalar \$::sd_files{$name};
    }

    return undef if !defined $fh;
    return $fh->getlines;
}

## ############
## SUB                   MIN
## ############

## takes a list of values and returns the least of them (numeric only)
sub min {
    my ($val) = @_;
    for (@_) {
        $val = $_ if $_ < $val;
    }
    return $val;
}

## ############
## SUB                   MAX
## ############

## takes a list of values and returns the greatest of them
sub max {
    my ($val) = @_;
    for (@_) {
        $val = $_ if $_ > $val;
    }
    return $val;
}

## ############
## SUB                   EXPAND_RANGES
## ############

sub expand_ranges {
    my (@data) = @_;
    my (@rc, $start, $stop, $step, $i);

    for (@data) {
	if (($start, $stop, $step) = m/^(\d+)-(\d+)(?:x(\d+))?$/) {
	    $step = 1 if $step eq '';
	    if ($start < $stop) {
		for ($i = $start; $i <= $stop; $i += $step) {
		    push (@rc, $i);
		}
	    } else {
		for ($i = $start; $i >= $stop; $i -= $step) {
		    push (@rc, $i);
		}
	    }
	} else {
	    push (@rc, $_);
	}
    }
    @rc;
}

sub center {
    my ($text, $width) = @_;
    my $len = length $text;
    $width = 78 if !defined $width;
    $width = $len if $width < $len;
    ' ' x int(($width - length $text) / 2) . $text;
}

sub bytrailingnum {
    my ($aname, $anum) = $a =~ m/^(\S+?)([\d.]*)$/;
    my ($bname, $bnum) = $b =~ m/^(\S+?)([\d.]*)$/;
    my $rc = $aname cmp $bname;
    $rc = $anum  <=> $bnum if !$rc;
    return $rc;
}

sub pdf_exclude {
    # Here's where we decide if it's okay to try to load the PDF module or
    # not.

    # It's not... PDFlib 2.0 doesn't like new Perl and doesn't work on Windows
    # Upgrade to PDFlib 4.0.x is big $$$$, so no PDF until we decide if we're
    # going to pony up.
    return 0;

    return 1 if $ENV{'SPEC_TRY_PDF'};
    return 0 if $ENV{'SPEC_NEVER_TRY_PDF'};
}

1;
