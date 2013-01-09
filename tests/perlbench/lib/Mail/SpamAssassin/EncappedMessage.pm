# Mail::SpamAssassin::EncappedMessage - interface to Mail::Audit message text,
# for versions of Mail::Audit with methods to encapsulate the message text
# itself (ie. not exposing a Mail::Internet object).

package Mail::SpamAssassin::EncappedMessage;

use strict;
use bytes;
use Carp;


use Mail::SpamAssassin::AuditMessage;

use vars qw{
  @ISA
};

@ISA = qw(Mail::SpamAssassin::AuditMessage);

###########################################################################

sub replace_header {
  my ($self, $hdr, $text) = @_;
  $self->{mail_object}->replace_header ($hdr, $text);
}

sub get_pristine_header {
  my ($self, $hdr) = @_;
  return $self->get_header ($hdr);
}

sub get_header {
  my ($self, $hdr) = @_;

  # Jul  1 2002 jm: needed to support 2.1 and later Mail::Audits, which
  # modified the semantics of get() for no apparent reason (argh).

  if ($Mail::Audit::VERSION > 2.0) {
    return $self->{mail_object}->head->get ($hdr);
  } else {
    return $self->{mail_object}->get ($hdr);
  }
}

sub get_body {
  my ($self) = @_;
  $self->{mail_object}->body();
}

sub replace_body {
  my ($self, $aryref) = @_;

  # Jul  1 2002 jm: use MIME::Body to support newer versions of
  # Mail::Audit. protect against earlier versions that don't have is_mime()
  # method, and load the MIME::Body class using a string eval so SA
  # doesn't itself have to require the MIMETools classes.
  #
  if (eval { $self->{mail_object}->is_mime(); }) {
    my $newbody;
    # please leave the eval and use on the same line.  kluge around a bug in RPM 4.1.
    # tvd - 2003.02.25
    eval 'use MIME::Body;
      my $newbody = new MIME::Body::InCore ($aryref);
    ';
    die "MIME::Body::InCore ctor failed" unless defined ($newbody);
    return $self->{mail_object}->bodyhandle ($newbody);
  }

  return $self->{mail_object}->body ($aryref);
}

1;
