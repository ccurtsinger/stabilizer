=head1 NAME

Mail::SpamAssassin::AutoWhitelist - auto-whitelist handler for SpamAssassin

=head1 SYNOPSIS

  (see Mail::SpamAssassin)


=head1 DESCRIPTION

Mail::SpamAssassin is a module to identify spam using text analysis and
several internet-based realtime blacklists.

This class is used internally by SpamAssassin to manage the automatic
whitelisting functionality.  Please refer to the C<Mail::SpamAssassin>
documentation for public interfaces.

=head1 METHODS

=over 4

=cut

package Mail::SpamAssassin::AutoWhitelist;

use strict;
use bytes;

use Mail::SpamAssassin;

use vars	qw{
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
  };

  $self->{factor} = $main->{conf}->{auto_whitelist_factor};

  if (!defined $self->{main}->{pers_addr_list_factory}) {
    $self->{checker} = undef;
  } else {
    $self->{checker} =
  	$self->{main}->{pers_addr_list_factory}->new_checker ($self->{main});
  }

  bless ($self, $class);
  $self;
}

###########################################################################

=item $meanscore = awl->check_address($addr, $originating_ip);

This method will return the mean score of all messages associated with the
given address, or undef if the address hasn't been seen before.

If B<$originating_ip> is supplied, it will be used in the lookup.

=cut

sub check_address {
  my ($self, $addr, $origip) = @_;

  if (!defined $self->{checker}) {
    return undef;		# no factory defined; we can't check
  }

  $self->{entry} = undef;

  # note: $origip could be undef here, if no public IP was found in the
  # message headers.
  my $fulladdr = $self->pack_addr ($addr, $origip);
  $self->{entry} = $self->{checker}->get_addr_entry ($fulladdr);

  if (!defined $self->{entry}->{count} || $self->{entry}->{count} == 0) {
    # no entry found
    if (defined $origip) {
      # try upgrading a default entry (probably from "add-addr-to-foo")
      my $noipaddr = $self->pack_addr ($addr, 'cmd');
      my $noipent = $self->{checker}->get_addr_entry ($noipaddr);

      if (defined $noipent->{count} && $noipent->{count} > 0) {
	dbg ("AWL: found entry w/o IP address for $addr: replacing with $origip");
	$self->{checker}->remove_entry($noipent);
	$self->{entry} = $noipent;
	$self->{entry}->{addr} = $fulladdr;
      }
    }
  }

  if ($self->{entry}->{count} == 0) { return undef; }

  return $self->{entry}->{totscore}/$self->{entry}->{count};
}

###########################################################################

=item awl->add_score($score);

This method will add half the score to the current entry.  Half the
score is used, so that repeated use of the same From and IP address
combination will gradually reduce the score.

=cut

sub add_score {
  my ($self,$score) = @_;

  if (!defined $self->{checker}) {
    return undef;		# no factory defined; we can't check
  }

  $self->{entry}->{count} ||= 0;
  $self->{checker}->add_score($self->{entry}, $score);
}

###########################################################################

=item awl->add_known_good_address($addr);

This method will add a score of -100 to the given address -- effectively
"bootstrapping" the address as being one that should be whitelisted.

=cut

sub add_known_good_address {
  my ($self, $addr) = @_;

  return $self->modify_address($addr, -100);
}

###########################################################################

=item awl->add_known_bad_address($addr);

This method will add a score of 100 to the given address -- effectively
"bootstrapping" the address as being one that should be blacklisted.

=cut

sub add_known_bad_address {
  my ($self, $addr) = @_;

  return $self->modify_address($addr, 100);
}

###########################################################################

sub remove_address {
  my ($self, $addr) = @_;

  return $self->modify_address($addr, undef);
}

###########################################################################

sub modify_address {
  my ($self, $addr, $score) = @_;

  if (!defined $self->{checker}) {
    return undef;		# no factory defined; we can't check
  }

  my $fulladdr = $self->pack_addr ($addr, 'cmd');
  my $entry = $self->{checker}->get_addr_entry ($fulladdr);

  # remove any old entries (will remove per-ip entries as well)
  # always call this regardless, as the current entry may have 0
  # scores, but the per-ip one may have more
  $self->{checker}->remove_entry($entry);

  # remove address only, no new score to add
  if (!defined($score)) { return 1; }

  # else add score. get a new entry first
  $entry = $self->{checker}->get_addr_entry ($fulladdr);
  $self->{checker}->add_score($entry, $score);

  return 0;
}

###########################################################################

sub finish {
  my $self = shift;

  if (!defined $self->{checker}) { return undef; }
  $self->{checker}->finish();
}

###########################################################################

# Entries in the db can have:
#
#   "from@addr|ip=nnn.nnn"	= from <from@addr>, IP addr nnn.nnn.*.*
#   "from@addr|ip=none"		= from <from@addr>, via private networks
#   "from@addr|ip=cmd"		= from <from@addr>, "commandline"
#
# the "commandline" variant is used for command-line manipulation of the
# AWL; it'll be upgraded into an "ip=nnn.nnn" entry first time it is
# used.

sub pack_addr {
  my ($self, $addr, $origip) = @_;

  $addr = lc $addr;
  $addr =~ s/[\000\;\'\"\!\|]/_/gs;	# paranoia

  if (!defined $origip) {
    # could not find an IP address to use, could be localhost mail or from
    # the user running "add-addr-to-*".
    $origip = 'none';
  } elsif ($origip eq 'cmd') {
    # pass that through
  } else {
    $origip =~ s/\.\d{1,3}\.\d{1,3}$//gs;
  }

  $origip =~ s/[^0-9\.noecmd]/_/gs;	# paranoia
  $addr."|ip=".$origip;
}

###########################################################################

sub dbg { Mail::SpamAssassin::dbg (@_); }

1;
