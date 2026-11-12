# Construct a research-question coding schema

A schema describes only the task and desired output shape for a research
question: the
[`ellmer::type_object()`](https://ellmer.tidyverse.org/reference/type_boolean.html)
used for structured LLM output, whose `description` doubles as the task
instruction (the single source of truth, not hand-duplicated in a
separate prompt string). It does not fix a model or context variant —
those are independent factors, supplied separately when the schema is
applied.

## Usage

``` r
new_rq_schema(name, type)
```

## Arguments

- name:

  Short RQ identifier (e.g. `"sentiment"`), recorded verbatim in the
  `research_question` output column (see
  [`analyse_with_schema()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/analyse_with_schema.md))

- type:

  An
  [`ellmer::type_object()`](https://ellmer.tidyverse.org/reference/type_boolean.html)
  describing the structured response; its `@description` is used as the
  task instruction

## Value

An `rq_schema` object
