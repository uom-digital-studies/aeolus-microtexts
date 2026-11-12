# Run the full Ollama pipeline for a research-question schema: load, tokenise, score, write

Supports resumption: if the output CSV already exists, only new units
are scored, and results are merged with the existing output before
writing.

## Usage

``` r
run_pipeline_with_schema(
  model,
  output,
  schema,
  granularity = "sentence",
  include_headlines = TRUE,
  context_variant = "no_context",
  chat_backend = ellmer::chat_ollama
)
```

## Arguments

- model:

  Name of the Ollama model to use

- output:

  Path to write the scored results CSV to. Parent directories are
  created if needed

- schema:

  An `rq_schema`, see
  [`new_rq_schema()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/new_rq_schema.md)

- granularity:

  Unit of analysis for this run, either `"sentence"` or `"microtext"`;
  see
  [`load_aeolus()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/load_aeolus.md)

- include_headlines:

  Logical. Whether to include headlines in the analysed text; see
  [`load_aeolus()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/load_aeolus.md)

- context_variant:

  See
  [`context_variant_text()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/context_variant_text.md)

- chat_backend:

  Chat client constructor; see
  [`analyse_with_schema()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/analyse_with_schema.md)

## Value

The scored results tibble (matching the ADR 0003 CSV schema), invisibly
