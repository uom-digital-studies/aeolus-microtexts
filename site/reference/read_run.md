# Read the results of a promoted run

Reads `results.csv` for a promoted run and validates it against the ADR
0003 schema. The returned tibble has no `run_id` column; bind runs
together with the `.id` argument of
[`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
if needed.

## Usage

``` r
read_run(run_id, dir = promoted_runs_dir())
```

## Arguments

- run_id:

  A run_id as listed by
  [`list_runs()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/list_runs.md).
  Matched exactly.

- dir:

  Root directory of promoted runs. Defaults to the shipped
  `inst/extdata/results/`. Intended for testing with fixture roots.

## Value

A tibble of results conforming to ADR 0003.

## See also

[`list_runs()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/list_runs.md)

## Examples

``` r
if (FALSE) { # \dontrun{
ids <- list_runs()$run_id
read_run(ids[1])

# Combine several runs, tagging each row with its run_id
purrr::map(ids, read_run) |>
  purrr::set_names(ids) |>
  dplyr::bind_rows(.id = "run_id")
} # }
```
