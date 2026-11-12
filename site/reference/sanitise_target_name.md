# Sanitise a raw Ollama model identifier into a valid `targets` symbol name

Deliberately distinct from
[`slugify_model()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/slugify_model.md)
(used for filesystem-safe output paths in
[`build_analysis_grid()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/build_analysis_grid.md))
— target-name validity is a `targets`-specific concern.

## Usage

``` r
sanitise_target_name(model)
```

## Arguments

- model:

  Raw Ollama model identifier

## Value

A single string valid as a `targets` target name
