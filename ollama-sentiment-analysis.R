# Use Ollama to grade sentiments in each Aeolus microtext

source("load-aeolus.R")

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

# --- CLI entry point ---------------------------------------------------
# `commandArgs(trailingOnly = TRUE)` is empty in an interactive session, so
# defaults below apply automatically when sourcing this file at the console.
parser <- optparse::OptionParser()
parser <- optparse::add_option(parser, "--input", type = "character",
                      default = "7_Aeolus.txt",
                      help = "Input microtexts file [default %default]")
parser <- optparse::add_option(parser, "--model", type = "character",
                      default = Sys.getenv("OLLAMA_MODEL", "llama3.2:1b"),
                      help = "Ollama model to use [default %default]")
parser <- optparse::add_option(parser, "--output", type = "character",
                      default = NA,
                      help = paste(
                        "Output CSV path.",
                        "Defaults to results/<model>-sentiment.csv"
                      ))

args <- optparse::parse_args(parser)

if (is.na(args$output)) {
  model_slug <- gsub("[^A-Za-z0-9._-]+", "-", args$model)
  args$output <- file.path("results", paste0(model_slug, "-sentiment.csv"))
}
dir.create(dirname(args$output), recursive = TRUE, showWarnings = FALSE)

aeolus <- load_aeolus(args$input)
aeolus_sentences <- tokenise_microtexts_by_sentence(aeolus, line, section)
aeolus_scored_sents <- analyse_sentiment_ollama(
  aeolus_sentences,
  sentence,
  args$model
)

readr::write_csv(aeolus_scored_sents, args$output)
message("Wrote ", nrow(aeolus_scored_sents), " scored sentences to ", args$output)
