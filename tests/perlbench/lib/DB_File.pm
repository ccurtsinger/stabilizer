package DB_File;

# This is a faked-up version of DB_File that uses in-memory hashes instead
# of files.

# Written for 400.perlbench in SPEC CPU2006 by Cloyce D. Spradling

use strict;
use Fcntl;
require Tie::Hash;
our %db;
@DB_File::ISA = qw(Tie::Hash);

sub TIEHASH {
  my ($self, $name) = (shift, shift);
  my $mode = shift || O_RDWR;
  if (exists $db{$name}) {
    $db{$name}->{'mode'} = $mode;
  } else {
    $db{$name} = { 'hash' => {},
                   'mode' => $mode };
  }
  bless $db{$name}, $self;
}

sub FETCH {
  my ($self, $key) = @_;

  return undef unless exists($self->{'hash'}->{$key});
  return undef unless ($self->{'mode'} & (O_RDWR | O_RDONLY));
  return $self->{'hash'}->{$key};
}

sub STORE {
  my ($self, $key, $val) = @_;

  return undef unless ($self->{'mode'} & (O_RDWR | O_WRONLY));
  $self->{'hash'}->{$key} = $val;
}

sub DELETE {
  my ($self, $key) = @_;

  return undef unless ($self->{'mode'} & (O_RDWR | O_WRONLY));
  delete $self->{'hash'}->{$key} if exists($self->{'hash'}->{$key});
}

sub CLEAR {
  my ($self) = @_;

  return undef unless ($self->{'mode'} & (O_RDWR | O_WRONLY));
  $self->{'hash'} = {};
}


sub EXISTS {
  my ($self, $key) = @_;

  return undef unless ($self->{'mode'} & (O_RDWR | O_RDONLY));
  return exists($self->{'hash'}->{$key});
}

sub FIRSTKEY {
  my ($self) = shift;
  my $a = keys %{$self->{'hash'}};
  return each %{$self->{'hash'}};
}

sub NEXTKEY {
  my $self = shift;
  return each %{$self->{'hash'}};
}

sub DESTROY {
  my $self = shift;
  # Do nothing; untieing a hash doesn't make its file go away!
}

sub ftest {
  my ($path) = @_;

  return 1 if exists $db{$path};
  return undef;
}

sub rename {
  my ($old, $new) = @_;

  return undef unless exists($db{$old});
  $db{$new} = $db{$old};
  return 1;
}

