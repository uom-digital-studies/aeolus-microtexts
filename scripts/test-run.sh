#!/usr/bin/env bash
# Drives the automatable steps of the real-HPC smoke test: push the repo
# to the cluster directly from
# this laptop (the HPC never talks to GitHub; it's just a `git push`
# target, kept in sync via a bare repo + post-receive hook), (re)install
# aeolusmicrotexts there (ADR 0004), then submit `_test_targets.R`'s
# single-model/single-cell grid as its own non-blocking `sbatch`
# dispatcher job (`dispatcher.slurm`, ADR 0006) and exit - it does not
# wait for that job to finish. `_test_targets.R` writes to its own
# `test-results/` dir and `_test_targets_store` store, so this never
# touches the real pipeline's `_targets/` store or `results/` output (the
# install + submit steps below).
#
# IMPORTANT: `git push` only sends *committed* changes. Commit (or at
# least `git add` + commit) local edits before running this script, or
# the HPC will build against stale code.
#
# What this script does NOT do, because they're genuinely manual/
# interactive, or because the dispatcher job itself is now fire-and-
# forget (ADR 0006): watching `squeue`/job logs while it runs, inspecting
# the output CSV against the schema in docs/adr/0003-results-csv-schema.md,
# cancelling the job, and cleaning up test-results/_test_targets_store
# afterwards. Reminders for those are printed below.
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
ssh "$HOST" "cd ${REMOTE_DIR} && module load foss/2022a R/4.2.2 && Rscript -e 'if (!requireNamespace(\"pak\", quietly = TRUE)) install.packages(\"pak\", repos = sprintf(\"https://r-lib.github.io/p/pak/stable/%s/%s/%s\", .Platform\$pkgType, R.Version()\$os, R.Version()\$arch)); pak::pkg_install(\".\")'"

echo "==> Validating _test_targets.R before submitting"
ssh "$HOST" "cd ${REMOTE_DIR} && module load foss/2022a R/4.2.2 && Rscript -e 'targets::tar_manifest(script = \"_test_targets.R\")'"

echo "==> Submitting dispatcher.slurm (fire-and-forget; see ADR 0006)"
ssh "$HOST" "cd ${REMOTE_DIR} && mkdir -p dispatcher-logs"
JOB_ID="$(ssh "$HOST" "cd ${REMOTE_DIR} && sbatch --parsable dispatcher.slurm")"

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
      - Confirm the output:
          ssh ${HOST} 'cat ${REMOTE_DIR}/test-results/*.csv'
        and check it matches the schema in docs/adr/0003-results-csv-schema.md.
      - Clean up (test-results/, _test_targets_store/, crew-logs/, and
        dispatcher-logs/ are all gitignored, nothing to revert/commit,
        just delete on the cluster when done):
          ssh ${HOST} 'rm -rf ${REMOTE_DIR}/test-results ${REMOTE_DIR}/_test_targets_store ${REMOTE_DIR}/crew-logs ${REMOTE_DIR}/dispatcher-logs'
EOF
