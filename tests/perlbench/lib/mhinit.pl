##---------------------------------------------------------------------------##
##  File:
##	$Id: mhinit.pl,v 2.48 2003/08/02 06:15:37 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      Initialization stuff for MHonArc.
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

##---------------------------------------------------------------------------##
##  Callbacks
##	We only declare once so custom front-ends do not have to
##	re-register each time.  This basically serves as a summary
##	of the callbacks available.
##---------------------------------------------------------------------------##

## After message body is read and converted:
##	&invoke($fields_hash_ref, $html_text_ref, $files_array_ref);
$CBMessageBodyRead = undef
    unless defined($CBMessageBodyRead);

## Right before database file is loaded:
##	$do_load = &invoke($pathname);
$CBDbPreLoad = undef
    unless defined($CBDbPreLoad);

## Right before database file is written:
##	$do_save = &invoke($pathname, $tmp_pathname);
$CBDbPreSave = undef
    unless defined($CBDbPreSave);

## When data has been written:
##	$do_save = &invoke($db_fh);
$CBDbSave = undef
    unless defined($CBDbSave);

## After message header is parsed:
##	$do_not_exclude = &invoke($fields_hash_ref, $raw_header_txt);
$CBMessageHeadRead = undef
    unless defined($CBMessageHeadRead);

## After message body is read from input
##	&invoke($fields_hash_ref, $raw_data_ref);
$CBRawMessageBodyRead = undef
    unless defined($CBRawMessageBodyRead);

## When a resource variable is being expanded:
##	($result, $recurse, $canclip) = &invoke($index, $varname, $arg);
$CBRcVarExpand = undef
    unless defined($CBRcVarExpand);

##---------------------------------------------------------------------------##

sub mhinit_vars {

# A couple of file-avoidance variables for CPU2006
%mhonarc_locks = ();
#%mhonarc_files = ();          # This shouldn't be cleared here because the
                               # caller will modify it.

##	The %Zone array should be augmented to contain all timezone
##	specifications with the positive/negative hour offset from UTC
##	(GMT).  The zone value is *added* to the time containing the
##	zone to determine GMT time.  Hence, the values will be the
##	negative inverse used in actual time specifications in messages.
##	(There has got to be a better way to handle timezones)
##	Array can be augmented/overridden via the resource file.
%Zone = (
    'ACDT', '-1030',	# Australian Central Daylight
    'ACST', '-0930',	# Australian Central Standard
    'ADT',   '0300',	# (US) Atlantic Daylight
    'AEDT', '-1100',	# Australian East Daylight
    'AEST', '-1000',	# Australian East Standard
    'AHDT',  '0900',
    'AHST',  '1000',	
    'AST',   '0400',	# (US) Atlantic Standard
    'AT',    '0200',	# Azores
    'AWDT', '-0900',	# Australian West Daylight
    'AWST', '-0800',	# Australian West Standard
    'BAT',  '-0300',	# Baghdad
    'BDST', '-0200',	# British Double Summer
    'BET',   '1100',	# Bering Standard
    'BST',  '-0100',	# British Summer
#   'BST',   '0300',	# Brazil Standard
    'BT',   '-0300',	# Baghdad
    'BZT2',  '0300',	# Brazil Zone 2
    'CADT', '-1030',	# Central Australian Daylight
    'CAST', '-0930',	# Central Australian Standard
    'CAT',   '1000',	# Central Alaska
    'CCT',  '-0800',	# China Coast
    'CDT',   '0500',	# (US) Central Daylight
    'CED',  '-0200',	# Central European Daylight
    'CET',  '-0100',	# Central European
    'CST',   '0600',	# (US) Central Standard
    'EAST', '-1000',	# Eastern Australian Standard
    'EDT',   '0400',	# (US) Eastern Daylight
    'EED',  '-0300',	# Eastern European Daylight
    'EET',  '-0200',	# Eastern Europe
    'EEST', '-0300',	# Eastern Europe Summer
    'EST',   '0500',	# (US) Eastern Standard
    'FST',  '-0200',	# French Summer
    'FWT',  '-0100',	# French Winter
    'GMT',   '0000',	# Greenwich Mean
    'GST',  '-1000',	# Guam Standard
#   'GST',   '0300',	# Greenland Standard
    'HDT',   '0900',	# Hawaii Daylight
    'HST',   '1000',	# Hawaii Standard
    'IDLE', '-1200',	# Internation Date Line East
    'IDLW',  '1200',	# Internation Date Line West
    'IST',  '-0530',	# Indian Standard
    'IT',   '-0330',	# Iran
    'JST',  '-0900',	# Japan Standard
    'JT',   '-0700',	# Java
    'KST',  '-0900',	# Korean Standard
    'MDT',   '0600',	# (US) Mountain Daylight
    'MED',  '-0200',	# Middle European Daylight
    'MET',  '-0100',	# Middle European
    'MEST', '-0200',	# Middle European Summer
    'MEWT', '-0100',	# Middle European Winter
    'MST',   '0700',	# (US) Mountain Standard
    'MT',   '-0800',	# Moluccas
    'NDT',   '0230',	# Newfoundland Daylight
    'NFT',   '0330',	# Newfoundland
    'NT',    '1100',	# Nome
    'NST',  '-0630',	# North Sumatra
#   'NST',   '0330',	# Newfoundland Standard
    'NZ',   '-1100',	# New Zealand
    'NZST', '-1200',	# New Zealand Standard
    'NZDT', '-1300',	# New Zealand Daylight
    'NZT',  '-1200',	# New Zealand
    'PDT',   '0700',	# (US) Pacific Daylight
    'PST',   '0800',	# (US) Pacific Standard
    'ROK',  '-0900',	# Republic of Korea
    'SAD',  '-1000',	# South Australia Daylight
    'SAST', '-0900',	# South Australia Standard
    'SAT',  '-0900',	# South Australia
    'SDT',  '-1000',	# South Australia Daylight
    'SST',  '-0200',	# Swedish Summer
    'SWT',  '-0100',	# Swedish Winter
    'USZ3', '-0400',	# USSR Zone 3
    'USZ4', '-0500',	# USSR Zone 4
    'USZ5', '-0600',	# USSR Zone 5
    'USZ6', '-0700',	# USSR Zone 6
    'UT',    '0000',	# Universal Coordinated
    'UTC',   '0000',	# Universal Coordinated
    'UZ10', '-1100',	# USSR Zone 10
    'WAT',   '0100',	# West Africa
    'WET',   '0000',	# West European
    'WST',  '-0800',	# West Australian Standard
    'YDT',   '0800',	# Yukon Daylight
    'YST',   '0900',	# Yukon Standard
    'ZP4',  '-0400',	# USSR Zone 3
    'ZP5',  '-0500',	# USSR Zone 4
    'ZP6',  '-0600',	# USSR Zone 5
);
%ZoneUD = ();

##	Assoc array listing mail header fields to exclude in output.
##	Each key is treated as a regular expression with '^' prepended
##	to it.

%HFieldsExc = (
    'content-', 1,		# Mime headers
    'errors-to', 1,
    'forward', 1,		# Forward lines (MH may add these)
    'lines', 1,
    'message-id', 1,
    'mime-', 1, 		# Mime headers
    'nntp-', 1,
    'originator', 1,
    'path', 1,
    'precedence', 1,
    'received', 1,		# MTA added headers
    'replied', 1,		# Replied lines (MH may add these)
    'return-path', 1,   	# MH/MTA header
    'status', 1,
    'via', 1,
    'x-', 1,    		# Non-standard headers
);

##	Hash defining HTML formats to apply to header fields
%HeadFields = (		# Nothing
    "-default-", "",
);
%HeadHeads = (		# Empasize field labels
    "-default-", "em",
);
@FieldOrder = (		# Order fields are listed
    'to',
    'subject',
    'from',
    'date',
    '-extra-',
);
%FieldODefs = (		# Fields not to slurp up in "-extra-"
    'to', 1,
    'subject', 1,
    'from', 1,
    'date', 1,
);

##	Extra header fields to store
@ExtraHFields = ();
%ExtraHFields = ();

##	Message information variables

$NewMsgCnt	=  0;	# Total number of new messages
$NumOfMsgs	=  0;	# Total number of messages
$LastMsgNum	= -1;	# Message number of last message
%Message  	= ();	# Message indexes to bodies
%MsgHead  	= ();	# Message indexes to heads
%MsgHtml  	= ();	# Flag if message is html
%Subject  	= ();	# Message indexes to subjects
%From   	= ();	# Message indexes to froms
%Date   	= ();	# Message indexes to dates
%MsgId  	= ();	# Message ids to indexes
%NewMsgId  	= ();	# New message ids to indexes
%IndexNum 	= ();	# Index key to message number
%Derived  	= ();	# Index key to derived files for message
%Refs   	= ();	# Index key to message references
%Follow  	= ();	# Index key to follow-ups
%FolCnt   	= ();	# Index key to number of follow-ups
%ContentType	= ();	# Index key to base content-type of message
%Icons    	= ();	# Index key to icon URL for content-type
%AddIndex 	= ();	# Flags for messages that must be written

@MListOrder	= ();	# List of indexes in order printed on main index
%Index2Mloc	= ();	# Map index to position in main index
@TListOrder	= ();	# List of indexes in order printed on thread index
%Index2Tloc	= ();	# Map index to position in thread index
%ThreadLevel	= ();	# Map index to thread level

%UDerivedFile	= ();	# Key = filename template.  Value = content template

##	Following variables used in thread computation

@ThreadList	= ();	# List of messages visible in thread index
@NotIdxThreadList
		= ();	# List of messages not visible in index
%HasRef		= ();	# Flags if message has references (Keys = indexes)
			# 	(Values = reference message indexes)
%HasRefDepth	= ();	# Depth of reference from HasRef value
%Replies	= ();	# Msg-ids of explicit replies (Keys = indexes)
%SReplies	= ();	# Msg-ids of subject-based replies (Keys = indexes)
%TVisible	= ();	# Message visible in thread index (Keys = indexes)
$DoMissingMsgs	=  0;	# Flag is missing messages should be noted in index

##	Some miscellaneous variables

%IsDefault	= ();	# Flags if certain resources are the default

$bs 		= "\b";	# Used as a separator
$Url 		= '(http://|https://|ftp://|afs://|wais://|telnet://|' .
		   'gopher://|news:|nntp:|mid:|cid:|mailto:|prospero:)';

$MLCP		= 0;	# Main index contains included files flag
$SLOW		= 0;	# Save memory flag
$NumOfPages	= 0;	# Number of index pages
$IdxMinPg	= -1;	# Starting page of index for updating
$TIdxMinPg	= -1;	# Starting page of thread index for updating
$IdxPageNum	= 0;	# Page to output if genidx
$DBPathName	= '';	# Full pathname of database file

##  Variable to hold function for converting message header text.
$MHeadCnvFunc	= "mhonarc::htmlize";

##  Regexp for variable detection
$VarExp    = $ENV{'M2H_VARREGEX'};
$VarExp    = '\$([^\$]*)\$'  if !defined($VarExp) || $VarExp !~ /\S/;

##  Regexp for address/msg-id detection (looks like cussing in cartoons)
$AddrExp  = '[^()<>@,;:\/\s"\'&|]+@[^()<>@,;:\/\s"\'&|]+';
$HAddrExp = '[^()<>@,;:\/\s"\'&|]+(?:@|&\#[xX]0*40;|&64;)[^()<>@,;:\/\s"\'&|]+';

##  Text clipping function and source file: Set in mhopt.pl.
$TextClipFunc	= undef;
$TextClipSrc	= undef;

##	Grab environment variable settings
##
$AFS	   = $ENV{'M2H_AFS'}        || 0;
$ANNOTATE  = $ENV{'M2H_ANNOTATE'}   || 0;
$DBFILE    = $ENV{'M2H_DBFILE'}     || 
	     (($MSDOS || $VMS) ? "mhonarc.db": ".mhonarc.db");
$DOCURL    = $ENV{'M2H_DOCURL'}     ||
	     'http://www.mhonarc.org/';
$IDXNAME   = "";	# Set in get_resources()
$IDXPREFIX = $ENV{'M2H_IDXPREFIX'}  || "mail";
$TIDXPREFIX= $ENV{'M2H_TIDXPREFIX'} || "thrd";
$IDXSIZE   = $ENV{'M2H_IDXSIZE'}    || 0;
$TIDXNAME  = "";	# Set in get_resources()
$OUTDIR    = $ENV{'M2H_OUTDIR'}     || $CURDIR;
$TTITLE    = $ENV{'M2H_TTITLE'}     || "Mail Thread Index";
$TITLE     = $ENV{'M2H_TITLE'}      || "Mail Index";
$MAILTOURL = $ENV{'M2H_MAILTOURL'}  || "";
$FROM      = $ENV{'M2H_MSGSEP'}     || '^From ';
$LOCKFILE  = $ENV{'M2H_LOCKFILE'}   ||
	     ($MSDOS ? "mhonarc.lck" :
		$VMS ? "mhonarc_lck" : ".mhonarc.lck");
$LOCKTRIES = $ENV{'M2H_LOCKTRIES'}  || 10;
$LOCKDELAY = $ENV{'M2H_LOCKDELAY'}  || 3;
$MAXSIZE   = $ENV{'M2H_MAXSIZE'}    || 0;
$TLEVELS   = $ENV{'M2H_TLEVELS'}    || 3;
$TSLICELEVELS =
	     $ENV{'M2H_TSLICELEVELS'} || -1;
$MHPATTERN = $ENV{'M2H_MHPATTERN'}  || '^\d+$';
$DefRcFile = $ENV{'M2H_DEFRCFILE'}  || '';
$HtmlExt   = $ENV{'M2H_HTMLEXT'}    || "html";
$MsgPrefix = $ENV{'M2H_MSGPREFIX'}  || "msg";
$DefRcName = $ENV{'M2H_DEFRCNAME'}  ||
	     (($MSDOS || $VMS) ? "mhonarc.mrc": ".mhonarc.mrc");
$GzipExe   = $ENV{'M2H_GZIPEXE'}    || 'gzip';
$SpamMode  = $ENV{'M2H_SPAMMODE'}   || 0;
$MainRcDir = undef;	# Set in read_resource_file()

$GMTDateFmt	= $ENV{'M2H_GMTDATEFMT'}   	|| '';
$LocalDateFmt	= $ENV{'M2H_LOCALDATEFMT'} 	|| '';
$ExpireDate	= $ENV{'M2H_EXPIREDATE'}   	|| '';
$ExpireDateTime = 0;
$ExpireTime	= $ENV{'M2H_EXPIREAGE'}    	|| 0;

$MsgGMTDateFmt	= $ENV{'M2H_MSGGMTDATEFMT'}   	|| '';
$MsgLocalDateFmt= $ENV{'M2H_MSGLOCALDATEFMT'}	|| '';

$NoSubjectTxt	= $ENV{'M2H_NOSUBJECTTXT'}	|| '[no subject]';

$NoteDir	= $ENV{'M2H_NOTEDIR'} 		|| 'notes';

$LockMethod 	= $ENV{'M2H_LOCKMETHOD'}	|| 'directory';
$LockMethod	= set_lock_mode($LockMethod);

$CONLEN      = defined($ENV{'M2H_CONLEN'})    ?  $ENV{'M2H_CONLEN'}	: 0;
$MAIN        = defined($ENV{'M2H_MAIN'})      ?  $ENV{'M2H_MAIN'}	: 1;
$MULTIIDX    = defined($ENV{'M2H_MULTIPG'})   ?  $ENV{'M2H_MULTIPG'}	: 0;
$MODTIME     = defined($ENV{'M2H_MODTIME'})   ?  $ENV{'M2H_MODTIME'}	: 0;
$NODOC       = defined($ENV{'M2H_DOC'})       ? !$ENV{'M2H_DOC'}	: 0;
$NOMAILTO    = defined($ENV{'M2H_MAILTO'})    ? !$ENV{'M2H_MAILTO'}	: 0;
$NoMsgPgs    = defined($ENV{'M2H_MSGPGS'})    ? !$ENV{'M2H_MSGPGS'}	: 0;
$NONEWS      = defined($ENV{'M2H_NEWS'})      ? !$ENV{'M2H_NEWS'}	: 0;
$NOSORT      = defined($ENV{'M2H_SORT'})      ? !$ENV{'M2H_SORT'}	: 0;
$NOURL       = defined($ENV{'M2H_URL'})       ? !$ENV{'M2H_URL'}	: 0;
$REVSORT     = defined($ENV{'M2H_REVSORT'})   ?  $ENV{'M2H_REVSORT'}	: 0;
$SUBSORT     = defined($ENV{'M2H_SUBSORT'})   ?  $ENV{'M2H_SUBSORT'}	: 0;
$AUTHSORT    = defined($ENV{'M2H_AUTHSORT'})  ?  $ENV{'M2H_AUTHSORT'}	: 0;
$THREAD      = defined($ENV{'M2H_THREAD'})    ?  $ENV{'M2H_THREAD'}	: 1;
$TNOSORT     = defined($ENV{'M2H_TSORT'})     ? !$ENV{'M2H_TSORT'}	: 0;
$TREVERSE    = defined($ENV{'M2H_TREVERSE'})  ?  $ENV{'M2H_TREVERSE'}	: 0;
$TSUBSORT    = defined($ENV{'M2H_TSUBSORT'})  ?  $ENV{'M2H_TSUBSORT'}	: 0;
$GzipFiles   = defined($ENV{'M2H_GZIPFILES'}) ?  $ENV{'M2H_GZIPFILES'}	: 0;
$GzipLinks   = defined($ENV{'M2H_GZIPLINKS'}) ?  $ENV{'M2H_GZIPLINKS'}	: 0;
$KeepOnRmm   = defined($ENV{'M2H_KEEPONRMM'}) ?  $ENV{'M2H_KEEPONRMM'}  : 0;
$UseLocalTime= defined($ENV{'M2H_USELOCALTIME'}) ? 
		       $ENV{'M2H_USELOCALTIME'} : 0;
$NoSubjectThreads = defined($ENV{'M2H_SUBJECTTHREADS'}) ?
			   !$ENV{'M2H_SUBJECTTHREADS'} : 0;
$SaveRsrcs   = defined($ENV{'M2H_SAVERESOURCES'}) ?
		       $ENV{'M2H_SAVERESOURCES'} : 1;
$POSIXstrftime = defined($ENV{'M2H_POSIXSTRFTIME'}) ?
			 $ENV{'M2H_POSIXSTRFTIME'} : 0;
$AddrModifyBodies  = defined($ENV{'M2H_MODIFYBODYADDRESSES'}) ?
			     $ENV{'M2H_MODIFYBODYADDRESSES'} : undef;
$IconURLPrefix  = defined($ENV{'M2H_ICONURLPREFIX'}) ?
			  $ENV{'M2H_ICONURLPREFIX'} : '';

if ($UNIX) {
    eval {
	$UMASK = defined($ENV{'M2H_UMASK'}) ?
		    $ENV{'M2H_UMASK'} : sprintf("%o",umask);
    };
}
$FilePerms      = $ENV{'M2H_FILEPERMS'} || '0666';
$FilePermsOct   = 0666;
$DbFilePerms    = $ENV{'M2H_DBFILEPERMS'} || '0660';
$DbFilePermsOct = 0660;

$CheckNoArchive = defined($ENV{'M2H_CHECKNOARCHIVE'}) ?
			  $ENV{'M2H_CHECKNOARCHIVE'} : 0;
$DecodeHeads = defined($ENV{'M2H_DECODEHEADS'}) ? $ENV{'M2H_DECODEHEADS'} : 0;
$DoArchive   = defined($ENV{'M2H_ARCHIVE'})     ? $ENV{'M2H_ARCHIVE'}     : 1;
$DoFolRefs   = defined($ENV{'M2H_FOLREFS'})     ? $ENV{'M2H_FOLREFS'}     : 1;
$Reconvert   = defined($ENV{'M2H_RECONVERT'})   ? $ENV{'M2H_RECONVERT'}   : 0;
$UsingLASTPG = defined($ENV{'M2H_USINGLASTPG'}) ? $ENV{'M2H_USINGLASTPG'} : 1;

$FastTempFiles = defined($ENV{'M2H_FASTTEMPFILES'}) ?
			 $ENV{'M2H_FASTTEMPFILES'} : 0;

$Lang        = $ENV{'M2H_LANG'} || $ENV{'LC_ALL'} || $ENV{'LANG'} || undef;

@FMTFILE     = defined($ENV{'M2H_RCFILE'}) ?
		    ($ENV{'M2H_RCFILE'}) : ();
@OtherIdxs   = defined($ENV{'M2H_OTHERINDEXES'}) ?
		    split(/:/, $ENV{'M2H_OTHERINDEXES'}) : ();
@PerlINC     = defined($ENV{'M2H_PERLINC'}) ?
		    split(/:/, $ENV{'M2H_PERLINC'}) : ();
@DateFields  = defined($ENV{'M2H_DATEFIELDS'}) ?
		    split(/:/, $ENV{'M2H_DATEFIELDS'}) : ();
@FromFields  = defined($ENV{'M2H_FROMFIELDS'}) ?
		    split(/:/, $ENV{'M2H_FROMFIELDS'}) : ();

# Version of @Datefiles in parsed format
@_DateFields = ( );

($TSliceNBefore, $TSliceNAfter, $TSliceInclusive) =
    defined($ENV{'M2H_TSLICE'}) ?
	split(/[:;]/, $ENV{'M2H_TSLICE'}) : (0, 4, 0);

##	Code for modify addresses in headers
$AddressModify = $ENV{'M2H_ADDRESSMODIFYCODE'} || "";

##	Regex representing "article" words for stripping out when doing
##	subject sorting.
$SubArtRxp   = $ENV{'M2H_SUBJECTARTICLERXP'} ||
	       q/^(the|a|an)\s+/;

##	Regex representing reply/forward prefixes to subject.
$SubReplyRxp = $ENV{'M2H_SUBJECTREPLYRXP'} ||
	       q/^\s*(re|sv|fwd|fw)[\[\]\d]*[:>-]+\s*/;

##	Code for stripping subjects
$SubStripCode = $ENV{'M2H_SUBJECTSTRIPCODE'} || "";

$MsgExcFilter = $ENV{'M2H_MSGEXCFILTER'} || "";

##	Arrays for months and weekdays.  If empty, the default settings
##	in mhtime.pl are used.

@Months   = $ENV{'M2H_MONTHS'}      ? split(/:/, $ENV{'M2H_MONTHS'})      : ();
@months   = $ENV{'M2H_MONTHSABR'}   ? split(/:/, $ENV{'M2H_MONTHSABR'})   : ();
@Weekdays = $ENV{'M2H_WEEKDAYS'}    ? split(/:/, $ENV{'M2H_WEEKDAYS'})    : ();
@weekdays = $ENV{'M2H_WEEKDAYSABR'} ? split(/:/, $ENV{'M2H_WEEKDAYSABR'}) : ();

##	Many of the following are set during runtime after the
##	database and resources have been read.  The variables are
##	listed here as a quick reference.

$ADDSINGLE	= 0;	# Flag if adding a single message
$IDXONLY	= 0;	# Flag if generating index to stdout
$RMM		= 0;	# Flag if removing messages
$SCAN		= 0;	# Flag if doing an archive scan

$MSGPGSSMARKUP	= '';	# Initial markup of message pages
$IDXPGSSMARKUP	= '';	# Initial markup of index pages
$TIDXPGSSMARKUP	= '';	# Initial markup of thread index pages
$SSMARKUP	= '';	# (Default) initial markup of all pages

$IDXLABEL	= '';	# Label for main index
$LIBEG  	= '';	# List open template for main index
$LIEND  	= '';	# List close template for main index
$LITMPL 	= '';	# List item template
$AUTHBEG	= '';	# Begin of author group
$AUTHEND	= '';	# End of author group
$DAYBEG   	= '';	# Begin of a day group
$DAYEND   	= '';	# End of a day group
$SUBJECTBEG	= '';	# Begin of subject group
$SUBJECTEND	= '';	# End of subject group

$TIDXLABEL	= '';	# Label for thread index
$THEAD  	= '';	# Thread index header (and list start)
$TFOOT  	= '';	# Thread index footer (and list end)
$TSINGLETXT	= '';	# Single/lone thread entry template
$TTOPBEG	= '';	# Top of a thread begin template
$TTOPEND	= '';	# Top of a thread end template
$TSUBLISTBEG	= '';	# Sub-thread list open
$TSUBLISTEND	= '';	# Sub-thread list close
$TLITXT 	= '';	# Thread list item text
$TLIEND 	= '';	# Thread list item end
$TLINONE	= '';	# List item for missing message in thread
$TLINONEEND	= '';	# List item end for missing message in thread
$TSUBJECTBEG	= '';	# Pre-text for subject-based items
$TSUBJECTEND	= '';	# Post-text for subject-based items
$TINDENTBEG	= '';	# Thread indent open
$TINDENTEND	= '';	# Thread indent close
$TCONTBEG	= '';	# Thread continue open
$TCONTEND	= '';	# Thread continue close

$TSLICEBEG		= '';	# Start of thread slice
$TSLICEEND		= '';	# End of thread slice
$TSLICESINGLETXT	= '';	# Single/lone thread entry template
$TSLICETOPBEG		= '';	# Top of a thread begin template
$TSLICETOPEND		= '';	# Top of a thread end template
$TSLICESUBLISTBEG	= '';	# Sub-thread list open
$TSLICESUBLISTEND	= '';	# Sub-thread list close
$TSLICELITXT 		= '';	# Thread list item text
$TSLICELIEND 		= '';	# Thread list item end
$TSLICELINONE		= '';	# List item for missing message in thread
$TSLICELINONEEND	= '';	# List item end for missing message in thread
$TSLICESUBJECTBEG	= '';	# Pre-text for subject-based items
$TSLICESUBJECTEND	= '';	# Post-text for subject-based items
$TSLICEINDENTBEG	= '';	# Thread indent open
$TSLICEINDENTEND	= '';	# Thread indent close
$TSLICECONTBEG		= '';	# Thread continue open
$TSLICECONTEND		= '';	# Thread continue close

$TSLICESINGLETXTCUR	= '';	# Current Single/lone thread entry template
$TSLICETOPBEGCUR	= '';	# Current Top of a thread begin template
$TSLICETOPENDCUR	= '';	# Current Top of a thread end template
$TSLICELITXTCUR 	= '';	# Thread list current item text
$TSLICELIENDCUR 	= '';	# Thread list current item end

$MSGFOOT	= '';	# Message footer
$MSGHEAD	= '';	# Message header
$TOPLINKS	= '';	# Message links at top of message
$BOTLINKS	= '';	# Message links at bottom of message
$SUBJECTHEADER	= '';	# Markup for message main subject line
$HEADBODYSEP 	= '';	# Markup between mail header and body
$MSGBODYEND 	= '';	# Markup at end of message data

$FIELDSBEG	= '';	# Beginning markup for mail header
$FIELDSEND	= '';	# End markup for mail header
$FLDBEG 	= '';	# Beginning markup for field text
$FLDEND 	= '';	# End markup for field text
$LABELBEG	= '';	# Beginning markup for field label
$LABELEND	= '';	# End markup for field label

$NEXTBUTTON	= '';  	# Next button template
$NEXTBUTTONIA	= '';  	# Next inactive button template
$PREVBUTTON	= '';  	# Previous button template
$PREVBUTTONIA	= '';  	# Previous inactive button template
$NEXTLINK	= '';  	# Next link template
$NEXTLINKIA	= '';  	# Next inactive link template
$PREVLINK	= '';  	# Previous link template
$PREVLINKIA	= '';  	# Previous inactive link template

$TNEXTBUTTON	= '';  	# Thread Next button template
$TNEXTBUTTONIA	= '';  	# Thread Next inactive button template
$TPREVBUTTON	= '';  	# Thread Previous button template
$TPREVBUTTONIA	= '';  	# Thread Previous inactive button template

$TTOPBUTTON	  = ''; # Top of thread button template
$TTOPBUTTONIA	  = ''; # Top of thread inactive button template
$TENDBUTTON	  = ''; # End of thread button template
$TENDBUTTONIA	  = ''; # End of thread inactive button template

$TNEXTTOPBUTTON	  = ''; # Next Thread button template
$TNEXTTOPBUTTONIA = ''; # Next Thread inactive button template
$TPREVTOPBUTTON	  = ''; # Previous Thread button template
$TPREVTOPBUTTONIA = ''; # Previous Thread inactive button template

$TNEXTINBUTTON	  = ''; # Within Thread Next button template
$TNEXTINBUTTONIA  = ''; # Within Thread Next inactive button template
$TPREVINBUTTON	  = ''; # Within Thread Previous button template
$TPREVINBUTTONIA  = ''; # Within Thread Previous inactive button template

$TNEXTLINK	= '';  	# Thread Next link template
$TNEXTLINKIA	= '';  	# Thread Next inactive link template
$TPREVLINK	= '';  	# Thread Previous link template
$TPREVLINKIA	= '';  	# Thread Previous inactive link template

$TTOPLINK	= ''; # Top of thread link template
$TTOPLINKIA	= ''; # Top of thread inactive link template
$TENDLINK	= ''; # End of thread link template
$TENDLINKIA	= ''; # End of thread inactive link template

$TNEXTTOPLINK	= '';	# Next Thread link template
$TNEXTTOPLINKIA = '';	# Next Thread inactive link template
$TPREVTOPLINK	= '';	# Previous Thread link template
$TPREVTOPLINKIA = '';	# Previous Thread inactive link template

$TNEXTINLINK	= '';	# Within Thread Next link template
$TNEXTINLINKIA  = '';	# Within Thread Next inactive link template
$TPREVINLINK	= '';	# Within Thread Previous link template
$TPREVINLINKIA  = '';	# Within Thread Previous inactive link template

$IDXPGBEG	= '';	# Beginning of main index page
$IDXPGEND	= '';	# Ending of main index page
$TIDXPGBEG	= '';	# Beginning of thread index page
$TIDXPGEND	= '';	# Ending of thread index page

$MSGPGBEG	= '';	# Beginning of message page
$MSGPGEND	= '';	# Ending of message page

$FIRSTPGLINK 	= '';  	# First page link template
$LASTPGLINK 	= '';  	# Last page link template
$NEXTPGLINK 	= '';  	# Next page link template
$NEXTPGLINKIA	= '';  	# Next page inactive link template
$PREVPGLINK 	= '';  	# Previous page link template
$PREVPGLINKIA	= '';  	# Previous page inactive link template

$TFIRSTPGLINK 	= '';  	# First thread page link template
$TLASTPGLINK 	= '';  	# Last thread page link template
$TNEXTPGLINK	= '';  	# Thread next page link template
$TNEXTPGLINKIA	= '';  	# Thread next page inactive link template
$TPREVPGLINK	= '';  	# Thread previous page link template
$TPREVPGLINKIA	= '';  	# Thread previous page inactive link template

$FOLUPBEGIN	= '';	# Start of follow-ups for message page
$FOLUPLITXT	= '';	# Markup for follow-up list entry
$FOLUPEND	= '';	# End of follow-ups for message page
$REFSBEGIN	= '';	# Start of refs for message page
$REFSLITXT	= '';	# Markup for ref list entry
$REFSEND	= '';	# End of refs for message page

$MSGIDLINK 	= '';	# Markup for linking message-ids

$NOTE		= '';	# Markup template when annotation available
$NOTEIA		= '';	# Markup template when annotation not available
$NOTEICON	= '';	# Markup template for note icon if annotation
$NOTEICONIA	= '';	# Markup template for note icon if no annotation

##	The following associative array if for defining custom
##	resource variables
%CustomRcVars	= ();

$X = "\034";	# Value separator (should equal $;)
		# NOTE: Older versions used this variable as
		#	the list value separator.  Its use should
		#	now only be for extracting time from
		#	indexes of messages or for processing
		#	old version data.

}

##---------------------------------------------------------------------------##

1;
