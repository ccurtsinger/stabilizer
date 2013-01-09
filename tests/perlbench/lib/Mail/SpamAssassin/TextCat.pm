#
# Copyright (C) 1997  Gertjan van Noord <vannoord@let.rug.nl>
# (original author)
#
# TextCat is located at http://odur.let.rug.nl/~vannoord/TextCat/
#
# Copyright (C) 2002  Daniel Quinlan
# (adapted for spamassassin, performance optimizations)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either the Artistic License or the GNU General
# Public License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.

package Mail::SpamAssassin::TextCat;

use strict;
use bytes;

use vars qw(
  $opt_a $opt_f $opt_t $opt_u
);

my @nm;
my $non_word_characters='0-9\s';

# settings
$opt_a = 10;
$opt_f = 0;
$opt_t = 400;
$opt_u = 1.05;

# $opt_a  If the number of languages to be returned by &classify is larger
#         than the value of $opt_a then an empty list is returned signifying
#         that the language is unknown.
#
# $opt_f  Before sorting is performed, the ngrams which occur $opt_f times
#         or less are removed.  This can be used to speed up the program for
#         longer inputs.  For shorter inputs, this should be set to 0.
#
# $opt_t  This option indicates the maximum number of ngrams that should be
#         compared with each of the language models (note that each of those
#         models is used completely).
#
# $opt_u  &classify returns a list of the best-scoring language together with
#         all languages which are less than $opt_u times worse.  Typical
#         values are 1.05 or 1.1.

sub classify {
  my ($self, $input) = @_;
  my %results;
  my $maxp = $opt_t;

  # create ngrams for input
  my @unknown = create_lm($input);

  # load language models once
  if (! @nm) {
    my @lm;
    my $ngram = {};
    my $rang = 1;
    dbg("Loading languages file...");
    open(LM, $self->{main}->{languages_filename})
	|| die "cannot open languages: $!\n";
    local $/ = undef;
    @lm = split(/\n/, <LM>);
    close(LM);
    # create language ngram maps once
    for (@lm) {
      # look for end delimiter
      if (/^0 (.+)/) {
	$ngram->{"language"} = $1;
	push(@nm, $ngram);
	# reset for next language
	$ngram = {};
	$rang = 1;
      }
      else {
	$ngram->{$_} = $rang++;
      }
    }
  }

  # test each language
  foreach my $ngram (@nm) {
    my $language = $ngram->{"language"};
    my $i = 0;
    my $p = 0;

    # compute result for language
    for (@unknown) {
      $p += exists($ngram->{$_}) ? abs($ngram->{$_} - $i) : $maxp;
      $i++;
    }
    $results{$language} = $p;
  }
  my @results = sort { $results{$a} <=> $results{$b} } keys %results;

  my $best = $results{$results[0]};

  my @answers=(shift(@results));
  while (@results && $results{$results[0]} < ($opt_u * $best)) {
    @answers=(@answers, shift(@results));
  }
  if (@answers > $opt_a) {
    dbg("Can't determine language uniquely enough");
    return ();
  }
  else {
    dbg("Language possibly: ".join(",",@answers));
    return @answers;
  }
}

sub create_lm {
  my %ngram;
  my @sorted;

  ($_) = @_;

  for (split("[$non_word_characters]+")) {
    $_ = "\000" . $_ . "\000";
    my $len = length($_);
    my $flen = $len;
    my $i;
    for ($i = 0; $i < $flen; $i++) {
      $len--;
      $ngram{substr($_, $i, 1)}++;
      ($len < 1) ? next : $ngram{substr($_, $i, 2)}++;
      ($len < 2) ? next : $ngram{substr($_, $i, 3)}++;
      ($len < 3) ? next : $ngram{substr($_, $i, 4)}++;
      if ($len > 3) { $ngram{substr($_, $i, 5)}++ };
    }
  }

  if ($opt_f > 0) {
    # as suggested by Karel P. de Vos <k.vos@elsevier.nl> we speed
    # up sorting by removing singletons, however I have very bad
    # results for short inputs, this way
    @sorted = sort { $ngram{$b} <=> $ngram{$a} }
		   (grep { $ngram{$_} > $opt_f } keys %ngram);
  }
  else {
    @sorted = sort { $ngram{$b} <=> $ngram{$a} } keys %ngram;
  }
  splice(@sorted, $opt_t) if (@sorted > $opt_t);

  return @sorted;
}

sub dbg { Mail::SpamAssassin::dbg (@_); }

1;
