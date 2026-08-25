# Real-HPC smoke-test pipeline (docs/hpc-smoke-test.md). A trimmed sibling
# of `_targets.R`: same `build_slurm_controllers()`/`build_grid_targets()`
# builders (R/pipeline-orchestration.R), but a single small model and a
# single grid cell, and its own store/results dir so it never touches the
# real pipeline's `_targets/` store or `results/` output. Run with:
#
#   Rscript -e 'targets::tar_make(script = "_test_targets.R", store = "_test_targets_store")'
#
# `llama3.2:1b` is the smallest model in `models.yml`, chosen purely to
# minimise pull time/memory for this smoke test — see
# docs/hpc-smoke-test.md for the rest of the manual validation steps
# (syncing the repo, installing the package, watching SLURM/logs, checking
# output) that this script doesn't automate.

library(targets)
library(aeolusmicrotexts)

tar_option_set(
  packages = "aeolusmicrotexts",
  imports = "aeolusmicrotexts"
)

test_models <- "llama3.2:1b"

tar_option_set(
  controller = rlang::exec(crew::crew_controller_group, !!!build_slurm_controllers(test_models))
)

list(
  tar_target(run_id, generate_run_id()),
  build_grid_targets(
    test_models,
    research_questions = "sentiment",
    context_variants = "no_context",
    granularities = "sentence",
    include_headlines = TRUE,
    results_dir = "test-results"
  )
)
