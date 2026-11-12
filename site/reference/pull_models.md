# Pull all models into the model store via the dispatcher

Starts an Ollama server, pulls each model in sequence, verifies all
models are in the store via `ollama list`, and returns their digests.
Errors if any pull fails or if a pulled model doesn't appear in the
final list.

## Usage

``` r
pull_models(
  models,
  model_store = model_store_dir(),
  start_server = start_ollama_server,
  run = processx::run
)
```

## Arguments

- models:

  Character vector of Ollama model identifiers to pull

- model_store:

  Path to the model store directory (default:
  [`model_store_dir()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/model_store_dir.md))

- start_server:

  Function with signature `function(model_store, log)` returning
  `list(process, host)`; defaults to
  [`start_ollama_server()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/start_ollama_server.md)

- run:

  Function with signature
  `function(cmd, args, ..., error_on_status, env)`; defaults to
  [`processx::run()`](http://processx.r-lib.org/reference/run.md)

## Value

A tibble with columns `model` and `digest`, one row per input model

## Details

Arguments `start_server` and `run` are injectable for testing (same
pattern as `analyse_with_schema`'s `chat_backend` parameter).
