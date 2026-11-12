# Read the SLURM resource configuration file

Read the SLURM resource configuration file

## Usage

``` r
read_slurm_resources(path = "slurm-resources.yml")
```

## Arguments

- path:

  Path to the YAML file; see `slurm-resources.yml` at the repo root for
  the expected shape (a `default` block plus optional per-model `models`
  overrides)

## Value

A list with (at least) a `default` element
