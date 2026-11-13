# Render the DH2027 manuscript (HTML + PDF), stage it into pkgdown/assets,
# then build the pkgdown site into site/.

# Find repo root
root <- rprojroot::find_root(rprojroot::is_r_package)

# Find manuscripts directories
# TODO: generalise when another manuscript is added
manuscript_dir <- file.path(root, "manuscripts", "dh2027")
assets_dir <- file.path(root, "pkgdown", "assets", "dh2027")

# Render manuscripts
quarto::quarto_render(manuscript_dir, output_format = "all")

# Clear our assets_dir and copy rendered manuscript(s)
if (fs::dir_exists(assets_dir)) {
  fs::dir_delete(assets_dir)
}
fs::dir_copy(file.path(manuscript_dir, "_output"), assets_dir)

# Then build site
pkgdown::build_site(pkg = root)
