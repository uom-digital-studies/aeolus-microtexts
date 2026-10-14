test_that("validate_results_schema() returns tbl invisibly when all required columns are present", {
  tbl <- tibble::tibble(
    research_question = "sentiment",
    model = "llama3.2:1b",
    context_variant = "no_context",
    granularity = "sentence",
    include_headlines = TRUE,
    microtext = 1L,
    unit_index = 1L,
    unit_of_analysis = "some text",
    label = "positive",
    score = 0.9
  )

  expect_identical(withVisible(validate_results_schema(tbl)), list(value = tbl, visible = FALSE))
})

test_that("validate_results_schema() errors naming missing columns", {
  tbl <- tibble::tibble(research_question = "sentiment", model = "llama3.2:1b")

  expect_error(validate_results_schema(tbl), "context_variant")
  expect_error(validate_results_schema(tbl), "score")
})

test_that("validate_results_schema() errors on invalid enum values", {
  tbl <- tibble::tibble(
    research_question = "sentiment",
    model = "llama3.2:1b",
    context_variant = "bogus_context",
    granularity = "paragraph",
    include_headlines = TRUE,
    microtext = 1L,
    unit_index = 1L,
    unit_of_analysis = "some text",
    label = "positive",
    score = 0.9
  )

  expect_error(validate_results_schema(tbl), "context_variant")
  expect_error(validate_results_schema(tbl), "granularity")
})

test_that("validate_results_schema() errors when include_headlines isn't logical", {
  tbl <- tibble::tibble(
    research_question = "sentiment",
    model = "llama3.2:1b",
    context_variant = "no_context",
    granularity = "sentence",
    include_headlines = "TRUE",
    microtext = 1L,
    unit_index = 1L,
    unit_of_analysis = "some text",
    label = "positive",
    score = 0.9
  )

  expect_error(validate_results_schema(tbl), "include_headlines")
})
