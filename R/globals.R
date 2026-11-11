# Names used as free variables in package code that are not defined in the
# package: `targets` pipeline targets referenced by name inside quoted
# commands (see build_pull_targets() and build_grid_targets()), and the
# `map` pattern helper that `targets` interprets in dynamic-branching
# patterns.

utils::globalVariables(c("models_pulled", "run_id", "map"))
