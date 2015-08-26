use warnings;
use strict;

package FreqAnalysis;

sub GetSortedAlphabet {
  my ( $stringref ) = @_;
  my %c;
  foreach my $t (split //, $$stringref) {
    next unless $t =~ /[a-zA-Z]/;
    $c{$t} = $c{$t} ? $c{$t}+1 : 1;
  }

  return sort {$c{$b} <=> $c{$a}} keys %c;
}

sub GetSortedAlphabetNonalph {
  my ( $stringref ) = @_;
  my %c;
  foreach my $t (split //, $$stringref) {
    next if $t =~ /\s/;
    $c{$t} = $c{$t} ? $c{$t}+1 : 1;
  }

  return sort {$c{$b} <=> $c{$a}} keys %c;
}

sub GetFreqKey {
  # Arguments are $P and $C, references to the ptext and ctext alphabets,
  # sorted from most to least frequent.
  my ( $P, $C ) = @_;
  my %c2p = ();

  for (my $i = 0; $i < @$C; $i++) {
    my $j = $i < @$P ? $i : scalar(@$P)-1;
    $c2p{$C->[$i]} = $P->[$j];      
  }

  my $deckey = '';
  foreach my $c (@$C) {
    $deckey .= $c2p{$c};
  }
  return $deckey;
}

###########################
##### OLD SUBROUTINES #####
###########################

sub FreqOrder {
  my ($stringref) = @_;
  my $string = $$stringref;
  
  my $total_letters = 0;
  my %letter_counts = ();
  
  foreach my $c (split //, $string) {
    next if $c eq ' ';
    next if $c =~ /\s/;    
    $total_letters++;
    $letter_counts{$c} = $letter_counts{$c} ? $letter_counts{$c} + 1 : 1;
  }
  
  my $order = '';
  foreach my $c (sort {$letter_counts{$b} <=> $letter_counts{$a}} keys %letter_counts) {
    $order .= $c;
  }
  return $order;
}

sub FreqKey {
  my $ctext = shift;
  my @alphabet = qw/a b c d e f g h i j k l m n o p q r s t u v w x y z/;
  my @ptextorder = qw/e t a o i n s h r d l u c m f w y p v b g k q j x z/;
  my %ctextcount = ();
  foreach my $l (@alphabet) {
    $ctextcount{$l} = CountLetter($l,$ctext);
  }
  my @ctextorder = sort {$ctextcount{$b} <=> $ctextcount{$a}} @alphabet;
  
  my %encrypt = ();
  foreach my $p (@ptextorder) {
    $encrypt{$p} = shift @ctextorder; 
  }
  
  my $key = '';
  foreach my $p (@alphabet) {
    $key .= $encrypt{$p}
  }
  
  return $key;
}

sub CountLetter {
  my ($l, $ctext) = @_;
  my $count = 0;
  foreach my $t (split //, $ctext) {
    $count++ if $t eq $l;
  }
  return $count;
}

1;
