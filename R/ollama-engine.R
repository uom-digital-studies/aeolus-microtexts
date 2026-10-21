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

#' Ensure a sentence ends with terminal punctuation
#'
#' @param x A character vector
#'
#' @returns `x`, with `"."` appended where it doesn't already end in `.`, `!`
#'   or `?`
#' @keywords internal
end_sentence <- function(x) {
  x <- trimws(x)
  ifelse(grepl("[.!?]$", x), x, paste0(x, "."))
}

#' Render an RQ schema's output fields as the output specification
#'
#' Neither ellmer nor Ollama shows the structured-output schema to the
#' model: it only constrains which tokens can be generated, so field
#' descriptions (e.g. a score's intended range) are otherwise never read.
#' This renders each field, in schema order, as plain text for the system
#' prompt. See ADR 0008 and `docs/structured-output.md`.
#'
#' @param schema An `rq_schema`, see [new_rq_schema()]
#'
#' @returns A single string
#' @export
build_output_spec <- function(schema) {
  fields <- S7::prop(schema$type, "properties")
  sections <- purrr::imap_chr(fields, function(field, name) {
    constraint <- if (S7::S7_inherits(field, ellmer::TypeEnum)) {
      paste0(
        "Allowed values: ",
        paste0("\"", S7::prop(field, "values"), "\"", collapse = ", "),
        "."
      )
    } else {
      paste0("Type: ", S7::prop(field, "type"), ".")
    }
    paste0(
      "### ", name, "\n",
      end_sentence(S7::prop(field, "description")), "\n",
      constraint
    )
  })
  paste0(
    "## Output fields\n\n",
    "Respond with a JSON object containing these fields, in this order.\n\n",
    paste(sections, collapse = "\n\n")
  )
}

#' Compose the system prompt for a schema
#'
#' Context variant + task instruction + output specification (see
#' CONTEXT.md). The task instruction is read from `schema$type@description`
#' and the output specification from its fields (see [build_output_spec()]),
#' so the RQ schema stays the single source of truth.
#'
#' @param schema An `rq_schema`, see [new_rq_schema()]
#' @param context_variant See [context_variant_text()]
#'
#' @returns A single string, suitable as a chat system prompt
#' @export
build_system_prompt <- function(schema, context_variant = "no_context") {
  instruction <- end_sentence(S7::prop(schema$type, "description"))
  paste0(
    context_variant_text(context_variant), instruction, "\n\n",
    build_output_spec(schema)
  )
}

#' Compose the user turn for a unit of analysis
#'
#' @param unit A single unit-of-analysis string, sent unchanged below the
#'   heading
#'
#' @returns A single string
#' @export
build_user_turn <- function(unit) {
  paste0("## The text\n\n", unit)
}

#' Convert an ellmer type to the JSON Schema used for structured output
#'
#' Approximates what ellmer sends as `response_format` for the types used in
#' RQ schemas (object, enum, basic scalars), for display in
#' [preview_prompt()] only. ellmer's own converter is unexported.
#'
#' @param type An ellmer type
#'
#' @returns A list, serialisable with [jsonlite::toJSON()]
#' @keywords internal
type_to_json_schema <- function(type) {
  description <- S7::prop(type, "description")
  if (S7::S7_inherits(type, ellmer::TypeObject)) {
    fields <- S7::prop(type, "properties")
    list(
      type = "object",
      description = description,
      properties = purrr::map(fields, type_to_json_schema),
      required = names(fields),
      additionalProperties = FALSE
    )
  } else if (S7::S7_inherits(type, ellmer::TypeEnum)) {
    list(type = "string", description = description, enum = S7::prop(type, "values"))
  } else {
    list(type = S7::prop(type, "type"), description = description)
  }
}

#' Preview what is sent to the model for one unit of analysis
#'
#' Prints the system prompt and user turn (which the model reads) and the
#' JSON Schema sent alongside them (which only constrains generation; the
#' model never reads it). See `docs/structured-output.md`.
#'
#' @param schema An `rq_schema`, see [new_rq_schema()]
#' @param context_variant See [context_variant_text()]
#' @param unit An example unit of analysis
#'
#' @returns A list with `system_prompt`, `user_turn` and `json_schema`
#'   (a JSON string), invisibly
#' @export
preview_prompt <- function(schema,
                           context_variant = "no_context",
                           unit = "IN THE HEART OF THE HIBERNIAN METROPOLIS") {
  out <- list(
    system_prompt = build_system_prompt(schema, context_variant),
    user_turn = build_user_turn(unit),
    json_schema = as.character(jsonlite::toJSON(
      type_to_json_schema(schema$type),
      auto_unbox = TRUE, pretty = TRUE
    ))
  )
  rule <- strrep("-", 60)
  cat(
    rule, "SYSTEM PROMPT (read by the model)", rule, out$system_prompt, "",
    rule, "USER TURN (read by the model)", rule, out$user_turn, "",
    rule, "JSON SCHEMA (constrains tokens only; not read by the model)", rule,
    out$json_schema,
    sep = "\n"
  )
  invisible(out)
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
#'   `function(system_prompt, model, params)`, returning an object with
#'   `$clone()` and `$chat_structured(text, type)`. Defaults to
#'   `ellmer::chat_ollama`; swap in a fake for tests
#' @param skip_indices Integer vector of row indices to skip during analysis.
#'   If provided, the corresponding rows are excluded from the LLM call and
#'   from the returned tibble entirely. Enables resumption on relaunch when
#'   previous progress is loaded from disk. Defaults to `NULL` (analyze all
#'   rows).
#'
#' @returns The rows of `aeolus_tbl` that were scored (i.e. excluding
#'   `skip_indices`), with three new columns conforming to the ADR 0003
#'   schema: `research_question` (`schema$name`), `label`, and `score`.
#' @export
analyse_with_schema <- function(aeolus_tbl,
                                 unit_of_analysis,
                                 schema,
                                 model = "llama3.1",
                                 context_variant = "no_context",
                                 system_prompt = build_system_prompt(schema, context_variant),
                                 chat_backend = ellmer::chat_ollama,
                                 skip_indices = NULL) {
  # Temperature is 0 so results are completely reproducible. `chat_structured()`
  # has no `temperature` argument (its `...` is prompt content only, strings
  # or <content> objects), so it must be set on the chat client itself.
  chat <- chat_backend(
    system_prompt = system_prompt, model = model,
    params = ellmer::params(temperature = 0)
  )

  units <- dplyr::pull(aeolus_tbl, {{ unit_of_analysis }})

  # Determine which rows to actually score
  row_indices <- seq_len(length(units))
  if (!is.null(skip_indices)) {
    row_indices <- row_indices[!(row_indices %in% skip_indices)]
  }
  units_to_score <- units[row_indices]

  results <- purrr::map(
    units_to_score,
    function(one_unit) {
      # Clone so each call starts from a fresh (stateless) conversation
      chat$clone()$chat_structured(build_user_turn(one_unit), type = schema$type)
    }
  )

  aeolus_tbl[row_indices, ] |>
    dplyr::mutate(
      research_question = schema$name,
      label = purrr::map_chr(results, "label"),
      score = purrr::map_dbl(results, "score")
    )
}

#' Run the full Ollama pipeline for a research-question schema: load,
#' tokenise, score, write
#'
#' Supports resumption: if the output CSV already exists, only new units are
#' scored, and results are merged with the existing output before writing.
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

  # Check if output CSV already exists and can be read
  existing <- NULL
  skip_indices <- NULL

  if (file.exists(output)) {
    tryCatch(
      {
        existing <- readr::read_csv(output, show_col_types = FALSE)

        # Validate that the CSV conforms to the ADR 0003 output schema
        validate_results_schema(existing)

        # Check for incomplete rows (NAs in key columns at the end)
        if (nrow(existing) > 0) {
          last_row_complete <- !is.na(existing$label[nrow(existing)]) &&
                               !is.na(existing$score[nrow(existing)])
          if (!last_row_complete) {
            warning("Existing output CSV has incomplete final row; discarding it.", call. = FALSE)
            # Remove the incomplete row
            existing <- existing[-nrow(existing), ]
          }
        }

        # The existing CSV contains results for the first nrow(existing) rows of
        # aeolus (since we always process aeolus in row order). Skip those rows
        # when scoring by index position.
        rows_already_scored <- nrow(existing)
        if (rows_already_scored > 0) {
          skip_indices <- seq_len(rows_already_scored)
          new_unit_count <- nrow(aeolus) - rows_already_scored
          message("Resuming: skipping ", rows_already_scored, " already-scored units, scoring ",
                  new_unit_count, " new units")
        }
      },
      error = function(e) {
        warning("Failed to validate existing output CSV at ", output, "; ", conditionMessage(e),
                ". Rerunning all units.", call. = FALSE)
        # Reset to NULL so all units are rerun
        skip_indices <<- NULL
        existing <<- NULL
      }
    )
  }

  scored <- analyse_with_schema(aeolus, unit_of_analysis, schema,
    model = model, context_variant = context_variant, chat_backend = chat_backend,
    skip_indices = skip_indices
  )

  result <- scored |>
    dplyr::mutate(model = model, context_variant = context_variant) |>
    dplyr::select(research_question, model, context_variant, granularity,
      include_headlines, microtext, unit_index, unit_of_analysis, label, score)

  # If we had existing progress, merge the new results with the old ones
  if (!is.null(existing)) {
    result <- dplyr::bind_rows(existing, result)
  }

  readr::write_csv(result, output)
  message("Wrote ", nrow(result), " scored units to ", output)

  invisible(result)
}
