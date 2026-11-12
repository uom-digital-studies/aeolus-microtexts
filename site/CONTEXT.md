# Aeolus Microtexts

Analyses the microtexts of the *Aeolus* episode of *Ulysses* as if they
were social media content, using LLM-based qualitative coding across
three research questions.

## Language

**Research question (RQ)**: One of three fixed lines of inquiry (RQ1
sentiment, RQ2 nationalism, RQ3 UGC-resemblance). Each RQ has a fixed RQ
schema that does not vary across a run. *Avoid*: rq, question, analysis
type

**Context variant**: One of three framings prepended to the system
prompt, giving the LLM different background about the text before it:
`no_context`, `ulysses_context` (“this text is from *Ulysses*”),
`media_text_context` (“this text is/is intended to be media text”).
Crossed independently within each research question. *Avoid*: prompt
variant, framing, condition

**RQ schema**: The fixed coding schema of a research question, holding
both its task instruction and the definitions of its output fields. The
single source of truth for what the model is asked to do and for the
output shape enforced during generation. Enforcement constrains
structure only; the model reads nothing of the RQ schema except what is
rendered into the system prompt. *Avoid*: coding schema, response
format, type

**Task instruction**: The sentence(s) telling the model what to classify
for a given research question. Derived programmatically from the RQ
schema, not hand-duplicated. *Avoid*: system prompt (system prompt =
context variant + task instruction + output specification)

**Output specification**: The plain-text rendering of the RQ schema’s
output fields (name, meaning, allowed values or type, in schema order)
included in the system prompt, so the model reads what each field means
rather than only having its structure enforced. *Avoid*: response format
(collides with the API request field that carries the enforced schema),
RQ schema (the source, not its rendering)

**System prompt**: Context variant + task instruction + output
specification, fixed within a grid cell. The unit of analysis is sent
separately as the user turn, under a “The text” heading (results CSVs
record the bare unit, without the heading). *Avoid*: prompt (ambiguous:
system prompt or user turn)

**Unit of analysis**: The span of text a single LLM call classifies.
Defined by two orthogonal factors: **granularity** (`microtext` vs
`sentence`) and **include_headline** (whether the ALL-CAPS headline is
included — prepended to the unit at `microtext` granularity, or retained
as its own unit rather than filtered out at `sentence` granularity). Its
concrete text is recorded in a results CSV’s `unit_of_analysis` column;
see `docs/adr/0003-results-csv-schema.md` for the full row schema.
*Avoid*: chunk, segment

**Microtext**: A block of text in `7_Aeolus.txt` delimited by an
ALL-CAPS headline, treated as the analogue of a single social-media
post. Identified in results CSVs by the `microtext` column (an integer
id); the R-internal grouping variable is still called `section`.
*Avoid*: post, entry, section (post is fine informally, but microtext is
the canonical term)

**Grid cell**: One combination of research question × model × context
variant × unit of analysis — the atomic unit of work in a run,
corresponding to one (or more, for sentence granularity) LLM
classification calls. Every row in a results CSV carries an explicit
column for each of these factors, so rows/files are self-describing and
freely concatenable regardless of how the run happened to be split
across files; see `docs/adr/0003-results-csv-schema.md`. *Avoid*:
combination, run, condition

**Run**: One invocation of the pipeline across some or all of the grid,
identified by a `run_id` combining a timestamp and the installed
`aeolusmicrotexts` package version (e.g. `20260821-153000_v0.1.0.9000`),
so output is traceable to the exact code that produced it. Lives only in
the `results/<run_id>/...` directory/filename layer
(`docs/adr/0003-results-csv-schema.md`), never as its own CSV column;
see `docs/adr/0004-install-package-for-targets-workers.md` for why the
version is embedded. *Avoid*: sweep (used informally elsewhere for the
same concept, but “run” is the canonical term)

**Promoted run**: A run whose results and model digests were manually
copied into `inst/extdata/results/<run_id>/` after researcher review,
and so readable from the installed package. *Avoid*: sweep, published
run

**Test mode**: A single R parameter that switches the pipeline to a
reduced sweep for local/Docker validation: 5 microtexts, using only the
small `llama3.2:1b` model. Controlled entirely in R, not via `targets`
branching. *Avoid*: dev mode, dry run

**Dispatcher job**: The single SLURM job (submitted by
`scripts/test-run.sh`/`scripts/run-sweep.sh`, non-GPU, `sapphire`
partition) that runs
[`targets::tar_make()`](https://docs.ropensci.org/targets/reference/tar_make.html)
itself: builds the grid, pulls every model into its model store once
before any worker starts, and coordinates workers, but does no LLM
inference. Exists to get `tar_make()` off the login node (compute nodes
can’t dial back into a login-node-hosted `crew` socket; see
`docs/adr/0001-crew-cluster-drives-slurm.md`). Submitted fire-and-forget
(no `--wait`) — the submitting script returns as soon as `sbatch`
accepts the job, it does not block until the run finishes. *Avoid*:
tar_make job, controller job, orchestrator (dispatcher is the canonical
term, paired with “worker” below)

**Worker**: A `crew.cluster` SLURM job (one per model, GPU partition,
per `slurm-resources.yml`) that runs `ollama serve`, checks that its
model is already present in its model store (never pulls it — the
dispatcher job does), and then executes grid cells dispatched to it.
Launched and torn down by the dispatcher job, not submitted directly by
any script. *Avoid*: node, task runner (worker is the `crew`-native
term, kept as-is here)

**Model store**: The project’s own directory (a sibling of the repo
checkout) that every Ollama server in a run reads models from, and that
the dispatcher job pulls into. Shared by every run, so only one run may
be active at a time — a run starting up can delete a concurrent run’s
in-progress pull. *Avoid*: pull-cache, models dir, shared model
directory, central store (the cluster-wide store, no longer used)

**Chat backend**: An injectable argument (default
[`ellmer::chat_ollama`](https://ellmer.tidyverse.org/reference/chat_ollama.html))
threaded through the analysis functions, swappable for a mocked/fake
implementation in fast logic tests. Exists because `ellmer` has no
built-in mock/test chat provider. *Avoid*: LLM client, provider (backend
is the pipeline-specific term)
