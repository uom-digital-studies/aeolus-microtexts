# Convert an ellmer type to the JSON Schema used for structured output

Approximates what ellmer sends as `response_format` for the types used
in RQ schemas (object, enum, basic scalars), for display in
[`preview_prompt()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/preview_prompt.md)
only. ellmer's own converter is unexported.

## Usage

``` r
type_to_json_schema(type)
```

## Arguments

- type:

  An ellmer type

## Value

A list, serialisable with
[`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
