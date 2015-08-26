use lib '../Modules';
use warnings;
use strict;

no warnings 'recursion';

package NoSpace;

sub FindWords {
  my ($str, $is_word, $max_word_length) = @_;
  return $str if !$str;
  return $str if $is_word->{$str};
  return $str if $str !~ /\S/;
  
  for (my $length = $max_word_length; $length > 0; $length--) {
    for (my $offset = 0; $offset+$length-1 < length($str); $offset++) {    
      my $w = substr($str,$offset,$length);
      next unless $is_word->{$w};
      
      if ($offset == 0) {
        my $ret = "$w " . (FindWords(substr($str,$length), $is_word, $max_word_length));
        $ret =~ s/\s+/ /g;
        return $ret;
      } elsif ($offset + $length == length($str)) {
        my $ret = (FindWords(substr($str,0,$offset), $is_word, $max_word_length)) . " $w";
        $ret =~ s/\s+/ /g;
        return $ret;
      } else {
        my $ret = (FindWords(substr($str,0,$offset), $is_word, $max_word_length)) . " $w " . (FindWords(substr($str,$offset+$length), $is_word, $max_word_length));
        $ret =~ s/\s+/ /g;
        return $ret;
      }
    }
  }
  
  return $str;
}


1;
