# Script lines run on an Ollama worker node before it starts pulling tasks

Loads the module chain Spartan's GPU partition requires for Ollama
(`GCCcore` -\> `ollama` -\> `foss`/`R`, matching the example scripts on
the server), points `OLLAMA_MODELS` at the model store directory, sets
`OLLAMA_NOPRUNE=1` to prevent the server from pruning unused models (the
dispatcher pulls once; workers must only check for existence), starts
the cluster's `run_ollama_server` wrapper (Spartan's own wrapper around
`ollama serve` — not called directly) in the background, waits for it to
respond, then checks that the model exists in the store. Workers never
pull; only the dispatcher does (ADR 0007).

## Usage

``` r
ollama_worker_script_lines(
  model,
  gres_gpu = "gpu:1",
  model_store = model_store_dir()
)
```

## Arguments

- model:

  Ollama model identifier

- gres_gpu:

  Value for the `--gres` SLURM directive, e.g. `"gpu:1"` (default) or
  `"gpu:2"` for a model that needs more than one GPU's VRAM

- model_store:

  Path to the model store directory (default:
  [`model_store_dir()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/model_store_dir.md))

## Value

A character vector of shell script lines

## Details

Unlike a plain `ollama serve`, Spartan's `run_ollama_server` binds to a
*random* port each time (it shares GPU nodes across users, so port 11434
can't be assumed free) and only reports the chosen `host:port` in its
own stdout, e.g. `OLLAMA_HOST=spartan-gpgpu126:34267 ollama <CMD>`. So
this redirects that stdout to a log file, polls it until the
`OLLAMA_HOST=...` line appears, and exports it — plus `OLLAMA_BASE_URL`
(the env var
[`ellmer::chat_ollama()`](https://ellmer.tidyverse.org/reference/chat_ollama.html)
actually reads, in `http://host:port` form) — before probing readiness,
so every later command in the job (the readiness curl, the model check,
and the R worker process itself) talks to the right port instead of
silently falling back to the unused default of 11434.

The server log is written to
`ollama-logs/<sanitised model>_$SLURM_JOB_ID.log` rather than a fixed
relative name: every GPU worker job runs from the same checkout-root
working directory (one `crew.cluster` SLURM job per model, ADR 0001), so
a shared plain filename like `ollama-server.log` is clobbered by every
concurrent model's worker (and by `crew`'s own relaunch of a timed-out
worker for the *same* model) — a worker can read another worker's
`OLLAMA_HOST=` line, or a truncated/interleaved one. Keying the path on
both the model slug and `$SLURM_JOB_ID` (always set inside an `sbatch`
job) gives every worker job its own file.

This log also contains the TTY progress-bar redraw sequences
`run_ollama_server`/`ollama pull` emit, which makes `grep` treat the
file as binary and, without `-a`, print `"binary file matches"` instead
of the actual match — silently breaking the `OLLAMA_HOST` extraction.
Both `grep` calls here force text mode with `-a` to avoid that, and the
result is checked for emptiness (failing the job immediately with a
clear message) rather than letting a blank `OLLAMA_HOST` silently
produce a hostless `OLLAMA_BASE_URL=http://` that only surfaces later as
a confusing `ellmer`/`httr2` URL-parsing error.

The leading `#SBATCH --gres=gpu:<n>` line requests the GPU(s).
`gres_gpu` lets this be e.g. `"gpu:2"` for a model too large for one
A100's VRAM — see `gres_gpu` in `slurm-resources.yml` (ADR 0001).
[`crew.cluster::crew_controller_slurm()`](https://wlandau.github.io/crew.cluster/reference/crew_controller_slurm.html)
has no dedicated `gres` argument, but `sbatch` keeps scanning for
`#SBATCH` directives up to the first non-comment line, and
`crew.cluster` places `script_lines` immediately after its own generated
header with no other commands in between — so a `#SBATCH` line is still
honoured here as long as it comes first.
