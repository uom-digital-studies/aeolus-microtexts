test_that("parse_ollama_host() extracts OLLAMA_HOST from run_ollama_server output", {
  lines <- c(
    "Start of output",
    "OLLAMA_HOST=spartan-gpgpu126:34267 ollama serve",
    "Loading model..."
  )
  result <- parse_ollama_host(lines)
  expect_equal(result, "spartan-gpgpu126:34267")
})

test_that("parse_ollama_host() returns NA when OLLAMA_HOST is absent", {
  lines <- c(
    "Start of output",
    "Loading model...",
    "Ready to go"
  )
  result <- parse_ollama_host(lines)
  expect_true(is.na(result))
})

test_that("parse_ollama_host() strips TTY control codes and finds OLLAMA_HOST", {
  # Simulating TTY progress bar junk (control sequences + newlines)
  lines <- c(
    "Starting ollama...",
    "\r\033[K\033[?25l\033[2K  Loading  \033[?25h",
    "OLLAMA_HOST=myhost:8080 ollama serve",
    "Ready"
  )
  result <- parse_ollama_host(lines)
  expect_equal(result, "myhost:8080")
})

test_that("parse_ollama_host() handles empty input", {
  result <- parse_ollama_host(character(0))
  expect_true(is.na(result))
})

test_that("parse_ollama_list() converts ollama list output to tibble(model, digest)", {
  # Real `ollama list` output: columns padded with runs of spaces (Go's
  # text/tabwriter), not literal tabs, with trailing padding on each line
  lines <- c(
    "NAME              ID              SIZE      MODIFIED        ",
    "llama3.1:latest   44136d36a686    4.7 GB    5 minutes ago    ",
    "mistral:latest    26d3fcbef1ba    26 GB     2 hours ago      "
  )
  result <- parse_ollama_list(lines)
  expect_equal(nrow(result), 2)
  expect_equal(colnames(result), c("model", "digest"))
  expect_equal(result$model, c("llama3.1:latest", "mistral:latest"))
  expect_equal(result$digest, c("44136d36a686", "26d3fcbef1ba"))
})

test_that("parse_ollama_list() handles empty list", {
  lines <- c(
    "NAME   ID              SIZE      MODIFIED        "
  )
  result <- parse_ollama_list(lines)
  expect_equal(nrow(result), 0)
  expect_equal(colnames(result), c("model", "digest"))
})

test_that("parse_ollama_list() truncates digest to 12 hex chars", {
  lines <- c(
    "NAME              ID                                SIZE      MODIFIED        ",
    "testmodel:latest  44136d36a6868a2c1ce0f9b13eef8c9    4.7 GB    5 minutes ago    "
  )
  result <- parse_ollama_list(lines)
  expect_equal(result$digest[1], "44136d36a686")
})

test_that("parse_ollama_list() ignores lines with fewer than expected columns", {
  lines <- c(
    "NAME              ID              SIZE      MODIFIED        ",
    "llama3.1:latest   44136d36a686    4.7 GB    5 minutes ago    ",
    "malformed line",
    "mistral:latest    26d3fcbef1ba    26 GB     2 hours ago      "
  )
  result <- parse_ollama_list(lines)
  expect_equal(nrow(result), 2)
  expect_equal(result$model, c("llama3.1:latest", "mistral:latest"))
})

# Note: start_ollama_server() test skipped as it requires processx to launch
# a real process; pull_models() tests verify the function's behavior via mocking

test_that("pull_models() pulls each model and returns tibble with digests", {
  pulled_models <- c("llama3.1:latest", "mistral:latest")
  pulled_digests <- c("44136d36a686", "26d3fcbef1ba")

  # Mock start_server: returns a fake process handle
  fake_start_server <- function(model_store, log) {
    list(
      process = list(kill = function() invisible(NULL)),
      host = "testhost:9999"
    )
  }

  # Mock run: simulates ollama pull succeeding, then ollama list returning both models
  call_count <- 0
  fake_run <- function(cmd, args, error_on_status = FALSE, env = character(), ...) {
    call_count <<- call_count + 1
    if (cmd == "ollama" && args[1] == "pull") {
      # Simulate pull success
      list(status = 0, stdout = "")
    } else if (cmd == "ollama" && args[1] == "list") {
      # Return both models in list (realistic space-padded columns)
      list(
        status = 0,
        stdout = paste(
          "NAME               ID                                SIZE      MODIFIED        ",
          "llama3.1:latest    44136d36a6868a2c1ce0f9b13eef8c9    4.7 GB    5 minutes ago    ",
          "mistral:latest     26d3fcbef1ba8a2c1ce0f9b13eef8c9    26 GB     2 hours ago      ",
          sep = "\n"
        )
      )
    }
  }

  result <- pull_models(
    models = pulled_models,
    model_store = "/fake/models",
    start_server = fake_start_server,
    run = fake_run
  )

  expect_equal(nrow(result), 2)
  expect_equal(colnames(result), c("model", "digest"))
  expect_equal(result$model, pulled_models)
  expect_equal(result$digest, pulled_digests)
})

test_that("pull_models() errors if a pulled model doesn't appear in ollama list", {
  fake_start_server <- function(model_store, log) {
    list(
      process = list(kill = function() invisible(NULL)),
      host = "testhost:9999"
    )
  }

  # Mock run: pull succeeds, but list omits one model
  fake_run <- function(cmd, args, error_on_status = FALSE, env = character(), ...) {
    if (cmd == "ollama" && args[1] == "pull") {
      list(status = 0, stdout = "")
    } else if (cmd == "ollama" && args[1] == "list") {
      # Only return llama3.1, not mistral
      list(
        status = 0,
        stdout = paste(
          "NAME               ID              SIZE      MODIFIED        ",
          "llama3.1:latest    44136d36a686    4.7 GB    5 minutes ago    ",
          sep = "\n"
        )
      )
    }
  }

  expect_error(
    pull_models(
      models = c("llama3.1:latest", "mistral:latest"),
      model_store = "/fake/models",
      start_server = fake_start_server,
      run = fake_run
    ),
    "mistral:latest"
  )
})

test_that("pull_models() errors if a pull command fails", {
  fake_start_server <- function(model_store, log) {
    list(
      process = list(kill = function() invisible(NULL)),
      host = "testhost:9999"
    )
  }

  # Mock run: pull fails
  fake_run <- function(cmd, args, error_on_status = FALSE, env = character(), ...) {
    if (cmd == "ollama" && args[1] == "pull") {
      if (error_on_status) {
        stop("Non-zero exit code")
      } else {
        list(status = 1, stdout = "Error: failed to pull")
      }
    }
  }

  expect_error(
    pull_models(
      models = c("llama3.1:latest"),
      model_store = "/fake/models",
      start_server = fake_start_server,
      run = fake_run
    )
  )
})

test_that("pull_models() kills the server on error via on.exit", {
  server_killed <- FALSE
  fake_start_server <- function(model_store, log) {
    list(
      process = list(kill = function() {
        server_killed <<- TRUE
      }),
      host = "testhost:9999"
    )
  }

  # Mock run: pull fails
  fake_run <- function(cmd, args, error_on_status = FALSE, env = character(), ...) {
    if (cmd == "ollama" && args[1] == "pull") {
      stop("Pull failed")
    }
  }

  expect_error(
    pull_models(
      models = c("llama3.1:latest"),
      model_store = "/fake/models",
      start_server = fake_start_server,
      run = fake_run
    )
  )

  expect_true(server_killed)
})

test_that("write_models_manifest() writes models CSV to output_dir", {
  temp_dir <- tempfile()
  dir.create(temp_dir)
  on.exit(unlink(temp_dir, recursive = TRUE))

  pulled <- tibble::tibble(
    model = c("llama3.1:latest", "mistral:latest"),
    digest = c("44136d36a686", "26d3fcbef1ba")
  )

  result <- write_models_manifest(pulled, temp_dir)

  expect_true(file.exists(result))
  expect_equal(result, file.path(temp_dir, "models.csv"))

  written <- readr::read_csv(result, show_col_types = FALSE)
  expect_equal(written$model, c("llama3.1:latest", "mistral:latest"))
  expect_equal(written$digest, c("44136d36a686", "26d3fcbef1ba"))
})

test_that("build_pull_targets() creates models_pulled and models_manifest targets", {
  targets::tar_dir({
    targets::tar_script({
      list(
        build_pull_targets(
          models = c("llama3.1:latest", "mistral:latest"),
          results_dir = "results"
        )
      )
    }, ask = FALSE)

    manifest <- targets::tar_manifest(callr_function = NULL)

    expect_setequal(
      manifest$name,
      c("models_pulled", "models_manifest")
    )
  })
})

test_that("build_pull_targets() sets deployment to main", {
  targets_list <- build_pull_targets(
    models = c("llama3.1:latest"),
    results_dir = "results"
  )

  # Check deployment attribute on both targets
  expect_equal(targets_list[[1]]$settings$deployment, "main")
  expect_equal(targets_list[[2]]$settings$deployment, "main")
})

test_that("build_pull_targets() embeds models as literal in command (for smart cue)", {
  targets::tar_dir({
    targets::tar_script({
      list(
        build_pull_targets(
          models = c("llama3.1:latest", "mistral:latest"),
          results_dir = "results"
        )
      )
    }, ask = FALSE)

    manifest <- targets::tar_manifest(
      fields = tidyselect::any_of(c("name", "command")),
      callr_function = NULL
    )

    pulled_row <- manifest[manifest$name == "models_pulled", ]
    # Models should be embedded as !! (quosure) so smart cue reruns only when list changes
    expect_true(grepl("pull_models", pulled_row$command, fixed = TRUE))
    expect_true(grepl("llama3.1:latest", pulled_row$command, fixed = TRUE))
  })
})

test_that("build_pull_targets() configures models_manifest with format = file", {
  targets_list <- build_pull_targets(
    models = c("llama3.1:latest"),
    results_dir = "results"
  )

  # Second target is models_manifest
  manifest_target <- targets_list[[2]]
  expect_equal(manifest_target$settings$format, "file")
})

test_that("build_pull_targets() nests models.csv under results_dir/run_id", {
  targets::tar_dir({
    targets::tar_script({
      list(
        build_pull_targets(
          models = c("llama3.1:latest"),
          results_dir = "test-results"
        )
      )
    }, ask = FALSE)

    manifest <- targets::tar_manifest(
      fields = tidyselect::any_of(c("name", "command")),
      callr_function = NULL
    )

    manifest_row <- manifest[manifest$name == "models_manifest", ]
    expect_true(grepl("test-results", manifest_row$command, fixed = TRUE))
  })
})
