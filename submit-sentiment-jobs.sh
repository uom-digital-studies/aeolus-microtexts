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

# Single run-ID shared by every task in this sweep, so all models' output
# files can be grouped/identified together.
RUN_ID=$(date +%Y%m%d-%H%M%S)

echo "Submitting $N_MODELS job(s) for models listed in $CONFIG (run ID: $RUN_ID)"
sbatch --array="0-$((N_MODELS - 1))" --export="CONFIG=$CONFIG,RUN_ID=$RUN_ID" run-sentiment-analysis.slurm
