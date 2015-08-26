use warnings;
use strict;
use sort 'stable';

package Utils;

sub Pattern {
  my @patternalphabet = qw/a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W X Y Z 0 1 2 3 4 5 6 7 8 9 + -/;
  my $word = shift;
  my $pos = 0;
  my %tr = ();
  $tr{' '} = ' ';
  for (my $i = 0; $i < length($word); $i++) {
    next if $tr{substr($word,$i,1)};
    $tr{substr($word,$i,1)} = $patternalphabet[$pos];
    $pos++;
  }
  return ReplaceString($word,\%tr);
}


sub APattern {
  my $ngram = shift;
  
  my $count = [];
  
  my @words = split /\s+/, $ngram;
  for (my $i = 0; $i < @words; $i++) {
    foreach my $c (split //, $words[$i]) {
      $count->[$i]{$c} = $count->[$i]{$c} ? $count->[$i]{$c}+1 : 1;
    }
  }
  
  my @new_words = ();
  for (my $i = 0; $i < @words; $i++) {
    my @chars_in_order = split //, $words[$i];
    for (my $j = scalar(@words)-1; $j >= 0; $j--) {
      no warnings 'uninitialized';
      @chars_in_order = sort {$count->[$j]{$b} <=> $count->[$j]{$a}} @chars_in_order; 
    }
    $new_words[$i] = join '', @chars_in_order;
  }  
  
  return Pattern(join(' ', @new_words));
}


sub ReplaceString {
  my ($text, $hash) = @_;
  my $string = '';
  foreach my $c (split //, $text) {
    if ($hash->{$c}) {
      $string .= $hash->{$c};
    } else {
      $string .= $c;
    }
  }
  return $string;  
}


sub ReadPList {
  my ($file,$gwp,$word,$maxlen,$nospace) = @_;
  
  open FILE, '<', $file || die $!;  
  while (<FILE>) {
    chomp;
    s/\s+$//g;
    
    if ($nospace) {
      s/ //g;
    }
    
    my ($order,$pattern,@ngrams) = split /\t+/;
    
    if ($order == 1) {
      foreach my $ngram (@ngrams) {      
        $word->{$ngram} = 1;
      }
    }

    if ($nospace) {
      $order = 1;
    }
    
    if ($order == 1) {
      foreach my $ngram (@ngrams) {      
        if (length($ngram) > $$maxlen) {
          $$maxlen = length($ngram);
        }
      }
    }
    
    if ($gwp->[$order]->{$pattern}) {
      push @{$gwp->[$order]->{$pattern}}, @ngrams;
    } else {
      @{$gwp->[$order]->{$pattern}} = @ngrams;
    }
  }
  close FILE || die $!;
}


sub PrintKey {
  my ($key,$C) = @_;
  
  my %tr = ();    
  for (my $i = 0; $i < @$C; $i++) {
    $tr{$C->[$i]} = substr($key,$i,1);
  }
  
  foreach my $c (sort @$C) {
    print $c;
  }
  print "\n";
  foreach my $c (sort @$C) {
    print $tr{$c};
  }
  print "\n\n";
}


sub Sim {
  my ($x, $y) = @_;
  my $com = 0;
  for (my $i = 0; $i < length($x); $i++) {
    $com++ if substr($x,$i,1) eq substr($y,$i,1);
  }
  return $com/length($x);
}


sub Decipher {
  my ($ctext, $key, @C) = @_;
  
  my %tr = ();    
  for (my $i = 0; $i < @C; $i++) {
    $tr{$C[$i]} = substr($key,$i,1);
  }
  
  return ReplaceString($ctext,\%tr);
}

1;
