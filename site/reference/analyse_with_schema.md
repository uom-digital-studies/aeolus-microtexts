# Analyse each unit of analysis in a tibble against a research-question schema

Analyse each unit of analysis in a tibble against a research-question
schema

## Usage

``` r
analyse_with_schema(
  aeolus_tbl,
  unit_of_analysis,
  schema,
  model = "llama3.1",
  context_variant = "no_context",
  system_prompt = build_system_prompt(schema, context_variant),
  chat_backend = ellmer::chat_ollama,
  skip_indices = NULL
)
```

## Arguments

- aeolus_tbl:

  A tibble with one row per unit of analysis (e.g. the output of
  [`load_aeolus()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/load_aeolus.md))

- unit_of_analysis:

  Column containing the unit-of-analysis text to analyse

- schema:

  An `rq_schema`, see
  [`new_rq_schema()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/new_rq_schema.md)

- model:

  Name of the Ollama model to use

- context_variant:

  See
  [`context_variant_text()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/context_variant_text.md);
  ignored if `system_prompt` is supplied directly

- system_prompt:

  Instructions given to the model before each unit of analysis; defaults
  to
  [`build_system_prompt()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/build_system_prompt.md)
  applied to `schema`/`context_variant`

- chat_backend:

  Chat client constructor with signature
  `function(system_prompt, model, params)`, returning an object with
  `$clone()` and `$chat_structured(text, type)`. Defaults to
  [`ellmer::chat_ollama`](https://ellmer.tidyverse.org/reference/chat_ollama.html);
  swap in a fake for tests

- skip_indices:

  Integer vector of row indices to skip during analysis. If provided,
  the corresponding rows are excluded from the LLM call and from the
  returned tibble entirely. Enables resumption on relaunch when previous
  progress is loaded from disk. Defaults to `NULL` (analyze all rows).

## Value

The rows of `aeolus_tbl` that were scored (i.e. excluding
`skip_indices`), with three new columns conforming to the ADR 0003
schema: `research_question` (`schema$name`), `label`, and `score`.
