# Compose the system prompt for a schema

Context variant + task instruction + output specification (see
CONTEXT.md). The task instruction is read from `schema$type@description`
and the output specification from its fields (see
[`build_output_spec()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/build_output_spec.md)),
so the RQ schema stays the single source of truth.

## Usage

``` r
build_system_prompt(schema, context_variant = "no_context")
```

## Arguments

- schema:

  An `rq_schema`, see
  [`new_rq_schema()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/new_rq_schema.md)

- context_variant:

  See
  [`context_variant_text()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/context_variant_text.md)

## Value

A single string, suitable as a chat system prompt
