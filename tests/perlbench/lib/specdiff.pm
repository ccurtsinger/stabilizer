#!/spec/cpu2006/bin/specperl
#!/spec/cpu2006/bin/specperl -d
#!/usr/bin/perl
#
#  specdiff - compares files to see if results match
#  Copyright (C) 1995-2001 Standard Performance Evaluation Corporation
#   All Rights Reserved
#
#  Author:  Christopher Chan-Nui
#
# $Id: specdiff,v 1.6 2002/02/01 16:24:48 cloyce Exp $

##############################################################################
# Find top of directory tree
##############################################################################

# Commented out for 400.perlbench
#BEGIN { 
#    if ($ENV{'SPEC'} ne '') {
#	unshift (@INC, "$ENV{'SPEC'}/bin", "$ENV{'SPEC'}/bin/lib", 
#	               "$ENV{'SPEC'}/bin/lib/site");
#    }
#}

package SPECdiff;

use strict;
use Cwd;
use File::Basename;

sub fileparam_val {
    my ($val, $file) = @_;
    if (ref($val) eq 'HASH') {
	if (exists $val->{$file}) {
	    $val = $val->{$file};
	} else {
	    $val = $val->{'default'};
	}
    }
    return $val;
}
sub fileparam {
    my $val = fileparam_val(@_);
    return istrue($val)?1:undef;
}

sub specdiff_main {
  @ARGV = @_;
##############################################################################
# Do real program
##############################################################################

require "compare.pm";
require "util.pm";
use Getopt::Long;

use vars qw($global_config);
use vars qw($obiwan $reltol $abstol $compress_whitespace $skiptol $skipabstol
	    $skipreltol $skipobiwan $opts);
$global_config;

shift @ARGV if ($ARGV[0] eq '--');

#unshift(@ARGV, split(' ',$ENV{'SPEC_SPECDIFF'})) 
#    if defined $ENV{'SPEC_SPECDIFF'};

my $cl_opts={ 'lines' => 10, 'verbose' => 1 };
Getopt::Long::config("no_ignore_case", "bundling");
my $rc = GetOptions ($cl_opts, qw(
		    binary|b
		    abstol|a=f
		    reltol|r=f
		    calctol|t
		    skiptol|s=i
		    skipabstol|s=i
		    skipreltol|s=i
		    skipobiwan|s=i
		    mis|m
		    cw|c
		    CW|C
		    obiwan|o
		    OBIWAN|O
		    os=s
		    datadir|d
		    lines|l=i
		    quiet
		    verbose|v=i
		    help|h
                    floating|floatcompare|f
		    ));

my $verbose;
$verbose = $cl_opts->{'verbose'};
$verbose = 0 if $cl_opts->{'quiet'};
my $os = $cl_opts->{'os'};
$cl_opts->{'cw'} = 0 if $cl_opts->{'CW'};
$cl_opts->{'obiwan'} = 0 if $cl_opts->{'OBIWAN'};

&usage if $cl_opts->{'help'};

if ($cl_opts->{'datadir'}) {

    print STDERR "Bad monkey!  Mustn't use the datadir option in the benchmark!\n";
    exit 1;

    my $pwd = cwd();
    my ($benchdir, $rundir, $subdir) = $pwd =~ m#(.*/\d+\.\S+)[/\\]run[/\\]([^/\\]+)(.*)#;
    my %vars;
    $subdir =~ s#^\\#/#g;
    $subdir =~ s#^/##;
    open(FILE, "<$benchdir/run/list") || die "Can't open '$benchdir/run/list': $!\n";
    while (<FILE>) {
	if (m/^$rundir\s+/) {
	    my @vars = split;
	    for my $pair (@vars) {
		my ($name, $val) = $pair =~ m/([^=]+)=(.*)/;
		$vars{$name} = $val;
	    }
	}
	last if m/^__END__/;
    }
    close(FILE);

    my $size = $vars{'size'};
    require "$benchdir/Spec/object.pm";
    my ($files, $dirs) = build_tree_hash($os, "$benchdir/data/$size/output");
    if (!@ARGV) {
	push (@ARGV, keys %$files);
    }
    print join(',', @ARGV), "\n" if $verbose >= 3;
    for my $filename (@ARGV) {
	my $subfilename = $filename;
	$subfilename = "$subdir/$filename" if $subdir ne '';
	if (! exists $files->{$subfilename}) {
	    print "'$subfilename' does not exist in '$size' output directory\n";
	    next;
	}

	my $opts = { cw         => fileparam($compress_whitespace, $subfilename),
		     obiwan     => fileparam($obiwan, $subfilename),
		     reltol     => fileparam_val($reltol, $subfilename),
		     abstol     => fileparam_val($abstol, $subfilename),
		     skiptol    => fileparam_val($skiptol, $subfilename),
		     skipabstol => fileparam_val($skipabstol, $subfilename),
		     skipreltol => fileparam_val($skipreltol, $subfilename),
		     skipobiwan => fileparam_val($skipobiwan, $subfilename),
		     calctol    => 0,
		     binary     => 0,
		     lines      => $cl_opts->{'lines'}
		 };
	$opts->{'floating'}= $cl_opts->{'floating'} if ($cl_opts->{'cw'});
	$opts->{'cw'}      = $cl_opts->{'cw'}       if ($cl_opts->{'cw'});
	$opts->{'abstol'}  = $cl_opts->{'abstol'}   if ($cl_opts->{'abstol'});
	$opts->{'reltol'}  = $cl_opts->{'reltol'}   if ($cl_opts->{'reltol'});
	$opts->{'obiwan'}  = $cl_opts->{'obiwan'}   if ($cl_opts->{'obiwan'});
	$opts->{'calctol'} = $cl_opts->{'calctol'}  if ($cl_opts->{'calctol'});
	$opts->{'skiptol'} = $cl_opts->{'skiptol'}  if ($cl_opts->{'skiptol'});
	$opts->{'skipabstol'} = $cl_opts->{'skipabstol'} if ($cl_opts->{'skipabstol'});
	$opts->{'skipreltol'} = $cl_opts->{'skipreltol'} if ($cl_opts->{'skipreltol'});
	$opts->{'skipobiwan'} = $cl_opts->{'skipobiwan'} if ($cl_opts->{'skipobiwan'});
	$opts->{'binary'}  = $cl_opts->{'binary'}  if ($cl_opts->{'binary'});
	my @rc = spec_diff($files->{$subfilename}, $filename, $opts);

	if (@rc) {
	    print "***$filename***\n";
	    print @rc;
	    exit 1 
	} elsif ($verbose >= 1) {
	    print "***$filename***\n";
	    print join(', ', map { "$_=$opts->{$_}" } sort keys %$opts),"\n" if ($verbose >= 2);
	    print @rc;
	}
    }
    exit (0);
}

usage() if (@ARGV+0 <= 0);
my $file1 = shift(@ARGV);
my $file2 = (@ARGV)?shift(@ARGV):"-";

#$file2 = "$file2/".basename($file1) if -d $file2;

my @rc = &spec_diff ($file1, $file2, $cl_opts);

#print STDERR "rc = ".join("\n", @rc),"\n";
if (@rc && $cl_opts->{'mis'}) {
  $::sd_files{"${file2}.mis"} = join("\n", @rc);
#    open (MIS, ">$file2.mis") || die "Can't open output '$file2.mis': $!\n";
#    print MIS @rc;
#    close(MIS);
}

print join(', ', map { "$_=$opts->{$_}" } sort keys %$opts),"\n" if ($verbose >= 2);
print @rc if $verbose;

return 1 if @rc;

}

sub usage {
    print <<EOT;
Usage: $0 [-l #] [-q] file1 [file2]
       -l     # of lines of differences to print (-1 for all)
       -q     don't print lines just set return code
       -a     absolute tolerance (for floating point compares)
       -r     relative tolerance (for floating point compares)
       -t     calculate required tolerances
       -s     set skiptol
       -o     allow off-by-one errors
       -O     *don't* allow off-by-one errors
       -m     write file2.mis with miscompares
       -c     collapse whitespace (doesn't do what you think it does)
       -C     *don't* collapse whitespace
       -d     Compare against file(s) in data directory
      --os    Set the operating system type (you don't need to do this)
       -v     Set the level of noisiness for the output
       -h     Print this message
EOT
    exit 1;
}

1;

__END__
