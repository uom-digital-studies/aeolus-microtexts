# LLM-based user-generated-content (UGC) resemblance analysis via Ollama
# (RQ3 — scaffolding only, no analysis logic yet)

#' Structured type describing whether a text resembles social media content
#'
#' TODO(RQ3): the `label` values and `score` description below are
#' placeholders (`"???"`) pending the final RQ3 analysis design.
social_media_text_type <- ellmer::type_object(
  "Determine if a text is typical of social media content",
  label = ellmer::type_enum(
    "???",
    values = c("???", "???", "???")
  ),
  score = ellmer::type_number(
    "???"
  )
)

#' Analyse how closely each sentence resembles social media content, using an Ollama model
#'
#' @param sentence_tbl A tibble with one row per sentence (e.g. `aeolus_sentences`)
#' @param sentence Column containing the sentence text to analyse
#' @param model Name of the Ollama model to use
#' @param system_prompt Instructions given to the model before each sentence
#'
#' @returns `sentence_tbl` with two new columns: `ugc_label` and `ugc_score`
#' @export
analyse_ugc_ollama <- function(sentence_tbl,
                                sentence,
                                model = "llama3.1",
                                system_prompt = paste(
                                  "You are a social media content analysis assistant.",
                                  "Classify whether this text resembles user-generated social media content."
                                )) {
  # TODO(RQ3): implement, mirroring analyse_sentiment_ollama() in
  # R/sentiment-llm.R once the UGC analysis design (and social_media_text_type
  # above) is finalised.
  stop("analyse_ugc_ollama() is not yet implemented", call. = FALSE)
}

#' Run the full Ollama UGC-resemblance pipeline: load, tokenise, score, write
#'
#' @param input Path to the Aeolus source text; see [load_aeolus()]
#' @param model Name of the Ollama model to use
#' @param output Path to write the scored sentences CSV to
#'
#' @returns The scored sentence tibble, invisibly
#' @export
run_ugc_pipeline <- function(input, model, output) {
  # TODO(RQ3): implement, mirroring run_sentiment_pipeline() in
  # R/sentiment-llm.R once analyse_ugc_ollama() exists.
  stop("run_ugc_pipeline() is not yet implemented", call. = FALSE)
}
