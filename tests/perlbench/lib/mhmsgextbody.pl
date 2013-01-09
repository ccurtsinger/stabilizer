##---------------------------------------------------------------------------##
##  File:
##	$Id: mhmsgextbody.pl,v 1.4 2003/01/18 02:58:12 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##	Library defines routine to filter message/external-body parts to
##	HTML for MHonArc.
##	Filter routine can be registered with the following:
##          <MIMEFILTERS>
##          message/external-body;m2h_msg_extbody::filter;mhmsgextbody.pl
##          </MIMEFILTERS>
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1999-2001	Earl Hood, mhonarc@mhonarc.org
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

package m2h_msg_extbody;

##---------------------------------------------------------------------------##
##	message/external-body filter for MHonArc.
##	The following filter arguments are recognized ($args):
##
##	local-file	Support local-file access-type.  This option
##			is best used for internal local mail archives
##			where it is known that readers will have
##			direct access to the file.
##
sub filter {
    my($fields, $data, $isdecode, $args) = @_;
    $args = ''  unless defined $args;

    # grab content-type
    my $ctype = $fields->{'content-type'}[0];
    return ''  unless $ctype =~ /\S/;

    # parse argument string
    my $b_lfile = $args =~ /\blocal-file\b/i;

    my $ret = '';
    my $parms = readmail::MAILparse_parameter_str($ctype, 1);
    my $access_type = lc $parms->{'access-type'}{'value'};
       $access_type =~ s/\s//g;
    my $cdesc = mhonarc::htmlize($fields->{'content-description'}[0]) || '';

    $$data =~ s/\A\s+//;
    my $dfields = readmail::MAILread_header($data);
    my $dctype  = mhonarc::htmlize($dfields->{'content-type'}[0]) || '';
    my $dmd5 	= mhonarc::htmlize($dfields->{'content-md5'}[0]) || '';
    my $size 	= mhonarc::htmlize($parms->{'size'}{'value'}) || '';
    my $expires	= mhonarc::htmlize($parms->{'expiration'}{'value'}) || '';
    my $name	= $parms->{'name'}{'value'} || '';

    ATYPE: {
	## FTP, TFTP, ANON-FTP
	if ( $access_type eq 'ftp' ||
	     $access_type eq 'anon-ftp' ||
	     $access_type eq 'tftp' ||
	     $access_type eq 'http' ||
	     $access_type eq 'x-http' ) {

	    my $site 	 = $parms->{'site'}{'value'} ||
			   $parms->{'host'}{'value'} || '';

	    my $port 	 = $parms->{'port'}{'value'} || '';
	       $port	 = ':'.$port  if $port ne '';

	    my $dir 	 = $parms->{'directory'}{'value'} ||
			   $parms->{'path'}{'value'} || '';
	       $dir	 = '/'.$dir  unless $dir =~ m|^/| || $dir eq '';

	    my $mode 	 = $parms->{'mode'}{'value'} || '';

	    my $proto	 = ($access_type eq 'x-http' || $access_type eq 'http')
			   ? 'http'
			   : ($access_type eq 'tftp')
			     ? 'tftp'
			     : 'ftp';
	    my $url	 = $proto . '://' .
			   mhonarc::urlize($site.$port) .
			   $dir . '/' .
			   mhonarc::urlize_path($name);
	    $ret	 = '<dl><dt>';
	    $ret	.= qq|<em>$cdesc</em><br>\n| if $cdesc;
	    $ret	.= qq|<a href="$url">&lt;$url&gt;</a></dt><dd>\n|;
	    $ret	.= qq|Content-type: <tt>$dctype</tt><br>\n|
			    if $dctype;
	    $ret	.= qq|MD5: <tt>$dmd5</tt><br>\n|
			    if $dmd5;
	    $ret	.= qq|Size: $size bytes<br>\n|
			    if $size;
	    $ret	.= qq|Transfer-mode: <tt>$mode</tt><br>\n|
			    if $mode;
	    $ret	.= qq|Expires: <tt>$expires</tt><br>\n|
			    if $expires;
	    $ret	.= qq|Username/password may be required.<br>\n|
			    if $access_type eq 'ftp';
	    $ret	.= "</dd></dl>\n";
	    last ATYPE;
	}

	## Local file
	if ($access_type eq 'local-file') {
	    last ATYPE  unless $b_lfile;
	    my $site 	 = $parms->{'site'}{'value'} || '';
	    my $url	 = 'file://' . mhonarc::urlize_path($name);
	    $ret	 = '<dl><dt>';
	    $ret	.= qq|<em>$cdesc</em><br>\n|  if $cdesc;
	    $ret	.= qq|<a href="$url">&lt;$url&gt;</a></dt><dd>\n|;
	    $ret	.= qq|Content-type: <tt>$dctype</tt><br>\n|
			    if $dctype;
	    $ret	.= qq|MD5: <tt>$dmd5</tt><br>\n|
			    if $dmd5;
	    $ret	.= qq|Size: $size bytes<br>\n|  	if $size;
	    $ret	.= qq|Expires: <tt>$expires</tt><br>\n|
			    if $expires;
	    $ret	.= qq|File accessible from the following domain: | .
			   qq|$site<br>\n|  if $site;
	    $ret	.= "</dd></dl>\n";
	    last ATYPE;
	}

	## Mail server
	if ($access_type eq 'mail-server') {
	    # not supported
	    last ATYPE;
	}

	## URL
	if ($access_type eq 'url') {
	    my $url 	 = $parms->{'url'}{'value'};
	       $url =~ s/[\s<>]+//g;
	       $url =~ s/javascript/_javascript_/ig;
	    $ret	 = '<dl><dt>';
	    $ret	.= qq|<em>$cdesc</em><br>\n|  if $cdesc;
	    $ret	.= qq|<a href="$url">&lt;$url&gt;</a></dt><dd>\n|;
	    $ret	.= qq|Content-type: <tt>$dctype</tt><br>\n|
			    if $dctype;
	    $ret	.= qq|MD5: <tt>$dmd5</tt><br>\n|
			    if $dmd5;
	    $ret	.= qq|Size: $size bytes<br>\n|
			    if $size;
	    $ret	.= qq|Expires: <tt>$expires</tt><br>\n|
			    if $expires;
	    $ret	.= "</dd></dl>\n";
	    last ATYPE;
	}

	last ATYPE;
    }

    ($ret);
}

##---------------------------------------------------------------------------##
1;
