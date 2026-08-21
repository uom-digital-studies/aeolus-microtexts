test_resources <- list(
  default = list(
    slurm_partition = NULL,
    slurm_cpus_per_task = 4,
    slurm_memory_gigabytes_per_cpu = 4,
    slurm_time_minutes = 120
  ),
  models = list(
    llama3.1 = list(slurm_memory_gigabytes_per_cpu = 8)
  )
)

test_that("resolve_slurm_resources() falls back to default for an unlisted model", {
  resolved <- resolve_slurm_resources("mistral", resources = test_resources)
  expect_equal(resolved, test_resources$default)
})

test_that("resolve_slurm_resources() applies a per-model override, field by field", {
  resolved <- resolve_slurm_resources("llama3.1", resources = test_resources)

  expect_equal(resolved$slurm_memory_gigabytes_per_cpu, 8)
  # Unoverridden fields are untouched
  expect_equal(resolved$slurm_cpus_per_task, 4)
  expect_equal(resolved$slurm_time_minutes, 120)
})

test_that("resolve_slurm_resources() errors clearly when 'default' is missing", {
  expect_error(
    resolve_slurm_resources("mistral", resources = list(models = list())),
    "default"
  )
})

test_that("read_slurm_resources() errors clearly on a missing file", {
  expect_error(
    read_slurm_resources(withr::local_tempfile()),
    "not found"
  )
})

test_that("read_slurm_resources() errors clearly when 'default' is missing", {
  path <- withr::local_tempfile(fileext = ".yml")
  writeLines("models:\n  llama3.1:\n    slurm_cpus_per_task: 8", path)

  expect_error(read_slurm_resources(path), "default")
})

test_that("read_slurm_resources() reads the repo-root slurm-resources.yml shape", {
  path <- withr::local_tempfile(fileext = ".yml")
  writeLines(
    c(
      "default:",
      "  slurm_partition: null",
      "  slurm_cpus_per_task: 4",
      "  slurm_memory_gigabytes_per_cpu: 4",
      "  slurm_time_minutes: 120",
      "models:",
      "  llama3.1:",
      "    slurm_memory_gigabytes_per_cpu: 8"
    ),
    path
  )

  resources <- read_slurm_resources(path)
  resolved <- resolve_slurm_resources("llama3.1", resources = resources)

  expect_equal(resolved$slurm_memory_gigabytes_per_cpu, 8)
  expect_equal(resolved$slurm_cpus_per_task, 4)
})
