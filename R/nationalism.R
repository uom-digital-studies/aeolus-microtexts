# RQ2: LLM-based nationalism analysis via Ollama.
#
# Schema only — the shared analyse/run logic lives in R/ollama-engine.R.

#' Coding schema for nationalist-orientation analysis (RQ2)
#'
#' @details Field order is deliberate: `score` is generated after `label`
#'   and may depend on it; see `docs/structured-output.md`.
#'
#' @include ollama-engine.R
#' @export
nationalism_schema <- new_rq_schema(
  name = "nationalism",
  type = ellmer::type_object(
    "Classify the nationalist orientation of this text",
    label = ellmer::type_enum(
      "Nationalist orientation of the text",
      values = c("nationalist", "ambivalent", "anti-nationalist")
    ),
    score = ellmer::type_number(
      "Nationalism index, from -1 (strongly anti-nationalist) to 1 (strongly nationalist)"
    )
  )
)
