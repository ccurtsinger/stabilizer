# Mail::SpamAssassin::Message - interface to any mail message text/headers

package Mail::SpamAssassin::Message;

use strict;
use bytes;
use Carp;

use vars qw{
  @ISA
};

@ISA = qw();

###########################################################################

sub new {
  my $class = shift;
  my ($mail_object) = @_;

  my $self = {
    'mail_object' 	=> $mail_object,
    'metadata'		=> { },
    'is_spamassassin_wrapper_object' => 1
  };
  bless ($self, $class);
  $self;
}

###########################################################################

sub get_mail_object {
  my ($self) = @_;
  return $self->{mail_object};
}

###########################################################################

sub create_new {
  my ($self, @args) = @_;
  die "unimplemented base method";
}

sub get_pristine_header {
  my ($self, $hdr) = @_;
  die "unimplemented base method";
}

sub get_header {
  my ($self, $hdr) = @_;
  die "unimplemented base method";
}

sub put_header {
  my ($self, $hdr, $text) = @_;
  die "unimplemented base method";
}

sub get_all_headers {
  my ($self) = @_;
  die "unimplemented base method";
}

sub replace_header {
  my ($self, $hdr, $text) = @_;
  die "unimplemented base method";
}

sub delete_header {
  my ($self, $hdr) = @_;
  die "unimplemented base method";
}

sub get_body {
  my ($self) = @_;
  die "unimplemented base method";
}

sub get_pristine {
  my ($self) = @_;
  die "unimplemented base method";
}

sub replace_body {
  my ($self, $aryref) = @_;
  die "unimplemented base method";
}

sub replace_original_message {
  my ($self, $aryref) = @_;
  die "unimplemented base method";
}

###########################################################################
# extremely simple shared metadata structure.  This emulates the
# header structure of an RFC-2822 mail message, but these "headers"
# are never actually added to the mail; instead they are dropped
# as soon as the message object is destroyed, and will never
# appear in the string representation.

sub get_metadata {
  my ($self, $hdr) = @_;
  $self->{metadata}->{$hdr};
}

sub put_metadata {
  my ($self, $hdr, $text) = @_;
  $self->{metadata}->{$hdr} = $text;
}

sub get_all_metadata {
  my ($self) = @_;

  my @ret = ();
  foreach my $key (sort keys %{$self->{metadata}}) {
    push (@ret, $key, ": ", $self->{metadata}->{$key}, "\n");
  }
  return join ("", @ret);
}

sub replace_metadata {
  my ($self, $hdr, $text) = @_;
  $self->{metadata}->{$hdr} = $text;
}

sub delete_metadata {
  my ($self, $hdr) = @_;
  delete $self->{metadata}->{$hdr};
}

1;
