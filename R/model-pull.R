# Model pull orchestration for the dispatcher (ADR 0007). The dispatcher
# pulls all models once at pipeline start; workers check for model existence
# via `ollama show` rather than attempting to pull. This centralizes network
# and storage load, avoids the race condition of multiple workers pulling
# simultaneously, and ensures workers never fail due to pull timeouts.

#' Extract OLLAMA_HOST from run_ollama_server output
#'
#' Pure function: parses `run_ollama_server` stdout to extract the `host:port`
#' string that the server binds to, since Spartan's version uses a random port.
#' Handles TTY control codes that might make `grep` treat the output as binary.
#'
#' @param lines Character vector of output lines (typically from a log file)
#'
#' @returns A single string `"host:port"`, or `NA` if not found
#' @keywords internal
parse_ollama_host <- function(lines) {
  # Extract OLLAMA_HOST=<host:port> from output, stripping any surrounding junk
  matches <- grep("OLLAMA_HOST=\\S+", lines, value = TRUE)
  if (length(matches) == 0) {
    return(NA_character_)
  }
  # Take first match, extract the host:port value after OLLAMA_HOST=
  host_str <- sub(".*OLLAMA_HOST=(\\S+).*", "\\1", matches[1])
  host_str
}

#' Parse ollama list output into a model manifest
#'
#' Pure function: converts `ollama list` stdout (tab-separated columns) into a
#' tibble mapping model identifiers to their content-address digests.
#'
#' @param lines Character vector of output lines from `ollama list`
#'
#' @returns A tibble with columns `model` and `digest` (ID truncated to 12 hex)
#' @keywords internal
parse_ollama_list <- function(lines) {
  # Expected format: tab-separated columns, first line is header
  # NAME              ID                                SIZE    MODIFIED
  # llama3.1:latest   44136d36a6868a2c1ce0f9b13eef8c9  4.7 GB  5 minutes ago

  if (length(lines) <= 1) {
    return(tibble::tibble(model = character(), digest = character()))
  }

  data_lines <- lines[-1]  # Skip header

  # Split on tabs and filter to lines with at least 2 columns
  parsed <- strsplit(data_lines, "\\t")
  valid_rows <- which(vapply(parsed, length, integer(1)) >= 2)

  if (length(valid_rows) == 0) {
    return(tibble::tibble(model = character(), digest = character()))
  }

  # Trim whitespace from model names
  models <- stringr::str_trim(vapply(parsed[valid_rows], function(x) x[1], character(1)))
  # ID column is second; trim whitespace then truncate to 12 hex chars
  digests <- substr(stringr::str_trim(vapply(parsed[valid_rows], function(x) x[2], character(1))), 1, 12)

  tibble::tibble(model = models, digest = digests)
}

#' Start an Ollama server with the given model store
#'
#' Launches `run_ollama_server` as a background process, waits for it to bind
#' and report its `OLLAMA_HOST=` to the log file, then verifies readiness via
#' `ollama list`.
#'
#' @param model_store Path to the model store directory
#' @param log Path to write the server's stdout/stderr log to
#'
#' @returns A list with:
#'   - `process`: A `processx::process` object with a `kill()` method
#'   - `host`: A string `"host:port"` the server is bound to
#' @keywords internal
start_ollama_server <- function(model_store, log) {
  # Set up environment with the model store directory
  env <- Sys.getenv()  # Copy current environment
  env[["OLLAMA_MODELS"]] <- model_store

  # Start the server process, redirecting output to log
  process <- processx::process$new(
    "run_ollama_server",
    stdout = log,
    stderr = "2>&1",
    env = c(env)
  )

  # Poll the log file for OLLAMA_HOST= up to 60 seconds
  host <- NA_character_
  start_time <- Sys.time()
  max_wait <- 60

  while (is.na(host) && as.numeric(Sys.time() - start_time) < max_wait) {
    # Read whatever's been written to the log so far
    if (file.exists(log)) {
      lines <- tryCatch(
        readLines(log),
        error = function(e) character(0)
      )
      host <- parse_ollama_host(lines)
    }
    if (is.na(host)) {
      Sys.sleep(1)
    }
  }

  if (is.na(host)) {
    process$kill()
    stop(
      "Ollama server did not report OLLAMA_HOST= within ", max_wait, " seconds; ",
      "check ", log, " for errors",
      call. = FALSE
    )
  }

  # Verify readiness by checking that `ollama list` responds
  start_time <- Sys.time()
  ready <- FALSE

  while (!ready && as.numeric(Sys.time() - start_time) < max_wait) {
    tryCatch(
      {
        processx::run(
          "ollama",
          "list",
          env = c(Sys.getenv(), OLLAMA_HOST = host),
          error_on_status = TRUE
        )
        ready <- TRUE
      },
      error = function(e) {
        # Not ready yet, will retry
      }
    )
    if (!ready) {
      Sys.sleep(1)
    }
  }

  if (!ready) {
    process$kill()
    stop(
      "Ollama server at ", host, " did not become ready within ", max_wait,
      " seconds",
      call. = FALSE
    )
  }

  list(process = process, host = host)
}

#' Pull all models into the model store via the dispatcher
#'
#' Starts an Ollama server, pulls each model in sequence, verifies all models
#' are in the store via `ollama list`, and returns their digests. Errors if
#' any pull fails or if a pulled model doesn't appear in the final list.
#'
#' Arguments `start_server` and `run` are injectable for testing (same pattern
#' as `analyse_with_schema`'s `chat_backend` parameter).
#'
#' @param models Character vector of Ollama model identifiers to pull
#' @param model_store Path to the model store directory (default:
#'   [model_store_dir()])
#' @param start_server Function with signature `function(model_store, log)`
#'   returning `list(process, host)`; defaults to [start_ollama_server()]
#' @param run Function with signature `function(cmd, args, ..., error_on_status, env)`;
#'   defaults to [processx::run()]
#'
#' @returns A tibble with columns `model` and `digest`, one row per input model
#' @export
pull_models <- function(models,
                        model_store = model_store_dir(),
                        start_server = start_ollama_server,
                        run = processx::run) {
  # Create a temporary log file for the server startup
  log <- tempfile(fileext = ".log")

  # Start the server and clean up on exit (success or error)
  server_result <- start_server(model_store, log)
  on.exit({
    server_result$process$kill()
    unlink(log)
  })

  # Pull each model
  env <- c(Sys.getenv(), OLLAMA_HOST = server_result$host)

  for (model in models) {
    run(
      "ollama",
      c("pull", model),
      error_on_status = TRUE,
      env = env
    )
  }

  # Verify all models are in the store
  list_result <- run(
    "ollama",
    "list",
    env = env
  )

  pulled_manifest <- parse_ollama_list(strsplit(list_result$stdout, "\n")[[1]])

  # Check that every input model is in the manifest
  missing <- setdiff(models, pulled_manifest$model)
  if (length(missing) > 0) {
    stop(
      "After pulling, the following model(s) are missing from ollama list: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  # Return only the models we pulled, in the order they were requested
  pulled_manifest |>
    dplyr::filter(model %in% models) |>
    dplyr::mutate(model = factor(model, levels = models)) |>
    dplyr::arrange(model) |>
    dplyr::mutate(model = as.character(model))
}

#' Write a model manifest to the results directory
#'
#' Writes the output of [pull_models()] to a CSV file for traceability.
#'
#' @param pulled A tibble as returned by [pull_models()], with columns
#'   `model` and `digest`
#' @param output_dir Directory to write the manifest to (created if needed)
#'
#' @returns The path to the written CSV file
#' @export
write_models_manifest <- function(pulled, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  output_path <- file.path(output_dir, "models.csv")
  readr::write_csv(pulled, output_path)
  output_path
}
