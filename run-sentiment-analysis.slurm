#!/bin/bash
#SBATCH --job-name=aeolus-sentiment
#SBATCH --output=logs/%x-%A_%a.out
#SBATCH --error=logs/%x-%A_%a.err
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
# --array is set at submission time by submit-sentiment-jobs.sh, based on
# how many models are listed in the config file.

set -euo pipefail

# Config file (path to a .yml listing `models:`) and this sweep's shared
# run-ID are passed in via `sbatch --export=...` from submit-sentiment-jobs.sh
CONFIG="${CONFIG:?CONFIG environment variable must point to a models .yml file}"
RUN_ID="${RUN_ID:?RUN_ID environment variable must be set (shared per sweep)}"

module load R    # adjust to your cluster's module system
module load ollama

mkdir -p logs results

# Start a per-node Ollama server and make sure it's ready before use
export OLLAMA_HOST=127.0.0.1:11434
ollama serve &
OLLAMA_PID=$!
trap 'kill "$OLLAMA_PID"' EXIT

until ollama list >/dev/null 2>&1; do
  sleep 1
done

# Pick this array task's model (0-indexed) out of the config file
MODEL=$(Rscript -e '
  args <- commandArgs(trailingOnly = TRUE)
  models <- yaml::read_yaml(args[1])$models
  idx <- as.integer(args[2]) + 1L
  if (idx > length(models)) stop("Array index exceeds number of models")
  cat(models[[idx]])
' "$CONFIG" "$SLURM_ARRAY_TASK_ID")

echo "Task $SLURM_ARRAY_TASK_ID running model: $MODEL (run ID: $RUN_ID)"

# Make sure the model is pulled locally before running the analysis
ollama pull "$MODEL"

# Slugify the model name the same way run_sentiment_pipeline()'s R side
# does, so filenames match what the CLI script would generate by default
MODEL_SLUG=$(echo "$MODEL" | sed -E 's/[^A-Za-z0-9._-]+/-/g')
OUTPUT="results/${RUN_ID}_${MODEL_SLUG}-sentiment.csv"

Rscript ollama-sentiment-analysis.R --model "$MODEL" --output "$OUTPUT"
