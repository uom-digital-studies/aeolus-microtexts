# Mask whitespace after single-letter initials (e.g. "J." in "J. J. O'Molloy") so a sentence tokeniser won't mistake them for sentence-final full stops.

Mask whitespace after single-letter initials (e.g. "J." in "J. J.
O'Molloy") so a sentence tokeniser won't mistake them for sentence-final
full stops.

## Usage

``` r
protect_initials(text)
```

## Arguments

- text:

  Character vector of raw text

## Value

Character vector, with whitespace after lone initials replaced by
`initial_placeholder`
