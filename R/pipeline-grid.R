# Pure grid-building and schema-dispatch logic for the targets pipeline
# (ADR 0001). No targets/crew/crew.cluster dependency here — this is the
# piece unit tests exercise directly without a live cluster; `_targets.R`
# (Step 2) is the only place that touches crew.cluster.

#' Look up the coding schema for a research question
#'
#' `_targets.R` dispatches generically to [run_pipeline_with_schema()] per
#' grid row, since grid rows only carry the research question as a string
#' (see [build_analysis_grid()]); this looks up the matching schema object.
#'
#' @param research_question One of `"sentiment"`, `"nationalism"`, `"ugc"`
#'
#' @returns The matching `rq_schema` object (see [new_rq_schema()])
#' @export
rq_schema_for <- function(research_question) {
  switch(research_question,
    sentiment = sentiment_schema,
    nationalism = nationalism_schema,
    ugc = ugc_schema,
    stop("Unknown research_question: ", research_question, call. = FALSE)
  )
}

#' Filesystem-safe slug for a model identifier
#'
#' Ollama model identifiers can contain characters that are awkward in file
#' names (e.g. `:` in `"llama3.2:1b"`); this collapses any run of characters
#' outside `[A-Za-z0-9._-]` to a single `-`.
#'
#' @param model Raw Ollama model identifier
#'
#' @returns A single string
#' @keywords internal
slugify_model <- function(model) {
  gsub("[^A-Za-z0-9._-]+", "-", model)
}

#' Build the full analysis grid for a sweep
#'
#' One row per combination of model x research question x context variant x
#' granularity x include_headlines — the unit `_targets.R` branches over via
#' `pattern = map(grid)`, dispatching each row to
#' [run_pipeline_with_schema()] via [rq_schema_for()].
#'
#' @param models Character vector of Ollama model identifiers to sweep over
#' @param research_questions Character vector, subset of `"sentiment"`,
#'   `"nationalism"`, `"ugc"`
#' @param context_variants Character vector, subset of `"no_context"`,
#'   `"ulysses_context"`, `"media_text_context"`
#' @param granularities Character vector, subset of `"sentence"`,
#'   `"microtext"`
#' @param include_headlines Logical vector, subset of `TRUE`/`FALSE`
#' @param output_dir Directory the per-cell results CSVs are written under
#'
#' @returns A tibble with one row per grid cell: `model`,
#'   `research_question`, `context_variant`, `granularity`,
#'   `include_headlines`, and `output` (a filesystem-safe, unique path under
#'   `output_dir`)
#' @export
build_analysis_grid <- function(models,
                                 research_questions = c("sentiment", "nationalism", "ugc"),
                                 context_variants = c("no_context", "ulysses_context", "media_text_context"),
                                 granularities = c("sentence", "microtext"),
                                 include_headlines = c(TRUE, FALSE),
                                 output_dir = "results") {
  tidyr::expand_grid(
    model = models,
    research_question = research_questions,
    context_variant = context_variants,
    granularity = granularities,
    include_headlines = include_headlines
  ) |>
    dplyr::mutate(
      output = file.path(
        output_dir,
        paste0(
          slugify_model(model), "_",
          research_question, "_",
          context_variant, "_",
          granularity, "_",
          ifelse(include_headlines, "with-headlines", "no-headlines"),
          ".csv"
        )
      )
    )
}

#' Generate a run identifier
#'
#' Combines a timestamp and a package version, per ADR 0004 and the "Run"
#' entry in `CONTEXT.md`, so every `results/<run_id>/...` output directory
#' is traceable to the exact code that produced it. Both arguments are
#' injectable so tests don't depend on wall-clock time or the installed
#' package version.
#'
#' @param version Package version to embed, defaults to the installed
#'   `aeolusmicrotexts` version
#' @param when Timestamp to embed, defaults to `Sys.time()`
#'
#' @returns A single string, e.g. `"20260821-153000_v0.1.0.9000"`
#' @export
generate_run_id <- function(version = utils::packageVersion("aeolusmicrotexts"),
                             when = Sys.time()) {
  paste0(format(when, "%Y%m%d-%H%M%S"), "_v", as.character(version))
}
