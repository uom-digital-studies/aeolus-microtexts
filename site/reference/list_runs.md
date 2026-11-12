# List the promoted runs

Scans the promoted runs directory (`inst/extdata/results/` in the
installed package) and returns one row per run, newest first.

## Usage

``` r
list_runs(dir = promoted_runs_dir())
```

## Arguments

- dir:

  Root directory of promoted runs. Defaults to the shipped
  `inst/extdata/results/`. Intended for testing with fixture roots.

## Value

A tibble with columns `run_id` (character), `date` (POSIXct, parsed from
the run_id), `version` (character, parsed from the run_id), and `models`
(list-column of character vectors of model names, as recorded in
`models.csv`). Use `tidyr::unnest(models)` to get one row per model.

## Details

Every subdirectory must be a valid run directory: its name must be a
run_id (`<YYYYMMDD-HHMMSS>_v<version>`) and it must contain both
`results.csv` and `models.csv`. Other files are ignored.

## See also

[`read_run()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/read_run.md)
to read a run's results,
[`read_run_metadata()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/read_run_metadata.md)
to read its model metadata.
