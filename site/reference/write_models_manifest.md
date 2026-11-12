# Write a model manifest to the results directory

Writes the output of
[`pull_models()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/pull_models.md)
to a CSV file for traceability.

## Usage

``` r
write_models_manifest(pulled, output_dir)
```

## Arguments

- pulled:

  A tibble as returned by
  [`pull_models()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/pull_models.md),
  with columns `model` and `digest`

- output_dir:

  Directory to write the manifest to (created if needed)

## Value

The path to the written CSV file
