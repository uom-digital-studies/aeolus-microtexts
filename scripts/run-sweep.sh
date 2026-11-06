#!/usr/bin/env bash
# Drives the automatable steps of a real sweep: push the repo to the
# cluster directly from this laptop (the HPC never talks to GitHub; it's
# just a `git push` target, kept in sync via a bare repo + post-receive
# hook), (re)install aeolusmicrotexts there (ADR 0004), then submit
# `_targets.R`'s full grid (model list in `models.yml`) as its own
# non-blocking `sbatch` dispatcher job (`sweep-dispatcher.slurm`, ADR
# 0006) and exit - it does not wait for that job to finish. Sibling of
# `scripts/test-run.sh`, which runs the smaller `_test_targets.R` smoke
# test instead; this script writes to the real pipeline's `results/`
# output dir and `_targets/` store.
#
# IMPORTANT: One run at a time per model store. Running two sweeps
# concurrently against the same model store leads to race conditions
# (multiple pulls of the same model, interleaved list operations, etc.).
# Use separate model store directories for parallel runs, or allow one
# to complete before starting another (ADR 0007).
#
# IMPORTANT: `git push` only sends *committed* changes. Commit (or at
# least `git add` + commit) local edits before running this script, or
# the HPC will build against stale code.
#
# What this script does NOT do, because they're genuinely manual/
# interactive, or because the dispatcher job itself is now fire-and-
# forget (ADR 0006): watching `squeue`/job logs while it runs, inspecting
# the output CSVs against the schema in docs/adr/0003-results-csv-schema.md,
# cancelling the job, and promoting reviewed results into
# inst/extdata/results/ afterwards. Reminders for those are printed below.
#
# Assumes: `spartan` is aliased in `~/.ssh/config` for the HPC cluster
# (override via the SPARTAN_HOST env var), and this is run from the repo
# root.
set -euo pipefail

source .env

HOST="${SPARTAN_HOST:-spartan}"
REMOTE_DIR="${SPARTAN_REMOTE_DIR:-~/aeolus-microtexts}"
BARE_DIR="${SPARTAN_GIT_DIR:-~/aeolus-microtexts.git}"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

echo "==> Ensuring bare repo exists on ${HOST}:${BARE_DIR}"
ssh "$HOST" "mkdir -p ${BARE_DIR} && git init --bare -q ${BARE_DIR} && mkdir -p ${REMOTE_DIR}"

echo "==> Installing post-receive hook (checks out the pushed branch into ${REMOTE_DIR})"
ssh "$HOST" "cat > ${BARE_DIR}/hooks/post-receive && chmod +x ${BARE_DIR}/hooks/post-receive" <<HOOK
#!/bin/sh
set -eu
while read -r oldrev newrev refname; do
  branch=\$(echo "\$refname" | sed 's#refs/heads/##')
  git --git-dir="${BARE_DIR}" --work-tree="${REMOTE_DIR}" checkout -f "\$branch"
done
HOOK

echo "==> Pointing local git remote 'hpc' at ${HOST}:${BARE_DIR}"
if git remote get-url hpc >/dev/null 2>&1; then
  git remote set-url hpc "${HOST}:${BARE_DIR}"
else
  git remote add hpc "${HOST}:${BARE_DIR}"
fi

echo "==> Pushing ${BRANCH} to ${HOST}:${BARE_DIR}"
git push hpc "${BRANCH}"

echo "==> Uploading .Renviron-hpc to ${HOST}:${REMOTE_DIR} (git push never carries it; it's gitignored)"
[ -f .Renviron-hpc ] || { echo ".Renviron-hpc not found in repo root - see docs/environment-variables.md" >&2; exit 1; }
scp .Renviron-hpc "${HOST}:${REMOTE_DIR}/.Renviron"

echo "==> Creating personal library on ${HOST} (ADR 0005: no renv, install straight from DESCRIPTION; path must match .Renviron-hpc's R_LIBS_USER)"
ssh "$HOST" "mkdir -p ~/R/library"

echo "==> Installing aeolusmicrotexts on ${HOST} (ADR 0004: formally installed, not load_all())"
ssh "$HOST" "cd ${REMOTE_DIR} && module load foss/2024a R/4.6.1 && Rscript -e 'if (!requireNamespace(\"pak\", quietly = TRUE)) install.packages(\"pak\", repos = sprintf(\"https://r-lib.github.io/p/pak/stable/%s/%s/%s\", .Platform\$pkgType, R.Version()\$os, R.Version()\$arch)); pak::pkg_install(\".\")'"

echo "==> Validating _targets.R before submitting"
ssh "$HOST" "cd ${REMOTE_DIR} && module load foss/2024a R/4.6.1 && Rscript -e 'targets::tar_manifest(script = \"_targets.R\")'"

echo "==> Submitting sweep-dispatcher.slurm (fire-and-forget; see ADR 0006)"
ssh "$HOST" "cd ${REMOTE_DIR} && mkdir -p dispatcher-logs"
JOB_ID="$(ssh "$HOST" "cd ${REMOTE_DIR} && sbatch --parsable sweep-dispatcher.slurm")"

cat <<EOF

==> Submitted dispatcher job ${JOB_ID}. This script does not wait for it
    to finish - everything from here is manual.

    Watch it:
      ssh ${HOST} 'squeue -u \$USER'
      ssh ${HOST} 'tail -f ${REMOTE_DIR}/dispatcher-logs/${JOB_ID}.log'
      ssh ${HOST} 'tail -f ${REMOTE_DIR}/crew-logs/*.log'

    Cancel it (and let any worker jobs it already launched run to
    completion/timeout on their own - no automatic cleanup, ADR 0006):
      ssh ${HOST} 'scancel ${JOB_ID}'

    Once it finishes:
      - Review the output:
          ssh ${HOST} 'ls ${REMOTE_DIR}/results'
        and check it matches the schema in docs/adr/0003-results-csv-schema.md.
      - Pull reviewed results down (sync-results.sh) and manually
        promote curated CSVs into inst/extdata/results/ once reviewed -
        full run output is never committed directly.
EOF
