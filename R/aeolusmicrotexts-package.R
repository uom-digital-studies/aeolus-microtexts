#' @keywords internal
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL

# Bare column names referenced via dplyr/tidyr NSE (e.g. `dplyr::mutate(x = ...)`)
# rather than `.data$x`, across R/data.R, R/pipeline-grid.R, R/ollama-engine.R.
# Most of these are the results-CSV schema columns fixed by ADR 0003
# (docs/adr/0003-results-csv-schema.md); the rest (`line`, `is_headline`,
# `previous_is_true`, `split_on`, `microtext_idx`, `temp_microtext`) are
# internal-only intermediate columns in `load_aeolus()`. Both groups are
# stable and unlikely to change, so declaring them here (rather than
# rewriting every reference as `.data$...`) is preferred for now.
utils::globalVariables(c(
  # ADR 0003 results-CSV schema columns
  "research_question", "model", "context_variant", "granularity",
  "microtext", "unit_index", "unit_of_analysis", "label", "score",
  # internal-only intermediate columns (load_aeolus())
  "line", "is_headline", "previous_is_true", "split_on", "microtext_idx",
  "temp_microtext"
))
