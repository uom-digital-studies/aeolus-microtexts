fixture_results <- function() {
  tibble::tibble(
    research_question = "sentiment",
    model = rep(c("llama3.2:3b", "llama3.3:70b"), each = 2),
    context_variant = rep(c("no_context", "ulysses_context"), 2),
    granularity = c("microtext", "sentence", "microtext", "sentence"),
    include_headlines = c(TRUE, FALSE, FALSE, TRUE),
    microtext = c(1L, 1L, 2L, 2L),
    unit_index = c(1L, 1L, 1L, 2L),
    unit_of_analysis = c("A headline. Body text.", "Body text.", "Second body.", "Another sentence."),
    label = c("positive", "negative", "neutral", "positive"),
    score = c(0.5, -0.25, 0, 1)
  )
}

fixture_models <- function() {
  tibble::tibble(
    model = c("llama3.2:3b", "llama3.3:70b"),
    digest = c("a80c4f17acd5", "a6eb4748fd29")
  )
}

# Writes a run directory under root; set results/models to NULL to omit a file
make_run <- function(root, run_id,
                     results = fixture_results(), models = fixture_models()) {
  dir <- file.path(root, run_id)
  dir.create(dir, recursive = TRUE)
  if (!is.null(results)) readr::write_csv(results, file.path(dir, "results.csv"))
  if (!is.null(models)) readr::write_csv(models, file.path(dir, "models.csv"))
  invisible(dir)
}

new_root <- function(env = parent.frame()) {
  withr::local_tempdir(.local_envir = env)
}

test_that("list_runs() returns the expected columns and types", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0")

  runs <- list_runs(root)

  expect_named(runs, c("run_id", "date", "version", "models"))
  expect_type(runs$run_id, "character")
  expect_s3_class(runs$date, "POSIXct")
  expect_type(runs$version, "character")
  expect_type(runs$models, "list")
  expect_type(runs$models[[1]], "character")
  expect_setequal(runs$models[[1]], fixture_models()$model)
})

test_that("list_runs() parses date and version from run_id", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0")

  runs <- list_runs(root)

  expect_equal(format(runs$date, "%Y%m%d-%H%M%S"), "20260101-120000")
  expect_equal(runs$version, "0.1.0")
})

test_that("list_runs() models column unnests", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0")

  unnested <- tidyr::unnest(list_runs(root), models)

  expect_setequal(unnested$models, fixture_models()$model)
})

test_that("list_runs() sorts runs newest first", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0")
  make_run(root, "20260301-090000_v0.2.0")
  make_run(root, "20260201-000000_v0.1.5")

  expect_equal(
    list_runs(root)$run_id,
    c("20260301-090000_v0.2.0", "20260201-000000_v0.1.5", "20260101-120000_v0.1.0")
  )
})

test_that("list_runs() errors when the root contains no runs", {
  root <- new_root()

  expect_error(list_runs(root), "list_runs")
})

test_that("list_runs() errors on an empty run directory", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0")
  dir.create(file.path(root, "20260301-090000_v0.2.0"))

  expect_error(list_runs(root), "20260301-090000_v0.2.0")
})

test_that("list_runs() errors when models.csv is missing", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0", models = NULL)

  expect_error(list_runs(root), "models.csv")
})

test_that("list_runs() errors when results.csv is missing", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0", results = NULL)

  expect_error(list_runs(root), "results.csv")
})

test_that("list_runs() errors when a directory name is not a run_id", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0")
  make_run(root, "not-a-run")

  expect_error(list_runs(root), "not-a-run")
})

test_that("list_runs() ignores extra files in run dirs and stray top-level files", {
  root <- new_root()
  dir <- make_run(root, "20260101-120000_v0.1.0")
  writeLines("notes", file.path(dir, "notes.txt"))
  writeLines("readme", file.path(root, "README.md"))

  expect_equal(list_runs(root)$run_id, "20260101-120000_v0.1.0")
})

test_that("read_run() returns the results with ADR 0003 column types", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0")

  res <- read_run("20260101-120000_v0.1.0", dir = root)

  expect_equal(nrow(res), nrow(fixture_results()))
  expect_type(res$research_question, "character")
  expect_type(res$model, "character")
  expect_type(res$context_variant, "character")
  expect_type(res$granularity, "character")
  expect_type(res$include_headlines, "logical")
  expect_type(res$microtext, "integer")
  expect_type(res$unit_index, "integer")
  expect_type(res$unit_of_analysis, "character")
  expect_type(res$label, "character")
  expect_type(res$score, "double")
})

test_that("read_run() returns its result visibly", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0")

  expect_true(withVisible(read_run("20260101-120000_v0.1.0", dir = root))$visible)
})

test_that("read_run() does not add a run_id column", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0")

  res <- read_run("20260101-120000_v0.1.0", dir = root)

  expect_false("run_id" %in% names(res))
  expect_named(res, names(fixture_results()))
})

test_that("read_run() errors with a hint when run_id is missing", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0")

  expect_error(read_run(dir = root), "list_runs")
})

test_that("read_run() errors with a hint for an unknown run_id", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0")

  expect_error(read_run("20990101-000000_v9.9.9", dir = root), "list_runs")
})

test_that("read_run() matches run_id exactly, not by prefix", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0")

  expect_error(read_run("20260101-120000", dir = root), "list_runs")
})

test_that("read_run() errors on schema-invalid results", {
  root <- new_root()
  results <- fixture_results()
  results$granularity[1] <- "paragraph"
  make_run(root, "20260101-120000_v0.1.0", results = results)

  expect_error(read_run("20260101-120000_v0.1.0", dir = root), "granularity")
})

test_that("read_run() errors on an unparseable column", {
  root <- new_root()
  results <- fixture_results()
  results$score <- "high"
  make_run(root, "20260101-120000_v0.1.0", results = results)

  expect_error(read_run("20260101-120000_v0.1.0", dir = root))
})

test_that("read_run_metadata() returns models.csv as a tibble", {
  root <- new_root()
  make_run(root, "20260101-120000_v0.1.0")

  meta <- read_run_metadata("20260101-120000_v0.1.0", dir = root)

  expect_equal(meta, fixture_models())
})

test_that("read_run_metadata() errors on wrong columns", {
  root <- new_root()
  models <- tibble::tibble(model = "llama3.2:3b", sha = "a80c4f17acd5")
  make_run(root, "20260101-120000_v0.1.0", models = models)

  expect_error(read_run_metadata("20260101-120000_v0.1.0", dir = root), "digest")
})

test_that("read_run_metadata() errors on duplicate models", {
  root <- new_root()
  models <- tibble::tibble(model = c("llama3.2:3b", "llama3.2:3b"),
                           digest = c("a80c4f17acd5", "b90d5a28ce6"))
  make_run(root, "20260101-120000_v0.1.0", models = models)

  expect_error(read_run_metadata("20260101-120000_v0.1.0", dir = root), "llama3.2:3b")
})

test_that("read_run_metadata() errors on an empty digest", {
  root <- new_root()
  models <- tibble::tibble(model = c("llama3.2:3b", "llama3.3:70b"),
                           digest = c("", "a6eb4748fd29"))
  make_run(root, "20260101-120000_v0.1.0", models = models)

  expect_error(read_run_metadata("20260101-120000_v0.1.0", dir = root), "digest")
})

# Real data: runs against the shipped inst/extdata/results/ directory

test_that("promoted runs are listed", {
  runs <- list_runs()

  expect_gt(nrow(runs), 0)
})

test_that("every promoted run reads consistently", {
  runs <- list_runs()

  purrr::walk(seq_len(nrow(runs)), function(i) {
    run <- runs[i, ]
    res <- read_run(run$run_id)
    meta <- read_run_metadata(run$run_id)

    expect_setequal(unique(res$model), meta$model)
    expect_setequal(unique(res$model), run$models[[1]])
    expect_equal(format(run$date, "%Y%m%d-%H%M%S"), substr(run$run_id, 1, 15))
    expect_equal(run$version, sub("^.*_v", "", run$run_id))
  })
})
