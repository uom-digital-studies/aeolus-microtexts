# Read the list of models to sweep over

Read the list of models to sweep over

## Usage

``` r
read_models(path = "models.yml")
```

## Arguments

- path:

  Path to the YAML file; see `models.yml` at the repo root for the
  expected shape (a top-level `models` sequence of objects, each with a
  `name` field; stray keys are ignored)

## Value

A tibble with columns `model` (Ollama model identifier), one row per
declared model
