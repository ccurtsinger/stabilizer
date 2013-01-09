##---------------------------------------------------------------------------##
##  File:
##	$Id: mhtxtenrich.pl,v 2.10 2003/08/07 20:35:32 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##	Library defines a routine for MHonArc to filter text/enriched
##	data.
##
##	Filter routine can be registered with the following:
##
##	    <MIMEFILTERS>
##	    text/enriched;m2h_text_enriched::filter;mhtxtenrich.pl
##	    text/richtext;m2h_text_enriched::filter;mhtxtenrich.pl
##	    </MIMEFILTERS>
##
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1997-2002	Earl Hood, mhonarc@mhonarc.org
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

package m2h_text_enriched;

my %enriched_tags = (
    'bigger' => 1,
    'bold' => 1,
    'center' => 1,
    'color' => 1,
    'comment' => 1,
    'excerpt' => 1,
    'fixed' => 1,
    'flushboth' => 1,
    'flushleft' => 1,
    'flushright' => 1,
    'fontfamily' => 1,
    'indent' => 1,
    'indentright' => 1,
    'italic' => 1,
    'lang' => 1,
    'lt' => 1,
    'nl' => 1,
    'nofill' => 1,
    'paraindent' => 1,
    'param' => 1,
    'samepage' => 1,
    'signature' => 1,
    'smaller' => 1,
    'subscript' => 1,
    'superscript' => 1,
    'underline' => 1,
);

my %special_to_char = (
    'lt'  => '<',
    'gt'  => '>',
);

##---------------------------------------------------------------------------
##	Filter routine.
##	XXX: Need to update this filter.  However, does anyone still use
##	     text/enriched anymore.
##
sub filter {
    my($fields, $data, $isdecode, $args) = @_;
    my($innofill, $chunk);
    my $charset = $fields->{'x-mha-charset'};
    my($charcnv, $real_charset_name) =
	    readmail::MAILload_charset_converter($charset);
    my $ret = "";
    $args   = ""  unless defined($args);

    ## Get content-type
    my($ctype) = $fields->{'content-type'}[0] =~ m%^\s*([\w\-\./]+)%;
    my $richtext = $ctype =~ /\btext\/richtext\b/i;

    if (defined($charcnv) && defined(&$charcnv)) {
	$$data = &$charcnv($$data, $real_charset_name);
    } else {
	mhonarc::htmlize($data);
	warn qq/\n/,
	     qq/Warning: Unrecognized character set: $charset\n/,
	     qq/         Message-Id: <$mhonarc::MHAmsgid>\n/,
	     qq/         Message Number: $mhonarc::MHAmsgnum\n/
		unless ($charcnv eq '-decode-');
    }
    ## Fixup any EOL mess
    $$data =~ s/\r?\n/\n/g;
    $$data =~ s/\r/\n/g;

    # translate back <>'s for tag processing
    $$data =~ s/&([lg]t);/$special_to_char{$1}/g;

    ## Convert specials
    if (!$richtext) {
	$$data =~ s/<</\&lt;/g;
    }

    ## Make sure only non-enriched tags are escaped
    $$data =~ s{<(/?)([^>]*)>}
    {
	my $eot = $1;
	my $tag = lc $2;
	$tag =~ s/\s+//g;
	($enriched_tags{$tag}) ? '<'.$eot.$tag.'>' : '&lt;'.$eot.$tag.'&gt;';
    }gexs;

    $innofill = 0;
    foreach $chunk (split(m|(</?nofill>)|i, $$data)) {
	if ($chunk =~ m|<nofill>|i) {
	    $ret .= '<pre>';
	    $innofill = 1;
	    next;
	}
	if ($chunk =~ m|</nofill>|i) {
	    $ret .= '</pre>';
	    $innofill = 0;
	    next;
	}
	convert_tags(\$chunk, $richtext);
	if (!$richtext && !$innofill) {
	    $chunk =~ s/(\n\s*)/&nl_seq_to_brs($1)/ge;
	}
	$ret .= $chunk;
    }
    $ret;
}

##---------------------------------------------------------------------------
##	convert_tags translates text/enriched commands to HTML tags.
##
sub convert_tags {
    my $str  = shift;
    my $richtext = shift;

    $$str =~ s{<comment\s*>.*?</comment\s*>}{}gis;

    $$str =~ s{<(/?)bold\s*>}{<$1b>}gi;
    $$str =~ s{<(/?)italic\s*>}{<$1i>}gi;
    $$str =~ s{<(/?)underline\s*>}{<$1u>}gi;
    $$str =~ s{<(/?)fixed\s*>}{<$1tt>}gi;
    $$str =~ s{<(/?)smaller\s*>}{<$1small>}gi;
    $$str =~ s{<(/?)bigger\s*>}{<$1big>}gi;
    $$str =~ s{<(/?)signature\s*>}{<$1pre>}gi;

    $$str =~ s{<fontfamily\s*>\s*<param\s*>([^<]+)</param\s*>}
	      {<font face="$1">}gix;
    $$str =~ s|</fontfamily\s*>|</font>|gi;
    $$str =~ s{<color\s*>\s*<param\s*>\s*(\S+)\s*</param\s*>}
	      {<font color="$1">}gix;
    $$str =~ s|</color\s*>|</font>|gi;
    $$str =~ s|<center\s*>|<p align="center">|gi;
    $$str =~ s|</center\s*>|</p>|gi;
    $$str =~ s|<flushleft\s*>|<p align="left">|gi;
    $$str =~ s|</flushleft\s*>|</p>|gi;
    $$str =~ s|<flushright\s*>|<p align="right">|gi;
    $$str =~ s|</flushright\s*>|</p>|gi;
    $$str =~ s|<flushboth\s*>|<p align="justify">|gi;
    $$str =~ s|</flushboth\s*>|</p>|gi;
    $$str =~ s|<paraindent\s*>\s*<param\s*>([^<]*)</param\s*>|<blockquote>|gi;
    $$str =~ s|</paraindent\s*>|</blockquote>|gi;

    $$str =~ s|<excerpt\s*>\s*(<param\s*>([^<]*)</param\s*>)?|<blockquote>|gi;
    $$str =~ s|</excerpt\s*>|</blockquote>|gi;

    $$str =~ s|<lang\s*>\s*<param\s*>([^<]*)</param\s*>|<div lang="$1">|gi;
    $$str =~ s|</lang\s*>|</div>|gi;

    # richtext commands
    $$str =~ s{</?samepage\s*>}{}gi;
    $$str =~ s{<(/?)subscript\s*>}{<$1sub>}gi;
    $$str =~ s{<(/?)superscript\s*>}{<$1sup>}gi;
    $$str =~ s{<lt\s*>}{&lt;}gi;
    $$str =~ s{<np\s*>}{\f}gi;
    $$str =~ s{<paragraph\s*>}{<p>}gi;
    $$str =~ s{</paragraph\s*>\n?}{</p>}gis;
    $$str =~ s{<indent\s*>}{<p style="margin-left: 1em;">}gi;
    $$str =~ s{</indent\s*>}{</p>}gi;
    $$str =~ s{<indentright\s*>}{<p style="margin-right: 1em;">}gi;
    $$str =~ s{</indentright\s*>}{</p>}gi;

    if ($richtext) {
	$$str =~ s{<nl\s*>\n?}{<br>}gis;
    } else {
	$$str =~ s{<nl\s*>}{}gis;
    }

    # Cleanup bad tags
    $$str =~ s{</?(?:para(?:m|indent)|excerpt|lang|color|fontfamily)\s*>}{}g;
}

##---------------------------------------------------------------------------
##	nl_seq_to_brs returns a "<BR>" string based on the number
##	of eols in a string.
##
sub nl_seq_to_brs {
    my($str) = shift;
    my($n);
    $n = $str =~ tr/\n/\n/;
    --$n;
    if ($n <= 0) {
	return " ";
    } else {
	return "<br>\n" x $n;
    }
}

##---------------------------------------------------------------------------
##	preserve_space returns a string with all spaces and tabs
##	converted to nbsps.
##
sub preserve_space {
    my($str) = shift;
    1 while
      $str =~ s/^([^\t]*)(\t+)/$1 . ' ' x (length($2) * 8 - length($1) % 8)/e;
    $str =~ s/ /\&nbsp;/g;
    $str;
}

##---------------------------------------------------------------------------
1;
