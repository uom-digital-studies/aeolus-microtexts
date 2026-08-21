test_that("nationalism_schema is named nationalism", {
  expect_equal(nationalism_schema$name, "nationalism")
})

test_that("analyse_nationalism_ollama() delegates to the shared engine", {
  unit_tbl <- tibble::tibble(unit_of_analysis = c("Erin go bragh.", "A neutral remark."))
  backend <- fake_chat_backend(list(
    list(label = "nationalist", score = 0.7),
    list(label = "ambivalent", score = 0.1)
  ))

  result <- analyse_nationalism_ollama(unit_tbl, unit_of_analysis, chat_backend = backend)

  expect_equal(result$research_question, c("nationalism", "nationalism"))
  expect_equal(result$label, c("nationalist", "ambivalent"))
  expect_equal(result$score, c(0.7, 0.1))
})

test_that("run_nationalism_pipeline() writes scored sentences via the shared engine", {
  output <- withr::local_tempfile(fileext = ".csv")
  aeolus <- load_aeolus("sentence", TRUE)
  backend <- fake_chat_backend(
    rep(list(list(label = "nationalist", score = 0.5)), nrow(aeolus))
  )

  run_nationalism_pipeline("fake-model", output, chat_backend = backend)

  written <- readr::read_csv(output, show_col_types = FALSE)
  expect_equal(unique(written$label), "nationalist")
  expect_equal(unique(written$research_question), "nationalism")
})
