##---------------------------------------------------------------------------##
##  File:
##	$Id: ewhutil.pl,v 2.14 2003/04/05 23:49:38 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      Generic utility routines
##---------------------------------------------------------------------------##
##    Copyright (C) 1996-2001	Earl Hood, mhonarc@mhonarc.org
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

package mhonarc;

my $HTMLSpecials = '"&<>';
my %HTMLSpecials = (
  '"'	=> '&quot;',
  '&'	=> '&amp;',
  '<'	=> '&lt;',
  '>'	=> '&gt;',
  # '@'	=> '&#x40;',  # XXX: Screws up ISO-2022-JP conversion
);

##---------------------------------------------------------------------------
##	Remove duplicates in an array.
##	Returns list with duplicates removed.
##
sub remove_dups {
    my $a = shift;
    return ()  unless scalar(@$a);
    my %dup = ();
    grep(!$dup{$_}++, @$a);
}

##---------------------------------------------------------------------------
##	"Entify" special characters

sub htmlize {			# Older name
    return ''  unless scalar(@_) && defined($_[0]);
    my $txt   = shift;
    my $txt_r = ref($txt) ? $txt : \$txt;
    $$txt_r =~ s/([$HTMLSpecials])/$HTMLSpecials{$1}/go;
    $$txt_r;
}

sub entify {			# Alternate name
    return ''  unless scalar(@_) && defined($_[0]);
    my $txt   = shift;
    my $txt_r = ref($txt) ? $txt : \$txt;
    $$txt_r =~ s/([$HTMLSpecials])/$HTMLSpecials{$1}/go;
    $$txt_r;
}

##	commentize entifies certain characters to avoid problems when a
##	string will be included in a comment declaration

sub commentize {
    my($txt) = $_[0];
    $txt =~ s/([\-&])/'&#'.unpack('C',$1).';'/ge;
    $txt;
}

sub uncommentize {
    my($txt) = $_[0];
    $txt =~ s/&#(\d+);/pack("C",$1)/ge;
    $txt;
}

##---------------------------------------------------------------------------
##	Copy a file.
##
sub cp {
# CPU2006 -- don't actually do anything with real files
return;
    my($src, $dst) = @_;
    open(SRC, $src) || die("ERROR: Unable to open $src\n");
    open(DST, "> $dst") || die("ERROR: Unable to create $dst\n");
    print DST <SRC>;
    close(SRC);
    close(DST);
}

##---------------------------------------------------------------------------
##	Translate html string back to regular string
##
sub dehtmlize {
    my $str   = shift;
    my $str_r = ref($str) ? $str : \$str;
    $$str_r =~ s/\&lt;/</g;
    $$str_r =~ s/\&gt;/>/g;
    $$str_r =~ s/\&amp;/\&/g;
    $$str_r =~ s/\&quot;/\&/g;
    $$str_r =~ s/\&#[xX]0*40;/@/g;
    $$str_r =~ s/\&#64;/@/g;
    $$str_r;
}

##---------------------------------------------------------------------------
##	Escape special characters in string for URL use.
##
sub urlize {
    my($url) = shift || "";
    my $url_r = ref($url) ? $url : \$url;
    $$url_r =~ s/([^\w\.\-:])/sprintf("%%%X",unpack("C",$1))/ge;
    $$url_r;
}

sub urlize_path {
    my($url) = shift || "";
    my $url_r = ref($url) ? $url : \$url;
    $$url_r =~ s/([^\w\.\-:\/])/sprintf("%%%X",unpack("C",$1))/ge;
    $$url_r;
}

##---------------------------------------------------------------------------##
##	Perform a "modified" rot13 on a string.  This version includes
##	the '@' character so addresses can be munged a little better.
##
sub mrot13 {
    my $str	= shift;
    $str =~ tr/@A-Z[a-z/N-Z[@A-Mn-za-m/;
    $str;
}

##---------------------------------------------------------------------------##
1;
