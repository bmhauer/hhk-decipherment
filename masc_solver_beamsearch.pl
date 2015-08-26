# Mono-Alphabetic Substitution Cipher Solver

use warnings;
use strict;
#use lib '../Modules';
use Getopt::Long;
use Time::HiRes qw( clock );
use sort 'stable';
no warnings 'recursion';

use ReadLM;
use JMSmoothing;
use FreqAnalysis;
use PScore;
use Utils;
use NoSpace;

# Record current time.
my $start = time();
my $cpu_start = clock();

# Configure output for no delay (just in case).
$| = 1;

# Fix Trigram LMs
my $ngramorder = 3;

# Get options.
my ($wordlm1_file, $wordlm2_file, $wordlm3_file) 
  = ('lmtrain_nyt_word.unk.wlm1','lmtrain_nyt_word.unk.wlm2','lmtrain_nyt_word.unk.wlm3');
my ($charlm1_file, $charlm2_file, $charlm3_file) 
  = ('lmtrain_nyt_word.chr.clm1','lmtrain_nyt_word.chr.clm2','lmtrain_nyt_word.chr.clm3');
my ($wl1, $wl2, $wl3) = (0.129793302623898, 0.226872659329747, 0.643334038046355);
my ($cl1, $cl2, $cl3) = (0.0950848948641174, 0.229797965264228, 0.675117139871655);
my $x = 0.05;
my $ngramlist = 'lmtrain_nyt_word.patlst';

my $order = 'e t a o i n s r h l d c p u m f g y w b v k x j z q';
my $nospace = 0;
our $verbose = 0;
my $maxit = 10;
my $beamsize = 50;
my $patternlimit = 50;

GetOptions(
  "w1=s" => \$wordlm1_file,
  "w2=s" => \$wordlm2_file,
  "w3=s" => \$wordlm3_file,
  "c1=s" => \$charlm1_file,
  "c2=s" => \$charlm2_file,
  "c3=s" => \$charlm3_file,
  "cc=f" => \$x, # Character lm coefficient
  "nl=s" => \$ngramlist,
  
  "o"    => \$order,
  "n"    => \$nospace,
  "v"    => \$verbose,
  "mi=i" => \$maxit,
  "bs=i" => \$beamsize,
  "pl=i" => \$patternlimit,
);


Message("Starting run at", `date`);
Message(
  "\nCharacter LMs: $charlm1_file, $charlm2_file, $charlm3_file",
  "\nWord      LMs: $wordlm1_file, $wordlm2_file, $wordlm3_file",
  "\nCharacter LM coefficinet: $x",
  "\nnglist\t$ngramlist",
  
  "\nCiphers without spaces: $nospace",
  "\nMaximum iterations: $maxit",
  "\nMaximum beam size: $beamsize",
  "\nN-grams per pattern: $patternlimit",
  "\n",
);



Message("Starting up...");

# Declare cipher and plaintext alphabets...
my @P = split(/\s+/, $order);
my @C;

Message("Reading language models.");

# Read Language Models:
my $charlm1 = {};
ReadLM::ReadUnigramLM($charlm1_file, $charlm1);
my $charlm2 = {};
ReadLM::ReadBigramLM($charlm2_file, $charlm2);
my $charlm3 = {};
ReadLM::ReadTrigramLM($charlm3_file, $charlm3);
my $wordlm1 = {};
ReadLM::ReadUnigramLM($wordlm1_file, $wordlm1);
my $wordlm2 = {};
ReadLM::ReadBigramLM($wordlm2_file, $wordlm2);
my $wordlm3 = {};
ReadLM::ReadTrigramLM($wordlm3_file, $wordlm3);

# Read ngram list
Message("Processing n-gram list.");
my $grams_with_pattern = [0,{},{},{}];
my $is_word = {};
my $maxlen = 0;
Utils::ReadPList($ngramlist,$grams_with_pattern,$is_word,\$maxlen,$nospace);

# Ready to go!
my $memory = {};

# Record current time.
Message("Ready to go! Timer resetting.");
$start = time();
$cpu_start = clock();
my $global_iteration_count;

while (<>) {
  chomp;
  my $ctext = $_;
  Message("Solving [$ctext].");
  my $solution;
  
  # Find the ciphertext's repetition pattern.
  my $p = Utils::Pattern($ctext);  
  if ($memory->{$p}) {
    # Seen this pattern before, we already have a solution.
    Message("Solved from memory.");
    $solution = $memory->{$p};
  } else {
    # A new pattern, let's solve it! 
       
    # Get an initial key.
    @C = FreqAnalysis::GetSortedAlphabet(\$p);
    Message("Alphabets: P[@P] C[@C]\n");
    my $root = FreqAnalysis::GetFreqKey(\@P, \@C);
    
    # Tell the user what the initaial key is.
    #Utils::PrintKey($root,\@C);
    
    # Now run Beam Search!
    my $key = BeamSearch($p, $root, $maxit, $beamsize, $ngramorder); # Get key
    
    $solution = Utils::Decipher($p,$key, @C); # Get solution
    $memory->{$p} = $solution; # Store solution
  }
  
  Message("Done!");
  
  # Cipher solved (we hope).
  print $verbose ? "SOLUTION:\t$solution\n\n" : "$solution\n";  
}


sub BeamSearch {
  my ($ctext, $root, $maxit, $beamsize, $n) = @_;
  my $best = $root;
  my @beam = ($root);
  my %score = ();
  $score{$root} = -inf; 
  
  Message("Starting search..."); 
  
  # Search for $maxit iterations...
  Message("Ready to search!");
  for (my $i = 1; $i <= $maxit; $i++) {
    $global_iteration_count = $i;
    last if @beam == 0;
    Message("Iteration $i starting.");
    my @newbeam = GetNewBeam($ctext, $beamsize, \%score, $n, \$best, @beam);
    @beam = @newbeam;
    Message("Iteration $i complete.");
  }  
  
  return $best;
}


sub GetNewBeam {
  my ($ctext, $beamsize, $score, $n, $best, @oldbeam) = @_;
  my @newbeam = ();
  my %seen = ();
  my $bestdec = Utils::Decipher($ctext,$$best, @C);
  
  # Gather new keys and their respective decipherments.
  # The structure of %newkeyhash is a bit confusing:
  #   keys are decipherments of the ctext
  #   values are the decipherment keys that generate them
  my %newkeyhash = ();
  foreach my $key (@oldbeam) {
    # Expand each key in the beam.
    if (!$nospace) {
      GetSuccessors($ctext,$key,\%newkeyhash,$n,$score,\%seen);
    } else {
      GetSuccessorsNoSpace($ctext,$key,\%newkeyhash,$n,$score,\%seen);
    }
  }
  
  # Now that we've collected the new keys, let's score them.
  my %newdeciphermentscores = ();
  foreach my $dtext (sort keys %newkeyhash) {
    $newdeciphermentscores{$dtext} = JMSmoothing::ProbCharWord(
      $dtext, $charlm1, $charlm2, $charlm3, $wordlm1, $wordlm2, $wordlm3,
      $cl1, $cl2, $cl3, $wl1, $wl2, $wl3, $x
    )
  }
  
  # Now processes the data.
  foreach my $d (sort keys %newkeyhash) {
    my $newdeciph = $d;
    my $new_key = $newkeyhash{$newdeciph};
    my $new_score = $newdeciphermentscores{$newdeciph};
    die "Error 4! No deciph" unless $newdeciph;
    die "Error 4! [$newdeciph], No new key" unless $new_key;
    die "Error 4! [$newdeciph], No score" unless $new_score;
    $score->{$new_key} = $new_score;
    die "Error 5! (this shouldn't be possible) [$$best]" unless $score->{$$best};
    
    if ($score->{$new_key} > $score->{$$best}) {
    #if ( Utils::BetterThan($newdeciph,$bestdec,$new_key,$$best,$is_word,$score) ) {
      $$best = $new_key;
      $bestdec = $newdeciph;
      Message("Best guess: ($bestdec) ($score->{$new_key})");
    }
    
    Insert($new_key, $score, \@newbeam);
    while (@newbeam > $beamsize) {
      pop @newbeam;
    }       
  }
  
  return @newbeam;
}


sub GetSuccessors {
  my ($ctext, $key, $newkeyhash, $n, $score, $seen) = @_;

  # decipher
  my $dtext = Utils::Decipher($ctext,$key, @C); 
  my @cwords = split /\s+/, $ctext;
  my @dwords = split /\s+/, $dtext;
  
  # Go through all ngram orders.
  for (my $k = 1; $k <= $n && $k <= @cwords; $k++) {
    my $m = $k-1;
    
    # Check all k-grams
    foreach (my $i = $m; $i < @cwords; $i++) {
      my $cw = join(' ', @cwords[$i-$m .. $i]);
      my $dw = join(' ', @dwords[$i-$m .. $i]);
      
      my $pattern_cw = Utils::Pattern($cw);
      next unless $grams_with_pattern->[$k]->{$pattern_cw};
      
      my @sorted;
      if ($global_iteration_count <= ($maxit/2)) {
        #Message("Candidates chosen by score alone.");
        @sorted = @{$grams_with_pattern->[$k]->{$pattern_cw}};
      }
      else {
        #Message("Candidates chosen by score and similarity.");
        my %simhash = ();
        foreach (@{$grams_with_pattern->[$k]->{$pattern_cw}}) {
          $simhash{$_} = Utils::Sim($_,$dw)
        }
        @sorted = sort {$simhash{$b} <=> $simhash{$a}}
                    @{$grams_with_pattern->[$k]->{$pattern_cw}};
      }
      
      my @candidates;
      if (@sorted > $patternlimit) {
        @candidates = @sorted[0..($patternlimit-1)];
      } else {
        @candidates = @sorted;
      }
                       
   
      foreach my $match (@candidates) {
        next if $match eq $dw;
        
        # Propose a new key. 
        my $new_key = Assume($cw, $match, $key);
        next if $score->{$new_key};
        next if $seen->{"$new_key"};
        $seen->{"$new_key"} = 1;          
           
        my $newdeciph = Utils::Decipher($ctext,$new_key, @C);
        $newkeyhash->{$newdeciph} = $new_key
        
      }
    }
  }
}


sub GetSuccessorsNoSpace {
  my ($ctext, $key, $newkeyhash,$n,$score,$seen) = @_;

  # decipher
  my $dtext = Utils::Decipher($ctext,$key, @C); 
  my @cwords = split /\s+/, $ctext;
  my @dwords = split /\s+/, $dtext;
  
  # All ngrams are of order 1.
  my $k = 1;
  my $m = 0;
  
  # Check all substrings
  for (my $sta = 0; $sta < length($ctext)-1; $sta++) {
    for (my $len = 2; ($len <= $maxlen) && ($len <= length($ctext)+$sta); $len++) {
      my $cw = substr($ctext,$sta,$len);
      my $dw = substr($dtext,$sta,$len);
      
      my $pattern_cw = Utils::Pattern($cw);
      next unless $grams_with_pattern->[$k]->{$pattern_cw};
      
      my %simhash = ();
      foreach (@{$grams_with_pattern->[$k]->{$pattern_cw}}) {
        $simhash{$_} = Utils::Sim($_,$dw)
      }
      
      my @sorted = sort {$simhash{$b} <=> $simhash{$a}}
                       @{$grams_with_pattern->[$k]->{$pattern_cw}};

      my @candidates;
      if (@sorted > $patternlimit) {
        @candidates = @sorted[0..($patternlimit-1)];
      } else {
        @candidates = @sorted;
      }
                       
   
      foreach my $match (@candidates) {
        next if $match eq $dw;
        
        # Propose a new key. 
        my $new_key = Assume($cw, $match, $key);
        next if $score->{$new_key};
        next if $seen->{"$new_key"};
        $seen->{"$new_key"} = 1;          
           
        my $newdeciph = NoSpace::FindWords(Utils::Decipher($ctext,$new_key, @C), $is_word, $maxlen);
        $newkeyhash->{$newdeciph} = $new_key
        
      }
    }
  }
}


sub Insert {
  # Given $item and a score hash $score,
  # insert $item into the given pre-sorted $list
  # such that $list remains sorted.
  
  my ($item, $score, $list) = @_;
  
  for (my $i = 0; $i < @$list; $i++) {
    if ($score->{$item} > $score->{$list->[$i]}) {
      splice(@$list,$i,0,$item);
      return;
    }
  }
  
  push(@$list, $item);
  return;
}


sub Assume {
  my ($cw, $suggest, $key) = @_;
  #print "\tA: [$cw] [$suggest] [$key]\n";
  my %encrypt = ();
  my %decrypt = ();
  for (0..(scalar(@C)-1)) {
    my $c = $C[$_];
    my $p = substr($key, $_, 1);
    $encrypt{$p} = $c;
    $decrypt{$c} = $p;
  }
 
  for (my $i = 0; $i < length($cw); $i++) {
    my $c1 = substr($cw,$i,1);
    my $p1 = substr($suggest,$i,1);
    next if $c1 =~ /\s/;
    next if $p1 =~ /\s/;    
    next if $decrypt{$c1} eq $p1;
    
    # Want c1 to decipher as p1... what does c1 decipher as now?    
    my $p2 = $decrypt{$c1};
    die "Assumption error: $c1 not encrypted!\n" unless $p2;
    
    # And what, if anything, does p1 get enciphered as now?
    if ($encrypt{$p1}) {
      my $c2 = $encrypt{$p1};
      
      $decrypt{$c1} = $p1;
      $encrypt{$p1} = $c1;
      
      $decrypt{$c2} = $p2;
      $encrypt{$p2} = $c2;
    } else {
      # No; p1 was not encrypted before, p2 won't be now.
      $decrypt{$c1} = $p1;
      $encrypt{$p1} = $c1;
      
      delete($encrypt{$p2});
    }
  }
  
  # New guess at the encryption key.
  my $newkey = '';
  foreach my $l (@C) {
    $newkey .= $decrypt{$l};
  }
  
  return $newkey;
}


sub Message {
  printf("%d / %.3f : %s\n", time() - $start, clock()-$cpu_start, "@_") if $verbose;
}
