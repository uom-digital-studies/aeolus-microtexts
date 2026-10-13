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

test_models_tbl <- tibble::tibble(
  model = c("llama3.1", "mistral"),
  source = c("central", "project")
)

test_that("default_ollama_project_models_dir() resolves to a sibling of the repo checkout root", {
  expect_equal(
    default_ollama_project_models_dir(start = testthat::test_path("..", "..")),
    file.path(dirname(rprojroot::find_package_root_file()), "ollama_models")
  )
})

test_that("resolve_ollama_models_dir() reads the central store from OLLAMA_CENTRAL_MODELS_DIR", {
  withr::local_envvar(OLLAMA_CENTRAL_MODELS_DIR = test_central_models_dir)
  expect_equal(resolve_ollama_models_dir("central"), test_central_models_dir)
})

test_that("resolve_ollama_models_dir() errors clearly when OLLAMA_CENTRAL_MODELS_DIR is unset", {
  withr::local_envvar(OLLAMA_CENTRAL_MODELS_DIR = NA)
  expect_error(resolve_ollama_models_dir("central"), "OLLAMA_CENTRAL_MODELS_DIR")
})

test_that("resolve_ollama_models_dir() uses the given project pull-cache dir for source = project", {
  expect_equal(
    resolve_ollama_models_dir("project", project_models_dir = test_project_models_dir),
    test_project_models_dir
  )
})

test_that("resolve_ollama_models_dir() errors on an unknown source", {
  expect_error(resolve_ollama_models_dir("elsewhere"), "Unknown model source")
})

test_that("build_slurm_controllers() builds one named controller per model", {
  withr::local_envvar(OLLAMA_CENTRAL_MODELS_DIR = test_central_models_dir)
  controllers <- build_slurm_controllers(test_models_tbl, resources = test_resources, host = test_host)

  expect_equal(names(controllers), c("llama3.1", "mistral"))
  expect_true(all(vapply(controllers, inherits, logical(1), "crew_class_controller")))
})

test_that("build_slurm_controllers() applies resolved per-model resources", {
  withr::local_envvar(OLLAMA_CENTRAL_MODELS_DIR = test_central_models_dir)
  controllers <- build_slurm_controllers(test_models_tbl, resources = test_resources, host = test_host)

  llama_options <- controllers[["llama3.1"]]$launcher$options_cluster
  mistral_options <- controllers[["mistral"]]$launcher$options_cluster

  # Per-model override applied ...
  expect_equal(llama_options$memory_gigabytes_per_cpu, 8)
  # ... while an unlisted model falls back to the default block
  expect_equal(mistral_options$memory_gigabytes_per_cpu, 4)
  expect_equal(mistral_options$cpus_per_task, 4)
})

test_that("build_slurm_controllers() embeds the ollama pull line for each model", {
  withr::local_envvar(OLLAMA_CENTRAL_MODELS_DIR = test_central_models_dir)
  controllers <- build_slurm_controllers(test_models_tbl, resources = test_resources, host = test_host)

  expect_true(any(grepl(
    "ollama pull llama3.1",
    controllers[["llama3.1"]]$launcher$options_cluster$script_lines
  )))
  expect_true(any(grepl(
    "ollama pull mistral",
    controllers[["mistral"]]$launcher$options_cluster$script_lines
  )))
})

test_that("build_slurm_controllers() embeds the GPU request, module loads, and OLLAMA_MODELS export", {
  withr::local_envvar(OLLAMA_CENTRAL_MODELS_DIR = test_central_models_dir)
  controllers <- build_slurm_controllers(
    tibble::tibble(model = "llama3.1", source = "central"),
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
  expect_true(any(grepl("^run_ollama_server > ollama-server.log 2>&1 &$", lines)))
  expect_true(any(grepl(
    paste0("^export OLLAMA_MODELS=", test_central_models_dir, "$"),
    lines
  )))
})

test_that("build_slurm_controllers() discovers the server's randomised port rather than assuming 11434", {
  withr::local_envvar(OLLAMA_CENTRAL_MODELS_DIR = test_central_models_dir)
  controllers <- build_slurm_controllers(
    tibble::tibble(model = "llama3.1", source = "central"),
    resources = test_resources,
    host = test_host
  )

  lines <- controllers[["llama3.1"]]$launcher$options_cluster$script_lines

  expect_true(any(grepl("OLLAMA_HOST=\\$\\(grep", lines)))
  expect_true(any(grepl("^export OLLAMA_BASE_URL=http://\\$\\{OLLAMA_HOST\\}$", lines)))
  expect_true(any(grepl("curl -sf http://\\$\\{OLLAMA_HOST\\}/", lines)))
  expect_false(any(grepl("11434", lines)))
})

test_that("build_slurm_controllers() points project-sourced models at the project pull-cache", {
  controllers <- build_slurm_controllers(
    tibble::tibble(model = "mistral", source = "project"),
    resources = test_resources,
    host = test_host
  )

  lines <- controllers[["mistral"]]$launcher$options_cluster$script_lines
  expected_dir <- default_ollama_project_models_dir()

  expect_true(any(grepl(
    paste0("^export OLLAMA_MODELS=", expected_dir, "$"),
    lines
  )))
})

test_that("build_slurm_controllers() errors clearly when a central model has no OLLAMA_CENTRAL_MODELS_DIR", {
  withr::local_envvar(OLLAMA_CENTRAL_MODELS_DIR = NA)

  expect_error(
    build_slurm_controllers(
      tibble::tibble(model = "llama3.1", source = "central"),
      resources = test_resources,
      host = test_host
    ),
    "OLLAMA_CENTRAL_MODELS_DIR"
  )
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
  withr::local_envvar(OLLAMA_CENTRAL_MODELS_DIR = test_central_models_dir)
  controllers <- build_slurm_controllers(
    test_models_tbl,
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
  withr::local_envvar(OLLAMA_CENTRAL_MODELS_DIR = test_central_models_dir)
  controllers <- build_slurm_controllers(test_models_tbl, resources = test_resources, host = test_host)

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
