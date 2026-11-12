# Build one crew.cluster SLURM controller per model

One controller/worker group per model (ADR 0001) — each worker starts
`ollama serve` once via
[`ollama_worker_script_lines()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/ollama_worker_script_lines.md)
and reuses it across that model's research-question x context-variant x
granularity x include_headlines cells. Splice the result into
[`crew::crew_controller_group()`](https://wlandau.github.io/crew/reference/crew_controller_group.html)
and pass to `tar_option_set(controller = ...)`.

## Usage

``` r
build_slurm_controllers(
  models,
  resources = read_slurm_resources(),
  host = dispatcher_host(),
  seconds_launch = 3600
)
```

## Arguments

- models:

  A character vector of Ollama model identifiers, or a tibble as
  returned by
  [`read_models()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/read_models.md)
  (the `model` column is extracted)

- resources:

  A list as returned by
  [`read_slurm_resources()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/read_slurm_resources.md);
  per-model overrides are resolved via
  [`resolve_slurm_resources()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/resolve_slurm_resources.md)
  keyed off model names. A resolved `gres_gpu` field (e.g. `"gpu:2"`) is
  passed to
  [`ollama_worker_script_lines()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/ollama_worker_script_lines.md)
  rather than spliced into
  [`crew.cluster::crew_options_slurm()`](https://wlandau.github.io/crew.cluster/reference/crew_options_slurm.html),
  which has no matching argument; it defaults to `"gpu:1"` when absent

- host:

  Address the dispatcher listens on and workers dial; see
  [`dispatcher_host()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/dispatcher_host.md)
  for why `crew`'s own default isn't used

- seconds_launch:

  Seconds `crew` waits for a launched worker to connect before treating
  it as lost and relaunching. Must cover GPU queue wait, but stay well
  below the dispatcher job's walltime: `crew`'s default (86400) makes a
  worker that dies before connecting leave the dispatcher hanging
  silently until walltime (ADR 0006). If a worker dies before connecting
  (e.g. module load fails, Ollama server fails to start), `crew` will
  relaunch it endlessly until either the worker connects or the
  dispatcher walltime is reached; this is a known behavior in crew
  1.3.3, accepted per ADR 0007

## Value

A list of `crew_controller_slurm` objects, one per model, each named for
its model

## Details

Each worker's SLURM stdout/stderr is captured to
`crew-logs/<sanitised model>_<job id>.log` (relative to the working
directory
[`targets::tar_make()`](https://docs.ropensci.org/targets/reference/tar_make.html)
is run from) — `crew.cluster` defaults this to `/dev/null` otherwise,
which silently discards module-load, Ollama startup, and worker errors.
The `crew-logs/` directory is created here (not left to SLURM) because a
missing `--output` directory makes `sbatch` fail the job immediately.
