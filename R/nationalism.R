# LLM-based nationalism analysis via Ollama (RQ2 — scaffolding only, no
# analysis logic yet)

#' Structured type describing the nationalist orientation of a sentence
nationalism_type <- ellmer::type_object(
  "Analyse a text for nationalist ideas",
  label = ellmer::type_enum(
    "Nationalist orientation of the sentence",
    values = c("nationalist", "ambivalent", "anti-nationalist")
  ),
  score = ellmer::type_number(
    "Nationalism index, from -1 (strongly anti-nationalist) to 1 (strongly nationalist)"
  )
)

#' Analyse the nationalist orientation of each sentence using an Ollama model
#'
#' @param sentence_tbl A tibble with one row per sentence (e.g. `aeolus_sentences`)
#' @param sentence Column containing the sentence text to analyse
#' @param model Name of the Ollama model to use
#' @param system_prompt Instructions given to the model before each sentence
#'
#' @returns `sentence_tbl` with two new columns: `nationalism_label` and `nationalism_score`
#' @export
analyse_nationalism_ollama <- function(sentence_tbl,
                                        sentence,
                                        model = "llama3.1",
                                        system_prompt = paste(
                                          "You are a political discourse analysis assistant.",
                                          "Classify the nationalist orientation of this text you are given."
                                        )) {
  # TODO(RQ2): implement, mirroring analyse_sentiment_ollama() in
  # R/sentiment-llm.R once the nationalism analysis design is finalised.
  stop("analyse_nationalism_ollama() is not yet implemented", call. = FALSE)
}

#' Run the full Ollama nationalism pipeline: load, tokenise, score, write
#'
#' @param input Path to the Aeolus source text; see [load_aeolus()]
#' @param model Name of the Ollama model to use
#' @param output Path to write the scored sentences CSV to
#'
#' @returns The scored sentence tibble, invisibly
#' @export
run_nationalism_pipeline <- function(input, model, output) {
  # TODO(RQ2): implement, mirroring run_sentiment_pipeline() in
  # R/sentiment-llm.R once analyse_nationalism_ollama() exists.
  stop("run_nationalism_pipeline() is not yet implemented", call. = FALSE)
}
