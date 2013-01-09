# Mail::SpamAssassin::AuditMessage - interface to Mail::Audit message text
package Mail::SpamAssassin::AuditMessage;

use strict;
use bytes;
use Carp;

use Mail::SpamAssassin::NoMailAudit;
use Mail::SpamAssassin::Message;

use vars qw{
  @ISA
};

@ISA = qw(Mail::SpamAssassin::Message);

###########################################################################

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self->{headers_pristine} = $self->get_all_headers();
  $self;
}

sub create_new {
  my ($self, @args) = @_;
  return Mail::SpamAssassin::NoMailAudit->new(@args);
}

sub put_header {
  my ($self, $hdr, $text) = @_;
  $self->{mail_object}->put_header ($hdr, $text);
}

sub delete_header {
  my ($self, $hdr) = @_;
  $self->{mail_object}->{obj}->head->delete ($hdr);
}

sub get_all_headers {
  my ($self) = @_;
  $self->{mail_object}->header();
}

sub get_pristine {
  my ($self) = @_;
  return join ('', $self->{headers_pristine}, "\n",
		 @{ $self->get_body() });
}

sub replace_original_message {
  my ($self, $data) = @_;

  my $textarray;
  if (ref $data eq 'ARRAY') {
    $textarray = $data;
  } elsif (ref $data eq 'GLOB') {
# CPU2006 -- no file I/O, please
#    if (defined fileno $data) {
#      $textarray = [ <$data> ];
#    }
  }

  # now split into [ headerline, ... ] and [ bodyline, ... ]
  my $heads = [ ];
  my $line;
  while (defined ($line = shift @{$textarray})) {
    last if ($line =~ /^$/);
    push (@{$heads}, $line);
  }

  $self->{mail_object}->head->empty;
  $self->{mail_object}->head->header ($heads);

  # take another copy of this
  $self->{headers_pristine} = $self->get_all_headers();

  $self->replace_body ($textarray);
}

1;
