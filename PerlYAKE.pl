#!/usr/bin/perl

use strict;
use warnings;

use utf8;

binmode STDOUT, 'utf8';

# So, this is an attempt to implement:
#     YAKE - Yet Another Keyword Extractor

# as described in paper by 
# Ricardo Campos, Vítor Mangaravite, Arian Pasquali,
#    Alípio Jorge, Célia Nunes and Adam Jatowt
#
# I've tried to write this in base Perl 5.34..
# No additional packages are needed!
# (This was not such a good decision, I had to invent some wheels)
# 
# Also, this is my first Perl scipt ever so don't laugh too much, please.
#
# created by Andrej Dravecky
# (*) no rights reserved

## Some notes:
#  my argparse will fail on files beginning with "-", I did not implement "--" 
#       but pls, don't name your files -*.*, that's just mean
#

# CONFIG (in case you don't want to use command-line arguments)
my $doc_file   = undef;           # doc file to be processed
my $sw_file    = './czech.txt';   # contains one stopword per line
my $phrase_len = 3;               # max length of keyphrase
my $window     = 2;               # sliding window  L/R sizes
                                  #     (1 = size 3; 2 = size 5 etc...)
my $top_n      = 20;              # return top n results 
my $sim_thresh = .5;              # similarity threshold

# help message with usage
our $help_message = <<"EOF";

PerlYAKE - Yet Another Keyword Extractor, now in Perl
usage: perlyake [-h|--help] [-w|--window WIN_SIZE] [-n|--number NUM]
                [-p|--phrase P_LEN] [-s|--stopwords FILE] DOCUMENT
args:
    -h, --help         print this help
    -w, --window       set window size to 2 * WIN_SIZE + 1
    -n, --number       number of results to return
    -p, --phrase       maximum keyphrase length
    -s, --stopwords    stopwords in the desired language, one per line
    -t, --threshold    similarity threshold for duplicate phrases (0.0 - 1.0)
    DOCUMENT           input document path
EOF

# error messages
our %error_messages = (
    1  => 'Unknown parameter: ',
    2  => 'Too many arguments!',
    3  => 'Stopword file could not be opened: ',
    4  => 'Document file could not be opened: ',
    
    30 => 'Missing document file!',
    31 => 'Missing stopwords file!',
    32 => 'Window not set!',
    33 => 'Phrase length not set!',
    34 => 'Number of results not set!',
    35 => 'Similarity threshold not set!',
 
    40 => 'Window not an integer!',
    41 => 'Phrase length not an integer!',
    42 => 'Number of results not an integer!',
    43 => 'Similarity threshold not a float!',
    
    50 => 'Window cannot be negative!',
    51 => 'Number of results cannot be negative!',
    52 => 'Phrase length has to be positive!',
    53 => 'Similarity threshold has to be in range 0.0 to 1.0!'
);

parse_arguments(\@ARGV, \$doc_file, \$sw_file, \$phrase_len,
                \$window, \$top_n, \$sim_thresh);

# open files and remove consecutive whitespaces
my $sw_text  = open_and_read($sw_file, 3);
my $doc_text = open_and_read($doc_file, 4);

# split text into sentences 
# (this might be enough for gramatically sound text)  
my @sentences = split /[\.\?\:\!]+\s+(?=\p{Lu})/, $$doc_text;
my @stopwords = split /\s+/, lc $$sw_text;

my ($tokens, $phrases) = gen_tokens_and_phrases(
        \@sentences, \@stopwords, $window, $phrase_len, $sim_thresh);

compute_term_scores($tokens);
compute_phrase_scores($tokens, $phrases);

my @sorted = sort { $phrases->{$a}->{'score'} <=> $phrases->{$b}->{'score'} } 
                keys(%$phrases);

my $no_dups = deduplicate(\@sorted, $sim_thresh, $top_n);

print $_,"\n" for @$no_dups;

exit 0;

# Simple argparse
sub parse_arguments {
    my ($args, $doc, $sw, $plen, $win, $topn, $simt) = @_;

    # parse arguments
    while (@$args) {
        my $arg = shift @$args;
        if    ($arg =~ /^-w$|^--window$/)    { $$win  = shift @$args; }
        elsif ($arg =~ /^-s$|^--stopwords$/) { $$sw   = shift @$args; }
        elsif ($arg =~ /^-p$|^--phrase$/)    { $$plen = shift @$args; }
        elsif ($arg =~ /^-n$|^--number$/)    { $$topn = shift @$args; }
        elsif ($arg =~ /^-t$|^--threshold$/) { $$simt = shift @$args; }
        elsif ($arg =~ /^-h$|^--help$/)      { die_nicely(0);       }
        elsif ($arg =~ /^-|^--/)             { die_nicely(1, $arg); } 
        elsif (defined $$doc)                { die_nicely(2);       }
        else                                 { $$doc = $arg; }
    }
    
    # define check sub refs
    my $check_def = sub { defined $_[0]; };
    my $check_int = sub { $_[0] =~ /^[+-]?\d+$/; };
    my $check_neg = sub { $_[0] >= 0; };
    my $check_positive = sub { $_[0] >= 1; };
    
    my $check_float = sub { $_[0] =~ /^[+-]?\d*(\.)?\d+/; };
    my $check_range = sub { $_[0] >= 0 && $_[0] <= 1; };

    # check args
    check(30, $check_def, $doc, $sw, $win, $plen, $topn, $simt);
    check(40, $check_int, $win, $plen, $topn);
    check(50, $check_neg, $win, $topn);
    check(52, $check_positive, $plen);
    
    check(43, $check_float, $simt);
    check(53, $check_range, $simt); 
    
    return;
}

# exit helper function
sub die_nicely {
    my ($out, $arg) = @_;
    if ($out) {
        print 'ERROR: ', $error_messages{$out};
        print $arg if defined $arg;
    }
    print "\n".$help_message;
	exit $out;
}

# check 
sub check {
    my ($count, $func) = (shift, shift);
    for (@_) {  # call *check* function on dereferenced scalar references
        die_nicely($count) unless $func->($$_);
        $count++;
    }
    return;
}

# open and read file, then remove consecutive whitespaces
sub open_and_read {
   my ($filen, $err_code) = @_;
   open my $FH, '<:utf8', "$filen" or die_nicely($err_code, $filen);
   read $FH, my $text, -s $FH; close $FH;
   $text =~ s/\s+/ /g;
   return \$text;
}



sub gen_tokens_and_phrases {
    my ($sents, $stops, $window, $phrasel) = @_;
    my $offset = 0;
    my %tokens; my %phrases;

    for my $sentence (@$sents) {
        my @chunks = split /[\p{P}]+/, $sentence; # split on all punctuation
        for my $chunk (@chunks) {
            my @words = split /\s+/, $chunk =~ s/\s*(.*)\s*/$1/r; # trim
            compute_chunk_stats(\%tokens, \@words, $offset++, $stops, $window);
            generate_phrases(\%phrases, \@words, \%tokens, $phrasel);
        }
    }
    return (\%tokens, \%phrases);
}

# compute term statistics for words in a chunk
sub compute_chunk_stats {
    my ($tokens, $words, $offset, $stopwords, $window) = @_;

    my @terms = map lc, @$words;
    my $chunk_len = scalar @terms - 1;

    for my $mid_idx (0 .. $chunk_len) {
        my $word = $words->[$mid_idx];
        my $term = $terms[$mid_idx];

        my $token_ref = exists $tokens->{$term} ? $tokens->{$term} :
            initialize_token($word, $term, $tokens, $stopwords, $window);

        #increment term frequency counters
        $token_ref->{'TF'}++;
        push @{ $token_ref->{'TS_o'} }, $offset;
        if    ($word =~ /^\p{L}\p{Lu}+$/)     { $token_ref->{'TF_a'}++; }
        elsif ($word =~ /^\p{Lu}{1}\p{Ll}+$/) { $token_ref->{'TF_u'}++; }

        # compute window indexing
        my $top_idx = get_min($mid_idx + $window, $chunk_len);
        my $bot_idx = get_max($mid_idx - $window, 0);
        
        # increment word occurence counters
        for my $idx ($bot_idx..$top_idx) {
            if ($idx < $mid_idx) {
                $token_ref->{'TL_o'}->[$mid_idx-$idx-1]{$terms[$idx]}++;
            } elsif ($idx > $mid_idx) {
                $token_ref->{'TR_o'}->[$idx-$mid_idx-1]{$terms[$idx]}++;
            }
        }
    }

    return;
}

# initialize new token in hash
sub initialize_token {
    my ($word, $token, $tokens, $stopwords, $window) = @_;
    my $tag;

    # Tag word
    if    (grep /^$token$/, @$stopwords) { $tag = 's'; }
    elsif ($word =~/^[\p{L}]+$/)         { $tag = 'p'; }
    else                                 { $tag = 'x'; } # yuck

    # Initialize token with tag
    $tokens->{$token} = {
        'TF'    => 0,        # term frequency
        'TF_a'  => 0,        # term frequency as acronym
        'TF_u'  => 0,        # term frequency as uppercase
        'TS_o'  => [],       # list of stentences offsets
        'TL_o'  => [],       # cooccurance to the left
        'TR_o'  => [],       # cooccurance to the righ
        'tag'   => $tag,     # term tag - s(topword), u(nparsable), p(arsable)
        'score' => 0,        # placeholder score val
    };

    # Initialize coocurence arrays
    foreach (0..$window-1) {
        push @{ $tokens->{$token}->{'TL_o'} }, {};
        push @{ $tokens->{$token}->{'TR_o'} }, {};
    }
    return \%{$tokens->{$token}};
}

# generate phrases of length max n
# n-grams cannot start or stop with a stopword
sub generate_phrases {
    my ($phrases, $words, $tokens, $pl) = @_;
    my $chunk_len = scalar @$words - 1;
    my @words = map lc, @$words;
    $words = \@words;
    for my $idx (0..$chunk_len) {
        next if $tokens->{lc $words->[$idx]}->{'tag'} ne 'p';
        
        my $top_idx = get_min($idx + $pl - 1, $chunk_len);

        for my $n ($idx..$top_idx) {
            next if $tokens->{lc $words->[$n]}->{'tag'} eq 's';
            my $cand = join ' ', @$words[$idx..$n];
            $phrases->{$cand}->{'freq'}++;
            $phrases->{$cand}->{'score'} = 0;
        }
    }
    return;
}

# compute term scores
sub compute_term_scores {
    my $tokens = shift;

    # get frequencies of valid terms
    my @validTFs; my $maxTF = 0;
    for my $key (keys %$tokens) {
        my $TF = $tokens->{$key}->{'TF'};
        push @validTFs, $TF unless $tokens->{$key}->{'tag'} eq 's';
        $maxTF = $TF if $TF > $maxTF; 
    }
    # term frequencies mean
    my $meanTF = do { 
        my $sumTF  = 0;
        $sumTF += $_ for @validTFs;
        $sumTF / scalar @validTFs;
    };
    # term frequencies standard deviation
    my $stdTF = do {
        my $sqsum = 0;
        $sqsum += ($_ - $meanTF)**2 for @validTFs;
        sqrt ($sqsum / scalar @validTFs);
    };

    foreach my $key (keys %$tokens) {
        my $tok = $tokens->{$key};
        
        my $tCase = get_max($tok->{'TF_a'}, $tok->{'TF_u'}) / 
                         1 + log $tok->{'TF'};

        my $tPos = term_position($tok);
        my $tRel = term_relation($tok, $tokens, $window, $maxTF); 

        my $tNorm = $tok->{'TF'} / ($meanTF + $stdTF);
        my $tSent = scalar unique(@{$tok->{'TS_o'}}) / scalar @sentences;

        $tokens->{$key}->{'score'} = 
            ($tRel ** 2 * $tPos) / ($tRel * $tCase + $tNorm + $tSent );
    }
}

sub term_position {
    my $tok = shift;
    my @arr = sort @{$tok->{'TS_o'}};
    my $mid_idx = int (scalar @arr / 2);
    return log log 3 + (
        scalar @arr % 2 ? $arr[$mid_idx] 
                        : ($arr[$mid_idx] + $arr[$mid_idx-1]) / 2
    );
}

sub term_relation {
    my ($tok, $tokens, $window, $maxTF) = @_;
    my $DL_DR = 0;
    for my $occ ('TL_o', 'TR_o') {
        my $total = 0; my %key_count;
        for my $w (0..$window-1) {
            while (my ($k, $v) = each %{$tok->{$occ}->[$w]}) {
                next if $tokens->{$k}->{'tag'} ne 'p';
                $total += $v;
                $key_count{$k}++;
            }
        }
        $DL_DR += $total ? scalar (keys %key_count) / $total : 0;
    }
    return 1 + $DL_DR * ($tok->{'TF'} / $maxTF);
}

# get unique elements from array
sub unique {
    my %seen;
    return grep !$seen{$_}++, @_;
}

sub compute_phrase_scores {
    my ($tokens, $phrases) = @_;
    for my $phrase (keys %$phrases) {
        my @terms = split /\s+/, lc $phrase;

        my $prodS = 1; my $sumS = 0;
        
        for my $idx (0..scalar @terms - 1) {
            if ($tokens->{$terms[$idx]}->{'tag'} ne 's') {
                $prodS *= $tokens->{$terms[$idx]}->{'score'};
                $sumS  += $tokens->{$terms[$idx]}->{'score'};
            
            } else { # stopwords can appear only between non stopwords
                my $bigram_prob = 
                      term_prob($terms[$idx], $terms[$idx-1], $tokens)
                    * term_prob($terms[$idx+1], $terms[$idx], $tokens);
                
                $prodS *= 1 + (1 - $bigram_prob);
                $sumS  -= 1 - $bigram_prob;
            }
        }
        my $p = $phrases->{$phrase};
        $phrases->{$phrase}->{'score'} = 
            $prodS / ($phrases->{$phrase}->{'freq'} * ($sumS + 1));
    }
}

# Compute term probability P(term1|term2)
sub term_prob {
    my ($term1, $term2, $tokens, $sum) = @_, 0;
    my $occ = $tokens->{$term2}->{'TR_o'}->[0];
    $sum += $_ for values %$occ;
    return $occ->{$term1} / $sum;
} 

sub deduplicate {
    my ($phrases, $threshold, $topn) = @_;
    my @nodups = ($phrases->[0]);
    
    PHR: for my $cand (@$phrases) {
        last if scalar @nodups == $topn;
        for my $phrase (@nodups) {
            my $dist = word_distance($cand, $phrase); 
            my $len  = get_max(length $cand, length $phrase);
            next PHR if ($dist / $len) < $threshold;  
        }
        push @nodups, $cand;
    }
    return \@nodups;
}
# compute word distance of two words
sub word_distance {
    my @chars1 = split //, shift; 
    my @chars2 = split //, shift;
    
    my $err_cache = [0..scalar @chars2];
    my $err_vec = [];

    for my $i (0..scalar @chars1 - 1) {
        push @$err_vec, $i + 1;
        for my $j (0..scalar @chars2 - 1) {
            my $delCost = $err_cache->[$j+1] + 1;
            my $insCost = $err_vec->[$j] + 1;
            my $subCost = $chars1[$i] eq $chars2[$j]
                        ? $err_cache->[$j] : $err_cache->[$j] + 1;
            push @$err_vec, get_min($delCost, $insCost, $subCost);
        }
        ($err_cache, $err_vec) = ($err_vec, []);
    }
    return $err_cache->[-1];
}



# get max argument
sub get_max {
    my $max = shift;
    $max = $max < $_ ? $_ : $max for @_;
    return $max;
}
# get min arg
sub get_min {
    my $min = shift;
    $min = $min > $_ ? $_ : $min for @_;
    return $min;
}

1; # should this be here?
