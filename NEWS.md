# aeolusmicrotexts 0.3.0

* In `_targets.R`, target `run_id` now always runs.
* Added `R/globals.R` declaring `models_pulled`, `run_id` and `map` as global variables, silencing R CMD check notes.
* `crew` moved from Imports to Suggests: the package never calls it, only `_targets.R` does (via `crew::`).
* `scripts/submit-structured-output-probe.R` now uses `read_models()`, `read_slurm_resources()` and `resolve_slurm_resources()` instead of ad-hoc YAML parsing.
* New `list_runs()`, `read_run()` and `read_run_metadata()` access promoted runs in `inst/extdata/results/<run_id>/`. `list_runs()` errors on malformed run directories.
* First promoted run added: `20261019-131523_v0.2.0.9000`.
* ADR 0003 amended for the promoted-run layout.

# aeolusmicrotexts 0.2.0

* **Prompt change affecting results (ADR 0008); results from earlier runs aren't comparable.** Neither ellmer nor Ollama shows the structured-output schema to the model, so field descriptions (incl. score ranges) were never read. The system prompt is now context variant + task instruction + output specification. The output specification is a new `build_output_spec()` that renders each field's name, description, and allowed values or type. The user turn now puts the unit under a `## The text` heading (new `build_user_turn()`); results CSVs still record the bare unit.
* New `preview_prompt()` prints the system prompt, user turn, and JSON Schema (marked as constraining tokens only) for any RQ schema and context variant.
* Documented how structured output reaches the model, and why `score` may depend on `label`, in `docs/structured-output.md`; `@details` note on each RQ schema. Added `jsonlite` to Imports.

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
