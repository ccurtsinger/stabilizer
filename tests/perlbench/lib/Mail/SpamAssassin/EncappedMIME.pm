# Mail::SpamAssassin::EncappedMIME - interface to Mail::Audit message text,
# for MIME::Entity-based Mail::Audit objects.

package Mail::SpamAssassin::EncappedMIME;

use Carp;
use strict;
use bytes;

use Mail::SpamAssassin::EncappedMessage;

use vars	qw{
  	@ISA
};

@ISA = qw(Mail::SpamAssassin::EncappedMessage);

###########################################################################

sub replace_body {
  my ($self, $aryref) = @_;

  my $bit = $self->{mail_object};
  while ($bit->parts > 0) {
    $bit = $bit->parts(0);
  }

  my $body = $bit->bodyhandle;

  return unless defined $body;
  ### Write data to the body:
  my $IO = $body->open("w")      || die "open body: $!";
  $IO->print(join "", @$aryref);
  $IO->close                  || die "close I/O handle: $!";
}

1;
