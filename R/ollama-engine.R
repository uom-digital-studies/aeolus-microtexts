# Generic LLM-analysis engine, shared across research questions (RQ1
# sentiment, RQ2 nationalism, RQ3 UGC-resemblance). Each RQ file supplies a
# fixed coding schema (an `rq_schema`) describing only the task/output shape;
# this file supplies the logic that applies any such schema to a tibble of
# units of analysis, or runs the full load/tokenise/score/write pipeline.
# Research question, model, and context variant are independent factors,
# each supplied separately, so they can be crossed freely (see CONTEXT.md).

#' Construct a research-question coding schema
#'
#' A schema describes only the task and desired output shape for a research
#' question: the `ellmer::type_object()` used for structured LLM output,
#' whose `description` doubles as the task instruction (the single source
#' of truth, not hand-duplicated in a separate prompt string). It does not
#' fix a model or context variant — those are independent factors, supplied
#' separately when the schema is applied.
#'
#' @param name Short RQ identifier (e.g. `"sentiment"`), recorded verbatim in
#'   the `research_question` output column (see [analyse_with_schema()])
#' @param type An `ellmer::type_object()` describing the structured response;
#'   its `@description` is used as the task instruction
#'
#' @returns An `rq_schema` object
#' @export
new_rq_schema <- function(name, type) {
  structure(
    list(
      name = name,
      type = type
    ),
    class = "rq_schema"
  )
}

#' Context variant framings
#'
#' The three fixed framings prepended to a schema's task instruction (see
#' CONTEXT.md). These are crossed against research questions and models
#' in [build_analysis_grid()].
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

#' Analyse each unit of analysis in a tibble against a research-question schema
#'
#' @param aeolus_tbl A tibble with one row per unit of analysis (e.g. the
#'   output of [load_aeolus()])
#' @param unit_of_analysis Column containing the unit-of-analysis text to
#'   analyse
#' @param schema An `rq_schema`, see [new_rq_schema()]
#' @param model Name of the Ollama model to use
#' @param context_variant See [context_variant_text()]; ignored if
#'   `system_prompt` is supplied directly
#' @param system_prompt Instructions given to the model before each unit of
#'   analysis; defaults to [build_system_prompt()] applied to
#'   `schema`/`context_variant`
#' @param chat_backend Chat client constructor with signature
#'   `function(system_prompt, model)`, returning an object with
#'   `$clone()` and `$chat_structured(text, type)`. Defaults to
#'   `ellmer::chat_ollama`; swap in a fake for tests
#'
#' @returns `aeolus_tbl` with three new columns conforming to the ADR 0003
#'   schema: `research_question` (`schema$name`), `label`, and `score`
#' @export
analyse_with_schema <- function(aeolus_tbl,
                                 unit_of_analysis,
                                 schema,
                                 model = "llama3.1",
                                 context_variant = "no_context",
                                 system_prompt = build_system_prompt(schema, context_variant),
                                 chat_backend = ellmer::chat_ollama) {
  chat <- chat_backend(system_prompt = system_prompt, model = model)

  units <- dplyr::pull(aeolus_tbl, {{ unit_of_analysis }})

  results <- purrr::map(
    units,
    function(one_unit) {
      # Clone so each call starts from a fresh (stateless) conversation
      # Temperature is 0 so results are completely reproducible
      chat$clone()$chat_structured(one_unit, type = schema$type, temperature = 0)
    }
  )

  aeolus_tbl |>
    dplyr::mutate(
      research_question = schema$name,
      label = purrr::map_chr(results, "label"),
      score = purrr::map_dbl(results, "score")
    )
}

#' Run the full Ollama pipeline for a research-question schema: load,
#' tokenise, score, write
#'
#' The reusable unit called by each RQ's `run_*_pipeline()` wrapper, and, in
#' turn, `_targets.R`.
#'
#' @param model Name of the Ollama model to use
#' @param output Path to write the scored results CSV to. Parent
#'   directories are created if needed
#' @param schema An `rq_schema`, see [new_rq_schema()]
#' @param granularity Unit of analysis for this run, either `"sentence"` or
#'   `"microtext"`; see [load_aeolus()]
#' @param include_headlines Logical. Whether to include headlines in the
#'   analysed text; see [load_aeolus()]
#' @param context_variant See [context_variant_text()]
#' @param chat_backend Chat client constructor; see [analyse_with_schema()]
#'
#' @returns The scored results tibble (matching the ADR 0003 CSV schema),
#'   invisibly
#' @export
run_pipeline_with_schema <- function(model, output, schema,
                                      granularity = "sentence",
                                      include_headlines = TRUE,
                                      context_variant = "no_context",
                                      chat_backend = ellmer::chat_ollama) {
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)

  aeolus <- load_aeolus(granularity, include_headlines)
  scored <- analyse_with_schema(aeolus, unit_of_analysis, schema,
    model = model, context_variant = context_variant, chat_backend = chat_backend
  )

  result <- scored |>
    dplyr::mutate(model = model, context_variant = context_variant) |>
    dplyr::select(research_question, model, context_variant, granularity,
      include_headlines, microtext, unit_index, unit_of_analysis, label, score
    )

  readr::write_csv(result, output)
  message("Wrote ", nrow(result), " scored units to ", output)

  invisible(result)
}
