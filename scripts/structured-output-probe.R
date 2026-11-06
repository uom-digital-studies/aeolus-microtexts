# Probe whether Ollama enforces a JSON schema for one model.
# Runs inside a GPU job submitted by scripts/submit-structured-output-probe.R,
# after ollama_worker_script_lines() has started the server and exported
# OLLAMA_BASE_URL (random port; see that function's docs).
#   Rscript scripts/structured-output-probe.R <model>

model <- commandArgs(trailingOnly = TRUE)[[1]]
base_url <- Sys.getenv("OLLAMA_BASE_URL")
if (base_url == "") stop("OLLAMA_BASE_URL not set", call. = FALSE)

schema <- list(
  type = "object",
  properties = list(
    sentiment = list(type = "string", enum = list("positive", "neutral", "negative")),
    confidence = list(type = "number")
  ),
  required = list("sentiment", "confidence")
)
messages <- list(list(
  role = "user",
  content = "Classify the sentiment of: 'The ferry was late again, typical.'"
))

post <- function(path, body) {
  httr2::request(base_url) |>
    httr2::req_url_path(path) |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_timeout(600) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform() |>
    httr2::resp_body_json()
}

native <- post("/api/chat", list(
  model = model, messages = messages, stream = FALSE,
  format = schema, options = list(temperature = 0)
))
openai <- post("/v1/chat/completions", list(
  model = model, messages = messages, temperature = 0,
  response_format = list(
    type = "json_schema",
    json_schema = list(name = "sentiment", schema = schema, strict = TRUE)
  )
))

responses <- c(
  native$message$content %||% native$error %||% NA_character_,
  openai$choices[[1]]$message$content %||% openai$error$message %||% NA_character_
)
tibble::tibble(
  model = model,
  endpoint = c("/api/chat", "/v1/chat/completions"),
  valid_json = purrr::map_lgl(responses, \(x) !is.na(x) && jsonlite::validate(x)),
  response = responses
) |>
  print(width = Inf)
