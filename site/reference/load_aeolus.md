# Read in Aeolus and split into microtexts, optionally filtering or tokenising further.

Read in Aeolus and split into microtexts, optionally filtering or
tokenising further.

## Usage

``` r
load_aeolus(
  granularity = c("microtext", "sentence"),
  include_headlines = c(TRUE, FALSE)
)
```

## Arguments

- granularity:

  The chosen unit of analysis for this run, either "sentence" or
  "microtext"

- include_headlines:

  Whether to include the headline or filter them out of the analysis.

## Value

A tibble, with each line of Aeolus keyed to a microtext
