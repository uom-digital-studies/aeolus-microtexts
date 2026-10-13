# Run the `targets`/`crew` dispatcher as its own non-blocking `sbatch` job, not on the login node

## Problem

`scripts/test-run.sh` ran `targets::tar_make()` directly on spartan's login node via a plain blocking `ssh`. The real-HPC smoke test (job `32847095`) failed because of this: `crew`'s dispatcher listens on the submitting machine's local IP (`nanonext::ip_addr()`), so with `tar_make()` on the login node, the GPU worker job had to dial back into the login node to receive tasks. That dial timed out (`Error in dial(...) : 5 | Timed out`), after the worker had already successfully pulled its Ollama model — i.e. the failure was connectivity, not the pipeline logic. This also independently violates spartan's "do not run programs on the login node" policy, already flagged in `TODO.md` before this run.

## Decision

Submit the dispatcher (the `tar_make()` process; see "Dispatcher job" in `CONTEXT.md`) as its own `sbatch` job, on the `sapphire` (general-purpose, non-GPU) partition, defined in a new tracked file, `dispatcher.slurm`, at the repo root — not generated inline as an SSH heredoc, and not run via `sinteractive`. `scripts/test-run.sh`'s `sbatch` call is fire-and-forget: no `--wait`, no blocking local `ssh` session, no trap/`SIGINT` forwarding. The script submits the job, prints the job ID and monitoring instructions, and exits.

Nested job submission — the dispatcher job itself calling `sbatch` to launch `crew.cluster` worker jobs — is confirmed permitted on spartan.

## Considered options

- **`sinteractive`**: rejected. It's designed for a human at a keyboard; scripting an unattended wrapper around it to run for the duration of a sweep is fragile, and `test-run.sh` is meant to run end-to-end with nobody watching a terminal.
- **Blocking `sbatch --wait`**: considered, since it would have let most of the existing trap/`SSH_PID` structure survive unchanged. Rejected per explicit preference for a non-blocking submit-and-exit flow instead.
- **Inline heredoc for the dispatcher script** (matching the existing post-receive-hook pattern): rejected in favor of a tracked file, consistent with the project's convention of keeping HPC/SLURM infra as sibling root-level files, and reviewable in git history rather than embedded in bash.

## Consequences

- `scripts/test-run.sh` changes from "block until the pipeline finishes, then print manual next steps" to "submit and exit immediately, printing the job ID and `squeue`/log-tailing instructions up front" — a real UX shift from today's script.
- Interrupting `test-run.sh` locally no longer cancels anything on the cluster; there's no trap, no `SSH_PID`, no `pkill`. Cancelling a submitted run is now a fully manual `ssh spartan scancel <job_id>`.
- No automatic cleanup of worker jobs if the dispatcher job is killed or exceeds its own walltime — out of scope for now, deferred.
- The dispatcher job's own SLURM resources (`sapphire`, 1 cpu, 4G mem, 150 min walltime for the smoke test) are a separate concern from `slurm-resources.yml`, which only covers GPU worker resources. The 150-minute figure is hand-picked (comfortably above the smoke test's single-worker 120-minute cap), not derived programmatically; revisit once `run-sweep.sh` needs to size a dispatcher job against a real multi-model sweep.
- `tar_manifest()` validation deliberately stays on the login node, unchanged — it's a sub-second, non-networked metadata read, not the sustained/compute-bearing kind of process the login-node policy targets.
