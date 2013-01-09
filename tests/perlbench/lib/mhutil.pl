##---------------------------------------------------------------------------##
##  File:
##	$Id: mhutil.pl,v 2.27 2003/01/09 23:42:28 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      Utility routines for MHonArc
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1995-1999	Earl Hood, mhonarc@mhonarc.org
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

use MHonArc::RFC822;

## RFC 2369 header fields to check for URLs
%HFieldsList = (
    'list-archive'  	=> 1,
    'list-help'  	=> 1,
    'list-owner'  	=> 1,
    'list-post'  	=> 1,
    'list-subscribe'  	=> 1,
    'list-unsubscribe' 	=> 1,
);

## Header fields that contain addresses
%HFieldsAddr = (
    'apparently-from'	=> 1,
    'apparently-to'	=> 1,
    'bcc'		=> 1,
    'cc'		=> 1,
    'dcc'		=> 1,
    'from'		=> 1,
    'mail-reply-to'	=> 1,
    'original-bcc'	=> 1,
    'original-cc'	=> 1,
    'original-from'	=> 1,
    'original-sender'	=> 1,
    'original-to'	=> 1,
    'reply-to'		=> 1,
    'resent-bcc'	=> 1,
    'resent-cc'		=> 1,
    'resent-from'	=> 1,
    'resent-sender'	=> 1,
    'resent-to'		=> 1,
    'return-path'	=> 1,
    'sender'		=> 1,
    'to'		=> 1,
    'x-envelope'	=> 1,
);

##---------------------------------------------------------------------------
##    Convert message header string to HTML encoded in
##    $readmail::TextEncode encoding.
##
sub htmlize_enc_head {
    my($cnvfunc, $charset) =
	readmail::MAILload_charset_converter($readmail::TextEncode);
    return htmlize($_[0])
	if ($cnvfunc eq '-decode-' || $cnvfunc eq '-ignore-');
    return &$cnvfunc($_[0], $charset);
}

##---------------------------------------------------------------------------
##    Clip text to specified length.
##
sub clip_text {
    my $str      = \shift;  # Prevent unnecessary copy.
    my $len      = shift;   # Clip length
    my $is_html  = shift;   # If entity references should be considered
    my $has_tags = shift;   # If html tags should be stripped

    if (!$is_html) {
      return substr($$str, 0, $len);
    }

    my $text = "";
    my $subtext = "";
    my $html_len = length($$str);
    my($pos, $sublen, $real_len, $semi);
    my $er_len = 0;
    
    for ( $pos=0, $sublen=$len; $pos < $html_len; ) {
	$subtext = substr($$str, $pos, $sublen);
	$pos += $sublen;

	# strip tags
	if ($has_tags) {
	    # Strip full tags
	    $subtext =~ s/<[^>]*>//g;
	    # Check if clipped part of a tag
	    if ($subtext =~ s/<[^>]*\Z//) {
		my $gt = index($$str, '>', $pos);
		$pos = ($gt < 0) ? $html_len : ($gt+1);
	    }
	}

	# check for clipped entity reference
	if (($pos < $html_len) && ($subtext =~ /\&[^;]*\Z/)) {
	    my $semi = index($$str, ';', $pos);
	    if ($semi < 0) {
		# malformed entity reference
		$subtext .= substr($$str, $pos);
		$pos = $html_len;
	    } else {
		$subtext .= substr($$str, $pos, $semi-$pos+1);
		$pos = $semi+1;
	    }
	}

	# compute entity reference lengths to determine "real" character
	# count and not raw character count.
	while ($subtext =~ /(\&[^;]+);/g) {
	    $er_len += length($1);
	}

	$text .= $subtext;

	# done if we have enough
	$real_len = length($text)-$er_len;
	if ($real_len >= $len) {
	    last;
	}
	$sublen = $len - (length($text)-$er_len);
    }
    $text;
}

##---------------------------------------------------------------------------
##	Get an e-mail address from (HTML) $str.
##
sub extract_email_address {
    return ''  unless defined $_[0];
    scalar(MHonArc::RFC822::first_addr_spec(shift));
}

##---------------------------------------------------------------------------
##	Get an e-mail name from $str.
##
sub extract_email_name {
    my @tokens   = MHonArc::RFC822::tokenise(shift);
    my @bare     = ( );
    my $possible = undef;
    my $skip	 = 0;

    my $tok;
    foreach $tok (@tokens) {
	next  if $skip;
	if ($tok =~ /^"/) {   # Quoted string
	    $tok =~ s/^"//;  $tok =~ s/"$//;
	    return $tok;
	}
	if ($tok =~ /^\(/) {  # Comment
	    $tok =~ s/^\(//; $tok =~ s/\)$//;
	    return $tok;
	}
	if ($tok =~ /^<$/) {  # Address spec, skip
	    $skip = 1;
	    next;
	}
	if ($tok =~ /^>$/) {
	    $skip = 0;
	    next;
	}
	push(@bare, $tok);    # Bare name
    }

    my $str;
    if (@bare) {
	$str = join(' ', @bare);
	$str =~ s/@.*//;
	$str =~ s/^\s+//; $str =~ s/\s+$//;
	return $str;
    }
    $str = MHonArc::RFC822::first_addr_spec(@tokens);
    $str =~ s/@.*//;
    $str;
}

##---------------------------------------------------------------------------
##	Routine to sort messages
##
sub sort_messages {
    my($nosort, $subsort, $authsort, $revsort) = @_;
    $nosort   = $NOSORT    if !defined($nosort);
    $subsort  = $SUBSORT   if !defined($subsort);
    $authsort = $AUTHSORT  if !defined($authsort);
    $revsort  = $REVSORT   if !defined($revsort);

    if ($nosort) {
	## Process order
	if ($revsort) {
	    return sort { $IndexNum{$b} <=> $IndexNum{$a} } keys %Subject;
	} else {
	    return sort { $IndexNum{$a} <=> $IndexNum{$b} } keys %Subject;
	}

    } elsif ($subsort) {
	## Subject order
	my(%sub, $idx, $sub);
	use locale;
	eval {
	    my $hs = scalar(%Subject);  $hs =~ s|^[^/]+/||;
	    keys(%sub) = $hs;
	};
	while (($idx, $sub) = each(%Subject)) {
	    $sub = lc $sub;
	    1 while $sub =~ s/$SubReplyRxp//io;
	    $sub =~ s/$SubArtRxp//io;
	    $sub{$idx} = $sub;
	}
	if ($revsort) {
	    return sort { ($sub{$a} cmp $sub{$b}) ||
			  (get_time_from_index($b) <=> get_time_from_index($a))
			} keys %Subject;
	} else {
	    return sort { ($sub{$a} cmp $sub{$b}) ||
			  (get_time_from_index($a) <=> get_time_from_index($b))
			} keys %Subject;
	}
	
    } elsif ($authsort) {
	## Author order
	my(%from, $idx, $from);
	use locale;
	eval {
	    my $hs = scalar(%From);  $hs =~ s|^[^/]+/||;
	    keys(%from) = $hs;
	};
	while (($idx, $from) = each(%From)) {
	    $from = lc extract_email_name($from);
	    $from{$idx} = $from;
	}
	if ($revsort) {
	    return sort { ($from{$a} cmp $from{$b}) ||
			  (get_time_from_index($b) <=> get_time_from_index($a))
			} keys %Subject;
	} else {
	    return sort { ($from{$a} cmp $from{$b}) ||
			  (get_time_from_index($a) <=> get_time_from_index($b))
			} keys %Subject;
	}

    } else {
	## Date order
	if ($revsort) {
	    return sort { (get_time_from_index($b) <=> get_time_from_index($a))
			  || ($IndexNum{$b} <=> $IndexNum{$a})
			} keys %Subject;
	} else {
	    return sort { (get_time_from_index($a) <=> get_time_from_index($b))
			  || ($IndexNum{$a} <=> $IndexNum{$b})
			} keys %Subject;
	}

    }
}

##---------------------------------------------------------------------------
##	Message-sort routines for sort().
##
sub increase_index {
    (&get_time_from_index($a) <=> &get_time_from_index($b)) ||
	($IndexNum{$a} <=> $IndexNum{$b});
}

##---------------------------------------------------------------------------
##	Routine for formating a message number for use in filenames or links.
##
sub fmt_msgnum {
    sprintf("%05d", $_[0]);
}

##---------------------------------------------------------------------------
##	Routine to get filename of a message number.
##
sub msgnum_filename {
    my($fmtstr) = "$MsgPrefix%05d.$HtmlExt";
    $fmtstr .= ".gz"  if $GzipLinks;
    sprintf($fmtstr, $_[0]);
}

##---------------------------------------------------------------------------
##	Routine to get filename of an index
##
sub get_filename_from_index {
    &msgnum_filename($IndexNum{$_[0]});
}

##---------------------------------------------------------------------------
##	Routine to get time component from index
##
sub get_time_from_index {
    (split(/$X/o, $_[0], 2))[0];
}

##---------------------------------------------------------------------------
##	Routine to get annotation of a message
##
sub get_note {
    my $index = shift;
    my $file = join($DIRSEP, get_note_dir(),
			     msgid_to_filename($Index2MsgId{$index}));
# CPU2006
#    if (!open(NOTEFILE, $file)) { return ""; }
#    my $ret = join("", <NOTEFILE>);
#    close NOTEFILE;
    my $fh = file_open($file);
    return '' if (!$fh);
    my $ret = join("", @$fh);
    $ret;
}

##---------------------------------------------------------------------------
##	Routine to determine if a message has an annotation
##
sub note_exists {
    my $index = shift;
# CPU2006
#    -e join($DIRSEP, get_note_dir(),
#		     msgid_to_filename($Index2MsgId{$index}));
  my $fname = join($DIRSEP, get_note_dir(),
		     msgid_to_filename($Index2MsgId{$index}));
  exists($mhonarc_files{$fname});
}

##---------------------------------------------------------------------------
##	Routine to get full pathname to annotation directory
##
sub get_note_dir {
    if (!OSis_absolute_path($NoteDir)) {
	return join($DIRSEP, $OUTDIR, $NoteDir);
    }
    $NoteDir;
}

##---------------------------------------------------------------------------
##	Routine to get lc author name from index
##
sub get_base_author {
    lc extract_email_name($From{$_[0]});
}

##---------------------------------------------------------------------------
##	Determine time from date.  Use %Zone for timezone offsets
##
sub get_time_from_date {
    my($mday, $mon, $yr, $hr, $min, $sec, $zone) = @_;
    my($time) = 0;

    $yr -= 1900  if $yr >= 1900;  # if given full 4 digit year
    $yr += 100   if $yr <= 37;    # in case of 2 digit years
    if (($yr < 70) || ($yr > 137)) {
	warn "Warning: Bad year (", $yr+1900, ") using current\n";
# CPU2006
	#$yr = (localtime(time))[5];
	$yr = 104;
    }

    ## If $zone, grab gmt time, else grab local
# CPU2006
    #if ($zone) {
    if (0 && $zone) {
	$zone =~ tr/a-z/A-Z/;
	$time = &timegm($sec,$min,$hr,$mday,$mon,$yr);

	# try to modify time/date based on timezone
	OFFSET: {
	    # numeric timezone
	    if ($zone =~ /^[\+-]\d+$/) {
		$time -= &zone_offset_to_secs($zone);
		last OFFSET;
	    }
	    # Zone
	    if (defined($Zone{$zone})) {
		# timezone abbrev
		$time += &zone_offset_to_secs($Zone{$zone});
		last OFFSET;

	    }
	    # Zone[+-]DDDD
	    if ($zone =~ /^([A-Z]\w+)([\+-]\d+)$/) {
		$time -= &zone_offset_to_secs($2);
		if (defined($Zone{$1})) {
		    $time += &zone_offset_to_secs($Zone{$1});
		    last OFFSET;
		}
	    }
	    # undefined timezone
	    warn qq|Warning: Unrecognized time zone, "$zone"\n|;
	}

    } else {
# CPU2006
	#$time = &timelocal($sec,$min,$hr,$mday,$mon,$yr);
	$time = &timegm($sec,$min,$hr,$mday,$mon,$yr);
    }
    $time;
}

##---------------------------------------------------------------------------
##	Routine to check if time has expired.
##
sub expired_time {
    ($ExpireTime && (time - $_[0] > $ExpireTime)) ||
    ($_[0] < $ExpireDateTime);
}

##---------------------------------------------------------------------------
##      Get HTML tags for formatting message headers
##
sub get_header_tags {
    my($f) = shift;
    my($ftago, $ftagc, $tago, $tagc);
 
    ## Get user specified tags (this is one funcky looking code)
    $tag = (defined($HeadHeads{$f}) ?
            $HeadHeads{$f} : $HeadHeads{"-default-"});
    $ftag = (defined($HeadFields{$f}) ?
             $HeadFields{$f} : $HeadFields{"-default-"});
    if ($tag) { $tago = "<$tag>";  $tagc = "</$tag>"; }
    else { $tago = $tagc = ''; }
    if ($ftag) { $ftago = "<$ftag>";  $ftagc = "</$ftag>"; }
    else { $ftago = $ftagc = ''; }
 
    ($tago, $tagc, $ftago, $ftagc);
}

##---------------------------------------------------------------------------
##	Format message headers in HTML.
##	$html = htmlize_header($fields_hash_ref);
##
sub htmlize_header {
    my $fields = shift;
    my($key,
       $tago, $tagc,
       $ftago, $ftagc,
       $item,
       @array);
    my($tmp);

    my $mesg = "";
    my %hf = %$fields;
    foreach $item (@FieldOrder) {
	if ($item eq '-extra-') {
	    foreach $key (sort keys %hf) {
		next  if $FieldODefs{$key};
		next  if $key =~ /^x-mha-/;
		delete $hf{$key}, next  if &exclude_field($key);

		@array = @{$hf{$key}};
		foreach $tmp (@array) {
		    $tmp = $HFieldsList{$key} ? mlist_field_add_links($tmp) :
						&$MHeadCnvFunc($tmp);
		    $tmp = field_add_links($key, $tmp, $fields);
		    ($tago, $tagc, $ftago, $ftagc) = get_header_tags($key);
		    $mesg .= join('', $LABELBEG,
				  $tago, htmlize(ucfirst($key)), $tagc,
				  $LABELEND,
				  $FLDBEG, $ftago, $tmp, $ftagc, $FLDEND,
				  "\n");
		}
		delete $hf{$key};
	    }
	} else {
	    if (!&exclude_field($item) && $hf{$item}) {
		@array = @{$hf{$item}};
		foreach $tmp (@array) {
		    $tmp = $HFieldsList{$item} ? mlist_field_add_links($tmp) :
						 &$MHeadCnvFunc($tmp);
		    $tmp = field_add_links($item, $tmp, $fields);
		    ($tago, $tagc, $ftago, $ftagc) = &get_header_tags($item);
		    $mesg .= join('', $LABELBEG,
				  $tago, htmlize(ucfirst($item)), $tagc,
				  $LABELEND,
				  $FLDBEG, $ftago, $tmp, $ftagc, $FLDEND,
				  "\n");
		}
	    }
	    delete $hf{$item};
	}
    }
    if ($mesg) { $mesg = $FIELDSBEG . $mesg . $FIELDSEND; }
    $mesg;
}

##---------------------------------------------------------------------------

sub mlist_field_add_links {
    my $txt	= shift;
    my $ret	= "";
    local($_);
    foreach (split(/(<[^>]+>)/, $txt)) {
	if (/^<\w+:/) {
	    chop; substr($_, 0, 1) = "";
	    $ret .= qq|&lt;<a href="$_">$_</a>&gt;|;
	} else {
	    $ret .= &$MHeadCnvFunc($_);
	}
    }
    $ret;
}

##---------------------------------------------------------------------------
##	Routine to add mailto/news links to a message header string.
##
sub field_add_links {
    my $label = lc shift;
    my $fld_text = shift;
    my $fields	 = shift;

    LBLSW: {
	if ($HFieldsAddr{$label}) {
	    if (!$NOMAILTO) {
		$fld_text =~ s{($HAddrExp)}
			      {&mailUrl($1, $fields->{'x-mha-message-id'},
					    $fields->{'x-mha-subject'},
					    $fields->{'x-mha-from'});
			      }gexo;
	    } else {
		$fld_text =~ s{($HAddrExp)}
			      {&htmlize(&rewrite_address($1))
			      }gexo;
	    }
	    last LBLSW;
	}
	if (!$NONEWS && ($label eq 'newsgroup' || $label eq 'newsgroups')) {
	    $fld_text = newsurl($fld_text);
	    last LBLSW;
	}
	last LBLSW;
    }
    $fld_text;
}


##---------------------------------------------------------------------------
##	Routine to add news links of newsgroups names
##
sub newsurl {
    my $str = shift;
    my $h = "";

    if ($str =~ s/^([^:]*:\s*)//) {
	$h = $1;
    }
    $str =~ s/\s//g;			# Strip whitespace
    my @groups = split(/,/, $str);	# Split groups
    foreach (@groups) {			# Make hyperlinks
	s|(.*)|<a href="news:$1">$1</a>|;
    }
    $h . join(', ', @groups);	# Rejoin string
}

##---------------------------------------------------------------------------
##	$html = mailUrl($email_addr, $msgid, $subject, $from);
##
sub mailUrl {
    my $eaddr = shift || '';
    my $msgid = shift || '';
    my $sub = shift || '';
    my $from = shift || '';
    dehtmlize(\$eaddr);

    local $_;
    my($url) = ($MAILTOURL);
    my($to) = (&urlize($eaddr));
    my($toname, $todomain) = map { urlize($_) } split(/@/,$eaddr,2);
    my($froml, $msgidl) = (&urlize($from), &urlize($msgid));
    my($fromaddrl) = (&extract_email_address($from));
    my($faddrnamel, $faddrdomainl) = map { urlize($_) } split(/@/,$fromaddrl,2);
    $fromaddrl = &urlize($fromaddrl);
    my($subjectl);

    # Add "Re:" to subject if not present
    if ($sub !~ /^$SubReplyRxp/io) {
	$subjectl = 'Re:%20' . &urlize($sub);
    } else {
	$subjectl = &urlize($sub);
    }
    $url =~ s/\$FROM\$/$froml/g;
    $url =~ s/\$FROMADDR\$/$fromaddrl/g;
    $url =~ s/\$FROMADDRNAME\$/$faddrnamel/g;
    $url =~ s/\$FROMADDRDOMAIN\$/$faddrdomainl/g;
    $url =~ s/\$MSGID\$/$msgidl/g;
    $url =~ s/\$SUBJECT\$/$subjectl/g;
    $url =~ s/\$SUBJECTNA\$/$subjectl/g;
    $url =~ s/\$TO\$/$to/g;
    $url =~ s/\$TOADDRNAME\$/$toname/g;
    $url =~ s/\$TOADDRDOMAIN\$/$todomain/g;
    $url =~ s/\$ADDR\$/$to/g;
    qq|<a href="$url">| . &htmlize(&rewrite_address($eaddr)) . q|</a>|;
}

##---------------------------------------------------------------------------##
##	Routine to parse variable definitions in a string.  The
##	function returns a list of variable/value pairs.  The format of
##	the string is similiar to attribute specification lists in
##	SGML, but NAMEs are any non-whitespace character.
##
sub parse_vardef_str {
    my($org) = shift;
    my($lower) = shift;
    my(%hash) = ();
    my($str, $q, $var, $value);

    ($str = $org) =~ s/^\s+//;
    while ($str =~ s/^([^=\s]+)\s*=\s*//) {
	$var = $1;
	if ($str =~ s/^(['"])//) {
	    $q = $1;
	    if (!($q eq "'" ? $str =~ s/^([^']*)'// :
			      $str =~ s/^([^"]*)"//)) {
		warn "Warning: Unclosed quote in: $org\n";
		return ();
	    }
	    $value = $1;

	} else {
	    if ($str =~ s/^(\S+)//) {
		$value = $1;
	    } else {
		warn "Warning: No value after $var in: $org\n";
		return ();
	    }
	}
	$str =~ s/^\s+//;
	$hash{$lower? lc($var): $var} = $value;
    }
    if ($str =~ /\S/) {
	warn "Warning: Trailing characters in: $org\n";
    }
    %hash;
}

##---------------------------------------------------------------------------##

sub msgid_to_filename {
    my $msgid = shift;
    if ($VMS) {
	$msgid =~ s/([^\w\-])/sprintf("=%02X",unpack("C",$1))/geo;
    } else {
	$msgid =~ s/([^\w.\-\@])/sprintf("=%02X",unpack("C",$1))/geo;
    }
    $msgid;
}

##---------------------------------------------------------------------------##
##	Check if new follow up list for a message is different from
##	old follow up list.
##
sub is_follow_ups_diff {
    my $f	= $Follow{$_[0]};
    my $o	= $FollowOld{$_[0]};
    if (defined($f) && defined($o)) {
	return 1  unless @$f == @$o;
	local $^W = 0;
	my $i;
	for ($i=0; $i < @$f; ++$i) {
	    return 1  if $f->[$i] ne $o->[$i];
	}
	return 0;
    }
    return (defined($f) || defined($o));
}

##---------------------------------------------------------------------------##
##	Retrieve icon URL for specified content-type.
##
sub get_icon_url {
    my $ctype = shift;
    my $icon = $Icons{$ctype};
    ICON: {
	last ICON  if defined $icon;
	if ($ctype =~ s|/.*||) {
	  $ctype .= '/*';
	  $icon = $Icons{$ctype};
	  last ICON  if defined $icon;
	}
	$icon = $Icons{'*/*'} || $Icons{'unknown'};
    }
    if (!defined($icon)) {
	return (undef, undef, undef);
    }
    if ($icon =~ s/\[(\d+)x(\d+)\]//) {
	return ($IconURLPrefix.$icon, $1, $2);
    }
    ($IconURLPrefix.$icon, undef, undef);
}

##---------------------------------------------------------------------------##

sub log_mesg {
    my $fh	= shift;
    my $doDate	= shift;

    if ($doDate) {
# CPU2006
	#my($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
	#print $fh sprintf("[%4d-%02d-%02d %02d:%02d:%02d] ",
	#		  $year+1900, $mon+1, $mday, $hour, $min, $sec);
	my($sec,$min,$hour,$mday,$mon,$year) = gmtime(time);
	push @$fh, sprintf("[%4d-%02d-%02d %02d:%02d:%02d] ",
			  $year+1900, $mon+1, $mday, $hour, $min, $sec);
    }
# CPU2006
    #print $fh @_;
    push @$fh, @_;
}

##---------------------------------------------------------------------------##

sub dump_hash {
    my $fh = shift;
    my $h = shift;
    local $_;
    foreach (sort keys %$h) {
# CPU2006
	#print $fh "$_ => ", $h->{$_}, "\n";
	push @$fh, "$_ => ". $h->{$_}. "\n";
    }
}

##---------------------------------------------------------------------------##
1;
