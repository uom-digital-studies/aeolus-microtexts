# RQ1: LLM-based sentiment analysis via Ollama.
#
# Schema only — the shared analyse/run logic lives in R/ollama-engine.R.

#' Coding schema for sentiment analysis (RQ1)
#'
#' @export
sentiment_schema <- new_rq_schema(
  name = "sentiment",
  type = ellmer::type_object(
    "Classify the sentiment of this text as positive, neutral, or negative",
    label = ellmer::type_enum(
      "Overall sentiment of the text",
      values = c("positive", "neutral", "negative")
    ),
    score = ellmer::type_number(
      "Sentiment intensity, from -1 (most negative) to 1 (most positive)"
    )
  )
)

#' Analyse the sentiment of each unit of analysis in a tibble using an Ollama model
#'
#' Thin wrapper around [analyse_with_schema()] using [sentiment_schema].
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
#'   schema: `research_question` (`"sentiment"`), `label`, and `score`
#' @export
analyse_sentiment_ollama <- function(unit_tbl,
                                      unit_of_analysis,
                                      model = "llama3.1",
                                      context_variant = "no_context",
                                      chat_backend = ellmer::chat_ollama) {
  analyse_with_schema(unit_tbl, {{ unit_of_analysis }}, sentiment_schema,
    model = model, context_variant = context_variant, chat_backend = chat_backend
  )
}

#' Run the full Ollama sentiment pipeline: load, tokenise, score, write
#'
#' Thin wrapper around [run_pipeline_with_schema()] using [sentiment_schema].
#' This is the reusable unit called by both the `ollama-sentiment-analysis.R`
#' CLI script and, potentially, other analysis code.
#'
#' @param model Name of the Ollama model to use
#' @param output Path to write the scored results CSV to. Parent directories
#'   are created if needed.
#' @param granularity Unit of analysis for this run; see [load_aeolus()]
#' @param include_headlines Logical. Whether to include headlines; see
#'   [load_aeolus()]
#' @param context_variant See [context_variant_text()]
#' @param chat_backend Chat client constructor; see [analyse_with_schema()]
#'
#' @returns The scored results tibble, invisibly
#' @export
run_sentiment_pipeline <- function(model, output,
                                    granularity = "sentence",
                                    include_headlines = TRUE,
                                    context_variant = "no_context",
                                    chat_backend = ellmer::chat_ollama) {
  run_pipeline_with_schema(model, output, sentiment_schema,
    granularity = granularity, include_headlines = include_headlines,
    context_variant = context_variant, chat_backend = chat_backend
  )
}
