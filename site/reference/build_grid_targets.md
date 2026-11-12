# Build the per-model grid/scored `targets` target pairs for a sweep

One `(grid_<model>, scored_<model>)` target pair per model (ADR 0001):
`grid_<model>` builds that model's rows via
[`build_analysis_grid()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/build_analysis_grid.md),
and `scored_<model>` branches dynamically over those rows, dispatching
each to
[`run_pipeline_with_schema()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/run_pipeline_with_schema.md)
via
[`rq_schema_for()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/rq_schema_for.md),
pinned to that model's controller/worker group
(`resources = tar_resources_crew(controller = model)`). Split into one
pair per model, rather than one grid-wide branching target, because a
single dynamic-branching target can only be pinned to one crew
controller (`tar_resources_crew(controller=)` is a length-1 string fixed
at target-definition time, not resolved per branch).

## Usage

``` r
build_grid_targets(
  models,
  research_questions = c("sentiment", "nationalism", "ugc"),
  context_variants = c("no_context", "ulysses_context", "media_text_context"),
  granularities = c("sentence", "microtext"),
  include_headlines = c(TRUE, FALSE),
  results_dir = "results"
)
```

## Arguments

- models:

  Character vector of Ollama model identifiers to sweep over

- research_questions, context_variants, granularities,
  include_headlines:

  Passed through to
  [`build_analysis_grid()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/build_analysis_grid.md)

- results_dir:

  Directory the per-cell results CSVs are written under, nested under
  the `run_id` target's value (see Details)

## Value

A (nested) list of `tar_target_raw()` target objects, suitable for
splicing into the pipeline script's returned target list

## Details

Each grid target's `output_dir` is `file.path(results_dir, run_id)`,
where `run_id` is looked up by name — the calling pipeline script must
define a target named `run_id` (e.g.
`tar_target(run_id, generate_run_id())`) so `targets` can track it as a
dependency.

**Important**: The grid command references `models_pulled` to ensure
workers don't launch before models are pulled. This is done via
`{ models_pulled; build_analysis_grid(...) }` in the command.
