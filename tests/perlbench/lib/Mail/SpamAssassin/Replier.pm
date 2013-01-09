# Mail::SpamAssassin::Replier - reply to a message with a canned response

package Mail::SpamAssassin::Replier;

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
  $class = ref($class) || $class;
  my ($main, $msg) = @_;

  my $self = {
    'main'		=> $main,
    'msg'		=> $msg,
  };

  $self->{conf} = $self->{main}->{conf};

  bless ($self, $class);
  $self;
}

###########################################################################

sub reply {
  my ($self, $replysender) = @_;

# CPU2006 shouldn't send mail
return;

  my $addr = $self->{msg}->get_header('From');
  if (!defined ($addr) || $addr eq '') {
    dbg ("no From: or Reply-To: header found, ignoring");
    return 0;
  }

  $addr =~ s/^.*?<(.+)>\s*$/$1/g                 # Foo Blah <jm@foo>
        or $addr =~ s/^(.+)\s\(.*?\)\s*$/$1/g;   # jm@foo (Foo Blah)

  require Mail::Internet;
  my $reply = new Mail::Internet();

  $reply->replace ('To', $addr);
  $reply->replace ('From', $replysender);

  my $text = $self->{conf}->{spamtrap_template};
  while ($text =~ s/^(\S+): (.*)$//m) {
    $reply->replace ($1, $2);
  }

  my $body = [
  	split (/$/, $text),
	"\n\n",
	$self->{msg}->get_all_headers(),
	"\n", 
	@{$self->{msg}->get_body()}
  ];

  $reply->body ($body);
  $reply->tidy_body ();

  # print $reply->as_string()."---\n\n";
  $reply->send();
}

###########################################################################

sub dbg { Mail::SpamAssassin::dbg (@_); }

1;
