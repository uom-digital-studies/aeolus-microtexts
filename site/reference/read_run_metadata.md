# Read the model metadata of a promoted run

Reads `models.csv` for a promoted run: one row per model with its
digest. Named broadly so that future metadata (e.g. JSON) can be
returned by the same function; the current return is `models.csv` as-is.

## Usage

``` r
read_run_metadata(run_id, dir = promoted_runs_dir())
```

## Arguments

- run_id:

  A run_id as listed by
  [`list_runs()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/list_runs.md).
  Matched exactly.

- dir:

  Root directory of promoted runs. Defaults to the shipped
  `inst/extdata/results/`. Intended for testing with fixture roots.

## Value

A tibble with character columns `model` and `digest`, one row per model.

## See also

[`list_runs()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/list_runs.md)
