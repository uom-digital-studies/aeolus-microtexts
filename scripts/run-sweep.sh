#!/usr/bin/env bash
# Reinstall aeolusmicrotexts (per ADR 0004 — workers must load an installed
# copy, never devtools::load_all()) before every tar_make(), so a sweep
# never accidentally runs against a stale installed version. Run from the
# repo root.
set -euo pipefail

Rscript -e 'pak::pkg_install(".", ask = FALSE)'
Rscript -e 'targets::tar_make()'
