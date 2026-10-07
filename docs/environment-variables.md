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
| `RENV_RESTORE_EXCLUDE` | `scripts/test-run.sh` | R expression (e.g. `c("Matrix", "slam")`) passed to `renv::restore(exclude = ...)`'s `exclude` argument on the HPC — see below for why this is needed. Defaults to `c("Matrix", "slam")` if unset, so `.env` only needs this once a *new* package hits the same failure. |

## `~/.Renviron` (per-machine, outside the repo)

- Read by R itself at startup (see `?Startup`), not by `renv` or by this project's scripts.
- Inherently host-specific: it can't be a single repo-tracked file, because the laptop and the HPC need different values (different filesystem layouts, different toolchains). Each machine that runs R for this project manages its own `~/.Renviron`.
- Holds R/renv-level config, not orchestration config.
- Gitignored, so `git push` never carries it to spartan. `scripts/test-run.sh` works around this by `scp`-ing the laptop's repo-root `.Renviron` to `${REMOTE_DIR}/.Renviron` right after the push, and fails fast (before pushing anything stale through) if no local `.Renviron` exists.
- **Precedence caveat:** per `?Startup`, R checks for `.Renviron` in the process's *current working directory* first, and only falls back to `~/.Renviron` if none is found there — whichever one is found is used in full, not merged with the other. Every `Rscript` call in `scripts/test-run.sh` (`renv::restore()`, `tar_manifest()`, `tar_make()`) runs with `cd ${REMOTE_DIR}` first, so once the upload step has placed `.Renviron` in `${REMOTE_DIR}`, **it shadows spartan's `~/.Renviron` for all of them** — `~/.Renviron` is never consulted by any R process `test-run.sh` starts.

There are currently no known variables needed in `~/.Renviron` for this project (see below for why `RENV_CONFIG_EXTERNAL_LIBRARIES` turned out not to be the fix for the `Matrix` restore failure).

### Why some packages fail to restore on spartan, and why `RENV_CONFIG_EXTERNAL_LIBRARIES` doesn't fix it

`renv::restore()` tries to materialize every package recorded in `renv.lock` into the project's private library, recompiling from source where no matching binary is cached. Any package whose compiled code links against R's own BLAS/LAPACK (`libRblas.so`/`libRlapack.so`) fails that rebuild on spartan's `foss/2022a` EasyBuild toolchain, e.g.:

```
Error in dyn.load(file, DLLpath = DLLpath, ...) :
  unable to load shared object '.../renv/staging/1/Matrix/libs/Matrix.so':
  libRlapack.so: cannot open shared object file: No such file or directory
```

(`Matrix` was the first to hit this, since it's a "recommended"-priority package that ships with R itself; `slam` hit the same failure later, against `libRblas.so` instead, despite being an ordinary CRAN dependency with no special relationship to R's own build.)

This is a known, unresolved upstream renv issue (e.g. [rstudio/renv#1684](https://github.com/rstudio/renv/issues/1684)) tied to R builds linked against external BLAS/LAPACK rather than R's bundled reference implementation — which is exactly how EasyBuild's `foss` toolchain builds R. renv's install-test subprocess can't find those `.so` files even though the parent R session (and `module load`) can.

An earlier version of this doc recommended setting `RENV_CONFIG_EXTERNAL_LIBRARIES` to point at the HPC R install's library. That doesn't work: `renv.config.external.libraries` only widens `.libPaths()` for *loading* packages once they're already resolved — it has no effect on `renv::restore()`'s decision about which lockfile entries to (re)install into the private library. `restore()` still tried to rebuild the affected package from source regardless, hitting the identical error. A general fix via `LD_LIBRARY_PATH` (pointed at `R.home("lib")`, set in `.Renviron` so it'd propagate to renv's child R process) was also tried and didn't resolve it either.

Given this is a research project rather than a long-lived service, we didn't chase a general fix further. Instead, `scripts/test-run.sh` just excludes each affected package from `restore()` as it comes up, via its `exclude` argument, using the `RENV_RESTORE_EXCLUDE` variable from `.env` (defaulted to `c("Matrix", "slam")` if `.env` doesn't set it):

```r
renv::restore(exclude = c("Matrix", "slam"))
```

This skips installing those packages into the project's private library, so the project falls back to whatever copy is already on the default library path (R's own bundled `Matrix`, and a binary-installed `slam`). If restore fails with the same `libRblas.so`/`libRlapack.so` error for a different package, add it to the `RENV_RESTORE_EXCLUDE` value in `.env` (or bump the default in `scripts/test-run.sh` directly, since it's shared across machines anyway).

## Adding a new variable

Decide which machine(s) actually need it:

- Needed only when running orchestration scripts from your laptop → `.env`, and add a row to the table above.
- Needed by R itself, and the value differs (or could differ) per machine → that machine's `~/.Renviron`, and add a row to the table above.
