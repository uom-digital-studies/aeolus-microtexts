test_that("analyse_ugc_ollama() still errors: RQ3 schema not yet finalised", {
  sentence_tbl <- tibble::tibble(sentence = "placeholder")
  expect_error(analyse_ugc_ollama(sentence_tbl, sentence), "not yet implemented")
})

test_that("run_ugc_pipeline() still errors: RQ3 schema not yet finalised", {
  expect_error(
    run_ugc_pipeline("input.txt", "fake-model", "output.csv"),
    "not yet implemented"
  )
})
