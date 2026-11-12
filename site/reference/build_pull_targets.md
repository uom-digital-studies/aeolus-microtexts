# Build dispatcher pull targets

Creates two targets for pulling all models once at pipeline start (ADR
0007):

- `models_pulled`: executes
  [`pull_models()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/pull_models.md)
  with the literal model list, so the smart cue reruns only when the
  model list changes

- `models_manifest`: writes the pulled models and their digests to
  `<results_dir>/<run_id>/models.csv` for traceability

## Usage

``` r
build_pull_targets(models, results_dir = "results")
```

## Arguments

- models:

  Character vector of Ollama model identifiers

- results_dir:

  Directory to nest `models.csv` under (default: `"results"`); the file
  itself is written to `file.path(results_dir, run_id, "models.csv")`

## Value

A list of two `tar_target_raw()` target objects

## Details

Both targets use `deployment = "main"` to run on the dispatcher, not
workers.
