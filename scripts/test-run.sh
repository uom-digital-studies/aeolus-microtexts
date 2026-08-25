#!/usr/bin/env bash
# Drives the automatable steps of the real-HPC smoke test
# (docs/hpc-smoke-test.md): sync the repo to the cluster, (re)install
# aeolusmicrotexts there (ADR 0004), then submit `_test_targets.R`'s
# single-model/single-cell grid via `crew.cluster` and block until it
# finishes. `_test_targets.R` writes to its own `test-results/` dir and
# `_test_targets_store` store, so this never touches the real pipeline's
# `_targets/` store or `results/` output (docs/hpc-smoke-test.md, step 3-4).
#
# What this script does NOT do, because they're genuinely manual/
# interactive (see docs/hpc-smoke-test.md for the full steps): watching
# `squeue`/worker logs while the job runs, inspecting the output CSV
# against the schema in docs/adr/0003-results-csv-schema.md, and cleaning
# up test-results/_test_targets_store afterwards. Reminders for those are
# printed below.
#
# Assumes: `spartan` is aliased in `~/.ssh/config` for the HPC cluster
# (override via the SPARTAN_HOST env var), and this is run from the repo
# root.
set -euo pipefail

HOST="${SPARTAN_HOST:-spartan}"
REMOTE_DIR="${SPARTAN_REMOTE_DIR:-~/aeolus-microtexts}"
REPO_URL="$(git config --get remote.origin.url)"

echo "==> Syncing repo to ${HOST}:${REMOTE_DIR}"
ssh "$HOST" "git -C ${REMOTE_DIR} pull" \
  || ssh "$HOST" "git clone ${REPO_URL} ${REMOTE_DIR}"

echo "==> Installing aeolusmicrotexts on ${HOST} (ADR 0004: formally installed, not load_all())"
ssh "$HOST" "cd ${REMOTE_DIR} && Rscript -e 'renv::restore(); renv::install(\".\")'"

echo "==> Validating _test_targets.R before submitting"
ssh "$HOST" "cd ${REMOTE_DIR} && Rscript -e 'targets::tar_manifest(script = \"_test_targets.R\", store = \"_test_targets_store\")'"

cat <<EOF

==> About to submit. In another terminal, you can watch:
      ssh ${HOST} 'squeue -u \$USER'
      ssh ${HOST} 'tail -f ${REMOTE_DIR}/crew-logs/*.log'

EOF

echo "==> Submitting _test_targets.R (blocks until the pipeline finishes)"
ssh "$HOST" "cd ${REMOTE_DIR} && Rscript -e 'targets::tar_make(script = \"_test_targets.R\", store = \"_test_targets_store\")'"

cat <<EOF

==> Done. Remaining manual steps (docs/hpc-smoke-test.md, steps 5-6):
      - Confirm the output:
          ssh ${HOST} 'cat ${REMOTE_DIR}/test-results/*.csv'
        and check it matches the schema in docs/adr/0003-results-csv-schema.md.
      - Clean up (test-results/ and _test_targets_store/ are gitignored,
        nothing to revert/commit, just delete on the cluster when done):
          ssh ${HOST} 'rm -rf ${REMOTE_DIR}/test-results ${REMOTE_DIR}/_test_targets_store'
EOF
