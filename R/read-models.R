#' @include ollama-engine.R
NULL

# Thin YAML reader for the model sweep list (ADR 0001). No
# targets/crew/crew.cluster dependency here — `_targets.R` (Step 2) is the
# only place that feeds this into `build_analysis_grid()`.

#' Read the list of models to sweep over
#'
#' @param path Path to the YAML file; see `models.yml` at the repo root for
#'   the expected shape (a top-level `models` sequence)
#'
#' @returns A character vector of Ollama model identifiers
#' @export
read_models <- function(path = "models.yml") {
  if (!file.exists(path)) {
    stop("models file not found: ", path, call. = FALSE)
  }

  models <- yaml::read_yaml(path)[["models"]]

  if (is.null(models)) {
    stop(
      "models file ", path, " is missing a required 'models' block",
      call. = FALSE
    )
  }

  unlist(models)
}
