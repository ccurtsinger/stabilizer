##---------------------------------------------------------------------------##
##  File:
##	$Id: UTF8.pm,v 1.6 2003/03/05 22:17:15 ehood Exp $
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

package MHonArc::UTF8;

use strict;
use MHonArc::CharMaps;

BEGIN {
    eval {
	require MHonArc::UTF8::Encode;
    };
    if (!$@) {
	# Encode module available
	*entify    = \&_entify;
	*clip      = \&MHonArc::UTF8::Encode::clip;
	*to_utf8   = \&MHonArc::UTF8::Encode::to_utf8;
	*str2sgml  = \&MHonArc::UTF8::Encode::str2sgml;
    } else {
	eval {
	    require MHonArc::UTF8::MapUTF8;
	};
	if (!$@) {
	    # Unicode::MapUTF8 module available
	    *entify    = \&_entify;
	    *clip      = \&MHonArc::UTF8::MapUTF8::clip;
	    *to_utf8   = \&MHonArc::UTF8::MapUTF8::to_utf8;
	    *str2sgml  = \&MHonArc::UTF8::MapUTF8::str2sgml;
	} else {
	    # Fallback to homegrown implementation
	    require MHonArc::UTF8::MhaEncode;
	    *entify    = \&_entify;
	    *clip      = \&MHonArc::UTF8::MhaEncode::clip;
	    *to_utf8   = \&MHonArc::UTF8::MhaEncode::to_utf8;
	    *str2sgml  = \&MHonArc::UTF8::MhaEncode::str2sgml;
	}
    }
}

##---------------------------------------------------------------------------##

sub _entify {
    my $text	= shift;
    my $text_r  = ref($text) ? $text : \$text;
    $$text_r =~ s/([$HTMLSpecials])/$HTMLSpecials{$1}/go;
    $$text_r;
}

##---------------------------------------------------------------------------##
1;
__END__

=head1 NAME

MHonArc::UTF8 - UTF-8 routines for MHonArc

=head1 SYNOPSIS

  <CharsetConverters override>
  plain;    mhonarc::htmlize;
  default;  MHonArc::UTF8::str2sgml; MHonArc/UTF8.pm
  </CharsetConverters>

  <TextClipFunc>
  MHonArc::UTF8::clip; MHonArc/UTF8.pm
  </TextClipFunc>

=head1 DESCRIPTION

MHonArc::UTF8 provides UTF-8 related routines for use in MHonArc.
The main use of the routines provided is to generate mail
archives encoded in Unicode UTF-8.

=head1 FUNCTIONS

=over

=item C<MHonArc::UTF8::to_utf8($data, $from_charset, $to_charset)>

Converts C<$data> encoded in C<$from_charset> into UTF-8.
C<$to_charset> is ignored since it assumed to be C<utf-8>.

This function is designed to be registered to the TEXTENCODE
resource:

  <TextEncode>
  utf-8; MHonArc::UTF8::to_utf8; MHonArc/UTF8.pm
  </TextEncode>

=item C<MHonArc::UTF8::str2sgml($data, $charset)>

This function is designed to be registered to the CHARSETCONVERTERS
resource:

  <CharsetConverters override>
  plain;    mhonarc::htmlize;
  us-ascii; mhonarc::htmlize;
  default;  MHonArc::UTF8::str2sgml; MHonArc/UTF8.pm
  </CharsetConverters>

All data passed in is converted to utf-8 with HTML specials
converted into entity references.

=item C<MHonArc::UTF8::clip($text, $clip_len, $is_html, $has_tags)>

This function is designed to be registered to the TEXTCLIPFUNC
resource to have utf-8 strings safely clipped in resource variable
expansion:

  <TextClipFunc>
  MHonArc::UTF8::clip; MHonArc/UTF8.pm
  </TextClipFunc>

=back

=head1 NOTES

=over

=item *

MHonArc::UTF8 tries to leverage existing Perl modules for handling
conversion to utf-8.  The following list the modules checked for
in the order of preference:

=over

=item 1

L<Encode|Encode>.  The Encode module is standard with Perl v5.8, or later.

=item 2

L<Unicode::MapUTF8|Unicode::MapUTF8>.  Unicode::MapUTF8 is an optional
module available via CPAN, and will work with Perl v5.6, or later.

B<Note:> Since it is unclear about the future of Unicode::MapUTF8,
it is possible that support for it may be dropped in the future.  It
appears to not have been updated in awhile since Perl's Encode module
will probably become the standard module to use for handling text
encodings.

=item 3

Fallback implementation.  The fallback implementation is designed to
work with older versions of Perl 5 if the above modules are not available.

=back

=back

=head1 SEE ALSO

The CHARSETCONVERTERS, TEXTCLIPFUNC, and TEXTENCODE
resources in the MHonArc documentation.

=head1 VERSION

C<$Id: UTF8.pm,v 1.6 2003/03/05 22:17:15 ehood Exp $>

=head1 AUTHOR

Earl Hood, earl@earlhood.com

MHonArc comes with ABSOLUTELY NO WARRANTY and MHonArc may be copied only
under the terms of the GNU General Public License, which may be found in
the MHonArc distribution.

=cut

