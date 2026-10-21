# RQ1: LLM-based sentiment analysis via Ollama.
#
# Schema only — the shared analyse/run logic lives in R/ollama-engine.R.

#' Coding schema for sentiment analysis (RQ1)
#'
#' @details Field order is deliberate: `score` is generated after `label`
#'   and may depend on it; see `docs/structured-output.md`.
#'
#' @include rq-schema-type.R
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
