use warnings;
use strict;

package PScore;

sub PScoreSingle {
  my ($e, $P, $x, $wordlm, $charlm, $ns) = @_;
  my $y = 1-$x;
  
  if (!ref($P)) {
    # expand $P into an array
    my @P_array = ($P,$P,$P,$P);
    $P = \@P_array;
  }
  
  my $score = 0;
  # Character score, order 3.
  my $f = $e;
  $f =~ s/ /_/g;
  $f = join(' ', split(//, $f));
  $score += $x * PScore($f,$P->[0],$charlm,3);
  # Word score, order 1.
  $score += $y * PScore($e,$P->[1],$wordlm,1);
  # Word score, order 2.
  $score += $y * PScore($e,$P->[2],$wordlm,2);
  # Word score, order 3.
  $score += $y * PScore($e,$P->[3],$wordlm,3);
  # Normalize.
  $score = $score / length($e);
  
  #if ($ns) {
  #  $score = ($score / scalar(split /\s+/, $e));
  #}
  
  return $score;
}

sub PScoreBatch {
  my ($list, $hash, $P, $x, $wordlm, $charlm, $ns) = @_;
  
  foreach my $e (@$list) { 
    $hash->{$e} = PScoreSingle($e, $P, $x, $wordlm, $charlm, $ns);
  }
}


sub PScore {
  my ($str, $P, $lm, $n) = @_;
  
  my $score = 0;
  
  my @tokens = split /\s+/, $str;
  for (my $i = 0; $i+($n-1) < @tokens; $i++) {  
    my @slice = @tokens[$i .. $i+($n-1)];
    my $ngram = join ' ', @slice;
    
    if ($lm->{$ngram}) {
      $score += $lm->{$ngram};
    } else {
      $score += $P;
    }
    
  }
  
  return $score;
}


sub ReadLM {
  my ($file, $hash) = @_;
  
  open FILE, '<', $file || die "[[$file]]\n$!";
  while (<FILE>) {
    chomp;
    my ($ngram, $prob) = split /\t+/;
    $hash->{$ngram} = $prob;
  }
  close FILE || die $!;
}

1;
