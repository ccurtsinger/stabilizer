##---------------------------------------------------------------------------##
##  File:
##	$Id: mhdysub.pl,v 2.10 2003/01/10 03:35:40 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      Definition of create_routines() that creates routines are
##	runtime.
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1996-2001	Earl Hood, mhonarc@mhonarc.org
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
##    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
##---------------------------------------------------------------------------##

package mhonarc;

my $_sub_eval_cnt = 0;

##---------------------------------------------------------------------------
##	create_routines is used to dynamically create routines that
##	would benefit from being create at run-time.  Routines
##	that have to check against several regular expressions
##	are candidates.
##
##	NOTE: Subroutine references would be cleaner, but code
##	      pre-dates Perl 5 where references were not supported.
##
sub create_routines {
    my($sub) = '';

    ##-----------------------------------------------------------------------
    ## exclude_field: Used to determine if field should be excluded from
    ## message header
    ##
    $sub  =<<'EndOfRoutine';
    sub exclude_field {
	my($f) = shift;
	my $ret = 0;
	EXC_FIELD_SW: {
EndOfRoutine

    # Create switch block for checking field against regular
    # expressions (a large || statement could also work).
    my $pat;
    foreach $pat (keys %HFieldsExc) {
	$sub .= join('',
		     'if ($f =~ /^',
		     $pat,
		     '/i) { $ret = 1;  last EXC_FIELD_SW; }',
		     "\n");
    }

    $sub .=<<'EndOfRoutine';
	};
	$ret;
    }
EndOfRoutine

    $sub .= "# $_sub_eval_cnt\n";  ++$_sub_eval_cnt;
    eval $sub;
    die("ERROR: Unable to create exclude_field routine:\n$@\n") if $@;

    ##-----------------------------------------------------------------------
    ## subject_strip: Used to apply user-defined s/// operations on
    ## message subjects as they are read;
    ##
    $sub  =<<EndOfRoutine;
    sub subject_strip {
	local(\$_) = shift;
	$SubStripCode;
	\$_;
    }
EndOfRoutine

    $sub .= "# $_sub_eval_cnt\n";  ++$_sub_eval_cnt;
    eval $sub;
    die("ERROR: Unable to create subject_strip routine:\n$@\n") if $@;

    ##-----------------------------------------------------------------------
    ##	Routine to determine last message number in use.
    ##
    $sub =<<'EndOfRoutine';
    sub get_last_msg_num {
# CPU2006
	#opendir(DIR, $OUTDIR) || die("ERROR: Unable to open $OUTDIR\n");
	my($max) = -1;
	my $msgrex = '^'.
		     "\Q$MsgPrefix".
		     '(\d+)\.'.
		     "\Q$HtmlExt".
		     '$'; # '
	chop $msgrex  if ($HtmlExt =~ /html$/i);

# CPU2006
	#foreach (readdir(DIR)) {
	foreach (keys %mhonarc_files) {
	    if (/$msgrex/io) { $max = int($1)  if $1 > $max; }
	}
# CPU2006
	#close(DIR);
	$max;
    }
EndOfRoutine

    $sub .= "# $_sub_eval_cnt\n";  ++$_sub_eval_cnt;
    eval $sub;
    die("ERROR: Unable to create get_last_msg_num routine:\n$@\n") if $@;

    ##-----------------------------------------------------------------------
    ##	Routine to get base subject text from index
    ##
    $sub =<<'EndOfRoutine';
    sub get_base_subject {
	my($ret) = ($Subject{$_[0]});
	1 while $ret =~ s/$SubReplyRxp//io;
	if ($ret eq "") {
	    return $NoSubjectTxt;
	}
	$ret;
    }
EndOfRoutine

    $sub .= "# $_sub_eval_cnt\n";  ++$_sub_eval_cnt;
    eval $sub;
    die("ERROR: Unable to create get_base_subject routine:\n$@\n") if $@;

    ##-----------------------------------------------------------------------
    ##	Routine to rewrite mail addresses in message header
    ##
    $sub =<<EndOfRoutine;
    sub rewrite_address {
	package mhonarc::Pkg_rewrite_address;
	local \$_ = mhonarc::dehtmlize(shift);
	$AddressModify;
	\$_;
    }
EndOfRoutine

    $sub .= "# $_sub_eval_cnt\n";  ++$_sub_eval_cnt;
    eval $sub;
    die("ERROR: Unable to create rewrite_address routine:\n$@\n") if $@;

    ##-----------------------------------------------------------------------
    ##	Routine to rewrite raw mail addresses
    ##
    $sub =<<EndOfRoutine;
sub rewrite_raw_address {
    package mhonarc::Pkg_rewrite_raw_address;
    local \$_ = shift;
    $AddressModify;
    \$_;
}
EndOfRoutine
    $sub .= "# $_sub_eval_cnt\n";  ++$_sub_eval_cnt;
    eval $sub;
    die("ERROR: Unable to create rewrite_raw_address routine:\n$@\n")
	if $@;

    ##-----------------------------------------------------------------------
    ## message_exclude: User-defined code to check if a message should
    ## be added or not.
    ##
    $sub  =<<EndOfRoutine;
    sub message_exclude {
	package mhonarc::Pkg_message_exclude;
	local(\$_) = shift;
	$MsgExcFilter;
    }
EndOfRoutine

    $sub .= "# $_sub_eval_cnt\n";  ++$_sub_eval_cnt;
    eval $sub;
    die("ERROR: Unable to create subject_strip routine:\n$@\n") if $@;

}

##---------------------------------------------------------------------------##
1;
