##---------------------------------------------------------------------------##
##  File:
##	$Id: mhnull.pl,v 1.8 2003/02/04 23:31:19 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##	Library defines the null filter routine for MHonArc.  Its use
##	is for dropping unwanted data from messages.
##	Filter routine can be registered with the following:
##              <MIMEFILTERS>
##              some-type/some-subtype;m2h_null::filter;mhnull.pl
##              </MIMEFILTERS>
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1998,1999	Earl Hood, mhonarc@mhonarc.org
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

package m2h_null;

sub filter {
    my($fields, $data, $isdecode, $args) = @_;
    my($ctype) = $fields->{'content-type'}[0] =~ m%^\s*([\w\-\./]+)%;
    my($disp, $nameparm, $raw_name, $html_name) =
	readmail::MAILhead_get_disposition($fields, 1);
    join("", '<p><tt>&lt;&lt;',
	     ($disp ? "$disp: " : ""),
	     ($html_name ? $html_name : $ctype),
	     '&gt;&gt;</tt></p>');
}

##---------------------------------------------------------------------------##
1;
