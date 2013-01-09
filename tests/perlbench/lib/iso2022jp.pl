##---------------------------------------------------------------------------##
##  File:
##	$Id: iso2022jp.pl,v 1.9 2002/12/04 20:00:39 ehood Exp $
##  Author(s):
##      Earl Hood       mhonarc@mhonarc.org
##      NIIBE Yutaka	gniibe@mri.co.jp
##	Takashi P.KATOH p-katoh@shiratori.riec.tohoku.ac.jp
##  Description:
##	Library defines routine to process iso-2022-jp data.
##---------------------------------------------------------------------------##
##    Copyright (C) 1995-2002
##	  Earl Hood, mhonarc@mhonarc.org
##	  NIIBE Yutaka, gniibe@mri.co.jp
##	  Takashi P.KATOH, p-katoh@shiratori.riec.tohoku.ac.jp
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

package iso_2022_jp;

$Url    	= '(http://|https://|ftp://|afs://|wais://|telnet://|ldap://' .
		   '|gopher://|news:|nntp:|mid:|cid:|mailto:|prospero:)';
$UrlExp 	= $Url . q%[^\s\(\)\|<>"']*[^\.?!;,"'\|\[\]\(\)\s<>]%;
$HUrlExp	= $Url . q%[^\s\(\)\|<>"'\&]*[^\.?!;,"'\|\[\]\(\)\s<>\&]%;

##---------------------------------------------------------------------------##
##	str2html(): Convert an iso-2022-jp string into HTML.  Function
##	interface similiar as iso8859.pl function.
##
sub str2html { jp2022_to_html($_[0], 1); }

##---------------------------------------------------------------------------##
##	Function to convert ISO-2022-JP data into HTML.  Function is based
##	on the following RFCs:
##
##	RFC-1468 I
##		J. Murai, M. Crispin, E. van der Poel, "Japanese Character
##		Encoding for Internet Messages", 06/04/1993. (Pages=6)
##
##	RFC-1554  I
##		M. Ohta, K. Handa, "ISO-2022-JP-2: Multilingual Extension of  
##		ISO-2022-JP", 12/23/1993. (Pages=6)
##
sub jp2022_to_html {
    my($body) = shift;
    my($nourl) = shift;
    my(@lines) = split(/\r?\n/,$body);
    my($ret, $ascii_text);
    local($_);

    $ret = "";
    my $cnt = scalar(@lines);
    my $i = 0;
    foreach (@lines) {
	# a trick to process preceding ASCII text
	$_ = "\033(B" . $_ unless /^\033/;

	# Process Each Segment
	while(1) {
	    if (s/^(\033\([BJ])//) { # Single Byte Segment
		$ret .= $1;
		while(1) {
		    if (s/^([^\033]+)//) {	# ASCII plain text
			$ascii_text = $1;

			# Replace meta characters in ASCII plain text
			$ascii_text =~ s%\&%\&amp;%g;
			$ascii_text =~ s%<%\&lt;%g;
			$ascii_text =~ s%>%\&gt;%g;
			## Convert URLs to hyperlinks
			$ascii_text =~ s%($HUrlExp)%<a href="$1">$1</a>%gio
			    unless $nourl;

			$ret .= $ascii_text;
		    } elsif (s/(\033\.[A-F])//) { # G2 Designate Sequence
			$ret .= $1;
		    } elsif (s/(\033N[ -])//) { # Single Shift Sequence
			$ret .= $1;
		    } else {
			last;
		    }
		}
	    } elsif (s/^(\033\$[\@AB]|\033\$\([CD])//) { # Double Byte Segment
		$ret .= $1;
		while (1) {
		    if (s/^([!-~][!-~]+)//) { # Double Char plain text
			$ret .= $1;
		    } elsif (s/(\033\.[A-F])//) { # G2 Designate Sequence
			$ret .= $1;
		    } elsif (s/(\033N[ -])//) { # Single Shift Sequence
			$ret .= $1;
		    } else {
			last;
		    }
		}
	    } else {
		# Something wrong in text
		$ret .= $_;
		last;
	    }
	}

	# remove a `trick'
	$ret =~ s/^\033\(B//;

	# add back eol
	$ret .= "\n"  unless (++$i >= $cnt);
    }

    ($ret);
}


##---------------------------------------------------------------------------##
##	clip($str, $length, $is_html, $has_tags): Clip an iso-2022-jp string.
##
##   The last argument $is_html specifies '&' should be treated
##   as HTML character or not.
##   (i.e., the length of '&amp;' will be 1 if $is_html).
##
sub clip {	# &clip($str, 10, 1, 1);
    my($str) = shift;
    my($length) = shift;
    my($is_html) = shift;
    my($has_tags) = shift;
    my($ret, $inascii);
    local($_) = $str;

    $ret = "";
    # a trick to process preceding ASCII text
    $_ = "\033(B" . $_ unless /^\033/;

    # Process Each Segment
    CLIP: while(1) {
	if (s/^(\033\([BJ])//) { # Single Byte Segment
	    $inascii = 1;
	    $ret .= $1;
	    while(1) {
		if (s/^([^\033])//) {      # ASCII plain text
		    if ($is_html) {
			if (($1 eq '<') && $has_tags) {
			    s/^[^>\033]*>//;
			} else {
			    if ($1 eq '&') {
				s/^([^\;]*\;)//;
				$ret .= "&$1";
			    } else {
				$ret .= $1;
			    }
			    $length--;
			}
		    } else {
			$ret .= $1;
			$length--;
		    }
		} elsif (s/(\033\.[A-F])//) { # G2 Designate Sequence
		    $ret .= $1;
		} elsif (s/(\033N[ -])//) { # Single Shift Sequence
		    $ret .= $1;
		    $length--;
		} else {
		    last;
		}
		last CLIP if ($length <= 0);
	    }
	} elsif (s/^(\033\$[\@AB]|\033\$\([CD])//) { # Double Byte Segment
	    $inascii = 0;
	    $ret .= $1;
	    while (1) {
		if (s/^([!-~][!-~])//) { # Double Char plain text
		    $ret .= $1;
		    # The length of a double-byte-char is assumed 2.
		    # If we consider compatibility with UTF-8, it should be 1.
		    $length -= 2;
		} elsif (s/(\033\.[A-F])//) { # G2 Designate Sequence
		    $ret .= $1;
		} elsif (s/(\033N[ -])//) { # Single Shift Sequence
		    $ret .= $1;
		    $length--;
		} else {
		    last;
		}
		last CLIP if ($length <= 0);
	    }
	} else {
	    # Something wrong in text
	    $ret .= $_;
	    last;
	}
    }

    # remove a `trick'
    $ret =~ s/^\033\(B//;

    # Shuold we check the last \033\([BJ] sequence?
    # (I believe it is too paranoid).
    $ret .= "\033(B" unless $inascii;

    ($ret);
}
##---------------------------------------------------------------------------##
1;
