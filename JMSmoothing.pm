use warnings;
use strict;

package JMSmoothing;

sub prob_trigram_sentence {
  my ($sen, $A1, $A2, $A3, $l1, $l2, $l3) = @_;
  if (abs(1 - ($l1 + $l2 + $l3)) > 0.001) {
    die "Lambda's not normalized!";
  }
  $sen = replace_unknowns($sen, $A1, '<u>');
  #$sen = '<s> <s> ' . $sen . ' <\s> <\s>'; # add sentence boundaries
  my @words = split /\s+/, $sen; # split into words
  
  my $log_jm_prob = 0; # Running total of the log-prob (log(1) == 0)
  
  # Start at the first word.
  #for (my $i = $n-1; $i < @words; $i++) {
  for (my $i = 0; $i < @words; $i++) {
    my $w1 = $i >= 2 ? $words[$i-2] : '';
    my $w2 = $i >= 1 ? $words[$i-1] : '';
    my $w3 = $words[$i];
    
    my $unigram_prob =            $A1->{$w3}           ? $A1->{$w3}           : 0;
    my $bigram_prob  = $i >= 1 && $A2->{$w2}{$w3}      ? $A2->{$w2}{$w3}      : 0;
    my $trigram_prob = $i >= 2 && $A3->{$w1}{$w2}{$w3} ? $A3->{$w1}{$w2}{$w3} : 0;
    
    my $prob = ($l1 * $unigram_prob) + ($l2 * $bigram_prob) + ($l3 * $trigram_prob);
    $log_jm_prob += log( $prob );
  }
  
  return $log_jm_prob;
}


sub replace_unknowns {
  my ($string, $A1, $unk) = @_;
  $unk = '<u>' unless $unk;
  
  my @words = split /\s+/, $string;
  for (my $i = 0; $i < @words; $i++) {
    if (!$A1->{$words[$i]}) {
      $words[$i] = $unk;
    }
  }
  
  return join ' ', @words;
}


sub ProbCharWord {
  my ($dtext, $charlm1, $charlm2, $charlm3, $wordlm1, $wordlm2, $wordlm3,
      $cl1, $cl2, $cl3, $wl1, $wl2, $wl3, $x) = @_;
      
  my $dtext_char = $dtext;
  $dtext_char =~ s/\s/_/g;
  $dtext_char = join(' ', split(//, $dtext_char));
  my $charscore = 
    prob_trigram_sentence($dtext_char,$charlm1,$charlm2,$charlm3,$cl1,$cl2,$cl3);
  my $wordscore = 
    prob_trigram_sentence($dtext,$wordlm1,$wordlm2,$wordlm3,$wl1,$wl2,$wl3);
  return (($x * $charscore) + ((1-$x) * $wordscore));
}

1;
