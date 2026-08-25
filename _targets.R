# targets + crew.cluster SLURM pipeline (ADR 0001). One crew.cluster SLURM
# controller/worker group per model (each starting `ollama serve` once and
# reusing it across that model's research-question x context-variant x
# granularity x include_headlines cells), combined into a controller group.
#
# Controller and target construction live in
# `R/pipeline-orchestration.R`'s `build_slurm_controllers()` /
# `build_grid_targets()` (shared with `_test_targets.R`'s smaller smoke-test
# grid, see docs/hpc-smoke-test.md) — this file just supplies the real
# model list and grid parameters.
#
# Package loading (ADR 0004): aeolusmicrotexts must be **installed**
# (`scripts/run-sweep.sh` runs `renv::install(".")` before `tar_make()`),
# not loaded via `devtools::load_all()` — this file calls its exported
# functions unqualified (per AGENTS.md), which requires the library() call
# below in addition to `packages=`/`imports=` in tar_option_set() (that
# option only governs how *target commands* are evaluated, not how this
# script itself builds the pipeline).

library(targets)
library(aeolusmicrotexts)

tar_option_set(
  packages = "aeolusmicrotexts",
  imports = "aeolusmicrotexts"
)

models <- read_models()

tar_option_set(
  controller = rlang::exec(crew::crew_controller_group, !!!build_slurm_controllers(models))
)

list(
  tar_target(run_id, generate_run_id()),
  build_grid_targets(models)
)
