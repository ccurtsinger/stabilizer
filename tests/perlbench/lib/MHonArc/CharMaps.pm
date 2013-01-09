##---------------------------------------------------------------------------##
##  File:
##	$Id: CharMaps.pm,v 1.2 2003/03/05 22:17:15 ehood Exp $
##  Author:
##      Earl Hood       earl@earlhood.com
##  Description:
##	POD after __END__
##---------------------------------------------------------------------------##
##    Copyright (C) 1997-2002	Earl Hood, earl@earlhood.com
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

package MHonArc::CharMaps;

use strict;
use vars qw( @ISA @EXPORT %HTMLSpecials $HTMLSpecials );

use Carp;
use Exporter ();
@ISA = qw( Exporter );
@EXPORT = qw( $HTMLSpecials %HTMLSpecials );

# The following two variables need to be in sync.  The hash version should
# have contain mappings for each character in the scalar version.
$HTMLSpecials = "\x22\x26\x3C\x3E";
%HTMLSpecials = (
    "\x22" =>	'&quot;',   	# ISOnum : Quotation mark
    "\x26" =>	'&amp;',  	# ISOnum : Ampersand
    "\x3C" =>	'&lt;',   	# ISOnum : Less-than sign
    "\x3E" =>	'&gt;',   	# ISOnum : Greater-than sign
);

sub new {
    my $self    = { };
    my $mod     = shift;        # Name of module
    my $tbl     = shift;        # Table of charsets to map files
    my $class   = ref($mod) || $mod;

    $self->{'_maps'} = { };	# Loaded maps
    $self->{'_tbl'} = $tbl;	# charsets -> map files table
    bless $self, $class;
    $self;
}

sub set_map {
  my $self	= shift;
  my $charset	= shift;
  my $map	= shift;
  my $old_map	= $self->{'_maps'}{$charset} || undef;
  $self->{'_maps'}{$charset} = $map;
  $old_map;
}

sub get_map {
  my $self	= shift;
  my $charset	= shift;

  my $map = $self->{'_maps'}{$charset};
  return $map  if defined($map);

  my $file = $self->{'_tbl'}{$charset};
  if (!defined($file)) {
      carp 'Warning: Unknown charset: ', $charset, "\n";
      $map = $self->{'_maps'}{$charset} = { };

  } else {
      delete $INC{$file};
      eval {
	  $map = $self->{'_maps'}{$charset} = require $file;
      };
      if ($@) {
	  carp 'Warning: ', $@, "\n";
	  $map = $self->{'_maps'}{$charset} = { };
      }
  }
  $map;
}

##---------------------------------------------------------------------------##
1;
__END__

=head1 SYNOPSIS

  use MHonArc::CharMaps;
  my %map_tbl = (
    charset1  => 'charset1_file.pm',
    charset2  => 'charset2_file.pm',
    #...
    charsetN  => 'charsetN_file.pm',
  );

  my $char_maps = MHonArc::CharMaps->new(\%map_tbl);
  my $map = $char_maps->get_map('charset1');

=head1 DESCRIPTION

MHonArc::CharMaps provides management for character mapping tables.

=head1 VERSION

$Id: CharMaps.pm,v 1.2 2003/03/05 22:17:15 ehood Exp $

=head1 AUTHOR

Earl Hood, earl@earlhood.com

MHonArc comes with ABSOLUTELY NO WARRANTY and MHonArc may be copied only
under the terms of the GNU General Public License, which may be found in
the MHonArc distribution.

=cut

