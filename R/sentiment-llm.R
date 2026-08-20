# RQ1: LLM-based sentiment analysis via Ollama.
#
# Schema only — the shared analyse/run logic lives in R/ollama-engine.R.

#' Coding schema for sentiment analysis (RQ1)
#'
#' @export
sentiment_schema <- new_rq_schema(
  name = "sentiment",
  type = ellmer::type_object(
    "Classify the sentiment of this social media post as positive, neutral, or negative",
    label = ellmer::type_enum(
      "Overall sentiment of the sentence",
      values = c("positive", "neutral", "negative")
    ),
    score = ellmer::type_number(
      "Sentiment intensity, from -1 (most negative) to 1 (most positive)"
    )
  )
)

#' Analyse the sentiment of each sentence in a tibble using an Ollama model
#'
#' Thin wrapper around [analyse_with_schema()] using [sentiment_schema].
#'
#' @param sentence_tbl A tibble with one row per sentence (e.g. `aeolus_sentences`)
#' @param sentence Column containing the sentence text to analyse
#' @param model Name of the Ollama model to use
#' @param context_variant See [context_variant_text()]
#' @param chat_backend Chat client constructor; see [analyse_with_schema()]
#'
#' @returns `sentence_tbl` with two new columns: `sentiment_label` and `sentiment_score`
#' @export
analyse_sentiment_ollama <- function(sentence_tbl,
                                      sentence,
                                      model = "llama3.1",
                                      context_variant = "no_context",
                                      chat_backend = ellmer::chat_ollama) {
  analyse_with_schema(sentence_tbl, sentence, sentiment_schema,
    model = model, context_variant = context_variant, chat_backend = chat_backend
  )
}

#' Run the full Ollama sentiment pipeline: load, tokenise, score, write
#'
#' Thin wrapper around [run_pipeline_with_schema()] using [sentiment_schema].
#' This is the reusable unit called by both the `ollama-sentiment-analysis.R`
#' CLI script and, potentially, other analysis code.
#'
#' @param input Path to the Aeolus source text; see [load_aeolus()]
#' @param model Name of the Ollama model to use
#' @param output Path to write the scored sentences CSV to. Parent directories
#'   are created if needed.
#' @param context_variant See [context_variant_text()]
#' @param chat_backend Chat client constructor; see [analyse_with_schema()]
#'
#' @returns The scored sentence tibble, invisibly
#' @export
run_sentiment_pipeline <- function(input, model, output,
                                    context_variant = "no_context",
                                    chat_backend = ellmer::chat_ollama) {
  run_pipeline_with_schema(input, model, output, sentiment_schema,
    context_variant = context_variant, chat_backend = chat_backend
  )
}
