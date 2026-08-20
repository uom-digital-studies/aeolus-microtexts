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

test_that("analyse_with_schema() scores each row and names columns from the schema", {
  sentence_tbl <- tibble::tibble(sentence = c("first sentence", "second sentence"))
  backend <- fake_chat_backend(list(
    list(label = "a", score = 0.5),
    list(label = "b", score = -0.2)
  ))

  result <- analyse_with_schema(sentence_tbl, sentence, test_schema,
    chat_backend = backend
  )

  expect_equal(nrow(result), 2)
  expect_equal(result$widget_label, c("a", "b"))
  expect_equal(result$widget_score, c(0.5, -0.2))
})

test_that("analyse_with_schema() passes model/context variant through to chat_backend", {
  sentence_tbl <- tibble::tibble(sentence = "only sentence")
  seen <- new.env()
  backend <- function(system_prompt, model) {
    seen$system_prompt <- system_prompt
    seen$model <- model
    fake_chat_backend(list(list(label = "a", score = 0)))(system_prompt, model)
  }

  analyse_with_schema(sentence_tbl, sentence, test_schema,
    model = "custom-model", context_variant = "media_text_context", chat_backend = backend
  )

  expect_equal(seen$model, "custom-model")
  expect_true(grepl("social media content", seen$system_prompt, fixed = TRUE))
})

test_that("run_pipeline_with_schema() loads, scores and writes a CSV", {
  input <- withr::local_tempfile()
  writeLines(c("HEADLINE", "Body sentence one."), input)
  output <- withr::local_tempfile(fileext = ".csv")
  backend <- fake_chat_backend(list(list(label = "a", score = 0.1)))

  result <- run_pipeline_with_schema(input, "fake-model", output, test_schema,
    chat_backend = backend
  )

  expect_true(file.exists(output))
  written <- readr::read_csv(output, show_col_types = FALSE)
  expect_equal(written$widget_label, "a")
  expect_equal(result$widget_score, 0.1)
})
