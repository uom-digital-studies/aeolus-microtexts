# Filesystem-safe slug for a model identifier

Ollama model identifiers can contain characters that are awkward in file
names (e.g. `:` in `"llama3.2:1b"`); this collapses any run of
characters outside `[A-Za-z0-9._-]` to a single `-`.

## Usage

``` r
slugify_model(model)
```

## Arguments

- model:

  Raw Ollama model identifier

## Value

A single string
