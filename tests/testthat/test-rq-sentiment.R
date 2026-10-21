test_that("sentiment_schema is named sentiment", {
  expect_equal(sentiment_schema$name, "sentiment")
})

test_that("sentiment_schema is valid a valid RQ schema", {
  expect_no_error(validate_rq_schema(sentiment_schema))
})
