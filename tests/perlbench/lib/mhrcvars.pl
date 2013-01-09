##---------------------------------------------------------------------------##
##  File:
##	$Id: mhrcvars.pl,v 2.25 2003/02/04 23:31:19 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      Defines routine for expanding resource variables.
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
##    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
##    02111-1307, USA
##---------------------------------------------------------------------------##

package mhonarc;

## Mapping of old resource variables to current versions.
my %old2new = (
    'FIRSTPG'    	=> [ 'PG', 'FIRST' ],
    'LASTPG'    	=> [ 'PG', 'LAST' ],
    'NEXTBUTTON'    	=> [ 'BUTTON', 'NEXT' ],
    'NEXTFROM'    	=> [ 'FROM', 'NEXT' ],
    'NEXTFROMADDR'    	=> [ 'FROMADDR', 'NEXT' ],
    'NEXTFROMNAME'    	=> [ 'FROMNAME', 'NEXT' ],
    'NEXTLINK'    	=> [ 'LINK', 'NEXT' ],
    'NEXTMSG'    	=> [ 'MSG', 'NEXT' ],
    'NEXTMSGNUM'    	=> [ 'MSGNUM', 'NEXT' ],
    'NEXTPG'    	=> [ 'PG', 'NEXT' ],
    'NEXTPGLINK'    	=> [ 'PGLINK', 'NEXT' ],
    'NEXTSUBJECT'	=> [ 'SUBJECT', 'NEXT' ],
    'PREVBUTTON'    	=> [ 'BUTTON', 'PREV' ],
    'PREVFROM'    	=> [ 'FROM', 'PREV' ],
    'PREVFROMADDR'    	=> [ 'FROMADDR', 'PREV' ],
    'PREVFROMNAME'    	=> [ 'FROMNAME', 'PREV' ],
    'PREVLINK'    	=> [ 'LINK', 'PREV' ],
    'PREVMSG'    	=> [ 'MSG', 'PREV' ],
    'PREVMSGNUM'    	=> [ 'MSGNUM', 'PREV' ],
    'PREVPGLINK'    	=> [ 'PGLINK', 'PREV' ],
    'PREVPG'    	=> [ 'PG', 'PREV' ],
    'PREVSUBJECT'	=> [ 'SUBJECT', 'PREV' ],
    'TFIRSTPG'    	=> [ 'PG', 'TFIRST' ],
    'TLASTPG'    	=> [ 'PG', 'TLAST' ],
    'TNEXTBUTTON'    	=> [ 'BUTTON', 'TNEXT' ],
    'TNEXTFROM'    	=> [ 'FROM', 'TNEXT' ],
    'TNEXTFROMADDR'    	=> [ 'FROMADDR', 'TNEXT' ],
    'TNEXTFROMNAME'    	=> [ 'FROMNAME', 'TNEXT' ],
    'TNEXTLINK'    	=> [ 'LINK', 'TNEXT' ],
    'TNEXTMSG'    	=> [ 'MSG', 'TNEXT' ],
    'TNEXTMSGNUM'    	=> [ 'MSGNUM', 'TNEXT' ],
    'TNEXTPGLINK'    	=> [ 'PGLINK', 'TNEXT' ],
    'TNEXTPG'    	=> [ 'PG', 'TNEXT' ],
    'TNEXTSUBJECT'	=> [ 'SUBJECT', 'TNEXT' ],
    'TPREVBUTTON'    	=> [ 'BUTTON', 'TPREV' ],
    'TPREVFROM'    	=> [ 'FROM', 'TPREV' ],
    'TPREVFROMADDR'    	=> [ 'FROMADDR', 'TPREV' ],
    'TPREVFROMNAME'    	=> [ 'FROMNAME', 'TPREV' ],
    'TPREVLINK'    	=> [ 'LINK', 'TPREV' ],
    'TPREVMSG'    	=> [ 'MSG', 'TPREV' ],
    'TPREVMSGNUM'    	=> [ 'MSGNUM', 'TPREV' ],
    'TPREVPGLINK'    	=> [ 'PGLINK', 'TPREV' ],
    'TPREVPG'    	=> [ 'PG', 'TPREV' ],
    'TPREVSUBJECT'	=> [ 'SUBJECT', 'TPREV' ],
);

##---------------------------------------------------------------------------
##	replace_li_var() is used to substitute vars to current
##	values.  This routine relies on some variables being set by the
##	calling routine or as globals.
##
sub replace_li_var {
    my($val, $index) = ($_[0], $_[1]);
    my($var,$len,$canclip,$raw,$isurl,$tmp,$ret) = ('',0,0,0,0,'','');
    my($jstr) = (0);
    my($expand) = (0);
    my($n) = (0);
    my($lref, $key, $pos);
    my($arg, $opt) = ("", "");
    my $isaddr = 0;

    ##	Get variable argument string
    if ($val =~ s/\(([^()]*)\)//) {
	$arg = $1;
    }

    ##	Get length specifier (if defined)
    ($var, $len) = split(/:/, $val, 2);
    $len = -1  unless defined $len;

    ##	Check for old resource variables and map to new
    ($var, $arg) = @{$old2new{$var}}  if defined($old2new{$var});

    ##	Check if variable in a URL string
    $isurl = 1  if ($len =~ s/u//ig);	
    ##	Check if variable in a JavaScript string
    $jstr  = 1  if ($len =~ s/j//ig);	

    ##	Do variable replacement
    REPLACESW: {
	## Invoke callback if defined
	if (defined($CBRcVarExpand) && defined(&$CBRcVarExpand)) {
	    ($tmp, $expand, $canclip) = &$CBRcVarExpand($index, $var, $arg);
	    last REPLACESW  if defined($tmp);
	}

	## -------------------------------------- ##
	## Message information resource variables ##
	## -------------------------------------- ##
    	if ($var eq 'DATE') {		## Message "Date:"
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    $tmp = defined($key) ? $Date{$key} : "";
	    last REPLACESW;
	}
    	if ($var eq 'DDMMYY' || $var eq 'DDMMYYYY' ||
	    $var eq 'MMDDYY' || $var eq 'MMDDYYYY' ||
	    $var eq 'YYMMDD' || $var eq 'YYYYMMDD') {
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    $tmp = defined($key) ?
			&time2mmddyy((split(/$X/o, $key))[0], lc $var) :
			"";
	    last REPLACESW;
	}
	my($cnd1, $cnd2, $cnd3) = (0,0,0);
    	if (($cnd1 = ($var eq 'FROM')) ||	## Message "From:"
	    ($cnd2 = ($var eq 'FROMADDR')) ||	## Message from mail address
	    ($cnd3 = ($var eq 'FROMNAME'))) {	## Message from name
	    my $esub = $cnd1 ? sub { $_[0]; } :
		       $cnd2 ? \&extract_email_address :
			       \&extract_email_name;
	    $canclip = 1; $raw = 1;
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    $tmp = defined($key) ? &$esub($From{$key}) : "(nil)";
	    if ($cnd3 && $SpamMode) {
		$tmp =~ s/($AddrExp)/rewrite_raw_address($1)/geo;
	    }
	    last REPLACESW;
	}
    	if ( ($cnd1 = ($var eq 'FROMADDRNAME')) ||
	     ($cnd2 = ($var eq 'FROMADDRDOMAIN')) ) {
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    if (!defined($key)) {
		$tmp = "";
		last REPLACESW;
	    }
	    my @a = split(/@/, extract_email_address($From{$key}), 2);
	    if ($cnd1) {
		$tmp = $a[0];
		last REPLACESW;
	    }
	    $tmp = defined($a[1]) ? $a[1] : "";
	    last REPLACESW;
	}
    	if ($var eq 'ICON') {		## Message icon
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    if (!defined($key)) {
		$tmp = "";
		last REPLACESW;
	    }
	    my($iconurl, $iw, $ih) = mhonarc::get_icon_url($ContentType{$key});
	    my $alttext = $iconurl ? $ContentType{$key} : 'unknown';
	    $tmp  = qq|<img src="$iconurl" border="0" alt="[$alttext]"|;
	    $tmp .= ' width="' .  $iw . '"'  if $iw;
	    $tmp .= ' height="' . $ih . '"'  if $ih;
	    $tmp .= '>';
	    last REPLACESW;
	}
    	if ($var eq 'ICONURL') {	## URL to message icon
	    $isurl = 0;
	    ($lref, $key, $pos)    = compute_msg_pos($index, $var, $arg);
	    my($iconurl, $iw, $ih) = mhonarc::get_icon_url($ContentType{$key});
	    $tmp = $iconurl  if defined($iconurl);
	    last REPLACESW;
	}
    	if ($var eq 'ICONURLPREFIX') {	## URL prefix to message icon
	    $isurl = 0;
	    $tmp = $IconURLPrefix;
	    last REPLACESW;
	}
    	if ($var eq 'MSG') {		## Filename of message page
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    $tmp = defined($key) ? &msgnum_filename($IndexNum{$key}) : "";
	    last REPLACESW;
	}
	if ($var eq 'MSGHFIELD') {	## Message header field
	    $canclip = 1; $raw = 1;
	    ($lref, $key, $pos, $opt) = compute_msg_pos($index, $var, $arg);
	    if (!defined($key)) {
		$tmp = '';
		last REPLACESW;
	    }
	    $opt =~ s/\s+//g;  $opt = lc $opt;
	    HFIELD: {
		my $fields = $ExtraHFields{$key};
		if (defined($fields) && defined($tmp = $fields->{$opt})) {
		    last HFIELD;
		}
		if ($opt eq 'subject') {
		    $tmp = $Subject{$key};
		    $tmp = $NoSubjectTxt  if $tmp eq '';
		    last HFIELD;
		}
		$tmp = '';
	    }
	    if ($HFieldsAddr{$opt}) {
		$isaddr = 1;
	    }
	    last REPLACESW;
	}
    	if ($var eq 'MSGGMTDATE') {	## Message GMT date
	    ($lref, $key, $pos, $opt) = compute_msg_pos($index, $var, $arg);
	    $tmp = &time2str($opt || $MsgGMTDateFmt,
			     &get_time_from_index($key), 0);
	    last REPLACESW;
	}
    	if ($var eq 'MSGID') {		## Message-ID
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    $tmp = defined($key) ? $Index2MsgId{$key} : "";
	    last REPLACESW;
	}
    	if ($var eq 'MSGLOCALDATE') {	## Message local date
	    ($lref, $key, $pos, $opt) = compute_msg_pos($index, $var, $arg);
	    $tmp = &time2str($opt || $MsgLocalDateFmt,
			     &get_time_from_index($key), 1);
	    last REPLACESW;
	}
    	if ($var eq 'MSGNUM') {		## Message number
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    $tmp = defined($key) ? &fmt_msgnum($IndexNum{$key}) : "";
	    last REPLACESW;
	}
    	if ($var eq 'MSGTORDNUM') {	## Message ordinal num in cur thread
	    # Some form of optimization should be done here since
	    # computation can degrade to n^2 (where n is size of thread)
	    # if variable is referenced for each message on thread index
	    # page.
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg, 1);
	    $tmp = 1;
	    my $level = $ThreadLevel{$key};
	    for (--$pos ; ($level > 0) && ($pos >= 0); --$pos, ++$tmp ) {
		$level = $ThreadLevel{$TListOrder[$pos]};
	    }
	    last REPLACESW;
	}
    	if ($var eq 'NOTE') {		## Annotation template markup
	    $expand = 1;
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    $tmp = note_exists($key) ? $NOTE : $NOTEIA;
	    last REPLACESW;
	}
    	if ($var eq 'NOTEICON') {	## Annotation ICON (HTML markup)
	    $expand = 1;
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    $tmp = note_exists($key) ? $NOTEICON : $NOTEICONIA;
	    last REPLACESW;
	}
    	if ($var eq 'NOTETEXT') {	## Annotation text
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    $tmp = get_note($key);
	    last REPLACESW;
	}
    	if ($var eq 'NUMFOLUP') {	## Number of explicit follow-ups
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    $tmp = defined($key) ? $FolCnt{$key} : "";
	    last REPLACESW;
	}
    	if ($var eq 'ORDNUM') {		## Sort order number of message
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    $tmp = defined($key) ? $pos+1 : -1;
	    last REPLACESW;
	}
    	if ($var eq 'SUBJECT') {	## Message subject
	    $canclip = 1; $raw = 1; $isurl = 0;
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    if (defined($key)) {
		$tmp = $Subject{$key};
		$tmp = $NoSubjectTxt  if $tmp eq "";
	    } else {
		$tmp = "";
	    }
	    last REPLACESW;
	}
    	if ($var eq 'SUBJECTNA') {	## Message subject (not linked)
	    $canclip = 1; $raw = 1;
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    if (defined($key)) {
		$tmp = $Subject{$key};
		$tmp = $NoSubjectTxt  if $tmp eq "";
	    } else {
		$tmp = "";
	    }
	    last REPLACESW;
	}
    	if ($var eq 'TLEVEL') {		## Thread level
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    $tmp = $ThreadLevel{$key};
	    last REPLACESW;
	}

	## ------------------------------------- ##
	## Message navigation resource variables ##
	## ------------------------------------- ##
	if ($var eq 'BUTTON') {
	    $expand = 1;
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    SW: {
		if ($arg eq 'NEXT') {
		    $tmp = defined($key) ? $NEXTBUTTON : $NEXTBUTTONIA;
		    last SW; }
		if ($arg eq 'PREV') {
		    $tmp = defined($key) ? $PREVBUTTON : $PREVBUTTONIA;
		    last SW; }
		if ($arg eq 'TNEXT') {
		    $tmp = defined($key) ? $TNEXTBUTTON : $TNEXTBUTTONIA;
		    last SW; }
		if ($arg eq 'TPREV') {
		    $tmp = defined($key) ? $TPREVBUTTON : $TPREVBUTTONIA;
		    last SW; }
		if ($arg eq 'TNEXTIN') {
		    $tmp = defined($key) ? $TNEXTINBUTTON : $TNEXTINBUTTONIA;
		    last SW; }
		if ($arg eq 'TPREVIN') {
		    $tmp = defined($key) ? $TPREVINBUTTON : $TPREVINBUTTONIA;
		    last SW; }
		if ($arg eq 'TNEXTTOP') {
		    $tmp = defined($key) ? $TNEXTTOPBUTTON : $TNEXTTOPBUTTONIA;
		    last SW; }
		if ($arg eq 'TPREVTOP') {
		    $tmp = defined($key) ? $TPREVTOPBUTTON : $TPREVTOPBUTTONIA;
		    last SW; }
		if ($arg eq 'TTOP') {
		    $tmp = ($key ne $index) ? $TTOPBUTTON : $TTOPBUTTONIA;
		    last SW; }
		if ($arg eq 'TEND') {
		    $tmp = ($key ne $index) ? $TENDBUTTON : $TENDBUTTONIA;
		    last SW; }
	    }
	    last REPLACESW;
	}
	if ($var eq 'LINK') {
	    $expand = 1;
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    SW: {
		if ($arg eq 'NEXT') {
		    $tmp = defined($key) ? $NEXTLINK : $NEXTLINKIA;
		    last SW; }
		if ($arg eq 'PREV') {
		    $tmp = defined($key) ? $PREVLINK : $PREVLINKIA;
		    last SW; }
		if ($arg eq 'TNEXT') {
		    $tmp = defined($key) ? $TNEXTLINK : $TNEXTLINKIA;
		    last SW; }
		if ($arg eq 'TPREV') {
		    $tmp = defined($key) ? $TPREVLINK : $TPREVLINKIA;
		    last SW; }
		if ($arg eq 'TNEXTIN') {
		    $tmp = defined($key) ? $TNEXTINLINK : $TNEXTINLINKIA;
		    last SW; }
		if ($arg eq 'TPREVIN') {
		    $tmp = defined($key) ? $TPREVINLINK : $TPREVINLINKIA;
		    last SW; }
		if ($arg eq 'TNEXTTOP') {
		    $tmp = defined($key) ? $TNEXTTOPLINK : $TNEXTTOPLINKIA;
		    last SW; }
		if ($arg eq 'TPREVTOP') {
		    $tmp = defined($key) ? $TPREVTOPLINK : $TPREVTOPLINKIA;
		    last SW; }
		if ($arg eq 'TTOP') {
		    $tmp = ($key ne $index) ? $TTOPLINK : $TTOPLINKIA;
		    last SW; }
		if ($arg eq 'TEND') {
		    $tmp = ($key ne $index) ? $TENDLINK : $TENDLINKIA;
		    last SW; }
	    }
	    last REPLACESW;
	}

    	if ($var eq 'TSLICE') {
	    my($bcnt, $acnt, $inclusive);
	    if ($arg) {
	      ($bcnt, $acnt, $inclusive) = split(/[;:]/, $arg);
	      $bcnt = $TSliceNBefore  if (!defined($bcnt) || $bcnt !~ /^\d+$/);
	      $acnt = $TSliceNAfter   if (!defined($acnt) || $acnt !~ /^\d+$/);
	      $inclusive = $TSliceInclusive  if (!defined($inclusive));
	    } else {
	      $bcnt = $TSliceNBefore;
	      $acnt = $TSliceNAfter;
	      $inclusive = $TSliceInclusive;
	    }
	    $tmp = &make_thread_slice($index, $bcnt, $acnt, $inclusive)
	    	if ($bcnt != 0 || $acnt != 0);
	    last REPLACESW;
	}

	## -------------------------------- ##
	## Index related resource variables ##
	## -------------------------------- ##
    	if ($var eq 'A_ATTR') {		## Anchor attrs to link to message
	    $isurl = 0;
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    if (!defined($key)) { $tmp = ""; last REPLACESW; }
	    $tmp = qq/name="/ . &fmt_msgnum($IndexNum{$key}) .
		   qq/" href="/ .
		   &msgnum_filename($IndexNum{$key}) .
		   qq/"/;
	    last REPLACESW;
	}
    	if ($var eq 'A_NAME') {		## Anchor name for message position
	    $isurl = 0;
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    if (!defined($key)) { $tmp = ""; last REPLACESW; }
	    $tmp = qq/name="/ . &fmt_msgnum($IndexNum{$key}) . qq/"/;
	    last REPLACESW;
	}
    	if ($var eq 'A_HREF') {		## Anchor href to link to message
	    $isurl = 0;
	    ($lref, $key, $pos) = compute_msg_pos($index, $var, $arg);
	    if (!defined($key)) { $tmp = ""; last REPLACESW; }
	    $tmp = qq/href="/ . &msgnum_filename($IndexNum{$key}) . qq/"/;
	    last REPLACESW;
	}
    	if ($var eq 'IDXFNAME') {	## Filename of index page
	    if ($MULTIIDX && ($n = int($Index2MLoc{$index}/$IDXSIZE)+1) > 1) {
		$tmp = sprintf("%s%d.$HtmlExt",
			       $IDXPREFIX, $index ne '' ? $n : 1);
	    } else {
		$tmp = $IDXNAME;
	    }
	    $tmp .= ".gz"  if $GzipLinks;
	    last REPLACESW;
	}
    	if ($var eq 'IDXLABEL') {	## Label for main index
	    $tmp = $IDXLABEL;
	    last REPLACESW;
	}
    	if ($var eq 'IDXSIZE') {	## Index page size
	    $tmp = $IDXSIZE;
	    last REPLACESW;
	}
    	if ($var eq 'IDXTITLE') {	## Main index title
	    $canclip = 1; $expand = 1;
	    $tmp = $TITLE;
	    last REPLACESW;
	}
    	if ($var eq 'NUMOFIDXMSG') {	## Number of items on the index page
	    $tmp = $PageSize;
	    last REPLACESW;
	}
    	if ($var eq 'NUMOFMSG') {	## Total number of messages
	    $tmp = $NumOfMsgs;
	    last REPLACESW;
	}
    	if ($var eq 'SORTTYPE') {	## Sort type of index
	    SORTTYPE: {
		if ($NOSORT)   { $tmp = 'Number';  last SORTTYPE; }
		if ($AUTHSORT) { $tmp = 'Author';  last SORTTYPE; }
		if ($SUBSORT)  { $tmp = 'Subject'; last SORTTYPE; }
		$tmp = 'Date';
		last SORTTYPE;
	    }
	    last REPLACESW;
	}
    	if ($var eq 'TIDXFNAME') {
	    if ($MULTIIDX && ($n = int($Index2TLoc{$index}/$IDXSIZE)+1) > 1) {
		$tmp = sprintf("%s%d.$HtmlExt",
			       $TIDXPREFIX, $index ne '' ? $n : 1);
	    } else {
		$tmp = $TIDXNAME;
	    }
	    $tmp .= ".gz"  if $GzipLinks;
	    last REPLACESW;
	}
    	if ($var eq 'TIDXLABEL') {
	    $tmp = $TIDXLABEL;
	    last REPLACESW;
	}
    	if ($var eq 'TIDXTITLE') {
	    $canclip = 1; $expand = 1;
	    $tmp = $TTITLE;
	    last REPLACESW;
	}
    	if ($var eq 'TSORTTYPE') {
	    TSORTTYPE: {
		if ($TNOSORT)   { $tmp = 'Number';  last TSORTTYPE; }
		if ($TSUBSORT)  { $tmp = 'Subject'; last TSORTTYPE; }
		$tmp = 'Date';
		last TSORTTYPE;
	    }
	    last REPLACESW;
	}

	if ($var eq 'PGLINK') {
	    $expand = 1;
	    SW: {
		if ($arg eq 'NEXT') {
		    $tmp = $PageNum < $NumOfPages ?
		    			$NEXTPGLINK : $NEXTPGLINKIA;
		    last SW; }
		if ($arg eq 'PREV') {
		    $tmp = $PageNum > 1 ? $PREVPGLINK : $PREVPGLINKIA;
		    last SW; }
		if ($arg eq 'TNEXT') {
		    $tmp = $PageNum < $NumOfPages ?
		    			$TNEXTPGLINK : $TNEXTPGLINKIA;
		    last SW; }
		if ($arg eq 'TPREV') {
		    $tmp = $PageNum > 1 ? $TPREVPGLINK : $TPREVPGLINKIA;
		    last SW; }
		if ($arg eq 'FIRST') {
		    $tmp = $FIRSTPGLINK;
		    last SW; }
		if ($arg eq 'LAST') {
		    $tmp = $LASTPGLINK;
		    last SW; }
		if ($arg eq 'TFIRST') {
		    $tmp = $TFIRSTPGLINK;
		    last SW; }
		if ($arg eq 'TLAST') {
		    $tmp = $TLASTPGLINK;
		    last SW; }
	    }
	    last REPLACESW;
	}
	if ($var eq 'PGLINKLIST') {
	    my $num = $PageNum;
	    my $t = $arg =~ s/T//gi;
	    my($before, $after) = split(/;/, $arg);
	    my $prefix  = $t ? $TIDXPREFIX : $IDXPREFIX;
	    my $suffix  = $HtmlExt;
	       $suffix .= '.gz'  if $GzipLinks;
	    if ($before ne "") {
		$before = $num - abs($before);
		$before = 1  unless $before > 1;
	    } else {
		$before = 1;
	    }
	    if ($after ne "") {
		$after  = $num + abs($after);
		$after  = $NumOfPages  unless $after < $NumOfPages;
	    } else {
		$after  = $NumOfPages;
	    }
	    $tmp = "";
	    for ($i=$before; $i < $num; ++$i) {
		if ($i == 1) {
		    $tmp .= sprintf('<a href="%s%s">%d</a> | ',
				    ($t ? $TIDXNAME : $IDXNAME),
				    ($GzipLinks ? '.gz' : ""), $i);
		    next;
		}
		$tmp .= sprintf('<a href="%s%d.%s">%d</a> | ',
			        $prefix, $i, $suffix, $i);
	    }
	    $tmp .= $num;
	    for ($i=$num+1; $i <= $after; ++$i) {
		$tmp .= sprintf(' | <a href="%s%d.%s">%d</a>',
			        $prefix, $i, $suffix, $i);
	    }
	    last REPLACESW;
	}

	if ($var eq 'PAGENUM') {
	    $tmp = $PageNum;
	    last REPLACESW;
	}
	if ($var eq 'NUMOFPAGES') {
	    $tmp = $NumOfPages;
	    last REPLACESW;
	}

	if ($var eq 'PG') {
	    my $num = $PageNum;
	    my $t = ($arg =~ s/^T//);
	    my $prefix = $t ? $TIDXPREFIX : $IDXPREFIX;
	    SW: {
		if ($arg eq 'NEXT')    { $num = $PageNum+1; last SW; }
		if ($arg eq 'PREV')    { $num = $PageNum-1; last SW; }
		if ($arg eq 'FIRST')   { $num = 0; last SW; }
		if ($arg eq 'LAST')    { $num = $NumOfPages; last SW; }
		if ($arg =~ /^-?\d+$/) { $num = $PageNum+$arg; last SW; }
	    }
	    if ($num < 2) {
		$tmp = $t ? $TIDXNAME : $IDXNAME;
	    } else {
		$num = $NumOfPages  if $num > $NumOfPages;
		$tmp = sprintf("%s%d.$HtmlExt", $prefix, $num);
	    }
	    $tmp .= ".gz"  if $GzipLinks;
	    last REPLACESW;
	}

	## -------------------------------- ##
	## Miscellaneous resource variables ##
	## -------------------------------- ##
    	if ($var eq 'DOCURL') {
	    $isurl = 0;
	    $tmp = $DOCURL;
	    last REPLACESW;
	}
	if ($var eq 'ENV') {
	    $tmp = htmlize($ENV{$arg});
	    last REPLACESW;
	}
    	if ($var eq 'GMTDATE') {
	    $tmp = &time2str($arg || $GMTDateFmt, time, 0);
	    last REPLACESW;
	}
    	if ($var eq 'HTMLEXT') {
	    $tmp = $HtmlExt;
	    last REPLACESW;
	}
	if ($var eq 'IDXPREFIX') {
	    $tmp = $IDXPREFIX;
	    last REPLACESW;
	}
    	if ($var eq 'LOCALDATE') {
	    $tmp = &time2str($arg || $LocalDateFmt, time, 1);
	    last REPLACESW;
	}
    	if ($var eq 'MSGPREFIX') {
	    $tmp = $MsgPrefix;
	    last REPLACESW;
	}
    	if ($var eq 'OUTDIR') {
	    $tmp = $OUTDIR;
	    last REPLACESW;
	}
    	if ($var eq 'PROG') {
	    $tmp = $PROG;
	    last REPLACESW;
	}
	if ($var eq 'TIDXPREFIX') {
	    $tmp = $TIDXPREFIX;
	    last REPLACESW;
	}
    	if ($var eq 'VERSION') {
	    $tmp = $VERSION;
	    last REPLACESW;
	}
    	if ($var eq '') {
	    $tmp = '$';
	    last REPLACESW;
	}

	## --------------------------- ##
	## User defined variable check ##
	## --------------------------- ##
	if (defined($CustomRcVars{$var})) {
	    $expand = 1;
	    $tmp = $CustomRcVars{$var};
	    last REPLACESW;
	}

	warn qq/Warning: Unrecognized variable: "$val"\n/;
	return "\$$val\$";
    }

    ##	Check if string needs to be expanded again
    if ($expand) {
	$tmp =~ s/$VarExp/&replace_li_var($1,$index)/geo;
    }

    ##	Check if URL text specifier is set
    if ($isurl) {
	$ret = &urlize($tmp);

    } else {
	if ($raw) {
	    $ret = &$MHeadCnvFunc($tmp);
	    if ($isaddr) {
		if ($NOMAILTO) {
		    $ret =~ s/($HAddrExp)/htmlize(rewrite_address($1))/geo;
		} else {
		    $ret =~ s/($HAddrExp)
			     /mailUrl($1, $Index2MsgId{$key},
					  $Subject{$key},
					  $From{$key})/gexo;
		}
	    }
	} else {
	    $ret = $tmp;
	}

	# Check for clipping
	if ($len > 0 && $canclip && (length($ret) > 0)) {
	    $ret = &$TextClipFunc($ret, $len, 1);
	}

	# Check if JavaScript string
	if ($jstr) {
	    $ret =~ s/\\/\\\\/g;	# escape backslashes
	    $ret =~ s/(["'])/\\$1/g;	# escape quotes
	    $ret =~ s/\n/\\n/g;		# escape newlines
	    $ret =~ s/\r/\\r/g;		# escape returns
	}
    }

    ##	Check for subject link
    $ret = qq|<a name="| .
	   &fmt_msgnum($IndexNum{$index}) .
	   qq|" href="| .
	   &msgnum_filename($IndexNum{$index}) .
	   qq|">$ret</a>|
	if $var eq 'SUBJECT' && $arg eq "";

    $ret;
}

##---------------------------------------------------------------------------##
##	compute_msg_pos(): Get message location data.
##	Return:
##	    ($aref,	: Reference to message listing array.
##	     $key,	: Message index key
##	     $pos,	: Integer offset location in $aref
##	     $opt)	: Left-over option string
##	$key will be undefined and $post will be set to -1 if message
##	position cannot be computed or is out-of-bounds.
##
sub compute_msg_pos {
    my($idx, $var, $arg, $usethread) = @_;
    my($ofs, $pos, $aref, $href, $key);
    my $opt  = undef;
    my $flip = 0;
    my $orgarg = $arg;

    ## Determine what list type
    if (($arg =~ s/^T//) || $usethread) {
	$aref = \@TListOrder;
	$href = \%Index2TLoc;
	$usethread = 1;
    } else {
	$aref = \@MListOrder;
	$href = \%Index2MLoc;
	$flip = $REVSORT;
    }

    ## Extract out optional data
    ($arg, $opt) = split(/;/, $arg, 2);

    SW: {
	if ($usethread && $TREVERSE) {
	    # when threads are listed in reverse, we preserve the
	    # sematics of "next/prev thread"
	    if ($arg eq 'NEXTTOP') {
		$arg = 'PREVTOP';
	    } elsif ($arg eq 'PREVTOP') {
		$arg = 'NEXTTOP';
	    }
	}

	$ofs =  0, last SW
	    if (!defined($arg)) || ($arg eq '') || ($arg eq 'CUR');
	$ofs = ($flip ? -$arg : $arg), last SW
	    if $arg =~ /^-?\d+$/;

	if ($arg eq 'NEXT') {		# next message
	    if (!$usethread || !$TREVERSE) {
	      $ofs = ($flip ? -1 : 1);
	      last SW;
	    }
	    # get here, it is thread and reverse
	    undef $ofs;
	    $pos = $href->{$idx};
	    if (($pos < $#$aref) && ($ThreadLevel{$aref->[$pos+1]} > 0)) {
		++$pos;
		last SW;
	    }
	    # get here, must goto physical previous top
	    # note no `last SW' statement
	    $arg = 'PREVTOP';
	}
	if ($arg eq 'PREV') {		# prev message
	    if (!$usethread || !$TREVERSE) {
	      $ofs = ($flip ? 1 : -1);
	      last SW;
	    }
	    # get here, it is thread and reverse
	    undef $ofs;
	    if ($ThreadLevel{$idx} > 0) {
		$pos = $href->{$idx};
		if (($pos > 0) && ($ThreadLevel{$aref->[$pos-1]} >= 0)) {
		    --$pos;
		    last SW;
		}
	    }
	    # get here, must goto physical next top
	    # note no `last SW' statement
	    $arg = 'NEXTTOP';
	}
	if ($arg eq 'FIRST') {
	    $pos = $flip ? $#$aref : 0;
	    undef $ofs;
	    last SW;
	}
	if ($arg eq 'LAST') {
	    $pos = $flip ? 0 : $#$aref;
	    undef $ofs;
	    last SW;
	}

	# if not thread variable, no more checking
	if (!$usethread) {
	    warn qq/Warning: $var: Invalid variable argument: "$orgarg"\n/;
	    $ofs = 0;
	    last SW;
	}

	if ($arg eq 'NEXTIN') {		# next message within a thread
	    $pos = $href->{$idx} + 1;
	    if ($pos > $#$aref || $ThreadLevel{$aref->[$pos]} <= 0) {
		$pos = -1;
	    }
	    undef $ofs;
	    last SW;
	}
	if ($arg eq 'PREVIN') {		# previous message within a thread
	    undef $ofs;
	    $pos = $href->{$idx};
	    if ($ThreadLevel{$aref->[$pos]} <= 0) {
		$pos = -1;
		last SW;
	    }
	    --$pos;
	    $pos = -1  if ($pos < 0);
	    last SW;
	}
	if ($arg eq 'PARENT') {		# parent message in thread
	    undef $ofs;
	    my $level = $ThreadLevel{$idx};
	    $pos = $Index2TLoc{$idx};
	    last SW  if ($level <= 0);
	    for (--$pos; $pos >= 0; --$pos) {
		last  if $ThreadLevel{$aref->[$pos]} < $level;
	    }
	    last SW;
	}
	if ($arg eq 'TOP') {
	    undef $ofs;
	    $pos = $Index2TLoc{$idx};
	    for (; $pos >= 0; --$pos) {
		last  if $ThreadLevel{$aref->[$pos]} <= 0;
	    }
	    last SW;
	}
	if (($arg eq 'NEXTTOP') ){	# start of next thread
	    undef $ofs;
	    $pos = $Index2TLoc{$idx};
	    for (++$pos; $pos <= $#$aref; ++$pos) {
		last  if $ThreadLevel{$aref->[$pos]} <= 0;
	    }
	    last SW;
	}
	if (($arg eq 'PREVTOP') ){	# start of previous thread
	    undef $ofs;
	    # Find current top first, then find previous top
	    for ($pos = $Index2TLoc{$idx}; $pos >= 0; --$pos) {
		last  if $ThreadLevel{$aref->[$pos]} <= 0;
	    }
	    if ($pos >= 0) {
		for (--$pos; $pos >= 0; --$pos) {
		    last  if $ThreadLevel{$aref->[$pos]} <= 0;
		}
	    }
	    last SW;
	}
	if ($arg eq 'END') {		# last message of thread
	    undef $ofs;
	    $pos = $Index2TLoc{$idx};
	    for (; $pos < $#$aref; ++$pos) {
		last  if $ThreadLevel{$aref->[$pos+1]} <= 0;
	    }
	    last SW;
	}

	warn qq/Warning: $var: Unrecognized variable argument: "$orgarg"\n/;
	$ofs = 0;
    }
    $pos = $href->{$idx} + $ofs  if defined($ofs);
    if (($pos > $#$aref) || ($pos < 0)) {
	$pos = -1;
	$key = undef;
    } else {
	$key = $aref->[$pos];
    }

    ($aref, $key, $pos, $opt);
}

##---------------------------------------------------------------------------##
1;
