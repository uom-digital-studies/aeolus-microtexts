# Fake chat backend, standing in for ellmer::chat_ollama() in tests.
#
# Structurally mimics the bit of the ellmer chat client interface that
# analyse_with_schema() relies on: `$clone()` (stateless clone per call) and
# `$chat_structured(text, type)` (returns a canned response, one per unit of
# analysis). This lets us exercise the pipeline logic without ever
# contacting a real Ollama server.

#' @param responses A list of `list(label = , score = )` responses, one per
#'   expected `chat_structured()` call, returned in order.
fake_chat_backend <- function(responses) {
  call_count <- 0L

  client <- list(
    chat_structured = function(text, type) {
      call_count <<- call_count + 1L
      if (call_count > length(responses)) {
        stop("fake_chat_backend: more calls than canned responses", call. = FALSE)
      }
      responses[[call_count]]
    }
  )
  client$clone <- function() client

  # Matches ellmer::chat_ollama(system_prompt =, model =, params =)
  function(system_prompt, model, params = NULL) client
}
