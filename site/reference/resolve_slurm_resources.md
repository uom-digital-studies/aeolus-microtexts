# Resolve the SLURM resources for a given model

Merges the `default` block with any `models[[model]]` override,
per-field — an override only replaces the fields it names, leaving the
rest of `default` untouched. Field names deliberately match
[`crew.cluster::crew_options_slurm()`](https://wlandau.github.io/crew.cluster/reference/crew_options_slurm.html)'s
arguments (`partition`, `cpus_per_task`, `memory_gigabytes_per_cpu`,
`time_minutes`) so
[`build_slurm_controllers()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/build_slurm_controllers.md)
can spread the result straight into it.

## Usage

``` r
resolve_slurm_resources(model, resources = read_slurm_resources())
```

## Arguments

- model:

  Model identifier to look up an override for

- resources:

  A list as returned by
  [`read_slurm_resources()`](https://uom-digital-studies.github.io/aeolusmicrotexts/reference/read_slurm_resources.md)

## Value

A named list of resolved SLURM options
