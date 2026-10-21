test_that("ugc_schema is named ugc", {
  expect_equal(ugc_schema$name, "ugc")
})

test_that("ugc_schema is valid a valid RQ schema", {
  expect_no_error(validate_rq_schema(ugc_schema))
})
