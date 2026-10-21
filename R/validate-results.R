# Validates results CSVs against the ADR 0003 column schema
# (docs/adr/0003-results-csv-schema.md). Used by run_pipeline_with_schema()
# when deciding whether an existing output CSV can be resumed from.

#' Validate a results tibble against the ADR 0003 schema
#'
#' Checks that `tbl` has all columns required by the results-CSV schema
#' described in `docs/adr/0003-results-csv-schema.md`, and that
#' `context_variant` and `granularity` only contain the enum values ADR 0003
#' fixes, and that `include_headlines` is logical. Does not check
#' `research_question`, `label`, or `score`, since valid values for those are
#' defined per-schema (see [new_rq_schema()]) rather than fixed by ADR 0003.
#'
#' @param tbl A tibble to validate, typically a results CSV read back from
#'   disk.
#'
#' @returns `tbl`, invisibly, if valid. Otherwise throws an error naming the
#'   missing columns and/or invalid values found.
#' @export
validate_results_schema <- function(tbl) {
  required_cols <- c("research_question", "model", "context_variant", "granularity",
                    "include_headlines", "microtext", "unit_index", "unit_of_analysis",
                    "label", "score")
  missing_cols <- setdiff(required_cols, names(tbl))
  if (length(missing_cols) > 0) {
    stop("Output CSV missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  problems <- c(
    enum_problem(tbl, "context_variant", c("no_context", "ulysses_context", "media_text_context")),
    enum_problem(tbl, "granularity", c("microtext", "sentence")),
    if (!is.logical(tbl$include_headlines)) {
      "include_headlines: must be logical, got " |> paste0(class(tbl$include_headlines)[[1]])
    }
  )
  if (length(problems) > 0) {
    stop("Output CSV failed schema validation:\n", paste("-", problems, collapse = "\n"))
  }

  invisible(tbl)
}

# Returns a one-line description of any values in tbl[[col]] outside
# allowed_values, or NULL if all values are allowed.
enum_problem <- function(tbl, col, allowed_values) {
  bad_values <- setdiff(unique(tbl[[col]]), allowed_values)
  if (length(bad_values) == 0) {
    return(NULL)
  }
  paste0(col, ": invalid value(s) ", paste(bad_values, collapse = ", "),
         " (allowed: ", paste(allowed_values, collapse = ", "), ")")
}
