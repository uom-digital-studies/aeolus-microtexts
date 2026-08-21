test_schema <- new_rq_schema(
  name = "widget",
  type = ellmer::type_object(
    "Widget-ness of a sentence",
    label = ellmer::type_enum("Widget label", values = c("a", "b")),
    score = ellmer::type_number("Widget score")
  )
)

test_that("build_system_prompt() derives the instruction from the schema description", {
  prompt <- build_system_prompt(test_schema)
  expect_true(grepl("Widget-ness of a sentence", prompt, fixed = TRUE))
})

test_that("build_system_prompt() prepends the requested context variant", {
  no_context <- build_system_prompt(test_schema, "no_context")
  ulysses <- build_system_prompt(test_schema, "ulysses_context")

  expect_false(grepl("Ulysses", no_context))
  expect_true(grepl("Ulysses", ulysses))
  expect_true(endsWith(ulysses, "Widget-ness of a sentence."))
})

test_that("build_system_prompt() errors on an unknown context variant", {
  expect_error(build_system_prompt(test_schema, "bogus_context"), "Unknown context_variant")
})

test_that("analyse_with_schema() scores each row and adds the ADR 0003 columns", {
  unit_tbl <- tibble::tibble(unit_of_analysis = c("first unit", "second unit"))
  backend <- fake_chat_backend(list(
    list(label = "a", score = 0.5),
    list(label = "b", score = -0.2)
  ))

  result <- analyse_with_schema(unit_tbl, unit_of_analysis, test_schema,
    chat_backend = backend
  )

  expect_equal(nrow(result), 2)
  expect_equal(result$research_question, c("widget", "widget"))
  expect_equal(result$label, c("a", "b"))
  expect_equal(result$score, c(0.5, -0.2))
})

test_that("analyse_with_schema() passes model/context variant through to chat_backend", {
  unit_tbl <- tibble::tibble(unit_of_analysis = "only unit")
  seen <- new.env()
  backend <- function(system_prompt, model) {
    seen$system_prompt <- system_prompt
    seen$model <- model
    fake_chat_backend(list(list(label = "a", score = 0)))(system_prompt, model)
  }

  analyse_with_schema(unit_tbl, unit_of_analysis, test_schema,
    model = "custom-model", context_variant = "media_text_context", chat_backend = backend
  )

  expect_equal(seen$model, "custom-model")
  expect_true(grepl("social media content", seen$system_prompt, fixed = TRUE))
})

test_that("run_pipeline_with_schema() loads, scores and writes a CSV matching the ADR 0003 schema", {
  output <- withr::local_tempfile(fileext = ".csv")
  aeolus <- load_aeolus("sentence", TRUE)
  backend <- fake_chat_backend(
    rep(list(list(label = "a", score = 0.1)), nrow(aeolus))
  )

  result <- run_pipeline_with_schema("fake-model", output, test_schema,
    granularity = "sentence", include_headlines = TRUE, chat_backend = backend
  )

  expect_true(file.exists(output))
  written <- readr::read_csv(output, show_col_types = FALSE)

  expect_equal(
    names(written),
    c("research_question", "model", "context_variant", "granularity",
      "include_headlines", "microtext", "unit_index", "unit_of_analysis",
      "label", "score"
    )
  )
  expect_equal(unique(written$research_question), "widget")
  expect_equal(unique(written$model), "fake-model")
  expect_equal(unique(written$context_variant), "no_context")
  expect_equal(unique(written$label), "a")
  expect_equal(unique(written$score), 0.1)
  expect_equal(result, written, ignore_attr = TRUE)
})
