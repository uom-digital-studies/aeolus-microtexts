test_that("read_models() parses name/source entries into a tibble", {
  path <- withr::local_tempfile(fileext = ".yml")
  yaml::write_yaml(
    list(models = list(
      list(name = "llama3.1:8b", source = "central"),
      list(name = "mistral", source = "project")
    )),
    path
  )

  result <- read_models(path)

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("model", "source"))
  expect_equal(result$model, c("llama3.1:8b", "mistral"))
  expect_equal(result$source, c("central", "project"))
})

test_that("read_models() errors when the file is missing", {
  expect_error(read_models("does-not-exist.yml"), "not found")
})

test_that("read_models() errors when the models block is missing", {
  path <- withr::local_tempfile(fileext = ".yml")
  yaml::write_yaml(list(not_models = list()), path)

  expect_error(read_models(path), "missing a required 'models' block")
})

test_that("read_models() errors when an entry is missing name or source", {
  path <- withr::local_tempfile(fileext = ".yml")
  yaml::write_yaml(
    list(models = list(list(name = "llama3.1:8b"))),
    path
  )

  expect_error(read_models(path), "missing a required 'name' or 'source'")
})

test_that("read_models() errors on an invalid source value", {
  path <- withr::local_tempfile(fileext = ".yml")
  yaml::write_yaml(
    list(models = list(list(name = "llama3.1:8b", source = "elsewhere"))),
    path
  )

  expect_error(read_models(path), "invalid source")
})
