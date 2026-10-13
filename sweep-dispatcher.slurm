#!/bin/bash
# Dispatcher job (see "Dispatcher job" in CONTEXT.md, ADR 0006): runs
# `targets::tar_make()` for the real sweep (`_targets.R`, full model list
# in `models.yml`, default `_targets/` store and `results/` output dir) as
# its own non-GPU `sbatch` job, off spartan's login node. From here it
# drives `crew.cluster`, which submits its own GPU worker `sbatch` jobs
# (nested submission, confirmed permitted on spartan) and waits for them
# over the network - something the login node can't do reliably (ADR
# 0006's Problem section). Sibling of `dispatcher.slurm`, which runs the
# smaller `_test_targets.R` smoke test instead.
#
# sapphire is spartan's general-purpose, non-GPU partition (the dispatcher
# itself never touches the GPU - only the workers it launches do). The
# 43200-minute (30-day) walltime is sapphire's own wall clock limit, not
# derived from the real grid's size (full model list x research questions
# x context variants x granularities x include_headlines, each cell
# capped at `slurm-resources.yml`'s per-worker time_minutes) - it's an
# upper bound, not an estimate of the real sweep's actual wall-clock
# (still unknown; ADR 0006's Consequences section flagged this).
#
# sapphire also caps a user at 15000 jobs; relevant if crew.cluster's
# worker count (nested sbatch submissions from this dispatcher) is ever
# sized close to that.
#
# Submitted from, and runs with working directory equal to, the checkout
# root on spartan (scripts/run-sweep.sh `cd`s there before calling
# `sbatch`) - so `_targets.R`'s relative paths (results/, _targets/) and
# `targets`/`crew.cluster`'s own relative paths (crew-logs/) resolve the
# same way they would if run by hand from that directory.
#SBATCH --job-name=aeolus-sweep-dispatcher
#SBATCH --partition=sapphire
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=43200
#SBATCH --output=dispatcher-logs/%j.log
#SBATCH --error=dispatcher-logs/%j.log

set -euo pipefail

module purge
module load foss/2022a R/4.2.2

Rscript -e 'targets::tar_make()'
