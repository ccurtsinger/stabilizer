##---------------------------------------------------------------------------##
##  File:
##	$Id: Encode.pm,v 1.2 2003/03/05 22:17:15 ehood Exp $
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

package MHonArc::UTF8::Encode;

use strict;
use Encode;
use MHonArc::CharMaps;

##---------------------------------------------------------------------------##

sub clip {
    my $str      = \shift;  # Prevent unnecessary copy.
    my $len      = shift;   # Clip length
    my $is_html  = shift;   # If entity references should be considered
    my $has_tags = shift;   # If html tags should be stripped

    my $u = Encode::decode('utf8', $$str);

    if (!$is_html) {
      return substr($u, 0, $len);
    }

    my $text = Encode::decode('utf8', '');
    my $subtext;
    my $html_len = length($u);
    my($pos, $sublen, $real_len, $semi);
    my $er_len = 0;
    
    for ( $pos=0, $sublen=$len; $pos < $html_len; ) {
	$subtext = substr($u, $pos, $sublen);
	$pos += $sublen;

	# strip tags
	if ($has_tags) {
	    # Strip full tags
	    $subtext =~ s/<[^>]*>//g;
	    # Check if clipped part of a tag
	    if ($subtext =~ s/<[^>]*\Z//) {
		my $gt = index($u, '>', $pos);
		$pos = ($gt < 0) ? $html_len : ($gt+1);
	    }
	}

	# check for clipped entity reference
	if (($pos < $html_len) && ($subtext =~ /\&[^;]*\Z/)) {
	    my $semi = index($u, ';', $pos);
	    if ($semi < 0) {
		# malformed entity reference
		$subtext .= substr($u, $pos);
		$pos = $html_len;
	    } else {
		$subtext .= substr($u, $pos, $semi-$pos+1);
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
	$real_len = length($text) - $er_len;
	if ($real_len >= $len) {
	    last;
	}
	$sublen = $len - (length($text) - $er_len);
    }
    Encode::encode('utf8', $text);
}

sub to_utf8 {
    my $charset = lc $_[1];
    return $_[0]  if ($charset eq 'us-ascii' ||
		      $charset eq 'utf-8' ||
		      $charset eq 'utf8');
    my $text    = $_[0];
    my $text_r	= ref($text) ? $text : \$text;
    eval {
	Encode::from_to($$text_r, $charset, 'utf8');
    };
    if ($@) {
	# fallback implementation.
	require MHonArc::UTF8::MhaEncode;
	return MHonArc::UTF8::MhaEncode::to_utf8($text_r, $charset);
    }
    $$text_r;
}

sub str2sgml {
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
    eval {
	Encode::from_to($$text_r, $charset, 'utf8');
	$$text_r =~ s/([$HTMLSpecials])/$HTMLSpecials{$1}/go;
    };
    if ($@) {
	# fallback implementation.
	require MHonArc::UTF8::MhaEncode;
	return MHonArc::UTF8::MhaEncode::str2sgml($text_r, $charset);
    }
    $$text_r;
}

##---------------------------------------------------------------------------##
1;
__END__

=head1 NAME

MHonArc::UTF8::Encode - UTF-8 Encode-based routines for MHonArc

=head1 SYNOPSIS

  use MHonArc::UTF8::Encode;

=head1 DESCRIPTION

MHonArc::UTF8::Encode provides UTF-8 related routines for use in MHonArc
by use Perl's v5.8, or later, Encode module.

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

C<$Id: Encode.pm,v 1.2 2003/03/05 22:17:15 ehood Exp $>

=head1 AUTHOR

Earl Hood, earl@earlhood.com

MHonArc comes with ABSOLUTELY NO WARRANTY and MHonArc may be copied only
under the terms of the GNU General Public License, which may be found in
the MHonArc distribution.

=cut

