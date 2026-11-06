# Drop `renv` in favor of direct install from `DESCRIPTION` via `pak`

## Context

This code is designed to run on an HPC, where the developer cannot directly install basic software. The HPC documentation initially suggested that the latest version of R available on the server was 4.2.2. It transpires that 4.6.1 is available (at the time of writing).

## Problem

`renv` was pinning R 4.2.2 and all dependencies via `renv.lock`, activated through `.Rprofile`. It caused ongoing HPC friction:

1. Several packages whose compiled code links against R's own BLAS/LAPACK (`Matrix`, `slam`) fail to rebuild from source on spartan's `foss/2022a` EasyBuild toolchain (known upstream issue, unresolved).
2. We tried several solutions, including using the `ignore` argument of `renv::restore`, and adding to the PATH to help `renv` find R's BLAS/LAPACK installations. But these solutions didn't actually work.
3. The `.Rprofile` activation adds complexity, particularly around verifying whether a running R session is using the right version (checked on every startup, easy to miss when versions differ).

Meanwhile, the research goal (LLM-based output analysis) makes strict package-version reproducibility a lower priority:

- LLM outputs are non-deterministic across runs by design (different seeds, model variants, inference parameters).
- Bit-reproducible, version-pinned package environments buy little when the main computational outputs aren't reproducible.
- A future re-run's dependency versions (whatever CRAN/P3M serve at that time) are acceptable for a research project — if strict pinning becomes critical later, a dated Posit Public Package Manager (P3M) snapshot URL can be used instead.

## Decision

Install the package and its `DESCRIPTION`-declared dependencies directly, with no lockfile. The mechanism: `pak::pkg_install(".")` instead of `renv::install(".")`. This resolves `Imports`/`Suggests` from `DESCRIPTION` and pulls prebuilt binaries from P3M where available, sidestepping source compiles in many cases.

**New HPC requirement:** A personal, writable R library in the user's home area (`~/R/library`), created once per user per HPC machine. The module-provided R library is shared/read-only, so `pak::pkg_install(".")` (and `pak` itself) must land somewhere writable. Without this, `install.packages()` fails outright or hangs in a non-interactive SLURM context. Set `R_LIBS_USER=~/R/library` in the HPC's `~/.Renviron` so it propagates to all `Rscript` calls.

## Changes

- Deleted `renv.lock`, `renv/` (directory), `.Rprofile`.
- Updated `scripts/test-run.sh` to create `~/R/library` once, then install via `pak::pkg_install(".")` with `R_LIBS_USER` set.
- Updated `scripts/run-sweep.sh` to install via `pak::pkg_install(".", ask = FALSE)` (laptop already has a default personal library).
- Updated header comments and docs to reflect the new install command.
- Documented `R_LIBS_USER` as a required `~/.Renviron` variable (HPC-only).

## Trade-offs

**Accepted:**
- No exact reproducibility of dependency versions — a future re-run gets whatever CRAN/P3M currently serves.
- Laptop and HPC must both have `pak` available (one-time prerequisite, documented, not scripted — same category as having R/git available).

**Retained:**
- Formal package installation (ADR 0004 principle still holds) — `targets` caching and `crew.cluster` worker visibility require it.
- Personal library isolation on the HPC — `R_LIBS_USER` creates a per-user writable space, avoiding conflicts across user projects or cluster-wide system changes.

## If strict pinning is needed later

Add a dated P3M snapshot URL to `options(repos = ...)` in `~/.Renviron`, or commit a separate `repos.R` file that sets it at startup. This avoids reintroducing `renv`, which carries the same HPC friction. A snapshot URL provides version-pinning without per-project private libraries or lockfile management.
