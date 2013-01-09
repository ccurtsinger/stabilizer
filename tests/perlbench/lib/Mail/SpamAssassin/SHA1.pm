#
# RSA's SHA-1 in perl5 - "Fast" version.
#
# Usage:
#	$sha = sha1($data);
#
# Test Case:
#	$sha = sha1("squeamish ossifrage\n");
#	print $sha;
#	820550664cf296792b38d1647a4d8c0e1966af57
#
# This code is written for perl5, specifically any perl version after 5.002.
#
# This version has been somewhat optimized for speed, and gets about
# 10 KB per second on a PPC604-120 42T workstation running AIX.  Still
# pitiful compared with C.  Feel free to improve it if you can.
#
# Disowner:
#   This original perl implementation of RSADSI's SHA-1 was written by
#   John L. Allen, allen@gateway.grumman.com on 03/08/97.  No copyright
#   or property rights are claimed or implied.  You may use, copy, modify
#   and re-distribute it in any way you see fit, for personal or business
#   use, for inclusion in any free or for-profit product, royalty-free
#   and with no further obligation to the author.
#
# Copyright (C) 2002  Daniel Quinlan
# (adapted public domain code into a module)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either the Artistic License or the GNU General
# Public License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.

package Mail::SpamAssassin::SHA1;

require 5.002;
use strict;
use bytes;
use integer;

use vars qw(
  @ISA @EXPORT
);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(sha1);

use constant HAS_DIGEST_SHA1 => eval { require Digest::SHA1; };

sub sha1 {
  my ($data) = @_;

  if (HAS_DIGEST_SHA1) {
    # this is about 40x faster than the below perl version
    return Digest::SHA1::sha1_hex($data);
  }
  else {
    return SHA1($data);
  }
}

sub SHA1($) {

local $^W = 0;
local $_;
my @a = (16..19); my @b = (20..39); my @c = (40..59); my @d = (60..79);
my $data = $_[0];
my $aa = 0x67452301; my $bb = 0xefcdab89; my $cc = 0x98badcfe;
my $dd = 0x10325476; my $ee = 0xc3d2e1f0;
my ($a, $b, $c, $d, $e, $t, $l, $r, $p) = (0)x9;
my @W;

do {
  $_ = substr $data, $l, 64;
  $l += ($r = length);
  $r++, $_.="\x80" if ($r<64 && !$p++);	# handle padding, but once only ($p)
  @W = unpack "N16", $_."\0"x7;		# unpack block into array of 16 ints
  $W[15] = $l*8 if ($r<57);		# bit length of file in final block

	# initialize working vars from the accumulators

  $a=$aa, $b=$bb, $c=$cc, $d=$dd, $e=$ee;

	# the meat of SHA is 80 iterations applied to the working vars

  for(@W){
    $t = ($b&($c^$d)^$d)	+ $e + $_ + 0x5a827999 + ($a<<5|31&$a>>27);
    $e = $d; $d = $c; $c = $b<<30 | 0x3fffffff & $b>>2; $b = $a; $a = $t;
  }
  for(@a){
    $t = $W[$_-3]^$W[$_-8]^$W[$_-14]^$W[$_-16];
    $W[$_] = $t = ($t<<1|1&$t>>31);
    $t += ($b&($c^$d)^$d)	+ $e + 0x5a827999 + ($a<<5|31&$a>>27);
    $e = $d; $d = $c; $c = $b<<30 | 0x3fffffff & $b>>2; $b = $a; $a = $t;
  }
  for(@b){
    $t = $W[$_-3]^$W[$_-8]^$W[$_-14]^$W[$_-16];
    $W[$_] = $t = ($t<<1|1&$t>>31);
    $t += ($b^$c^$d)		+ $e + 0x6ed9eba1 + ($a<<5|31&$a>>27);
    $e = $d; $d = $c; $c = $b<<30 | 0x3fffffff & $b>>2; $b = $a; $a = $t;
  }
  for(@c){
    $t = $W[$_-3]^$W[$_-8]^$W[$_-14]^$W[$_-16];
    $W[$_] = $t = ($t<<1|1&$t>>31);
    $t += ($b&$c|($b|$c)&$d)	+ $e + 0x8f1bbcdc + ($a<<5|31&$a>>27);
    $e = $d; $d = $c; $c = $b<<30 | 0x3fffffff & $b>>2; $b = $a; $a = $t;
  }
  for(@d){
    $t = $W[$_-3]^$W[$_-8]^$W[$_-14]^$W[$_-16];
    $W[$_] = $t = ($t<<1|1&$t>>31);
    $t += ($b^$c^$d)		+ $e + 0xca62c1d6 + ($a<<5|31&$a>>27);
    $e = $d; $d = $c; $c = $b<<30 | 0x3fffffff & $b>>2; $b = $a; $a = $t;
  }

	# add in the working vars to the accumulators, modulo 2**32

  $aa+=$a, $bb+=$b, $cc+=$c, $dd+=$d, $ee+=$e;

} while $r>56;

sprintf "%.8x%.8x%.8x%.8x%.8x", $aa & 0xffffffff, $bb & 0xffffffff, $cc & 0xffffffff, $dd & 0xffffffff, $ee & 0xffffffff;
}

1;
