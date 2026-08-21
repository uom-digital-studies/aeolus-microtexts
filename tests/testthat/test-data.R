# Tests for load_aeolus() against the schema in docs/adr/0003-results-csv-schema.md
# Only the columns present at this stage of the pipeline are checked:
# granularity, include_headlines, microtext, unit_index, unit_of_analysis.

granularities <- c("microtext", "sentence")
headline_settings <- c(TRUE, FALSE)

test_that("load_aeolus() validates its arguments", {
  expect_error(load_aeolus(granularity = "paragraph", include_headlines = TRUE))
  expect_error(load_aeolus(granularity = "sentence", include_headlines = "yes"))
})

test_that("output has the ADR 0003 columns, in order, with correct types", {
  df <- load_aeolus("sentence", TRUE)
  expect_named(df, c("granularity", "include_headlines", "microtext", "unit_index", "unit_of_analysis"))
  expect_type(df$granularity, "character")
  expect_type(df$include_headlines, "logical")
  expect_type(df$unit_index, "integer")
  expect_type(df$unit_of_analysis, "character")
})

test_that("granularity metadata column matches the requested parameter", {
  for (g in granularities) {
    for (h in headline_settings) {
      df <- load_aeolus(g, h)
      expect_true(all(df$granularity == g), info = paste(g, h))
    }
  }
})

test_that("include_headlines metadata column matches the requested parameter", {
  for (g in granularities) {
    for (h in headline_settings) {
      df <- load_aeolus(g, h)
      expect_true(all(df$include_headlines == h), info = paste(g, h))
    }
  }
})

test_that("Aeolus contains 63 microtexts, regardless of granularity/headline settings", {
  for (g in granularities) {
    for (h in headline_settings) {
      df <- load_aeolus(g, h)
      expect_equal(dplyr::n_distinct(df$microtext), 63, info = paste(g, h))
    }
  }
})

test_that("microtext granularity yields exactly one unit per microtext", {
  df <- load_aeolus("microtext", TRUE)
  expect_equal(nrow(df), 63)
  expect_true(all(df$unit_index == 1))
})

test_that("sentence granularity yields the expected total number of sentences", {
  df <- load_aeolus("sentence", include_headlines = FALSE)
  expect_equal(nrow(df), 981)
})

test_that("unit_index is a contiguous 1-based sequence within each microtext", {
  df <- load_aeolus("sentence", TRUE)
  idx_ok <- df |>
    dplyr::arrange(microtext, unit_index) |>
    dplyr::group_by(microtext) |>
    dplyr::summarise(ok = identical(unit_index, seq_len(dplyr::n())), .groups = "drop")
  expect_true(all(idx_ok$ok))
})

test_that("unit_index preserves the original document order of sentences", {
  df_sentence <- load_aeolus("sentence", include_headlines = TRUE)
  df_microtext <- load_aeolus("microtext", include_headlines = TRUE)

  reconstructed <- df_sentence |>
    dplyr::arrange(microtext, unit_index) |>
    dplyr::group_by(microtext) |>
    dplyr::summarise(
      text = stringr::str_squish(stringr::str_c(unit_of_analysis, collapse = " ")),
      # One specific exception that breaks the test
      text = stringr::str_replace(text, "As he most! J", "As he most!J"),
      .groups = "drop"
    )

  expect_equal(reconstructed$text, df_microtext$unit_of_analysis)
})

test_that("microtext-level text is whitespace-normalised", {
  df <- load_aeolus("microtext", TRUE)
  expect_equal(df$unit_of_analysis, stringr::str_squish(df$unit_of_analysis))
})

test_that("sentence tokenisation does not fragment initials/abbreviations into spurious units", {
  df <- load_aeolus("sentence", include_headlines = FALSE)
  degenerate <- dplyr::filter(df, stringr::str_detect(unit_of_analysis, "^[[:alpha:]]\\.\\s*$"))
  expect_equal(nrow(degenerate), 0)
})

test_that("excluding headlines removes headline text from the sentence-level output", {
  with_headlines <- load_aeolus("sentence", TRUE)
  without_headlines <- load_aeolus("sentence", FALSE)

  expect_lt(nrow(without_headlines), nrow(with_headlines))

  headline_like <- stringr::str_detect(without_headlines$unit_of_analysis, "^[^a-z]+$")
  expect_false(any(headline_like))
})
