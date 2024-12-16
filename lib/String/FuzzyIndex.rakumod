my sub fzindex (   Str $haystack,
                Str $needle,

                Int :$s_id  = +6,
                Int :$s_ocr = +3,
                Int :$s_gap = -1,
                Int :$s_nid = -1,

                Bool :$ignore_diacritics   = False,
                Bool :$glossover_ocrerrors = False,

                --> List:D

        ) is export {
    #-------------------------------------------------------------------------------
    # Sanity check.
    #-------------------------------------------------------------------------------
    unless ($s_id, $s_ocr, $s_gap, $s_nid).max == $s_id {
        die "Error: fzindex-logic relies on s_id to represent the highest awardable similarity score.";
    }

    #-------------------------------------------------------------------------------
    # Declaration of results array @R and perfect match routine ahead of fuzzy match
    # prerequisites that we may never need.
    #-------------------------------------------------------------------------------
    my @R;

    my sub perfect_match (--> Int:D) {
        #-------------------------------------------------------------------------------
        # Use the 'indices' built-in, which is much faster than our fuzzy sw-alignment,
        # to quickly test for perfect occurrences of the needle in the haystack. If any are
        # identified, build the results array @R in the same way as for a fuzzy match.
        #-------------------------------------------------------------------------------
        @R=();
        unless $haystack.chars == 0 || $needle.chars == 0 {

            my $spos;
            my $nlen  = $needle.chars;
            my $frac  = 1/1;
            my $s1sp;
            my $s1ep;
            my $s2sp  = 0;
            my $s2ep  = $nlen-1;
            my @tb_s1 = $needle.comb;
            my @tb_s2 = @tb_s1;
            my @tb_sc;

            my @start_pos = indices($haystack, $needle, :overlap);
            for 0..(@start_pos.end) -> $i {
                $spos  = @start_pos[$i];
                $s1sp  = $spos;
                $s1ep  = $spos + $nlen-1;
                @tb_sc = $s_id, { $_ + $s_id } ... ($nlen * $s_id);
                @R[$i] = ($frac<>, $s1sp<>, $s1ep<>, $s2sp<>, $s2ep<>, @tb_s1.List, @tb_s2.List, @tb_sc.List);
            }
        }
        return @R.elems;
    }


    unless perfect_match() {
        #-------------------------------------------------------------------------------
        # Declare basic data structures and auxiliary subroutines for fuzzy matching now
        # we know we need them.
        #-------------------------------------------------------------------------------
        my Str @s1 = $haystack.comb;
        my Str @s2 = $needle.comb;

        my Int @H[@s1.elems+1;@s2.elems+1];
        my Int @Q[@s1.elems+1;@s2.elems+1];

        my Str (@tb_s1, @tb_s2);
        my Int @tb_sc;

        sub s (Str $a, Str $b --> Int:D)  {
            #-------------------------------------------------------------------------------
            # Score the similarity of the elements $a and $b.
            #-------------------------------------------------------------------------------
            if $ignore_diacritics {
                return $s_id if $a.samemark(" ") eq $b.samemark(" ");
            } else {
                return $s_id if $a eq $b;
            }

            if $glossover_ocrerrors {
                return $s_ocr if ($a,$b)  (<=)  ( 'a' , 'e' , 'o' , 's' )                ||
                        ($a,$b)  (<=)  ( 'b' , 'h' )                                     ||
                        ($a,$b)  (<=)  ( 'c' , 'e' , 'o' )                               ||
                        ($a,$b)  (<=)  ( 'c' , 't' )                                     ||
                        ($a,$b)  (<=)  ( 'D' , 'O' , 'o' , '0' )                         ||
                        ($a,$b)  (<=)  ( 'f' , 'I' , 'i' , 'l' , 't' , '1' , '|', '!' )  ||
                        ($a,$b)  (<=)  ( 'f' , 's' )                                     ||
                        ($a,$b)  (<=)  ( 'g' , 'q' )                                     ||
                        ($a,$b)  (<=)  ( 'G' , 'ô', '6' )                                ||
                        ($a,$b)  (<=)  ( 'h' , 'n' )                                     ||
                        ($a,$b)  (<=)  ( 'i' , 'j' )                                     ||
                        ($a,$b)  (<=)  ( 'm' , 'n' )                                     ||
                        ($a,$b)  (<=)  ( 'M' , 'N' )                                     ||
                        ($a,$b)  (<=)  ( 'S' , 's' , '5' , '8' )                         ||
                        ($a,$b)  (<=)  ( 'u' , 'v' , 'y' )                               ||
                        ($a,$b)  (<=)  ( 'U' , 'V' )                                     ||
                        ($a,$b)  (<=)  ( '0' , '8' )                                     ||
                        ($a,$b)  (<=)  ( ',' , '.' , ' ' )                               ||
                        ($a,$b)  (<=)  ( ';' , ':' );
            }
            return $s_nid;
        }

        my sub init_HQ (--> List:D) {
            #-------------------------------------------------------------------------------
            # Initialize the scoring matrix H and the direction matrix Q while keeping track
            # of the indices of element(s) holding H's maximum score in the array H_max.
            #-------------------------------------------------------------------------------
            my Int $rows        = @H.shape[0];
            my Int $cols        = @H.shape[1];
            my Int @im_scores[3];
            my Int ($max_direction, $max_im_score);
            my @H_max           = 0, (0,0);

            for 0..^$cols -> $j { @H[0;$j] = 0 };
            for 1..^$rows -> $i { @H[$i;0] = 0 };

            for 1..^$rows -> $i {
                for 1..^$cols -> $j {

                    @im_scores[0] = @H[$i;$j-1]   + $s_gap;
                    @im_scores[1] = @H[$i-1;$j-1] + s @s1[$i-1], @s2[$j-1];
                    @im_scores[2] = @H[$i-1;$j]   + $s_gap;

                    $max_im_score = 0;
                    for 0,1,2 -> $x {
                        if @im_scores[$x] > $max_im_score {
                            $max_im_score = @im_scores[$x];
                            $max_direction = $x;
                        }
                    }
                    @H[$i;$j] = $max_im_score;
                    @Q[$i;$j] = $max_direction;

                    if $max_im_score >= @H_max[0] {
                        if $max_im_score > @H_max[0] {
                            @H_max = $max_im_score, ($i, $j);
                        } else {
                            @H_max.push: ($i,$j);
                        }
                    }
                }
            }
            return @H_max;
        }

        my sub traceback (Int $i, Int $j --> List:D) {
            #-------------------------------------------------------------------------------
            # Run traceback through scoring matrix H, starting from $i,$j back to first 0,
            # directed by direction matrix: Q[$i;$j] reveals the direction in H from which
            # the point H[$i;$j] was reached during scoring.
            #-------------------------------------------------------------------------------
            @tb_sc.push: @H[$i;$j];

            my ($k, $l);
            given @Q[$i;$j] {
                # 0: go back left; gap in haystack sequence
                when 0 {
                    @tb_s1.push: '-';
                    @tb_s2.push: @s2[$j-1];
                    $k=$i;
                    $l=$j-1
                }
                # 1: go back diagonally (left-up); match or substitution
                when 1 {
                    @tb_s1.push: @s1[$i-1];
                    @tb_s2.push: @s2[$j-1];
                    $k=$i-1;
                    $l=$j-1
                }
                # 2: go back up; gap in needle sequence
                when 2 {
                    @tb_s1.push: @s1[$i-1];
                    @tb_s2.push: '-';
                    $k=$i-1;
                    $l=$j;
                }
            }

            if @H[$k;$l] == 0 {
                return [$i,$j];
            } else {
                traceback $k, $l;
            }
        }

        #-------------------------------------------------------------------------------
        # Initialize scoring and direction matrices H, Q; perform tracebacks from each
        # pair of indices associated with a non-zero maximum score in H as recorded in
        # @H_max, and construct the results array @R.
        #-------------------------------------------------------------------------------
        my @H_max = init_HQ();

        # Construct results array @R, unless there are no matches to be reported.
        unless @H_max[0] == 0 {

            my $tmsc = @s2.elems * $s_id;
            my $mxsc = @H_max[0];
            my $frac = ($mxsc/$tmsc);

            loop ( my $i=1; $i < @H_max.elems; $i++ ) {

                @tb_s1 = ();
                @tb_s2 = ();
                @tb_sc = ();
                my @h = |@H_max[$i];
                my @tb_orig = traceback @h[0], @h[1];

                my $s1sp = @tb_orig[0]-1;
                my $s1ep = @h[0]-1;
                my $s2sp = @tb_orig[1]-1;
                my $s2ep = @h[1]-1;

                @R[$i-1] = ($frac<>, $s1sp<>, $s1ep<>, $s2sp<>, $s2ep<>,
                        @tb_s1.reverse.List, @tb_s2.reverse.List, @tb_sc.reverse.List);
            }
        }
    }
    @R.List
}

=begin pod

=head1 NAME

String::FuzzyIndex - Fuzzy index routine based on Smith-Waterman algorithm

=head1 SYNOPSIS

=begin code :lang<raku>

use String::FuzzyIndex;

my @fzmatch = fzindex($haystack, $needle);

my @fzmatch = fzindex($haystack, $needle, :s_id(6), :s_ocr(3), :s_gap(-1), :s_nid(-1));
my @fzmatch = fzindex($haystack, $needle, :ignore_diacritics);
my @fzmatch = fzindex($haystack, $needle, :glossover_ocrerrors);

=end code

=head1 DESCRIPTION

`String::FuzzyIndex` is a pure Raku module for fuzzy string matchingi
based on the L<Smith-Waterman algorithm|https://en.wikipedia.org/wiki/Smith%E2%80%93Waterman_algorithm>.  It provides a single subroutine named C<fzindex>.

=head1 SUBROUTINES

=head2 fzindex

The subroutine <fzindex> locates the best match(es) of a needle
string in a haystack string and returns the best-match data in the
form of a C<List>. In case no best match was found, the C<List> is
empty. Otherwise the returned C<List> contains, for each best match,
an eight-element sub-C<List> describing that match.

The structure of a sub-`List` is as follows:

=begin table

| Index |  Type     | Description                                                 |
|:------|:----------|:------------------------------------------------------------|
| 0     | Rat       | Match score as fraction of maximum score for perfect match  |
| 1     | Int       | Index of start position of match in haystack                |
| 2     | Int       | Index of end position of match in haystack                  |
| 3     | Int       | Index of start position of match in needle                  |
| 4     | Int       | Index of end position of match in needle                    |
| 5     | List[Str] | Traceback buffer for match in haystack                      |
| 6     | List[Str] | Traceback buffer for match in needle                        |
| 7     | List[Int] | Traceback buffer comprising the match's similarity scores   |

=end table

=head3 Similarity scoring scheme

The operation of C<fzindex> is based on the
L<Smith-Waterman algorithm|https://en.wikipedia.org/wiki/Smith%E2%80%93Waterman_algorithm>.
This algorithm is used to identify the best match(es) by performing
so-called 'local sequence alignment', i.e. by comparing segments of the
haystack and the needle of all possible lengths, and optimizing a
similarity measure.

In the process, individual characters from the haystack and the
needle are pairwise compared and scored based on how similar they
are. If two characters are identical, their alignment is assigned
the similarity score C<s_id>. If they are not identical, their
alignment is assigned the similarity score C<s_nid>, unless the
options C<ignore_diacritics> and/or C<:glossover_ocrerrors> are used
(see below).

The alignment of haystack and needle segments may also call for
the acknowledgement of gaps: positions in an aligned segment that
correspond to neither identical nor non-identical elements. To this
end, C<fzindex> implements a linear gap penalty scheme according to
which each such gap is assigned a gap penalty C<s_gap>. In the
traceback buffers reported for a match, gaps are denoted with a dash
('-').

When working with strings extracted from OCRed data, mismatches in
the alignment of segments may arise from the improper recognition of
diacritics and/or the mixup of two characters. A 'ç' may, for instance,
have been recognized as a 'c' and so frustrate alignment. Similarly,
an 'I' is commonly OCRed as an 'l', or an '|'. C<fzindex> offers two
options to help mitigate such OCR-related issues:

=item :ignore_diacritics

Causes diacritics to be ignored in assessing whether two characters
are identical. Hence, the pairwise comparison of 'ç' and 'c' results
in assignment of the similarity score `s_id` rather than the score
C<s_nid>.

=item :glossover_ocrerrors

Causes the alignment of two characters that are commonly confused in
OCR to be assigned the score C<s_ocr> rather than the score C<s_nid>.

The default scores, which may be changed using correspondingly named
arguments, are as follows:

=begin table

| Score |  Default value | Description                                                   |
|:------|:--------------:|:--------------------------------------------------------------|
| s_id  | +6             | Score awarded to identical/matching characters                |
| s_ocr | +3             | Score awarded to possibly identical characters in OCR context |
| s_gap | -1             | Penalty for a gap (a dash in the traceback buffer)            |
| s_nid | -1             | Score awarded to non-identical characters                     |

=end table

=head3 Intended use
The Raku built-in L<C<index>|https://docs.raku.org/type/Str#method_index>
localizes the first perfect match of a needle within a haystack.
It is fast, but when it comes up empty, one may be left wondering if
either the haystack or the needle perhaps contains a typo, spelling
variation, OCR error or the like that caused C<index> to report the
absence of the needle from the haystack. In such a case, C<fzindex>
may be used as a backup for C<index>.

However, since C<index> is comparably fast, C<fzindex> internally
executes an C<index>-based (actually:
L<C<indices>|https://docs.raku.org/type/Str#method_indices>-based)
match attempt before starting a local sequence alignment attempt.

Because of this, there is generally no need to implement the use of
C<fzindex> as an actual backup to the use of the C<index> built-in.
Instead, the C<fzindex> routine may be used instead of the built-in
C<index>. Such use of C<fzindex> obviously comes at a performance
penalty, but has the advantages that (i) all perfect matches are
reported at once, and (ii) any best fuzzy matches are reported in
case no perfect matches exist.

=head3 Optimization

The Raku implementation of the Smith-Waterman algorithm is naturally
relatively slow, and in the present version of C<String::FuzzyIndex>
no significant optimization attempt has been made. Should you need
fuzzy string matching for a large number of lengthy strings, you are
probably better off with an implementation in a low level language
like C.

That said, some performance enhancing code has already been tested
and is likely to appear in future versions.

=head3 Example

=begin code :lang<raku>

use String::FuzzyIndex;

my $haystack  = 'The squeeky weel gets the grease.';
my $needle    = 'squeaky wheel';

my @r = fzindex($haystack, $needle);

say "{@r.elems} match(es) found.";
for @r -> ($score, $hsp, $hep, $nsp, $nep, $htb, $ntb, $stb) {
    say "Match score               : ", $score;
    say "Matching haystack portion : ", $haystack.substr: $hsp, ($hep-$hsp+1);
    say "Matching needle portion   : ", $needle.substr:   $nsp, ($nep-$nsp+1);
    say "Scoring traceback buffer  : ", $stb;
    say "Haystack traceback buffer : ", $htb;
    say "Needle traceback buffer   : ", $ntb;
}

=end code

=begin output

1 match(es) found.
Match score               : 0.820513
Matching haystack portion : squeeky weel
Matching needle portion   : squeaky wheel
Scoring traceback buffer  : (6 12 18 24 23 29 35 41 47 46 52 58 64)
Haystack traceback buffer : (s q u e e k y   w - e e l)
Needle traceback buffer   : (s q u e a k y   w h e e l)

=end output

=head1 AUTHOR

threadless-screw

=head1 COPYRIGHT AND LICENSE

Copyright 2019 threadless-screw

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
