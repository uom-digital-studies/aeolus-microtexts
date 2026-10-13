# aeolusmicrotexts 0.1.3

* Fixed issue passing temperature parameter to Ollama

# aeolusmicrotexts 0.1.2

# aeolusmicrotexts 0.1.1

* `dispatcher_host()` added to try and fix dns issues when jobs are managed on HPC
* `build_slurm_controllers()` now captures each SLURM worker's stdout/stderr to `crew-logs/<model>_<job id>.log` instead of letting `crew.cluster` discard it to `/dev/null`, so a stalled or vanished worker job can actually be diagnosed.
* Completed data pipeline to implement key elements of ADR 0003. The `unit_of_analysis` and `include_headlines` conditions can now be elegantly crossed when the data is constituted for a run.
* `run_pipeline_with_schema()` (and the `run_sentiment_pipeline()`/`run_nationalism_pipeline()` wrappers) now call `load_aeolus(granularity, include_headlines)` and write output matching the ADR 0003 CSV schema exactly, instead of the previous broken/ad hoc columns.
* Added a `targets` + `crew.cluster` pipeline (ADR 0001): root-level `_targets.R` is a thin wrapper around the functions `build_slurm_controllers()` and `build_grid_targets()`. The pipeline creates a separate worker for each model in the run.
* Added a smoke test procedure

# aeolusmicrotexts 0.1.0

* Initial package scaffold.
