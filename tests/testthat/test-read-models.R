test_that("read_models() parses name entries into a tibble", {
  path <- withr::local_tempfile(fileext = ".yml")
  yaml::write_yaml(
    list(models = list(
      list(name = "llama3.1:8b"),
      list(name = "mistral")
    )),
    path
  )

  result <- read_models(path)

  expect_s3_class(result, "tbl_df")
  expect_named(result, "model")
  expect_equal(result$model, c("llama3.1:8b", "mistral"))
})

test_that("read_models() ignores extra keys in model entries", {
  path <- withr::local_tempfile(fileext = ".yml")
  yaml::write_yaml(
    list(models = list(
      list(name = "llama3.1:8b", source = "central", extra = "ignored")
    )),
    path
  )

  result <- read_models(path)

  expect_equal(result$model, "llama3.1:8b")
  expect_named(result, "model")
})

test_that("read_models() errors when the file is missing", {
  expect_error(read_models("does-not-exist.yml"), "not found")
})

test_that("read_models() errors when the models block is missing", {
  path <- withr::local_tempfile(fileext = ".yml")
  yaml::write_yaml(list(not_models = list()), path)

  expect_error(read_models(path), "missing a required 'models' block")
})

test_that("read_models() errors when an entry is missing name", {
  path <- withr::local_tempfile(fileext = ".yml")
  yaml::write_yaml(
    list(models = list(list(other_field = "value"))),
    path
  )

  expect_error(read_models(path), "missing a required 'name'")
})
