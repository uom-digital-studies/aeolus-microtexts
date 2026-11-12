test_schema <- new_rq_schema(
  name = "stonky",
  type = ellmer::type_object(
    "Stonky-hood of a sentence",
    label = ellmer::type_enum("Stonk label", values = c("stank", "stink")),
    score = ellmer::type_number("Stonky-hood score")
  )
)

test_that("preview_prompt() returns a prompt_preview", {
  out <- preview_prompt(test_schema, unit = "That unit")
  expect_s3_class(out, "prompt_preview")
})

test_that("preview_prompt() returns system prompt, user turn and JSON Schema", {
  out <- preview_prompt(test_schema, unit = "A unit")
  expect_equal(out$system_prompt, build_system_prompt(test_schema))
  expect_equal(out$user_turn, "## The text\n\nA unit")
  parsed <- jsonlite::fromJSON(out$json_schema, simplifyVector = FALSE)
  expect_equal(names(parsed$properties), c("label", "score"))
  expect_equal(unlist(parsed$properties$label$enum), c("stank", "stink"))
})

test_that("new_prompt_preview() rejects non-character fields", {
  expect_error(new_prompt_preview(system_prompt = 1))
  expect_error(new_prompt_preview(user_turn = list("a")))
  expect_error(new_prompt_preview(json_schema = NULL))
})

test_that("print() shows labelled sections in order and returns input invisibly", {
  out <- preview_prompt(test_schema, unit = "A unit")
  expect_invisible(res <- print(out))
  expect_identical(res, out)

  printed <- capture.output(print(out))
  headers <- grep("^(SYSTEM PROMPT|USER TURN|JSON SCHEMA)", printed)
  expect_length(headers, 3)
  expect_true(all(diff(headers) > 0))
})

test_that("print() wraps lines to `width`", {
  out <- preview_prompt(test_schema, unit = "A unit")
  printed <- capture.output(print(out, width = 40))
  expect_lte(max(nchar(printed)), 40)
  expect_equal(sum(printed == strrep("-", 40)), 6)
})

test_that("print() preserves JSON Schema indentation", {
  out <- preview_prompt(test_schema, unit = "A unit")
  printed <- capture.output(print(out, width = 80))
  expect_true(any(grepl("^    \"", printed)))
})

test_that("wrap_lines() wraps long lines and keeps blank lines", {
  wrapped <- wrap_lines("aaa bbb ccc ddd\n\neee", width = 8)
  expect_equal(wrapped, "aaa bbb\nccc ddd\n\neee")
})

test_that("wrap_lines() preserves indentation on wrapped continuation lines", {
  wrapped <- wrap_lines("  aaa bbb ccc", width = 9)
  expect_equal(wrapped, "  aaa bbb\n  ccc")
})
