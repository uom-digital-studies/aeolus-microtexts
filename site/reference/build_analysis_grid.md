# Build the full analysis grid for a sweep

One row per combination of model x research question x context variant x
granularity x include_headlines — the unit `_targets.R` branches over
via `pattern = map(grid)`, dispatching each row to
[`run_pipeline_with_schema()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/run_pipeline_with_schema.md)
via
[`rq_schema_for()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/rq_schema_for.md).

## Usage

``` r
build_analysis_grid(
  models,
  research_questions = c("sentiment", "nationalism", "ugc"),
  context_variants = c("no_context", "ulysses_context", "media_text_context"),
  granularities = c("sentence", "microtext"),
  include_headlines = c(TRUE, FALSE),
  output_dir = "results"
)
```

## Arguments

- models:

  Character vector of Ollama model identifiers to sweep over

- research_questions:

  Character vector, subset of `"sentiment"`, `"nationalism"`, `"ugc"`

- context_variants:

  Character vector, subset of `"no_context"`, `"ulysses_context"`,
  `"media_text_context"`

- granularities:

  Character vector, subset of `"sentence"`, `"microtext"`

- include_headlines:

  Logical vector, subset of `TRUE`/`FALSE`

- output_dir:

  Directory the per-cell results CSVs are written under

## Value

A tibble with one row per grid cell: `model`, `research_question`,
`context_variant`, `granularity`, `include_headlines`, and `output` (a
filesystem-safe, unique path under `output_dir`)
