# Look up the coding schema for a research question

`_targets.R` dispatches generically to
[`run_pipeline_with_schema()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/run_pipeline_with_schema.md)
per grid row, since grid rows only carry the research question as a
string (see
[`build_analysis_grid()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/build_analysis_grid.md));
this looks up the matching schema object.

## Usage

``` r
rq_schema_for(research_question)
```

## Arguments

- research_question:

  One of `"sentiment"`, `"nationalism"`, `"ugc"`

## Value

The matching `rq_schema` object (see
[`new_rq_schema()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/new_rq_schema.md))
