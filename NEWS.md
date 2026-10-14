# aeolusmicrotexts 0.1.5

* Extracted the ADR 0003 results-CSV column check out of `run_pipeline_with_schema()` into its own `validate_results_schema()` in `R/schema-validation.R`. Hardened it to also check `context_variant`/`granularity` against the enum values fixed by ADR 0003 and that `include_headlines` is logical (previously presence-only); `research_question`/`label`/`score` remain unchecked since valid values there are per-schema, not fixed by the ADR.
* Grid cells now checkpoint progress incrementally and resume from disk on walltime kill: `run_pipeline_with_schema()` detects existing output CSVs and skips already-scored units, reducing re-computation when a worker is killed mid-cell. `analyse_with_schema()` now accepts a `skip_indices` parameter to support this resumption logic; skipped rows are simply excluded from its return value, rather than NA-filled and then filtered out downstream.
* `slurm-resources.yml` default `time_minutes` now set to 720 (was accidentally blank, causing workers to be killed ~10 minutes in).
* `ollama_worker_script_lines()` now exports `OLLAMA_CONTEXT_LENGTH=2048` to prevent oversized context windows that slow down large models. (Longest microtext is 361 words long.)
* Dropped `gemma4:26b` from `models.yml` (ollama 0.17.5 doesn't support the gemma4 architecture).
* `scripts/sync-results.sh` now deletes the contents of the remote `dispatcher-logs/`, `ollama-logs/`, and `crew-logs/` directories after syncing them down, so logs don't pile up on spartan across sweeps.

# aeolusmicrotexts 0.1.4

* Fixed a race condition where concurrent GPU workers shared a single `ollama-server.log` file, causing a worker to pick up another model's `OLLAMA_HOST` (or a truncated/interleaved line). `ollama_worker_script_lines()` now writes each worker's server log to a per-model, per-SLURM-job path under `ollama-logs/`.
* Implemented ADR 0007: the dispatcher now pulls all models into the shared model store once via `pull_models()` (`R/model-pull.R`) before any worker launches, writing a `models.csv` manifest (model + digest) for traceability; GPU workers no longer pull models themselves, only verify presence via `ollama show` and fail fast if a model is missing. Removed the old central model-store/`source` column machinery in favour of a single `model_store_dir()`.

# aeolusmicrotexts 0.1.3

* Fixed issue passing temperature parameter to Ollama

# aeolusmicrotexts 0.1.2

* `dispatcher_host()` added to try and fix dns issues when jobs are managed on HPC

# aeolusmicrotexts 0.1.1

* `build_slurm_controllers()` now captures each SLURM worker's stdout/stderr to `crew-logs/<model>_<job id>.log` instead of letting `crew.cluster` discard it to `/dev/null`, so a stalled or vanished worker job can actually be diagnosed.
* Completed data pipeline to implement key elements of ADR 0003. The `unit_of_analysis` and `include_headlines` conditions can now be elegantly crossed when the data is constituted for a run.
* `run_pipeline_with_schema()` (and the `run_sentiment_pipeline()`/`run_nationalism_pipeline()` wrappers) now call `load_aeolus(granularity, include_headlines)` and write output matching the ADR 0003 CSV schema exactly, instead of the previous broken/ad hoc columns.
* Added a `targets` + `crew.cluster` pipeline (ADR 0001): root-level `_targets.R` is a thin wrapper around the functions `build_slurm_controllers()` and `build_grid_targets()`. The pipeline creates a separate worker for each model in the run.
* Added a smoke test procedure

# aeolusmicrotexts 0.1.0

* Initial package scaffold.
