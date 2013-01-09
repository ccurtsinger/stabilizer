##---------------------------------------------------------------------------##
##  File:
##	$Id: CharEnt.pm,v 1.14 2003/03/05 22:17:15 ehood Exp $
##  Author:
##      Earl Hood       earl@earlhood.com
##  Description:
##	POD after __END__
##---------------------------------------------------------------------------##
##    Copyright (C) 1997-2002	Earl Hood, earl@earlhood.com
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

package MHonArc::CharEnt;

use strict;
use MHonArc::CharMaps;
use MHonArc::Char;

##---------------------------------------------------------------------------
##      Charset specification to mapping
##---------------------------------------------------------------------------
##  NOTE: The mapping uses a single name for a charset.
##	  The CHARSETALIASES resource can be used to map aka names (aliases)
##	  to the names used here.
##  NOTE: UTF-8 does not require a map since UTF-8 is decoded straight
##	  to &#xHHHH; entity references.
##  NOTE: iso-2022-{jp,kr} are translated to euc-{jp,kr} first before
##	  conversion.

my %CharsetMaps = (
    'iso-8859-1'     =>	'MHonArc/CharEnt/ISO8859_1.pm',
    'iso-8859-2'     =>	'MHonArc/CharEnt/ISO8859_2.pm',
    'iso-8859-3'     =>	'MHonArc/CharEnt/ISO8859_3.pm',
    'iso-8859-4'     =>	'MHonArc/CharEnt/ISO8859_4.pm',
    'iso-8859-5'     =>	'MHonArc/CharEnt/ISO8859_5.pm',
    'iso-8859-6'     =>	'MHonArc/CharEnt/ISO8859_6.pm',
    'iso-8859-7'     =>	'MHonArc/CharEnt/ISO8859_7.pm',
    'iso-8859-8'     =>	'MHonArc/CharEnt/ISO8859_8.pm',
    'iso-8859-9'     =>	'MHonArc/CharEnt/ISO8859_9.pm',
    'iso-8859-10'    =>	'MHonArc/CharEnt/ISO8859_10.pm',
    'iso-8859-11'    =>	'MHonArc/CharEnt/ISO8859_11.pm',
    'iso-8859-13'    =>	'MHonArc/CharEnt/ISO8859_13.pm',
    'iso-8859-14'    =>	'MHonArc/CharEnt/ISO8859_14.pm',
    'iso-8859-15'    =>	'MHonArc/CharEnt/ISO8859_15.pm',
    'iso-8859-16'    =>	'MHonArc/CharEnt/ISO8859_16.pm',
    'cp866'	     =>	'MHonArc/CharEnt/CP866.pm',
    'cp949'	     =>	'MHonArc/CharEnt/CP949.pm', # euc-kr
    'cp932'	     =>	'MHonArc/CharEnt/CP932.pm', # shiftjis
    'cp936'	     =>	'MHonArc/CharEnt/CP936.pm', # GBK
    'cp950'	     =>	'MHonArc/CharEnt/CP950.pm',
    'cp1250'	     =>	'MHonArc/CharEnt/CP1250.pm',
    'cp1251'	     =>	'MHonArc/CharEnt/CP1251.pm',
    'cp1252'	     =>	'MHonArc/CharEnt/CP1252.pm',
    'cp1253'	     =>	'MHonArc/CharEnt/CP1253.pm',
    'cp1254'	     =>	'MHonArc/CharEnt/CP1254.pm',
    'cp1255'	     =>	'MHonArc/CharEnt/CP1255.pm',
    'cp1256'	     =>	'MHonArc/CharEnt/CP1256.pm',
    'cp1257'	     =>	'MHonArc/CharEnt/CP1257.pm',
    'cp1258'	     =>	'MHonArc/CharEnt/CP1258.pm',
    'koi-0'	     =>	'MHonArc/CharEnt/KOI_0.pm',
    'koi-7'	     =>	'MHonArc/CharEnt/KOI_7.pm',
    'koi8-a'	     =>	'MHonArc/CharEnt/KOI8_A.pm',
    'koi8-b'	     =>	'MHonArc/CharEnt/KOI8_B.pm',
    'koi8-e'	     =>	'MHonArc/CharEnt/KOI8_E.pm',
    'koi8-f'	     =>	'MHonArc/CharEnt/KOI8_F.pm',
    'koi8-r'	     =>	'MHonArc/CharEnt/KOI8_R.pm',
    'koi8-u'	     =>	'MHonArc/CharEnt/KOI8_U.pm',
    'gost19768-87'   =>	'MHonArc/CharEnt/GOST19768_87.pm',
    'viscii'	     =>	'MHonArc/CharEnt/VISCII.pm',
    'macarabic'	     =>	'MHonArc/CharEnt/AppleArabic.pm',
    'maccentraleurroman' => 'MHonArc/CharEnt/AppleCenteuro.pm',
    'maccroatian'    =>	'MHonArc/CharEnt/AppleCroatian.pm',
    'maccyrillic'    =>	'MHonArc/CharEnt/AppleCyrillic.pm',
    'macgreek'	     =>	'MHonArc/CharEnt/AppleGreek.pm',
    'machebrew'	     =>	'MHonArc/CharEnt/AppleHebrew.pm',
    'macicelandic'   =>	'MHonArc/CharEnt/AppleIceland.pm',
    'macromanian'    =>	'MHonArc/CharEnt/AppleRomanian.pm',
    'macroman'	     =>	'MHonArc/CharEnt/AppleRoman.pm',
    'macthai'	     =>	'MHonArc/CharEnt/AppleThai.pm',
    'macturkish'     =>	'MHonArc/CharEnt/AppleTurkish.pm',
    'big5-eten'      =>	'MHonArc/CharEnt/BIG5_ETEN.pm',
    'big5-hkscs'     =>	'MHonArc/CharEnt/BIG5_HKSCS.pm',
    'gb2312'         =>	'MHonArc/CharEnt/GB2312.pm',
    'euc-jp'         =>	'MHonArc/CharEnt/EUC_JP.pm',
    'hp-roman8'      =>	'MHonArc/CharEnt/HP_ROMAN8.pm',
);

my $char_maps = MHonArc::CharMaps->new(\%CharsetMaps);

###############################################################################
##	Routines
###############################################################################

sub str2sgml {
    my $data 	 =    shift;
    my $charset  = lc shift;

    my $data_r  = ref($data) ? $data : \$data;
    $charset =~ tr/_/-/;

    # UTF-8 can be converted algorithmically.
    if ($charset eq 'utf-8') {
	_utf8_to_sgml($data_r);
	return $$data_r;
    }
    # If us-ascii, use simple s/// operation.
    if ($charset eq 'us-ascii') {
	$$data_r =~ s/([$HTMLSpecials])/$HTMLSpecials{$1}/go;
	return $$data_r;
    }

    MHonArc::Char::map_conv($data_r, $charset, $char_maps, \%HTMLSpecials);
}

##---------------------------------------------------------------------------##
##  Private Routines.

# Array of masks for lead byte in UTF-8 (for Perl <5.6)
# This could be computed on-the-fly, but using an array is faster
my @utf8_lb_mask = (
    0x3F, 0x1F, 0xF, 0x7, 0x3, 0x1  # 1, 2, 3, 4, 5, 6 bytes, respectively
);
# Regex pattern for UTF-8 data
my $utf8_re = q/([\x00-\x7F]|
		 [\xC0-\xDF][\x80-\xBF]|
		  \xE0      [\xA0-\xBF][\x80-\xBF]|
		 [\xE1-\xEF][\x80-\xBF]{2}|
		  \xF0      [\x90-\xBF][\x80-\xBF]{2}|
		 [\xF1-\xF7][\x80-\xBF]{3}|
		  \xF8      [\x88-\xBF][\x80-\xBF]{3}|
		 [\xF9-\xFB][\x80-\xBF]{4}|
		  \xFC      [\x84-\xBF][\x80-\xBF]{4}|
		  \xFD      [\x80-\xBF]{5}|
		 .)/;

sub _utf8_to_sgml {
    my $data_r = shift;

    if ($] >= 5.006) {
	# UTF-8-aware perl
	my($char);
	$$data_r =~ s{
	    $utf8_re
	}{
	    (($char = unpack('U',$1)) <= 0x7F)
	      ? $HTMLSpecials{$1} || $1
	      : sprintf('&#x%X;',$char);
	}gxeso;

    } else {
	# non-UTF-8-aware perl
	my($i, $n, $char);
	$$data_r =~ s{
	    $utf8_re
	}{
	    if (($n = length($1)) == 1) {
		$HTMLSpecials{$1} || $1;
	    } else {
		$char = (unpack('C',substr($1,0,1)) &
			 $utf8_lb_mask[$n-1]) << ($n-1)*6;
		for ($i=1; $i < $n; ++$i) {
		    $char |= ((unpack('C',substr($1,$i,1)) & 0x3F) <<
			     (($n-$i-1)*6));
		}
		sprintf('&#x%X;',$char);
	    }
       }gxseo;
    }
}

##---------------------------------------------------------------------------##
1;
__END__

=head1 NAME

MHonArc::CharEnt - HTML Character routines for MHonArc.

=head1 SYNOPSIS

  use MHonArc::CharEnt;

  MHonArc resource file:

    <CharsetConverters>
    ...
    iso-8859-15;    MHonArc::CharEnt::str2sgml;     MHonArc/CharEnt.pm
    ...
    </CharsetConverters>

=head1 DESCRIPTION

MHonArc::CharEnt provides the main character conversion routine
used by MHonArc for converting non-ASCII encoded message header data
and text/plain character data into HTML.  This module was initially
written to just support 8-bit only charsets.  However, it has been
extended to support multibyte charsets.

All characters are mapped to HTML 4.0 character entity references
(e.g. &lt; &gt;) or to Unicode numeric character entity references
(e.g. &#x203E;).  Most modern browsers will support the Unicode
references directly.

=head1 NOTES

=over

=item *

This module relies on MHonArc's CHARSETALIASES resource for defining
alternate names for charset supported.

=item *

Most character conversion is done through mapping tables that
are dynamicly loaded on a as-needed basis.  There is probably
room for optimization by trying to replace tables for charsets
with algorithmic conversion solutions.

UTF-8 conversion is done algorithmically.

=item *

A main goal of this module is to convert raw non-ASCII data of
various character sets to ASCII data using entity references for
non-ASCII characters.  This way, archive files will all be in ASCII,
with modern compliant HTML browsers being able to handle the rendering
of non-ASCII characters from the standard named and numeric character
entity references.

This does make reading the raw HTML source for non-English languages
difficult, but this may be a non-issue with most users.

=back

=head1 VERSION

$Id: CharEnt.pm,v 1.14 2003/03/05 22:17:15 ehood Exp $

=head1 AUTHOR

Earl Hood, earl@earlhood.com

MHonArc comes with ABSOLUTELY NO WARRANTY and MHonArc may be copied only
under the terms of the GNU General Public License, which may be found in
the MHonArc distribution.

=cut

