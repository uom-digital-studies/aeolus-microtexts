test_that("analyse_ugc_ollama() still errors: RQ3 schema not yet finalised", {
  unit_tbl <- tibble::tibble(unit_of_analysis = "placeholder")
  expect_error(analyse_ugc_ollama(unit_tbl, unit_of_analysis), "not yet implemented")
})

test_that("run_ugc_pipeline() still errors: RQ3 schema not yet finalised", {
  expect_error(
    run_ugc_pipeline("input.txt", "fake-model", "output.csv"),
    "not yet implemented"
  )
})
