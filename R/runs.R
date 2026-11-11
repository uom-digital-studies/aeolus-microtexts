# Access to promoted runs: curated results and model metadata copied into
# inst/extdata/results/<run_id>/ after researcher review (see CONTEXT.md
# "Promoted run" and docs/adr/0003-results-csv-schema.md).

#' List the promoted runs
#'
#' Scans the promoted runs directory (`inst/extdata/results/` in the installed
#' package) and returns one row per run, newest first.
#'
#' Every subdirectory must be a valid run directory: its name must be a run_id
#' (`<YYYYMMDD-HHMMSS>_v<version>`) and it must contain both `results.csv` and
#' `models.csv`. Other files are ignored.
#'
#' @param dir Root directory of promoted runs. Defaults to the shipped
#'   `inst/extdata/results/`. Intended for testing with fixture roots.
#'
#' @returns A tibble with columns `run_id` (character), `date` (POSIXct,
#'   parsed from the run_id), `version` (character, parsed from the run_id),
#'   and `models` (list-column of character vectors of model names, as
#'   recorded in `models.csv`). Use `tidyr::unnest(models)` to get one row
#'   per model.
#' @seealso [read_run()] to read a run's results, [read_run_metadata()] to
#'   read its model metadata.
#' @export
list_runs <- function(dir = promoted_runs_dir()) {
  run_dirs <- list.dirs(dir, recursive = FALSE, full.names = FALSE)
  if (length(run_dirs) == 0) {
    stop("list_runs(): no runs found in ", dir)
  }

  parsed <- purrr::map(run_dirs, parse_run_id)
  purrr::walk(run_dirs, run_files, dir = dir)

  tibble::tibble(
    run_id = run_dirs,
    date = do.call(c, purrr::map(parsed, "date")),
    version = purrr::map_chr(parsed, "version"),
    models = purrr::map(run_dirs, \(id) read_run_metadata(id, dir)$model)
  ) |>
    dplyr::arrange(dplyr::desc(date))
}

#' Read the results of a promoted run
#'
#' Reads `results.csv` for a promoted run and validates it against the ADR 0003
#' schema. The returned tibble has no `run_id` column; bind runs together with
#' the `.id` argument of [dplyr::bind_rows()] if needed.
#'
#' @param run_id A run_id as listed by [list_runs()]. Matched exactly.
#' @param dir Root directory of promoted runs. Defaults to the shipped
#'   `inst/extdata/results/`. Intended for testing with fixture roots.
#'
#' @returns A tibble of results conforming to ADR 0003.
#' @seealso [list_runs()]
#'
#' @examples
#' \dontrun{
#' ids <- list_runs()$run_id
#' read_run(ids[1])
#'
#' # Combine several runs, tagging each row with its run_id
#' purrr::map(ids, read_run) |>
#'   purrr::set_names(ids) |>
#'   dplyr::bind_rows(.id = "run_id")
#' }
#' @export
read_run <- function(run_id, dir = promoted_runs_dir()) {
  if (missing(run_id)) {
    stop("read_run(): `run_id` is required; see list_runs() for available runs")
  }
  files <- run_files(run_id, dir)

  res <- suppressWarnings(readr::read_csv(
    files[["results"]],
    col_types = readr::cols(
      research_question = readr::col_character(),
      model = readr::col_character(),
      context_variant = readr::col_character(),
      granularity = readr::col_character(),
      include_headlines = readr::col_logical(),
      microtext = readr::col_integer(),
      unit_index = readr::col_integer(),
      unit_of_analysis = readr::col_character(),
      label = readr::col_character(),
      score = readr::col_double()
    ),
    progress = FALSE
  ))

  probs <- readr::problems(res)
  if (nrow(probs) > 0) {
    stop("read_run(): ", run_id, "/results.csv has unparseable values:\n",
         paste0("- row ", probs$row, ", column ", probs$col, ": ", probs$expected,
                " expected, got '", probs$actual, "'", collapse = "\n"))
  }

  validate_results_schema(res)
  # Return results visibly
  res
}

#' Read the model metadata of a promoted run
#'
#' Reads `models.csv` for a promoted run: one row per model with its digest.
#' Named broadly so that future metadata (e.g. JSON) can be returned by the
#' same function; the current return is `models.csv` as-is.
#'
#' @inheritParams read_run
#' @returns A tibble with character columns `model` and `digest`, one row per
#'   model.
#' @seealso [list_runs()]
#' @export
read_run_metadata <- function(run_id, dir = promoted_runs_dir()) {
  if (missing(run_id)) {
    stop("read_run_metadata(): `run_id` is required; see list_runs() for available runs")
  }
  files <- run_files(run_id, dir)

  meta <- readr::read_csv(
    files[["models"]],
    col_types = readr::cols(.default = readr::col_character()),
    progress = FALSE
  )

  if (!identical(names(meta), c("model", "digest"))) {
    stop("read_run_metadata(): ", run_id, "/models.csv must have columns `model` and `digest`; found: ",
         paste(names(meta), collapse = ", "))
  }
  dup <- unique(meta$model[duplicated(meta$model)])
  if (length(dup) > 0) {
    stop("read_run_metadata(): ", run_id, "/models.csv has duplicate models: ",
         paste(dup, collapse = ", "))
  }
  if (any(is.na(meta$digest) | meta$digest == "")) {
    stop("read_run_metadata(): ", run_id, "/models.csv has empty `digest` values")
  }

  meta
}

# Shipped promoted runs directory; errors if the package is not installed
promoted_runs_dir <- function() {
  dir <- system.file("extdata", "results", package = "aeolusmicrotexts")
  if (dir == "") {
    stop("Promoted runs directory not found; is aeolusmicrotexts installed?")
  }
  dir
}

# Splits a run_id into its date (POSIXct, local tz as in generate_run_id())
# and version. Errors if x is not a run_id.
parse_run_id <- function(x) {
  m <- regexec("^([0-9]{8}-[0-9]{6})_v([0-9]+(\\.[0-9]+)*)$", x)
  parts <- regmatches(x, m)[[1]]
  if (length(parts) == 0) {
    stop("Not a valid run_id: '", x, "' (expected <YYYYMMDD-HHMMSS>_v<version>)")
  }
  list(
    date = as.POSIXct(parts[[2]], format = "%Y%m%d-%H%M%S"),
    version = parts[[3]]
  )
}

# Paths to a run's results.csv and models.csv; errors if the run or either
# file is missing.
run_files <- function(run_id, dir) {
  run_dir <- file.path(dir, run_id)
  if (!dir.exists(run_dir)) {
    stop("Unknown run_id '", run_id, "'; see list_runs() for available runs")
  }
  files <- c(results = file.path(run_dir, "results.csv"),
             models = file.path(run_dir, "models.csv"))
  missing_files <- basename(files[!file.exists(files)])
  if (length(missing_files) > 0) {
    stop("Run '", run_id, "' is missing: ", paste(missing_files, collapse = ", "))
  }
  files
}
