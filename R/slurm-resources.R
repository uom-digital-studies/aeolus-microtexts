# Thin YAML reader + per-model resource resolution for crew.cluster SLURM
# controllers (ADR 0001). No crew/crew.cluster dependency here — just the
# pure merge logic, testable without a live cluster; `build_slurm_controllers()`
# (R/pipeline-orchestration.R) is the only place that spreads the result
# (after prefixing field names with `slurm_`) into
# `crew.cluster::crew_controller_slurm()`.

#' Read the SLURM resource configuration file
#'
#' @param path Path to the YAML file; see `slurm-resources.yml` at the repo
#'   root for the expected shape (a `default` block plus optional
#'   per-model `models` overrides)
#'
#' @returns A list with (at least) a `default` element
#' @export
read_slurm_resources <- function(path = "slurm-resources.yml") {
  if (!file.exists(path)) {
    stop("slurm resources file not found: ", path, call. = FALSE)
  }

  resources <- yaml::read_yaml(path)

  if (is.null(resources[["default"]])) {
    stop(
      "slurm resources file ", path, " is missing a required 'default' block",
      call. = FALSE
    )
  }

  resources
}

#' Resolve the SLURM resources for a given model
#'
#' Merges the `default` block with any `models[[model]]` override,
#' per-field — an override only replaces the fields it names, leaving the
#' rest of `default` untouched. Field names deliberately match
#' `crew.cluster::crew_controller_slurm()`'s `slurm_*` arguments, minus
#' their `slurm_` prefix (`partition`, `cpus_per_task`,
#' `memory_gigabytes_per_cpu`, `time_minutes`) — [build_slurm_controllers()]
#' adds the prefix back before spreading the result into it.
#'
#' @param model Model identifier to look up an override for
#' @param resources A list as returned by [read_slurm_resources()]
#'
#' @returns A named list of resolved SLURM options
#' @export
resolve_slurm_resources <- function(model, resources = read_slurm_resources()) {
  if (is.null(resources[["default"]])) {
    stop("resources is missing a required 'default' block", call. = FALSE)
  }

  override <- resources[["models"]][[model]]
  if (is.null(override)) {
    override <- list()
  }

  utils::modifyList(resources$default, override)
}
