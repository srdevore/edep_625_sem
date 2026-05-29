# Quarto post-render hook. Copies raw rlab .qmd source files into
# _site/rlab-downloads/ so the "Download .qmd" link on the labs listing
# resolves to the real source (not the rendered .html page).
#
# Why a separate folder: Quarto's listing engine rewrites any href that
# matches a known project source file. Linking to rlabs/foo.qmd from the
# listing gets silently rewritten to ./rlabs/foo.html. Serving the same
# file from a path the listing engine doesn't recognize (rlab-downloads/)
# avoids the rewrite.

dest_dir <- file.path("_site", "rlab-downloads")
dir.create(dest_dir, showWarnings = FALSE, recursive = TRUE)

qmd_files <- list.files("rlabs", pattern = "\\.qmd$", full.names = TRUE)
for (f in qmd_files) {
  file.copy(f, file.path(dest_dir, basename(f)), overwrite = TRUE)
}
