##---------------------------------------------------------------------------##
##  File:
##	$Id: MhaEncode.pm,v 1.3 2003/03/05 22:17:15 ehood Exp $
##  Author:
##      Earl Hood       earl@earlhood.com
##  Description:
##	POD after __END__.
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

package MHonArc::UTF8::MhaEncode;

use strict;
use MHonArc::CharMaps;
use MHonArc::Char;

my %CharsetMaps = (
    'iso-8859-1'     =>	'MHonArc/UTF8/ISO8859_1.pm',
    'iso-8859-2'     =>	'MHonArc/UTF8/ISO8859_2.pm',
    'iso-8859-3'     =>	'MHonArc/UTF8/ISO8859_3.pm',
    'iso-8859-4'     =>	'MHonArc/UTF8/ISO8859_4.pm',
    'iso-8859-5'     =>	'MHonArc/UTF8/ISO8859_5.pm',
    'iso-8859-6'     =>	'MHonArc/UTF8/ISO8859_6.pm',
    'iso-8859-7'     =>	'MHonArc/UTF8/ISO8859_7.pm',
    'iso-8859-8'     =>	'MHonArc/UTF8/ISO8859_8.pm',
    'iso-8859-9'     =>	'MHonArc/UTF8/ISO8859_9.pm',
    'iso-8859-10'    =>	'MHonArc/UTF8/ISO8859_10.pm',
    'iso-8859-11'    =>	'MHonArc/UTF8/ISO8859_11.pm',
    'iso-8859-13'    =>	'MHonArc/UTF8/ISO8859_13.pm',
    'iso-8859-14'    =>	'MHonArc/UTF8/ISO8859_14.pm',
    'iso-8859-15'    =>	'MHonArc/UTF8/ISO8859_15.pm',
    'iso-8859-16'    =>	'MHonArc/UTF8/ISO8859_16.pm',
    'cp866'	     =>	'MHonArc/UTF8/CP866.pm',
    'cp949'	     =>	'MHonArc/UTF8/CP949.pm', # euc-kr
    'cp932'	     =>	'MHonArc/UTF8/CP932.pm', # shiftjis
    'cp936'	     =>	'MHonArc/UTF8/CP936.pm', # GBK
    'cp950'	     =>	'MHonArc/UTF8/CP950.pm',
    'cp1250'	     =>	'MHonArc/UTF8/CP1250.pm',
    'cp1251'	     =>	'MHonArc/UTF8/CP1251.pm',
    'cp1252'	     =>	'MHonArc/UTF8/CP1252.pm',
    'cp1253'	     =>	'MHonArc/UTF8/CP1253.pm',
    'cp1254'	     =>	'MHonArc/UTF8/CP1254.pm',
    'cp1255'	     =>	'MHonArc/UTF8/CP1255.pm',
    'cp1256'	     =>	'MHonArc/UTF8/CP1256.pm',
    'cp1257'	     =>	'MHonArc/UTF8/CP1257.pm',
    'cp1258'	     =>	'MHonArc/UTF8/CP1258.pm',
    'koi-0'	     =>	'MHonArc/UTF8/KOI_0.pm',
    'koi-7'	     =>	'MHonArc/UTF8/KOI_7.pm',
    'koi8-a'	     =>	'MHonArc/UTF8/KOI8_A.pm',
    'koi8-b'	     =>	'MHonArc/UTF8/KOI8_B.pm',
    'koi8-e'	     =>	'MHonArc/UTF8/KOI8_E.pm',
    'koi8-f'	     =>	'MHonArc/UTF8/KOI8_F.pm',
    'koi8-r'	     =>	'MHonArc/UTF8/KOI8_R.pm',
    'koi8-u'	     =>	'MHonArc/UTF8/KOI8_U.pm',
    'gost19768-87'   =>	'MHonArc/UTF8/GOST19768_87.pm',
    'viscii'	     =>	'MHonArc/UTF8/VISCII.pm',
    'macarabic'	     =>	'MHonArc/UTF8/AppleArabic.pm',
    'maccentraleurroman' => 'MHonArc/UTF8/AppleCenteuro.pm',
    'maccroatian'    =>	'MHonArc/UTF8/AppleCroatian.pm',
    'maccyrillic'    =>	'MHonArc/UTF8/AppleCyrillic.pm',
    'macgreek'	     =>	'MHonArc/UTF8/AppleGreek.pm',
    'machebrew'	     =>	'MHonArc/UTF8/AppleHebrew.pm',
    'macicelandic'   =>	'MHonArc/UTF8/AppleIceland.pm',
    'macromanian'    =>	'MHonArc/UTF8/AppleRomanian.pm',
    'macroman'	     =>	'MHonArc/UTF8/AppleRoman.pm',
    'macthai'	     =>	'MHonArc/UTF8/AppleThai.pm',
    'macturkish'     =>	'MHonArc/UTF8/AppleTurkish.pm',
    'big5-eten'      =>	'MHonArc/UTF8/BIG5_ETEN.pm',
    'big5-hkscs'     =>	'MHonArc/UTF8/BIG5_HKSCS.pm',
    'gb2312'         =>	'MHonArc/UTF8/GB2312.pm',
    'euc-jp'         =>	'MHonArc/UTF8/EUC_JP.pm',
    'hp-roman8'      =>	'MHonArc/UTF8/HP_ROMAN8.pm',
);

my $char_maps = MHonArc::CharMaps->new(\%CharsetMaps);

##---------------------------------------------------------------------------##

# We do not care for valid sequences, just that we catch everything
my $utf8_re = q/[\x00-\x7F]|
		[\xC0-\xDF][\x00-\xFF]|
		[\xE0-\xEF][\x00-\xFF]{2}|
		[\xF0-\xF7][\x00-\xFF]{3}|
		[\xF8-\xFB][\x00-\xFF]{4}|
		[\xFC\xFD][\x00-\xFF]{5}|
		[\x80-\xFF]/;

# Return the length of an utf-8 string
sub utf8_length {
    my $n = 0;
    while ($_[0] =~ m/($utf8_re)/gox) { ++$n; };
    $n;
}

##---------------------------------------------------------------------------##

## Version of TEXTCLIPFUNC for utf8 strings for versions of Perl without
## decent utf8 support (Perl <= 5.6.x).
sub clip {
    my $str      = shift;   # Unfortunately, it is much easier to make a copy
    my $len      = shift;   # Clip length
    my $is_html  = shift;   # If entity references should be considered
    my $has_tags = shift;   # If html tags should be stripped

    # If not HTML text, things are alot easier
    if (!$is_html) {
	# do nothing if we know for sure there is nothing to do
	return $str
	    if length($str) <= $len;

	# Get $len utf8 chars
	$str =~ m/^((?:$utf8_re){1,$len})/x;
	return $1;
    }

    $str =~ s/<[^>]*>//g  if $has_tags;
    return $str  if length($str) <= $len; # nothing to do

    my($utf8_len, $er_len);
    my $text = "";
    my $subtext = "";
    my $sub_len = $len;
    my $real_len = 0;
    
    while ($str ne '') {
	if (!($str =~ s/^((?:$utf8_re){1,$sub_len})//x)) {
	    # pattern should always match, but just in-case...
	    warn qq/Warning: MHonArc::UTF8::MhaEncode::clip:/,
			 qq/ Internal error/;
	    return $text . $str;
	}
	$subtext = $1;

	# check for clipped entity reference
	if (($str ne '') && ($subtext =~ /\&[^;]*\Z/)) {
	    if ($str =~ s/^([^;]*;)//) {
		$subtext .= $1;
	    } else {
		warn qq/Warning: MHonArc::UTF8::MhaEncode::clip: malformed/,
			     qq/ entity reference detected\n/;
		$subtext .= $str;
		$str = '';
	    }
	}

	# compute entity reference lengths to determine "real" character
	# count and not raw character count.
	$er_len = 0;
	while ($subtext =~ /(\&[^;]+);/g) {
	    $er_len += length($1);
	}

	# done if we have enough
	$utf8_len  = utf8_length($subtext);
	$real_len += $utf8_len - $er_len;
	$text     .= $subtext;
	last       if ($real_len >= $len);
	$sub_len   = $len - $real_len;
    }
    $text;
}

sub to_utf8 {
    my $data    = shift;
    my $charset = lc shift;
    my $data_r  = ref($data) ? $data : \$data;

    return $$data_r  if ($charset eq 'us-ascii' ||
			 $charset eq 'utf-8' ||
			 $charset eq 'utf8');
    MHonArc::Char::map_conv($data_r, $charset, $char_maps);
}

sub str2sgml {
    my $data    = shift;
    my $charset = lc shift;
    my $data_r  = ref($data) ? $data : \$data;

    if ($charset eq 'us-ascii') {
	if ($$data_r =~ /[\x80-\xFF]/) {
	    $charset = 'iso-8859-1';
	} else {
	    $$data_r =~ s/([$HTMLSpecials])/$HTMLSpecials{$1}/go;
	    return $$data_r;
	}
    }
    if ($charset eq 'utf-8' || $charset eq 'utf8') {
	$$data_r =~ s/([$HTMLSpecials])/$HTMLSpecials{$1}/go;
	return $$data_r;
    }
    MHonArc::Char::map_conv($data_r, $charset, $char_maps);
    $$data_r =~ s/([$HTMLSpecials])/$HTMLSpecials{$1}/go;
    $$data_r;
}

##---------------------------------------------------------------------------##
1;
__END__

=head1 NAME

MHonArc::UTF8::MhaEncode - UTF-8 based routines for MHonArc

=head1 SYNOPSIS

  use MHonArc::UTF8::MhaEncode;

=head1 DESCRIPTION

MHonArc::UTF8::MhaEncode provides UTF-8 related routines for use in MHonArc.
Implementation of routines are designed to work with non-Unicode aware versions
of Perl 5.

This module is generally not accessed directly since it is used by
MHonArc::UTF8 when determining what encoding routines it can use based
on your perl installation.  However, the following shows you how to use
it directly:

  <CharsetConverters override>
  plain;   mhonarc::htmlize;
  default; MHonArc::UTF8::MhaEncode::str2sgml; MHonArc/UTF8/MhaEncode.pm
  </CharsetConverters>

  <TextClipFunc>
  MHonArc::UTF8::MhaEncode::clip; MHonArc/UTF8/MhaEncode.pm
  </TextClipFunc>

=head1 FUNCTIONS

=over

=item C<to_utf8($data, $from_charset, $to_charset)>

Converts C<$data> encoded in C<$from_charset> into UTF-8.
C<$to_charset> is ignored since it assumed to be C<utf-8>.

=item C<str2sgml($data, $charset)>

All data passed in is converted to utf-8 with HTML specials
converted into entity references.

=item C<clip($text, $clip_len, $is_html, $has_tags)>

Clip C<$text> to C<$clip_len> number of characters.

=back

=head1 SEE ALSO

L<MHonArc::UTF8|MHonArc::UTF8>

=head1 VERSION

C<$Id: MhaEncode.pm,v 1.3 2003/03/05 22:17:15 ehood Exp $>

=head1 AUTHOR

Earl Hood, earl@earlhood.com

MHonArc comes with ABSOLUTELY NO WARRANTY and MHonArc may be copied only
under the terms of the GNU General Public License, which may be found in
the MHonArc distribution.

=cut

