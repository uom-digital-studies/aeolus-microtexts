test_that("sentiment_schema is named sentiment", {
  expect_equal(sentiment_schema$name, "sentiment")
})

test_that("analyse_sentiment_ollama() delegates to the shared engine", {
  unit_tbl <- tibble::tibble(unit_of_analysis = c("Great day.", "Terrible day."))
  backend <- fake_chat_backend(list(
    list(label = "positive", score = 0.8),
    list(label = "negative", score = -0.9)
  ))

  result <- analyse_sentiment_ollama(unit_tbl, unit_of_analysis, chat_backend = backend)

  expect_equal(result$research_question, c("sentiment", "sentiment"))
  expect_equal(result$label, c("positive", "negative"))
  expect_equal(result$score, c(0.8, -0.9))
})

test_that("run_sentiment_pipeline() writes scored sentences via the shared engine", {
  output <- withr::local_tempfile(fileext = ".csv")
  aeolus <- load_aeolus("sentence", TRUE)
  backend <- fake_chat_backend(
    rep(list(list(label = "neutral", score = 0)), nrow(aeolus))
  )

  run_sentiment_pipeline("fake-model", output, chat_backend = backend)

  written <- readr::read_csv(output, show_col_types = FALSE)
  expect_equal(unique(written$label), "neutral")
  expect_equal(unique(written$research_question), "sentiment")
})
