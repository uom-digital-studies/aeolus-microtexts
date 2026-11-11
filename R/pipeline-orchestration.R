# crew.cluster/targets-specific orchestration layer (ADR 0001). Wraps the
# pure grid logic in R/pipeline-grid.R and R/slurm-resources.R into the
# controllers and target objects a `targets` pipeline script needs; this is
# the only file that touches `crew`/`crew.cluster`/`targets` directly. Kept
# here (rather than inline in `_targets.R`) so `_targets.R` and
# `_test_targets.R` (root-level orchestration entry points, per project
# structure notes) can share it without duplicating controller/target
# construction logic.

#' The project's model store directory
#'
#' Computed as a fixed sibling of the repo checkout root (e.g.
#' `<checkout>/../ollama_models`) rather than sourced from an environment
#' variable: since the whole repo now lives inside the confidential Spartan
#' project directory (that directory is the confidentiality boundary), the
#' checkout's own location is no longer sensitive, so this path can be
#' derived automatically instead of threaded through config. Uses
#' [rprojroot::find_root()] to locate the checkout root robustly regardless
#' of the current working directory.
#'
#' @param start Directory to start searching upward from for the repo root
#'
#' @returns A single string: the absolute path to the model store
#'   directory
#' @keywords internal
model_store_dir <- function(start = ".") {
  repo_root <- rprojroot::find_root(rprojroot::is_r_package, path = start)
  file.path(dirname(repo_root), "ollama_models")
}

#' Script lines run on an Ollama worker node before it starts pulling tasks
#'
#' Loads the module chain Spartan's GPU partition requires for Ollama
#' (`GCCcore` -> `ollama` -> `foss`/`R`, matching the example scripts on
#' the server), points `OLLAMA_MODELS` at the model store directory,
#' sets `OLLAMA_NOPRUNE=1` to prevent the server from pruning unused models
#' (the dispatcher pulls once; workers must only check for existence),
#' starts the cluster's `run_ollama_server` wrapper (Spartan's own wrapper
#' around `ollama serve` — not called directly) in the background, waits for
#' it to respond, then checks that the model exists in the store. Workers
#' never pull; only the dispatcher does (ADR 0007).
#'
#' Unlike a plain `ollama serve`, Spartan's `run_ollama_server` binds to a
#' *random* port each time (it shares GPU nodes across users, so port 11434
#' can't be assumed free) and only reports the chosen `host:port` in its own
#' stdout, e.g. `OLLAMA_HOST=spartan-gpgpu126:34267 ollama <CMD>`. So this
#' redirects that stdout to a log file, polls it until the `OLLAMA_HOST=...`
#' line appears, and exports it — plus `OLLAMA_BASE_URL` (the env var
#' `ellmer::chat_ollama()` actually reads, in `http://host:port` form) —
#' before probing readiness, so every later command in the job (the readiness
#' curl, the model check, and the R worker process itself) talks to the right
#' port instead of silently falling back to the unused default of 11434.
#'
#' The server log is written to `ollama-logs/<sanitised model>_$SLURM_JOB_ID.log`
#' rather than a fixed relative name: every GPU worker job runs from the same
#' checkout-root working directory (one `crew.cluster` SLURM job per model,
#' ADR 0001), so a shared plain filename like `ollama-server.log` is clobbered
#' by every concurrent model's worker (and by `crew`'s own relaunch of a
#' timed-out worker for the *same* model) — a worker can read another
#' worker's `OLLAMA_HOST=` line, or a truncated/interleaved one. Keying the
#' path on both the model slug and `$SLURM_JOB_ID` (always set inside an
#' `sbatch` job) gives every worker job its own file.
#'
#' This log also contains the TTY progress-bar redraw sequences
#' `run_ollama_server`/`ollama pull` emit, which makes `grep` treat the file
#' as binary and, without `-a`, print `"binary file matches"` instead of the
#' actual match — silently breaking the `OLLAMA_HOST` extraction. Both
#' `grep` calls here force text mode with `-a` to avoid that, and the result
#' is checked for emptiness (failing the job immediately with a clear
#' message) rather than letting a blank `OLLAMA_HOST` silently produce a
#' hostless `OLLAMA_BASE_URL=http://` that only surfaces later as a
#' confusing `ellmer`/`httr2` URL-parsing error.
#'
#' The leading `#SBATCH --gres=gpu:<n>` line requests the GPU(s). `gres_gpu`
#' lets this be e.g. `"gpu:2"` for a model too large for one A100's VRAM —
#' see `gres_gpu` in `slurm-resources.yml` (ADR 0001).
#' `crew.cluster::crew_controller_slurm()` has no dedicated `gres` argument,
#' but `sbatch` keeps scanning for `#SBATCH` directives up to the first
#' non-comment line, and `crew.cluster` places `script_lines` immediately
#' after its own generated header with no other commands in between — so a
#' `#SBATCH` line is still honoured here as long as it comes first.
#'
#' @param model Ollama model identifier
#' @param gres_gpu Value for the `--gres` SLURM directive, e.g. `"gpu:1"`
#'   (default) or `"gpu:2"` for a model that needs more than one GPU's VRAM
#' @param model_store Path to the model store directory (default:
#'   [model_store_dir()])
#'
#' @returns A character vector of shell script lines
#' @keywords internal
ollama_worker_script_lines <- function(model, gres_gpu = "gpu:1", model_store = model_store_dir()) {
  slug <- sanitise_target_name(model)
  ollama_log <- paste0("ollama-logs/", slug, "_${SLURM_JOB_ID}.log")
  c(
    paste0("#SBATCH --gres=", gres_gpu),
    "module purge",
    # Load modules in separate lines to facilitate updating;
    # if they are all in one line, then tests are harder to update
    "module load foss/2024a",
    "module load ollama/0.40.8-CUDA-12.8.0",
    "module load R/4.6.1",
    paste0("export OLLAMA_MODELS=", model_store),
    "export OLLAMA_NOPRUNE=1",
    "export OLLAMA_CONTEXT_LENGTH=2048",
    "mkdir -p ollama-logs",
    paste0("OLLAMA_LOG=", ollama_log),
    "run_ollama_server > $OLLAMA_LOG 2>&1 &",
    "for i in $(seq 1 30); do grep -aq 'OLLAMA_HOST=' $OLLAMA_LOG && break; sleep 2; done",
    "export OLLAMA_HOST=$(grep -aoE 'OLLAMA_HOST=\\S+' $OLLAMA_LOG | head -1 | cut -d= -f2)",
    "if [ -z \"$OLLAMA_HOST\" ]; then echo \"Could not find OLLAMA_HOST= in $OLLAMA_LOG; aborting\" >&2; exit 1; fi",
    "export OLLAMA_BASE_URL=http://${OLLAMA_HOST}",
    "for i in $(seq 1 30); do curl -sf http://${OLLAMA_HOST}/ && break; sleep 2; done",
    paste0("ollama show ", model, " > /dev/null || { echo \"Model ", model, " not in model store; aborting\" >&2; exit 1; }")
  )
}

#' The address workers should dial to reach the dispatcher
#'
#' Resolves the dispatcher node's own hostname via DNS, rather than letting
#' `crew` default to the first entry of `nanonext::ip_addr()`: Spartan
#' compute nodes have several interfaces, and the first-listed one is not
#' reachable from other nodes, so workers' dials time out (ADR 0006,
#' "Amendment: dispatcher host address"). The DNS-resolved address is what
#' other nodes use to reach this one, independent of interface order or
#' names. Evaluated wherever the pipeline script is sourced, i.e. inside the
#' dispatcher job.
#'
#' @param nodename Hostname to resolve; defaults to this machine's
#' @param resolve Function mapping a hostname to an IP string, or `NULL` if
#'   it can't be resolved; injectable for tests
#'
#' @returns A single string: the resolved IP address
#' @keywords internal
dispatcher_host <- function(nodename = Sys.info()[["nodename"]],
                            resolve = utils::nsl) {
  ip <- resolve(nodename)
  if (is.null(ip) || length(ip) != 1L || is.na(ip) || identical(ip, "")) {
    stop(
      "Could not resolve dispatcher hostname '", nodename, "' to an IP ",
      "address; pass `host` to build_slurm_controllers() explicitly",
      call. = FALSE
    )
  }
  ip
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
#' Each worker's SLURM stdout/stderr is captured to
#' `crew-logs/<sanitised model>_<job id>.log` (relative to the working
#' directory `targets::tar_make()` is run from) — `crew.cluster` defaults
#' this to `/dev/null` otherwise, which silently discards module-load,
#' Ollama startup, and worker errors. The `crew-logs/` directory is
#' created here (not left to SLURM) because a missing `--output` directory
#' makes `sbatch` fail the job immediately.
#'
#' @param models A character vector of Ollama model identifiers, or a
#'   tibble as returned by [read_models()] (the `model` column is extracted)
#' @param resources A list as returned by [read_slurm_resources()];
#'   per-model overrides are resolved via [resolve_slurm_resources()]
#'   keyed off model names. A resolved `gres_gpu` field (e.g. `"gpu:2"`)
#'   is passed to [ollama_worker_script_lines()] rather than spliced into
#'   `crew.cluster::crew_options_slurm()`, which has no matching argument;
#'   it defaults to `"gpu:1"` when absent
#' @param host Address the dispatcher listens on and workers dial; see
#'   [dispatcher_host()] for why `crew`'s own default isn't used
#' @param seconds_launch Seconds `crew` waits for a launched worker to
#'   connect before treating it as lost and relaunching. Must cover GPU
#'   queue wait, but stay well below the dispatcher job's walltime: `crew`'s
#'   default (86400) makes a worker that dies before connecting leave the
#'   dispatcher hanging silently until walltime (ADR 0006). If a worker dies
#'   before connecting (e.g. module load fails, Ollama server fails to start),
#'   `crew` will relaunch it endlessly until either the worker connects or the
#'   dispatcher walltime is reached; this is a known behavior in crew 1.3.3,
#'   accepted per ADR 0007
#'
#' @returns A list of `crew_controller_slurm` objects, one per model, each
#'   named for its model
#' @export
build_slurm_controllers <- function(models,
                                    resources = read_slurm_resources(),
                                    host = dispatcher_host(),
                                    seconds_launch = 3600) {
  # Support both character vectors and tibbles (from read_models())
  if (is.data.frame(models)) {
    model_names <- models$model
  } else {
    model_names <- models
  }

  dir.create("crew-logs", showWarnings = FALSE)
  controllers <- purrr::map(model_names, function(model) {
    model_resources <- resolve_slurm_resources(model, resources = resources)
    # gres_gpu drives the #SBATCH --gres line (ollama_worker_script_lines()),
    # not a crew_options_slurm() argument, so it's pulled out of the splice
    # below rather than passed straight through.
    gres_gpu <- model_resources[["gres_gpu"]]
    if (is.null(gres_gpu)) {
      gres_gpu <- "gpu:1"
    }
    model_resources[["gres_gpu"]] <- NULL
    slug <- sanitise_target_name(model)
    rlang::exec(
      crew.cluster::crew_controller_slurm,
      name = model,
      workers = 1,
      host = host,
      seconds_launch = seconds_launch,
      # crew.cluster >= 0.4.0 moved script_lines and the slurm_*
      # arguments off crew_controller_slurm() itself and onto this
      # options_cluster object (the top-level slurm_* arguments are
      # deprecated).
      options_cluster = rlang::exec(
        crew.cluster::crew_options_slurm,
        script_lines = ollama_worker_script_lines(model, gres_gpu = gres_gpu),
        # Defaults to /dev/null, which silently discards worker
        # stdout/stderr (module loads, ollama startup, mirai worker errors) -
        # the opposite of what you want while debugging a stalled/vanished job.
        # One file per worker job, %A = SLURM job ID.
        log_output = file.path("crew-logs", paste0(slug, "_%A.log")),
        log_error = file.path("crew-logs", paste0(slug, "_%A.log")),
        !!!model_resources
      )
    )
  })
  rlang::set_names(controllers, model_names)
}

#' Build dispatcher pull targets
#'
#' Creates two targets for pulling all models once at pipeline start (ADR 0007):
#' - `models_pulled`: executes [pull_models()] with the literal model list, so
#'   the smart cue reruns only when the model list changes
#' - `models_manifest`: writes the pulled models and their digests to
#'   `<results_dir>/<run_id>/models.csv` for traceability
#'
#' Both targets use `deployment = "main"` to run on the dispatcher, not workers.
#'
#' @param models Character vector of Ollama model identifiers
#' @param results_dir Directory to nest `models.csv` under (default: `"results"`);
#'   the file itself is written to `file.path(results_dir, run_id, "models.csv")`
#'
#' @returns A list of two `tar_target_raw()` target objects
#' @export
build_pull_targets <- function(models, results_dir = "results") {
  list(
    targets::tar_target_raw(
      name = "models_pulled",
      command = rlang::expr(pull_models(models = !!models)),
      deployment = "main"
    ),
    targets::tar_target_raw(
      name = "models_manifest",
      command = rlang::expr(
        write_models_manifest(models_pulled, file.path(!!results_dir, run_id))
      ),
      format = "file",
      deployment = "main"
    )
  )
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
#' **Important**: The grid command references `models_pulled` to ensure workers
#' don't launch before models are pulled. This is done via
#' `{ models_pulled; build_analysis_grid(...) }` in the command.
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
          {
            models_pulled
            build_analysis_grid(
              models = !!model,
              research_questions = !!research_questions,
              context_variants = !!context_variants,
              granularities = !!granularities,
              include_headlines = !!include_headlines,
              output_dir = file.path(!!results_dir, run_id)
            )
          }
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
