# Generate a run identifier

Combines a timestamp and a package version, per ADR 0004 and the "Run"
entry in `CONTEXT.md`, so every `results/<run_id>/...` output directory
is traceable to the exact code that produced it. Both arguments are
injectable so tests don't depend on wall-clock time or the installed
package version.

## Usage

``` r
generate_run_id(
  version = utils::packageVersion("aeolusmicrotexts"),
  when = Sys.time()
)
```

## Arguments

- version:

  Package version to embed, defaults to the installed `aeolusmicrotexts`
  version

- when:

  Timestamp to embed, defaults to
  [`Sys.time()`](https://rdrr.io/r/base/Sys.time.html)

## Value

A single string, e.g. `"20260821-153000_v0.1.0.9000"`
