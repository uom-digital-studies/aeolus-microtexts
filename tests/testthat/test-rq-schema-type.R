valid_type <- function() {
  ellmer::type_object(
    "Classify the sentiment of this text",
    label = ellmer::type_enum("Overall sentiment", values = c("positive", "negative")),
    score = ellmer::type_number("Sentiment intensity, from -1 to 1")
  )
}

test_that("new_rq_schema() returns an rq_schema with name and type", {
  type <- valid_type()
  schema <- new_rq_schema("sentiment", type)

  expect_s3_class(schema, "rq_schema")
  expect_identical(schema$name, "sentiment")
  expect_identical(schema$type, type)
})

test_that("new_rq_schema() errors when name is not a scalar character", {
  expect_error(new_rq_schema(c("a", "b"), valid_type()), "name")
  expect_error(new_rq_schema(1, valid_type()), "name")
})

test_that("new_rq_schema() errors when type is not a type object", {
  expect_error(new_rq_schema("sentiment", "not a type"), "TypeObject")
})

test_that("validate_rq_schema() returns a valid schema unchanged", {
  schema <- new_rq_schema("sentiment", valid_type())

  expect_identical(validate_rq_schema(schema), schema)
})

test_that("validate_rq_schema() errors when name is missing", {
  expect_error(validate_rq_schema(list(type = valid_type())), "no name")
})

test_that("validate_rq_schema() errors when name is not a scalar character", {
  schema <- list(name = c("a", "b"), type = valid_type())

  expect_error(validate_rq_schema(schema), "not a scalar character")
})

test_that("validate_rq_schema() errors when type is not a type object", {
  schema <- list(name = "sentiment", type = "not a type")

  expect_error(validate_rq_schema(schema), "TypeObject")
})

test_that("validate_rq_schema() errors when properties are out of order", {
  type <- ellmer::type_object(
    "Classify the sentiment of this text",
    score = ellmer::type_number("Sentiment intensity"),
    label = ellmer::type_enum("Overall sentiment", values = c("positive", "negative"))
  )

  expect_error(validate_rq_schema(list(name = "sentiment", type = type)), "'label' and 'score'")
})

test_that("validate_rq_schema() errors when there are extra properties", {
  type <- ellmer::type_object(
    "Classify the sentiment of this text",
    label = ellmer::type_enum("Overall sentiment", values = c("positive", "negative")),
    score = ellmer::type_number("Sentiment intensity"),
    extra_property = ellmer::type_string("Why")
  )

    expect_error(validate_rq_schema(list(name = "sentiment", type = type)))
})

test_that("validate_rq_schema() errors when label is not an enum", {
  type <- ellmer::type_object(
    "Classify the sentiment of this text",
    label = ellmer::type_string("Overall sentiment"),
    score = ellmer::type_number("Sentiment intensity")
  )

  expect_error(validate_rq_schema(list(name = "sentiment", type = type)), "label")
})

test_that("validate_rq_schema() errors when score is not a basic type", {
  type <- ellmer::type_object(
    "Classify the sentiment of this text",
    label = ellmer::type_enum("Overall sentiment", values = c("positive", "negative")),
    score = ellmer::type_enum("Sentiment intensity", values = "high")
  )

  expect_error(validate_rq_schema(list(name = "sentiment", type = type)), "score")
})
