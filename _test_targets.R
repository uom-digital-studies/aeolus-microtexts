# Real-HPC smoke-test pipeline, driven by `scripts/test-run.sh`. A trimmed sibling
# of `_targets.R`: same `build_slurm_controllers()`/`build_grid_targets()`
# builders (R/pipeline-orchestration.R), but a single small model and a
# single grid cell, and its own store/results dir so it never touches the
# real pipeline's `_targets/` store or `results/` output. Run with:
#
#   Rscript -e 'targets::tar_make(script = "_test_targets.R", store = "_test_targets_store")'
#
# Initial tests had a problem: the internal model store had a permission
# issue, that prevent ollama from serving the model to this process.
# Accordingly, I've changed the test to download a small model.

library(targets)
library(aeolusmicrotexts)

tar_option_set(
  packages = "aeolusmicrotexts",
  imports = "aeolusmicrotexts"
)

test_models <- tibble::tibble(model = "llama3.2:1b", source = "project")

tar_option_set(
  controller = rlang::exec(crew::crew_controller_group, !!!build_slurm_controllers(test_models))
)

list(
  tar_target(run_id, generate_run_id()),
  build_grid_targets(
    test_models$model,
    research_questions = "sentiment",
    context_variants = "no_context",
    granularities = "microtext",
    include_headlines = TRUE,
    results_dir = "test-results"
  )
)
