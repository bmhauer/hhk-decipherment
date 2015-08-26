use warnings;
use strict;

package ReadLM;

sub ReadWordList {
  # Takes a filename and a hash.
  my ($file, $words) = @_;
  
  open WORDS, '<', $file || die $!;
  while (<WORDS>) {
    chomp;
    my ($word, @other) = split /\t+/;
    $words->{$word} = 1;
  }
  close WORDS || die $!;
}


sub ReadUnigramLM {
  my ($file, $lm) = @_;
  
  open LM, '<', $file || die $!;
  while (<LM>) {
    chomp;
    my ($w1, $p) = split /\t+/;
    $lm->{$w1} = $p;
  }
  close LM || die $!;
}


sub ReadBigramLM {
  my ($file, $lm) = @_;
  
  open LM, '<', $file || die $!;
  while (<LM>) {
    chomp;
    my ($w1, $w2, $p) = split /\t+/;
    $lm->{$w1}{$w2} = $p;
  }
  close LM || die $!;
}


sub ReadTrigramLM {
  my ($file, $lm) = @_;
  
  open LM, '<', $file || die $!;
  while (<LM>) {
    chomp;
    my ($w1, $w2, $w3, $p) = split /\t+/;
    $lm->{$w1}{$w2}{$w3} = $p;
  }
  close LM || die $!;
}


sub ReadProbs {
  my ($file, $lm) = @_;
  
  open LM, '<', $file || die $!;
  while (<LM>) {
    chomp;
    my ($w, $p) = split /\t+/;
    $lm->{$w} = $p;
  }
  close LM || die $!;
}


1;