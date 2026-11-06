# Submit one GPU job per model that starts Ollama with OLLAMA_DEBUG=1
# (reusing ollama_worker_script_lines()) and runs structured-output-probe.R.
# Run from the repo root on the login node:
#   Rscript scripts/submit-structured-output-probe.R [model ...]
# Server logs: ollama-logs/<model slug>_<jobid>.log
# Probe output: probe-logs/<model slug>_<jobid>.out

models <- commandArgs(trailingOnly = TRUE)
if (length(models) == 0) {
  models <- yaml::read_yaml("models.yml")$models |> purrr::map_chr("name")
}
resources <- yaml::read_yaml("slurm-resources.yml")
dir.create("probe-logs", showWarnings = FALSE)

submit <- function(model) {
  res <- utils::modifyList(resources$default, resources$models[[model]] %||% list())
  slug <- aeolusmicrotexts:::sanitise_target_name(model)
  setup <- aeolusmicrotexts:::ollama_worker_script_lines(model, gres_gpu = res$gres_gpu)
  # Debug must be set before run_ollama_server starts
  serve_at <- grep("^run_ollama_server", setup)
  setup <- append(setup, "export OLLAMA_DEBUG=1", after = serve_at - 1)
  # setup[1] is the #SBATCH --gres line; keep all directives before commands
  lines <- c(
    "#!/bin/bash",
    paste0("#SBATCH --job-name=probe_", slug),
    paste0("#SBATCH --partition=", res$partition),
    paste0("#SBATCH --cpus-per-task=", res$cpus_per_task),
    paste0("#SBATCH --mem-per-cpu=", res$memory_gigabytes_per_cpu, "G"),
    "#SBATCH --time=00:30:00",
    paste0("#SBATCH --output=probe-logs/", slug, "_%j.out"),
    setup,
    paste0("Rscript scripts/structured-output-probe.R '", model, "'")
  )
  path <- tempfile(paste0("probe_", slug, "_"), fileext = ".slurm")
  writeLines(lines, path)
  system2("sbatch", path)
}

purrr::walk(models, submit)
