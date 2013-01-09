package Mail::SpamAssassin::NoLocker;

# For CPU2006, everything is single-threaded, so just sort of short-circuit
# all the locking.

use strict;
use bytes;

use Mail::SpamAssassin;
use Mail::SpamAssassin::Locker;

use vars qw{
  @ISA
};

@ISA = qw(Mail::SpamAssassin::Locker);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self;
}

sub safe_lock {
  my ($self, $path, $max_retries) = @_;

  return 1;     # Success!
}

sub safe_unlock {
  my ($self, $path) = @_;

  return;       # Success again!
}

1;
