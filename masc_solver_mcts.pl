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
my $maxit = 100;
my $patternlimit = 50;
my $ucbParamC = 1;

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
  "pc=i" => \$ucbParamC,
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
  "\nUCB Parameter C: $ucbParamC",
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
    
    # Now run Monte Carlo Tree Search!
    my $key = MCTS($p, $root, $maxit, $ngramorder); # Get key
    
    $solution = Utils::Decipher($p,$key, @C); # Get solution
    $memory->{$p} = $solution; # Store solution
  }
  
  Message("Done!");
  
  # Cipher solved (we hope).
  print $verbose ? "SOLUTION:\t$solution\n\n" : "$solution\n";  
}


sub MCTS {
  my ($ctext, $root, $maxit, $ngramorder) = @_;
  
  # Initial key info.
  my $best = $root; # Best key found so far.
  my $bestdec = Utils::Decipher($ctext,$best,@C);
  
  print "Starting off with $root.\n" if $verbose;
  
  # Initial tree state.
  my $children    = {};
  my $cscores     = {};
  my $key_value   = {};
  my $key_visits  = {};
  my $key_ucb     = {};

  # Start by finding the value of the root node.
  $key_value->{$root} = -inf;
  $key_visits->{$root} = 0;
  $key_ucb->{$root} = 'IS_ROOT';

  # Begin the search!
  for (my $i = 1; $i <= $maxit; $i++) {
    $global_iteration_count = $i;
    Message("Iteration $i starting.");
  
    ### SELECTION: Find a leaf to explore.
    my @path = Selection($root, $children, $key_ucb, $key_visits);
    my $leaf = $path[-1];
    Message("Selection -- $path[-1] ", scalar @path);
    
    ### EXPANSION: Explore the leaf, extend the path.  
    my $newkey = Expansion($ctext,$leaf,$children,$key_value,$key_visits,$key_ucb,$cscores);
    my $newdec = Utils::Decipher($ctext,$newkey,@C);
    if ($key_value->{$newkey} > $key_value->{$best}) {
    #if ($score->{$new_key} > $score->{$$best}) {
    #if ( Utils::BetterThan($newdec,$bestdec,$newkey,$best,$is_word,$key_value) ) {
      $best = $newkey;
      $bestdec = $newdec;
      Message("Best guess: ($bestdec)");
    }
    push (@path, $newkey);
    Message("Expansion -- $newkey");
      
    ### BACKPROPAGATION: Update the tree along the path.
    Backpropagation(\@path, $key_value, $key_visits, $key_ucb, $cscores);
    
    Message("Iteration $i complete.");
  }
  
  return $best;
}


sub Selection {
  # STEP 1: recursively select optimal child nodes until a leaf node L is reached.
  my ($node, $children, $key_ucb, $key_visits) = @_;  
  
  $key_visits->{$node}++;
  
  if (!($children->{$node})) {
    # Node is a leaf. 
    # Return the leaf as a singleton list.
    return ($node);    
  } else {
    # Node is not a leaf.    
    # Choose the best child.
    my $bestchild = $children->{$node}->[0];
    return $node unless $bestchild;
    my $bestchild_ucb = $key_ucb->{$bestchild};    
    foreach my $c (@{$children->{$node}}) {
      my $c_ucb = $key_ucb->{$c};
      if ($c_ucb > $bestchild_ucb) {
        $bestchild = $c;
        $bestchild_ucb = $c_ucb;
      }
    }
    
    return ($node, Selection($bestchild, $children, $key_ucb, $key_visits));    
  }
}


sub Expansion {
  # STEP 2: create one or more child nodes and select one.
  my ($ctext, $leaf, $children, $key_value, $key_visits, $key_ucb, $cscores) = @_;
  my %seen = ();  
  
  # decipher
  my $dtext = Utils::Decipher($ctext,$leaf,@C); 
  my @cwords = split /\s+/, $ctext;
  my @dwords = split /\s+/, $dtext;
  
  # Set up some variables.
  $children->{$leaf} = [];
  $cscores->{$leaf} = [];
  my $C = $leaf;
  my $Cvalue = $key_value->{$leaf};
  my $Cdeciph = Utils::Decipher($ctext, $C, \@C);
  
  # find new children
  #my @potentials = ();
  my %newkeyhash = ();
  #my @c;
  if (!$nospace) {
    GetSuccessors($ctext, $leaf, \%newkeyhash, $ngramorder, $key_value, \%seen);
  }  else {
    GetSuccessorsNoSpace($ctext, $leaf, \%newkeyhash, $ngramorder, $key_value, \%seen);
  }
  #@potentials = @c;
  Message("Expansion -- Found", scalar keys %newkeyhash, "total children.");
  
  # Now that we've collected the new keys, let's score them.
  my %newdeciphermentscores = ();
  foreach my $dtext (sort keys %newkeyhash) {
    $newdeciphermentscores{$dtext} = JMSmoothing::ProbCharWord(
      $dtext, $charlm1, $charlm2, $charlm3, $wordlm1, $wordlm2, $wordlm3,
      $cl1, $cl2, $cl3, $wl1, $wl2, $wl3, $x
    )
  }
  
  foreach my $d (keys %newkeyhash) {
    my $newdeciph = $d;
    die "Error 4! No deciph" unless $newdeciph;
    
    my $new_key = $newkeyhash{$newdeciph};
    die "Error 4! [$newdeciph], No new key" unless $new_key;
    # Make sure we do not repeat a node.
    next if $key_visits->{$new_key};
    
    my $new_score = $newdeciphermentscores{$newdeciph};
    die "Error 4! [$newdeciph], No score" unless $new_score;
    
    # Record the score.
    $key_value->{$new_key} = $new_score;  
    
    # Visit the new node.
    $key_visits->{$new_key} = 1;
      
    # Add the new key to its parent's child list.
    push @{$children->{$leaf}}, $new_key;
    push @{$cscores->{$leaf}}, $new_score;
        
    # Get and save ucb.
    my $srnum = log($key_visits->{$leaf});
    my $srden = $key_visits->{$new_key};
    $key_ucb->{$new_key} = ($key_value->{$new_key} + ($ucbParamC * sqrt($srnum / $srden)));
    
    # Is this the best child?
    if ($new_score > $Cvalue) {
      $C = $new_key;
      $Cvalue = $new_score;
      $Cdeciph = $newdeciph;
    }
  }
  
  return $C;  
}


sub Backpropagation {
  # STEP 4: Update the current move sequence with the simulation result.
  my ($path, $key_value, $key_visits, $key_ucb, $cscores) = @_;
  
  # Find the highest value along our path.
  my $max_value = $key_value->{$path->[1]};  
  for (my $i = 1; $i < @$path; $i++) {
    my $n = $path->[$i];
    
    if ($key_value->{$n} > $max_value) {
      $max_value = $key_value->{$n};
    }
  }
  
  # Update the values and UCBs along the path.
  for (my $i = 1; $i < @$path; $i++) {
    my $n = $path->[$i];
    $key_value->{$n} = $max_value; 
    
    # Set UCB.
    
    my $ucbterm = 0;
    my $srnum = log($key_visits->{$path->[$i-1]});
    my $srden = $key_visits->{$n};
    $ucbterm = ($ucbParamC * sqrt($srnum / $srden));   
    
    $key_ucb->{$n} = ($key_value->{$n} + $ucbterm);
  }
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
