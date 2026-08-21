# Use an explicit `Collate` field to fix R file load order

> **Update (2026-08-21):** superseded in favour of `@include` roxygen tags. See
> note at the end of this ADR.

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

## Update: switched to `@include` roxygen tags

The hand-maintained `Collate` field silently went stale: a new file
(`R/aeolusmicrotexts-package.R`) was added without updating `Collate`, which
made `R CMD INSTALL`/`renv::install(".")` fail outright ("files ... missing
from 'Collate' field") rather than degrade gracefully. Nothing enforced
keeping the list in sync with `R/`.

We now let roxygen2 generate `Collate` from `@include` tags declared on the
files that have the load-order dependency: `nationalism.R`, `sentiment-llm.R`,
and `ugc.R` each declare `@include ollama-engine.R` (since they call
`new_rq_schema()` at the top level). Files with no load-order dependency
(`data.R`, `aeolusmicrotexts-package.R`, `pipeline-grid.R`,
`slurm-resources.R`) need no tag. Running `devtools::document()` /
`roxygen2::roxygenise()` regenerates `Collate` automatically, so adding a new
file can't silently break it — either the file has no ordering dependency and
needs no tag, or it does and the tag documents it right next to the code that
needs it.
