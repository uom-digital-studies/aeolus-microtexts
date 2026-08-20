# OMINOUS—FOR (J)IM: A Sentiment Analysis of the *Aeolus* Microtexts

The aim of this project is to explore the microtexts of the *Aeolus* episode as social media content. The key research questions are:

**RQ1**: How is sentiment distributed across the text, according to human, lexicon-based and LLM sentiment analysers?

**RQ2:** Is there a correlation between sentiment polarity/intensity and nationalism in the episode?

**RQ3:** How much do the microtexts resemble contemporary social media content? (Can an LLM be fooled into thinking the mirotexts are UGC?)

## TODO: restructure as a research compendium

Plan: `.posit/assistant/plans/2026-08-13-1630-restructure-aeolus-microtexts-as-research-compendium.md`

Goal: turn this repo into an installable R package (`aeolusmicrotexts`) holding
reusable logic/data/vignettes, with SLURM/HPC infrastructure kept as sibling
files outside the package, eventually deposit-able as an RO-Crate.

- [x] Scaffold package skeleton: `DESCRIPTION`, `NAMESPACE`, `LICENSE`, `LICENSE.md`, `NEWS.md`, `.Rbuildignore`
- [x] Move `load-aeolus.R` content into `R/data.R`; update `load_aeolus()` to default to `system.file("extdata", "7_Aeolus.txt", package = "aeolusmicrotexts")`
- [x] Move `7_Aeolus.txt` into `inst/extdata/`; add TODO note on its edition/extraction provenance
- [x] Refactor `ollama-sentiment-analysis.R`: move `analyse_sentiment_ollama()` and new `run_sentiment_pipeline()` into `R/sentiment-llm.R`; reduce the top-level script to CLI parsing + one call
- [x] Update `submit-sentiment-jobs.sh` to generate/export a shared run-ID/timestamp per sweep; update `run-sentiment-analysis.slurm` and the CLI script to use it in the output path
- [ ] Scaffold `R/nationalism.R`, `R/ugc.R` and give the existing empty `ollama-nationalism-analysis.R`/`ollama-ucg-analysis.R` the thin-wrapper shape (no real logic yet)
- [ ] Build `vignettes/rq1-sentiment.Rmd` from `aeolus-sentiment-analysis.Rmd` (keep all four lexicons, compute joins live, read Ollama results from `inst/extdata/results/`); add `vignettes/rq2-nationalism.Rmd` and `vignettes/rq3-ugc.Rmd` skeletons; retire the old Rmd
- [ ] Add `sync-results.sh` (SSH-alias-based rsync wrapper to pull `results/` down from the HPC cluster)
- [ ] Add `.Rprofile` check warning when the running R version differs from the one recorded in `renv.lock`
- [ ] Update `.gitignore` to also ignore top-level `results/` (only promoted copies under `inst/extdata/results/` are tracked)
- [ ] Rewrite `README.md` to cover package usage (installation, basic example) alongside the HPC/SLURM workflow
- [ ] Run `devtools::document()` to generate `NAMESPACE`/`man/`; sanity-check with `devtools::load_all()`
- [ ] Manually promote one or more curated result CSVs into `inst/extdata/results/` once a sweep has been reviewed

Deferred / out of scope for now: RO-Crate metadata generation, `CITATION.cff` (once the article has a DOI), automated tests/CI/pkgdown, RQ2/RQ3 actual analysis logic, and exact edition/provenance details for `7_Aeolus.txt`.

