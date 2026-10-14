# TODO

[x] Refactor `ugc.R`, `sentiment-llm.R` and `nationalism.R` to clearly distinguish the schema for each research question from the logic of applying it to the data; use test-driven development, setting up tests that mock the LLM output locally
[x] Implement `granularity`/`include_headline` branching in `load_aeolus()`/`tokenise_microtexts_by_sentence()` (currently always sentence-tokenises with headlines retained)
[x] Update `run_pipeline_with_schema()` to emit the results-CSV schema in `docs/adr/0003-results-csv-schema.md` (self-describing columns incl. `research_question`, raw `model`, `context_variant`, `granularity`, `include_headline`, `microtext`, `unit_index`, `unit_of_analysis`, `label`, `score`)
[x] Build `_targets.R` + `slurm-resources.yml` (root-level, per ADR 0001), TDD-ing `R/pipeline-grid.R`/`R/slurm-resources.R`
[x] Get rid of `renv`. It's causing issues. Let's just rely on the R package to run, and not worry about versioning.
[x] Run the real-HPC smoke test (`_test_targets.R` via `scripts/test-run.sh`), before trusting the pipeline for a real sweep
[x] Audit remaining env vars (e.g. `OLLAMA_MODELS_DIR`) against `docs/environment-variables.md`'s `.env`/`~/.Renviron` split; document any still missing
[x] Rewrite `scripts/run-sweep.sh` so that it dispatches the job locally from laptop, using `sapphire` as the remote job dispathcing node, like `scripts/test-run.sh`
[x] Add `sync-results.sh` (SSH-alias-based rsync wrapper to pull `results/` down from the HPC cluster)
[x] Update `.gitignore` to also ignore top-level `results/` (only promoted copies under `inst/extdata/results/` are tracked)
[ ] Rewrite `README.md` to cover package usage (installation, basic example) alongside the HPC/SLURM workflow, with a high-level explanation for researchers/reviewers wanting to reproduce this analysis (see `docs/environment-variables.md` for the env-var setup split)
[ ] Manually promote one or more curated result CSVs into `inst/extdata/results/` once a sweep has been reviewed
[x] Remove the central model store from the project (`source` field in `models.yml`/`read_models()`, `resolve_ollama_models_dir()`'s `central` branch, `OLLAMA_CENTRAL_MODELS_DIR` in `.Renviron-hpc`/`docs/environment-variables.md`, matching tests/docs); it caused bugs and is no longer used
[ ] Size `sweep-dispatcher.slurm`'s walltime (currently a 1440-min placeholder) against the real grid once a sweep's actual wall-clock is known
[x] Decide whether `validate_results_schema()` (R/schema-validation.R) should stay presence-only (current behavior) or also validate types/enum values (e.g. `granularity %in% c("microtext","sentence")`, `include_headlines` is logical) — now validates `context_variant`/`granularity` enums (fixed by ADR 0003) and `include_headlines` type; `research_question`/`label`/`score` left unchecked since valid values are per-schema (see `new_rq_schema()`), not fixed by the ADR
