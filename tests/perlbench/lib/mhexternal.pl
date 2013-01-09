##---------------------------------------------------------------------------##
##  File:
##	$Id: mhexternal.pl,v 2.17 2003/08/07 05:49:47 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##	Library defines a routine for MHonArc to filter content-types
##	that cannot be directly filtered into HTML, but a linked to an
##	external file.
##
##	Filter routine can be registered with the following:
##
##		<MIMEFILTERS>
##		*/*:m2h_external'filter:mhexternal.pl
##		</MIMEFILTERS>
##
##	Where '*/*' represents various content-types.  See code below for
##	all types supported.
##
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

package m2h_external;

##---------------------------------------------------------------------------
##	Filter routine.
##
##	Argument string may contain the following values.  Each value
##	should be separated by a space:
##
##	excludeexts="ext1,ext2,..."
##			A comma separated list of message specified filename
##			extensions to exclude.  I.e.  If the filename
##			extension matches an extension in excludeexts,
##			the content will not be written.  The return
##			markup will contain the name of the attachment,
##			but no link to the data.  This option is best
##			used with application/octet-stream to exclude
##			unwanted data that is not tagged with the proper
##			content-type.  The m2h_null::filter can be used
##			to exclude content by content-type.
##
##			Applicable when content-type not image/* and
##			usename or usenameext is in effect.
##
##	ext=ext 	Use `ext' as the filename extension.
##
##	forceattach 	Never inline image data.
##
##	forceinline 	Inline image data, always
##
##	frame		Draw a frame around the attachment link.
##
##	iconurl="url"	Use "url" for location of icon to use.
##			The quotes are required around the url.
##
##	inline  	Inline image data by default if
##			content-disposition not defined.
##
##	inlineexts="ext1,ext2,..."
##			A comma separated list of message specified filename
##			extensions to treat as possible inline data.
##			Applicable when content-type not image/* and
##			usename or usenameext is in effect.
##
##	subdir		Place derived files in a subdirectory
##
##      target=name     Set TARGET attribute for anchor link to file.
##			Defaults to not defined.
##
##	type="description"
##			Use "description" as type description of the
##			data.  The double quotes are required.
##
##	useicon		Include an icon as part of the link to the
##			extracted file.  Url for icon is obtained
##			ICONS resource or from the iconurl option.
##
##	usename 	Use (file)name attribute for determining name
##			of derived file.  Use this option with caution
##			since it can lead to filename conflicts and
##			security problems.
##
##	usenameext 	Use (file)name attribute for determining the
##			extension for the derived file.  Use this option
##			with caution since it can lead to security
##			problems.
##
sub filter {
    my($fields, $data, $isdecode, $args) = @_;
    my($ret, $filename, $urlfile);
    require 'mhmimetypes.pl';

    ## Init variables
    $args	   = ''  unless defined($args);
    my $name	   = '';
    my $ctype	   = '';
    my $type	   = '';
    my $ext	   = '';
    my $inline	   =  0;
    my $inext	   = '';
    my $intype	   = '';
    my $target	   = '';
    my $path       = '';
    my $subdir     = $args =~ /\bsubdir\b/i;
    my $usename    = $args =~ /\busename\b/i;
    my $usenameext = $args =~ /\busenameext\b/i;
    my $debug      = $args =~ /\bdebug\b/i;
    my $inlineexts = '';
    my $excexts    = '';
    if ($args =~ /\binlineexts=(\S+)/) {
	$inlineexts = join("", ',', lc($1), ',');
	$inlineexts =~ s/['"]//g;
    }
    if ($args =~ /\bexcludeexts=(\S+)/) {
	$excexts = join("", ',', lc($1), ',');
	$excexts =~ s/['"]//g;
	&debug("Exclude extensions: $excexts") if $debug;
    }

    ## Get content-type
    if (!defined($ctype = $fields->{'x-mha-content-type'})) {
	($ctype) = $fields->{'content-type'}[0] =~ m%^\s*([\w\-\./]+)%;
	$ctype =~ tr/A-Z/a-z/;
    }
    $type = (mhonarc::get_mime_ext($ctype))[1];

    ## Get disposition
    my($disp, $nameparm, $raw_name, $html_name) =
	readmail::MAILhead_get_disposition($fields, 1);
    $name = $nameparm  if $usename;
    &debug("Content-type: $ctype",
	   "Disposition: $disp; filename=$nameparm",
	   "Arg-string: $args")  if $debug;

    ## Get filename extension in disposition
    my $dispext = '';
    if ($nameparm && ($nameparm !~ /^\./) && ($nameparm =~ /\.(\w+)$/)) {
      $dispext = lc $1;
      &debug("Disposition filename extension: $dispext") if $debug;
    }

    ## Check if content is excluded based on filename extension
    if ($excexts && index($excexts, ",$dispext,") >= $[) {
      return (qq|<p><tt>&lt;&lt;attachment: |.
	      mhonarc::htmlize($nameparm).
	      qq|&gt;&gt;</tt></p>\n|);
    }

    ## Check if file goes in a subdirectory
    $path = join('', $mhonarc::MsgPrefix, $mhonarc::MHAmsgnum)
	if $subdir;

    ## Check if extension and type description passed in
    if ($args =~ /\bext=(\S+)/i)      { $inext  = $1;  $inext =~ s/['"]//g; }
    if ($args =~ /\btype="([^"]+)"/i) { $intype = $1; }

    ## Check if utilizing extension from mail header defined filename
    if ($dispext && $usenameext) {
	$inext = $1;
    }

    ## Check if inlining (images only)
    INLINESW: {
	if ($args =~ /\bforceattach\b/i) {
	    $inline = 0;
	    last INLINESW;
	}
	if ($args =~ /\bforceinline\b/i) {
	    $inline = 1;
	    last INLINESW;
	}
	if ($disp) {
	    $inline = ($disp =~ /\binline\b/i);
	    last INLINESW;
	}
	$inline = ($args =~ /\binline\b/i);
    }

    ## Check if target specified
    if    ($args =~ /target="([^"]+)"/i) { $target = $1; }
    elsif ($args =~ /target=(\S+)/i)     { $target = $1; }
    $target =~ s/['"]//g;
    $target = qq/ TARGET="$target"/  if $target;

    ## Write file
    $filename =
	mhonarc::write_attachment($ctype, $data, $path, $name, $inext);
    ($urlfile = $filename) =~
	s/([^\w.\-\/])/sprintf("%%%X",unpack("C",$1))/ge;
    &debug("File-written: $filename")  if $debug;

    ## Check if inlining when CT not image/*
    if ($inline && ($ctype !~ /\bimage/i)) {
	if ($inlineexts && ($usename || $usenameext) &&
		($filename =~ /\.(\w+)$/)) {
	    my $fext = lc($1);
	    $inline = 0  if (index($inlineexts, ",$fext,") < $[);
	} else {
	    $inline = 0;
	}
    }

    ## Create HTML markup
    if ($inline) {
	$ret  = '<p>'.
		mhonarc::htmlize($fields->{'content-description'}[0]).
		"</p>\n"
	    if (defined $fields{'content-description'});
	$ret .= qq|<p><a href="$urlfile" $target><img src="$urlfile" | .
		qq|alt="$type"></a></p>\n|;

    } else {
	my $is_mesg = $ctype =~ /^message\//;
	my $desc = '<em>Description:</em> ';
	my $namelabel;

	if ($is_mesg && ($$data =~ /^subject:\s(.+)$/mi)) {
	    #$namelabel = mhonarc::htmlize($1);
	    $namelabel = readmail::MAILdecode_1522_str($1);
	    $desc .= 'Message attachment';
	} else {
	    $desc .= mhonarc::htmlize($fields->{'content-description'}[0]) ||
		     $type;
	    if ($nameparm) {
		#$namelabel = mhonarc::htmlize($nameparm);
		$namelabel = $html_name;
	    } elsif ($filename) {
		$namelabel = $filename;
		$namelabel =~ s/^.*$mhonarc::DIRSEPREX//o;
		mhonarc::htmlize(\$namelabel);
	    } else {
		$namelabel = $ctype;
	    }
	}

	# check if using icon
	my($icon_mu, $iconurl, $iw, $ih);
	if ($args =~ /\buseicon\b/i) {
	    if ($args =~ /\biconurl="([^"]+)"/i) {
		$iconurl = $1;
		if ($iconurl =~ s/\[(\d+)x(\d+)\]//) {
		    ($iw, $ih) = ($1, $2);
		}
	    } else {
		($iconurl, $iw, $ih) = mhonarc::get_icon_url($ctype);
	    }
	    if ($iconurl) {
		$icon_mu  = join('', '<img src="', $iconurl,
				 '" align="left" border=0 alt="Attachment:"');
		$icon_mu .= join('', ' width="',  $iw, '"')  if $iw;
		$icon_mu .= join('', ' height="', $ih, '"')  if $ih;
		$icon_mu .= '>';
	    }
	}
	my $frame = $args =~ /\bframe\b/;
	if (!$frame) {
	    if ($icon_mu) {
	      $ret =<<EOT;

<p><strong><a href="$urlfile" $target>$icon_mu</a>
<a href="$urlfile" $target><tt>$namelabel</tt></a></strong><br>
$desc</p>
EOT
	    } else {
	      $ret =<<EOT;
<p><strong>Attachment:
<a href="$urlfile" $target><tt>$namelabel</tt></a></strong><br>
$desc</p>
EOT
	    }
	} else {
	    if ($icon_mu) {
	      $ret =<<EOT;
<table border="1" cellspacing="0" cellpadding="4">
<tr valign="top"><td><strong><a href="$urlfile" $target>$icon_mu</a>
<a href="$urlfile" $target><tt>$namelabel</tt></a></strong><br>
$desc</td></tr></table>
EOT
	    } else {
	      $ret =<<EOT;
<table border="1" cellspacing="0" cellpadding="4">
<tr><td><strong>Attachment:
<a href="$urlfile" $target><tt>$namelabel</tt></a></strong><br>
$desc</td></tr></table>
EOT
	    }
	}
    }

    # Mark part filtered
    my $cid = $fields->{'content-id'}[0]
	if (defined($fields->{'content-id'}));
    if (defined($cid)) {
	$cid =~ s/[\s<>]//g;
	$cid = 'cid:'.$cid;
    } elsif (defined($fields->{'content-location'})) {
	$cid = $fields->{'content-location'}[0];
	$cid =~ s/['"\s]//g;
    }
    if (defined($cid) && defined($readmail::Cid{$cid})) {
	$readmail::Cid{$cid}->{'filtered'} = 1;
	$readmail::Cid{$cid}->{'uri'} = $filename;
    }

    ($ret, $path || $filename);
}

##---------------------------------------------------------------------------

sub debug {
    local($_);
    foreach (@_) {
	print STDERR "m2h_external: ", $_;
	print STDERR "\n"  unless /\n$/;
    }
}

##---------------------------------------------------------------------------
1;
