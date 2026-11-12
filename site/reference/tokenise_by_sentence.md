# Reshape Aeolus tibble to have one row per sentence, with each sentence as a string. If headlines are included, ensure they are treated as separate sentences, since they don't end with full stops.

Reshape Aeolus tibble to have one row per sentence, with each sentence
as a string. If headlines are included, ensure they are treated as
separate sentences, since they don't end with full stops.

## Usage

``` r
tokenise_by_sentence(line_tbl, line, microtext_idx, is_headline)
```

## Arguments

- line_tbl:

  A tibble of Aeolus, with one row per line

- line:

  String column containing the lines

- microtext_idx:

  Numerical column containing the index of microtexts

- is_headline:

  Logical column determining if the given line is in a headline

## Value

A new tibble, with one row per sentence
