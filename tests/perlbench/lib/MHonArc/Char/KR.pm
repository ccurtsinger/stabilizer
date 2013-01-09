##---------------------------------------------------------------------------##
##  File:
##	$Id: KR.pm,v 1.1 2002/12/18 05:38:43 ehood Exp $
##  Author:
##      Earl Hood       earl@earlhood.com
##---------------------------------------------------------------------------##
##    Copyright (C) 2002	Earl Hood, earl@earlhood.com
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

package MHonArc::Char::KR;

sub kr_2022_to_euc {
    # implementation of this function plagerized from Encode::KR::2022_KR.
    my $data_r	= shift;
    my($match);
    $data_r =~ s/\e\$\)C//gx;	      # remove the designator
    $data_r =~ s{\x0E		      # replace characters in GL
		 ([^\x0F]*)	      # between SO(\x0e) and SI(\x0f)
		 \x0F}		      # with characters in GR
    {
	$match = $1;
	$match =~ tr/\x21-\x7e/\xa1-\xfe/;
	$match;
    }gex;
}

1;
