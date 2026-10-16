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
  expect_true(startsWith(ulysses, "This text is from James Joyce"))
})

test_that("build_system_prompt() is context variant + task instruction + output specification", {
  prompt <- build_system_prompt(test_schema, "ulysses_context")
  expect_equal(
    prompt,
    paste0(
      "This text is from James Joyce's novel Ulysses. Widget-ness of a sentence.\n\n",
      build_output_spec(test_schema)
    )
  )
})

test_that("build_output_spec() renders fields in schema order with values or type", {
  spec <- build_output_spec(test_schema)
  expect_equal(
    spec,
    paste0(
      "## Output fields\n\n",
      "Respond with a JSON object containing these fields, in this order.\n\n",
      "### label\nWidget label.\nAllowed values: \"a\", \"b\".\n\n",
      "### score\nWidget score.\nType: number."
    )
  )
})

test_that("build_output_spec() doesn't double terminal punctuation", {
  schema <- new_rq_schema("x", ellmer::type_object(
    "Task",
    score = ellmer::type_number("From -1 to 1.")
  ))
  spec <- build_output_spec(schema)
  expect_true(grepl("From -1 to 1.\n", spec, fixed = TRUE))
  expect_false(grepl("..", spec, fixed = TRUE))
})

test_that("build_user_turn() puts the unit under a 'The text' heading", {
  expect_equal(build_user_turn("HELLO. World."), "## The text\n\nHELLO. World.")
})

test_that("analyse_with_schema() sends the unit as a headed user turn", {
  seen <- new.env()
  backend <- function(system_prompt, model, params = NULL) {
    client <- list(chat_structured = function(text, type) {
      seen$text <- text
      list(label = "a", score = 0)
    })
    client$clone <- function() client
    client
  }
  result <- analyse_with_schema(
    tibble::tibble(unit_of_analysis = "only unit"), unit_of_analysis,
    test_schema, chat_backend = backend
  )
  expect_equal(seen$text, "## The text\n\nonly unit")
  expect_equal(result$unit_of_analysis, "only unit")
})

test_that("preview_prompt() returns system prompt, user turn and JSON Schema", {
  out <- NULL
  expect_output(out <- preview_prompt(test_schema, unit = "A unit"), "not read by the model")
  expect_equal(out$system_prompt, build_system_prompt(test_schema))
  expect_equal(out$user_turn, "## The text\n\nA unit")
  parsed <- jsonlite::fromJSON(out$json_schema, simplifyVector = FALSE)
  expect_equal(names(parsed$properties), c("label", "score"))
  expect_equal(unlist(parsed$properties$label$enum), c("a", "b"))
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
  backend <- function(system_prompt, model, params = NULL) {
    seen$system_prompt <- system_prompt
    seen$model <- model
    fake_chat_backend(list(list(label = "a", score = 0)))(system_prompt, model, params)
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

test_that("analyse_with_schema() with skip_indices excludes those rows from the result", {
  unit_tbl <- tibble::tibble(unit_of_analysis = c("first", "second", "third"))
  backend <- fake_chat_backend(list(
    list(label = "b", score = -0.2)
  ))

  result <- analyse_with_schema(unit_tbl, unit_of_analysis, test_schema,
    chat_backend = backend, skip_indices = c(1, 3)
  )

  # Only row 2 scored; rows 1 and 3 are omitted entirely
  expect_equal(nrow(result), 1)
  expect_equal(result$unit_of_analysis, "second")
  expect_equal(result$research_question, "widget")
  expect_equal(result$label, "b")
  expect_equal(result$score, -0.2)
})

test_that("run_pipeline_with_schema() resumes from existing output: scores only new units and merges results", {
  output <- withr::local_tempfile(fileext = ".csv")
  aeolus <- load_aeolus("sentence", TRUE)
  n_total <- nrow(aeolus)
  
  # Manually create a CSV with the first 100 rows pre-scored
  first_n <- 100
  first_scored <- aeolus |>
    dplyr::slice(1:first_n) |>
    dplyr::mutate(
      research_question = "widget",
      model = "fake-model",
      context_variant = "no_context",
      label = "a",
      score = 0.1
    ) |>
    dplyr::select(research_question, model, context_variant, granularity,
                  include_headlines, microtext, unit_index, unit_of_analysis, label, score)
  
  readr::write_csv(first_scored, output)
  
  # Now resume: run_pipeline_with_schema should skip the first 100 rows and score the rest
  remaining_count <- n_total - first_n
  backend2 <- fake_chat_backend(
    rep(list(list(label = "b", score = -0.3)), remaining_count)
  )
  result2 <- run_pipeline_with_schema("fake-model", output, test_schema,
    granularity = "sentence", include_headlines = TRUE, chat_backend = backend2
  )
  
  # Result should now have all units
  expect_equal(nrow(result2), n_total)
  written2 <- readr::read_csv(output, show_col_types = FALSE)
  expect_equal(nrow(written2), n_total)
  
  # First 100 should still be "a" (from first_scored), rest should be "b" (from result2)
  expect_equal(sum(written2$label == "a"), first_n)
  expect_equal(sum(written2$label == "b"), remaining_count)
})

test_that("run_pipeline_with_schema() handles missing columns in existing CSV by rerunning all units", {
  output <- withr::local_tempfile(fileext = ".csv")
  aeolus <- load_aeolus("sentence", TRUE)
  n_total <- nrow(aeolus)
  
  # Write a CSV with missing required columns
  writeLines("research_question,model\nwidget,bad", output)
  
  # Should rerun all units
  backend <- fake_chat_backend(
    rep(list(list(label = "c", score = 0.7)), n_total)
  )
  
  expect_warning(
    result <- run_pipeline_with_schema("fake-model", output, test_schema,
      granularity = "sentence", include_headlines = TRUE, chat_backend = backend
    ),
    "Failed to validate existing output CSV"
  )
  
  # Should have rerun all units
  expect_equal(nrow(result), n_total)
  written <- readr::read_csv(output, show_col_types = FALSE)
  expect_equal(nrow(written), n_total)
  # All rows should have been rescored with label "c"
  expect_true(all(written$label == "c"))
})

test_that("run_pipeline_with_schema() detects and discards incomplete final row", {
  output <- withr::local_tempfile(fileext = ".csv")
  aeolus <- load_aeolus("sentence", TRUE)
  n_total <- nrow(aeolus)
  
  # Manually create a CSV with the first 50 rows scored, but last row incomplete (NA values)
  first_n <- 50
  partial_scored <- aeolus |>
    dplyr::slice(1:first_n) |>
    dplyr::mutate(
      research_question = "widget",
      model = "fake-model",
      context_variant = "no_context",
      label = "a",
      score = 0.1
    ) |>
    dplyr::select(research_question, model, context_variant, granularity,
                  include_headlines, microtext, unit_index, unit_of_analysis, label, score)
  
  # Modify the last row to have NAs (incomplete)
  partial_scored$label[nrow(partial_scored)] <- NA_character_
  partial_scored$score[nrow(partial_scored)] <- NA_real_
  
  readr::write_csv(partial_scored, output)
  
  # Now resume: should discard incomplete row, then skip first 49 (complete) rows
  remaining_count <- n_total - (first_n - 1)
  backend2 <- fake_chat_backend(
    rep(list(list(label = "b", score = -0.3)), remaining_count)
  )
  expect_warning(
    result2 <- run_pipeline_with_schema("fake-model", output, test_schema,
      granularity = "sentence", include_headlines = TRUE, chat_backend = backend2
    ),
    "incomplete final row"
  )
  
  # Result should have all units (49 complete from before + remaining new ones)
  expect_equal(nrow(result2), n_total)
  written2 <- readr::read_csv(output, show_col_types = FALSE)
  expect_equal(nrow(written2), n_total)
  
  # First 49 should still be "a", rest should be "b"
  expect_equal(sum(written2$label == "a"), first_n - 1)
  expect_equal(sum(written2$label == "b"), remaining_count)
})
