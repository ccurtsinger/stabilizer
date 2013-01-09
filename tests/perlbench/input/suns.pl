#!/usr/local/bin/perl
# Developed by Kaivalya/Cloyce/Jason - Kmd
# Version 1.0 Tue Aug 27 14:01:53 CDT 2002
# Default output file name
$output_name = "validate";
$dict_name   = "WORDS";
# Dictionary name and optionally validation name can be provided
$dict_name   = shift(@ARGV) if (@ARGV);
$output_name = shift(@ARGV) if (@ARGV);

$| = 1;
$k = 0;
$b = "";

# open dictionary, scrambled file and validation file (optional)

#  if ($dict_name =~ m/\.(z|gz|Z)$/) {
#   open (DICT, "zcat $dict_name|") || die "Can't open file '$dict_name': $!\n";
#   } 
#  else {
   open (DICT, "<$dict_name") || die "Can't open file '$dict_name': $!\n";
#   }

open (OUTPUT, ">$output_name") || die "Can't open output file '$output_name'\n";

###### all files opened and available
#
#
print "Dictionary  - $dict_name\n";
print OUTPUT "Dictionary  - $dict_name\n";
print "Validation  - $output_name\n\n";
print OUTPUT "Validation  - $output_name\n\n";

#
# Read in dictionary, store it in associateve array

printf OUTPUT "Reading Dictionary : ";

# read dictionary, scramble it and also misspell  
# some of the words
while (<DICT>) {
       chomp;
       $element = $_;
       # scramble it
       $revelm = reverse split(//, $element);
       $dicthash++;
       push( @{$words{join( "", sort split( //, $_ ) )}}, $_ );
       &misspellit;  # mis-spell few words;
       push( @{$jwords{join("", sort split( //, $x ) )}}, $x );
}

# define two arryas:  scrambled and unable to scramble arrays
# these will be used for validation

@valid_scram = ();
@valid_scram_not = ();

# Cycle through scrambled and look up %words 

@sort_words = sort byfield keys( %jwords );

# while ( ($sort_word, $scrambled) = each( %jwords ) ) {
foreach $sort_word ( @sort_words ) {
	 $scrambled = $jwords{$sort_word};
         if (exists $words{$sort_word}) {
             @words = @{$words{$sort_word}};
	     foreach( @{$scrambled} ) {
		     push( @valid_scram,  sprintf("%24s --> @words\n", $_  ));
		     $unscrambled += @words;
	     }
         } else {
	     @words = @{$scrambled};
             push( @valid_scram_not, sprintf( "%24s\n", @words ) );
	     $couldnotunscramble += @words;
         }
}

print OUTPUT "\nWords unscrambled  : ", $unscrambled, "\n";
print OUTPUT "Can not unscrmble  : ", $couldnotunscramble, "\n\n";
print OUTPUT  "Validation output:\n\n";

print OUTPUT "        UNSCRAMBLED:\n";

$increment = int( ($#valid_scram + 1) * 0.010 );
$increment = 1 unless $increment;
print OUTPUT "Valid increment = ", $increment, "\n";

for( $i = 0; $i <= $#valid_scram; $i += $increment ) {
	print OUTPUT $valid_scram [ $i ];
}

print OUTPUT "\n CANNOT UNSCRAMBLE :\n";

$increment = int( ($#valid_scram_not + 1) * 0.10 );
$increment = 1 unless $increment;

print OUTPUT "Invalid increment = ", $increment, "\n";


for( $i = 0; $i <= $#valid_scram_not; $i += $increment ) {
	print OUTPUT $valid_scram_not [ $i ];
}

print OUTPUT "\n\n";

print "Finished\n";

# Release all resources (gracefully)
close (DICT);
close (OUTPUT);
exit (0);

#------------Mis-spell some of the scrambled words

sub misspellit {

$k++;

#  chop;

if (
    $k % 511   &&
    $k % 1023  && 
    $k % 4097  &&
    $k % 8193  &&
    $k % 16387 &&
    $k % 32767
    )   { &keepit; } 
    
else    { &fixspell; }
}
sub fixspell {
$x = join('', $b++, $revelm );
if ($j++ > 27) { $b = "a";
                 $j = 0;  
               }
}
sub keepit {
$x = $revelm;
}

sub byfield {
        return( $a cmp $b );
}

