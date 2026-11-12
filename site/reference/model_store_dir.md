# The project's model store directory

Computed as a fixed sibling of the repo checkout root (e.g.
`<checkout>/../ollama_models`) rather than sourced from an environment
variable: since the whole repo now lives inside the confidential Spartan
project directory (that directory is the confidentiality boundary), the
checkout's own location is no longer sensitive, so this path can be
derived automatically instead of threaded through config. Uses
[`rprojroot::find_root()`](https://rprojroot.r-lib.org/reference/find_root.html)
to locate the checkout root robustly regardless of the current working
directory.

## Usage

``` r
model_store_dir(start = ".")
```

## Arguments

- start:

  Directory to start searching upward from for the repo root

## Value

A single string: the absolute path to the model store directory
