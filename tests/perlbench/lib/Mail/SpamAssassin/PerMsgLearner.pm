=head1 NAME

Mail::SpamAssassin::PerMsgLearner - per-message status (spam or not-spam)

=head1 SYNOPSIS

  my $spamtest = new Mail::SpamAssassin ({
    'rules_filename'      => '/etc/spamassassin.rules',
    'userprefs_filename'  => $ENV{HOME}.'/.spamassassin.cf'
  });
  my $mail = Mail::SpamAssassin::NoMailAudit->new();

  my $status = $spamtest->learn ($mail);
  ...


=head1 DESCRIPTION

The Mail::SpamAssassin C<learn()> method returns an object of this
class.  This object encapsulates all the per-message state for
the learning process.

=head1 METHODS

=over 4

=cut

package Mail::SpamAssassin::PerMsgLearner;

use strict;
use bytes;

use Mail::SpamAssassin;
use Mail::SpamAssassin::AutoWhitelist;
use Mail::SpamAssassin::PerMsgStatus;
use Mail::SpamAssassin::Bayes;

use vars qw{
  @ISA
};

@ISA = qw();

###########################################################################

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my ($main, $msg) = @_;

  my $self = {
    'main'              => $main,
    'msg'               => $msg,
    'learned'		=> 0,
  };

  $self->{conf} = $self->{main}->{conf};

  $self->{bayes_scanner} = $self->{main}->{bayes_scanner};

  bless ($self, $class);
  $self;
}

###########################################################################

=item $status->learn_spam($id)

Learn the message as spam.

C<$id> is an optional message-identification string, used internally
to tag the message.  If it is C<undef>, the Message-Id of the message
will be used.  It should be unique to that message.

=cut

sub learn_spam {
  my ($self, $id) = @_;

  if ($self->{main}->{learn_with_whitelist}) {
    $self->{main}->add_all_addresses_to_blacklist ($self->{msg});
  }

  # use the real message-id here instead of mass-check's idea of an "id",
  # as we may deliver the msg into another mbox format but later need
  # to forget it's training.
  $self->{learned} = $self->{bayes_scanner}->learn (1, $self->{msg}, $id);
}

###########################################################################

=item $status->learn_ham($id)

Learn the message as ham.

C<$id> is an optional message-identification string, used internally
to tag the message.  If it is C<undef>, the Message-Id of the message
will be used.  It should be unique to that message.

=cut

sub learn_ham {
  my ($self, $id) = @_;

  if ($self->{main}->{learn_with_whitelist}) {
    $self->{main}->add_all_addresses_to_whitelist ($self->{msg});
  }

  $self->{learned} = $self->{bayes_scanner}->learn (0, $self->{msg}, $id);
}

###########################################################################

=item $status->forget($id)

Forget about a previously-learned message.

C<$id> is an optional message-identification string, used internally
to tag the message.  If it is C<undef>, the Message-Id of the message
will be used.  It should be unique to that message.

=cut

sub forget {
  my ($self, $id) = @_;

  if ($self->{main}->{learn_with_whitelist}) {
    $self->{main}->remove_all_addresses_from_whitelist ($self->{msg});
  }

  $self->{learned} = $self->{bayes_scanner}->forget ($self->{msg}, $id);
}

###########################################################################

=item $didlearn = $status->did_learn()

Returns C<1> if the message was learned from or forgotten succesfully.

=cut

sub did_learn {
  my ($self) = @_;
  return ($self->{learned});
}

###########################################################################

=item $status->finish()

Finish with the object.

=cut

sub finish {
  my $self = shift;
  delete $self->{main};
  delete $self->{msg};
  delete $self->{conf};
}

###########################################################################

sub dbg { Mail::SpamAssassin::dbg (@_); }

###########################################################################

1;
__END__

=back

=head1 SEE ALSO

C<Mail::SpamAssassin>
C<spamassassin>

