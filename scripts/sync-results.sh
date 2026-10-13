#!/usr/bin/env bash
# Pulls the real pipeline's `results/` directory down from spartan via
# rsync, for local review before any curated CSV is promoted into
# `inst/extdata/results/` (TODO.md). One-way, spartan -> laptop; never
# pushes anything back. Safe to re-run - rsync only transfers new/changed
# files - and safe to run while a sweep is still in progress, to check on
# partial output (results/<run_id>/... is written incrementally, one CSV
# per grid cell).
#
# Assumes: `spartan` is aliased in `~/.ssh/config` for the HPC cluster
# (override via the SPARTAN_HOST env var), and this is run from the repo
# root.
set -euo pipefail

source .env

HOST="${SPARTAN_HOST:-spartan}"
REMOTE_DIR="${SPARTAN_REMOTE_DIR:-~/aeolus-microtexts}"

mkdir -p results

echo "==> Syncing ${HOST}:${REMOTE_DIR}/results/ -> ./results/"
rsync -avz --progress "${HOST}:${REMOTE_DIR}/results/" "results/"

cat <<EOF

==> Synced. Review against docs/adr/0003-results-csv-schema.md before
    promoting any curated CSV into inst/extdata/results/ (manual step,
    TODO.md) - full run output under results/ stays local/gitignored.
EOF
