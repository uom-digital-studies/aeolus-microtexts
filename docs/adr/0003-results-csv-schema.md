# Results CSVs use one self-describing long-format row schema across the whole sweep

The pipeline sweep crosses research question × model × context variant × unit of analysis (granularity × include_headline). The previous ad hoc format wrote one CSV per (model, research question) pair, with columns `section, sentence, <rq>_label, <rq>_score`; `context_variant`, `granularity`, and `include_headline` existed only as function parameters, never landing in the file or filename, and `model`/research question were recoverable only by parsing the filename. This made files impossible to safely concatenate or reason about once multiple context variants, granularities, or SLURM-array splits entered the picture.

We chose a single canonical long-format schema, written identically regardless of how many files a sweep is split across (one combined CSV, one per grid cell, one per SLURM array task — the split granularity is an operational choice with no effect on structure):

| column | meaning |
|---|---|
| `research_question` | `"sentiment"` \| `"nationalism"` \| `"ugc"` (the schema name) |
| `model` | raw Ollama model identifier as passed to the chat backend, e.g. `"llama3.2:1b"` (not the filesystem-safe slug used in filenames) |
| `context_variant` | `"no_context"` \| `"ulysses_context"` \| `"media_text_context"` |
| `granularity` | `"microtext"` \| `"sentence"` |
| `include_headlines` | boolean; see the "Unit of analysis" entry in `CONTEXT.md` for what this means at each granularity |
| `microtext` | integer id of the microtext (renamed from the internal `section` grouping variable) |
| `unit_index` | 1-based position of this unit within its microtext (always `1` at `microtext` granularity; preserves sentence order at `sentence` granularity) |
| `unit_of_analysis` | the exact text string sent to the LLM for this row's classification call |
| `label` | the schema's enum classification |
| `score` | the schema's numeric score |

Every row is fully self-describing: any subset of grid cells can be written to a shared file or split across many and later combined with a plain `bind_rows()`, because the schema never varies. `label`/`score` are deliberately generic rather than RQ-prefixed (e.g. not `sentiment_label`) — `research_question` is its own column, so prefixing would only reintroduce the wide-format problem (NA-heavy columns) when combining rows from different research questions into one long file.

Run provenance (which sweep/`run_id` produced a file) is deliberately *not* a column — it describes how the data was produced, not what was classified, and stays in the directory/filename layer (`results/<run_id>/...`), stripped away when a curated CSV is promoted into `inst/extdata/results/`.

`include_headline` is recorded per row even though it is fully implied by the run's configuration. This is redundant by construction, but kept for transparency: a promoted CSV read outside the pipeline should never require cross-referencing an external run config to know what a row's `unit_of_analysis` actually contains.

Note: as of this ADR, `load_aeolus()`/`tokenise_microtexts_by_sentence()` do not yet implement the `granularity`/`include_headline` branching this schema assumes — they always tokenise by sentence with headline lines retained. The schema is written ahead of that implementation so the `targets` refactor (ADR 0001) has a stable target to build against; see `TODO.md`.
