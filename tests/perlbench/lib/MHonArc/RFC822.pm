##---------------------------------------------------------------------------##
##  File:
##      $Id: RFC822.pm,v 1.2 2003/03/07 08:03:41 ehood Exp $
##  Author:
##      Earl Hood	earl@earlhood.com
##	Module adapted to Perl 5 from Perl 4 library:
##	rfc822.pl -- A perl package to manipulate RFC822 mail headers
##	A. P. Barrett <barrett@ee.und.ac.za>, June 1993
##	Revision: 1.1 Date: 1993/06/28 11:28:18
##
##  Description:
##      Module to handle parsing of RFC 822 mail header strings.
##---------------------------------------------------------------------------##
##    Copyright (C) 1993          A. P. Barrett
##    Copyright (C) 1997,2003     Earl Hood, earl@earlhood.com
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
 
package MHonArc::RFC822;

use strict;
use Exporter ();
use vars qw( @ISA @EXPORT @EXPORT_OK $VERSION );
@ISA = qw ( Exporter );
$VERSION = "0.01";

@EXPORT = ();
@EXPORT_OK = qw(
    &tokenise
    &untokenise
    &uncomment
    &first_route_addr
    &first_addr_spec
);


##---------------------------------------------------------------------------##
## Synopsis:
##	use MHonArc::RFC822;
##
##	# sample input
##	$string = 'Joe (Random) User <@route:"j.r.l"@host.com>';
##
##---------------------------------------------------------------------------##
##	    @toks = MHonArc::RFC822::tokenise($string);
##
##	Convert string to tokens.
##	In an array context, returns:
##		('Joe', '(Random)', 'User', '<', '@', 'route', ':', 
##			'"j.r.l"', '@', 'host', '.', 'com', '>')
##	Not intended for use in a scalar context, but would return:
##		'Joe(Random)User<@route:"j.r.l"@host.com>'
##
##---------------------------------------------------------------------------##
##	    $newstring = MHonArc::RFC822::untokenise(@toks);
##
##	Convert tokens to string with minimum white space.
##	Not intended for use in an array context.
##	In a scalar context, returns:
##		'Joe(Random)User<@route:"j.r.l"@host.com>'
##
##---------------------------------------------------------------------------##
##	    @newtoks   = MHonArc::RFC822::uncomment($string);
##	    @newtoks   = MHonArc::RFC822::uncomment(@toks);
##	    $newstring = MHonArc::RFC822::uncomment($string);
##	    $newstring = MHonArc::RFC822::uncomment(@toks);
##
##	Remove comments.
##	In an array context, returns:
##		 ('Joe', 'User', '<', '@', 'route', ':', 
##			'"j.r.l"', '@', 'host', '.', 'com', '>')
##	In a scalar context, returns:
##		'Joe User<@route:"j.r.l"@host.com>'
##
##---------------------------------------------------------------------------##
##	    @newtoks   = MHonArc::RFC822::first_route_addr($string);
##	    @newtoks   = MHonArc::RFC822::first_route_addr(@toks);
##	    $newstring = MHonArc::RFC822::first_route_addr($string);
##	    $newstring = MHonArc::RFC822::first_route_addr(@toks);
##
##	Obtain first route-addr or addr-spec.
##
##	In an array context, returns:
##		 ('<', '@', 'route', ':',
##			'"j.r.l"', '@', 'host', '.', 'com', '>')
##	In a scalar context, returns:
##		'<@route:"j.r.l"@host.com>'
##
##---------------------------------------------------------------------------##
##	    @newtoks   = MHonArc::RFC822::first_addr_spec($string);
##	    @newtoks   = MHonArc::RFC822::first_addr_spec(@toks);
##	    $newstring = MHonArc::RFC822::first_addr_spec($string);
##	    $newstring = MHonArc::RFC822::first_addr_spec(@toks);
##
##	Obtain first addr-spec.
##	In an array context, returns:
##		 ('"j.r.l"', '@', 'host', '.', 'com')
##	In a scalar context, returns:
##		'"j.r.l"@host.com'
##---------------------------------------------------------------------------##

## Define some variables to help us write regexps.
my $self_delimiters = '<>@,;:.';		# use /[$self_delimiters]/
my $specials = $self_delimiters.'()\\\\"\\[\\]';# use /[$specials]/
my $quoted_pair = '\\\\.';			# use /$quoted_pair/
my $qp_or_bs_end = $quoted_pair.'|\\\\$';	# use /$qp_or_bs_end/

##---------------------------------------------------------------------------##
## Tokenise, per RFC 822.
##
## As an extension, allows atoms to contain quoted pairs.
## The last output token might contain an unterminated quoted pair,
## comment, domain literal or quoted string.
## Other output tokens might contain solitary unmatched special characters.
##
## Input is a single string.
## In an array context, output is a list of tokens.
## In a scalar context, output is a single string (not very useful).

sub tokenise {
    local $_ = shift;
    my (@outtoks);
    my ($firstchar);
    my ($comment, $comment_depth);

    while (s/^\s*(\S)/$firstchar = $1/e) {
	if ($firstchar =~ /[$self_delimiters]/o) {
	    # a special character as a self-delimiting token.
	    s/^(.)//;
	    push (@outtoks, $1);
	} elsif ($firstchar eq '"') {
	    # a quoted string.
	    # XXX we don't prohibit bare CR.
	    s/^(\"(?:$qp_or_bs_end|[^\\"])*(?:\"|\Z))//o;
	    push (@outtoks, $1);
	} elsif ($firstchar eq '[') {
	    # a domain literal.
	    # XXX we don't prohibit bare CR or '['.
	    s/^(\[(?:$qp_or_bs_end|[^\\\]])*(?:\]|$))//o;
	    push (@outtoks, $1);
	} elsif ($firstchar eq '(') {
	    # a comment.
	    do {
		s/^([^()]*([()]|$))//;
		$comment .= $1;
		$comment_depth++ if $2 eq '(';
		$comment_depth-- if $2 eq ')';
		do {
		    # XXX error recovery for unterminated comment
		    $comment_depth = 0;
		} if $2 eq '';
	    } until ($comment_depth == 0);
	    push (@outtoks, $comment);
	} elsif ($firstchar ne '\\' && $firstchar =~ /[$specials]/o) {
	    # an illegal special character.
	    s/^(.)//;
	    push (@outtoks, $1);
	} else {
	    # should be an atom, which is not allowed to contain
	    # special characters or control characters.
	    # we have already checked for all special chars except
	    # controls and backslash.
	    # XXX we don't check for controls.
	    # XXX we allow a quoted-pair as part of an atom.
	    s/^(($qp_or_bs_end|[^\s$specials])+)//o;
	    push (@outtoks, $1);
	 }
    }

    # return result
    wantarray ? @outtoks : &untokenise(@outtoks);
}

##---------------------------------------------------------------------------##
## Convert a list of tokens to a single string.
##
## Just pastes the tokens together, with blanks where they are essential.
##
## Input is a list of tokens.
## Output is a single string.

sub untokenise {
    my ($token, $prevtok);
    my ($result);
    my ($prev, $this);

    foreach $token (@_) {
	# Do we need a space?
	# A space is essential when both the left and right tokens
	# are either atoms or quoted strings.
	# XXX - Spaces are desirable in some other places, but for
	# 	now it's too difficult to worry about that.  It's
	#	context-dependent anyway -- for example, we sometimes
	#	want spaces after ':' and ',', but not when they appear
	#	inside a route-addr.  The tokener has no business knowing
	#	about such details.
	if ($result ne '') {
	    $prev = substr($prevtok, $[, 1);
	    $this = substr($token, $[, 1);
	    if (   ($this eq '"' || $this !~ /[$specials]/o)
		&& ($prev eq '"' || $prev !~ /[$specials]/o))
	    {
		$result .= ' ';
	    }
	}
	$result .= $token;
	$prevtok = $token;
    }

    # return result
    $result;
}

##---------------------------------------------------------------------------##
## Delete comments.
##
## Input can be a single string or a list of tokens.
## In an array context, output is a list of tokens.
## In a scalar context, output is a single string.

sub uncomment {
    my (@intoks) = @_;
    my (@outtoks);
    my ($token);

    # tokenise the input if we were given a single string
    @intoks = &tokenise($intoks[$[])  if $#intoks le $[;

    # delete comment tokens
    @outtoks = grep (/^[^(]/, @intoks);

    # return result
    wantarray ? @outtoks : &untokenise(@outtoks);
}

##---------------------------------------------------------------------------##
## Try to extract a single RFC-822 route-addr or addr-spec from a
## list of addresses.
##
## Returns the first route-addr or addr-spec if there are several
## (for example, if the input is a comma-separated list)..
## Garbage in, garbage out.
##
## Input can be a single string or a list of tokens.
## In an array context, output is a list of tokens.
## In a scalar context, output is a single string.

sub first_route_addr {
    my (@intoks) = @_;
    my (@outtoks);
    my ($token, $firstchar);
    my ($state) = 'start';

    # tokenise the input if we were given a single string
    @intoks = &tokenise($intoks[$[])  if $#intoks le $[;

    foreach $token (@intoks) {
	$firstchar = substr($token,0,1);
	if ($firstchar eq '(') {
	    # ignore comments
	    next;
	} elsif ($firstchar eq '<') {
	    # '<' is start of route-addr.
	    # discard what came before.
	    $state = 'routeaddr';
	    @outtoks = ($token);
	} elsif ($firstchar eq ':') {
	    # ':' might be end of phrase for a group,
	    # or might be end of route and start of addr-spec in route-addr.
	    if ($state eq 'routeaddr') {
		push (@outtoks, $token);
	    } else {
		$state = 'start';
		@outtoks = ();
	    }
	} elsif ($firstchar eq ',') {
	    # ',' might be a separator between addresses
	    # or might be part of a route inside a route-addr.
	    if ($state eq 'routeaddr') {
		push (@outtoks, $token);
	    } else {
		$state = 'start';
		last if $#outtoks ge $[; # we got what we wanted
	    }
	} elsif ($firstchar eq '>') {
	    # '>' is end of route-addr
	    push (@outtoks, $token);
	    $state = 'end';
	    last; # we got what we wanted
	} elsif ($firstchar eq ';') {
	    # ';' is end of group
	    $state = 'end';
	    last if $#outtoks ge $[; # we got what we wanted
	} else {
	    # accumulate valid tokens.
	    push (@outtoks, $token);
	}
    }

    # return result
    wantarray ? @outtoks : &untokenise(@outtoks);
}

##---------------------------------------------------------------------------##
## Try to extract a single RFC-822 addr-spec from a list of addresses.
##
## Returns the first addr-spec if there are several.
## Garbage in, garbage out.
##
## Input can be a single string or a list of tokens.
## In an array context, output is a list of tokens.
## In a scalar context, output is a single string.

sub first_addr_spec {
    my (@intoks) = @_;
    my ($token);
    my ($i, $startpos, $endpos);

    # Get the first route-addr or addr-spec
    @intoks = &first_route_addr(@intoks);

    # if starts with '<' then it was a route-addr.
    # Keep the stuff between the last ':' (if any) and the first '>'.
    if ($intoks[$[] eq '<') {
	$startpos = $[+1;	# skip the initial '<'
	$endpos = $#intoks;	# don't yet know if there is a final '>'
	foreach $i ($startpos..$endpos) {
	    $token = $intoks[$i];
	    if ($token eq '>') {
		$endpos = $i - 1;
		last;
	    } elsif ($token eq ':') {
		$startpos = $i + 1;
	    }
	}
    }
    # if it didn't start with '<' then it was an addr-spec
    else {
	$startpos = $[;
	$endpos = $#intoks;
    }

    # return result
    wantarray ? @intoks[$startpos..$endpos]
	      : &untokenise(@intoks[$startpos..$endpos]);
}

##---------------------------------------------------------------------------##
1;
