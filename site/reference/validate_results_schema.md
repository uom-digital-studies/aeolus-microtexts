# Validate a results tibble against the ADR 0003 schema

Checks that `tbl` has all columns required by the results-CSV schema
described in `docs/adr/0003-results-csv-schema.md`, and that
`context_variant` and `granularity` only contain the enum values ADR
0003 fixes, and that `include_headlines` is logical. Does not check
`research_question`, `label`, or `score`, since valid values for those
are defined per-schema (see
[`new_rq_schema()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/new_rq_schema.md))
rather than fixed by ADR 0003.

## Usage

``` r
validate_results_schema(tbl)
```

## Arguments

- tbl:

  A tibble to validate, typically a results CSV read back from disk.

## Value

`tbl`, invisibly, if valid. Otherwise throws an error naming the missing
columns and/or invalid values found.
