#' Preview what is sent to the model for one unit of analysis
#'
#' Returns the system prompt and user turn (which the model reads) and the
#' JSON Schema sent alongside them (which only constrains generation; the
#' model never reads it). See `docs/structured-output.md`. The print method
#' wraps the output for display in an article or presentation.
#'
#' @param schema An `rq_schema`, see [new_rq_schema()]
#' @param context_variant See [context_variant_text()]
#' @param unit An example unit of analysis
#'
#' @returns A list of class `prompt_preview` with `system_prompt`, `user_turn`
#' and `json_schema` (a JSON string). The print method returns its input
#' invisibly.
#'
#' @examples
#' preview <- preview_prompt(sentiment_schema)
#' preview
#'
#' # Wrap the printed output more narrowly, e.g. for a slide
#' print(preview, width = 40)
#'
#' # Preview a different unit of analysis
#' preview_prompt(
#'   sentiment_schema,
#'   unit = "A custom unit of analysis"
#' )$user_turn
#' @export
preview_prompt <- function(schema,
                           context_variant = "no_context",
                           unit = "IN THE HEART OF THE HIBERNIAN METROPOLIS") {
  new_prompt_preview(
    system_prompt = build_system_prompt(schema, context_variant),
    user_turn = build_user_turn(unit),
    json_schema = as.character(jsonlite::toJSON(
      type_to_json_schema(schema$type),
      auto_unbox = TRUE, pretty = TRUE
    )))
}

new_prompt_preview <- function(
    system_prompt = character(),
    user_turn = character(),
    json_schema = character()) {

  stopifnot(rlang::is_character(system_prompt))
  stopifnot(rlang::is_character(user_turn))
  stopifnot(rlang::is_character(json_schema))

  structure(
    .Data = list(
      system_prompt = system_prompt,
      user_turn = user_turn,
      json_schema = json_schema
    ),
    class = "prompt_preview")
}


#' @param x The preview_prompt to be printed
#'
#' @param width Width of the printed preview (text is wrapped so that the
#'  prompt can be shown in a presentation or article).
#' @param ... Unused. Kept for compatibility with `print` signature.
#'
#' @rdname preview_prompt
#' @export
print.prompt_preview <- function(x, width = 60, ...) {
  rule <- strrep("-", width)
  wrapped <- purrr::map(
    x, \(s) wrap_lines(s, width = width)
  )
  cat(
    rule,
    wrap_lines("SYSTEM PROMPT (fixed instructions for experiment)", width),
    rule,
    wrapped$system_prompt,
    rule,
    wrap_lines("USER TURN (datum for analysis)", width),
    rule,
    wrapped$user_turn,
    rule,
    wrap_lines("JSON SCHEMA (constrains output; not seen by model)", width),
    rule,
    wrapped$json_schema,
    sep = "\n"
  )
  invisible(x)
}

wrap_lines <- function(prompt_part, width) {
  # Split prompt into lines
  lines <- stringr::str_split_1(prompt_part, pattern = "\n")
  # Get indentation for each line, as a numeric vector
  indents <- stringr::str_extract(lines, "^\\s*") |> nchar()
  # Now wrap each line:
  wrapped_lines <- purrr::map2_chr(
    lines, indents,
    \(l, i) stringr::str_wrap(l, width = width, indent = i, exdent = i)
    )
  # Flatten into scalar vector
  flat <- stringr::str_flatten(wrapped_lines, collapse = "\n")
  flat
}
