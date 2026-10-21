# Constructor and validator for research-question coding schema

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

  if (!rlang::is_scalar_character(name)) {
    rlang::stop_input_type(name, "a scalar character vector")
  }

  S7::check_is_S7(type, ellmer::TypeObject)

  structure(
    list(
      name = name,
      type = type
    ),
    class = "rq_schema"
  )
}

#' Check that the rq_schema contains the required data.
#'
#' @param rq_schema An RQ schema, as created by `new_rq_schema`
#'
#' @returns The passed rq_schema, if there are no errors.
#' @export
validate_rq_schema <- function(rq_schema) {

  if (!"name" %in% names(rq_schema)) {
    rlang::abort("RQ schema has no name.")
  }

  if (!rlang::is_scalar_character(rq_schema$name)) {
    rlang::abort("RQ schema name is not a scalar character.")
  }

  S7::check_is_S7(rq_schema$type, ellmer::TypeObject)

  if (!rlang::is_scalar_character(S7::prop(rq_schema$type, "description"))) {
    rlang::abort("RQ schema task description is not a scalar character")
  }

  if (!identical(names(S7::prop(rq_schema$type, "properties")), c("label", "score"))) {
    rlang::abort("RQ Schema does not have exactly the properies 'label' and 'score'.")
  }

  label <- S7::prop(rq_schema$type, "properties") |> purrr::pluck("label")
  S7::check_is_S7(label, ellmer::TypeEnum)

  score <- S7::prop(rq_schema$type, "properties") |> purrr::pluck("score")
  S7::check_is_S7(score, ellmer::TypeBasic)

  rq_schema
}
