#!/usr/bin/perl 

#
# $Log: checkspam.pl,v $
# Revision 1.3  2004/03/26 20:55:28  cloyce
# Multiply all SpamAssassin scores by 1000 to get around the need for FP math.
#
# Revision 1.2  2004/02/10 21:59:15  cloyce
# Add more debugging output
#
# Revision 1.1  2004/01/12 16:21:20  cloyce
# Big workload overhaul -- added Mail::SpamAssassin, updated CPU2000 components
#
#

use Mail::SpamAssassin;
use Mail::SpamAssassin::NoMailAudit;
use Mail::Header;
use Mail::Util;
use Digest::MD5;
$^H |= 1;	# use integer!

$| = 1;
# Debug levels.  Setting any level will cause validation to fail (duh)
# 1   -- general stuff
# 2   -- dump generated messages as they're processed
# 4   -- choose_header debugging
# 8   -- get_msg_line debugging
# 16  -- message checking heartbeat
# 32  -- show MD5 sums as they're generated
# 64  -- show numbers of body lines
$debug = 0; #65535 - 32;

srand(1018987167);

my $findmsg;# = 'f18d3d11b71452cf800370fff12c685a';

# Get %headers, @headerlist, $words
require 'mailcomp.pm' unless $findmsg;

# These are globalish because they need to persist across calls to
# get_msg_line, and in some cases it would be stupid and time-consuming
# to calculate them over and over again.
my @header_order = qw(X-Yow Subject Date To From Message-Id); # Reverse order
my $horderre = '('.join('|', @header_order).')';
my @headerlist = grep { !/$horderre/o } keys %headers;
my $numlines = @lines+0;
my %num_hdrs = map { $_ => @{$headers{$_}}+0 } keys %headers;
my $msg_state = 0;		# 0 -- Start of message 'From_'
				# 1 -- Doing 'Received:' headers
				# 2 -- Other header generation
				# 3 -- Body generation
my ($num_received_hdrs, $num_hdr_lines, $num_body_lines) = (0,0,0);
my ($cur_msg_lines, %cur_seen_hdrs) = (0, ());

my $spamtest = Mail::SpamAssassin->new();
# In the real world, a server processing so many messages would load and
# compile all the rules once, like this:
$spamtest->compile_now(0);

# Get the command line parameters
my ($num_msgs,			# Number of messages to generate
    $header_min,		# Minimum number of headers (lines)
    $header_max,		# Maximum number of headers (lines)
    $lines_min,			# Minimum # lines in message
    $lines_max,			# Maximum # lines in message
    $do_bayes,			# Do Bayesian scoring?
    $load_ham,                  # Load known ham?
    $load_spam,                 # Load known spam?
    $do_corpus                  # Classify the corpuses?
    ) = (@ARGV);

our %openf = ();
our %md5s = ();
our %ham = ();
our %spam = ();

# All of the message generation happens here, under the covers.
# Generate MD5s at the same time...
my $msgnum = $num_msgs;
foreach $msgref (read_random_mbox()) {
	my $md5 = Digest::MD5->md5_hex(join('', @{$msgref}));
	print "$msgnum: $md5\n";
        $msgs{$md5} = $msgref;
	$msgnum--;
}
warn "In gen" if $findmsg && exists($msgs{$findmsg}); # Can't happen

# Load the ham and the spam
if ($load_ham) { 
  require 'ham.pl';
  # These are just references, so it should be pretty fast.
  map { $msgs{$_} = $ham{$_} } keys %ham if $do_corpus;
  warn "In ham" if $findmsg && exists($ham{$findmsg});
}
if ($load_spam) { 
  require 'spam.pl';
  # These are just references, so it should be pretty fast.
  map { $msgs{$_} = $spam{$_} } keys %spam if $do_corpus;
  warn "In spam" if $findmsg && exists($spam{$findmsg});
}

map { delete $msgs{$_} } grep { $_ ne $findmsg } keys %msgs if $findmsg;

my $t = 0;
my $last_time = 0;
$num_msgs = (keys %msgs)+0;
print "\ncheckspam $num_msgs $header_min $header_max $lines_min $lines_max $do_bayes\n";

if ($debug & 32) {
    print "MD5s and references:\n";
    foreach (reverse sort keys %msgs) {
	print "$_: $msgs{$_}\n";
    }
}

my @rc = ();

print "Looking for spam:\n" if ($debug & 1);
foreach my $md5 (reverse sort keys %msgs) {
   print '.' if ($debug & 16);
   my $msgref = $msgs{$md5};
   print "$md5: $msgref\n" if ($debug & 32);

   if ($debug & 2) {
#      print Data::Dumper->Dump([$md5, $msgref], [qw(md5 msgref)]),"\n";
       print "$md5:\n";
       print ' '.join(' ', @{$msgref}),"\n";
   }

   my $mail = Mail::SpamAssassin::NoMailAudit->new('data' => $msgref);
   my $status = $spamtest->check($mail);
   print "${md5}:\n";
   if ($status->is_spam()) {
     printf "  SPAM[%6d]: %s\n", $status->get_hits(), $status->get_names_of_tests_hit();
  } else {
     printf "  NOT SPAM[%6d]: %s\n", $status->get_hits(), $status->get_names_of_tests_hit();
  }
  # Rewrite the mail
  $status->rewrite_mail();
  my $newmsgref = [ @{$mail->header()}, "\r\n", @{$mail->body()} ];
  my $newmsgmd5 = Digest::MD5->md5_hex(join('', @{$newmsgref}));
  if ($debug & 64) {
    print "newmsg: $newmsgmd5\n  ".join("  ", @{$newmsgref})."\n";
  }
  print "  ...replaced by $newmsgmd5\n";
  $msgs{$newmsgmd5} = $newmsgref;
  delete $msgs{$md5};
  $status->finish();
} 

print join('', @rc)."\n" if @rc;

print "\n\n" if ($debug & 16);

#
# Following is the message generation state machine.  It's called by
# read_random_mbox() from the SPECified Mail::Utils distribution
#
sub get_msg_line {
    return undef unless ($num_msgs > 0);
    print "get_msg_line: msg_state == $msg_state:" if ($debug & 8);
    if ($msg_state == 0) {	# Start of new message; initialize everything
	$num_hdr_lines = int(rand($header_max - $header_min)) + $header_min;
        $num_hdr_lines = $header_max if ($num_header_lines > $header_max);

	$cur_msg_lines = 1;
        # Always have at least one Received header
	$num_received_hdrs = int(rand($num_hdr_lines - @header_order+0))+1;
        $num_received_hdrs = 1 if ($num_received_hdrs+(@header_order+0) > $header_max);
	$num_msg_lines = int(rand($lines_max - $lines_min)) + $lines_min - $num_hdr_lines;
        $num_msg_lines = $lines_max - $num_hdr_lines if ($num_msg_lines > $lines_max - $num_hdr_lines);
	%cur_hdrs_seen = map { $_ => 0 } ('From_', 'Received', @header_order);
	# Transition to the next state
	$msg_state = 1;
	print "New message #$num_msgs: $num_hdr_lines headers ($num_received_hdrs Received:), $num_msg_lines body lines\n";
	# Each message must have an envelope 'From ', or it's not mbox format!
	print "From_: " if ($debug & 64);
	my $header = choose_header('From_');
	print " $header" if ($debug & 8);
	return $header;
    } elsif ($msg_state == 1) {	# Do received headers
	if ($num_received_hdrs > 0) {
	    $num_received_hdrs--;
	    $num_hdr_lines--;
	    print "Received: " if ($debug & 64);
	    my $header = choose_header('Received');
	    print " $header" if ($debug & 8);
	    return $header;
	} else {
	    $msg_state = 2;
	    print " 'Received:' done.  Transitioning to normal header lines\n" if ($debug & 8);
	    return get_msg_line();
	}
    } elsif ($msg_state == 2) {
	if ($num_hdr_lines > 0) {
	    my $hdrnum = int(rand(@headerlist+0));
	    my $hdr = $headerlist[$hdrnum];
	    if (!defined $header_order[$num_hdr_lines]) { # Choose a random one
		while (exists $cur_hdrs_seen{$hdr}) {
		    $hdrnum = int(rand(@headerlist+0));
		    $hdr = $headerlist[$hdrnum];
		}
	    } else {
		$hdr = $header_order[$num_hdr_lines];
	    }
	    $num_hdr_lines--;
	    print "$hdr: " if ($debug & 64);
	    my $header = choose_header($hdr);
	    print " $header" if ($debug & 8);
	    return $header;
	} else {
	    print "Body begins:\n" if ($debug & 64);
	    print " Headers done.  Transitioning to message body\n" if ($debug & 8);
	    $msg_state = 3;
	    return "\n";	# End of headers
	}
    } elsif ($msg_state == 3) {
	if ($num_msg_lines > 0) {
	    $num_msg_lines--;
	    my $linenum = int(rand($numlines));
	    print "$linenum\n" if ($debug & 64);
	    my $line = $lines[$linenum];
	    print " $linenum of $numlines = \"$line\"\n" if ($debug & 8);
	    return "$line\n";
	} else {
	    print " EOM\n" if ($debug & 8);
	    print "\n" if ($debug & 64);
	    $msg_state = 0;
	    $num_msgs--;
	    return "\n";	# End of message
	}
    }
}

sub choose_header {
    my ($hdr) = @_;
    print "choose_header($hdr): $num_hdrs{$hdr} choices\n" if ($debug & 4);
    my $hdrnum = int(rand($num_hdrs{$hdr}));
    my $header = $headers{$hdr}->[$hdrnum];
    print "  \"$header\"\n" if ($debug & 4);
    while (!defined($header) || $header =~ /^$/o) {
    	$hdrnum = int(rand($num_hdrs{$hdr}));
	$header = $headers{$hdr}->[$hdrnum];
	print "  \"$header\"\n" if ($debug & 4);
    }
    $cur_hdrs_seen{$hdr}++;
    print "$hdrnum\n" if ($debug & 64);
    return "$header\n";
}
