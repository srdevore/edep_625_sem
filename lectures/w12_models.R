# Data prep, model syntax and cached fits for the Week 12 LVPA lecture.
# Source from lectures/ (the qmd does this). FIML fits on this data take
# ~2-3 minutes each (hundreds of missing-data patterns), so each fit is
# cached in lectures/w12_cache/<name>.rds. Delete a file to refit it.
suppressPackageStartupMessages(library(lavaan))

# ---- Data ------------------------------------------------------------------
raw <- read.csv("../data/w12_data_pisa22_GBR_anx_stress_growth_n1000.csv")

anx_items <- paste0("anx", 1:6)    # ST292Q01JA-Q06JA
str_items <- paste0("str", 1:10)   # ST345Q01JA-Q10JA
gm_items  <- paste0("gm", 1:4)     # ST263Q02JA, Q04JA, Q06JA, Q08JA

pisa <- data.frame(
  setNames(raw[sprintf("ST292Q%02dJA", 1:6)], anx_items),
  setNames(raw[sprintf("ST345Q%02dJA", 1:10)], str_items),
  setNames(raw[sprintf("ST263Q%02dJA", c(2, 4, 6, 8))], gm_items),
  math = raw$MATH_AVE / 100   # 100 points = 1 unit, so variances are comparable
)
# Make "higher = more of the construct" for every item
pisa[anx_items] <- 5 - pisa[anx_items]               # 4-pt: higher = more anxious
pisa[gm_items]  <- 5 - pisa[gm_items]                # 4-pt: higher = more growth mindset
rev_str <- paste0("str", c(1, 3, 4, 7, 10))          # negatively keyed stress items
pisa[rev_str] <- 6 - pisa[rev_str]                   # 5-pt: higher = more resistant

# ---- Model syntax ------------------------------------------------------------
ind <- function(f, items) paste0(f, " =~ ", paste(items, collapse = " + "))

# Residual covariances freed by modification indices (Example 1 & 2)
mods <- '
  anx5 ~~ anx6
  str6 ~~ str9
  str5 ~~ str6
'

# Example 1: stress -> anx -> math
m1_meas0 <- paste(ind("stress", str_items), ind("anx", anx_items),
                  "math ~~ stress + anx", sep = "\n")
m1_meas  <- paste(m1_meas0, mods, sep = "\n")
m1_sem   <- paste(ind("stress", str_items), ind("anx", anx_items), mods, '
  anx  ~ a*stress
  math ~ b*anx
  ind := a*b
', sep = "\n")

# Example 2: gm -> stress, gm + stress -> anx, anx -> math
m2_meas0 <- paste(ind("gm", gm_items), ind("stress", str_items),
                  ind("anx", anx_items), "math ~~ gm + stress + anx", sep = "\n")
m2_meas  <- paste(m2_meas0, mods, sep = "\n")
m2_sem   <- paste(ind("gm", gm_items), ind("stress", str_items),
                  ind("anx", anx_items), mods, '
  stress ~ g1*gm
  anx    ~ g2*gm + s*stress
  math   ~ b*anx
  ind_gm_stress_anx := g1*s
  ind_gm_anx_math   := (g2 + g1*s)*b
', sep = "\n")

# ---- Cached fitting ------------------------------------------------------------
dir.create("w12_cache", showWarnings = FALSE)
cached_fit <- function(name, model, fun = lavaan::sem) {
  f <- file.path("w12_cache", paste0(name, ".rds"))
  if (file.exists(f)) return(readRDS(f))
  fit <- fun(model, data = pisa, estimator = "MLR", missing = "fiml")
  saveRDS(fit, f)
  fit
}

m1_step1 <- paste(m1_meas0, "anx5 ~~ anx6", sep = "\n")
m1_step2 <- paste(m1_step1, "str6 ~~ str9", sep = "\n")

specs <- list(
  m1_step1 = list(m1_step1, lavaan::cfa), m1_step2 = list(m1_step2, lavaan::cfa),
  m1_meas0 = list(m1_meas0, lavaan::cfa), m1_meas = list(m1_meas, lavaan::cfa),
  m1_sem   = list(m1_sem,   lavaan::sem),
  m2_meas0 = list(m2_meas0, lavaan::cfa), m2_meas = list(m2_meas, lavaan::cfa),
  m2_sem   = list(m2_sem,   lavaan::sem)
)
get_fit <- function(name) {
  fit <- cached_fit(name, specs[[name]][[1]], specs[[name]][[2]])
  attr(fit, "nm") <- name   # lets gfit() look up cached fit measures
  fit
}

# Cached fit measures (robust RMSEA CIs take ~25 s each to compute)
fm_names <- c("chisq.scaled", "df.scaled", "pvalue.scaled", "cfi.robust", "tli.robust",
              "rmsea.robust", "rmsea.ci.lower.robust", "rmsea.ci.upper.robust", "srmr")
cached_fm <- function(name) {
  f <- file.path("w12_cache", paste0(name, "_fm.rds"))
  if (file.exists(f)) return(readRDS(f))
  fm <- fitMeasures(get_fit(name), fm_names)
  saveRDS(fm, f)
  fm
}

# Cached modification indices (modindices() on a FIML fit is slow-ish too)
cached_mi <- function(name) {
  f <- file.path("w12_cache", paste0(name, "_mi.rds"))
  if (file.exists(f)) return(readRDS(f))
  mi <- modindices(get_fit(name), sort. = TRUE)
  saveRDS(mi, f)
  mi
}
