##---------------------------------------------------------------------------##
##  File:
##	$Id: MapUTF8.pm,v 1.2 2003/03/05 22:17:15 ehood Exp $
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

package MHonArc::UTF8::MapUTF8;

use strict;
use Unicode::String;
use Unicode::MapUTF8;
use MHonArc::CharMaps;

sub clip {
    use utf8;
    my $str      = \shift;  # Prevent unnecessary copy.
    my $len      = shift;   # Clip length
    my $is_html  = shift;   # If entity references should be considered
    my $has_tags = shift;   # If html tags should be stripped

    my $u = Unicode::String::utf8($$str);

    if (!$is_html) {
      return $u->substr(0, $len);
    }

    my $text = Unicode::String::utf8('');
    my $subtext;
    my $html_len = $u->length;
    my($pos, $sublen, $real_len, $semi);
    my $er_len = 0;
    
    for ( $pos=0, $sublen=$len; $pos < $html_len; ) {
	$subtext = $u->substr($pos, $sublen);
	$pos += $sublen;

	# strip tags
	if ($has_tags) {
	    # Strip full tags
	    $subtext =~ s/<[^>]*>//g;
	    # Check if clipped part of a tag
	    if ($subtext =~ s/<[^>]*\Z//) {
		my $gt = $u->index('>', $pos);
		$pos = ($gt < 0) ? $html_len : ($gt+1);
	    }
	}

	# check for clipped entity reference
	if (($pos < $html_len) && ($subtext =~ /\&[^;]*\Z/)) {
	    my $semi = $u->index(';', $pos);
	    if ($semi < 0) {
		# malformed entity reference
		$subtext .= $u->substr($pos);
		$pos = $html_len;
	    } else {
		$subtext .= $u->substr($pos, $semi-$pos+1);
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
	$real_len = $text->length - $er_len;
	if ($real_len >= $len) {
	    last;
	}
	$sublen = $len - ($text->length - $er_len);
    }
    $text;
}

sub to_utf8 {
    my $text	= shift;
    my $charset = lc shift;
    my $text_r  = ref($text) ? $text : \$text;

    if (Unicode::MapUTF8::utf8_supported_charset($charset)) {
	return Unicode::MapUTF8::to_utf8(
		    {-string => $$text_r, -charset => $charset});
    }
    # Invoke fallback implementation.
    require MHonArc::UTF8::MhaEncode;
    return MHonArc::UTF8::MhaEncode::to_utf8($text_r, $charset);
}

sub str2sgml{
    my $text	= shift;
    my $charset = lc shift;
    my $text_r  = ref($text) ? $text : \$text;

    if ($charset eq 'us-ascii') {
	if ($$text_r =~ /[\x80-\xFF]/) {
	    $charset = 'iso-8859-1';
	} else {
	    $$text_r =~ s/([$HTMLSpecials])/$HTMLSpecials{$1}/go;
	    return $$text_r;
	}
    }
    if ($charset eq 'utf-8' || $charset eq 'utf8') {
	$$text_r =~ s/([$HTMLSpecials])/$HTMLSpecials{$1}/go;
	return $$text_r;
    }
    if ($charset eq 'utf-8' || $charset eq 'utf8') {
	$$text_r =~ s/([$HTMLSpecials])/$HTMLSpecials{$1}/go;
	return $$text_r;
    }
    if (Unicode::MapUTF8::utf8_supported_charset($charset)) {
	$$text_r = Unicode::MapUTF8::to_utf8(
	    {-string => $$text_r, -charset => $charset});
	$$text_r =~ s/([$HTMLSpecials])/$HTMLSpecials{$1}/go;
	return $$text_r;
    }
    # Invoke fallback implementation.
    require MHonArc::UTF8::MhaEncode;
    return MHonArc::UTF8::MhaEncode::str2sgml($text_r, $charset);
}

##---------------------------------------------------------------------------##
1;
__END__

=head1 NAME

MHonArc::UTF8::MapUTF8 - UTF-8 Unicode::MapUTF8-based routines for MHonArc

=head1 SYNOPSIS

  use MHonArc::UTF8::MapUTF8;

=head1 DESCRIPTION

MHonArc::UTF8::MapUTF8 provides UTF-8 related routines for use in MHonArc
by use Perl's v5.6, or later, Unicode::MapUTF8 module, which is available
via CPAN.

This module is generally not accessed directly since it is used by
MHonArc::UTF8 when determining what encoding routines it can use based
on your perl installation.

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

C<$Id: MapUTF8.pm,v 1.2 2003/03/05 22:17:15 ehood Exp $>

=head1 AUTHOR

Earl Hood, earl@earlhood.com

MHonArc comes with ABSOLUTELY NO WARRANTY and MHonArc may be copied only
under the terms of the GNU General Public License, which may be found in
the MHonArc distribution.

=cut

