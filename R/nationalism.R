# RQ2: LLM-based nationalism analysis via Ollama.
#
# Schema only — the shared analyse/run logic lives in R/ollama-engine.R.

#' Coding schema for nationalist-orientation analysis (RQ2)
#'
#' @include ollama-engine.R
#' @export
nationalism_schema <- new_rq_schema(
  name = "nationalism",
  type = ellmer::type_object(
    "Classify the nationalist orientation of this text",
    label = ellmer::type_enum(
      "Nationalist orientation of the text",
      values = c("nationalist", "ambivalent", "anti-nationalist")
    ),
    score = ellmer::type_number(
      "Nationalism index, from -1 (strongly anti-nationalist) to 1 (strongly nationalist)"
    )
  )
)

#' Analyse the nationalist orientation of each unit of analysis using an Ollama model
#'
#' Thin wrapper around [analyse_with_schema()] using [nationalism_schema].
#'
#' @param unit_tbl A tibble with one row per unit of analysis (e.g. the
#'   output of [load_aeolus()])
#' @param unit_of_analysis Column containing the unit-of-analysis text to
#'   analyse
#' @param model Name of the Ollama model to use
#' @param context_variant See [context_variant_text()]
#' @param chat_backend Chat client constructor; see [analyse_with_schema()]
#'
#' @returns `unit_tbl` with three new columns conforming to the ADR 0003
#'   schema: `research_question` (`"nationalism"`), `label`, and `score`
#' @export
analyse_nationalism_ollama <- function(unit_tbl,
                                        unit_of_analysis,
                                        model = "llama3.1",
                                        context_variant = "no_context",
                                        chat_backend = ellmer::chat_ollama) {
  analyse_with_schema(unit_tbl, {{ unit_of_analysis }}, nationalism_schema,
    model = model, context_variant = context_variant, chat_backend = chat_backend
  )
}

#' Run the full Ollama nationalism pipeline: load, tokenise, score, write
#'
#' Thin wrapper around [run_pipeline_with_schema()] using [nationalism_schema].
#'
#' @param model Name of the Ollama model to use
#' @param output Path to write the scored results CSV to
#' @param granularity Unit of analysis for this run; see [load_aeolus()]
#' @param include_headlines Logical. Whether to include headlines; see
#'   [load_aeolus()]
#' @param context_variant See [context_variant_text()]
#' @param chat_backend Chat client constructor; see [analyse_with_schema()]
#'
#' @returns The scored results tibble, invisibly
#' @export
run_nationalism_pipeline <- function(model, output,
                                      granularity = "sentence",
                                      include_headlines = TRUE,
                                      context_variant = "no_context",
                                      chat_backend = ellmer::chat_ollama) {
  run_pipeline_with_schema(model, output, nationalism_schema,
    granularity = granularity, include_headlines = include_headlines,
    context_variant = context_variant, chat_backend = chat_backend
  )
}
