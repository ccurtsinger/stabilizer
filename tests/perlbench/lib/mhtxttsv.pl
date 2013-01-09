##---------------------------------------------------------------------------##
##  File:
##	$Id: mhtxttsv.pl,v 2.5 2003/01/19 01:35:59 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##	Library defines routine to filter text/tab-separated-values body
##	parts to HTML
##	for MHonArc.
##	Filter routine can be registered with the following:
##              <MIMEFILTERS>
##              text/tab-separated-values:m2h_text_plain'filter:mhtxttsv.pl
##              </MIMEFILTERS>
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1998-2001	Earl Hood, mhonarc@mhonarc.org
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

package m2h_text_tsv;

##---------------------------------------------------------------------------##
##	Text/tab-separated-values filter for mhonarc.
##
sub filter {
    my($fields, $data, $isdecode, $args) = @_;
    my($field, $line, $ret);
    local($_);

    $$data =~ s/^\s+//;
    $ret  = "<table border=1>\n";
    foreach $line (split(/\r?\n/, $$data)) {
	$ret .= "<tr>";
	foreach $field (split(/\t/, $line)) {
	    $ret .= '<td>' . mhonarc::htmlize($field) . '</td>';
	}
	$ret .= "</tr>\n";
    }
    $ret .= "</table>\n";
    ($ret);
}

##---------------------------------------------------------------------------##
1;
