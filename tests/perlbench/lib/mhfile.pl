##---------------------------------------------------------------------------##
##  File:
##	$Id: mhfile.pl,v 2.10 2003/02/22 04:40:11 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      File routines for MHonArc
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1997-1999	Earl Hood, mhonarc@mhonarc.org
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

use Symbol;
use Fcntl;
use File::Basename;

my $_have_File_Temp;
BEGIN {
    # If File::Temp is installed, we will use it for temporary file
    # generation.
    eval { require File::Temp; };
    $_have_File_Temp = scalar($@) ? 0 : 1;

    # Increase File::Temp safety level if setuid
    if ($_have_File_Temp && $UNIX && $TaintMode) {
	File::Temp->safe_level(File::Temp::MEDIUM);
    }

    # Perl <5.004 did not auto-call srand().
    eval { require 5.004; };
    srand(time ^ ($$ + ($$ << 15)))  if scalar($@);
}

# Characters to use for home-grown temporay file generation.  We stick to
# basic alphanumerics to avoid OS-specific filename limitations.
my @TEMP_CHARS = qw(
    A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
    a b c d e f g h i j k l m n o p q r s t u v w x y z
    0 1 2 3 4 5 6 7 8 9 _
);

# Maximum tries to create a temporary file in home-grown implementation
sub TEMP_MAX_TRIES() { 10; }

##---------------------------------------------------------------------------##

sub file_open {
    my($file) = shift;
    my($handle) = gensym;
    my($gz) = $file =~ /\.gz$/i;

# CPU2006
    #if ($gz) {
    if (0 && $gz) {
	cmd_pipe_open($handle, $GzipExe, '-cd', $file);
	return $handle;
    }
# CPU2006
#    return $handle  if open($handle, $file);
#    if (-e "$file.gz") {
#	cmd_pipe_open($handle, $GzipExe, '-cd', "$file.gz");
#	return $handle;
#    }
#    die qq/ERROR: Failed to open "$file": $!\n/;
    if (exists $mhonarc_files{$file}) {
        $handle = $mhonarc_files{$file};
	return $handle;
    }
    return 0;
}

sub cmd_pipe_open {
    my $handle	= shift;
    my @cmd	= @_;

    if (!$UNIX) {
	return $handle  if open($handle, join(' ', @cmd, '|'));
	die qq/ERROR: Failed to exec @cmd: $!\n/;
    }
    my $child_pid = open($handle, '-|');
    if ($child_pid) {   # parent
	return $handle;
    } else {		# child
      #open(STDERR, '>&STDOUT');
      exec(@cmd) || die qq/ERROR: Cannot exec "@cmd": $!\n/;
    }
}

sub file_gzip {
    my $file = shift;

# CPU2006
return;

    return  if ($file =~ /\.gz$/i);
    if (system($GzipExe, $file) != 0) {
	die qq/ERROR: Failed to exec "$GzipExe $file": $! $?\n/;
    }
}

## This function is currently not used anymore
# Except for in CPU2006, that is
sub file_create {
    my($file) = shift;
    my($gz) = shift;
    my($handle) = gensym;

# CPU2006
    #if ($gz) {
    if (0 && $gz) {
	$file .= ".gz"  unless $file =~ /\.gz$/;
	return $handle  if open($handle, "| $GzipExe > $file");
	die qq{ERROR: Failed to exec "| $GzipExe > $file": $!\n};
    }
# CPU2006
#    return $handle  if open($handle, "> $file");
#    die qq{ERROR: Failed to create "$file": $!\n};
    $mhonarc_files{$file} = [];
    $handle = $mhonarc_files{$file};
    return $handle;
}

sub file_exists {
# CPU2006
    #(-e $_[0]) || (-e "$_[0].gz");
    (exists $mhonarc_files{$_[0]});
}

sub file_copy {
    my($src, $dst) = ($_[0], $_[1]);
    my($gz) = $src =~ /\.gz$/i;

# CPU2006
#    if ($gz || (-e "$src.gz")) {
#	$src .= ".gz"  unless $gz;
#	$dst .= ".gz"  unless $dst =~ /\.gz$/i;
#    }
#    &cp($src, $dst);
    # An error will occur if $mhonarc_files{$src} doesn't exist
    @{$mhonarc_files{$dst}} = @{$mhonarc_files{$src}};
}

sub file_rename {
    my($src, $dst) = ($_[0], $_[1]);
    my($gz) = $src =~ /\.gz$/i;

# CPU2006
#    if ($gz || (-e "$src.gz")) {
#	$src .= ".gz"  unless $gz;
#	$dst .= ".gz"  unless $dst =~ /\.gz$/i;
#    }
#    if (!rename($src, $dst)) {
#	die qq/ERROR: Unable to rename "$src" to "$dst": $!\n/;
#    }
    @{$mhonarc_files{$dst}} = @{$mhonarc_files{$src}};
    delete $mhonarc_files{$src};
    $dst;
}

sub file_remove {
    my($file) = shift;

# CPU2006
#    unlink($file);
#    unlink("$file.gz");
    delete $mhonarc_files{$file};
}

sub file_utime {
    my($atime) = shift;
    my($mtime) = shift;

# CPU2006
return;

    foreach (@_) {
	utime($atime, $mtime, $_, "$_.gz");
    }
}

sub file_temp {
    my $template = shift;
    my $dir	 = shift || $CURDIR;
    my($handle, $tmpfile);

    MKTEMP: {
# CPU2006
	#if ($FastTempFiles) {
	if (0 && $FastTempFiles) {
	    $handle = gensym;
	    $tmpfile = join($DIRSEP, $dir, $template.$$);
	    if (!sysopen($handle, $tmpfile,
			 (O_WRONLY|O_EXCL|O_CREAT), 0600)) {
		die qq/ERROR: Unable to create temp file "$tmpfile": $!\n/;
	    }
	    last MKTEMP;
	}
# CPU2006
	#if ($_have_File_Temp) {
	if (0 && $_have_File_Temp) {
	    ($handle, $tmpfile) =
		File::Temp::tempfile($template, 'DIR' => $dir, 'UNLINK' => 0);
	    last MKTEMP;
	}

	$handle = gensym;
	my($i);
	for ($i=0; $i < TEMP_MAX_TRIES; ++$i) {
	    ($tmpfile = $template) =~
		s/X/$TEMP_CHARS[int(rand($#TEMP_CHARS))]/ge;
	    $tmpfile = join($DIRSEP, $dir, 'TEMPFILE'.$tmpfile);
# CPU2006
#	    last  if sysopen($handle, $tmpfile,
#			     (O_WRONLY|O_EXCL|O_CREAT), 0600);
            $handle = file_create($tmpfile);
            last if defined($handle);
	}
	if ($i >= TEMP_MAX_TRIES) {
	    die qq/ERROR: Unable to create temp file "$tmpfile": $!\n/;
	}
    }
    ($handle, $tmpfile);
}

sub file_chmod {
    my $file  = shift;
    my $perm  = shift || $FilePermsOct;

# CPU2006
return;

    ## Capture any die's in case chmod not supported.
    eval {
	if (chmod(($perm &~ umask), $file) < 1) {
	    warn qq/Warning: Unable to change "$file" permissions to "/,
		 sprintf('%o'. $perm),
		 qq/": $!\n/;
	}
    };
}

##---------------------------------------------------------------------------##

sub dir_create {
    my $path  = shift;
    my $perms = shift || 0777;

# CPU2006
return;

    if (!$UNIX) {
	## Non-Unix OS's do not have symlinks
	return  if (-e $path);
	if (!mkdir($path, $perms)) {
	    die qq/ERROR: Unable to create "$path": $!\n/;
	}
	return;
    }

    ## Check if $path is a symlink
    if (-l $path) {
	# symlink, try to delete
	warn qq/Warning: "$path" is a symlink, will try to replace...\n/;
	if (!unlink($path)) {
	    die qq/ERROR: "$path" is a symlink, unable to remove: $!\n/;
	}
    } elsif (-e $path) {
	die qq/ERROR: "$path" is not a directory: $!\n/  if !(-d _);
	# already exists, nothing to do
	return;
    }

    my $dirname = dirname($path);
    my @info = stat($dirname);
    if ($info[2] & Fcntl::S_IWGRP || $info[2] & Fcntl::S_IWOTH) {
	my($i, $errstr, $tmpdir);
	for ($i=0; $i < TEMP_MAX_TRIES; ++$i) {
	    $tmpdir = dir_temp('dirXXXXXXXXXX', $dirname);
	    if (!rename($tmpdir, $path)) {
		$errstr = "$!";
		rmdir($tmpdir);
		if (-l $path) {
		    # hmmmm, somone trying to so something malicious?
		    warn qq/Warning: Possible symlink attack attempted with /,
			 qq/"$path"\n/;
		    die qq/ERROR: "$path" is a symlink, unable to remove: $!\n/
			unless unlink $path;
		} elsif (-d $path) {
		    # somebody snuck in and created it
		    return;
		} elsif (-e _) {
		    die qq/ERROR: "$path" exists, but it did not before, /,
			qq/and it is not a directory!\n/;
		}
	    }
	}
	if ($i >= TEMP_MAX_TRIES) {
	    die qq/ERROR: Unable to rename "$tmpdir" to "$path": $errstr\n/;
	}

    } else {
	if (!mkdir($path, $perms)) {
	    die qq/ERROR: Unable to create "$path": $!\n/;
	}
	return;
    }
    chmod(($perms &~ umask), $path);
}

sub dir_temp {
    my $template = shift;
    my $dir	 = shift || $CURDIR;
    my($tmpdir);

# CPU2006
return '.';

    MKTEMP: {
	if ($_have_File_Temp) {
	    $tmpdir =
		File::Temp::tempdir($template, 'DIR' => $dir, 'CLEANUP' => 0);
	    last MKTEMP;
	}

	my($i);
	for ($i=0; $i < TEMP_MAX_TRIES; ++$i) {
	    ($tmpdir = $template) =~
		s/X/$TEMP_CHARS[int(rand($#TEMP_CHARS))]/ge;
	    $tmpdir = join($DIRSEP, $dir, $tmpdir);
	    last  if mkdir $tmpdir, 0700;
	}
	if ($i >= TEMP_MAX_TRIES) {
	    die qq/ERROR: Unable to create temp dir "$tmpdir": $!\n/;
	}
    }
    $tmpdir;
}

sub dir_remove {
    my($file) = shift;

# CPU2006
return 1;

    if (-d $file) {
	local(*DIR);
	local($_);
	if (!opendir(DIR, $file)) {
	    warn qq{Warning: Unable to open "$file"\n};
	    return 0;
	}
	my @files = grep(!/^(\.|\..)$/i, readdir(DIR));
	closedir(DIR);
	foreach (@files) {
	    &dir_remove($file . $mhonarc::DIRSEP . $_);
	}
	if (!rmdir($file)) {
	    warn qq{Warning: Unable to remove "$file": $!\n};
	    return 0;
	}

    } else {
	if (!unlink($file)) {
	    warn qq{Warning: Unable to delete "$file": $!\n};
	    return 0;
	}
    }
    1;
}

##---------------------------------------------------------------------------##

sub rand_string {
    my $template = shift;
    $template =~ s/X/$TEMP_CHARS[int(rand($#TEMP_CHARS))]/ge;
    $template;
}

##---------------------------------------------------------------------------##
1;
