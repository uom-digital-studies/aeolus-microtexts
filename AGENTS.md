# R style

- Always qualify functions with their namespace (unless base R), e.g. `dplyr::filter`
- Exception to qualifying functions: do not qualify `aeolusmicrotext` functions in `_targets.R`, because this will confuse the static analysis.
- Prefer tidyverse functions, e.g. `purrr` for iteration, `tibble` for data frames
- Use the native pipe
- New RQ schema files (like `nationalism.R`, `sentiment-llm.R`, `ugc.R`) call `new_rq_schema()` at the top level, so they must load after `R/ollama-engine.R`. Tag them `#' @include ollama-engine.R` and run `devtools::document()` to regenerate `DESCRIPTION`'s `Collate` field — never hand-edit `Collate` (see ADR 0002). If a new file adds any other top-level, load-order-sensitive code, give it an `@include` tag for its dependency too.

# Project structure

- This repo is an installable R package (`aeolusmicrotexts`) holding reusable logic (`R/`), data (`inst/extdata/`), and vignettes.
- HPC/SLURM infrastructure is kept as sibling files outside the package (root-level scripts/configs), not inside `R/` or `inst/`.
- Pipeline orchestration follows ADR 0001 (`docs/adr/0001-crew-cluster-drives-slurm.md`): `targets` + `crew.cluster` drive SLURM directly. `_targets.R` and `slurm-resources.yml` live at the repo root and call into package functions. `models.yml` stays a separate root file so model choices are tracked distinctly in git history. The existing hand-written `.slurm`/bash scripts are superseded and will be deleted once the `targets` pipeline is validated.
- Result CSVs are promoted into `inst/extdata/results/` only manually, after researcher review; full run output stays external (synced via `sync-results.sh`), never committed.
- RO-Crate deposit is an aspirational, non-binding future goal — don't let it drive current structural decisions.
- See `CONTEXT.md` for domain terminology and `docs/adr/` for architectural decisions.

# Project management

- Be as concise as possible while still making sense. Sacrifice grammar for concision.
- Outstanding work is tracked in `TODO.md`, not in `AGENTS.md`/`CONTEXT.md`
- Summarise all key changes in `NEWS.md`, and remind the human to bump the version using `usethis::use_version()` as appropriate.
- Run `devtools::check()` or remind the user to do so at the end of all work sessions
