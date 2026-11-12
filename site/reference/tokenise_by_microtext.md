# Reshape Aeolus tibble to have one row per microtext, with each microtext as a string.

Reshape Aeolus tibble to have one row per microtext, with each microtext
as a string.

## Usage

``` r
tokenise_by_microtext(line_tbl, line, microtext_idx)
```

## Arguments

- line_tbl:

  A tibble of Aeolus, with one row per line

- line:

  String column containing the lines

- microtext_idx:

  Numerical column containing the index of microtexts

## Value

A new tibble, with one row per microtext
