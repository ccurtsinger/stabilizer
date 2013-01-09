##---------------------------------------------------------------------------##
##  File:
##	$Id: JP.pm,v 1.1 2002/12/18 05:38:43 ehood Exp $
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

package MHonArc::Char::JP;

sub jp_2022_to_euc {
    # implementation of this function plagerized from Encode::JP::JIS7.
    my $data_in = shift;
    my $data_r  = ref($data_in) ? $data_in : \$data_in;

    my ($esc_0212, $esc_asc, $esc_kana, $chunk);
    $$data_r =~ s{(?:(\e\$\(D)|			  # JIS 0212
		     (?:\e\$\@|\e\$B|\e&\@\e\$B)| # JIS 0208
		     (\e\([BJ])|		  # ISO ASC
		     (\e\(I))			  # JIS KANA
		     ([^\e]*)}
    {
	($esc_0212, $esc_asc, $esc_kana, $chunk) =
	    ($1, $2, $3, $4);
	if (!$esc_asc) {
	    $chunk =~ tr/\x21-\x7e/\xa1-\xfe/;
	    if ($esc_kana) {
		$chunk =~ s/([\xa1-\xdf])/\x8e$1/og;
	    } elsif ($esc_0212) {
		$chunk =~ s/([\xa1-\xfe][\xa1-\xfe])/\x8f$1/og;
	    }
	}
	$chunk;
    }gex;
}

1;
