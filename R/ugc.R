# RQ3: LLM-based user-generated-content (UGC) resemblance analysis via
# Ollama. Scaffolding only — schema not yet finalised, no analysis logic.

#' Coding schema for UGC-resemblance analysis (RQ3)
#'
#' @details Field order is deliberate: `score` is generated after `label`
#'   and may depend on it; see `docs/structured-output.md`.
#'
#' @include ollama-engine.R
#' @export
ugc_schema <- new_rq_schema(
  name = "ugc",
  type = ellmer::type_object(
    "Judge the resemblance of this text to typical user-generated content",
    label = ellmer::type_enum(
      "content type",
      values = c("ugc", "other")
    ),
    score = ellmer::type_number(
      "How typical this text is of ugc, from -1 (utterly atypical) to +1 (utterly typical)."
    )
  )
)
