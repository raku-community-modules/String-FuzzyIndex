# Name
`String::FuzzyIndex` is a pure Perl 6 module for fuzzy string matching based on
the [Smith-Waterman algorithm](https://en.wikipedia.org/wiki/Smith%E2%80%93Waterman_algorithm).

# Synopsis
    use String::FuzzyIndex;

    my @fzmatch = fzindex($haystack, $needle);

    my @fzmatch = fzindex($haystack, $needle, :s_id(6), :s_ocr(3), :s_gap(-1), :s_nid(-1));
    my @fzmatch = fzindex($haystack, $needle, :ignore_diacritics);
    my @fzmatch = fzindex($haystack, $needle, :glossover_ocrerrors);

# Subroutines
`String::FuzzyIndex` provides a single subroutine named `fzindex`.

# Description
The subroutine `fzindex` locates the best match(es) of a needle string in a
haystack string and returns the best-match data in the form of a `List`. In case
no best match was found, the `List` is empty. Otherwise the returned `List`
contains, for each best match, an eight-element sub-`List` describing that
match. The structure of a sub-`List` is as follows:

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

## Similarity scoring scheme
The operation of `fzindex` is based on the [Smith-Waterman
algorithm](https://en.wikipedia.org/wiki/Smith%E2%80%93Waterman_algorithm). This
algorithm is used to identify the best match(es) by performing so-called 'local
sequence alignment', i.e. by comparing segments of the haystack and the needle
of all possible lengths, and optimizing a similarity measure.

In the process, individual characters from the haystack and the needle are
pairwise compared and scored based on how similar they are. If two characters
are identical, their alignment is assigned the similarity score `s_id`. If they
are not identical, their alignment is assigned the similarity score `s_nid`,
unless the options `:ignore_diacritics` and/or `:glossover_ocrerrors` are used
(see below).

The alignment of haystack and needle segments may also call for the
acknowledgement of gaps: positions in an aligned segment that correspond to
neither identical nor non-identical elements. To this end, `fzindex` implements
a linear gap penalty scheme according to which each such gap is assigned a gap
penalty `s_gap`. In the traceback buffers reported for a match, gaps are denoted
with a dash ('-').

When working with strings extracted from OCRed data, mismatches in the alignment
of segments may arise from the improper recognition of diacritics and/or the
mixup of two characters. A 'ç' may, for instance, have been recognized as a 'c'
and so frustrate alignment. Similarly, an 'I' is commonly OCRed as an 'l', or an
'|'. `fzindex` offers two options to help mitigate such OCR-related issues:

* The option `:ignore_diacritics` causes diacritics to be ignored in assessing
  whether two characters are identical. Hence, the pairwise comparison of 'ç'
  and 'c' results in assignment of the similarity score `s_id` rather than the
  score `s_nid`.

* The option `:glossover_ocrerrors` causes the alignment of two characters that
are commonly confused in OCR to be assigned the score `s_ocr` rather than the
score `s_nid`.

The default scores, which may be changed using correspondingly named arguments,
are as follows:

| Score |  Default value | Description                                                   |
|:------|:--------------:|:--------------------------------------------------------------|
| s_id  | +6             | Score awarded to identical/matching characters                |
| s_ocr | +3             | Score awarded to possibly identical characters in OCR context |
| s_gap | -1             | Penalty for a gap (a dash in the traceback buffer)            |
| s_nid | -1             | Score awarded to non-identical characters                     |

## Intended use
The Perl 6 built-in `index` localizes the first perfect match of a needle within
a haystack. It is fast, but when it comes up empty, one may be left wondering if
either the haystack or the needle perhaps contains a typo, spelling variation,
OCR error or the like that caused `index` to report the absence of the needle
from the haystack. In such a case, `fzindex` may be used as a backup for `index`.

However, since `index` is comparably fast, `fzindex` internally executes an
`index`-based (actually: `indices`-based) match attempt before starting a local
sequence alignment attempt. Because of this, there is generally no need to
implement the use of `fzindex` as an actual backup to the use of the `index`
built-in. Instead, the `fzindex` routine may be used instead of the built-in
`index`. Such use of `fzindex` obviously comes at a performance penalty, but has
the advantages that (i) all perfect matches are reported at once, and (ii) any
best fuzzy matches are reported in case no perfect matches exist.


## Optimization
The Perl 6 implementation of the Smith-Waterman algorithm is naturally
relatively slow, and in the present version of `String::FuzzyIndex` no
significant optimization attempt has been made. Should you need fuzzy string
matching for a large number of lengthy strings, you are probably better off with
an implementation in a low level language like C.

That said, some performance enhancing code has already been tested and is likely
to appear in future versions.

## Example

CODE:

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

OUTPUT:

    1 match(es) found.
    Match score               : 0.820513
    Matching haystack portion : squeeky weel
    Matching needle portion   : squeaky wheel
    Scoring traceback buffer  : (6 12 18 24 23 29 35 41 47 46 52 58 64)
    Haystack traceback buffer : (s q u e e k y   w - e e l)
    Needle traceback buffer   : (s q u e a k y   w h e e l)

# Revision History

* v0.2 (09.09.2019)
  - Performance improvement in perfect_match routine
* v0.1 (07.09.2019)
  - Initial release

# License
`String::FuzzyIndex` is free and open source software. You may redistribute
it and/or modify it under the terms of the Artistic License 2.0.

# Contact
Bug reports and suggestions are welcome, and may be reported via the GitHub
project page: https://github.com/threadless-screw/String-FuzzyIndex.