##---------------------------------------------------------------------------##
##  File:
##	$Id: mhidxrc.pl,v 2.15 2003/03/31 17:53:47 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      MHonArc library defining values for various index resources
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1996-1999	Earl Hood, mhonarc@mhonarc.org
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

sub mhidxrc_set_vars {

##-----------------##
## Index resources ##
##-----------------##

$IdxTypeStr = $NOSORT ? 'Message' :
		        $SUBSORT ? 'Subject' :
			$AUTHSORT ? 'Author' :
			'Date';
## MAIN index resources
## if ($MAIN) {

    ##	Label for main index
    unless ($IDXLABEL) {
	$IDXLABEL = $IdxTypeStr . ' Index';
	$IsDefault{'IDXLABEL'} = 1;
    }

    ##	Beginning of main index page
    unless ($IDXPGBEG) {
	$IDXPGBEG =<<'EndOfStr';
<!doctype html public "-//W3C//DTD HTML//EN">
<html>
<head>
<title>$IDXTITLE$</title>
</head>
<body>
<h1>$IDXTITLE$</h1>
EndOfStr
	$IsDefault{'IDXPGBEG'} = 1;
    }

    ##	End of main index page
    unless ($IDXPGEND) {
	$IDXPGEND = "</body>\n</html>\n";
	$IsDefault{'IDXPGEND'} = 1;
    }

    ##	Beginning of main index list
    unless ($LIBEG) {
	$LIBEG  = '';
	$LIBEG .= "<ul>\n" .
		  '<li><a href="$TIDXFNAME$">$TIDXLABEL$</a></li>' .
		  "\n</ul>\n"  if $THREAD;
	$LIBEG .= '$PGLINK(PREV)$$PGLINK(NEXT)$' . "\n"  if $MULTIIDX;
	$LIBEG .= "<hr>\n<ul>\n";
	$IsDefault{'LIBEG'} = 1;
    }

    ## End of main index list
    unless ($LIEND) {
	$LIEND  = "</ul>\n";
	$IsDefault{'LIEND'} = 1;
    }

    ## Main index entry (start, content, and end)
    unless ($LITMPL) {
	$LITMPL = qq|<li><strong>\$SUBJECT\$</strong>\n| .
		  qq|<ul><li><em>From</em>: |;
	if ($SpamMode) {
	    $LITMPL .= q|$FROMNAME$|;
	} else {
	    $LITMPL .= q|$FROM$|;
	}
	$LITMPL .= qq|</li></ul>\n</li>\n|;
	$IsDefault{'LITMPL'} = 1;
    }

    ## Main list group resources
    unless ($AUTHBEG) {
	$AUTHBEG = ''; $IsDefault{'AUTHBEG'} = 1;
    }
    unless ($AUTHEND) {
	$AUTHEND = ''; $IsDefault{'AUTHEND'} = 1;
    }
    unless ($DAYBEG) {
	$DAYBEG = ''; $IsDefault{'DAYBEG'} = 1;
    }
    unless ($DAYEND) {
	$DAYEND = ''; $IsDefault{'DAYEND'} = 1;
    }
    unless ($SUBJECTBEG) {
	$SUBJECTBEG = ''; $IsDefault{'SUBJECTBEG'} = 1;
    }
    unless ($SUBJECTEND) {
	$SUBJECTEND = ''; $IsDefault{'SUBJECTEND'} = 1;
    }

## }

## THREAD index resources
## if ($THREAD) {

    ##	Label for thread index
    unless ($TIDXLABEL) {
	$TIDXLABEL = 'Thread Index';
	$IsDefault{'TIDXLABEL'} = 1;
    }

    ##	Beginning of thread index page
    unless ($TIDXPGBEG) {
	$TIDXPGBEG =<<'EndOfStr';
<!doctype html public "-//W3C//DTD HTML//EN">
<html>
<head>
<title>$TIDXTITLE$</title>
</head>
<body>
<h1>$TIDXTITLE$</h1>
EndOfStr
	$IsDefault{'TIDXPGBEG'} = 1;
    }
    ## End of thread index page
    unless ($TIDXPGEND) {
	$TIDXPGEND = "</body>\n</html>\n";
	$IsDefault{'TIDXPGEND'} = 1;
    }

    ## Head of thread index page (also contains list start markup)
    unless ($THEAD) {
	$THEAD  = '';
	$THEAD .= "<ul>\n" .
		  '<li><a href="$IDXFNAME$">$IDXLABEL$</a></li>' .
		  "\n</ul>\n"  if $MAIN;
	$THEAD .= '$PGLINK(TPREV)$$PGLINK(TNEXT)$' . "\n"  if $MULTIIDX;
	$THEAD .= "<hr>\n<ul>\n";
	$IsDefault{'THEAD'} = 1;
    }
    ## Foot of thread index page (also contains list end markup)
    unless ($TFOOT) {
	$TFOOT  = "</ul>\n";
	$IsDefault{'TFOOT'} = 1;
    }

    ## Template for thread entry with no follow-ups
    unless ($TSINGLETXT) {
	$TSINGLETXT =<<'EndOfStr';
<li><strong>$SUBJECT$</strong>,
<em>$FROMNAME$</em></li>
EndOfStr
	$IsDefault{'TSINGLETXT'} = 1;
    }

    ## Template for thread entry that is the start of a thread
    unless ($TTOPBEG) {
	$TTOPBEG =<<'EndOfStr';
<li><strong>$SUBJECT$</strong>,
<em>$FROMNAME$</em>
EndOfStr
	$IsDefault{'TTOPBEG'} = 1;
    }
    ## Template for end of a thread
    unless ($TTOPEND) {
	$TTOPEND = "</li>\n";
	$IsDefault{'TTOPEND'} = 1;
    }

    ## Template for the start of a sub-thread
    unless ($TSUBLISTBEG) {
	$TSUBLISTBEG  = "<ul>\n";
	$IsDefault{'TSUBLISTBEG'} = 1;
    }
    ## Template for the end of a sub-thread
    unless ($TSUBLISTEND) {
	$TSUBLISTEND  = "</ul>\n";
	$IsDefault{'TSUBLISTEND'} = 1;
    }

    ## Template for the start and content of a regular thread entry
    unless ($TLITXT) {
	$TLITXT =<<'EndOfStr';
<li><strong>$SUBJECT$</strong>,
<em>$FROMNAME$</em>
EndOfStr
	$IsDefault{'TLITXT'} = 1;
    }
    ## Template for end of a regular thread entry
    unless ($TLIEND) {
	$TLIEND = "</li>\n";
	$IsDefault{'TLIEND'} = 1;
    }

    ## Template for the start of subject based section
    unless ($TSUBJECTBEG) {
	$TSUBJECTBEG  = "<li>&lt;Possible follow-ups&gt;</li>\n";
	$IsDefault{'TSUBJECTBEG'} = 1;
    }
    ## Template for the end of subject based section
    unless ($TSUBJECTEND) {
	$TSUBJECTEND  = " ";
	$IsDefault{'TSUBJECTEND'} = 1;
    }

    ## Template for start and content of missing message in thread
    unless ($TLINONE) {
	$TLINONE = "<li><em>Message not available</em>";
	$IsDefault{'TLINONE'} = 1;
    }
    ## Template for end of missing message in thread
    unless ($TLINONEEND) {
	$TLINONEEND = "</li>\n";
	$IsDefault{'TLINONEEND'} = 1;
    }

    ## Template for opening an indent (for cross-page threads)
    unless ($TINDENTBEG) {
	$TINDENTBEG = "<ul>\n";
	$IsDefault{'TINDENTBEG'} = 1;
    }
    ## Template for closing an indent (for cross-page threads)
    unless ($TINDENTEND) {
	$TINDENTEND = "</ul>\n";
	$IsDefault{'TINDENTEND'} = 1;
    }

    ## Template for start of a continued thread (for cross-page threads)
    unless ($TCONTBEG) {
	$TCONTBEG = '<li><strong>$SUBJECTNA$</strong>, ' .
		    "<em>(continued)</em>\n";
	$IsDefault{'TCONTBEG'} = 1;
    }
    ## Template for end of a continued thread (for cross-page threads)
    unless ($TCONTEND) {
	$TCONTEND = "</li>\n";
	$IsDefault{'TCONTEND'} = 1;
    }

    $DoMissingMsgs = $TLINONE =~ /\S/;

## }

## Thread Slice Resources
unless ($TSLICEBEG) {
    $TSLICEBEG = "<blockquote><ul>\n";
    $IsDefault{'TSLICEBEG'} = 1;
}
unless ($TSLICEEND) {
    $TSLICEEND = "</ul></blockquote>\n";
    $IsDefault{'TSLICEEND'} = 1;
}

if ($TSLICELEVELS < 0) {
    $TSLICELEVELS = $TLEVELS;
    $IsDefault{'TSLICELEVELS'} = 1;
}

unless ($TSLICESINGLETXT) {
    $TSLICESINGLETXT = $TSINGLETXT;
    $IsDefault{'TSLICESINGLETXT'} = 1;
}
unless ($TSLICETOPBEG) {
    $TSLICETOPBEG = $TTOPBEG;
    $IsDefault{'TSLICETOPBEG'} = 1;
}
unless ($TSLICETOPEND) {
    $TSLICETOPEND = $TTOPEND;
    $IsDefault{'TSLICETOPEND'} = 1;
}
unless ($TSLICESUBLISTBEG) {
    $TSLICESUBLISTBEG = $TSUBLISTBEG;
    $IsDefault{'TSLICESUBLISTBEG'} = 1;
}
unless ($TSLICESUBLISTEND) {
    $TSLICESUBLISTEND = $TSUBLISTEND;
    $IsDefault{'TSLICESUBLISTEND'} = 1;
}
unless ($TSLICELITXT) {
    $TSLICELITXT = $TLITXT;
    $IsDefault{'TSLICELITXT'} = 1;
}
unless ($TSLICELIEND) {
    $TSLICELIEND = $TLIEND;
    $IsDefault{'TSLICELIEND'} = 1;
}
unless ($TSLICELINONE) {
    $TSLICELINONE = $TLINONE;
    $IsDefault{'TSLICELINONE'} = 1;
}
unless ($TSLICELINONEEND) {
    $TSLICELINONEEND = $TLINONEEND;
    $IsDefault{'TSLICELINONEEND'} = 1;
}
unless ($TSLICESUBJECTBEG) {
    $TSLICESUBJECTBEG = $TSUBJECTBEG;
    $IsDefault{'TSLICESUBJECTBEG'} = 1;
}
unless ($TSLICESUBJECTEND) {
    $TSLICESUBJECTEND = $TSUBJECTEND;
    $IsDefault{'TSLICESUBJECTEND'} = 1;
}
unless ($TSLICEINDENTBEG) {
    $TSLICEINDENTBEG = $TINDENTBEG;
    $IsDefault{'TSLICEINDENTBEG'} = 1;
}
unless ($TSLICEINDENTEND) {
    $TSLICEINDENTEND = $TINDENTEND;
    $IsDefault{'TSLICEINDENTEND'} = 1;
}
unless ($TSLICECONTBEG) {
    $TSLICECONTBEG = $TCONTBEG;
    $IsDefault{'TSLICECONTBEG'} = 1;
}
unless ($TSLICECONTEND) {
    $TSLICECONTEND = $TCONTEND;
    $IsDefault{'TSLICECONTEND'} = 1;
}

unless ($TSLICESINGLETXTCUR) {
    $TSLICESINGLETXTCUR = $TSLICESINGLETXT;
    $IsDefault{'TSLICESINGLETXTCUR'} = 1;
}
unless ($TSLICETOPBEGCUR) {
    $TSLICETOPBEGCUR = $TSLICETOPBEG;
    $IsDefault{'TSLICETOPBEGCUR'} = 1;
}
unless ($TSLICETOPENDCUR) {
    $TSLICETOPENDCUR = $TSLICETOPEND;
    $IsDefault{'TSLICETOPENDCUR'} = 1;
}
unless ($TSLICELITXTCUR) {
    $TSLICELITXTCUR = $TSLICELITXT;
    $IsDefault{'TSLICELITXTCUR'} = 1;
}
unless ($TSLICELIENDCUR) {
    $TSLICELIENDCUR = $TSLICELIEND;
    $IsDefault{'TSLICELIENDCUR'} = 1;
}

##-------------------##
## Message resources ##
##-------------------##

unless (@DateFields) {
    @DateFields  = ('received', 'date');
    @_DateFields = ( ['received',0], ['date',0] );
    $IsDefault{'DATEFIELDS'} = 1;
} else {
    local($_);
    my $f;
    foreach (@DateFields) {
	s/\s//g;  tr/A-Z/a-z/;
	$f = $_;
	if ($f =~ s/\[(\d+)\]//) {
	    push(@_DateFields, [ $f, $1 ]);
	} else {
	    push(@_DateFields, [ $f, 0 ]);
	}
    }
}
unless (@FromFields) {
    @FromFields = ('from', 'mail-reply-to', 'reply-to', 'return-path',
		   'apparently-from', 'sender', 'resent-sender');
    $IsDefault{'FROMFIELDS'} = 1;
}

## Beginning of message page
unless ($MSGPGBEG) {
    $MSGPGBEG =<<'EndOfStr';
<!doctype html public "-//W3C//DTD HTML//EN">
<html>
<head>
<title>$SUBJECTNA$</title>
EndOfStr
    
    $MSGPGBEG .= qq|<link rev="made" href="mailto:\$FROMADDR\$">\n|
		 unless $SpamMode;
    $MSGPGBEG .= "</head>\n<body>\n";
    $IsDefault{'MSGPGBEG'} = 1;
}

## End of message page
unless ($MSGPGEND) {
    $MSGPGEND = "</body>\n</html>\n";
    $IsDefault{'MSGPGEND'} = 1;
}

## Subject header
unless ($SUBJECTHEADER) {
    $SUBJECTHEADER = '<h1>$SUBJECTNA$</h1>' . "\n<hr>\n";
    $IsDefault{'SUBJECTHEADER'} = 1;
}

## Separator between message data head and message data body
unless ($HEADBODYSEP) {
    $HEADBODYSEP = "<hr>\n";
    $IsDefault{'HEADBODYSEP'} = 1;
}

## Separator between end of message data and rest of page
unless ($MSGBODYEND) {
    $MSGBODYEND = "<hr>\n";
    $IsDefault{'MSGBODYEND'} = 1;
}

##---------------------------------##
## Mail header formating resources ##
##---------------------------------##

$FIELDSBEG = "<ul>\n",	$IsDefault{'FIELDSBEG'} = 1	unless $FIELDSBEG;
$FIELDSEND = "</ul>\n",	$IsDefault{'FIELDSEND'} = 1	unless $FIELDSEND;
$LABELBEG = "<li>",	$IsDefault{'LABELBEG'} = 1  	unless $LABELBEG;
$LABELEND = ":",	$IsDefault{'LABELEND'} = 1	unless $LABELEND;
$FLDBEG  = " ", 	$IsDefault{'FLDBEG'} = 1	unless $FLDBEG;
$FLDEND  = "</li>",	$IsDefault{'FLDEND'} = 1    	unless $FLDEND;

##-----------------------------------##
##  Next/prev message link resources ##
##-----------------------------------##

## Next/prev buttons
$NEXTBUTTON = '[<a href="$MSG(NEXT)$">'.$IdxTypeStr.' Next</a>]',
    $IsDefault{'NEXTBUTTON'} = 1	unless $NEXTBUTTON;
$PREVBUTTON = '[<a href="$MSG(PREV)$">'.$IdxTypeStr.' Prev</a>]',
    $IsDefault{'PREVBUTTON'} = 1	unless $PREVBUTTON;
$NEXTBUTTONIA = "[$IdxTypeStr Next]",
    $IsDefault{'NEXTBUTTONIA'} = 1	unless $NEXTBUTTONIA;
$PREVBUTTONIA = "[$IdxTypeStr Prev]",
    $IsDefault{'PREVBUTTONIA'} = 1	unless $PREVBUTTONIA;

## Next message link
unless ($NEXTLINK) {
    $NEXTLINK =<<EndOfStr;
<li>Next by $IdxTypeStr:
<strong><a href="\$MSG(NEXT)\$">\$SUBJECT(NEXT)\$</a></strong>
</li>
EndOfStr
    $IsDefault{'NEXTLINK'} = 1;
}

## Inactive next message link
$NEXTLINKIA = '', $IsDefault{'NEXTLINKIA'} = 1	unless $NEXTLINKIA;

## Previous message link
unless ($PREVLINK) {
    $PREVLINK =<<EndOfStr;
<li>Prev by $IdxTypeStr:
<strong><a href="\$MSG(PREV)\$">\$SUBJECT(PREV)\$</a></strong>
</li>
EndOfStr
    $IsDefault{'PREVLINK'} = 1;
}

## Inactive previous message link
$PREVLINKIA = '', $IsDefault{'PREVLINKIA'} = 1  unless $PREVLINKIA;

## Thread next/previous buttons
$TNEXTBUTTON = '[<a href="$MSG(TNEXT)$">Thread Next</a>]',
    $IsDefault{'TNEXTBUTTON'} = 1	unless $TNEXTBUTTON;
$TPREVBUTTON = '[<a href="$MSG(TPREV)$">Thread Prev</a>]',
    $IsDefault{'TPREVBUTTON'} = 1	unless $TPREVBUTTON;
$TNEXTBUTTONIA = '[Thread Next]',
    $IsDefault{'TNEXTBUTTONIA'} = 1	unless $TNEXTBUTTONIA;
$TPREVBUTTONIA = '[Thread Prev]',
    $IsDefault{'TPREVBUTTONIA'} = 1	unless $TPREVBUTTONIA;

$TNEXTINBUTTON = '[<a href="$MSG(TNEXTIN)$">Next in Thread</a>]',
    $IsDefault{'TNEXTINBUTTON'} = 1	unless $TNEXTINBUTTON;
$TNEXTINBUTTONIA = '[Next in Thread]',
    $IsDefault{'TNEXTINBUTTONIA'} = 1	unless $TNEXTINBUTTONIA;
$TPREVINBUTTON = '[<a href="$MSG(TPREVIN)$">Prev in Thread</a>]',
    $IsDefault{'TPREVINBUTTON'} = 1	unless $TPREVINBUTTON;
$TPREVINBUTTONIA = '[Prev in Thread]',
    $IsDefault{'TPREVINBUTTONIA'} = 1	unless $TPREVINBUTTONIA;

$TNEXTTOPBUTTON = '[<a href="$MSG(TNEXTTOP)$">Next Thread</a>]',
    $IsDefault{'TNEXTTOPBUTTON'} = 1	unless $TNEXTTOPBUTTON;
$TNEXTTOPBUTTONIA = '[Next Thread]',
    $IsDefault{'TNEXTTOPBUTTONIA'} = 1	unless $TNEXTTOPBUTTONIA;
$TPREVTOPBUTTON = '[<a href="$MSG(TPREVTOP)$">Prev Thread</a>]',
    $IsDefault{'TPREVTOPBUTTON'} = 1	unless $TPREVTOPBUTTON;
$TPREVTOPBUTTONIA = '[Prev Thread]',
    $IsDefault{'TPREVTOPBUTTONIA'} = 1	unless $TPREVTOPBUTTONIA;

$TTOPBUTTON = '[<a href="$MSG(TTOP)$">First in Thread</a>]',
    $IsDefault{'TTOPBUTTON'} = 1	unless $TTOPBUTTON;
$TTOPBUTTONIA = '[First in Thread]',
    $IsDefault{'TTOPBUTTONIA'} = 1	unless $TTOPBUTTONIA;
$TENDBUTTON = '[<a href="$MSG(TEND)$">Last in Thread</a>]',
    $IsDefault{'TENDBUTTON'} = 1	unless $TENDBUTTON;
$TENDBUTTONIA = '[Last in Thread]',
    $IsDefault{'TENDBUTTONIA'} = 1	unless $TENDBUTTONIA;

## Next message by thread link
unless ($TNEXTLINK) {
    $TNEXTLINK =<<'EndOfStr';
<li>Next by thread:
<strong><a href="$MSG(TNEXT)$">$SUBJECT(TNEXT)$</a></strong>
</li>
EndOfStr
    $IsDefault{'TNEXTLINK'} = 1;
}
## Inactive next message in thread link
$TNEXTLINKIA = '', $IsDefault{'TNEXTLINKIA'} = 1  unless $TNEXTLINKIA;

## Previous message by thread link
unless ($TPREVLINK) {
    $TPREVLINK =<<'EndOfStr';
<li>Previous by thread:
<strong><a href="$MSG(TPREV)$">$SUBJECT(TPREV)$</a></strong>
</li>
EndOfStr
    $IsDefault{'TPREVLINK'} = 1;
}
## Inactive previous message in thread link
$TPREVLINKIA = '', $IsDefault{'TPREVLINKIA'} = 1  unless $TPREVLINKIA;

## Next message within thread link
unless ($TNEXTINLINK) {
    $TNEXTINLINK =<<'EndOfStr';
<li>Next in thread:
<strong><a href="$MSG(TNEXTIN)$">$SUBJECT(TNEXTIN)$</a></strong>
</li>
EndOfStr
    $IsDefault{'TNEXTINLINK'} = 1;
}
## Inactive next message within thread link
$TNEXTINLINKIA = '', $IsDefault{'TNEXTINLINKIA'} = 1  unless $TNEXTINLINKIA;

## Previous message within thread link
unless ($TPREVINLINK) {
    $TPREVINLINK =<<'EndOfStr';
<li>Previous in thread:
<strong><a href="$MSG(TPREVIN)$">$SUBJECT(TPREVIN)$</a></strong>
</li>
EndOfStr
    $IsDefault{'TPREVINLINK'} = 1;
}
## Inactive previous message within thread link
$TPREVINLINKIA = '', $IsDefault{'TPREVINLINKIA'} = 1  unless $TPREVINLINKIA;

## Next thread
unless ($TNEXTTOPLINK) {
    $TNEXTTOPLINK =<<'EndOfStr';
<li>Next thread:
<strong><a href="$MSG(TNEXTTOP)$">$SUBJECT(TNEXTTOP)$</a></strong>
</li>
EndOfStr
    $IsDefault{'TNEXTTOPLINK'} = 1;
}
## Inactive next thread
$TNEXTTOPLINKIA = '', $IsDefault{'TNEXTTOPLINKIA'} = 1  unless $TNEXTTOPLINKIA;

## Previous thread
unless ($TPREVTOPLINK) {
    $TPREVTOPLINK =<<'EndOfStr';
<li>Previous thread:
<strong><a href="$MSG(TPREVTOP)$">$SUBJECT(TPREVTOP)$</a></strong>
</li>
EndOfStr
    $IsDefault{'TPREVTOPLINK'} = 1;
}
## Inactive prev thread
$TPREVTOPLINKIA = '', $IsDefault{'TPREVTOPLINKIA'} = 1  unless $TPREVTOPLINKIA;

## First in thread
unless ($TTOPLINK) {
    $TTOPLINK =<<'EndOfStr';
<li>First in thread:
<strong><a href="$MSG(TTOP)$">$SUBJECT(TTOP)$</a></strong>
</li>
EndOfStr
    $IsDefault{'TTOPLINK'} = 1;
}
## Inactive first in thread
$TTOPLINKIA = '', $IsDefault{'TTOPLINKIA'} = 1  unless $TTOPLINKIA;

## Last in thread
unless ($TENDLINK) {
    $TENDLINK =<<'EndOfStr';
<li>Last in thread:
<strong><a href="$MSG(TEND)$">$SUBJECT(TEND)$</a></strong>
</li>
EndOfStr
    $IsDefault{'TENDLINK'} = 1;
}
## Inactive last in thread
$TENDLINKIA = '', $IsDefault{'TENDLINKIA'} = 1  unless $TENDLINKIA;

## Top links in message
if (!$TOPLINKS) {
    $TOPLINKS  = "<hr>\n";
    $TOPLINKS .= '$BUTTON(PREV)$$BUTTON(NEXT)$'
	if $MAIN;
    $TOPLINKS .= '$BUTTON(TPREV)$$BUTTON(TNEXT)$'
	if $THREAD;
    $TOPLINKS .= '[<a href="$IDXFNAME$#$MSGNUM$">$IDXLABEL$</a>]'
	if $MAIN;
    $TOPLINKS .= '[<a href="$TIDXFNAME$#$MSGNUM$">$TIDXLABEL$</a>]'
	if $THREAD;
    $IsDefault{'TOPLINKS'} = 1;
}

## Bottom links in message
if (!$BOTLINKS) {
    $BOTLINKS =  "<ul>\n";
    $BOTLINKS .= '$LINK(PREV)$$LINK(NEXT)$'  if $MAIN;
    $BOTLINKS .= '$LINK(TPREV)$$LINK(TNEXT)$'  if $THREAD;
    if ($MAIN || $THREAD) {
	$BOTLINKS .= "<li>Index(es):\n<ul>\n";
	$BOTLINKS .= '<li><a href="$IDXFNAME$#$MSGNUM$">' .
		     "<strong>$IdxTypeStr</strong></a></li>\n"  if $MAIN;
	$BOTLINKS .= '<li><a href="$TIDXFNAME$#$MSGNUM$">' .
		     "<strong>Thread</strong></a></li>\n"  if $THREAD;
    }
    $BOTLINKS .= "</ul>\n</li>\n</ul>\n";
    $IsDefault{'BOTLINKS'} = 1;
}

## Follow-up and References resources
unless ($FOLUPBEGIN) {
    $FOLUPBEGIN =<<'EndOfVar';
<ul><li><strong>Follow-Ups</strong>:
<ul>
EndOfVar
    $IsDefault{'FOLUPBEGIN'} = 1;
}
unless ($FOLUPLITXT) {
    if ($SpamMode) {
	$FOLUPLITXT =<<'EndOfVar';
<li><strong>$SUBJECT$</strong>
<ul><li><em>From:</em> $FROMNAME$</li></ul></li>
EndOfVar
    } else {
	$FOLUPLITXT =<<'EndOfVar';
<li><strong>$SUBJECT$</strong>
<ul><li><em>From:</em> $FROM$</li></ul></li>
EndOfVar
    }
    $IsDefault{'FOLUPLITXT'} = 1;
}
unless ($FOLUPEND) {
    $FOLUPEND =<<'EndOfVar';
</ul></li></ul>
EndOfVar
    $IsDefault{'FOLUPEND'} = 1;
}

unless ($REFSBEGIN) {
    $REFSBEGIN =<<'EndOfVar';
<ul><li><strong>References</strong>:
<ul>
EndOfVar
    $IsDefault{'REFSBEGIN'} = 1;
}
unless ($REFSLITXT) {
    if ($SpamMode) {
    $REFSLITXT =<<'EndOfVar';
<li><strong>$SUBJECT$</strong>
<ul><li><em>From:</em> $FROMNAME$</li></ul></li>
EndOfVar
    } else {
	$REFSLITXT =<<'EndOfVar';
<li><strong>$SUBJECT$</strong>
<ul><li><em>From:</em> $FROM$</li></ul></li>
EndOfVar
    }
    $IsDefault{'REFSLITXT'} = 1;
}
unless ($REFSEND) {
    $REFSEND =<<'EndOfVar';
</ul></li></ul>
EndOfVar
    $IsDefault{'REFSEND'} = 1;
}

##--------------------------------------------##
## Next/previous main/thread index page links ##
##--------------------------------------------##

$FIRSTPGLINK = '[<a href="$PG(FIRST)$">First Page</a>]',
    $IsDefault{'FIRSTPGLINK'} = 1	unless $FIRSTPGLINK;
$LASTPGLINK  = '[<a href="$PG(LAST)$">Last Page</a>]',
    $IsDefault{'LASTPGLINK'} = 1	unless $LASTPGLINK;
$NEXTPGLINK  = '[<a href="$PG(NEXT)$">Next Page</a>]',
    $IsDefault{'NEXTPGLINK'} = 1	unless $NEXTPGLINK;
$PREVPGLINK  = '[<a href="$PG(PREV)$">Prev Page</a>]',
    $IsDefault{'PREVPGLINK'} = 1	unless $PREVPGLINK;

$TFIRSTPGLINK = '[<a href="$PG(TFIRST)$">First Page</a>]',
    $IsDefault{'TFIRSTPGLINK'} = 1	unless $TFIRSTPGLINK;
$TLASTPGLINK  = '[<a href="$PG(TLAST)$">Last Page</a>]',
    $IsDefault{'TLASTPGLINK'} = 1	unless $TLASTPGLINK;
$TNEXTPGLINK  = '[<a href="$PG(TNEXT)$">Next Page</a>]',
    $IsDefault{'TNEXTPGLINK'} = 1	unless $TNEXTPGLINK;
$TPREVPGLINK  = '[<a href="$PG(TPREV)$">Prev Page</a>]',
    $IsDefault{'TPREVPGLINK'} = 1	unless $TPREVPGLINK;

$NEXTPGLINKIA  = '[Next Page]',
    $IsDefault{'NEXTPGLINKIA'} = 1	unless $NEXTPGLINKIA;
$PREVPGLINKIA  = '[Prev Page]',
    $IsDefault{'PREVPGLINKIA'} = 1	unless $PREVPGLINKIA;
$TNEXTPGLINKIA = '[Next Page]',
    $IsDefault{'TNEXTPGLINKIA'} = 1	unless $TNEXTPGLINKIA;
$TPREVPGLINKIA = '[Prev Page]',
    $IsDefault{'TPREVPGLINKIA'} = 1	unless $TPREVPGLINKIA;

##---------------##
## Miscellaneous ##
##---------------##

$MSGIDLINK = '<a $A_HREF$>$MSGID$</a>',
     $IsDefault{'MSGIDLINK'} = 1	unless $MSGIDLINK;

$NOTE	    = '$NOTETEXT$',
     $IsDefault{'NOTE'} = 1		unless $NOTE;
$NOTEIA	    = '',
     $IsDefault{'NOTEIA'} = 1		unless $NOTEIA;
$NOTEICON   = '',
     $IsDefault{'NOTEICON'} = 1		unless $NOTEICON;
$NOTEICONIA = '',
     $IsDefault{'NOTEICONIA'} = 1	unless $NOTEICONIA;

##	Set unknown icon
$Icons{'unknown'} = $Icons{'text/plain'}  unless $Icons{'unknown'};

##
if ($AddressModify eq "") {
    $AddressModify =
	q{s|([\!\%\w\.\-+=/]+@)([\w\-]+\.[\w\.\-]+)|$1.('x' x length($2))|ge}
	if $SpamMode;
    $IsDefault{'AddressModify'} = 1;
}

if ($MAILTOURL eq "") {
    if ($SpamMode) {
	$MAILTOURL = 'mailto:$TOADDRNAME$@DOMAIN.HIDDEN';
    } else {
	$MAILTOURL = 'mailto:$TO$';
    }
    $IsDefault{'MAILTOURL'} = 1;
}

if (!defined($AddrModifyBodies)) {
    $AddrModifyBodies  = 1  if $SpamMode;
}

}

##---------------------------------------------------------------------------##
1;
