# RQ2: LLM-based nationalism analysis via Ollama.
#
# Schema only — the shared analyse/run logic lives in R/ollama-engine.R.

#' Coding schema for nationalist-orientation analysis (RQ2)
#'
#' @export
nationalism_schema <- new_rq_schema(
  name = "nationalism",
  type = ellmer::type_object(
    "Classify the nationalist orientation of this text",
    label = ellmer::type_enum(
      "Nationalist orientation of the sentence",
      values = c("nationalist", "ambivalent", "anti-nationalist")
    ),
    score = ellmer::type_number(
      "Nationalism index, from -1 (strongly anti-nationalist) to 1 (strongly nationalist)"
    )
  )
)

#' Analyse the nationalist orientation of each sentence using an Ollama model
#'
#' Thin wrapper around [analyse_with_schema()] using [nationalism_schema].
#'
#' @param sentence_tbl A tibble with one row per sentence (e.g. `aeolus_sentences`)
#' @param sentence Column containing the sentence text to analyse
#' @param model Name of the Ollama model to use
#' @param context_variant See [context_variant_text()]
#' @param chat_backend Chat client constructor; see [analyse_with_schema()]
#'
#' @returns `sentence_tbl` with two new columns: `nationalism_label` and `nationalism_score`
#' @export
analyse_nationalism_ollama <- function(sentence_tbl,
                                        sentence,
                                        model = "llama3.1",
                                        context_variant = "no_context",
                                        chat_backend = ellmer::chat_ollama) {
  analyse_with_schema(sentence_tbl, sentence, nationalism_schema,
    model = model, context_variant = context_variant, chat_backend = chat_backend
  )
}

#' Run the full Ollama nationalism pipeline: load, tokenise, score, write
#'
#' Thin wrapper around [run_pipeline_with_schema()] using [nationalism_schema].
#'
#' @param input Path to the Aeolus source text; see [load_aeolus()]
#' @param model Name of the Ollama model to use
#' @param output Path to write the scored sentences CSV to
#' @param context_variant See [context_variant_text()]
#' @param chat_backend Chat client constructor; see [analyse_with_schema()]
#'
#' @returns The scored sentence tibble, invisibly
#' @export
run_nationalism_pipeline <- function(input, model, output,
                                      context_variant = "no_context",
                                      chat_backend = ellmer::chat_ollama) {
  run_pipeline_with_schema(input, model, output, nationalism_schema,
    context_variant = context_variant, chat_backend = chat_backend
  )
}
