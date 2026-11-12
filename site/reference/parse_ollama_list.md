# Parse ollama list output into a model manifest

Pure function: converts `ollama list` stdout (tab-separated columns)
into a tibble mapping model identifiers to their content-address
digests.

## Usage

``` r
parse_ollama_list(lines)
```

## Arguments

- lines:

  Character vector of output lines from `ollama list`

## Value

A tibble with columns `model` and `digest` (ID truncated to 12 hex)
