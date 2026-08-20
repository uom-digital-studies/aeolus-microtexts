# Generic LLM-analysis engine, shared across research questions (RQ1
# sentiment, RQ2 nationalism, RQ3 UGC-resemblance). Each RQ file supplies a
# fixed coding schema (an `rq_schema`) describing only the task/output shape;
# this file supplies the logic that applies any such schema to a tibble of
# sentences, or runs the full load/tokenise/score/write pipeline. Research
# question, model, and context variant are independent factors, each
# supplied separately, so they can be crossed freely (see CONTEXT.md).

#' Construct a research-question coding schema
#'
#' A schema describes only the task and desired output shape for a research
#' question: the `ellmer::type_object()` used for structured LLM output,
#' whose `description` doubles as the task instruction (the single source
#' of truth, not hand-duplicated in a separate prompt string). It does not
#' fix a model or context variant — those are independent factors, supplied
#' separately when the schema is applied.
#'
#' @param name Short RQ identifier (e.g. `"sentiment"`), used to derive the
#'   `<name>_label`/`<name>_score` output column names
#' @param type An `ellmer::type_object()` describing the structured response;
#'   its `@description` is used as the task instruction
#'
#' @returns An `rq_schema` object
#' @export
new_rq_schema <- function(name, type) {
  structure(
    list(
      name = name,
      type = type,
      label_col = paste0(name, "_label"),
      score_col = paste0(name, "_score")
    ),
    class = "rq_schema"
  )
}

#' Context variant framings
#'
#' The three fixed framings prepended to a schema's task instruction (see
#' CONTEXT.md). Crossing these against research questions/models is future
#' sweep work (not yet built); today's callers use the default,
#' `"no_context"`.
#'
#' @param context_variant One of `"no_context"`, `"ulysses_context"`,
#'   `"media_text_context"`
#'
#' @returns A single string (possibly empty)
#' @keywords internal
context_variant_text <- function(context_variant = "no_context") {
  switch(context_variant,
    no_context = "",
    ulysses_context = "This text is from James Joyce's novel Ulysses. ",
    media_text_context = "This text is, or is intended to resemble, social media content. ",
    stop("Unknown context_variant: ", context_variant, call. = FALSE)
  )
}

#' Compose the system prompt for a schema
#'
#' Combines a context variant framing with the task instruction, which is
#' read from `schema$type@description` rather than hand-written per RQ, so
#' the schema stays the single source of truth.
#'
#' @param schema An `rq_schema`, see [new_rq_schema()]
#' @param context_variant See [context_variant_text()]
#'
#' @returns A single string, suitable as a chat system prompt
#' @export
build_system_prompt <- function(schema, context_variant = "no_context") {
  instruction <- S7::prop(schema$type, "description")
  paste0(context_variant_text(context_variant), instruction, ".")
}

#' Analyse each sentence in a tibble against a research-question schema
#'
#' @param sentence_tbl A tibble with one row per sentence (e.g. `aeolus_sentences`)
#' @param sentence Column containing the sentence text to analyse
#' @param schema An `rq_schema`, see [new_rq_schema()]
#' @param model Name of the Ollama model to use
#' @param context_variant See [context_variant_text()]; ignored if
#'   `system_prompt` is supplied directly
#' @param system_prompt Instructions given to the model before each sentence;
#'   defaults to [build_system_prompt()] applied to `schema`/`context_variant`
#' @param chat_backend Chat client constructor with signature
#'   `function(system_prompt, model)`, returning an object with
#'   `$clone()` and `$chat_structured(text, type)`. Defaults to
#'   `ellmer::chat_ollama`; swap in a fake for tests
#'
#' @returns `sentence_tbl` with two new columns, named `<schema$name>_label`
#'   and `<schema$name>_score`
#' @export
analyse_with_schema <- function(sentence_tbl,
                                 sentence,
                                 schema,
                                 model = "llama3.1",
                                 context_variant = "no_context",
                                 system_prompt = build_system_prompt(schema, context_variant),
                                 chat_backend = ellmer::chat_ollama) {
  chat <- chat_backend(system_prompt = system_prompt, model = model)

  sentences <- dplyr::pull(sentence_tbl, {{ sentence }})

  results <- purrr::map(
    sentences,
    function(one_sentence) {
      # Clone so each call starts from a fresh (stateless) conversation
      chat$clone()$chat_structured(one_sentence, type = schema$type)
    },
    .progress = "Analysing sentences"
  )

  sentence_tbl |>
    dplyr::mutate(
      "{schema$label_col}" := purrr::map_chr(results, "label"),
      "{schema$score_col}" := purrr::map_dbl(results, "score")
    )
}

#' Run the full Ollama pipeline for a research-question schema: load,
#' tokenise, score, write
#'
#' The reusable unit called by each RQ's `run_*_pipeline()` wrapper, and, in
#' turn, by the `ollama-*-analysis.R` CLI scripts.
#'
#' @param input Path to the Aeolus source text; see [load_aeolus()]
#' @param model Name of the Ollama model to use
#' @param output Path to write the scored sentences CSV to. Parent
#'   directories are created if needed
#' @param schema An `rq_schema`, see [new_rq_schema()]
#' @param context_variant See [context_variant_text()]
#' @param chat_backend Chat client constructor; see [analyse_with_schema()]
#'
#' @returns The scored sentence tibble, invisibly
#' @export
run_pipeline_with_schema <- function(input, model, output, schema,
                                      context_variant = "no_context",
                                      chat_backend = ellmer::chat_ollama) {
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)

  aeolus <- load_aeolus(input)
  aeolus_sentences <- tokenise_microtexts_by_sentence(aeolus, line, section)
  aeolus_scored_sents <- analyse_with_schema(aeolus_sentences, sentence, schema,
    model = model, context_variant = context_variant, chat_backend = chat_backend
  )

  readr::write_csv(aeolus_scored_sents, output)
  message("Wrote ", nrow(aeolus_scored_sents), " scored sentences to ", output)

  invisible(aeolus_scored_sents)
}
