test_that("rq_schema_for() returns the matching schema object", {
  expect_identical(rq_schema_for("sentiment"), sentiment_schema)
  expect_identical(rq_schema_for("nationalism"), nationalism_schema)
  expect_identical(rq_schema_for("ugc"), ugc_schema)
})

test_that("rq_schema_for() errors on an unknown research question", {
  expect_error(rq_schema_for("bogus"), "Unknown research_question")
})

test_that("build_analysis_grid() has one row per combination of factors", {
  grid <- build_analysis_grid(
    models = c("llama3.1", "mistral"),
    research_questions = c("sentiment", "nationalism"),
    context_variants = c("no_context", "ulysses_context"),
    granularities = c("sentence", "microtext"),
    include_headlines = c(TRUE, FALSE)
  )

  expect_equal(nrow(grid), 2 * 2 * 2 * 2 * 2)
  expect_equal(
    names(grid),
    c("model", "research_question", "context_variant", "granularity",
      "include_headlines", "output"
    )
  )
})

test_that("build_analysis_grid() produces unique, filesystem-safe output paths", {
  grid <- build_analysis_grid(
    models = c("llama3.2:1b", "llama3.1"),
    research_questions = "sentiment",
    context_variants = "no_context",
    granularities = "sentence",
    include_headlines = TRUE,
    output_dir = "results"
  )

  expect_equal(length(unique(grid$output)), nrow(grid))
  expect_true(all(startsWith(grid$output, "results/")))
  # No characters that are awkward in file names (e.g. the ':' in a model tag)
  expect_false(any(grepl(":", grid$output, fixed = TRUE)))
})

test_that("build_analysis_grid() respects a custom output_dir", {
  grid <- build_analysis_grid(
    models = "llama3.1",
    research_questions = "sentiment",
    context_variants = "no_context",
    granularities = "sentence",
    include_headlines = TRUE,
    output_dir = "custom-dir"
  )

  expect_true(all(startsWith(grid$output, "custom-dir/")))
})

test_that("generate_run_id() embeds the given version and timestamp", {
  when <- as.POSIXct("2026-08-21 15:30:00", tz = "UTC")
  run_id <- generate_run_id(version = "0.1.0.9000", when = when)
  grid <- build_analysis_grid(
    models = "llama3.1",
    research_questions = "sentiment",
    context_variants = "no_context",
    granularities = "sentence",
    include_headlines = TRUE,
    output_dir = file.path("results", run_id)
  )

  expect_equal(run_id, "20260821-153000_v0.1.0.9000")
  expect_true(all(startsWith(grid$output, file.path("results", run_id))))
})
