##---------------------------------------------------------------------------##
##  File:
##	$Id: mhtxthtml.pl,v 2.34 2003/08/07 21:24:53 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##	Library defines routine to filter text/html body parts
##	for MHonArc.
##	Filter routine can be registered with the following:
##	    <MIMEFILTERS>
##	    text/html:m2h_text_html'filter:mhtxthtml.pl
##	    </MIMEFILTERS>
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1995-2000	Earl Hood, mhonarc@mhonarc.org
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


package m2h_text_html;

# Beginning of URL match expression
my $Url	= '(\w+://|\w+:)';

# Script related attributes: Basically any attribute that starts with "on"
my $SAttr = q/\bon\w+\b/;

# Script/questionable related elements
my $SElem = q/\b(?:applet|base|embed|form|ilayer|input|layer|link|meta|/.
	         q/object|option|param|select|textarea)\b/;

# Elements with auto-loaded URL attributes
my $AElem = q/\b(?:img|body|iframe|frame|object|script|input)\b/;
# URL attributes
my $UAttr = q/\b(?:action|background|cite|classid|codebase|data|datasrc|/.
	         q/dynsrc|for|href|longdesc|lowsrc|profile|src|url|usemap|/.
		 q/vrml)\b/;

# Used to reverse the effects of CHARSETCONVERTERS
my %special_to_char = (
    'lt'    => '<',
    'gt'    => '>',
    'amp'   => '&',
    'quot'  => '"',
);

##---------------------------------------------------------------------------
##	The filter must modify HTML content parts for merging into the
##	final filtered HTML messages.  Modification is needed so the
##	resulting filtered message is valid HTML.
##
##	Arguments:
##
##	allowcomments	Preserve any comment declarations.  Normally
##			Comment declarations are munged to prevent
##			SSI attacks or comments that can conflict
##			with MHonArc processing.  Use this option
##			with care.
##
##	allownoncidurls	Preserve URL-based attributes that are not
##			cid: URLs.  Normally, any URL-based attribute
##			-- href, src, background, classid, data,
##			longdesc -- will be stripped if it is not a
##			cid: URL.  This is to prevent malicious URLs
##			that verify mail addresses for spam purposes,
##			secretly set cookies, or gather some
##			statistical data automatically with the use of
##			elements that cause browsers to automatically
##			fetch data: IMG, BODY, IFRAME, FRAME, OBJECT,
##			SCRIPT, INPUT.
##
##	allowscript	Preserve any markup associated with scripting.
##			This includes elements and attributes related
##			to scripting.  The default is to delete any
##			scripting markup for security reasons.
##
##	attachcheck	Honor attachment disposition.  By default,
##			all text/html data is displayed inline on
##			the message page.  If attachcheck is specified
##			and Content-Disposition specifies the data as
##			an attachment, the data is saved to a file
##			with a link to it from the message page.
##
##	disablerelated	Disable MHTML processing.
##
##	nofont  	Remove <FONT> tags.
##
##	notitle  	Do not print title.
##
##	subdir		Place derived files in a subdirectory
##

# DEVELOPER's NOTE:
#   The script stripping code is probably not complete.  Since a
#   whitelist model is not being used -- because full HTML parsing
#   would be required (and possible reliance on non-standard modules) --
#   Future scripting extensions added to HTML could get by the filtering.
#   The FAQ mentions the problems with HTML messages and recommends
#   disabling HTML in archives.

sub filter {
    my($fields, $data, $isdecode, $args) = @_;
    $args = ''  unless defined $args;

    ## Check if content-disposition should be checked
    if ($args =~ /\battachcheck\b/i) {
	my($disp, $nameparm, $raw) =
	    readmail::MAILhead_get_disposition($fields);
	if ($disp =~ /\battachment\b/i) {
	    require 'mhexternal.pl';
	    return (m2h_external::filter(
		      $fields, $data, $isdecode,
		      readmail::get_filter_args('m2h_external::filter')));
	}
    }

    local(@files) = ();	# XXX: Used by resolve_cid!!!
    my $base 	 = '';
    my $title	 = '';
    my $noscript = 1;
       $noscript = 0  if $args =~ /\ballowscript\b/i;
    my $nofont	 = $args =~ /\bnofont\b/i;
    my $notitle	 = $args =~ /\bnotitle\b/i;
    my $onlycid  = $args !~ /\ballownoncidurls\b/i;
    my $subdir   = $args =~ /\bsubdir\b/i;
    my $norelate = $args =~ /\bdisablerelated\b/i;
    my $allowcom = $args =~ /\ballowcomments\b/i;
    my $atdir    = $subdir ? $mhonarc::MsgPrefix.$mhonarc::MHAmsgnum : "";
    my $tmp;

    my $charset = $fields->{'x-mha-charset'};
    my($charcnv, $real_charset_name) =
	    readmail::MAILload_charset_converter($charset);
    if (defined($charcnv) && defined(&$charcnv)) {
	$$data = &$charcnv($$data, $real_charset_name);
	# translate HTML specials back
	$$data =~ s/&([lg]t|amp|quot);/$special_to_char{$1}/g;
    } elsif ($charcnv ne '-decode-') {
	warn qq/\n/,
	     qq/Warning: Unrecognized character set: $charset\n/,
	     qq/         Message-Id: <$mhonarc::MHAmsgid>\n/,
	     qq/         Message Number: $mhonarc::MHAmsgnum\n/;
    }

    ## Unescape ascii letters to simplify strip code
    dehtmlize_ascii($data);

    ## Get/remove title
    if (!$notitle) {
	if ($$data =~ s|<title\s*>([^<]*)</title\s*>||io) {
	    $title = "<address>Title: <strong>$1</strong></address>\n"
		unless $1 eq "";
	}
    } else {
	$$data =~ s|<title\s*>[^<]*</title\s*>||io;
    }

    ## Get/remove BASE url: The base URL may be defined in the HTML
    ## data or defined in the entity header.
    BASEURL: {
	if ($$data =~ s|(<base\s[^>]*>)||i) {
	    $tmp = $1;
	    if ($tmp =~ m|href\s*=\s*['"]([^'"]+)['"]|i) {
		$base = $1;
	    } elsif ($tmp =~ m|href\s*=\s*([^\s>]+)|i) {
		$base = $1;
	    }
	    last BASEURL  if ($base =~ /\S/);
	} 
	if ((defined($tmp = $fields->{'content-base'}[0]) ||
	       defined($tmp = $fields->{'content-location'}[0])) &&
	       ($tmp =~ m%/%)) {
	    ($base = $tmp) =~ s/['"\s]//g;
	}
    }
    $base =~ s|(.*/).*|$1|;

    ## Strip out certain elements/tags to support proper inclusion:
    ## some browsers are forgiving about dublicating header tags, but
    ## we try to do things right.  It also help minimize XSS exploits.
    $$data =~ s|<head\s*>[\s\S]*</head\s*>||io;
    1 while ($$data =~ s|<!doctype\s[^>]*>||gio);
    1 while ($$data =~ s|</?html\b[^>]*>||gio);
    1 while ($$data =~ s|</?x-html\b[^>]*>||gio);
    1 while ($$data =~ s|</?meta\b[^>]*>||gio);
    1 while ($$data =~ s|</?link\b[^>]*>||gio);

    ## Strip out style information if requested.
    if ($nofont) {
	$$data =~ s|<style[^>]*>.*?</style\s*>||gios;
	1 while ($$data =~ s|</?font\b[^>]*>||gio);
	1 while ($$data =~ s/\b(?:style|class)\s*=\s*"[^"]*"//gio);
	1 while ($$data =~ s/\b(?:style|class)\s*=\s*'[^']*'//gio);
	1 while ($$data =~ s/\b(?:style|class)\s*=\s*[^\s>]+//gio);
	1 while ($$data =~ s|</?style\b[^>]*>||gi);
    }

    ## Strip out scripting markup
    if ($noscript) {
	# remove scripting elements and attributes
	$$data =~ s|<script[^>]*>.*?</script\s*>||gios;
	unless ($nofont) {  # avoid dup work if style already stripped
	    $$data =~ s|<style[^>]*>.*?</style\s*>||gios;
	    1 while ($$data =~ s|</?style\b[^>]*>||gi);
	}
	1 while ($$data =~ s|$SAttr\s*=\s*"[^"]*"||gio); #"
	1 while ($$data =~ s|$SAttr\s*=\s*'[^']*'||gio); #'
	1 while ($$data =~ s|$SAttr\s*=\s*[^\s>]+||gio);
	1 while ($$data =~ s|</?$SElem[^>]*>||gio);
	1 while ($$data =~ s|</?script\b||gi);

	# for netscape 4.x browsers
	$$data =~ s/(=\s*["']?\s*)(?:\&\{)+/$1/g;

	# Neutralize javascript:... URLs: Unfortunately, browsers
	# are stupid enough to recognize a javascript URL with whitespace
	# in it (like tabs and newlines).
	$$data =~ s/\bj\s*a\s*v\s*a\s*s\s*c\s*r\s*i\s*p\s*t/_javascript_/gi;

	# IE has a very unsecure expression() operator extension to
	# CSS, so we have to nuke it also.
	$$data =~ s/\bexpression\b/_expression_/gi;
    }

    ## Modify relative urls to absolute using BASE
    if ($base =~ /\S/) {
        $$data =~ s/($UAttr\s*=\s*['"])([^'"]+)(['"])/
		   join("", $1, &addbase($base,$2), $3)/geoix;
    }
    
    ## Check for frames: Do not support, so just show source
    if ($$data =~ m/<frameset\b/i) {
	$$data = join('', '<pre>', mhonarc::htmlize($$data), '</pre>');
	return ($title.$$data, @files);
    }

    ## Check for body attributes
    if ($$data =~ s|<body\b([^>]*)>||i) {
	require 'mhutil.pl';
	my $a = $1;
	my %attr = mhonarc::parse_vardef_str($a, 1);
	if (%attr) {
	    ## Use a table with a single cell to encapsulate data to
	    ## set visual properties.  We use a mixture of old attributes
	    ## and CSS to set properties since browsers may not support
	    ## all of the CSS settings via the STYLE attribute.
	    my $tpre = '<table width="100%"><tr><td ';
	    my $tsuf = "";
	    $tpre .= qq|background="$attr{'background'}" |
		     if $attr{'background'};
	    $tpre .= qq|bgcolor="$attr{'bgcolor'}" |
		     if $attr{'bgcolor'};
	    $tpre .= qq|style="|;
	    $tpre .= qq|background-color: $attr{'bgcolor'}; |
		     if $attr{'bgcolor'};
	    if ($attr{'background'}) {
		if ($attr{'background'} =
			&resolve_cid($onlycid, $attr{'background'}, $atdir)) {
		    $tpre .= qq|background-image: url($attr{'background'}) |;
		}
	    }
	    $tpre .= qq|color: $attr{'text'}; |
		     if $attr{'text'};
	    $tpre .= qq|a:link { color: $attr{'link'} } |
		     if $attr{'link'};
	    $tpre .= qq|a:active { color: $attr{'alink'} } |
		     if $attr{'alink'};
	    $tpre .= qq|a:visited { color: $attr{'vlink'} } |
		     if $attr{'vlink'};
	    $tpre .= '">';
	    if ($attr{'text'}) {
		$tpre .= qq|<font color="$attr{'text'}">|;
		$tsuf .= '</font>';
	    }
	    $tsuf .= '</td></tr></table>';
	    $$data = $tpre . $$data . $tsuf;
	}
    }
    1 while ($$data =~ s|</?body\b[^>]*>||ig);

    my $ahref_tmp;
    if ($onlycid) {
	# If only cid URLs allowed, we still try to preserve <a href> or
	# any hyperlinks in a document would be stripped out.
	# Algorithm: Replace HREF attribute string in <A>'s with a
	#	     random string.  We then restore HREF after CID
	#	     resolution.  We do not worry about javascript since
	#	     we neutralized it earlier.
	$ahref_tmp = mhonarc::rand_string('alnkXXXXXXXXXX');

	# Make sure "href" not in rand string
	$ahref_tmp =~ s/href/XXXX/gi;

	# Remove occurances of random string from input first.  This
	# should cause nothing to be deleted, but is done to avoid
	# a potential exploit attempt.
	$$data =~ s/\b$ahref_tmp\b//g;

	# Replace all <a href> with <a RAND_STR>.  We make sure to
	# leave cid: attributes alone since they are processed later.
	$$data =~ s/(<a\b[^>]*)href\s*=\s*("(?!\s*cid:)[^"]+")
		   /$1$ahref_tmp=$2/gix;  # double-quoted delim attribute
	$$data =~ s/(<a\b[^>]*)href\s*=\s*('(?!\s*cid:)[^']+')
		   /$1$ahref_tmp=$2/gix;  # single-quoted delim attribute
	$$data =~ s/(<a\b[^>]*)href\s*=\s*((?!['"]?\s*cid:)[^\s>]+)
		   /$1$ahref_tmp=$2/gix;  # non-quoted attribute
    }

    ## Check for CID URLs (multipart/related HTML).  Multiple expressions
    ## exist to handle variations in how attribute values are delimited.
    if ($norelate) {
	if ($onlycid) {
	    $$data =~ s/($UAttr\s*=\s*["])[^"]+(["])/$1$2/goi;
	    $$data =~ s/($UAttr\s*=\s*['])[^']+(['])/$1$2/goi;
	    $$data =~ s/($UAttr\s*=\s*[^\s'">][^\s>]+)/ /goi;
	}
    } else {
	$$data =~ s/($UAttr\s*=\s*["])([^"]+)(["])
		   /join("",$1,&resolve_cid($onlycid, $2, $atdir),$3)/geoix;
	$$data =~ s/($UAttr\s*=\s*['])([^']+)(['])
		   /join("",$1,&resolve_cid($onlycid, $2, $atdir),$3)/geoix;
	$$data =~ s/($UAttr\s*=\s*)([^\s'">][^\s>]+)
		   /join("",$1,'"',&resolve_cid($onlycid, $2, $atdir),'"')
		   /geoix;
    }

    if ($onlycid) {
	# Restore HREF attributes of <A>'s.
	$$data =~ s/\b$ahref_tmp\b/href/g;
    }

    ## Check comment declarations: may screw-up mhonarc processing
    ## and avoids someone sneaking in SSIs.
    if (!$allowcom) {
      #$$data =~ s/<!(?:--(?:[^-]|-[^-])*--\s*)+>//go; # can crash perl
      $$data =~ s/<!--[^-]+[#X%\$\[]*/<!--/g;  # Just mung them (faster)
    }

    ($title.$$data, @files);
}

##---------------------------------------------------------------------------

sub addbase {
    my($b, $u) = @_;
    return $u  if !defined($b) || $b !~ /\S/;

    my($ret);
    $u =~ s/^\s+//;
    if ($u =~ m%^$Url%o || $u =~ m/^#/) {
	## Absolute URL or scroll link; do nothing
        $ret = $u;
    } else {
	## Relative URL
	if ($u =~ /^\./) {
	    ## "./---" or "../---": Need to remove and adjust base
	    ## accordingly.
	    $b =~ s/\/$//;
	    my @a = split(/\//, $b);
	    my $cnt = 0;
	    while ( $cnt <= scalar(@a) &&
		    $u =~ s|^(\.{1,2})/|| ) { ++$cnt  if length($1) == 2; }
	    splice(@a, -$cnt)  if $cnt > 0;
	    $b = join('/', @a, "");

	} elsif ($u =~ m%^/%) {
	    ## "/---": Just use hostname:port of base.
	    $b =~ s%^(${Url}[^/]*)/.*%$1%o;
	}
        $ret = $b . $u;
    }
    $ret;
}

##---------------------------------------------------------------------------

sub resolve_cid {
    my $onlycid   = shift;
    my $cid_in    = shift;
    my $attachdir = shift;
    my $cid	  = $cid_in;

    $cid =~ s/&#(?:x0*40|64);/@/g;
    my $href = $readmail::Cid{$cid};
    if (!defined($href)) {
	my $basename = $cid;
	$basename =~ s/.*\///;
	if (!defined($href = $readmail::Cid{$basename})) {
	    return ""  if $onlycid;
	    return ($cid =~ /^cid:/i)? "": $cid_in;
	}
	$cid = $basename;
    }

    if ($href->{'uri'}) {
	# Part already converted; multiple references to part
	return $href->{'uri'};
    }

    # Get content-type of data and return if type is excluded
    my $ctype = $href->{'fields'}{'x-mha-content-type'};
    if (!defined($ctype)) {
      $ctype = $href->{'fields'}{'content-type'}[0];
      ($ctype) = $ctype =~ m{^\s*([\w\-\./]+)};
    }
    return ""  if readmail::MAILis_excluded($ctype);

    require 'mhmimetypes.pl';
    my $filename;
    my $decodefunc =
	readmail::load_decoder(
	    $href->{'fields'}{'content-transfer-encoding'}[0]);
    if (defined($decodefunc) && defined(&$decodefunc)) {
	my $data = &$decodefunc(${$href->{'body'}});
	$filename = mhonarc::write_attachment(
			    $ctype,
			    \$data,
			    $attachdir);
    } else {
	$filename = mhonarc::write_attachment(
			    $ctype,
			    $href->{'body'},
			    $attachdir);
    }
    $href->{'filtered'} = 1; # mark part filtered for readmail.pl
    $href->{'uri'}      = $filename;

    push(@files, $filename); # @files defined in filter!!
    $filename;
}

##---------------------------------------------------------------------------

sub dehtmlize_ascii {
  my $str = shift;
  my $str_r = ref($str) ? $str : \$str;

  $$str_r =~ s{\&\#(\d+);?}{
      my $n = int($1);
      if (($n >= 7 && $n <= 13) ||
          ($n == 32) || ($n == 61) ||
          ($n >= 48 && $n <= 58) ||
          ($n >= 64 && $n <= 90) ||
          ($n >= 97 && $n <= 122)) {
          pack('C', $n);
      } else {
          '&#'.$1.';'
      }
  }gex;
  $$str_r =~ s{\&\#[xX]([0-9abcdefABCDEF]+);?}{
      my $n = hex($1);
      if (($n >= 7 && $n <= 13) ||
          ($n == 32) || ($n == 61) ||
          ($n >= 48 && $n <= 58) ||
          ($n >= 64 && $n <= 90) ||
          ($n >= 97 && $n <= 122)) {
          pack('C', $n);
      } else {
          '&#x'.$1.';'
      }
  }gex;

  $$str_r;
}

##---------------------------------------------------------------------------

1;
