# Use an explicit `Collate` field to fix R file load order

Package R files are sourced in a fixed order at load/build time (both by
`devtools::load_all()` and `R CMD INSTALL`). Several files now define
top-level values that run immediately on sourcing rather than deferring to
call time: `R/nationalism.R` and `R/sentiment-llm.R` each call
`new_rq_schema()` (defined in `R/ollama-engine.R`) to build their schema
object at the top level. Without an explicit order, files are sourced
alphabetically, so `nationalism.R` loads before `ollama-engine.R` and fails
with "could not find function `new_rq_schema`".

We added an explicit `Collate` field to `DESCRIPTION`, listing
`ollama-engine.R` before the per-RQ schema files (`nationalism.R`,
`sentiment-llm.R`, `ugc.R`), which in turn come after `data.R` (schema
files don't depend on `data.R`, but pipeline logic in `ollama-engine.R`
does via `load_aeolus()`/`tokenise_microtexts_by_sentence()`).

Alternative considered: define each schema lazily, e.g. inside the
`analyse_*_ollama()` wrapper or via a function instead of a top-level
binding. Rejected for now — top-level schema objects are simpler to
inspect/test directly (`sentiment_schema$label_col`), and the load-order
fix is a one-line `DESCRIPTION` addition. If new files are added that
introduce further top-level, load-order-sensitive definitions, `Collate`
should be extended accordingly (or reconsidered in favour of lazy
construction).
