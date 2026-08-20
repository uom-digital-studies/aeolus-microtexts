test_that("nationalism_schema names columns nationalism_label/nationalism_score", {
  expect_equal(nationalism_schema$label_col, "nationalism_label")
  expect_equal(nationalism_schema$score_col, "nationalism_score")
})

test_that("analyse_nationalism_ollama() delegates to the shared engine", {
  sentence_tbl <- tibble::tibble(sentence = c("Erin go bragh.", "A neutral remark."))
  backend <- fake_chat_backend(list(
    list(label = "nationalist", score = 0.7),
    list(label = "ambivalent", score = 0.1)
  ))

  result <- analyse_nationalism_ollama(sentence_tbl, sentence, chat_backend = backend)

  expect_equal(result$nationalism_label, c("nationalist", "ambivalent"))
  expect_equal(result$nationalism_score, c(0.7, 0.1))
})

test_that("run_nationalism_pipeline() writes scored sentences via the shared engine", {
  input <- withr::local_tempfile()
  writeLines(c("HEADLINE", "A patriotic line."), input)
  output <- withr::local_tempfile(fileext = ".csv")
  backend <- fake_chat_backend(list(list(label = "nationalist", score = 0.5)))

  run_nationalism_pipeline(input, "fake-model", output, chat_backend = backend)

  written <- readr::read_csv(output, show_col_types = FALSE)
  expect_equal(written$nationalism_label, "nationalist")
})
