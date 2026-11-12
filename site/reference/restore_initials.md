# Undo `protect_initials()`, restoring plain spaces.

Undo
[`protect_initials()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/protect_initials.md),
restoring plain spaces.

## Usage

``` r
restore_initials(text)
```

## Arguments

- text:

  Character vector previously passed through
  [`protect_initials()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/protect_initials.md)

## Value

Character vector with `initial_placeholder` replaced by a space
