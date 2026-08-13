#!/bin/bash
# Usage: ./submit-sentiment-jobs.sh [config.yml]
# Reads the `models:` array from config.yml, then submits a SLURM job array
# with one task per model.
set -euo pipefail

CONFIG="${1:-models.yml}"

N_MODELS=$(Rscript -e '
  cat(length(yaml::read_yaml(commandArgs(trailingOnly = TRUE)[1])$models))
' "$CONFIG")

if [[ "$N_MODELS" -lt 1 ]]; then
  echo "No models found in $CONFIG" >&2
  exit 1
fi

echo "Submitting $N_MODELS job(s) for models listed in $CONFIG"
sbatch --array="0-$((N_MODELS - 1))" --export="CONFIG=$CONFIG" run-sentiment-analysis.slurm
