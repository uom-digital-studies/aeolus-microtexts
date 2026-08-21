# Aeolus Microtexts

Analyses the microtexts of the *Aeolus* episode of *Ulysses* as if they were social media content, using LLM-based qualitative coding across three research questions.

## Language

**Research question (RQ)**:
One of three fixed lines of inquiry (RQ1 sentiment, RQ2 nationalism, RQ3 UGC-resemblance). Each RQ has a fixed coding schema (an `ellmer::type_object()`) that does not vary across the pipeline sweep.
_Avoid_: rq, question, analysis type

**Context variant**:
One of three framings prepended to the system prompt, giving the LLM different background about the text before it: `no_context`, `ulysses_context` ("this text is from *Ulysses*"), `media_text_context` ("this text is/is intended to be media text"). Crossed independently within each research question.
_Avoid_: prompt variant, framing, condition

**Task instruction**:
The sentence(s) telling the model what to classify for a given research question. Derived programmatically from that RQ's schema description (the single source of truth), not hand-duplicated — composed together with the context variant to form the full system prompt.
_Avoid_: system prompt (system prompt = context variant + task instruction, not the task instruction alone)

**Unit of analysis**:
The span of text a single LLM call classifies. Defined by two orthogonal factors: **granularity** (`microtext` vs `sentence`) and **include_headline** (whether the ALL-CAPS headline is included — prepended to the unit at `microtext` granularity, or retained as its own unit rather than filtered out at `sentence` granularity). Its concrete text is recorded in a results CSV's `unit_of_analysis` column; see `docs/adr/0003-results-csv-schema.md` for the full row schema.
_Avoid_: chunk, segment

**Microtext**:
A block of text in `7_Aeolus.txt` delimited by an ALL-CAPS headline, treated as the analogue of a single social-media post. Identified in results CSVs by the `microtext` column (an integer id); the R-internal grouping variable is still called `section`.
_Avoid_: post, entry, section (post is fine informally, but microtext is the canonical term)

**Grid cell**:
One combination of research question × model × context variant × unit of analysis — the atomic unit of work in a run, corresponding to one (or more, for sentence granularity) LLM classification calls. Every row in a results CSV carries an explicit column for each of these factors, so rows/files are self-describing and freely concatenable regardless of how the run happened to be split across files; see `docs/adr/0003-results-csv-schema.md`.
_Avoid_: combination, run, condition

**Run**:
One invocation of the pipeline across some or all of the grid, identified by a `run_id` combining a timestamp and the installed `aeolusmicrotexts` package version (e.g. `20260821-153000_v0.1.0.9000`), so output is traceable to the exact code that produced it. Lives only in the `results/<run_id>/...` directory/filename layer (`docs/adr/0003-results-csv-schema.md`), never as its own CSV column; see `docs/adr/0004-install-package-for-targets-workers.md` for why the version is embedded.
_Avoid_: sweep (used informally elsewhere for the same concept, but "run" is the canonical term)

**Test mode**:
A single R parameter that switches the pipeline to a reduced sweep for local/Docker validation: 5 microtexts, using only the small `llama3.2:1b` model. Controlled entirely in R, not via `targets` branching.
_Avoid_: dev mode, dry run

**Chat backend**:
An injectable argument (default `ellmer::chat_ollama`) threaded through the analysis functions, swappable for a mocked/fake implementation in fast logic tests. Exists because `ellmer` has no built-in mock/test chat provider.
_Avoid_: LLM client, provider (backend is the pipeline-specific term)
