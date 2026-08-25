# crew.cluster/targets-specific orchestration layer (ADR 0001). Wraps the
# pure grid logic in R/pipeline-grid.R and R/slurm-resources.R into the
# controllers and target objects a `targets` pipeline script needs; this is
# the only file that touches `crew`/`crew.cluster`/`targets` directly. Kept
# here (rather than inline in `_targets.R`) so `_targets.R` and
# `_test_targets.R` (root-level orchestration entry points, per project
# structure notes) can share it without duplicating controller/target
# construction logic.

#' Script lines run on an Ollama worker node before it starts pulling tasks
#'
#' Starts `ollama serve` in the background, waits for it to respond, then
#' pulls the model once so every task the worker runs afterwards reuses the
#' same warm server/model.
#'
#' @param model Ollama model identifier
#'
#' @returns A character vector of shell script lines
#' @keywords internal
ollama_worker_script_lines <- function(model) {
  c(
    "ollama serve &",
    "for i in $(seq 1 30); do curl -sf http://127.0.0.1:11434/ && break; sleep 2; done",
    paste("ollama pull", model)
  )
}

#' Sanitise a raw Ollama model identifier into a valid `targets` symbol name
#'
#' Deliberately distinct from [slugify_model()] (used for filesystem-safe
#' output paths in [build_analysis_grid()]) — target-name validity is a
#' `targets`-specific concern.
#'
#' @param model Raw Ollama model identifier
#'
#' @returns A single string valid as a `targets` target name
#' @keywords internal
sanitise_target_name <- function(model) {
  gsub("[^A-Za-z0-9_.]+", "_", model)
}

#' Build one crew.cluster SLURM controller per model
#'
#' One controller/worker group per model (ADR 0001) — each worker starts
#' `ollama serve` once via [ollama_worker_script_lines()] and reuses it
#' across that model's research-question x context-variant x granularity x
#' include_headlines cells. Splice the result into
#' `crew::crew_controller_group()` and pass to
#' `tar_option_set(controller = ...)`.
#'
#' @param models Character vector of Ollama model identifiers
#' @param resources A list as returned by [read_slurm_resources()];
#'   per-model overrides are resolved via [resolve_slurm_resources()]
#'
#' @returns A list of `crew_controller_slurm` objects, one per model, each
#'   named for its model
#' @export
build_slurm_controllers <- function(models, resources = read_slurm_resources()) {
  controllers <- purrr::map(models, function(model) {
    model_resources <- resolve_slurm_resources(model, resources = resources)
    crew.cluster::crew_controller_slurm(
      name = model,
      workers = 1,
      options_cluster = rlang::exec(
        crew.cluster::crew_options_slurm,
        script_lines = ollama_worker_script_lines(model),
        !!!model_resources
      )
    )
  })
  rlang::set_names(controllers, models)
}

#' Build the per-model grid/scored `targets` target pairs for a sweep
#'
#' One `(grid_<model>, scored_<model>)` target pair per model (ADR 0001):
#' `grid_<model>` builds that model's rows via [build_analysis_grid()], and
#' `scored_<model>` branches dynamically over those rows, dispatching each
#' to `run_pipeline_with_schema()` via `rq_schema_for()`, pinned to that
#' model's controller/worker group (`resources = tar_resources_crew(controller
#' = model)`). Split into one pair per model, rather than one grid-wide
#' branching target, because a single dynamic-branching target can only be
#' pinned to one crew controller (`tar_resources_crew(controller=)` is a
#' length-1 string fixed at target-definition time, not resolved per
#' branch).
#'
#' Each grid target's `output_dir` is `file.path(results_dir, run_id)`,
#' where `run_id` is looked up by name — the calling pipeline script must
#' define a target named `run_id` (e.g. `tar_target(run_id,
#' generate_run_id())`) so `targets` can track it as a dependency.
#'
#' @param models Character vector of Ollama model identifiers to sweep over
#' @param research_questions,context_variants,granularities,include_headlines
#'   Passed through to [build_analysis_grid()]
#' @param results_dir Directory the per-cell results CSVs are written
#'   under, nested under the `run_id` target's value (see Details)
#'
#' @returns A (nested) list of `tar_target_raw()` target objects, suitable
#'   for splicing into the pipeline script's returned target list
#' @export
build_grid_targets <- function(models,
                                research_questions = c("sentiment", "nationalism", "ugc"),
                                context_variants = c("no_context", "ulysses_context", "media_text_context"),
                                granularities = c("sentence", "microtext"),
                                include_headlines = c(TRUE, FALSE),
                                results_dir = "results") {
  purrr::map(models, function(model) {
    slug <- sanitise_target_name(model)
    grid_name <- paste0("grid_", slug)
    scored_name <- paste0("scored_", slug)
    grid_sym <- as.symbol(grid_name)

    list(
      targets::tar_target_raw(
        name = grid_name,
        command = rlang::expr(
          build_analysis_grid(
            models = !!model,
            research_questions = !!research_questions,
            context_variants = !!context_variants,
            granularities = !!granularities,
            include_headlines = !!include_headlines,
            output_dir = file.path(!!results_dir, run_id)
          )
        )
      ),
      targets::tar_target_raw(
        name = scored_name,
        command = rlang::expr(
          run_pipeline_with_schema(
            model = !!model,
            output = (!!grid_sym)$output,
            schema = rq_schema_for((!!grid_sym)$research_question),
            granularity = (!!grid_sym)$granularity,
            include_headlines = (!!grid_sym)$include_headlines,
            context_variant = (!!grid_sym)$context_variant
          )
        ),
        pattern = rlang::expr(map(!!grid_sym)),
        resources = targets::tar_resources(
          crew = targets::tar_resources_crew(controller = model)
        )
      )
    )
  })
}
