# Render the DH2027 manuscript (HTML + PDF), stage it into pkgdown/assets,
# then build the pkgdown site into site/. Run from the repo root.

manuscript_dir <- "manuscripts/dh2027"
assets_dir <- file.path("pkgdown", "assets", "dh2027")

quarto::quarto_render(manuscript_dir)

# Start clean so stale files don't linger in the site
fs::dir_delete(assets_dir)  # errors if absent; use fs::dir_exists() guard
fs::dir_copy(file.path(manuscript_dir, "_output"), assets_dir)

pkgdown::build_site()
