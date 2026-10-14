#!/bin/bash
# One-off feasibility check: can a non-GPU `sapphire` job (where the
# dispatcher job runs) pull Ollama models? The planned race-condition fix
# has the dispatcher pull every model once before any worker starts, which
# assumes sapphire nodes (1) can load the ollama module, (2) can start
# Spartan's `run_ollama_server` wrapper, (3) reach the Ollama registry, and
# (4) that `ollama show` distinguishes present from missing models (the
# workers' planned presence check).
#
# Pulls into a throwaway temp dir, never the project model store, so it's
# safe to run alongside anything. Run from the checkout root on spartan:
#
#   sbatch scripts/check-sapphire-pull.slurm
#
# then read check-sapphire-pull_<jobid>.log; the last block summarises
# PASS/FAIL per step.
#SBATCH --job-name=aeolus-check-sapphire-pull
#SBATCH --partition=sapphire
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=30
#SBATCH --output=check-sapphire-pull_%j.log
#SBATCH --error=check-sapphire-pull_%j.log

# No `set -e`: every step should run and report, not abort on first failure.
set -uo pipefail

TEST_MODEL=llama3.2:1b
declare -A RESULT

report() { RESULT[$1]=$2; echo "== $1: $2"; }

module purge
if module load GCCcore/11.3.0 && module load ollama/0.17.5-CUDA-12.8.0; then
  report module_load PASS
else
  report module_load FAIL
fi
command -v ollama && command -v run_ollama_server

REGISTRY_STATUS=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 https://registry.ollama.ai/v2/)
echo "registry HTTP status: $REGISTRY_STATUS"
# Any HTTP response (even 401/404) proves outbound network; 000 means none.
if [ "$REGISTRY_STATUS" != "000" ]; then report internet PASS; else report internet FAIL; fi

export OLLAMA_MODELS=$(mktemp -d "${TMPDIR:-/tmp}/ollama-check.XXXXXX")
OLLAMA_LOG=$(mktemp "${TMPDIR:-/tmp}/ollama-check-log.XXXXXX")
echo "OLLAMA_MODELS=$OLLAMA_MODELS"

run_ollama_server > "$OLLAMA_LOG" 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null; rm -rf "$OLLAMA_MODELS" "$OLLAMA_LOG"' EXIT

for i in $(seq 1 30); do grep -aq 'OLLAMA_HOST=' "$OLLAMA_LOG" && break; sleep 2; done
export OLLAMA_HOST=$(grep -aoE 'OLLAMA_HOST=\S+' "$OLLAMA_LOG" | head -1 | cut -d= -f2)
echo "OLLAMA_HOST=$OLLAMA_HOST"

READY=0
if [ -n "$OLLAMA_HOST" ]; then
  for i in $(seq 1 30); do curl -sf "http://${OLLAMA_HOST}/" && READY=1 && break; sleep 2; done
fi
if [ "$READY" = 1 ]; then report server_start PASS; else report server_start FAIL; fi

if [ "$READY" = 1 ]; then
  if ollama show "$TEST_MODEL" > /dev/null 2>&1; then
    report show_missing_fails FAIL
  else
    report show_missing_fails PASS
  fi

  if ollama pull "$TEST_MODEL"; then report pull PASS; else report pull FAIL; fi

  if ollama show "$TEST_MODEL" > /dev/null 2>&1; then
    report show_present_succeeds PASS
  else
    report show_present_succeeds FAIL
  fi
  ollama list
fi

echo "---- server log ----"
cat "$OLLAMA_LOG"

echo "---- summary ----"
for step in module_load internet server_start show_missing_fails pull show_present_succeeds; do
  echo "$step: ${RESULT[$step]:-NOT RUN}"
done
