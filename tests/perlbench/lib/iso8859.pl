##---------------------------------------------------------------------------##
##  File:
##	$Id: iso8859.pl,v 2.6 2003/01/01 07:57:06 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##	THIS FILE IS DEPRECATED.
##---------------------------------------------------------------------------##
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

package iso_8859;

use MHonArc::CharEnt;

BEGIN {
  *str2sgml = \&MHonArc::CharEnt::str2sgml;
}

##---------------------------------------------------------------------------##
1;
