# $Id: HTML.pm,v 1.96 2003/09/12 00:04:27 quinlan Exp $

package Mail::SpamAssassin::HTML;
1;

package Mail::SpamAssassin::PerMsgStatus;
use HTML::Parser 3.24 ();

use strict;
use bytes;

use vars qw{
  $re_loose $re_strict $events
};

# HTML decoding TODOs
# - add URIs to list for faster URI testing

# elements defined by the HTML 4.01 and XHTML 1.0 DTDs (do not change them!)
$re_loose = 'applet|basefont|center|dir|font|frame|frameset|iframe|isindex|menu|noframes|s|strike|u';
$re_strict = 'a|abbr|acronym|address|area|b|base|bdo|big|blockquote|body|br|button|caption|cite|code|col|colgroup|dd|del|dfn|div|dl|dt|em|fieldset|form|h1|h2|h3|h4|h5|h6|head|hr|html|i|img|input|ins|kbd|label|legend|li|link|map|meta|noscript|object|ol|optgroup|option|p|param|pre|q|samp|script|select|small|span|strong|style|sub|sup|table|tbody|td|textarea|tfoot|th|thead|title|tr|tt|ul|var';

# loose list of HTML events
$events = 'on(?:activate|afterupdate|beforeactivate|beforecopy|beforecut|beforedeactivate|beforeeditfocus|beforepaste|beforeupdate|blur|change|click|contextmenu|controlselect|copy|cut|dblclick|deactivate|errorupdate|focus|focusin|focusout|help|keydown|keypress|keyup|load|losecapture|mousedown|mouseenter|mouseleave|mousemove|mouseout|mouseover|mouseup|mousewheel|move|moveend|movestart|paste|propertychange|readystatechange|reset|resize|resizeend|resizestart|select|submit|timeerror|unload)';

my %tested_colors;

sub html_init {
  my ($self) = @_;

  push @{ $self->{bgcolor_color} }, "#ffffff";
  push @{ $self->{bgcolor_tag} }, "default";
  push @{ $self->{fgcolor_color} }, "#000000";
  push @{ $self->{fgcolor_tag} }, "default";
  undef %tested_colors;
}

sub html_tag {
  my ($self, $tag, $attr, $num) = @_;

  $self->{html_inside}{$tag} += $num;

  $self->{html}{elements}++ if $tag =~ /^(?:$re_strict|$re_loose)$/io;
  $self->{html}{tags}++;

  if ($tag =~ /^(?:body|table|tr|th|td)$/) {
    $self->html_bgcolor($tag, $attr, $num);
  }
  if ($tag =~ /^(?:body|font)$/) {
    $self->html_fgcolor($tag, $attr, $num);
  }

  if ($num == 1) {
    $self->html_format($tag, $attr, $num);
    $self->html_uri($tag, $attr, $num);
    $self->html_tests($tag, $attr, $num);

    $self->{html_last_tag} = $tag;
  }

  if ($tag =~ /^(?:b|i|u|strong|em|big|center|h\d)$/) {
    $self->{html}{shouting} += $num;

    if ($self->{html}{shouting} > $self->{html}{max_shouting}) {
      $self->{html}{max_shouting} = $self->{html}{shouting};
    }
  }
}

sub html_format {
  my ($self, $tag, $attr, $num) = @_;

  # ordered by frequency of tag groups
  if ($tag eq "br") {
    push @{$self->{html_text}}, "\n";
  }
  elsif ($tag eq "li" || $tag eq "td") {
    push @{$self->{html_text}}, " ";
  }
  elsif ($tag eq "p" || $tag eq "hr") {
    push @{$self->{html_text}}, "\n\n";
  }
  elsif ($tag eq "img" && exists $attr->{alt} && $attr->{alt} ne "") {
    push @{$self->{html_text}}, " $attr->{alt} ";
  }
}

sub html_uri {
  my ($self, $tag, $attr, $num) = @_;
  my $uri;

  # ordered by frequency of tag groups
  if ($tag =~ /^(?:body|table|tr|td)$/) {
    push @{$self->{html_text}}, "URI:$uri " if $uri = $attr->{background};
  }
  elsif ($tag =~ /^(?:a|area|link)$/) {
    push @{$self->{html_text}}, "URI:$uri " if $uri = $attr->{href};
  }
  elsif ($tag =~ /^(?:img|frame|iframe|embed|script)$/) {
    push @{$self->{html_text}}, "URI:$uri " if $uri = $attr->{src};
  }
  elsif ($tag eq "form") {
    push @{$self->{html_text}}, "URI:$uri " if $uri = $attr->{action};
  }
  elsif ($tag eq "base") {
    if ($uri = $attr->{href}) {
      # use <BASE HREF="URI"> to turn relative links into absolute links

      # even if it is a base URI, handle like a normal URI as well
      push @{$self->{html_text}}, "URI:$uri ";

      # a base URI will be ignored by browsers unless it is an absolute
      # URI of a standard protocol
      if ($uri =~ m@^(?:ftp|https?)://@i) {
	# remove trailing filename, if any; base URIs can have the
	# form of "http://foo.com/index.html"
	$uri =~ s@^([a-z]+://[^/]+/.*?)[^/\.]+\.[^/\.]{2,4}$@$1@i;
	# Make sure it ends in a slash
	$uri .= "/" unless $uri =~ m@/$@;
	$self->{html}{base_href} = $uri;
      }
    }
  }
}

# input values from 0 to 255
sub rgb_to_hsv {
  my ($r, $g, $b) = @_;
  my ($h, $s, $v, $max, $min);

  if ($r > $g) {
    $max = $r; $min = $g;
  }
  else {
    $min = $r; $max = $g;
  }
  $max = $b if $b > $max;
  $min = $b if $b < $min;
  $v = $max;
  $s = $max ? ($max - $min) / $max : 0;
  if ($s == 0) {
    $h = undef;
  }
  else {
    my $cr = ($max - $r) / ($max - $min);
    my $cg = ($max - $g) / ($max - $min);
    my $cb = ($max - $b) / ($max - $min);
    if ($r == $max) {
      $h = $cb - $cg;
    }
    elsif ($g == $max) {
      $h = 2 + $cr - $cb;
    }
    elsif ($b == $max) {
      $h = 4 + $cg - $cr;
    }
    $h *= 60;
    $h += 360 if $h < 0;
  }
  return ($h, $s, $v);
}

# HTML 4 defined 16 colors
my %html_color = (
  aqua		=> '#00ffff',
  black		=> '#000000',
  blue		=> '#0000ff',
  fuchsia	=> '#ff00ff',
  gray		=> '#808080',
  green		=> '#008000',
  lime		=> '#00ff00',
  maroon	=> '#800000',
  navy		=> '#000080',
  olive		=> '#808000',
  purple	=> '#800080',
  red		=> '#ff0000',
  silver	=> '#c0c0c0',
  teal		=> '#008080',
  white		=> '#ffffff',
  yellow	=> '#ffff00',
);

# popular X11 colors specified in CSS3 color module
my %name_color = (
  aliceblue	=> '#f0f8ff',
  cyan		=> '#00ffff',
  darkblue	=> '#00008b',
  darkcyan	=> '#008b8b',
  darkgray	=> '#a9a9a9',
  darkgreen	=> '#006400',
  darkred	=> '#8b0000',
  firebrick	=> '#b22222',
  gold		=> '#ffd700',
  lightslategray=> '#778899',
  magenta	=> '#ff00ff',
  orange	=> '#ffa500',
  pink		=> '#ffc0cb',
  whitesmoke	=> '#f5f5f5',
);

sub name_to_rgb {
  return $html_color{$_[0]} || $name_color{$_[0]} || $_[0];
}

sub pop_bgcolor {
  my ($self) = @_;

  pop @{ $self->{bgcolor_color} };
  pop @{ $self->{bgcolor_tag} };
}

sub html_bgcolor {
  my ($self, $tag, $attr, $num) = @_;

  if ($num == 1) {
    # close elements with optional end tags
    if ($tag eq "body") {
      # compromise between HTML browsers generally only using first
      # body and some messages including multiple HTML attachments:
      # pop everything except first body color
      while ($self->{bgcolor_tag}[-1] !~ /^(?:default|body)$/) {
	$self->pop_bgcolor();
      }
    }
    if ($tag eq "tr") {
      while ($self->{bgcolor_tag}[-1] =~ /^t[hd]$/) {
	$self->pop_bgcolor();
      }
      $self->pop_bgcolor() if $self->{bgcolor_tag}[-1] eq "tr";
    }
    elsif ($tag =~ /^t[hd]$/) {
      $self->pop_bgcolor() if $self->{bgcolor_tag}[-1] =~ /^t[hd]$/;
    }
    # figure out new bgcolor
    my $bgcolor;
    if (exists $attr->{bgcolor}) {
      $bgcolor = name_to_rgb(lc($attr->{bgcolor}));
    }
    else {
      $bgcolor = $self->{bgcolor_color}[-1];
    }
    # tests
    if ($tag eq "body" && $bgcolor !~ /^\#?ffffff$/) {
      $self->{html}{bgcolor_nonwhite} = 1;
    }
    # push new bgcolor
    push @{ $self->{bgcolor_color} }, $bgcolor;
    push @{ $self->{bgcolor_tag} }, $tag;
  }
  else {
    # close elements
    if ($tag eq "body") {
      $self->pop_bgcolor() if $self->{bgcolor_tag}[-1] eq "body";
    }
    elsif ($tag eq "table") {
      while ($self->{bgcolor_tag}[-1] =~ /^t[rhd]$/) {
	$self->pop_bgcolor();
      }
      $self->pop_bgcolor() if $self->{bgcolor_tag}[-1] eq "table";
    }
    elsif ($tag eq "tr") {
      while ($self->{bgcolor_tag}[-1] =~ /^t[hd]$/) {
	$self->pop_bgcolor();
      }
      $self->pop_bgcolor() if $self->{bgcolor_tag}[-1] eq "tr";
    }
    elsif ($tag =~ /^t[hd]$/) {
      $self->pop_bgcolor() if $self->{bgcolor_tag}[-1] =~ /^t[hd]$/;
    }
  }
}
  
sub pop_fgcolor {
  my ($self) = @_;

  pop @{ $self->{fgcolor_color} };
  pop @{ $self->{fgcolor_tag} };
}

sub html_fgcolor {
  my ($self, $tag, $attr, $num) = @_;

  if ($num == 1) {
    if ($tag eq "body") {
      # compromise between HTML browsers generally only using first
      # body and some messages including multiple HTML attachments:
      # pop everything except first body color
      while ($self->{fgcolor_tag}[-1] !~ /^(?:default|body)$/) {
	$self->pop_fgcolor();
      }
    }
    # figure out new fgcolor
    my $fgcolor;
    if ($tag eq "font" && exists $attr->{color}) {
      $fgcolor = name_to_rgb(lc($attr->{color}));
    }
    elsif ($tag eq "body" && exists $attr->{text}) {
      $fgcolor = name_to_rgb(lc($attr->{text}));
    }
    else {
      $fgcolor = $self->{fgcolor_color}[-1];
    }
    # push new fgcolor
    push @{ $self->{fgcolor_color} }, $fgcolor;
    push @{ $self->{fgcolor_tag} }, $tag;
  }
  else {
    # close elements
    if ($tag eq "body") {
      $self->pop_fgcolor() if $self->{fgcolor_tag}[-1] eq "body";
    }
    if ($tag eq "font") {
      $self->pop_fgcolor() if $self->{fgcolor_tag}[-1] eq "font";
    }
  }
}

sub html_font_invisible {
  my ($self, $text) = @_;

  my $fg = $self->{fgcolor_color}[-1];
  my $bg = $self->{bgcolor_color}[-1];

  return if exists $tested_colors{"$fg\000$bg"};
  $tested_colors{"$fg\000$bg"}++;

  # invisibility
  if (substr($fg,-6) eq substr($bg,-6)) {
    $self->{html}{font_invisible} = 1;
  }
  # near-invisibility
  elsif ($fg =~ /^\#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/) {
    my ($r1, $g1, $b1) = (hex($1), hex($2), hex($3));

    if ($bg =~ /^\#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/) {
      my ($r2, $g2, $b2) = (hex($1), hex($2), hex($3));

      my $r = ($r1 - $r2);
      my $g = ($g1 - $g2);
      my $b = ($b1 - $b2);

      # geometric distance weighted by brightness
      # maximum distance is 191.151823601032
      my $distance = ((0.2126*$r)**2 + (0.7152*$g)**2 + (0.0722*$b)**2)**0.5;

      # the text is very difficult to read if the distance is under 12,
      # a limit of 14 to 16 might be okay if the usage significantly
      # increases (near-invisible text is at about 0.95% of spam and
      # 1.25% of HTML spam right now), but please test any changes first
      if ($distance < 12) {
	$self->{html}{"font_near_invisible"} = 1;
      }
    }
  }
}

sub html_tests {
  my ($self, $tag, $attr, $num) = @_;

  if ($tag eq "table" && exists $attr->{border} && $attr->{border} =~ /(\d+)/)
  {
    $self->{html}{thick_border} = 1 if $1 > 1;
  }
  if ($tag eq "script") {
    $self->{html}{javascript} = 1;
  }
  if ($tag =~ /^(?:a|body|div|input|form|td|layer|area|img)$/i) {
    for (keys %$attr) {
      if (/\b(?:$events)\b/io)
      {
	$self->{html}{html_event} = 1;
      }
      if (/\bon(?:blur|contextmenu|focus|load|resize|submit|unload)\b/i &&
	  $attr->{$_})
      {
	$self->{html}{html_event_unsafe} = 1;
        if ($attr->{$_} =~ /\.open\s*\(/) { $self->{html}{window_open} = 1; }
        if ($attr->{$_} =~ /\.blur\s*\(/) { $self->{html}{window_blur} = 1; }
        if ($attr->{$_} =~ /\.focus\s*\(/) { $self->{html}{window_focus} = 1; }
      }
    }
  }
  if ($tag eq "font" && exists $attr->{size}) {
    $self->{html}{big_font} = 1 if (($attr->{size} =~ /^\s*(\d+)/ && $1 > 3) ||
			    ($attr->{size} =~ /\+(\d+)/ && $1 >= 1));
  }
  if ($tag eq "font" && exists $attr->{color}) {
    my $bg = $self->{bgcolor_color}[-1];
    my $fg = lc($attr->{color});
    if ($fg =~ /^\#?[0-9a-f]{6}$/ && $fg !~ /^\#?(?:00|33|66|80|99|cc|ff){3}$/)
    {
      $self->{html}{font_color_unsafe} = 1;
    }
    if ($fg !~ /^\#?[0-9a-f]{6}$/ && !exists $html_color{$fg})
    {
      $self->{html}{font_color_name} = 1;
    }
    if ($fg =~ /^\#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/) {
      my ($h, $s, $v) = rgb_to_hsv(hex($1), hex($2), hex($3));
      if (!defined($h)) {
	$self->{html}{font_gray} = 1 unless ($v == 0 || $v == 255);
      }
      elsif ($h < 30 || $h >= 330) {
	$self->{html}{font_red} = 1;
      }
      elsif ($h < 90) {
	$self->{html}{font_yellow} = 1;
      }
      elsif ($h < 150) {
	$self->{html}{font_green} = 1;
      }
      elsif ($h < 210) {
	$self->{html}{font_cyan} = 1;
      }
      elsif ($h < 270) {
	$self->{html}{font_blue} = 1;
      }
      elsif ($h < 330) {
	$self->{html}{font_magenta} = 1;
      }
    }
    else {
      $self->{html}{font_color_unknown} = 1;
    }
  }
  if ($tag eq "font" && exists $attr->{face}) {
    #print STDERR "FONT " . $attr->{face} . "\n";
    if ($attr->{face} =~ /[A-Z]{3}/ && $attr->{face} !~ /M[ST][A-Z]|ITC/) {
      $self->{html}{font_face_caps} = 1;
    }
    if ($attr->{face} !~ /^[a-z][a-z -]*[a-z](?:,\s*[a-z][a-z -]*[a-z])*$/i) {
      $self->{html}{font_face_bad} = 1;
    }
    for (split(/,/, lc($attr->{face}))) {
      $self->{html}{font_face_odd} = 1 if ! /^\s*(?:arial|arial black|courier new|geneva|helvetica|ms sans serif|sans serif|sans-serif|sans-serif;|serif|sunsans-regular|swiss|tahoma|times|times new roman|trebuchet|trebuchet ms|verdana)\s*$/i;
    }
  }
  if (exists($attr->{style})) {
    if ($attr->{style} =~ /font(?:-size)?:\s*(\d+(?:\.\d*)?|\.\d+)(p[tx])/i) {
      my $size = $1;
      my $type = $2;

      $self->{html}{big_font} = 1 if (lc($type) eq "pt" && $size > 12);
    }
  }
  if ($tag eq "img" && exists $attr->{width} && exists $attr->{height}) {
    my $width = 0;
    my $height = 0;
    my $area = 0;

    # assume 800x600 screen for percentage values
    if ($attr->{width} =~ /^(\d+)(\%)?$/) {
      $width = $1;
      $width *= 8 if (defined $2 && $2 eq "%");
    }
    if ($attr->{height} =~ /^(\d+)(\%)?$/) {
      $height = $1;
      $height *= 6 if (defined $2 && $2 eq "%");
    }
    if ($width > 0 && $height > 0) {
      $area = $width * $height;
      $self->{html}{image_area} += $area;
    }
    # this is intended to match any width and height if they're specified
    if (exists $attr->{src} &&
	$attr->{src} =~ /\.(?:pl|cgi|php|asp|jsp|cfm)\b/i)
    {
      $self->{html}{web_bugs} = 1;
    }
  }
  if ($tag eq "form" && exists $attr->{action}) {
    $self->{html}{form_action_mailto} = 1 if $attr->{action} =~ /mailto:/i
  }
  if ($tag =~ /^i?frame$/) {
    $self->{html}{relaying_frame} = 1;
  }
  if ($tag =~ /^(?:object|embed)$/) {
    $self->{html}{embeds} = 1;
  }
  if ($tag eq "title" &&
      !(exists $self->{html_inside}{body} && $self->{html_inside}{body} > 0))
  {
    $self->{html}{title_text} = "";
  }
  if ($tag eq "meta" &&
      exists $attr->{'http-equiv'} &&
      exists $attr->{content} &&
      $attr->{'http-equiv'} =~ /Content-Type/i &&
      $attr->{content} =~ /\bcharset\s*=\s*["']?([^"']+)/i)
  {
    $self->{html}{charsets} .= exists $self->{html}{charsets} ? " $1" : $1;
  }

  $self->{html}{anchor_text} ||= "" if ($tag eq "a");
}

sub html_text {
  my ($self, $text) = @_;

  if (exists $self->{html_inside}{a} && $self->{html_inside}{a} > 0) {
    $self->{html}{anchor_text} .= " $text";
  }

  if (exists $self->{html_inside}{script} && $self->{html_inside}{script} > 0)
  {
    if ($text =~ /\b(?:$events)\b/io)
    {
      $self->{html}{html_event} = 1;
    }
    if ($text =~ /\bon(?:blur|contextmenu|focus|load|resize|submit|unload)\b/i)
    {
      $self->{html}{html_event_unsafe} = 1;
    }
    if ($text =~ /\.open\s*\(/) { $self->{html}{window_open} = 1; }
    if ($text =~ /\.blur\s*\(/) { $self->{html}{window_blur} = 1; }
    if ($text =~ /\.focus\s*\(/) { $self->{html}{window_focus} = 1; }
    return;
  }

  if (exists $self->{html_inside}{style} && $self->{html_inside}{style} > 0) {
    if ($text =~ /font(?:-size)?:\s*(\d+(?:\.\d*)?|\.\d+)(p[tx])/i) {
      my $size = $1;
      my $type = $2;

      $self->{html}{big_font} = 1 if (lc($type) eq "pt" && $size > 12);
    }
    return;
  }

  if (!(exists $self->{html_inside}{body} && $self->{html_inside}{body} > 0) &&
        exists $self->{html_inside}{title} && $self->{html_inside}{title} > 0)
  {
    $self->{html}{title_text} .= $text;
  }

  $self->html_font_invisible($text) if $text =~ /[^ \t\n\r\f\x0b\xa0]/;

  $text =~ s/^\n//s if $self->{html_last_tag} eq "br";
  push @{$self->{html_text}}, $text;
}

sub html_comment {
  my ($self, $text) = @_;

  $self->{html}{comment_8bit} = 1 if $text =~ /[\x80-\xff]{3,}/;
  $self->{html}{comment_email} = 1 if $text =~ /\S+\@\S+/;
  $self->{html}{comment_egp} = 1 if $text =~ /\S+begin egp html banner\S+/;
  $self->{html}{comment_saved_url} = 1 if $text =~ /<!-- saved from url=\(\d{4}\)/;
  $self->{html}{comment_sky} = 1 if $text =~ /SKY-(?:Email-Address|Database|Mailing|List)/;
  $self->{html}{total_comment_length} += length($text) + 7; # "<!--" + "-->"

  if (exists $self->{html_inside}{script} && $self->{html_inside}{script} > 0)
  {
    if ($text =~ /\b(?:$events)\b/io)
    {
      $self->{html}{html_event} = 1;
    }
    if ($text =~ /\bon(?:blur|contextmenu|focus|load|resize|submit|unload)\b/i)
    {
      $self->{html}{html_event_unsafe} = 1;
    }
    if ($text =~ /\.open\s*\(/) { $self->{html}{window_open} = 1; }
    if ($text =~ /\.blur\s*\(/) { $self->{html}{window_blur} = 1; }
    if ($text =~ /\.focus\s*\(/) { $self->{html}{window_focus} = 1; }
    return;
  }

  if (exists $self->{html_inside}{style} && $self->{html_inside}{style} > 0) { 
    if ($text =~ /font(?:-size)?:\s*(\d+(?:\.\d*)?|\.\d+)(p[tx])/i) {
      my $size = $1;
      my $type = $2;

      $self->{html}{big_font} = 1 if (lc($type) eq "pt" && $size > 12);
    }
  }

  if (exists $self->{html}{shouting} && $self->{html}{shouting} > 1) {
    $self->{html}{comment_shouting} = 1;
  }
}

sub html_declaration {
  my ($self, $text) = @_;

  if ($text =~ /^<!doctype/i) {
    my $tag = "!doctype";

    $self->{html}{elements}++;
    $self->{html}{tags}++;
    $self->{html_inside}{$tag} = 0;
  }
}

###########################################################################
# HTML parser tests
###########################################################################

sub html_tag_balance {
  my ($self, undef, $rawtag, $rawexpr) = @_;
  $rawtag =~ /^([a-zA-Z0-9]+)$/; my $tag = $1;
  $rawexpr =~ /^([\<\>\=\!\-\+ 0-9]+)$/; my $expr = $1;

  return 0 unless exists $self->{html_inside}{$tag};

  $self->{html_inside}{$tag} =~ /^([\<\>\=\!\-\+ 0-9]+)$/;
  my $val = $1;
  return eval "$val $expr";
}

sub html_image_only {
  my ($self, undef, $min, $max) = @_;

  return (exists $self->{html_inside}{'img'} &&
	  exists $self->{html}{non_space_len} &&
	  $self->{html}{non_space_len} > $min &&
	  $self->{html}{non_space_len} <= $max &&
	  $self->get('X-eGroups-Return') !~ /^sentto-.*\@returns\.groups\.yahoo\.com$/);
}

sub html_image_ratio {
  my ($self, undef, $min, $max) = @_;

  return 0 unless (exists $self->{html}{non_space_len} &&
		   exists $self->{html}{image_area} &&
		   $self->{html}{image_area} > 0);
  my $ratio = int(100000 * $self->{html}{non_space_len} / $self->{html}{image_area} + 0.5);
  return ($ratio > $min && $ratio <= $max);
}

sub html_charset_faraway {
  my ($self) = @_;

  return 0 unless exists $self->{html}{charsets};

  my @locales = $self->get_my_locales();
  return 0 if grep { $_ eq "all" } @locales;

  my $okay = 0;
  my $bad = 0;
  for my $c (split(' ', $self->{html}{charsets})) {
    if (Mail::SpamAssassin::Locales::is_charset_ok_for_locales($c, @locales)) {
      $okay++;
    }
    else {
      $bad++;
    }
  }
  return ($bad && ($bad >= $okay));
}

sub html_tag_exists {
  my ($self, undef, $tag) = @_;
  return exists $self->{html_inside}{$tag};
}

sub html_test {
  my ($self, undef, $test) = @_;
  return $self->{html}{$test};
}

sub html_eval {
  my ($self, undef, $test, $expr) = @_;
  return exists $self->{html}{$test} && eval "qq{\Q$self->{html}{$test}\E} $expr";
}

sub html_message {
  my ($self) = @_;

  return (exists $self->{html}{elements} &&
	  ($self->{html}{elements} >= 8 ||
	   $self->{html}{elements} >= $self->{html}{tags} / 2));
}

sub html_range {
  my ($self, undef, $test, $min, $max) = @_;

  return 0 unless exists $self->{html}{$test};

  $test = $self->{html}{$test};

  # not all perls understand what "inf" means, so we need to do
  # non-numeric tests!  urg!
  if ( !defined $max || $max eq "inf" ) {
    return ( $test eq "inf" ) ? 1 : ($test > $min);
  }
  elsif ( $test eq "inf" ) {
    # $max < inf, so $test == inf means $test > $max
    return 0;
  }
  else {
    # if we get here everything should be a number
    return ($test > $min && $test <= $max);
  }
}

1;
__END__
