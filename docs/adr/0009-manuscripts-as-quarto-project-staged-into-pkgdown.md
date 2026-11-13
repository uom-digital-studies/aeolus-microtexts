# Manuscripts live in a Quarto manuscript project, staged into pkgdown assets

The DH2027 abstract needs to be published on the pkgdown site as both HTML and PDF. pkgdown renders one format per article (`as_is` replaces the HTML rather than adding to it), so a `vignettes/articles/` article can't give both. We moved it to `manuscripts/dh2027/` as a Quarto `manuscript` project (`format: [html, pdf]`) and `scripts/build-site.R` renders it, copies the output into `pkgdown/assets/dh2027/`, then runs `pkgdown::build_site()`. pkgdown copies `pkgdown/assets/` into the site root, so the files are served at `dh2027/index.{html,pdf}`, linked from the navbar in `_pkgdown.yml`.

## Considered options

- **Companion `*-pdf.qmd` article with a shared `{{< include >}}` body.** Keeps everything under `vignettes/`, but gives two articles, awkward includes with executable chunks and cross-references, and re-renders both on every `build_site()`.
- **`as_is: true` + `extension: pdf` on the existing article.** Replaces the HTML; rejected because both formats are wanted.

## Consequences

- Manuscripts are not vignettes: excluded from the package build (`^manuscripts$` in `.Rbuildignore`) and from `R CMD check`.
- Manuscript rendering is not part of `build_site()` alone; the site must be built via `scripts/build-site.R` or the manuscript will be missing.
- `pkgdown/`, `_freeze/` and `_output/` are generated and gitignored. `site/` is still committed and deployed manually.
- The manuscript uses the *installed* `aeolusmicrotexts`, not the working tree; install before rendering.
- `freeze: true` means chunks re-execute only when `index.qmd` changes; delete `_freeze/` to force a re-run after package changes.

## Pre-push hook

A pre-push hook (`.githooks/pre-push`) checks if a site rebuild is required before a push. It watches a set of files that affect the site. That watchlist may need to be updated over time as the project evolves.
