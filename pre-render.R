# Quarto pre-render hook. Reads _class-config.yml and propagates shared
# values across the site so course-wide info is sourced from one place.
# Also handles release-date gating: pages with a `release:` field in their
# YAML are toggled `draft: true`/removed based on the current time.

library(yaml)

config <- read_yaml("_class-config.yml")

# === 1. Sync _quarto.yml website title to course_name ============
qy_lines <- readLines("_quarto.yml")
website_idx <- grep("^website:", qy_lines)
if (length(website_idx) > 0) {
  title_idx <- grep("^\\s+title:", qy_lines)
  inside <- title_idx[title_idx > website_idx[1]]
  if (length(inside) > 0) {
    target <- min(inside)
    leading_ws <- sub("^(\\s*).*", "\\1", qy_lines[target])
    new_line <- sprintf('%stitle: "%s"', leading_ws, config$course_name)
    if (qy_lines[target] != new_line) {
      qy_lines[target] <- new_line
      writeLines(qy_lines, "_quarto.yml")
    }
  }
}

# === 2. Root _metadata.yml — index.qmd inherits title from course_name =
write_yaml(list(title = config$course_name), "_metadata.yml")

# === 3. lectures/_metadata.yml — subtitle + author for lecture decks ===
lectures_metadata <- list(
  subtitle = config$course_name,
  author   = config$course_instructor
)
if (!dir.exists("lectures")) dir.create("lectures")
write_yaml(lectures_metadata, "lectures/_metadata.yml")

# === 4. Release-date gating ============================================
# A page with `release: "week N"` in its YAML is rendered as a draft until
# one hour before the first class meeting of week N (i.e., students don't
# see it on the public site until you push within that window).
# The teacher profile bypasses gating.

day_names <- c("Sunday", "Monday", "Tuesday", "Wednesday",
               "Thursday", "Friday", "Saturday")

compute_release_dt <- function(token, cfg) {
  tz         <- if (is.null(cfg$timezone)) "" else cfg$timezone
  start_time <- if (is.null(cfg$class_start_time)) "00:00"
                else cfg$class_start_time

  m <- regmatches(token,
                  regexec("^(?:show )?week (\\d+)$", token))[[1]]
  if (length(m) == 2) {
    week_num <- as.integer(m[2])
    week_start_date <- as.Date(cfg$class_start) + (week_num - 1) * 7
    day_nums <- match(cfg$class_days, day_names) - 1
    candidates <- seq(week_start_date, week_start_date + 6, by = "day")
    matching <- candidates[as.POSIXlt(candidates)$wday %in% day_nums]
    if (length(matching) == 0) return(as.POSIXct(NA))
    first_meeting <- matching[1]
    meeting_dt <- as.POSIXct(paste(first_meeting, start_time), tz = tz)
    return(meeting_dt - 3600)
  }
  as.POSIXct(NA)
}

profile    <- Sys.getenv("QUARTO_PROFILE", "")
is_teacher <- grepl("teacher", profile)
now        <- Sys.time()

qmd_files <- list.files(".", pattern = "\\.qmd$",
                        recursive = TRUE, full.names = FALSE)
qmd_files <- qmd_files[!grepl("(^|/)_(site|teacher)/", qmd_files)]

for (qmd in qmd_files) {
  text <- tryCatch(readLines(qmd, warn = FALSE), error = function(e) NULL)
  if (is.null(text) || length(text) < 2 || text[1] != "---") next
  end <- which(text == "---")[2]
  if (is.na(end)) next

  yaml_block <- text[2:(end - 1)]
  parsed <- tryCatch(yaml.load(paste(yaml_block, collapse = "\n")),
                     error = function(e) NULL)
  if (is.null(parsed) || is.null(parsed$release)) next

  release_dt <- compute_release_dt(parsed$release, config)
  if (is.na(release_dt)) next

  should_draft <- !is_teacher && now < release_dt
  draft_idx <- grep("^draft:", yaml_block)
  body <- if (end < length(text)) text[(end + 1):length(text)] else character(0)

  if (should_draft) {
    desired <- "draft: true"
    if (length(draft_idx) == 0) {
      yaml_block <- c(yaml_block, desired)
      writeLines(c("---", yaml_block, "---", body), qmd)
    } else if (yaml_block[draft_idx[1]] != desired) {
      yaml_block[draft_idx[1]] <- desired
      writeLines(c("---", yaml_block, "---", body), qmd)
    }
  } else if (length(draft_idx) > 0) {
    yaml_block <- yaml_block[-draft_idx[1]]
    writeLines(c("---", yaml_block, "---", body), qmd)
  }
}
