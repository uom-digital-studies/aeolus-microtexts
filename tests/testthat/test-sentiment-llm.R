test_that("sentiment_schema names columns sentiment_label/sentiment_score", {
  expect_equal(sentiment_schema$label_col, "sentiment_label")
  expect_equal(sentiment_schema$score_col, "sentiment_score")
})

test_that("analyse_sentiment_ollama() delegates to the shared engine", {
  sentence_tbl <- tibble::tibble(sentence = c("Great day.", "Terrible day."))
  backend <- fake_chat_backend(list(
    list(label = "positive", score = 0.8),
    list(label = "negative", score = -0.9)
  ))

  result <- analyse_sentiment_ollama(sentence_tbl, sentence, chat_backend = backend)

  expect_equal(result$sentiment_label, c("positive", "negative"))
  expect_equal(result$sentiment_score, c(0.8, -0.9))
})

test_that("run_sentiment_pipeline() writes scored sentences via the shared engine", {
  input <- withr::local_tempfile()
  writeLines(c("HEADLINE", "A fine day it was."), input)
  output <- withr::local_tempfile(fileext = ".csv")
  backend <- fake_chat_backend(list(list(label = "neutral", score = 0)))

  run_sentiment_pipeline(input, "fake-model", output, chat_backend = backend)

  written <- readr::read_csv(output, show_col_types = FALSE)
  expect_equal(written$sentiment_label, "neutral")
})
