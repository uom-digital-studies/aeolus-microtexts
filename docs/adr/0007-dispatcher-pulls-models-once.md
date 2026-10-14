# The dispatcher job pulls every model once; workers only check for it

## Problem

Every worker (one concurrent GPU job per model, ADR 0001) started its own Ollama server against the same model store and ran `ollama pull`. Two things made this unsafe:

- **Startup pruning.** Ollama (0.17.5, the `ollama` module on spartan; Spartan's `run_ollama_server` wrapper doesn't change this) prunes unreferenced blobs from `OLLAMA_MODELS` on every server start, unless `OLLAMA_NOPRUNE` is set. A blob only becomes referenced once its pull finishes and writes the manifest. So any worker starting up, or `crew` relaunching one, can delete another worker's in-progress download.
- **Tag drift.** `ollama pull` on a model that's already present still checks the registry, and downloads again if the tag has moved. A worker relaunched mid-run could end up on different weights from the rest of the run.

Pull failures were also silent: neither the readiness probe's nor `ollama pull`'s exit status was checked.

## Decision

- The dispatcher job pulls every model in `models.yml` into the model store once, in a `targets` target (`deployment = "main"`). Every `scored_*` target depends on it, so `crew` launches no worker until all pulls are done. The target's R function starts Spartan's `run_ollama_server` itself via `processx`, and stops it when done.
- The pull target uses the default cue, keyed on the model list, so it reruns only when `models.yml` changes. Resuming a failed run doesn't pull again, which keeps model versions fixed for the whole `run_id`.
- The target returns a model/digest table and writes it to `results/<run_id>/models.csv`, so results trace back to exact model weights, not just tags.
- Workers set `OLLAMA_NOPRUNE=1`, never pull, and check for their model with `ollama show <model>`. A worker exits non-zero if the server doesn't become ready or the model is missing.
- The dispatcher's own server leaves pruning on. It starts before any worker exists and cleans out stale blobs that the workers' `NOPRUNE` setting leaves behind.
- Only one run may be active at a time per model store (see "Model store" in `CONTEXT.md`).

Feasibility was confirmed by `scripts/check-sapphire-pull.slurm`: on `sapphire`, the `ollama` module loads, `run_ollama_server` starts, the registry is reachable, and `ollama show` fails for a missing model and succeeds for a present one.

## Considered options

- **Per-worker pulls with `OLLAMA_NOPRUNE` plus a `flock` on a lock file in the store**: rejected. It depends on `flock` working across nodes on spartan's shared filesystem, and it leaves tag drift in place.
- **A separate pull job, or a pull step in `run-sweep.sh`, before the dispatcher**: rejected. It's one more moving part whose ordering lives in scripts rather than in the `targets` dependency graph.
- **Pulling again on every `tar_make()` (`cue = "always"`)**: rejected. Resuming a run after a tag moved would mix two model versions under one `run_id`.

## Consequences

- The dispatcher job, which does no inference, now loads the `ollama` module and runs a server, but only briefly.
- `crew` 1.3.3 never stops relaunching a worker that exits before connecting (`launch_max` is deprecated, and `crashes_max` only counts crashes mid-task). A persistent worker-side fault, such as an unreadable store, therefore repeats every `seconds_launch` (1 h) until the dispatcher's time limit. This is accepted: once the pull happens up front, such faults are environmental and show up in `crew-logs/`.
- If someone deletes the store by hand, `targets` won't notice. Workers will fail their presence check; `tar_invalidate()` the pull target to fix it.
- Stale blobs are only cleaned when a dispatcher starts up.
