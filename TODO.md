# TODO

[ ] Refactor `ugc.R`, `sentiment-llm.R` and `nationalism.R` to clearly distinguish the schema for each research question from the logic of applying it to the data; use test-driven development, setting up tests that mock the LLM output locally
[ ] Build `_targets.R` + `slurm-resources.yml` (root-level, per ADR 0001); retire `submit-sentiment-jobs.sh`/`run-sentiment-analysis.slurm`/`ollama-*.R` once validated; use test-driven development, setting up local dockert for testing slurm job allocation locally
[ ] Add `sync-results.sh` (SSH-alias-based rsync wrapper to pull `results/` down from the HPC cluster)
[ ] Add `.Rprofile` check warning when the running R version differs from the one recorded in `renv.lock`
[ ] Update `.gitignore` to also ignore top-level `results/` (only promoted copies under `inst/extdata/results/` are tracked)
[ ] Rewrite `README.md` to cover package usage (installation, basic example) alongside the HPC/SLURM workflow
[ ] Manually promote one or more curated result CSVs into `inst/extdata/results/` once a sweep has been reviewed
