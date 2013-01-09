##---------------------------------------------------------------------------##
##  File:
##      $Id: mhthread.pl,v 2.11 2002/11/20 23:53:12 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      Thread routines for MHonArc
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1995-2001	Earl Hood, mhonarc@mhonarc.org
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

##---------------------------------------------------------------------------
##	write_thread_index outputs the thread index
##
sub write_thread_index {
    local($onlypg) = shift;
    local($tmpl, $handle);
    local($index) = ("");
    local(*a);
    local($PageNum, $PageSize, $totalpgs, %Printed);
    local($lastlevel, $tlevel, $iscont, $i, $offstart, $offend);
    my($tmpfile);

    local($level) = 0;  	## !!!Used in print_thread!!!
    local($last0index) = '';

    ## Make sure list orders are set
    if (!scalar(@TListOrder)) {
	&compute_threads();
    }
    if (!scalar(@MListOrder)) {	# need for resource variable expansions
	@MListOrder = &sort_messages();
	%Index2MLoc = ();
	@Index2MLoc{@MListOrder} = (0 .. $#MListOrder);
    }

    &compute_page_total();
    @ThreadList = @TListOrder;
    $PageNum  = $onlypg || 1;
    $totalpgs = $onlypg || $NumOfPages;
 
    for ( ; $PageNum <= $totalpgs; ++$PageNum) {
	next  if $PageNum < $TIdxMinPg;

	if ($MULTIIDX) {
	    $offstart = ($PageNum-1) * $IDXSIZE;
	    $offend   = $offstart + $IDXSIZE-1;
	    $offend   = $#TListOrder  if $#TListOrder < $offend;
	    @a        = @TListOrder[$offstart..$offend];

	    if ($PageNum > 1) {
		$TIDXPATHNAME = join("", $OUTDIR, $DIRSEP,
				     $TIDXPREFIX, $PageNum, ".", $HtmlExt);
	    } else {
		$TIDXPATHNAME = join($DIRSEP, $OUTDIR, $TIDXNAME);
	    }

	} else {
	    $TIDXPATHNAME = join($DIRSEP, $OUTDIR, $TIDXNAME);
	    if ($IDXSIZE && (($i = ($#ThreadList+1) - $IDXSIZE) > 0)) {
		if ($TREVERSE) {
		    @NotIdxThreadList = splice(@ThreadList, $IDXSIZE);
		} else {
		    @NotIdxThreadList = splice(@ThreadList, 0, $i);
		}
	    }
	    *a = *ThreadList;
	}
	$PageSize = scalar(@a);

	if ($IDXONLY) {
	    $handle = \*STDOUT;
	} else {
	    ($handle, $tmpfile) = file_temp('tidxXXXXXXXXXX', $OUTDIR);
	}
	print STDOUT "Writing $TIDXPATHNAME ...\n"  unless $QUIET;

	$tmpl = ($TIDXPGSSMARKUP ne '') ? $TIDXPGSSMARKUP : $SSMARKUP;
	if ($tmpl ne '') {
	    $tmpl =~ s/$VarExp/&replace_li_var($1,'')/geo;
    # CPU2006
	    #print $handle $tmpl;
	    push @$handle, $tmpl;
	}

# CPU2006
	#print $handle "<!-- ", &commentize("MHonArc v$VERSION"), " -->\n";
	push @$handle, "<!-- ". &commentize("MHonArc v$VERSION"). " -->\n";

	($tmpl = $TIDXPGBEG) =~ s/$VarExp/&replace_li_var($1,'')/geo;
# CPU2006
	#print $handle $tmpl;
	push @$handle, $tmpl;

	($tmpl = $THEAD) =~ s/$VarExp/&replace_li_var($1,'')/geo;
# CPU2006
	#print $handle $tmpl;
	push @$handle, $tmpl;

	## Flag visible messages for use in printing thread index page
	foreach $index (@a) { $TVisible{$index} = 1; }

	## Print index.  Print unless message has been printed, or
	## unless it has reference that is visible.
	$level = 0;		# !!!Used in print_thread!!!
	$lastlevel = $ThreadLevel{$a[0]};

	# check if continuing a thread
	if ($lastlevel > 0) {
	    ($tmpl = $TCONTBEG) =~ s/$VarExp/&replace_li_var($1,$a[0])/geo;
    # CPU2006
	    #print $handle $tmpl;
	    push @$handle, $tmpl;
	}
	# perform any indenting
	for ($i=0; $i < $lastlevel; ++$i) {
	    ++$level;
	    if ($level <= $TLEVELS) {
		($tmpl = $TINDENTBEG) =~ s/$VarExp/&replace_li_var($1,'')/geo;
		push @$handle, $tmpl;
	    }
	}
	# print index listing
	foreach $index (@a) {
	    $tlevel = $ThreadLevel{$index};
	    if (($lastlevel > 0) && ($tlevel < $lastlevel)) {
		for ($i=$tlevel; $i < $lastlevel; ++$i) {
		    if ($level <= $TLEVELS) {
			($tmpl = $TINDENTEND) =~
			    s/$VarExp/&replace_li_var($1,'')/geo;
                # CPU2006
			#print $handle $tmpl;
			push @$handle, $tmpl;
		    }
		    --$level;
		}
		$lastlevel = $tlevel;
		if ($lastlevel < 1) {	# Check if continuation done
		    ($tmpl = $TCONTEND) =~
			s/$VarExp/&replace_li_var($1,'')/geo;
            # CPU2006
		    #print $handle $tmpl;
		    push @$handle, $tmpl;
		}
	    }
	    unless ($Printed{$index} ||
		    ($HasRef{$index} && $TVisible{$HasRef{$index}})) {
		&print_thread($handle, $index,
			      ($lastlevel > 0) ? 0 : 1);
	    }
	}
	# unindent if required
	for ($i=0; $i < $lastlevel; ++$i) {
	    if ($level <= $TLEVELS) {
		($tmpl = $TINDENTEND) =~ s/$VarExp/&replace_li_var($1,'')/geo;
        # CPU2006
		#print $handle $tmpl;
		push @$handle, $tmpl;
	    }
	    --$level;
	}
	# close continuation if required
	if ($lastlevel > 0) {
	    ($tmpl = $TCONTEND) =~ s/$VarExp/&replace_li_var($1,'')/geo;
    # CPU2006
	    #print $handle $tmpl;
	    push @$handle, $tmpl;
	}

	## Reset visibility flags
	foreach $index (@a) { $TVisible{$index} = 0; }

	($tmpl = $TFOOT) =~ s/$VarExp/&replace_li_var($1,'')/geo;
# CPU2006
	#print $handle $tmpl;
	push @$handle, $tmpl;

	&output_doclink($handle);

	($tmpl = $TIDXPGEND) =~ s/$VarExp/&replace_li_var($1,'')/geo;
# CPU2006
	#print $handle $tmpl;
	push @$handle, $tmpl;

# CPU2006
	#print $handle "<!-- ", &commentize("MHonArc v$VERSION"), " -->\n";
	push @$handle, "<!-- ". &commentize("MHonArc v$VERSION"). " -->\n";

# CPU2006
	#if (!$IDXONLY) {
	if (0 && !$IDXONLY) {
	    close($handle);
	    file_gzip($tmpfile)  if $GzipFiles;
	    file_chmod(file_rename($tmpfile, $TIDXPATHNAME));
	}
    }
}

##---------------------------------------------------------------------------
##	Routine to compute the order messages are listed by thread.
##	Main use is to provide the ability to correctly define
##	values for resource variables related to next/prev thread
##	message.
##
##	NOTE: Thread order is determined by all the messages in an
##	archive, and not by what is visible in the thread index page.
##	Hence, if the thread index page size is less than number of
##	messages, the next/prev messages of thread (accessible via
##	resource variables) will not necessarily correspond to the
##	actual physical next/prev message listed in the thread index.
##	
##	The call to do_thread() defines the TListOrder array for use
##	in expanding thread related resource variables.
##
sub compute_threads {
    local(%FirstSub2Index) = ();
    local(%Counted) = ();
    local(%stripsub) = ();
    local(@refs);
    local($index, $msgid, $refindex, $depth, $tmp);

    ##	Reset key data structures
    @TListOrder  = ();
    %Index2TLoc  = ();
    %ThreadLevel = ();
    %HasRef	 = ();
    %HasRefDepth = ();
    %Replies 	 = ();
    %SReplies 	 = ();

    ##	Sort by date first for subject based threads
    @ThreadList = sort_messages(0,0,0,0);

    ##	Find first occurrances of subjects
    if (!$NoSubjectThreads) {
	foreach $index (@ThreadList) {
	    $tmp = lc $Subject{$index};
	    1 while (($tmp =~ s/^$SubReplyRxp//io) ||
		     ($tmp =~ s/\s*-\s*re(ply|sponse)\s*$//io));

	    $stripsub{$index} = $tmp;
	    next  unless $tmp =~ /\S/;
	    $FirstSub2Index{$tmp} = $index
		unless defined($FirstSub2Index{$tmp}) ||
		       (defined($Refs{$index}) &&
			grep($MsgId{$_}, @{$Refs{$index}}));
	}
    }

    ##	Compute thread data
    TCOMP: foreach $index (@ThreadList) {
	next  unless defined($Refs{$index});

	# Check for explicit threading
	if (@refs = @{$Refs{$index}}) {
	    $depth = 0;
	    while ($msgid = pop(@refs)) {
		if (($refindex = $MsgId{$msgid})) {

		    $HasRef{$index} = $refindex;
		    $HasRefDepth{$index} = $depth;
		    if ($Replies{$refindex}) {
			push(@{$Replies{$refindex}}, $index);
		    } else {
			$Replies{$refindex} = [ $index ];
		    }
		    next TCOMP;
		}
		++$depth;
	    }
	}

    } continue {
	# Check for subject-based threading
	if (!$NoSubjectThreads && !$HasRef{$index}) {
	    $refindex = $FirstSub2Index{$stripsub{$index}};
	    if ($refindex && ($refindex ne $index)) {

		$HasRef{$index} = $refindex;
		$HasRefDepth{$index} = 0;
		if ($SReplies{$refindex}) {
		    push(@{$SReplies{$refindex}}, $index);
		} else {
		    $SReplies{$refindex} = [ $index ];
		}
	    }
	}
    }

    ## Calculate thread listing order
    @ThreadList = sort_messages($TNOSORT, $TSUBSORT, 0, $TREVERSE);
    foreach $index (@ThreadList) {
	unless ($Counted{$index} || $HasRef{$index}) {
	    &do_thread($index, 0);
	}
    }
}

##---------------------------------------------------------------------------
##	do_thread() computes the order messages are listed by thread.
##	Uses %Counted defined locally in compute_thread_from_list().
##	do_thread() main purpose is to set the TListOrder array and
##	Index2TLoc assoc array.
##
sub do_thread {
    local($idx, $level) = ($_[0], $_[1]);
    local(@repls, @srepls) = ();

    ## Get replies
    @repls  = sort increase_index @{$Replies{$idx}}
	if defined($Replies{$idx});
    @srepls = sort increase_index @{$SReplies{$idx}}
	if defined($SReplies{$idx});

    ## Add index to printed order list (IMPORTANT SIDE-EFFECT)
    push(@TListOrder, $idx);
    $Index2TLoc{$idx} = $#TListOrder;

    ## Mark message
    $Counted{$idx} = 1;
    $ThreadLevel{$idx} = $level;

    if (@repls) {
	foreach (@repls) {
	    &do_thread($_, $level + 1 + $HasRefDepth{$_});
	}
    }
    if (@srepls) {
	foreach (@srepls) {
	    &do_thread($_, $level + 1 + $HasRefDepth{$_});
	}
    }
}

##---------------------------------------------------------------------------
##	Routine to print thread.
##	Uses %Printed defined by caller.
##
sub print_thread {
    local($handle, $idx, $top) = ($_[0], $_[1], $_[2]);
    my(@repls, @srepls) = ();
    my($attop, $haverepls, $hvnirepls, $single, $depth, $i);
    my $didtliend = 0;

    ## Get replies
    @repls  = sort increase_index @{$Replies{$idx}}
	if defined($Replies{$idx});
    @srepls = sort increase_index @{$SReplies{$idx}}
	if defined($SReplies{$idx});
    $depth  = $HasRefDepth{$idx};
    $hvnirepls = (@repls || @srepls);

    @repls  = grep($TVisible{$_}, @repls);
    @srepls = grep($TVisible{$_}, @srepls);
    $haverepls = (@repls || @srepls);

    ## $hvnirepls is a flag if the message has replies, but they are
    ## not visible.  $haverepls is a flag if the message has visible
    ## replies.  $hvnirepls is used to determine the $attop and
    ## $single flags.  $haverepls is used for determine recursive
    ## calls and level.

    ## Print entry
    #$attop  = ($top && $haverepls);
    #$single = ($top && !$haverepls);
    $attop   = ($top && $hvnirepls);
    $single  = ($top && !$hvnirepls);

    if ($attop) {
	&print_thread_var($handle, $idx, \$TTOPBEG);
    } elsif ($single) {
	&print_thread_var($handle, $idx, \$TSINGLETXT);
    } else {
	## Check for missing messages
	if ($DoMissingMsgs) {
	    for ($i=$depth; $i > 0; --$i) {
		++$level;
		&print_thread_var($handle, $idx, \$TLINONE);
		&print_thread_var($handle, $idx, \$TSUBLISTBEG)
		    if $level <= $TLEVELS;
	    }
	}
	&print_thread_var($handle, $idx, \$TLITXT);
    }

    ## Increment level count if their are replies
    ++$level  if ($haverepls);

    ## Print list item close if hit max depth
    if (!$attop && !$single && ($level > $TLEVELS)) {
	&print_thread_var($handle, $idx, \$TLIEND);
	$didtliend = 1;
    }

    ## Mark message printed
    $Printed{$idx} = 1;

    ## Print sub-threads
    if (scalar(@repls) || scalar(@srepls)) {
	&print_thread_var($handle, $idx, \$TSUBLISTBEG)  if $level <= $TLEVELS;
	foreach (@repls) {
	    &print_thread($handle, $_);
	}
	if (@srepls) {
	    &print_thread_var($handle, $idx, \$TSUBJECTBEG);
	    foreach (@srepls) {
		&print_thread($handle, $_);
	    }
	    &print_thread_var($handle, $idx, \$TSUBJECTEND);
	}
	&print_thread_var($handle, $idx, \$TSUBLISTEND)  if $level <= $TLEVELS;
    }

    ## Decrement level count if their were replies
    --$level  if ($haverepls);

    ## Check for missing messages
    if ($DoMissingMsgs && !($attop || $single)) {
	for ($i=$depth; $i > 0; --$i) {
	    &print_thread_var($handle, $idx, \$TLINONEEND);
	    &print_thread_var($handle, $idx, \$TSUBLISTEND)
		if $level <= $TLEVELS;
	    --$level;
	}
    }

    ## Close entry text
    if ($attop) {
	&print_thread_var($handle, $idx, \$TTOPEND);
    } elsif (!$single && !$didtliend) {
	&print_thread_var($handle, $idx, \$TLIEND);
    }
}

##---------------------------------------------------------------------------
##	Print out text based upon resource variable referenced by $tvar.
##
sub print_thread_var {
    my($handle, $index, $tvar) = @_;
    my($tmpl);
    ($tmpl = $$tvar) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
    #print $handle $tmpl;
    push @$handle, $tmpl;
}

##---------------------------------------------------------------------------
##	make_thread_slice generates a slice of the thread listing.
##	Arguments are:
##
##	    $refindex	: Reference message index that slice is based
##	    $bcnt	: Number of messages before $refindex to list
##	    $acnt	: Number of messages after $refindex to list
##
##	Returns string containing thread slice text.
##
sub make_thread_slice {
    my($refindex, $bcnt, $acnt, $inclusive) = @_;
    my($slicetxt) = "";

    my($pos)   = $Index2TLoc{$refindex};
    my($start) = $pos - $bcnt;
    my($end)   = $pos + $acnt;
    $start     = 0             if $start < 0;
    $end       = $#TListOrder  if $end > $#TListOrder;
    if ($inclusive) {
	# adjust before count
	if ($bcnt == 0 || $ThreadLevel{$TListOrder[$pos]} <= 0) {
	    $start = $pos;
	} else {
	    for ($i=$pos-1; ($i > $start) && ($i > 0); --$i) {
		last  if ($ThreadLevel{$TListOrder[$i]} <= 0);
	    }
	    $start = $i;
	}
	# adjust after count
	if ($acnt != 0) {
	    for ($i=$pos+1; ($i <= $end) && ($i <= $#TListOrder); ++$i) {
		last  if ($ThreadLevel{$TListOrder[$i]} <= 0);
	    }
	    $end = $i-1;
	}

    }
    my(@a)         = @TListOrder[$start..$end];
    my($lastlevel) = $ThreadLevel{$a[0]};
    my($tmpl, $index, $tlevel, $iscont, $i);

    local($level)     = 0;  	## XXX: Used in make_thread!!!
    local(%Printed)   = ();	## XXX: Used in make_thread!!!

    ($tmpl = $TSLICEBEG) =~ s/$VarExp/&replace_li_var($1,'')/geo;
    $slicetxt .= $tmpl;

    ## Flag visible messages for use in printing thread
    foreach $index (@a) { $TVisible{$index} = 1; }

    # check if continuing a thread
    if ($lastlevel > 0) {
	($tmpl = $TSLICECONTBEG) =~ s/$VarExp/&replace_li_var($1,$a[0])/geo;
	$slicetxt .= $tmpl;
    }
    # perform any indenting
    for ($i=0; $i < $lastlevel; ++$i) {
	++$level;
	if ($level <= $TSLICELEVELS) {
	    ($tmpl = $TSLICEINDENTBEG) =~ s/$VarExp/&replace_li_var($1,'')/geo;
	    $slicetxt .= $tmpl;
	}
    }
    # print index listing
    foreach $index (@a) {
	$tlevel = $ThreadLevel{$index};
	if (($lastlevel > 0) && ($tlevel < $lastlevel)) {
	    for ($i=$tlevel; $i < $lastlevel; ++$i) {
		if ($level <= $TSLICELEVELS) {
		    ($tmpl = $TSLICEINDENTEND) =~
			s/$VarExp/&replace_li_var($1,'')/geo;
		    $slicetxt .= $tmpl;
		}
		--$level;
	    }
	    $lastlevel = $tlevel;
	    if ($lastlevel < 1) {	# Check if continuation done
		($tmpl = $TSLICECONTEND) =~
		    s/$VarExp/&replace_li_var($1,'')/geo;
		$slicetxt .= $tmpl;
	    }
	}
	unless ($Printed{$index} ||
		($HasRef{$index} && $TVisible{$HasRef{$index}})) {
	    $slicetxt .= &make_thread($index,
			      (($lastlevel > 0) ? 0 : 1), $refindex);
	}
    }
    # unindent if required
    for ($i=0; $i < $lastlevel; ++$i) {
	if ($level <= $TSLICELEVELS) {
	    ($tmpl = $TSLICEINDENTEND) =~ s/$VarExp/&replace_li_var($1,'')/geo;
	    $slicetxt .= $tmpl;
	}
	--$level;
    }
    # close continuation if required
    if ($lastlevel > 0) {
	($tmpl = $TSLICECONTEND) =~ s/$VarExp/&replace_li_var($1,'')/geo;
	$slicetxt .= $tmpl;
    }

    ## Reset visibility flags
    foreach $index (@a) { $TVisible{$index} = 0; }

    ($tmpl = $TSLICEEND) =~ s/$VarExp/&replace_li_var($1,'')/geo;
    $slicetxt .= $tmpl;

    $slicetxt;
}

##---------------------------------------------------------------------------
##	Routine to generate text representing a thread.
##	Used by make_thread_slice().
##	Uses %Printed and $level defined by caller.
##
sub make_thread {
    my($idx, $top, $refidx) = @_;
    my($attop, $haverepls, $hvnirepls, $single, $depth, $i);
    my(@repls, @srepls) = ( );
    my($ret) = "";

    ## Get replies
    @repls  = sort increase_index @{$Replies{$idx}}
	if defined($Replies{$idx});
    @srepls = sort increase_index @{$SReplies{$idx}}
	if defined($SReplies{$idx});
    $depth  = $HasRefDepth{$idx};
    $hvnirepls = (@repls || @srepls);

    @repls  = grep($TVisible{$_}, @repls);
    @srepls = grep($TVisible{$_}, @srepls);
    $haverepls = (@repls || @srepls);

    ## $hvnirepls is a flag if the message has replies, but they are
    ## not visible.  $haverepls is a flag if the message has visible
    ## replies.  $hvnirepls is used to determine the $attop and
    ## $single flags.  $haverepls is used for determine recursive
    ## calls and level.

    ## Print entry
    $attop   = ($top && $hvnirepls);
    $single  = ($top && !$hvnirepls);

    if ($attop) {
	$ret .= &expand_thread_var($idx,
		  ($idx eq $refidx) ? \$TSLICETOPBEGCUR : \$TSLICETOPBEG);
    } elsif ($single) {
	$ret .= &expand_thread_var($idx,
		  ($idx eq $refidx) ? \$TSLICESINGLETXTCUR: \$TSLICESINGLETXT);
    } else {
	## Check for missing messages
	if ($DoMissingMsgs) {
	    for ($i = $depth; $i > 0; $i--) {
		$level++;
		$ret .= &expand_thread_var($idx, \$TSLICELINONE);
		$ret .= &expand_thread_var($idx, \$TSLICESUBLISTBEG)
		    if $level <= $TSLICELEVELS;
	    }
	}
	$ret .= &expand_thread_var($idx,
		  ($idx eq $refidx) ? \$TSLICELITXTCUR : \$TSLICELITXT);
    }

    ## Increment level count if their are replies
    if ($haverepls) {
	$level++;
    }

    ## Mark message printed
    $Printed{$idx} = 1;

    ## Print sub-threads
    if (@repls) {
	$ret .= &expand_thread_var($idx, \$TSLICESUBLISTBEG)
	    if $level <= $TSLICELEVELS;
	foreach (@repls) {
	    $ret .= &make_thread($_, 0, $refidx);
	}
	$ret .= &expand_thread_var($idx, \$TSLICESUBLISTEND)
	    if $level <= $TSLICELEVELS;
    }
    if (@srepls) {
	$ret .= &expand_thread_var($idx, \$TSLICESUBLISTBEG)
	    if $level <= $TSLICELEVELS;
	$ret .= &expand_thread_var($idx, \$TSLICESUBJECTBEG);
	foreach (@srepls) {
	    $ret .= &make_thread($_, 0, $refidx);
	}
	$ret .= &expand_thread_var($idx, \$TSLICESUBJECTEND);
	$ret .= &expand_thread_var($idx, \$TSLICESUBLISTEND)
	    if $level <= $TSLICELEVELS;
    }

    ## Decrement level count if their were replies
    if ($haverepls) {
	$level--;
    }
    ## Check for missing messages
    if ($DoMissingMsgs && !($attop || $single)) {
	for ($i = $depth; $i > 0; $i--) {
	    $ret .= &expand_thread_var($idx, \$TSLICELINONEEND);
	    $ret .= &expand_thread_var($idx, \$TSLICESUBLISTEND)
		if $level <= $TSLICELEVELS;
	    $level--;
	}
    }

    ## Close entry text
    if ($attop) {
	$ret .= &expand_thread_var($idx,
		  ($idx eq $refidx) ? \$TSLICETOPENDCUR : \$TSLICETOPEND);
    } elsif (!$single) {
	$ret .= &expand_thread_var($idx,
		  ($idx eq $refidx) ? \$TSLICELIENDCUR : \$TSLICELIEND);
    }

    $ret;
}

##---------------------------------------------------------------------------
##	Expand text based upon resource variable referenced by $tvar.
##
sub expand_thread_var {
    my($index, $tvar) = @_;
    my($expstr);
    ($expstr = $$tvar) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
    $expstr;
}

##---------------------------------------------------------------------------
1;
