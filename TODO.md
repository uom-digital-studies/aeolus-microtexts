# TODO

[x] Refactor `ugc.R`, `sentiment-llm.R` and `nationalism.R` to clearly distinguish the schema for each research question from the logic of applying it to the data; use test-driven development, setting up tests that mock the LLM output locally
[x] Implement `granularity`/`include_headline` branching in `load_aeolus()`/`tokenise_microtexts_by_sentence()` (currently always sentence-tokenises with headlines retained)
[x] Update `run_pipeline_with_schema()` to emit the results-CSV schema in `docs/adr/0003-results-csv-schema.md` (self-describing columns incl. `research_question`, raw `model`, `context_variant`, `granularity`, `include_headline`, `microtext`, `unit_index`, `unit_of_analysis`, `label`, `score`)
[x] Build `_targets.R` + `slurm-resources.yml` (root-level, per ADR 0001), TDD-ing `R/pipeline-grid.R`/`R/slurm-resources.R`
[ ] Run the real-HPC smoke test per `docs/hpc-smoke-test.md` (`_test_targets.R` via `scripts/test-run.sh`), before trusting the pipeline for a real sweep
[ ] Confirm `mistral` (in `models.yml`) is actually available — it's absent from the central Ollama model store listed in `ollama/2025README.md`; either pull it into `OLLAMA_MODELS_DIR` (needs compute-node internet access, unconfirmed) or swap it for a model already in the central store
[ ] Choose the right SLURM partition for the real sweep — `slurm-resources.yml`'s `gpu-a100-short` default is only good for the ~30 min smoke test
[ ] `scripts/test-run.sh`/`scripts/run-sweep.sh` currently run `Rscript`/`tar_make()` directly on the login node (via bare `ssh`, no `sbatch`/`sinteractive`) — fix per the cluster's "do not run programs on the login node" policy before the real sweep
[ ] Add `sync-results.sh` (SSH-alias-based rsync wrapper to pull `results/` down from the HPC cluster)
[ ] Add `.Rprofile` check warning when the running R version differs from the one recorded in `renv.lock`
[ ] Update `.gitignore` to also ignore top-level `results/` (only promoted copies under `inst/extdata/results/` are tracked)
[ ] Rewrite `README.md` to cover package usage (installation, basic example) alongside the HPC/SLURM workflow
[ ] Manually promote one or more curated result CSVs into `inst/extdata/results/` once a sweep has been reviewed
