#' @include ollama-engine.R
NULL

# Thin YAML reader for the model sweep list (ADR 0001). No
# targets/crew/crew.cluster dependency here — `_targets.R` (Step 2) is the
# only place that feeds this into `build_analysis_grid()`.

#' Read the list of models to sweep over
#'
#' @param path Path to the YAML file; see `models.yml` at the repo root for
#'   the expected shape (a top-level `models` sequence of objects, each with
#'   a `name` and a `source` of either `"central"` or `"project"`)
#'
#' @returns A tibble with columns `model` (Ollama model identifier) and
#'   `source` (`"central"` or `"project"`), one row per declared model
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

  purrr::map_dfr(models, \(entry) {
    if (is.null(entry[["name"]]) || is.null(entry[["source"]])) {
      stop(
        "models file ", path,
        " has an entry missing a required 'name' or 'source' field",
        call. = FALSE
      )
    }

    if (!entry[["source"]] %in% c("central", "project")) {
      stop(
        "models file ", path, " has model '", entry[["name"]],
        "' with an invalid source '", entry[["source"]],
        "' (must be 'central' or 'project')",
        call. = FALSE
      )
    }

    tibble::tibble(model = entry[["name"]], source = entry[["source"]])
  })
}
