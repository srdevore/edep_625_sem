# Builds the class schedule from _class-config.yml and _schedule.yml.
# Source this file in any qmd that needs the schedule. After sourcing,
# the following are available:
#   class_config        - list of course config
#   class_start_date    - Date of semester start
#   class_end_date      - Date of semester end
#   class_schedule_df   - data.frame with Week, Date, Topic, Prep, Turn in

suppressPackageStartupMessages(library(yaml))

class_config   <- read_yaml("_class-config.yml")
.schedule_yaml <- read_yaml("_schedule.yml")

.day_nums <- match(class_config$class_days,
  c("Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday")) - 1

class_start_date <- as.Date(class_config$class_start)
class_end_date   <- class_start_date + (class_config$weeks * 7 - 1)

.all_dates     <- seq(class_start_date, class_end_date, by = "day")
.meeting_dates <- .all_dates[as.POSIXlt(.all_dates)$wday %in% .day_nums]

.ref_monday <- .meeting_dates[1] -
               (as.integer(format(.meeting_dates[1], "%u")) - 1)
.weeks_col <- as.integer(floor(as.numeric(.meeting_dates - .ref_monday) / 7) + 1)

.holiday_keys <- names(class_config$holidays)
.holiday_vals <- unlist(class_config$holidays, use.names = FALSE)
.is_holiday   <- as.character(.meeting_dates) %in% .holiday_keys

.n <- length(.meeting_dates)
.topics  <- character(.n)
.preps   <- character(.n)
.turnins <- character(.n)

if (any(.is_holiday)) {
  .topics[.is_holiday] <- .holiday_vals[
    match(as.character(.meeting_dates[.is_holiday]), .holiday_keys)]
}

.get_field <- function(s, field) {
  v <- s[[field]]; if (is.null(v)) "" else as.character(v)
}
.sessions     <- .schedule_yaml$sessions
.sess_topic   <- vapply(.sessions, .get_field, character(1), "topic")
.sess_prep    <- vapply(.sessions, .get_field, character(1), "prep")
.sess_turn_in <- vapply(.sessions, .get_field, character(1), "turn_in")

.class_idx <- which(!.is_holiday)
.n_class   <- length(.class_idx)
if (length(.sess_topic) < .n_class) {
  .pad <- .n_class - length(.sess_topic)
  .sess_topic   <- c(.sess_topic, rep("TBD", .pad))
  .sess_prep    <- c(.sess_prep, rep("", .pad))
  .sess_turn_in <- c(.sess_turn_in, rep("", .pad))
}
.topics[.class_idx]  <- .sess_topic[seq_len(.n_class)]
.preps[.class_idx]   <- .sess_prep[seq_len(.n_class)]
.turnins[.class_idx] <- .sess_turn_in[seq_len(.n_class)]

class_schedule_df <- data.frame(
  Week        = .weeks_col,
  Date        = format(.meeting_dates, "%a, %b %d, %Y"),
  Topic       = .topics,
  Prep        = .preps,
  `Turn in`   = .turnins,
  check.names = FALSE,
  stringsAsFactors = FALSE
)
