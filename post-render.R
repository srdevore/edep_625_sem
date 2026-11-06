# Quarto post-render hook. Copies raw rlab .qmd source files into
# _site/rlab-downloads/ so the "Download .qmd" link on the labs listing
# resolves to the real source (not the rendered .html page).
#
# Why a separate folder: Quarto's listing engine rewrites any href that
# matches a known project source file. Linking to rlabs/foo.qmd from the
# listing gets silently rewritten to ./rlabs/foo.html. Serving the same
# file from a path the listing engine doesn't recognize (rlab-downloads/)
# avoids the rewrite.
#
# Teacher notes: labs use `::: {.content-visible when-profile="teacher"}`
# fenced divs. Rendered HTML drops them under the student profile, but a
# raw .qmd copy would leak them to students. So on non-teacher builds we
# strip those blocks from the copied source (teacher builds copy verbatim).

# Remove teacher-only fenced divs from qmd source lines. Depth-aware so
# nested fences inside a teacher block are handled: an attribute fence
# (`::: {...}`) always opens; a bare fence (`:::`) closes the innermost.
strip_teacher_blocks <- function(lines) {
  out <- character(0)
  in_block <- FALSE
  depth <- 0L
  for (ln in lines) {
    trimmed <- trimws(ln)
    if (!in_block) {
      if (grepl("content-visible", trimmed) &&
          grepl('when-profile="teacher"', trimmed)) {
        in_block <- TRUE
        depth <- 1L
      } else {
        out <- c(out, ln)
      }
    } else if (grepl("^:::+\\s*\\{", trimmed)) {
      depth <- depth + 1L
    } else if (grepl("^:::+\\s*$", trimmed)) {
      depth <- depth - 1L
      if (depth == 0L) in_block <- FALSE
    }
  }
  out
}

profile    <- Sys.getenv("QUARTO_PROFILE", "")
is_teacher <- grepl("teacher", profile)

dest_dir <- file.path("_site", "rlab-downloads")
dir.create(dest_dir, showWarnings = FALSE, recursive = TRUE)

qmd_files <- list.files("rlabs", pattern = "\\.qmd$", full.names = TRUE)
for (f in qmd_files) {
  dest <- file.path(dest_dir, basename(f))
  if (is_teacher) {
    file.copy(f, dest, overwrite = TRUE)
  } else {
    lines <- readLines(f, warn = FALSE)
    writeLines(strip_teacher_blocks(lines), dest)
  }
}

# Data files used by the labs ship alongside the .qmd source, so the "Data"
# column on the listing has something to point at. Quarto does not copy
# these on its own -- they are not referenced by any rendered href.
data_files <- list.files("rlabs", pattern = "\\.(csv|tsv|rds|xlsx|sav|dta)$",
                         full.names = TRUE, ignore.case = TRUE)
for (f in data_files) {
  file.copy(f, file.path(dest_dir, basename(f)), overwrite = TRUE)
}

# Student-facing templates that students download and fill in. Copied
# verbatim (NOT stripped): the teacher-profile blocks in these files are
# placeholders the students' groups are meant to fill in, and the file holds
# no real answers.
template_dir <- file.path("_site", "template-downloads")
dir.create(template_dir, showWarnings = FALSE, recursive = TRUE)
file.copy(file.path("widgets", "review_quiz.qmd"),
          file.path(template_dir, "review_quiz.qmd"), overwrite = TRUE)
