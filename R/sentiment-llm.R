# LLM-based sentiment analysis via Ollama

#' Structured type describing the sentiment of a single sentence
sentiment_type <- ellmer::type_object(
  "Sentiment analysis of a sentence",
  label = ellmer::type_enum(
    "Overall sentiment of the sentence",
    values = c("positive", "neutral", "negative")
  ),
  score = ellmer::type_number(
    "Sentiment intensity, from -1 (most negative) to 1 (most positive)"
  )
)

#' Analyse the sentiment of each sentence in a tibble using an Ollama model
#'
#' @param sentence_tbl A tibble with one row per sentence (e.g. `aeolus_sentences`)
#' @param sentence Column containing the sentence text to analyse
#' @param model Name of the Ollama model to use
#' @param system_prompt Instructions given to the model before each sentence
#'
#' @returns `sentence_tbl` with two new columns: `sentiment_label` and `sentiment_score`
#' @export
analyse_sentiment_ollama <- function(sentence_tbl,
                                      sentence,
                                      model = "llama3.1",
                                      system_prompt = paste(
                                        "You are a sentiment analysis assistant.",
                                        "Classify the sentiment of this social media post you are given."
                                      )) {
  chat <- ellmer::chat_ollama(system_prompt = system_prompt, model = model)

  sentences <- dplyr::pull(sentence_tbl, {{ sentence }})

  results <- purrr::map(
    sentences,
    function(one_sentence) {
      # Clone so each call starts from a fresh (stateless) conversation
      chat$clone()$chat_structured(one_sentence, type = sentiment_type)
    },
    .progress = "Analysing sentiment"
  )

  sentence_tbl |>
    dplyr::mutate(
      sentiment_label = purrr::map_chr(results, "label"),
      sentiment_score = purrr::map_dbl(results, "score")
    )
}

#' Run the full Ollama sentiment pipeline: load, tokenise, score, write
#'
#' Loads Aeolus, splits it into sentences, scores each sentence's sentiment
#' with [analyse_sentiment_ollama()], and writes the result to `output` as a
#' CSV. This is the reusable unit called by both the `ollama-sentiment-analysis.R`
#' CLI script and, potentially, other analysis code.
#'
#' @param input Path to the Aeolus source text; see [load_aeolus()]
#' @param model Name of the Ollama model to use
#' @param output Path to write the scored sentences CSV to. Parent directories
#'   are created if needed.
#'
#' @returns The scored sentence tibble, invisibly
#' @export
run_sentiment_pipeline <- function(input, model, output) {
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)

  aeolus <- load_aeolus(input)
  aeolus_sentences <- tokenise_microtexts_by_sentence(aeolus, line, section)
  aeolus_scored_sents <- analyse_sentiment_ollama(aeolus_sentences, sentence, model)

  readr::write_csv(aeolus_scored_sents, output)
  message("Wrote ", nrow(aeolus_scored_sents), " scored sentences to ", output)

  invisible(aeolus_scored_sents)
}
