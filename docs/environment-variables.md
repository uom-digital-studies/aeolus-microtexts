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

## `~/.Renviron` (per-machine, outside the repo)

- Read by R itself at startup (see `?Startup`), not by `renv` or by this project's scripts.
- Inherently host-specific: it can't be a single repo-tracked file, because the laptop and the HPC need different values (different filesystem layouts, different toolchains). Each machine that runs R for this project manages its own `~/.Renviron`.
- Holds R-level config, not orchestration config.
- Gitignored, so `git push` never carries it to spartan. `scripts/test-run.sh` works around this by `scp`-ing the laptop's repo-root `.Renviron` to `${REMOTE_DIR}/.Renviron` right after the push, and fails fast (before pushing anything stale through) if no local `.Renviron` exists.
- **Precedence caveat:** per `?Startup`, R checks for `.Renviron` in the process's *current working directory* first, and only falls back to `~/.Renviron` if none is found there — whichever one is found is used in full, not merged with the other. Every `Rscript` call in `scripts/test-run.sh` (`tar_manifest()`, `tar_make()`) runs with `cd ${REMOTE_DIR}` first, so once the upload step has placed `.Renviron` in `${REMOTE_DIR}`, **it shadows spartan's `~/.Renviron` for all of them** — `~/.Renviron` is never consulted by any R process `test-run.sh` starts.

Known variables (HPC-only, set in the HPC's `~/.Renviron`):

| Variable | Purpose |
| --- | --- |
| `R_LIBS_USER` | Path to a user-writable personal library (e.g. `~/R/library`). Required on spartan because the module-provided R library is shared/read-only; `pak::pkg_install(".")` needs a writable destination. Not needed on a laptop, which has a default personal library. Set before any install/package-load operation. |

## Adding a new variable

Decide which machine(s) actually need it:

- Needed only when running orchestration scripts from your laptop → `.env`, and add a row to the table above.
- Needed by R itself, and the value differs (or could differ) per machine → that machine's `~/.Renviron`, and add a row to the table above.
