# hhk-decipherment
Code for "Solving Substitution Ciphers with Combined Language Models" by Bradley Hauer, Ryan Hayward, and Grzegorz Kondrak.

Monoalphabetic Substitution Cipher Solver
As described in "Solving Substitution Ciphers with Combined Language Models",
by Bradley Hauer, Ryan Hayward, and Greg Kondrak,
The 25th International Conference on Computational Linguistics (COLING 2014)

Included is a solver for monoalphabetic substitution ciphers (MASCs). If
you've worked with decipherment or cryptography at all (or even if you 
haven't!), you've probably seen a MASC before. These ciphers work by
replacing each letter in the message -- the PLAINTEXT -- with a unique
symbol, such that two letters are replaced by the same symbol if, and
only if, they are identical. So if we replace 'a' with 'X', ALL 'a's become
'X's, and ONLY 'a's become 'X's. The replacement system chosen is called the
KEY. Here is an example key:

abcdefghijklmnopqrstuvwxyz
qwertyuiopasdfghjklzxcvbnm

This key says that all 'a's become 'q's, all 'b's become 'w's, and so on. So
'this is a top secret message'
becomes
'ziol ol q zgh ltektz dtllqut'

How would we break this cipher if we didn't know the key? For an English 
cipher, the number of keys is 26!, or 403,291,461,126,605,635,584,000,000
-- far too many to just try them all. The code you have downloaded can solve
these ciphers in minutes. We include two programs, 'masc_solver_beamsearch.pl'
and 'masc_solver_mcts.pl'. The former is a little bit slower, but will make 
fewer mistakes on average. Both are implemented as Perl scripts, so run them
with your favorite Perl interpreter.

On GNU/Linux, try the following
echo 'ziol ol q zgh ltektz dtllqut' | perl masc_solver_beamsearch.pl
echo 'ziol ol q zgh ltektz dtllqut' | perl masc_solver_mcts.pl

In both cases, you should get 'this is a top secret message' as your output.
In general, both programs read from standard input, and write to standard
output. This code has not been tested on operating systems other than
GNU/Linux.

The files beginning with "lmtrain_nyt_word" are derived from the New York
Times corpus.
