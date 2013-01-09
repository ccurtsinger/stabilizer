package Mail::SpamAssassin::Locker;

use strict;
use bytes;
use Fcntl;

use Mail::SpamAssassin;

use vars qw{
  @ISA
};

@ISA = qw();

###########################################################################

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my $self = { };
  bless ($self, $class);
  $self;
}

###########################################################################

sub safe_lock {
  my ($self, $path, $max_retries) = @_;
  # max_retries is optional, should default to about 30
  die "safe_lock not implemented by Locker subclass";
}

###########################################################################

sub safe_unlock {
  my ($self, $path) = @_;
  die "safe_unlock not implemented by Locker subclass";
}

###########################################################################

1;
