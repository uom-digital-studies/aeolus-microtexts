# Run the `targets`/`crew` dispatcher as its own non-blocking `sbatch` job, not on the login node

## Problem

`scripts/test-run.sh` ran `targets::tar_make()` directly on spartan's login node via a plain blocking `ssh`. The real-HPC smoke test (job `32847095`) failed because of this: `crew`'s dispatcher listens on the submitting machine's local IP (`nanonext::ip_addr()`), so with `tar_make()` on the login node, the GPU worker job had to dial back into the login node to receive tasks. That dial timed out (`Error in dial(...) : 5 | Timed out`), after the worker had already successfully pulled its Ollama model — i.e. the failure was connectivity, not the pipeline logic. (This diagnosis turned out to be incomplete — see "Amendment: dispatcher host address" below. Running the dispatcher on the login node still also violates spartan policy, so the decision stands.) This also independently violates spartan's "do not run programs on the login node" policy, already flagged in `TODO.md` before this run.

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

## Amendment: dispatcher host address

Moving the dispatcher into its own `sapphire` job did not fix the timeout: the next smoke test (dispatcher `32849186`, worker `32849189`) failed identically — worker pulled its model, then `dial(...) : 5 | Timed out`, while the dispatcher kept waiting. The real cause was which address the dispatcher advertised, not which node it ran on. With no `host` set, `crew` uses `utils::head(nanonext::ip_addr(), 1)` — the first interface the OS lists. Spartan compute nodes have several interfaces; the first (`eno8303`, apparently a management network) is not the one the node's DNS name resolves to (a `bond0` VLAN), and connections to it from other nodes are silently dropped (confirmed with a `/dev/tcp` probe from the login node: blocked). The original login-node failure was very likely the same problem.

Decision: `build_slurm_controllers()` passes an explicit `host` to `crew.cluster::crew_controller_slurm()`: the IP that the dispatcher node's own hostname resolves to (`utils::nsl(Sys.info()[["nodename"]])`, failing fast if it doesn't resolve). The DNS-resolved address is what other nodes use to reach a node, so it doesn't depend on interface order or names, which are not hardcoded. The script is sourced inside the dispatcher job, so it resolves to the dispatcher node. Under `tar_manifest()` on the login node it resolves to the login node instead, which is harmless because the controller is never started there.

Also set `seconds_launch` (default 86400) well below the dispatcher's walltime. With the default, a worker that dies before connecting leaves the dispatcher waiting silently until SLURM kills it at walltime, with nothing recorded in the `targets` store — exactly what happened with `32849186`. A shorter `seconds_launch` makes `crew` treat the worker as failed and relaunch it, so these failures show up within the run. It counts from submission, so it must cover GPU queue wait plus the Ollama pull.

Not yet verified: whether GPU nodes can reach the DNS-resolved address on `crew`'s random high port. If the next run still times out, suspect a port firewall: ask spartan support for an allowed port range and set `port` explicitly as well.
