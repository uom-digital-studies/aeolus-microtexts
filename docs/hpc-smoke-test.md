# Real-HPC smoke test for the `targets` pipeline

Manual, one-off validation that `_targets.R` (ADR 0001) can actually submit
and run a job on the real HPC cluster via `crew.cluster` — not a `testthat`
target. Run this once `_targets.R` and `slurm-resources.yml` are in place,
before trusting the pipeline for a real sweep. See ADR 0004 for the
package-install assumption this test is also meant to confirm (shared
filesystem/renv library between submission and compute nodes).

Assumes: `spartan` is aliased in `~/.ssh/config` for the HPC cluster, and
you're running zsh locally.

## 1. Sync the repo to the cluster

If the repo isn't already checked out on `spartan`, clone/pull it there over
SSH:

```zsh
ssh spartan 'git -C ~/aeolus-microtexts pull' || \
  ssh spartan 'git clone <repo-url> ~/aeolus-microtexts'
```

## 2. Install the package on the cluster

Per ADR 0004, workers need `aeolusmicrotexts` formally installed, not
`load_all()`'d. From the login node:

```zsh
ssh spartan 'cd ~/aeolus-microtexts && Rscript -e "renv::restore(); renv::install(\".\")"'
```

## 3. Confirm the smoke-test pipeline is valid

`_test_targets.R` (a trimmed sibling of `_targets.R`, sharing its
controller/target builders from `R/pipeline-orchestration.R`) already
defines a single-row grid — `llama3.2:1b`, `sentiment`, `no_context`,
`sentence`, headlines included — writing to its own `test-results/`
directory and `_test_targets_store` store, so it never touches the real
pipeline's `_targets/` store or `results/` output. No manual editing or
reverting needed; just confirm it's valid before submitting:

```zsh
ssh spartan 'cd ~/aeolus-microtexts && Rscript -e "targets::tar_manifest(script = \"_test_targets.R\", store = \"_test_targets_store\")"'
```

`llama3.2:1b` is the smallest model in `models.yml` and is a reasonable
choice here purely because it minimizes pull time and memory — this is
about proving SLURM submission and Ollama startup work end-to-end, not
about result quality.

## 4. Submit and watch it run

```zsh
ssh spartan 'cd ~/aeolus-microtexts && Rscript -e "targets::tar_make(script = \"_test_targets.R\", store = \"_test_targets_store\")"'
```

In a second terminal, watch the job queue to confirm SLURM actually accepts
and schedules it:

```zsh
ssh spartan 'squeue -u $USER'
```

Once it's running, check the worker log for the `ollama serve` /
`ollama pull llama3.2:1b` startup sequence (path depends on
`crew.cluster`'s log directory config):

```zsh
ssh spartan 'tail -f ~/aeolus-microtexts/crew-logs/*.log'
```

## 5. Confirm the output

```zsh
ssh spartan 'cat ~/aeolus-microtexts/test-results/*.csv'
```

Check the CSV matches the schema in `docs/adr/0003-results-csv-schema.md`
(columns incl. `research_question`, `model`, `context_variant`,
`granularity`, `include_headline`, `microtext`, `unit_index`,
`unit_of_analysis`, `label`, `score`).

## 6. Clean up

`test-results/` and `_test_targets_store/` are gitignored, so nothing to
revert or commit — delete them on the cluster once you're done, e.g. `ssh
spartan 'rm -rf ~/aeolus-microtexts/test-results ~/aeolus-microtexts/_test_targets_store'`.
