# Environment variables

Two separate mechanisms configure this project's environment, scoped differently — worth keeping straight rather than reaching for whichever is closer at hand.

## `.env` (repo root, gitignored)

- Read via `source .env` at the top of root-level orchestration scripts (currently `scripts/test-run.sh`).
- Lives on whichever machine *runs those scripts* — in practice, your laptop. `git push` to the HPC bare repo only sends committed files, so `.env` never reaches spartan, and doesn't need to.
- Holds config for driving the HPC from the outside: which host to SSH to, which remote paths to use.

Known variables:

| Variable | Used by | Purpose |
| --- | --- | --- |
| `SPARTAN_HOST` | `scripts/test-run.sh` | SSH alias for the HPC cluster (overrides the `spartan` default) |
| `SPARTAN_REMOTE_DIR` | `scripts/test-run.sh` | Work tree path on the HPC that the bare repo's post-receive hook checks out into |
| `SPARTAN_GIT_DIR` | `scripts/test-run.sh` | Path to the bare repo on the HPC |

## `.Renviron-hpc` (repo root, gitignored) → spartan's `~/.Renviron`

- Read by R itself at startup (see `?Startup`), not by `renv` or by this project's scripts. Holds R-level config, not orchestration config.
- `~/.Renviron` is inherently host-specific: it can't be a single repo-tracked file, because the laptop and the HPC need different values (different filesystem layouts, different toolchains). `.Renviron-hpc` is spartan's copy, staged at the repo root on your laptop purely so `scripts/test-run.sh` has something to `scp`; R on your laptop never reads this file (it's not named `.Renviron`, so R's own startup search skips it), and R on spartan never reads it *as `.Renviron-hpc`* either — only after it's been copied and renamed, below.
- Gitignored (`.gitignore` line 7) — never tracked, never committed, never carried by `git push`. You maintain it locally, out of band.
- **Mechanism:** right after `git push hpc "${BRANCH}"`, `scripts/test-run.sh` runs `scp .Renviron-hpc "${HOST}:${REMOTE_DIR}/.Renviron"` — this both copies the file to spartan *and* renames it to `.Renviron` in the process (the destination path's basename is `.Renviron`, not `.Renviron-hpc`). The script fails fast (before pushing anything stale through) if no local `.Renviron-hpc` exists.
- **Precedence caveat:** per `?Startup`, R checks for `.Renviron` in the process's *current working directory* first, and only falls back to `~/.Renviron` if none is found there — whichever one is found is used in full, not merged with the other. Every `Rscript` call in `scripts/test-run.sh` (`tar_manifest()`, `tar_make()`) runs with `cd ${REMOTE_DIR}` first, so once the upload step has placed `.Renviron` in `${REMOTE_DIR}`, **it shadows spartan's `~/.Renviron` for all of them** — spartan's own `~/.Renviron` (if any) is never consulted by any R process `test-run.sh` starts.
- **Overriding caveat:** R's startup processing of `.Renviron` sets each listed variable unconditionally, which *overrides* a same-named variable already present in the process's inherited shell environment (it isn't "set if absent" like a `.bashrc` export). This is also why `.Renviron-hpc` can be the *sole* source of truth for these variables rather than needing to be duplicated inline on each `ssh "..."` command: every remote `Rscript` call in `scripts/test-run.sh` `cd`s into `${REMOTE_DIR}` first (so the precedence caveat above applies, pulling in `.Renviron-hpc`'s values), and even if something upstream in the `ssh` command line set the same variable, `.Renviron-hpc` would win anyway. `scripts/test-run.sh` relies on this and does **not** set any of these variables inline, to keep a single source of truth (DRY) — don't reintroduce an inline copy "for safety"; it would be redundant at best and silently ignored at worst.

Known variables (HPC-only, set in `.Renviron-hpc`):

| Variable | Purpose |
| --- | --- |
| `R_LIBS_USER` | Path to a user-writable personal library. Required on spartan because the module-provided R library is shared/read-only; `pak::pkg_install(".")` and `targets::tar_make()` need a writable destination/library. Not needed on a laptop, which has a default personal library. **`.Renviron-hpc` must set `R_LIBS_USER="~/R/library/"` exactly**, matching the path `scripts/test-run.sh`'s `mkdir -p ~/R/library` step creates — that `mkdir` step and `.Renviron-hpc` are two independent places encoding the same path, since `mkdir` can't read `.Renviron-hpc` (it's a shell step, not an R one). If they diverge, install writes packages into one library while `tar_manifest()`/`tar_make()` (which do read `.Renviron-hpc`) look for them in whatever path `.Renviron-hpc` actually says — a silent library-path mismatch that surfaces as confusing "package not found" errors with no apparent env misconfiguration. |
| `OLLAMA_CENTRAL_MODELS_DIR` | Path to the cluster's shared, read-only Ollama model store (see `resolve_ollama_models_dir()` in `R/pipeline-orchestration.R`), required when building the pipeline on spartan. Set only in `.Renviron-hpc`, not inline, since `scripts/test-run.sh` itself doesn't need the value — it's only consumed by the remote R process. A value in the laptop's `.env` has no effect here: `.env` is sourced into the *local* bash process running `scripts/test-run.sh`, but the pipeline-building `Rscript` calls run on spartan over `ssh`, which does not forward local shell environment variables. |

## Adding a new variable

Decide which machine(s) actually need it:

- Needed only when running orchestration scripts from your laptop → `.env`, and add a row to the table above.
- Needed by R itself on spartan → `.Renviron-hpc`, and add a row to the table above.
