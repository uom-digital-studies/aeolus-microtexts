test_resources <- list(
  default = list(
    partition = NULL,
    cpus_per_task = 4,
    memory_gigabytes_per_cpu = 4,
    time_minutes = 120
  ),
  models = list(
    "llama3.1" = list(memory_gigabytes_per_cpu = 8)
  )
)

# Explicit, so tests never depend on DNS-resolving the test machine's hostname
test_host <- "127.0.0.1"

test_central_models_dir <- "/data/gpfs/shared/ollama_models"
test_project_models_dir <- "/data/gpfs/projects/test-project/ollama_models"

test_models <- c("llama3.1", "mistral")

test_that("model_store_dir() resolves to a sibling of the repo checkout root", {
  expect_equal(
    model_store_dir(start = testthat::test_path("..", "..")),
    file.path(dirname(rprojroot::find_package_root_file()), "ollama_models")
  )
})

test_that("build_slurm_controllers() builds one named controller per model", {
  controllers <- build_slurm_controllers(test_models, resources = test_resources, host = test_host)

  expect_equal(names(controllers), c("llama3.1", "mistral"))
  expect_true(all(vapply(controllers, inherits, logical(1), "crew_class_controller")))
})

test_that("build_slurm_controllers() allows a per-model gres_gpu override, defaulting to gpu:1", {
  resources_with_gres <- test_resources
  resources_with_gres$models[["mistral"]] <- list(gres_gpu = "gpu:2")
  controllers <- build_slurm_controllers(test_models, resources = resources_with_gres, host = test_host)

  llama_lines <- controllers[["llama3.1"]]$launcher$options_cluster$script_lines
  mistral_lines <- controllers[["mistral"]]$launcher$options_cluster$script_lines

  expect_equal(llama_lines[1], "#SBATCH --gres=gpu:1")
  expect_equal(mistral_lines[1], "#SBATCH --gres=gpu:2")
  # gres_gpu must not leak into crew_options_slurm(), which has no such arg
  expect_null(controllers[["mistral"]]$launcher$options_cluster$gres_gpu)
})

test_that("build_slurm_controllers() applies resolved per-model resources", {
  controllers <- build_slurm_controllers(test_models, resources = test_resources, host = test_host)

  llama_options <- controllers[["llama3.1"]]$launcher$options_cluster
  mistral_options <- controllers[["mistral"]]$launcher$options_cluster

  # Per-model override applied ...
  expect_equal(llama_options$memory_gigabytes_per_cpu, 8)
  # ... while an unlisted model falls back to the default block
  expect_equal(mistral_options$memory_gigabytes_per_cpu, 4)
  expect_equal(mistral_options$cpus_per_task, 4)
})

test_that("build_slurm_controllers() embeds the model check line (ollama show) for each model", {
  controllers <- build_slurm_controllers(test_models, resources = test_resources, host = test_host)

  expect_true(any(grepl(
    "ollama show llama3.1",
    controllers[["llama3.1"]]$launcher$options_cluster$script_lines
  )))
  expect_true(any(grepl(
    "ollama show mistral",
    controllers[["mistral"]]$launcher$options_cluster$script_lines
  )))
})

test_that("build_slurm_controllers() embeds the GPU request, module loads, and OLLAMA_MODELS export", {
  controllers <- build_slurm_controllers(
    "llama3.1",
    resources = test_resources,
    host = test_host
  )

  lines <- controllers[["llama3.1"]]$launcher$options_cluster$script_lines

  # Must be first: sbatch only honours #SBATCH directives up to the first
  # non-comment line, and crew.cluster places script_lines right after its
  # own generated header.
  expect_equal(lines[1], "#SBATCH --gres=gpu:1")
  expect_true(any(grepl("^module load GCCcore/", lines)))
  expect_true(any(grepl("^module load ollama/", lines)))
  expect_true(any(grepl("^module load foss/.* R/", lines)))
  expect_true(any(grepl("^OLLAMA_LOG=ollama-logs/llama3\\.1_\\$\\{SLURM_JOB_ID\\}\\.log$", lines)))
  expect_true(any(grepl("^run_ollama_server > \\$OLLAMA_LOG 2>&1 &$", lines)))
  expect_true(any(grepl("^mkdir -p ollama-logs$", lines)))
  expect_true(any(grepl(
    paste0("^export OLLAMA_MODELS=", model_store_dir(), "$"),
    lines
  )))
})

test_that("build_slurm_controllers() discovers the server's randomised port rather than assuming 11434", {
  controllers <- build_slurm_controllers(
    "llama3.1",
    resources = test_resources,
    host = test_host
  )

  lines <- controllers[["llama3.1"]]$launcher$options_cluster$script_lines

  expect_true(any(grepl("OLLAMA_HOST=\\$\\(grep", lines)))
  expect_true(any(grepl("^export OLLAMA_BASE_URL=http://\\$\\{OLLAMA_HOST\\}$", lines)))
  expect_true(any(grepl("curl -sf http://\\$\\{OLLAMA_HOST\\}/", lines)))
  expect_false(any(grepl("11434", lines)))
})

test_that("build_slurm_controllers() greps the per-job OLLAMA_LOG in text mode so TTY control codes don't hide OLLAMA_HOST", {
  controllers <- build_slurm_controllers(
    "llama3.1",
    resources = test_resources,
    host = test_host
  )

  lines <- controllers[["llama3.1"]]$launcher$options_cluster$script_lines

  expect_true(any(grepl("grep -aq 'OLLAMA_HOST=' \\$OLLAMA_LOG", lines)))
  expect_true(any(grepl("grep -aoE 'OLLAMA_HOST=\\\\S\\+' \\$OLLAMA_LOG", lines)))
})

test_that("build_slurm_controllers() gives different models different OLLAMA_LOG paths", {
  controllers <- build_slurm_controllers(test_models, resources = test_resources, host = test_host)

  llama_lines <- controllers[["llama3.1"]]$launcher$options_cluster$script_lines
  mistral_lines <- controllers[["mistral"]]$launcher$options_cluster$script_lines

  llama_log_line <- llama_lines[grepl("^OLLAMA_LOG=", llama_lines)]
  mistral_log_line <- mistral_lines[grepl("^OLLAMA_LOG=", mistral_lines)]

  expect_length(llama_log_line, 1)
  expect_length(mistral_log_line, 1)
  expect_false(identical(llama_log_line, mistral_log_line))
})

test_that("build_slurm_controllers() aborts the job if OLLAMA_HOST ends up empty", {
  controllers <- build_slurm_controllers(
    "llama3.1",
    resources = test_resources,
    host = test_host
  )

  lines <- controllers[["llama3.1"]]$launcher$options_cluster$script_lines
  host_export_idx <- grep("^export OLLAMA_HOST=", lines)
  check_idx <- grep("Could not find OLLAMA_HOST=", lines)
  base_url_idx <- grep("^export OLLAMA_BASE_URL=", lines)

  expect_length(check_idx, 1)
  expect_true(any(grepl('if \\[ -z "\\$OLLAMA_HOST" \\]', lines)))
  expect_true(any(grepl("exit 1", lines)))
  # Must check between discovering the host and using it to build the URL
  expect_true(check_idx > host_export_idx && check_idx < base_url_idx)
})

test_that("build_slurm_controllers() points all models at the model store", {
  controllers <- build_slurm_controllers(
    "mistral",
    resources = test_resources,
    host = test_host
  )

  lines <- controllers[["mistral"]]$launcher$options_cluster$script_lines
  expected_dir <- model_store_dir()

  expect_true(any(grepl(
    paste0("^export OLLAMA_MODELS=", expected_dir, "$"),
    lines
  )))
})

test_that("dispatcher_host() returns the DNS-resolved address of the given hostname", {
  fake_resolve <- function(nodename) {
    expect_equal(nodename, "spartan-bm999")
    "10.0.0.5"
  }
  expect_equal(dispatcher_host("spartan-bm999", resolve = fake_resolve), "10.0.0.5")
})

test_that("dispatcher_host() errors clearly when the hostname doesn't resolve", {
  expect_error(
    dispatcher_host("no-such-node", resolve = function(nodename) NULL),
    "Could not resolve dispatcher hostname 'no-such-node'"
  )
  expect_error(
    dispatcher_host("no-such-node", resolve = function(nodename) NA_character_),
    "Could not resolve"
  )
})

test_that("build_slurm_controllers() passes host and seconds_launch through to crew", {
  controllers <- build_slurm_controllers(
    test_models,
    resources = test_resources,
    host = "10.0.0.5",
    seconds_launch = 1234
  )

  purrr::walk(controllers, function(controller) {
    expect_equal(controller$client$host, "10.0.0.5")
    expect_equal(controller$launcher$seconds_launch, 1234)
  })
})

test_that("build_slurm_controllers() defaults seconds_launch well below crew's 24h", {
  controllers <- build_slurm_controllers(test_models, resources = test_resources, host = test_host)

  expect_equal(controllers[["llama3.1"]]$launcher$seconds_launch, 3600)
})

test_that("sanitise_target_name() collapses characters invalid in target names", {
  expect_equal(sanitise_target_name("llama3.2:1b"), "llama3.2_1b")
})

test_that("build_grid_targets() creates a grid/scored target pair per model", {
  targets::tar_dir({
    targets::tar_script({
      list(
        targets::tar_target(run_id, "fake-run"),
        build_grid_targets(
          models = c("fake-model-a", "fake-model-b"),
          research_questions = "sentiment",
          context_variants = "no_context",
          granularities = "sentence",
          include_headlines = TRUE
        )
      )
    }, ask = FALSE)

    manifest <- targets::tar_manifest(callr_function = NULL)

    expect_setequal(
      manifest$name,
      c(
        "run_id",
        "grid_fake_model_a", "scored_fake_model_a",
        "grid_fake_model_b", "scored_fake_model_b"
      )
    )
  })
})

test_that("build_grid_targets() branches scored_<model> over grid_<model>", {
  targets::tar_dir({
    targets::tar_script({
      list(
        targets::tar_target(run_id, "fake-run"),
        build_grid_targets(
          models = "fake-model",
          research_questions = "sentiment",
          context_variants = "no_context",
          granularities = "sentence",
          include_headlines = TRUE
        )
      )
    }, ask = FALSE)

    manifest <- targets::tar_manifest(
      fields = tidyselect::any_of(c("name", "command", "pattern")),
      callr_function = NULL
    )
    scored <- manifest[manifest$name == "scored_fake_model", ]
    grid <- manifest[manifest$name == "grid_fake_model", ]

    expect_equal(scored$pattern, "map(grid_fake_model)")
    # Dispatches via rq_schema_for() on the grid row's research_question ...
    expect_true(grepl("rq_schema_for(grid_fake_model$research_question)", scored$command, fixed = TRUE))
    # ... and the grid row builds output paths nested under run_id
    expect_true(grepl("results", grid$command, fixed = TRUE))
    expect_true(grepl("run_id", grid$command, fixed = TRUE))
  })
})

test_that("build_grid_targets() nests output under a custom results_dir", {
  targets::tar_dir({
    targets::tar_script({
      list(
        targets::tar_target(run_id, "fake-run"),
        build_grid_targets(
          models = "fake-model",
          research_questions = "sentiment",
          context_variants = "no_context",
          granularities = "sentence",
          include_headlines = TRUE,
          results_dir = "test-results"
        )
      )
    }, ask = FALSE)

    manifest <- targets::tar_manifest(
      fields = tidyselect::any_of(c("name", "command")),
      callr_function = NULL
    )
    grid <- manifest[manifest$name == "grid_fake_model", ]

    expect_true(grepl("test-results", grid$command, fixed = TRUE))
  })
})
