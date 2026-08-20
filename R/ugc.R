# RQ3: LLM-based user-generated-content (UGC) resemblance analysis via
# Ollama. Scaffolding only — schema not yet finalised, no analysis logic.

#' Coding schema for UGC-resemblance analysis (RQ3)
#'
#' TODO(RQ3): the `label` values and `score`/instruction text below are
#' placeholders (`"???"`) pending the final RQ3 analysis design.
#'
#' @export
ugc_schema <- new_rq_schema(
  name = "ugc",
  type = ellmer::type_object(
    "???",
    label = ellmer::type_enum(
      "???",
      values = c("???", "???", "???")
    ),
    score = ellmer::type_number(
      "???"
    )
  )
)

#' Analyse how closely each sentence resembles social media content, using an Ollama model
#'
#' @param sentence_tbl A tibble with one row per sentence (e.g. `aeolus_sentences`)
#' @param sentence Column containing the sentence text to analyse
#' @param model Name of the Ollama model to use
#' @param context_variant See [context_variant_text()]
#' @param chat_backend Chat client constructor; see [analyse_with_schema()]
#'
#' @returns `sentence_tbl` with two new columns: `ugc_label` and `ugc_score`
#' @export
analyse_ugc_ollama <- function(sentence_tbl,
                                sentence,
                                model = "llama3.1",
                                context_variant = "no_context",
                                chat_backend = ellmer::chat_ollama) {
  # TODO(RQ3): remove this guard and delegate to analyse_with_schema()
  # (mirroring analyse_sentiment_ollama() in R/sentiment-llm.R) once
  # ugc_schema above is finalised.
  stop("analyse_ugc_ollama() is not yet implemented", call. = FALSE)
}

#' Run the full Ollama UGC-resemblance pipeline: load, tokenise, score, write
#'
#' @param input Path to the Aeolus source text; see [load_aeolus()]
#' @param model Name of the Ollama model to use
#' @param output Path to write the scored sentences CSV to
#' @param context_variant See [context_variant_text()]
#' @param chat_backend Chat client constructor; see [analyse_with_schema()]
#'
#' @returns The scored sentence tibble, invisibly
#' @export
run_ugc_pipeline <- function(input, model, output,
                              context_variant = "no_context",
                              chat_backend = ellmer::chat_ollama) {
  # TODO(RQ3): remove this guard and delegate to run_pipeline_with_schema()
  # (mirroring run_sentiment_pipeline() in R/sentiment-llm.R) once
  # analyse_ugc_ollama() is implemented.
  stop("run_ugc_pipeline() is not yet implemented", call. = FALSE)
}
