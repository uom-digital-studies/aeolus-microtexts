test_that("nationalism_schema is named nationalism", {
  expect_equal(nationalism_schema$name, "nationalism")
})

test_that("nationalism_schema is valid a valid RQ schema", {
  expect_no_error(validate_rq_schema(nationalism_schema))
})
