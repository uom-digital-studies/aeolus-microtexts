# Render an RQ schema's output fields as the output specification

Neither ellmer nor Ollama shows the structured-output schema to the
model: it only constrains which tokens can be generated, so field
descriptions (e.g. a score's intended range) are otherwise never read.
This renders each field, in schema order, as plain text for the system
prompt. See ADR 0008 and `docs/structured-output.md`.

## Usage

``` r
build_output_spec(schema)
```

## Arguments

- schema:

  An `rq_schema`, see
  [`new_rq_schema()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/new_rq_schema.md)

## Value

A single string
