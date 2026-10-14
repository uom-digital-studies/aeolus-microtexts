#!/bin/bash
# Dispatcher job (see "Dispatcher job" in CONTEXT.md, ADR 0006): runs
# `targets::tar_make()` for the real-HPC smoke test as its own non-GPU
# `sbatch` job, off spartan's login node. From here it drives
# `crew.cluster`, which submits its own GPU worker `sbatch` jobs (nested
# submission, confirmed permitted on spartan) and waits for them over the
# network - something the login node can't do reliably (ADR 0006's
# Problem section).
#
# Resources below are hand-picked for the smoke test specifically
# (`_test_targets.R`'s single model/single cell): sapphire is spartan's
# general-purpose, non-GPU partition (the dispatcher itself never touches
# the GPU - only the workers it launches do), and the 150-minute walltime
# is comfortably above the single worker's 120-minute cap in
# slurm-resources.yml. Revisit both once a dispatcher job needs to size
# itself against a real multi-model run-sweep.sh sweep.
#
# Submitted from, and runs with working directory equal to, the checkout
# root on spartan (scripts/test-run.sh `cd`s there before calling
# `sbatch`) - so `_test_targets.R`'s relative paths (test-results/,
# _test_targets_store/) and `targets`/`crew.cluster`'s own relative paths
# (crew-logs/) resolve the same way they would if run by hand from that
# directory.
#
# IMPORTANT: One dispatcher per model store. Running two sweeps concurrently
# against the same model store leads to race conditions (multiple pulls of the
# same model, interleaved list operations, etc.). Use separate model store
# directories for parallel runs, or allow one to complete before starting another.
#
#SBATCH --job-name=aeolus-dispatcher
#SBATCH --partition=sapphire
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=150
#SBATCH --output=dispatcher-logs/%j.log
#SBATCH --error=dispatcher-logs/%j.log

set -euo pipefail

module purge
module load GCCcore/11.3.0
module load ollama/0.17.5-CUDA-12.8.0
module load foss/2022a R/4.2.2

Rscript -e 'targets::tar_make(script = "_test_targets.R", store = "_test_targets_store")'
