##---------------------------------------------------------------------------##
##  File:
##	$Id: mhindex.pl,v 1.11 2002/11/20 23:53:12 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##	Main index routines for mhonarc
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
##	write_main_index outputs main index of archive
##
sub write_main_index {
    my $onlypg = shift;
    my($outhandle, $tmpfile, $i, $i_p0, $tmpl, $isfirst, $tmp,
       $offstart, $offend);
    local($PageNum, $PageSize); # XXX: Use in replace_li_vars()
    my($totalpgs);
    local(*a);

    &compute_page_total();
    $PageNum    = $onlypg || 1;
    $totalpgs   = $onlypg || $NumOfPages;
    if (!scalar(@MListOrder)) {
	@MListOrder = &sort_messages();
	%Index2MLoc = ();
	@Index2MLoc{@MListOrder} = (0 .. $#MListOrder);
    }

    for ( ; $PageNum <= $totalpgs; ++$PageNum) {
	next  if $PageNum < $IdxMinPg;

	$isfirst = 1;

        if ($MULTIIDX) {
            $offstart = ($PageNum-1) * $IDXSIZE;
            $offend   = $offstart + $IDXSIZE-1;
            $offend   = $#MListOrder  if $#MListOrder < $offend;
            @a        = @MListOrder[$offstart..$offend];

	    if ($PageNum > 1) {
		$IDXPATHNAME = join("", $OUTDIR, $DIRSEP,
				    $IDXPREFIX, $PageNum, ".", $HtmlExt);
	    } else {
		$IDXPATHNAME = join($DIRSEP, $OUTDIR, $IDXNAME);
	    }

	} else {
	    if ($IDXSIZE && (($i = ($#MListOrder+1) - $IDXSIZE) > 0)) {
		if ($REVSORT) {
		    @a = @MListOrder[0..($IDXSIZE-1)];
		} else {
		    @a = @MListOrder[$i..$#MListOrder];
		}
	    } else {
		*a = *MListOrder;
	    }
	    $IDXPATHNAME = join($DIRSEP, $OUTDIR, $IDXNAME);
	}
	$PageSize = scalar(@a);
	    
	## Open/create index file
	if ($IDXONLY) {
	   $outhandle = \*STDOUT;
	} else {
	    ($outhandle, $tmpfile) = file_temp('midxXXXXXXXXXX', $OUTDIR);
	}
	print STDOUT "Writing $IDXPATHNAME ...\n"  unless $QUIET;

	## Print top part of index
	&output_maillist_head($outhandle);

	## Output links to messages

	if ($NOSORT) {
	    foreach $index (@a) {
		($tmpl = $LITMPL) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
		#print $outhandle $tmpl;
		push @$outhandle, $tmpl;
	    }

	} elsif ($SUBSORT) {
	    my($prevsub) = '';
	    foreach $index (@a) {
		if (($tmp = get_base_subject($index)) ne $prevsub) {
		    $prevsub = $tmp;
		    if (!$isfirst) {
			($tmpl = $SUBJECTEND) =~
				s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
			#print $outhandle $tmpl;
			push @$outhandle, $tmpl;
		    } else {
			$isfirst = 0;
		    }
		    ($tmpl = $SUBJECTBEG) =~
			s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
		    #print $outhandle $tmpl;
		    push @$outhandle, $tmpl;
		}
		($tmpl = $LITMPL) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
		#print $outhandle $tmpl;
		push @$outhandle, $tmpl;
	    }
	    ($tmpl = $SUBJECTEND) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
	    #print $outhandle $tmpl;
	    push @$outhandle, $tmpl;

	} elsif ($AUTHSORT) {
	    local($prevauth) = '';
	    foreach $index (@a) {
		if (($tmp = &get_base_author($index)) ne $prevauth) {
		    $prevauth = $tmp;
		    if (!$isfirst) {
			($tmpl = $AUTHEND) =~
			    s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
			#print $outhandle $tmpl;
			push @$outhandle, $tmpl;
		    } else {
			$isfirst = 0;
		    }
		    ($tmpl = $AUTHBEG) =~
			s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
		    #print $outhandle $tmpl;
		    push @$outhandle, $tmpl;
		}
		($tmpl = $LITMPL) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
		#print $outhandle $tmpl;
		push @$outhandle, $tmpl;
	    }
	    ($tmpl = $AUTHEND) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
	    #print $outhandle $tmpl;
	    push @$outhandle, $tmpl;

	} else {
	    my($prevdate) = '';
	    my($time);
	    foreach $index (@a) {
		$time = &get_time_from_index($index);
# CPU2006 -- only use GMT
#		$tmp = join("", $UseLocalTime ? (localtime($time))[3,4,5] :
#						(gmtime($time))[3,4,5]);
		$tmp = join("", (gmtime($time))[3,4,5]);
		if ($tmp ne $prevdate) {
		    $prevdate = $tmp;
		    if (!$isfirst) {
			($tmpl = $DAYEND) =~
			    s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
			#print $outhandle $tmpl;
			push @$outhandle, $tmpl;
		    } else {
			$isfirst = 0;
		    }
		    ($tmpl = $DAYBEG) =~
			s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
		    #print $outhandle $tmpl;
		    push @$outhandle, $tmpl;
		}
		($tmpl = $LITMPL) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
		#print $outhandle $tmpl;
		push @$outhandle, $tmpl;
	    }
	    ($tmpl = $DAYEND) =~ s/$VarExp/&replace_li_var($1,$index)/geo;
# CPU2006
	    #print $outhandle $tmpl;
	    push @$outhandle, $tmpl;
	}

	## Print bottom part of index
	&output_maillist_foot($outhandle);
# CPU2006
#	if (!$IDXONLY) {
#	    close($outhandle);
#	    file_gzip($tmpfile)  if $GzipFiles;
#	    file_chmod(file_rename($tmpfile, $IDXPATHNAME));
#	}
    }
}

##---------------------------------------------------------------------------
##	output_maillist_head() outputs the beginning of the index page.
##
sub output_maillist_head {
    my $handle = shift;
    local $index = "";
    my($tmp);

    $tmp = ($IDXPGSSMARKUP ne '') ? $IDXPGSSMARKUP : $SSMARKUP;
    if ($tmp ne '') {
	$tmp =~ s/$VarExp/&replace_li_var($1,'')/geo;
# CPU2006
	#print $handle $tmp;
	push @$handle, $tmp;
    }

# CPU2006
    #print $handle "<!-- ", &commentize("MHonArc v$VERSION"), " -->\n";
    push @$handle, "<!-- ". &commentize("MHonArc v$VERSION"). " -->\n";

    ## Output title
    ($tmp = $IDXPGBEG) =~ s/$VarExp/&replace_li_var($1,'')/geo;
# CPU2006
    #print $handle $tmp;
    push @$handle, $tmp;

    ## Output start of index
    ($tmp = $LIBEG) =~ s/$VarExp/&replace_li_var($1,'')/geo;
# CPU2006
    #print $handle $tmp;
    push @$handle, $tmp;
}

##---------------------------------------------------------------------------
##	output_maillist_foot() outputs the end of the index page.
##
sub output_maillist_foot {
    my $handle = shift;
    local $index = "";
    my($tmp);

    ## Close message listing
    ($tmp = $LIEND) =~ s/$VarExp/&replace_li_var($1,'')/geo;
# CPU2006
    #print $handle $tmp;
    push @$handle, $tmp;

    &output_doclink($handle);

    ## Close document
    ($tmp = $IDXPGEND) =~ s/$VarExp/&replace_li_var($1,'')/geo;
# CPU2006
    #print $handle $tmp;
    #print $handle "<!-- ", &commentize("MHonArc v$VERSION"), " -->\n";
    push @$handle, $tmp;
    push @$handle, "<!-- ". &commentize("MHonArc v$VERSION"). " -->\n";
}

##---------------------------------------------------------------------------
##	Output link to documentation, if specified
##
sub output_doclink {
    local($handle) = ($_[0]);
    if (!$NODOC && $DOCURL) {
# CPU2006
#	print $handle "<hr>\n";
#	print $handle
#		"<address>\n",
#		"Mail converted by ",
#		qq|<a href="$DOCURL">MHonArc</a> $VERSION\n|,
#		"</address>\n";
	push @$handle, "<hr>\n",
		"<address>\n",
		"Mail converted by ".
		qq|<a href="$DOCURL">MHonArc</a> $VERSION\n|.
		"</address>\n";
    }
}

##---------------------------------------------------------------------------
1;
