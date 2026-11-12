# Start an Ollama server with the given model store

Launches `run_ollama_server` as a background process, waits for it to
bind and report its `OLLAMA_HOST=` to the log file, then verifies
readiness via `ollama list`.

## Usage

``` r
start_ollama_server(model_store, log)
```

## Arguments

- model_store:

  Path to the model store directory

- log:

  Path to write the server's stdout/stderr log to

## Value

A list with:

- `process`: A
  [`processx::process`](http://processx.r-lib.org/reference/process.md)
  object with a `kill()` method

- `host`: A string `"host:port"` the server is bound to
