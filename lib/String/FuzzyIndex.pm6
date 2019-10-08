
unit module String::FuzzyIndex;

sub fzindex (   Str $haystack,
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

    sub perfect_match (--> Int:D) {
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

        sub init_HQ (--> List:D) {
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

        sub traceback (Int $i, Int $j --> List:D) {
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
    return @R.List;
}