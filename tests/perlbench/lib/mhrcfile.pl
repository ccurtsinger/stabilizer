##---------------------------------------------------------------------------##
##  File:
##	$Id: mhrcfile.pl,v 2.37 2003/08/13 03:56:28 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      Routines for parsing resource files
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

# CPU2006
require 'mhfile.pl';

##---------------------------------------------------------------------------
##	read_resource_file() reads the specifed resource file and any
##	language variations.
##
sub read_resource_file {
    my $filename = shift;
    my $nowarn	 = shift;
    my $lang	 = shift || $Lang;
    my @files = get_lang_file_list($filename, $lang);

    my $file;
    my $found = 0;
    foreach $file (get_lang_file_list($filename, $lang)) {
# CPU2006
	#if (-r $file) {
	if (file_exists($file)) {
	    parse_resource_file($file);
	    ++$found;
# CPU2006
#	} elsif (-e _) {
#	    qq/Warning: "$file" is not readable\n/;
	}
    }
    if (!$found && !$nowarn) {
	qq/Warning: Unable to read resource file "$filename"\n/;
    }
    $found;
}

##---------------------------------------------------------------------------
##	get_lang_file_list() returns list of filenames that include
##	language setting.
##
sub get_lang_file_list {
    my $pathname =  shift;
    my $lang     =  lc (shift || $Lang);
       $lang     =~ s/\s+//g;
    return ($pathname)  unless $lang;

    my $codeset = '';
    if ($lang =~ s/\.(.*)$//) {
	$codeset = '.' . lc($1);
    }

    my @files   = ($pathname);
    my $curbase = $pathname . '.';
    my $tag;
    foreach $tag (split(/[\-_]/, $lang)) {
	next  unless $tag =~ /\S/;
	$curbase .= $tag;
	push(@files, $curbase);
	push(@files, $curbase.$codeset)  if ($codeset);
	$curbase .= '_';
    }
    @files;
}

##---------------------------------------------------------------------------
##	parse_resource_file() parses the resource file.
##	(The code for this routine could probably be simplified).
##
sub parse_resource_file {
    my($file) = shift;
    my($line, $tag, $label, $acro, $hr, $type, $routine, $plfile,
       $url, $arg, $tmp, @a);
    my($elem, $attr, $override, $handle, $pathhead, $chop);
    local($_);
    $override = 0;

# CPU2006
    #$handle = &file_open($file);
    $handle = $mhonarc_files{$file};
    die "read_resource_file got a wierd reference (",ref($handle),") trying to open \"$file\".  A list of possible files follows: ".join("\n", sort keys %mhonarc_files)."\nStopped" if (ref($handle) ne 'ARRAY');

    if ($file =~ m%(.*)[$DIRSEPREX]%o) {
	$pathhead = $1;
	$MainRcDir = $pathhead  unless defined $MainRcDir;
    } else {
	$pathhead = '';
    }

    print STDOUT "Reading resource file: $file ...\n"  unless $QUIET;
# CPU2006
    #while (defined($line = <$handle>)) {
    while (defined($line = shift (@$handle))) {
	next unless $line =~ /^\s*<([^>]+)>/;
	$attr = '';
	($elem, $attr) = split(' ', $1, 2);
	$attr = ''  unless defined($attr);
	$elem =~ tr/A-Z/a-z/;
	$override = ($attr =~ /override/i);
	$chop = ($attr =~ /chop/i);

      FMTSW: {
	if ($elem eq 'addressmodifycode') {	# Code to strip subjects
	    $AddressModify = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'authorbegin') {		# Begin for author group
	    $AUTHBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'authorend') {		# End for author group
	    $AUTHEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'authsort') {		# Sort msgs by author
	    $AUTHSORT = 1;
	    $NOSORT = 0;  $SUBSORT = 0;
	    last FMTSW;
	}
	if ($elem eq 'botlinks') {		# Bottom links in message
	    $BOTLINKS = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'charsetaliases') {	# Charset aliases
	    $IsDefault{'CHARSETALIASES'} = 0;
	    readmail::MAILset_charset_aliases({ }, $override);
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/charsetaliases\s*>/i;
		next  unless $line =~ /\S/;
		$line =~ s/\s//g;
		($name, $aliases) = split(/;/, $line, 2);
		readmail::MAILset_charset_aliases({
		    $name => [ split(/,/, $aliases) ] });
	    }
	    last FMTSW;
	}
	if ($elem eq 'charsetconverters') {	# Charset filters
	    $IsDefault{'CHARSETCONVERTERS'} = 0;
	    if ($override) {
		%readmail::MIMECharSetConverters = ();
		%readmail::MIMECharSetConvertersSrc = ();
	    }
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/charsetconverters\s*>/i;
		next  if $line =~ /^\s*$/;
		$line =~ s/\s//g;
		($type,$routine,$plfile) = split(/;/,$line,3);
		$type = lc($type);
		$readmail::MIMECharSetConverters{$type}    = $routine;
		$readmail::MIMECharSetConvertersSrc{$type} = $plfile
		    if defined($plfile) and $plfile =~ /\S/;
	    }
	    last FMTSW;
	}
	if ($elem eq 'checknoarchive') {
	    $CheckNoArchive = 1; last FMTSW;
	}
	if ($elem eq 'conlen') {
	    $CONLEN = 1; last FMTSW;
	}
	if ($elem eq 'datefields') {
	    @a = &get_list_content($handle, $elem);
	    if (@a) { @DateFields = @a; }
	    last FMTSW;
	}
	if ($elem eq 'daybegin') {		# Begin for day group
	    $DAYBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'dayend') {		# End for day group
	    $DAYEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'dbfileperms') {		# DBFILE creation permissions
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$line =~ s/\s//g;
		$DbFilePerms = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'decodeheads') {
	    $DecodeHeads = 1; last FMTSW;
	}
	if ($elem eq 'definederived') {		# Custom derived file
	    %UDerivedFile = ()  if $override;
    # CPU2006
	    #$line = <$handle>;
	    $line = shift(@$handle);
	    last FMTSW if $line =~ /^\s*<\/definederived\s*>/i;
	    $line =~ s/\s//g;
	    $UDerivedFile{$line} = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'definevar') {		# Custom resource variable
	    @CustomRcVars = ()  if $override;
    # CPU2006
	    #$line = <$handle>;
	    $line = shift(@$handle);
	    last FMTSW if $line =~ /^\s*<\/definevar\s*>/i;
	    $line =~ s/\s//g;
	    $CustomRcVars{$line} = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'doc') {			# Link to documentation
	    $NODOC = 0; last FMTSW;
	}
	if ($elem eq 'docurl') {		# Doc URL
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$DOCURL = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'excs') {			# Exclude header fields
	    %HFieldsExc = ()  if $override;
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/excs\s*>/i;
		next  unless $line =~ /\S/;
		$line =~ s/\s//g;  $line =~ tr/A-Z/a-z/;
		$HFieldsExc{$line} = 1  if $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'expireage') {		# Time in seconds until expire
	    if (($tmp = &get_elem_int($handle, $elem, 1)) ne '') {
		$ExpireTime = $tmp;
	    }
	    last FMTSW;
	}
	if ($elem eq 'expiredate') {		# Expiration date
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$ExpireDate = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'fasttempfiles') {		# Non-random temp files
	    $FastTempFiles = 1; last FMTSW;
	}
	if ($elem eq 'fieldstore') {		# Fields to store
	    @ExtraHFields = ()  if $override;
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if     $line =~ /^\s*<\/fieldstore\s*>/i;
		next  unless $line =~ /\S/;
		$line =~ s/\s+//g;  $line =~ tr/A-Z/a-z/;
		push(@ExtraHFields, $line);
	    }
	    last FMTSW;
	}
	if ($elem eq 'fieldstyles') {		# Field text style
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/fieldstyles\s*>/i;
		next  if $line =~ /^\s*$/;
		$line =~ s/\s//g;  $line =~ tr/A-Z/a-z/;
		($label, $tag) = split(/:/,$line);
		$HeadFields{$label} = $tag;
	    }
	    last FMTSW;
	}
	if ($elem eq 'fieldorder') {		# Field order
	    @FieldOrder = ();  %FieldODefs = ();
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/fieldorder\s*>/i;
		next  if $line =~ /^\s*$/;
		$line =~ s/\s//g;  $line =~ tr/A-Z/a-z/;
		push(@FieldOrder, $line);
		$FieldODefs{$line} = 1;
	    }
	    # push(@FieldOrder,'-extra-')  if (!$FieldODefs{'-extra-'});
	    last FMTSW;
	}
	if ($elem eq 'fieldsbeg') {		# Begin markup of mail head
	    $FIELDSBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'fieldsend') {		# End markup of mail head
	    $FIELDSEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'fileperms') {		# File creation permissions
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$line =~ s/\s//g;
		$FilePerms = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'firstpglink') {		# First page link in index
	    $FIRSTPGLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'fldbeg') {		# Begin markup of field text
	    $FLDBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'fldend') {		# End markup of field text
	    $FLDEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'folrefs') {		# Print explicit fol/refs
	    $DoFolRefs = 1; last FMTSW;
	}
	if ($elem eq 'folupbegin') {		# Begin markup for follow-ups
	    $FOLUPBEGIN = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'folupend') {		# End markup for follow-ups
	    $FOLUPEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'foluplitxt') {		# Follow-up link markup
	    $FOLUPLITXT = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'fromfields') {		# Fields to get author
	    @a = &get_list_content($handle, $elem);
	    if (@a) { @FromFields = @a; }
	    last FMTSW;
	}
	if ($elem eq 'gmtdatefmt') {		# GMT date format
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$GMTDateFmt = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'gzipexe') {		# Gzip executable
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$line =~ s/\s+$//g;
		$GzipExe = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'gzipfiles') {
	    $GzipFiles = 1;  last FMTSW;
	}
	if ($elem eq 'gziplinks') {
	    $GzipLinks = 1;  last FMTSW;
	}
	if ($elem eq 'headbodysep') {
	    $HEADBODYSEP = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'htmlext') {		# Extension for HTML files
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$line =~ s/\s//g;
		$HtmlExt = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'icons') {			# Icons
	    %Icons = ()  if $override;
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/icons\s*>/i;
		next  if $line =~ /^\s*$/;
		$line =~ s/\s//g;
		($type, $url) = split(/[;:]/,$line,2);
		$type =~ tr/A-Z/a-z/;
		$Icons{$type} = $url;
	    }
	    last FMTSW;
	}
	if ($elem eq 'iconurlprefix') {		# Prefix for ICON urls
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$line =~ s/\s+//g;
		$IconURLPrefix = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'idxfname') {		# Index filename
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$line =~ s/\s//g;
		$IDXNAME = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'idxlabel') {		# Index label
	    $IDXLABEL = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'idxpgbegin') {		# Opening markup of index
	    $IDXPGBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'idxpgend') {		# Closing markup of index
	    $IDXPGEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'idxprefix') {		# Prefix for main idx pages
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$line =~ s/\s//g;
		$IDXPREFIX = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'idxsize') {		# Size of index
	    if (($tmp = &get_elem_int($handle, $elem, 1)) ne '') {
		$IDXSIZE = $tmp;
	    }
	    last FMTSW;
	}
	if ($elem eq 'include') {		# Include other rc files
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/include\s*>/i;
		next  if $line =~ /^\s*$/;
		$line =~ s/\s+$//;
		$line = $pathhead . $line  if ($line !~ /$DIRSEPREX/o);
		&read_resource_file($line);
	    }
	    last FMTSW;
	}
	if ($elem eq 'keeponrmm') {		# Keep files on rmm
	    $KeepOnRmm = 1;
	    last FMTSW;
	}
	if ($elem eq 'lang') {			# Locale/language
	    $Lang = &get_elem_last_line($handle, $elem);
	    $Lang =~ s/\s+//g;
	    last FMTSW;
	}
	if ($elem eq 'labelbeg') {		# Begin markup of label
	    $LABELBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'labelend') {		# End markup of label
	    $LABELEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'labelstyles') {		# Field label style
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/labelstyles\s*>/i;
		next  if $line =~ /^\s*$/;
		$line =~ s/\s//g;  $line =~ tr/A-Z/a-z/;
		($label, $tag) = split(/:/,$line);
		$HeadHeads{$label} = $tag;
	    }
	    last FMTSW;
	}
	if ($elem eq 'lastpglink') {		# Last page link in index
	    $LASTPGLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'listbegin') {		# List begin
	    $LIBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'listend') {		# List end
	    $LIEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'litemplate') {		# List item template
	    $LITMPL = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'localdatefmt') {		# Local date format
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$LocalDateFmt = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'lockmethod') {		# Locking method
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$LockMethod = &set_lock_mode($line);
	    }
	    last FMTSW;
	}
	if ($elem eq 'mailto') {		# Convert e-mail addrs
	    $NOMAILTO = 0; last FMTSW;
	}
	if ($elem eq 'mailtourl') {		# mailto URL
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/mailtourl\s*>/i;
		next  if $line =~ /^\s*$/;
		$line =~ s/\s//g;
		$MAILTOURL = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'main') {			# Print main index
	    $MAIN = 1; last FMTSW;
	}
	if ($elem eq 'maxsize') {		# Size of archive
	    if (($tmp = &get_elem_int($handle, $elem, 1)) ne '') {
		$MAXSIZE = $tmp;
	    }
	    last FMTSW;
	}
	if ($elem eq 'msgbodyend') {		# Markup after message body
	    $MSGBODYEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'msgexcfilter') {		# Code selectively exclude msgs
	    $MsgExcFilter = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'msgpgs') {		# Output message pages
	    $NoMsgPgs = 0; last FMTSW;
	}
	if ($elem eq 'msgprefix') {		# Prefix for message files
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$line =~ s/\s//g;
		$MsgPrefix = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'mhpattern') {		# File pattern MH-like dirs
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$MHPATTERN = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'mimealtprefs') {		# Mime alternative prefs
	    $IsDefault{'MIMEALTPREFS'} = 0;
	    @MIMEAltPrefs = ();
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/mimealtprefs\s*>/i;
		$line =~ s/\s//g;
		push(@MIMEAltPrefs, lc($line))  if $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'mimedecoders') {		# Mime decoders
	    $IsDefault{'MIMEDECODERS'} = 0;
	    if ($override) {
		%readmail::MIMEDecoders = ();
		%readmail::MIMEDecodersSrc = ();
	    }
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if     $line =~ /^\s*<\/mimedecoders\s*>/i;
		next  unless $line =~ /\S/;
		$line =~ s/\s//g;
		($type,$routine,$plfile) = split(/;/,$line,3);
		$type =~ tr/A-Z/a-z/;
		$readmail::MIMEDecoders{$type}    = $routine;
		$readmail::MIMEDecodersSrc{$type} = $plfile  if $plfile =~ /\S/;
	    }
	    last FMTSW;
	}
	if ($elem eq 'mimefilters') {		# Mime filters
	    $IsDefault{'MIMEFILTERS'} = 0;
	    if ($override) {
		%readmail::MIMEFilters = ();
		%readmail::MIMEFiltersSrc = ();
	    }
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/mimefilters\s*>/i;
		next  if $line =~ /^\s*$/;
		$line =~ s/\s//g;
		($type,$routine,$plfile) = split(/;/,$line,3);
		$type =~ tr/A-Z/a-z/;
		$readmail::MIMEFilters{$type}    = $routine;
		$readmail::MIMEFiltersSrc{$type} = $plfile  if $plfile =~ /\S/;
	    }
	    last FMTSW;
	}
	if ($elem eq 'mimeargs') {		# Mime arguments
	    $IsDefault{'MIMEARGS'} = 0;
	    %readmail::MIMEFiltersArgs = ()  if $override;
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if     $line =~ /^\s*<\/mimeargs\s*>/i;
		next  unless $line =~ /\S/;
		$line =~ s/^\s+//;
		if ($line =~ /;/) {
		    ($type, $arg) = split(/;/,$line,2);
		} else {
		    ($type, $arg) = split(/:/,$line,2);
		}
		$type =~ tr/A-Z/a-z/  if $type =~ m%/%;
		$readmail::MIMEFiltersArgs{$type} = $arg;
	    }
	    last FMTSW;
	}
	if ($elem eq 'mimeexcs') {		# Mime exclusions
	    $IsDefault{'MIMEEXCS'} = 0;
	    %readmail::MIMEExcs = ()  if $override;
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/mimeexcs\s*>/i;
		$line =~ s/\s//g;  $line =~ tr/A-Z/a-z/;
		$readmail::MIMEExcs{$line} = 1  if $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'modifybodyaddresses') {	# Modify addresses in bodies
	    $AddrModifyBodies = 1; last FMTSW;
	}
	if ($elem eq 'months') {		# Full month names
	    @a = &get_list_content($handle, $elem);
	    if (scalar(@a)) {
		@Months = @a;
	    }
	    last FMTSW;
	}
	if ($elem eq 'monthsabr') {		# Abbreviated month names
	    @a = &get_list_content($handle, $elem);
	    if (scalar(@a)) {
		@months = @a;
	    }
	    last FMTSW;
	}
	if ($elem eq 'modtime') {		# Mod time same as msg date
	    $MODTIME = 1; last FMTSW;
	}
	if ($elem eq 'msgfoot') {		# Message footer text
	    $MSGFOOT = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'msggmtdatefmt') {		# Message GMT date format
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$MsgGMTDateFmt = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'msghead') {		# Message header text
	    $MSGHEAD = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'msgidlink') {
	    $MSGIDLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'msglocaldatefmt') {	# Message local date format
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$MsgLocalDateFmt = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'msgpgbegin') {		# Opening markup of message
	    $MSGPGBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'msgpgend') {		# Closing markup of message
	    $MSGPGEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'msgsep') {		# Message separator
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$FROM = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'multipg') {		# Print multi-page indexes
	    $MULTIIDX = 1; last FMTSW;
	}
	if ($elem eq 'nextbutton') {		# Next button link in message
	    $NEXTBUTTON = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'nextbuttonia') {
	    $NEXTBUTTONIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'nextlink') {		# Next link in message
	    $NEXTLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'nextlinkia') {
	    $NEXTLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'nextpglink') {		# Next page link in index
	    $NEXTPGLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'nextpglinkia') {
	    $NEXTPGLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'news') {			# News for linking
	    $NONEWS = 0; last FMTSW;
	}
	if ($elem eq 'noauthsort') {		# Do not sort msgs by author
	    $AUTHSORT = 0;
	    last FMTSW;
	}
	if ($elem eq 'nochecknoarchive') {
	    $CheckNoArchive = 0; last FMTSW;
	}
	if ($elem eq 'noconlen') {		# Ignore content-length
	    $CONLEN = 0; last FMTSW;
	}
	if ($elem eq 'nodecodeheads') {		# Don't decode charsets
	    $DecodeHeads = 0; last FMTSW;
	}
	if ($elem eq 'nodoc') {			# Do not link to docs
	    $NODOC = 1; last FMTSW;
	}
	if ($elem eq 'nofasttempfiles') {	# Random temp files
	    $FastTempFiles = 0; last FMTSW;
	}
	if ($elem eq 'nofolrefs') {		# Don't print explicit fol/refs
	    $DoFolRefs = 0; last FMTSW;
	}
	if ($elem eq 'nomodifybodyaddresses') {	# Don't modify addresses
	    $AddrModifyBodies = 0; last FMTSW;
	}
	if ($elem eq 'nogzipfiles') {		# Don't gzip files
	    $GzipFiles = 0;  last FMTSW;
	}
	if ($elem eq 'nogziplinks') {		# Don't add ".gz" to links
	    $GzipLinks = 0;  last FMTSW;
	}
	if ($elem eq 'nokeeponrmm') {		# Remove files on rmm
	    $KeepOnRmm = 0;
	    last FMTSW;
	}
	if ($elem eq 'nomailto') {		# Do not convert e-mail addrs
	    $NOMAILTO = 1; last FMTSW;
	}
	if ($elem eq 'nomain') {		# No main index
	    $MAIN = 0; last FMTSW;
	}
	if ($elem eq 'nomodtime') {		# Do not change mod times
	    $MODTIME = 0; last FMTSW;
	}
	if ($elem eq 'nomsgpgs') {		# Do not print message pages
	    $NoMsgPgs = 1; last FMTSW;
	}
	if ($elem eq 'nomultipg') {		# Single page index
	    $MULTIIDX = 0; last FMTSW;
	}
	if ($elem eq 'nonews') {		# Ignore news for linking
	    $NONEWS = 1; last FMTSW;
	}
	if ($elem eq 'noposixstrftime') {	# Do not use POSIX::strftime()
	    $POSIXstrftime = 0;
	    last FMTSW;
	}
	if ($elem eq 'noreverse') {		# Sort in normal order
	    $REVSORT = 0; last FMTSW;
	}
	if ($elem eq 'nosaveresources') {	# Do not save resources
	    $SaveRsrcs = 0;
	    last FMTSW;
	}
	if ($elem eq 'nosort') {		# Do not sort messages
	    $NOSORT = 1;
	    last FMTSW;
	}
	if ($elem eq 'nospammode') {		# Do not do anti-spam stuff
	    $SpamMode = 0; last FMTSW;
	}
	if ($elem eq 'nosubjectthreads') {	# No check subjects for threads
	    $NoSubjectThreads = 1;
	    last FMTSW;
	}
	if ($elem eq 'nosubjecttxt') {		# Text to use if no subject
	    $NoSubjectTxt = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'nosubsort') {		# Do not sort msgs by subject
	    $SUBSORT = 0;
	    last FMTSW;
	}
	if ($elem eq 'note') {			# Annotation markup
	    $NOTE = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'notedir') {		# Notes directory
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$NoteDir = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'noteia') {		# No Annotation markup
	    $NOTEIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'noteicon') {		# Note icon
	    $NOTEICON = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'noteiconia') {		# Note icon when no annotation
	    $NOTEICONIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'nothread') {		# No thread index
	    $THREAD = 0; last FMTSW;
	}
	if ($elem eq 'notreverse') {		# Thread sort in normal order
	    $TREVERSE = 0; last FMTSW;
	}
	if ($elem eq 'notsubsort' ||
	    $elem eq 'tnosubsort') {		# No subject order for threads
	    $TSUBSORT = 0;
	    last FMTSW;
	}
	if ($elem eq 'notsort' ||
	    $elem eq 'tnosort') {		# Raw order for threads
	    $TNOSORT = 1; $TSUBSORT = 0;
	    last FMTSW;
	}
	if ($elem eq 'nourl') {			# Ignore URLs
	    $NOURL = 1; last FMTSW;
	}
	if ($elem eq 'nouselocaltime') {	# Not using localtime
	    $UseLocalTime = 0; last FMTSW;
	}
	if ($elem eq 'nousinglastpg') {		# Not using $LASTPG$
	    $UsingLASTPG = 0; last FMTSW;
	}
	if ($elem eq 'otherindexes') {		# Other indexes
	    @OtherIdxs = ()  if $override;
	    unshift(@OtherIdxs, &get_pathname_content($handle, $elem));
	    last FMTSW;
	}
	if ($elem eq 'perlinc') {		# Define perl search paths
	    @PerlINC = ()  if $override;
	    unshift(@PerlINC, &get_pathname_content($handle, $elem));
	    last FMTSW;
	}
	if ($elem eq 'posixstrftime') {		# Use POSIX::strftime()
	    $POSIXstrftime = 1;
	    last FMTSW;
	}
	if ($elem eq 'prevbutton') {		# Prev button link in message
	    $PREVBUTTON = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'prevbuttonia') {		# Prev i/a button link
	    $PREVBUTTONIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'prevlink') {		# Prev link in message
	    $PREVLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'prevlinkia') {		# Prev i/a link
	    $PREVLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'prevpglink') {		# Prev page link for index
	    $PREVPGLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'prevpglinkia') {
	    $PREVPGLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'refsbegin') {		# Explicit ref links begin
	    $REFSBEGIN = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'refsend') {		# Explicit ref links end
	    $REFSEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'refslitxt') {		# Explicit ref link
	    $REFSLITXT = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'reverse') {		# Reverse sort
	    $REVSORT = 1;
	    last FMTSW;
	}
	if ($elem eq 'saveresources') {		# Save resources in db
	    $SaveRsrcs = 1;
	    last FMTSW;
	}
	if ($elem eq 'sort') {			# Sort messages by date
	    $NOSORT = 0;
	    $AUTHSORT = 0;  $SUBSORT = 0;
	    last FMTSW;
	}
	if ($elem eq 'spammode') {		# Obfsucate/hide addresses
	    $SpamMode = 1; last FMTSW;
	}
	if ($elem eq 'ssmarkup') {		# Initial page markup
	    $SSMARKUP = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'msgpgssmarkup') {		# Initial message page markup
	    $MSGPGSSMARKUP = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'idxpgssmarkup') {		# Initial index page markup
	    $IDXPGSSMARKUP = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tidxpgssmarkup') {	# Initial thread idx page markup
	    $TIDXPGSSMARKUP = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'subjectarticlerxp') {	# Regex for language articles
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$SubArtRxp = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'subjectreplyrxp') {	# Regex for reply text
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$SubReplyRxp = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'subjectstripcode') {	# Code to strip subjects
	    $SubStripCode = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'subjectthreads') {	# Check subjects for threads
	    $NoSubjectThreads = 0;
	    last FMTSW;
	}
	if ($elem eq 'subsort') {		# Sort messages by subject
	    $SUBSORT = 1;
	    $AUTHSORT = 0;  $NOSORT = 0;
	    last FMTSW;
	}
	if ($elem eq 'subjectbegin') {		# Begin for subject group
	    $SUBJECTBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'subjectend') {		# End for subject group
	    $SUBJECTEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'subjectheader') {
	    $SUBJECTHEADER = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tcontbegin') {		# Thread cont. start
	    $TCONTBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tcontend') {		# Thread cont. end
	    $TCONTEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'textclipfunc') {		# Text clipping function
	    $TextClipFunc = undef;
	    $TextClipSrc = undef;
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/textclipfunc\s*>/i;
		next  if $line =~ /^\s*$/;
		$line =~ s/\s//g;
		($TextClipFunc,$TextClipSrc) = split(/;/,$line,2);
	    }
	}
	if ($elem eq 'defcharset') {		# Default charset
	    $readmail::TextDefCharset = lc get_elem_last_line($handle, $elem);
	    $readmail::TextDefCharset =~ s/\s//g;
	    $readmail::TextDefCharset = 'us-ascii'
		if $readmail::TextDefCharset eq '';
	}
	if ($elem eq 'tendbutton') {		# End of thread button
	    $TENDBUTTON = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tendbuttonia') {
	    $TENDBUTTONIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tendlink') {		# End of thread link
	    $TENDLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tendlinkia') {
	    $TENDLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'textencode') {		# Text encoder
	    $readmail::TextEncode      = undef;
	    $readmail::TextEncoderFunc = undef;
	    $readmail::TextEncoderSrc  = undef;
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if     $line =~ /^\s*<\/textencode\s*>/i;
		next  unless $line =~ /\S/;
		($type,$routine,$plfile)   = split(/;/,$line,3);
		$type    =~ s/\s//g;
		$routine =~ s/\s//g;
		$plfile  =~ s/^\s+//;  $plfile =~ s/\s+\z//g;
		$readmail::TextEncode      = lc $type;
		$readmail::TextEncoderFunc = $routine;
		$readmail::TextEncoderSrc  = $plfile
		    if defined($plfile) and $plfile =~ /\S/;
		$IsDefault{'TEXTENCODE'} = 0;
	    }
	    last FMTSW;
	}
	if ($elem eq 'tfirstpglink') {		# First thread page link
	    $TFIRSTPGLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tfoot') {			# Thread idx foot
	    $TFOOT = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'thead') {			# Thread idx head
	    $THEAD = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tidxfname') {		# Threaded idx filename
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$line =~ s/\s//g;
		$TIDXNAME = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'tidxlabel') {		# Thread index label
	    $TIDXLABEL = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tidxpgbegin') {		# Opening markup of thread idx
	    $TIDXPGBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tidxpgend') {		# Closing markup of thread idx
	    $TIDXPGEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tidxprefix') {		# Prefix for thread idx pages
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$line =~ s/\s//g;
		$TIDXPREFIX = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'timezones') {		# Time zones
	    if ($override) { %ZoneUD = (); }
    # CPU2006
	    #while (defined($line = <$handle>)) {
	    while (defined($line = shift(@$handle))) {
		last  if $line =~ /^\s*<\/timezones\s*>/i;
		$line =~ s/\s//g;  $line =~ tr/a-z/A-Z/;
		($acro,$hr) = split(/:/,$line);
		$acro =~ tr/a-z/A-Z/;
		$ZoneUD{$acro} = $hr;
	    }
	    last FMTSW;
	}
	if ($elem eq 'tindentbegin') {		# Thread indent start
	    $TINDENTBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tindentend') {		# Thread indent end
	    $TINDENTEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'title') {			# Title of index page
	    $TITLE = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tlastpglink') {		# Last thread page link
	    $TLASTPGLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tlevels') {		# Level of threading
	    if (($tmp = &get_elem_int($handle, $elem, 1)) ne '') {
		$TLEVELS = $tmp;
	    }
	    last FMTSW;
	}
	if ($elem eq 'tlinone') {		# Markup for missing message
	    $TLINONE = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tlinoneend') {		# End markup for missing msg
	    $TLINONEEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tlitxt') {		# Thread idx list item
	    $TLITXT = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tliend') {		# Thread idx list item end
	    $TLIEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'toplinks') {		# Top links in message
	    $TOPLINKS = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tslice') {
	    ($TSliceNBefore, $TSliceNAfter, $TSliceInclusive) =
		&get_list_content($handle, $elem);
	    last FMTSW;
	}
	if ($elem eq 'tslicebeg') {		# Start of thread slice
	    $TSLICEBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tsliceend') {		# End of thread slice
	    $TSLICEEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tslicelevels') {		# Level of slice threading
	    if (($tmp = &get_elem_int($handle, $elem, 1)) ne '') {
		$TSLICELEVELS = $tmp;
	    }
	    last FMTSW;
	}
        if ($elem eq 'tslicesingletxt') {
          $TSLICESINGLETXT = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicetopbegin') {
          $TSLICETOPBEG = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicetopend') {
          $TSLICETOPEND = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicesublistbeg') {
          $TSLICESUBLISTBEG = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicesublistend') {
          $TSLICESUBLISTEND = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicelitxt') {
          $TSLICELITXT = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tsliceliend') {
          $TSLICELIEND = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicelinone') {
          $TSLICELINONE = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicelinoneend') {
          $TSLICELINONEEND = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicesubjectbeg') {
          $TSLICESUBJECTBEG = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicesubjectend') {
          $TSLICESUBJECTEND = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tsliceindentbegin') {
          $TSLICEINDENTBEG = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tsliceindentend') {
          $TSLICEINDENTEND = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicecontbegin') {
          $TSLICECONTBEG = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicecontend') {
          $TSLICECONTEND = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicesingletxtcur') {
          $TSLICESINGLETXTCUR = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicetopbegincur') {
          $TSLICETOPBEGCUR = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicetopendcur') {
          $TSLICETOPENDCUR = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tslicelitxtcur') {
          $TSLICELITXTCUR = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
        if ($elem eq 'tsliceliendcur') {
          $TSLICELIENDCUR = &get_elem_content($handle, $elem, $chop);
          last FMTSW;
        }
	if ($elem eq 'tsort') {			# Date order for threads
	    $TNOSORT = 0; $TSUBSORT = 0;
	    last FMTSW;
	}
	if ($elem eq 'tsubsort') {		# Subject order for threads
	    $TNOSORT = 0; $TSUBSORT = 1;
	    last FMTSW;
	}
	if ($elem eq 'tsublistbeg') {		# List begin in sub-thread
	    $TSUBLISTBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tsublistend') {		# List end in sub-thread
	    $TSUBLISTEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tsubjectbeg') {		# Begin markup for sub thread
	    $TSUBJECTBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tsubjectend') {		# End markup for sub thread
	    $TSUBJECTEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tsingletxt') {		# Markup for single msg
	    $TSINGLETXT = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'ttopbegin') {		# Begin for top of a thread
	    $TTOPBEG = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'ttopend') {		# End for a thread
	    $TTOPEND = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'ttitle') {		# Title of threaded idx
	    $TTITLE = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'thread') {		# Create thread index
	    $THREAD = 1; last FMTSW;
	}
	if ($elem eq 'tnextbutton') {		# Thread Next button link
	    $TNEXTBUTTON = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tnextbuttonia') {
	    $TNEXTBUTTONIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tnextinbutton') {	# Within Thread Next button link
	    $TNEXTINBUTTON = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tnextinbuttonia') {
	    $TNEXTINBUTTONIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tnextinlink') {	# Within Thread Next link
	    $TNEXTINLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tnextinlinkia') {
	    $TNEXTINLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tnextlink') {	# Thread Next link
	    $TNEXTLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tnextlinkia') {
	    $TNEXTLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tnextpglink') {		# Thread next page link
	    $TNEXTPGLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tnextpglinkia') {
	    $TNEXTPGLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevbutton') {		# Thread Prev button link
	    $TPREVBUTTON = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevbuttonia') {
	    $TPREVBUTTONIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevinbutton') {	# Within thread previous button
	    $TPREVINBUTTON = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevinbuttonia') {
	    $TPREVINBUTTONIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevinlink') {	# Within thread previous link
	    $TPREVINLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevinlinkia') {
	    $TPREVINLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevlink') {		# Thread previous link
	    $TPREVLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevlinkia') {
	    $TPREVLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevpglink') {		# Thread previous page link
	    $TPREVPGLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevpglinkia') {
	    $TPREVPGLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'treverse') {		# Reverse order of threads
	    $TREVERSE = 1; last FMTSW;
	}
	if ($elem eq 'tnexttopbutton') {	# Next thread button
	    $TNEXTTOPBUTTON = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tnexttopbuttonia') {
	    $TNEXTTOPBUTTONIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tnexttoplink') {		# Next thread link
	    $TNEXTTOPLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tnexttoplinkia') {
	    $TNEXTTOPLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevtopbutton') {	# Previous thread button
	    $TPREVTOPBUTTON = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevtopbuttonia') {
	    $TPREVTOPBUTTONIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevtoplink') {		# Previous thread link
	    $TPREVTOPLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'tprevtoplinkia') {
	    $TPREVTOPLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'ttopbutton') {		# Top of thread button
	    $TTOPBUTTON = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'ttopbuttonia') {
	    $TTOPBUTTONIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'ttoplink') {		# Top of thread link
	    $TTOPLINK = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'ttoplinkia') {
	    $TTOPLINKIA = &get_elem_content($handle, $elem, $chop);
	    last FMTSW;
	}
	if ($elem eq 'umask') {		# Umask of process
	    if ($line = &get_elem_last_line($handle, $elem)) {
		$line =~ s/\s//g;
		$UMASK = $line;
	    }
	    last FMTSW;
	}
	if ($elem eq 'uselocaltime') {		# Use localtime for day groups
	    $UseLocalTime = 1; last FMTSW;
	}
	if ($elem eq 'usinglastpg') {
	    $UsingLASTPG = 1; last FMTSW;
	}
	if ($elem eq 'varregex') {		# Regex matching rc vars
	    $tmp = &get_elem_last_line($handle, $elem);
	    # only take value if not blank
	    $VarExp = $tmp  if $tmp =~ /\S/;
	    last FMTSW;
	}
	if ($elem eq 'weekdays') {		# Full weekday name
	    @a = &get_list_content($handle, $elem);
	    if (scalar(@a)) {
		@Weekdays = @a;
	    }
	    last FMTSW;
	}
	if ($elem eq 'weekdaysabr') {		# Abbreviated weekday name
	    @a = &get_list_content($handle, $elem);
	    if (scalar(@a)) {
		@weekdays = @a;
	    }
	    last FMTSW;
	}

      } ## End FMTSW
    }
# CPU2006
    #close($handle);
    1;
}

##----------------------------------------------------------------------
sub get_elem_content {
    my($filehandle, $gi, $chop) = @_;
    my($ret) = '';

# CPU2006
    #while (<$filehandle>) {
    while (defined($_ = shift(@$filehandle))) {
	last  if /^\s*<\/$gi\s*>/i;
	$ret .= $_;
    }
    $ret =~ s/\r?\n?$//  if $chop;
    $ret;
}

##----------------------------------------------------------------------
sub get_elem_int {
    my($filehandle, $gi, $abs) = @_;
    my($ret) = '';

# CPU2006
    #while (<$filehandle>) {
    while (defined($_ = shift(@$filehandle))) {
	last  if /^\s*<\/$gi\s*>/i;
	next  unless /^\s*[-+]?\d+\s*$/;
	s/[+\s]//g;
	s/-//  if $abs;
	$ret = $_;
    }
    $ret;
}

##----------------------------------------------------------------------
sub get_elem_last_line {
    my($filehandle, $gi) = @_;
    my($ret) = '';

# CPU2006
    #while (<$filehandle>) {
    while (defined($_ = shift(@$filehandle))) {
	last  if /^\s*<\/$gi\s*>/i;
	next  unless /\S/;
	$ret = $_;
    }
    $ret =~ s/\r?\n?$//;
    $ret;
}

##----------------------------------------------------------------------
sub get_list_content {
    my($filehandle, $gi) = @_;
    my(@items) = ();

# CPU2006
    #while (<$filehandle>) {
    while (defined($_ = shift(@$filehandle))) {
	last  if /^\s*<\/$gi\s*>/i;
	next  unless /\S/;
	s/\r?\n?$//;
	push(@items, split(/[:;]/, $_));
    }
    @items;
}

##----------------------------------------------------------------------
sub get_pathname_content {
    my($filehandle, $gi) = @_;
    my(@items) = ();

# CPU2006
    #while (<$filehandle>) {
    while (defined($_ = shift(@$filehandle))) {
	last  if /^\s*<\/$gi\s*>/i;
	next  unless /\S/;
	s/\r?\n?$//;
	push(@items, split(/$PATHSEP/o, $_));
    }
    @items;
}

##---------------------------------------------------------------------------##
1;
