# TODO

[x] Refactor `ugc.R`, `sentiment-llm.R` and `nationalism.R` to clearly distinguish the schema for each research question from the logic of applying it to the data; use test-driven development, setting up tests that mock the LLM output locally
[x] Implement `granularity`/`include_headline` branching in `load_aeolus()`/`tokenise_microtexts_by_sentence()` (currently always sentence-tokenises with headlines retained)
[x] Update `run_pipeline_with_schema()` to emit the results-CSV schema in `docs/adr/0003-results-csv-schema.md` (self-describing columns incl. `research_question`, raw `model`, `context_variant`, `granularity`, `include_headline`, `microtext`, `unit_index`, `unit_of_analysis`, `label`, `score`)
[ ] Build `_targets.R` + `slurm-resources.yml` (root-level, per ADR 0001), TDD-ing `R/pipeline-grid.R`/`R/slurm-resources.R` (scaffold-only so far)
[ ] Run the real-HPC smoke test per `docs/hpc-smoke-test.md` once `_targets.R` is implemented, before trusting the pipeline for a real sweep
[ ] Add `sync-results.sh` (SSH-alias-based rsync wrapper to pull `results/` down from the HPC cluster)
[ ] Add `.Rprofile` check warning when the running R version differs from the one recorded in `renv.lock`
[ ] Update `.gitignore` to also ignore top-level `results/` (only promoted copies under `inst/extdata/results/` are tracked)
[ ] Rewrite `README.md` to cover package usage (installation, basic example) alongside the HPC/SLURM workflow
[ ] Manually promote one or more curated result CSVs into `inst/extdata/results/` once a sweep has been reviewed
