##---------------------------------------------------------------------------##
##  File:
##	$Id: Encode.pm,v 1.2 2002/12/20 08:01:11 ehood Exp $
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

package MHonArc::Encode;

use strict;

BEGIN {
    # If the Encode module is available, we use it, otherwise, we
    # try to use Unicode::MapUTF8.
    eval {
	require Encode;
    };
    if (!$@) {
	*from_to  = \&_encode_from_to;
    } else {
	require Unicode::MapUTF8;
	*from_to  = \&_unimap_from_to;
    }
}

##---------------------------------------------------------------------------##

sub _encode_from_to {
    my $text_r   = shift;
    my $from_enc = lc shift;
    my $to_enc   = lc shift;

    return ''  if $$text_r eq '';

    # Strip utf8 string flag if set
    if (Encode::is_utf8($$text_r)) {
	$$text_r = Encode::encode('utf8', $$text_r);
    }
    my $is_error = 0;
    eval {
	if (!defined(Encode::from_to($$text_r, $from_enc, $to_enc))) {
	    warn qq/Warning: MHonArc::Encode: Unable to convert /,
			  qq/"$from_enc" to "$to_enc"\n/;
	    $is_error = 1;
	}
    };
    if ($@) {
	warn qq/Warning: $@\n/;
	$is_error = 1;
    }
    $is_error ? undef : $to_enc;
}


sub _unimap_from_to {
    my $text_r   = shift;
    my $from_enc = lc shift;
    my $to_enc   = lc shift;

    if (!Unicode::MapUTF8::utf8_supported_charset($from_enc)) {
	warn qq/Warning: MHonArc::Encode "$from_enc" not supported\n/;
	return undef;
    }
    if (!Unicode::MapUTF8::utf8_supported_charset($to_enc)) {
	warn qq/Warning: MHonArc::Encode "$to_enc" not supported\n/;
	return undef;
    }
    $$text_r = Unicode::MapUTF8::to_utf8(
		      {-string => $$text_r, -charset => $from_enc});
    $$text_r = Unicode::MapUTF8::from_utf8(
		      {-string => $$text_r, -charset => $to_enc});
    $to_enc;
}

##---------------------------------------------------------------------------##
1;
__END__

=head1 NAME

MHonArc::Encode - Text encoding routines for MHonArc

=head1 SYNOPSIS

  <TextEncode>
  charset; MHonArc::Encode::from_to; MHonArc/Encode.pm
  </TextEncode>

=head1 DESCRIPTION

MHonArc::Encode provides support for converting text in one
encoding to text in another encoding.

If you converting all data into utf-8, it is recommended
to use the L<MHonArc::UTF8|MHonArc::UTF8> module instead.

=head1 FUNCTIONS

=over

=item C<MHonArc::Encode::from_to($data_ref, $from_charset, $to_charset)>

This function is designed to be registered to the TEXTENCODE
resource:

  <TextEncode>
  charset; MHonArc::Encode::from_to; MHonArc/Encode.pm
  </TextEncode>

Converts C<$data_ref> encoded in C<$from_charset> into C<$to_charset>).
C<$data_ref> should be a reference to a scalar string.  Conversion is
done in-place.

C<undef> is returned if conversion from C<$from_charset> to
C<$to_charset>) is not supported.

=back

=head1 NOTES

=over

=item *

If available, the L<Encode|Encode> module is used for converting
the text.  If not available,
the L<Unicode::MapUTF8|Unicode::MapUTF8> module is used.

The Encode module is only provided with Perl 5.8, and later.
The Unicode::MapUTF8 module is available via CPAN, but require Perl
5.6, or later.

=back

=head1 SEE ALSO

L<MHonArc::UTF8|MHonArc::UTF8>

The TEXTENCODE and CHARSETCONVERTERS resources in the MHonArc documentation.

=head1 VERSION

C<$Id: Encode.pm,v 1.2 2002/12/20 08:01:11 ehood Exp $>

=head1 AUTHOR

Earl Hood, earl@earlhood.com

MHonArc comes with ABSOLUTELY NO WARRANTY and MHonArc may be copied only
under the terms of the GNU General Public License, which may be found in
the MHonArc distribution.

=cut

