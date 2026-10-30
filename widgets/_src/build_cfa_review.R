# Builds the five fake CFA reports for the "CFA Reporting: Review" activity.
#
# Run from the repo root:  Rscript widgets/_src/build_cfa_review.R
#
# For each report it simulates data (fixed seed), fits the models in lavaan,
# and writes a Quarto partial widgets/cfa_review/_report_N.qmd whose numbers
# come from the fitted models (so chi-square, df, loadings, covariances all
# agree with each other). Each report omits or garbles specific items on
# purpose; omitted items show up only in the TEACHER profile, as red
# placeholders like "[covariance table]" (never the answer itself).
# Flawed-but-present content is shown in orange in the teacher profile.

suppressMessages({ library(lavaan); library(semPlot) })

out_dir <- "widgets/cfa_review"
img_dir <- file.path(out_dir, "img")
dir.create(img_dir, recursive = TRUE, showWarnings = FALSE)

# ---------- formatting helpers ------------------------------------------
cap <- function(x) paste0(toupper(substring(x, 1, 1)), substring(x, 2))
f   <- function(x, k = 2) formatC(x, digits = k, format = "f")
nz  <- function(x, k = 2) sub("^(-?)0\\.", "\\1.", f(x, k))          # no leading zero
pf  <- function(p) ifelse(p < .001, "< .001", paste0("= ", nz(p, 3)))
pcell <- function(p) ifelse(p < .001, "< .001", nz(p, 3))

# Teacher-only red placeholder for MISSING material (own bullet, hidden from students)
miss <- function(label)
  sprintf('\n::: {.content-visible when-profile="teacher"}\n- [\\[%s\\]]{.missing}\n:::\n', label)
# Present-but-flawed text: orange in teacher profile, plain for students
flaw <- function(txt)
  sprintf('[%s]{.flawed .content-visible when-profile="teacher"}[%s]{.content-hidden when-profile="teacher"}', txt, txt)

tbl <- function(df, align = NULL) {
  paste(knitr::kable(df, format = "pipe", row.names = FALSE, align = align), collapse = "\n")
}

# ---------- simulation ---------------------------------------------------
make_pop <- function(lam1, lam2, phi, v1, v2, n1, n2, resid_cov = "") {
  l1 <- paste(sprintf("%s*%s", lam1, v1), collapse = " + ")
  l2 <- paste(sprintf("%s*%s", lam2, v2), collapse = " + ")
  rv <- c(sprintf("%s ~~ %s*%s", v1, 1 - lam1^2, v1), sprintf("%s ~~ %s*%s", v2, 1 - lam2^2, v2))
  paste(c(sprintf("%s =~ %s", n1, l1), sprintf("%s =~ %s", n2, l2),
          sprintf("%s ~~ 1*%s", n1, n1), sprintf("%s ~~ 1*%s", n2, n2),
          sprintf("%s ~~ %s*%s", n1, phi, n2), rv, resid_cov), collapse = "\n")
}
gen <- function(pop, n, seed, M, SD, lo, hi, dig, vars, skew = NULL, kurt = NULL) {
  set.seed(seed)
  d <- simulateData(pop, sample.nobs = n, skewness = skew, kurtosis = kurt)[, vars]
  for (j in seq_along(vars))
    d[[j]] <- pmin(hi, pmax(lo, round(M[j] + SD[j] * d[[j]], dig)))
  stopifnot(!anyNA(d))
  d
}

# ---------- statistics helpers -------------------------------------------
mardia <- function(d) {
  X <- scale(as.matrix(d), scale = FALSE); n <- nrow(X); p <- ncol(X)
  S <- crossprod(X) / n; m <- X %*% solve(S) %*% t(X)
  b1 <- sum(m^3) / n^2; b2 <- mean(diag(m)^2)
  zs <- n * b1 / 6; dfs <- p * (p + 1) * (p + 2) / 6
  zk <- (b2 - p * (p + 2)) / sqrt(8 * p * (p + 2) / n)
  list(skew = b1, skew_chi = zs, skew_df = dfs, skew_p = pchisq(zs, dfs, lower.tail = FALSE),
       kurt = b2, kurt_z = zk, kurt_p = 2 * pnorm(-abs(zk)))
}
uni_skew <- function(x) { z <- x - mean(x); mean(z^3) / mean(z^2)^1.5 }
uni_kurt <- function(x) { z <- x - mean(x); mean(z^4) / mean(z^2)^2 - 3 }   # excess

fits <- function(m, robust) {
  fm <- fitMeasures(m)
  g <- function(a, b) if (robust) fm[[b]] else fm[[a]]
  list(chisq = g("chisq", "chisq.scaled"), df = fm[["df"]],
       p = if (robust) fm[["pvalue.scaled"]] else fm[["pvalue"]],
       sf = if (robust) fm[["chisq.scaling.factor"]] else NA,
       cfi = g("cfi", "cfi.robust"),
       rmsea = g("rmsea", "rmsea.robust"),
       lo = g("rmsea.ci.lower", "rmsea.ci.lower.robust"),
       hi = g("rmsea.ci.upper", "rmsea.ci.upper.robust"),
       srmr = fm[["srmr"]], npar = fm[["npar"]])
}

# ---------- table builders -----------------------------------------------
cov_table <- function(d, k) {
  S <- cov(d); v <- colnames(d)
  mat <- matrix("", length(v), length(v), dimnames = list(v, v))
  for (i in seq_along(v)) for (j in seq_len(i)) mat[i, j] <- f(S[i, j], k)
  tbl(cbind(` ` = v, as.data.frame(mat)), align = c("l", rep("r", length(v))))
}
desc_table <- function(d, cols) {
  df <- data.frame(Indicator = names(d))
  if ("M"   %in% cols) df$M   <- f(sapply(d, mean), 2)
  if ("SD"  %in% cols) df$SD  <- f(sapply(d, sd), 2)
  dg <- if (all(unlist(d) == round(unlist(d)))) 0 else 1
  if ("Min" %in% cols) df$Min <- f(sapply(d, min), dg)
  if ("Max" %in% cols) df$Max <- f(sapply(d, max), dg)
  tbl(df, align = c("l", rep("r", ncol(df) - 1)))
}
skew_kurt_table <- function(d, which) {
  df <- data.frame(Indicator = names(d))
  if ("skew" %in% which) df$Skewness <- f(sapply(d, uni_skew), 2)
  if ("kurt" %in% which) df$`Excess kurtosis` <- f(sapply(d, uni_kurt), 2)
  tbl(df, align = c("l", rep("r", ncol(df) - 1)))
}
est_table <- function(m, vars, unstd, std) {
  pe <- parameterEstimates(m); ss <- standardizedSolution(m)
  lo <- pe[pe$op == "=~", ]; ls <- ss[ss$op == "=~", ]
  df <- data.frame(Factor = lo$lhs, Indicator = lo$rhs)
  if (unstd) {
    df$b  <- f(lo$est, 2)
    df$SE <- ifelse(is.na(lo$se) | lo$se == 0, "—", f(lo$se, 2))
    df$z  <- ifelse(is.na(lo$z), "—", f(lo$z, 2))
    df$p  <- ifelse(is.na(lo$pvalue), "—", pcell(lo$pvalue))
  }
  if (std) df$`β` <- nz(ls$est.std, 2)
  tbl(df, align = c("l", "l", rep("r", ncol(df) - 2)))
}
other_est_table <- function(m, unstd, std) {
  pe <- parameterEstimates(m); ss <- standardizedSolution(m)
  pe <- pe[pe$op == "~~", ]; ss <- ss[ss$op == "~~", ]
  lab <- ifelse(pe$lhs == pe$rhs,
                ifelse(pe$lhs %in% lavNames(m, "lv"), paste0("Variance: ", pe$lhs), paste0("Residual variance: ", pe$lhs)),
                ifelse(pe$lhs %in% lavNames(m, "lv"), paste0("Covariance: ", pe$lhs, " ↔ ", pe$rhs),
                       paste0("Residual covariance: ", pe$lhs, " ↔ ", pe$rhs)))
  if (!unstd && std) lab <- ifelse(pe$lhs != pe$rhs & pe$lhs %in% lavNames(m, "lv"),
                                   sub("Covariance", "Correlation", lab), lab)
  df <- data.frame(Parameter = lab)
  if (unstd) {
    df$Estimate <- f(pe$est, 2); df$SE <- f(pe$se, 2)
    df$z <- ifelse(is.na(pe$z), "—", f(pe$z, 2)); df$p <- ifelse(is.na(pe$pvalue), "—", pcell(pe$pvalue))
  }
  if (std) df$`Std. estimate` <- nz(ss$est.std, 2)
  tbl(df, align = c("l", rep("r", ncol(df) - 1)))
}
fit_table <- function(rows, show_chisq = TRUE, show_rmsea = TRUE, robust = FALSE) {
  df <- data.frame(Model = names(rows))
  if (show_chisq) {
    df$`χ²` <- sapply(rows, function(r) f(r$chisq, 2))
    df$df <- sapply(rows, function(r) as.character(r$df))
    df$p  <- sapply(rows, function(r) pcell(r$p))
  }
  df$CFI <- sapply(rows, function(r) nz(r$cfi, 3));
  if (show_rmsea) df$`RMSEA [90% CI]` <- sapply(rows, function(r) sprintf("%s [%s, %s]", nz(r$rmsea, 3), nz(r$lo, 3), nz(r$hi, 3)))
  df$SRMR <- sapply(rows, function(r) nz(r$srmr, 3))
  tbl(df, align = c("l", rep("r", ncol(df) - 1)))
}

# ---------- diagram ------------------------------------------------------
diagram <- function(models, file) {
  png(file, width = 900 * length(models), height = 700, res = 130)
  par(mfrow = c(1, length(models)), mar = c(1, 1, 2, 1))
  for (i in seq_along(models)) {
    semPaths(models[[i]], what = "path", whatLabels = "name", layout = "tree2",
             style = "lisrel", residuals = TRUE, intercepts = FALSE, nCharNodes = 0,
             sizeMan = 7, sizeLat = 9, edge.label.cex = 0.9, label.cex = 1,
             edge.color = "grey25", mar = c(4, 4, 4, 4))
    if (length(models) > 1) title(names(models)[i], cex.main = 1)
  }
  dev.off()
}

# path diagram with standardized estimates on the paths
est_diagram <- function(m, file) {
  png(file, width = 900, height = 700, res = 130)
  par(mar = c(1, 1, 2, 1))
  semPaths(m, what = "std", whatLabels = "std", layout = "tree2",
           style = "lisrel", residuals = TRUE, intercepts = FALSE, nCharNodes = 0,
           sizeMan = 7, sizeLat = 9, edge.label.cex = 0.9, label.cex = 1,
           edge.color = "grey25", mar = c(4, 4, 4, 4))
  dev.off()
}

# ---------- the report builder -------------------------------------------
build_report <- function(cfg) {
  d <- cfg$data; vars <- names(d); N <- nrow(d); p <- length(vars)
  robust <- cfg$estimator == "MLR"
  m <- cfa(cfg$syntax, d, estimator = cfg$estimator)
  stopifnot(lavInspect(m, "converged"))
  fm <- fits(m, robust)
  known <- p * (p + 1) / 2
  R <- cor(d); maxr <- max(abs(R[lower.tri(R)])); detR <- det(R)
  mv <- mardia(d)
  inc <- cfg$include
  out <- character()
  add <- function(...) out <<- c(out, ...)

  add("#### Background", "", cfg$background, "", "#### Research question", "", cfg$rq, "")

  # ---- Methods
  add("#### Methods", "",
      "**Participants and procedure**", "",
      cfg$participants, "",
      "**Variables**", "",
      sprintf("- Indicators (%d, all continuous): %s", p, cfg$var_text),
      sprintf("- All %d indicators come from a single questionnaire, the %s.", p, cfg$instrument),
      sprintf("- Sample size: N = %d. The rule of thumb used was at least 10 participants per indicator (%d × 10 = %d); no power analysis was conducted.",
              N, p, p * 10),
      "- There were no missing data. All data were collected from participants (simulated for this exercise).", "",
      "**Analysis**", "",
      sprintf("- Analyses were run in R (%s) with the lavaan package (version %s); path diagrams were drawn with semPlot (version %s).",
              R.version.string, as.character(packageVersion("lavaan")), as.character(packageVersion("semPlot"))),
      "")

  # ---- Results
  add("#### Results", "")

  # Assumptions
  add("**Assumptions**", "")
  if (length(inc$assump) == 0) {
    add(miss("assumptions: linearity, multicollinearity, sample size, independence"))
  } else {
    a <- character()
    if ("lin" %in% inc$assump) a <- c(a, "- *Linearity:* Bivariate scatterplots for all pairs of indicators were inspected and showed approximately linear relationships.")
    if ("mc" %in% inc$assump) a <- c(a, sprintf("- *Multicollinearity:* The largest correlation among indicators was r = %s (below .85) and the determinant of the correlation matrix was %s (above .00001), so multicollinearity was not a concern.", nz(maxr, 2), nz(detR, 3)))
    if ("ss" %in% inc$assump) a <- c(a, sprintf("- *Adequate sample size:* N = %d meets the 10-participants-per-indicator rule of thumb (minimum = %d).", N, p * 10))
    if ("ind" %in% inc$assump) a <- c(a, "- *Independent observations:* Each participant completed the questionnaire once, on their own, and participants were recruited individually (not clustered in classes, clinics, or other groups).")
    add(a, "")
    for (mm in setdiff(c("lin", "mc", "ss", "ind"), inc$assump))
      add(miss(c(lin = "assumption: linearity", mc = "assumption: multicollinearity",
                 ss = "assumption: adequate sample size", ind = "assumption: independent observations")[[mm]]))
  }
  add("")

  # Distributions
  add("**Distributions**", "")
  if (inc$skew || inc$kurt) {
    add(skew_kurt_table(d, c(if (inc$skew) "skew", if (inc$kurt) "kurt")), "")
  }
  if (inc$mv) {
    add(sprintf("- Multivariate normality (Mardia's test): skewness = %s, χ²(%d) = %s, p %s; kurtosis = %s, z = %s, p %s.",
                f(mv$skew, 2), mv$skew_df, f(mv$skew_chi, 2), pf(mv$skew_p), f(mv$kurt, 2), f(mv$kurt_z, 2), pf(mv$kurt_p)), "")
  }
  if (!inc$skew) add(miss("univariate skewness"))
  if (!inc$kurt) add(miss("univariate kurtosis"))
  if (!inc$mv)   add(miss("multivariate normality"))
  if (!is.null(cfg$dist_note)) add(cfg$dist_note, "")
  if (!is.null(cfg$dist_missing)) add(miss(cfg$dist_missing))
  add("")

  # Data summary
  add("**Data summary**", "")
  if (inc$cov) add("Sample covariance matrix (variances on the diagonal):", "", cov_table(d, cfg$cov_dig), "")
  else add(miss("covariance table"))
  if (length(inc$desc)) add(if (inc$cov) "Descriptive statistics:" else "Descriptive statistics for each indicator:", "", desc_table(d, inc$desc), "")
  if (!is.null(cfg$summary_missing)) for (s in cfg$summary_missing) add(miss(s))
  add("")

  # Specification
  add("**Specification**", "")
  add("- Hypothesized model: a two-factor CFA (factors allowed to correlate), each indicator loading on one factor only, with no cross-loadings and no correlated residuals.")
  if (cfg$id == 5) add("- Two competing models were specified in advance (see Background): Model 1 (one factor) and Model 2 (two correlated factors).")
  add("- lavaan syntax for the hypothesized model:", "", "```r", cfg$syntax, "```", "")
  if (inc$ident) add("- Identification: the scale of each factor was set by fixing the first loading to 1 (marker variable); factor variances were freely estimated.")
  else add(miss("identification / scaling method"))
  if (inc$spec_params) add(sprintf("- Free parameters: %d (%s).", fm$npar, cfg$param_text)) else add(miss("number of free parameters"))
  if (inc$spec_df) add(sprintf("- Unique elements in the covariance matrix: %d; degrees of freedom: %d − %d = %d.", known, known, fm$npar, known - fm$npar))
  else add(miss("degrees of freedom"))
  if (inc$diagram) {
    mods <- if (cfg$id == 5) list(`Model 1: one factor` = cfa(cfg$syntax1, d, estimator = cfg$estimator),
                                 `Model 2: two factors` = m) else list(m)
    imgfile <- sprintf("img/report_%d_diagram.png", cfg$id)
    diagram(mods, file.path(out_dir, imgfile))
    imgfile <- paste0("/", out_dir, "/", imgfile)  # root-relative: works from the combined page and the standalone downloads
    add("", sprintf("![Figure 1. Hypothesized model.](%s){width=%s}", imgfile, if (cfg$id == 5) "100%" else "60%"), "")
  } else add(miss("path diagram"))
  add("")

  # Estimation
  add("**Estimation**", "")
  est_txt <- switch(cfg$estimator_text,
    ml  = "- Models were estimated with maximum likelihood (ML) in lavaan, using the sample covariance matrix.",
    mlr = "- Because the data were not normally distributed (see Distributions), models were estimated with robust maximum likelihood (MLR; Satorra–Bentler scaled test statistic, Huber–White standard errors) in lavaan. Scaled/robust fit indices are reported below.",
    generic = "- Models were estimated with maximum likelihood-based estimation in lavaan using the sample covariance matrix.")
  add(est_txt,
      "- The model converged with no warnings, and all variance estimates were positive (no Heywood cases).", "")

  # Model fit
  add("**Model fit**", "")
  fit_rows <- list(); fit_rows[[if (cfg$id == 5) "Model 2: two factors" else if (cfg$id == 4) "Model 1 (hypothesized)" else "Hypothesized model"]] <- fm
  m1 <- NULL; m2 <- NULL
  if (cfg$id == 4) {
    m2 <- cfa(cfg$syntax2, d, estimator = cfg$estimator); fit_rows[["Model 2 (respecified)"]] <- fits(m2, robust)
  }
  if (cfg$id == 5) {
    m1 <- cfa(cfg$syntax1, d, estimator = cfg$estimator)
    fit_rows <- c(list(`Model 1: one factor` = fits(m1, robust)), fit_rows)
  }
  add(sprintf("- Fit was evaluated with %s, and the cutoffs of Hu and Bentler (1999): CFI ≥ .95, RMSEA ≤ .06, SRMR ≤ .08.",
              paste(c(if (inc$fit_chisq) "the chi-square test", "CFI", if (inc$fit_rmsea) "RMSEA (90% CI)", "SRMR")[
                c(inc$fit_chisq, TRUE, inc$fit_rmsea, TRUE)], collapse = ", ")))
  if (robust) add("- Chi-square, CFI, and RMSEA are the scaled/robust versions.")
  add("", fit_table(fit_rows, inc$fit_chisq, inc$fit_rmsea, robust), "")
  if (!inc$fit_chisq) add(miss("chi-square test of model fit"))
  if (!inc$fit_rmsea) add(miss("RMSEA with 90% CI"))
  fin <- if (cfg$id == 4) fits(m2, robust) else fm
  fin_name <- if (cfg$id == 4) "the respecified model" else "the model"
  if (cfg$id == 5) fin_name <- "Model 2"
  add(sprintf("- %s", cfg$fit_text(fin, fin_name)), "")

  # Respecification / model comparison
  add("**Respecification**", "")
  if (cfg$id %in% 1:3) {
    add("- No respecification was carried out; the hypothesized model was retained as specified.", "")
  }
  if (cfg$id == 4) {
    mi <- modindices(m, sort. = TRUE)[1, ]
    lrt <- lavTestLRT(m, m2); lrt <- lrt[2, ]
    mf <- fits(m, robust)
    add(sprintf("- The hypothesized model fit poorly (CFI = %s, RMSEA = %s).", nz(mf$cfi, 3), nz(mf$rmsea, 3)),
        sprintf("- %s", flaw(sprintf("To improve fit, modification indices were inspected. The largest (MI = %s) suggested a residual covariance between %s and %s, so this parameter was freed.",
                                      f(mi$mi, 1), mi$lhs, mi$rhs))),
        sprintf("- %s", flaw("The two indicators are both about physical or mental reactions to the test, so the researchers felt the added parameter made sense.")),
        sprintf("- The respecified model fit better: scaled Δχ²(%d) = %s, p %s; ΔCFI = %s. Model 2 was retained as the final model.",
                lrt[["Df diff"]], f(lrt[["Chisq diff"]], 2), pf(lrt[["Pr(>Chisq)"]]), nz(fin$cfi - mf$cfi, 3)), "")
  }
  if (cfg$id == 5) {
    lrt <- lavTestLRT(m1, m)[2, ]
    f1 <- fits(m1, robust)
    add(sprintf("- As planned in the Background, Model 1 (one factor) and Model 2 (two correlated factors) were compared. Model 1 fit poorly (CFI = %s, SRMR = %s).",
                nz(f1$cfi, 3), nz(f1$srmr, 3)),
        sprintf("- Scaled chi-square difference test: Δχ²(%d) = %s, p %s; ΔCFI = %s, in favor of Model 2. Model 2 was retained.",
                lrt[["Df diff"]], f(lrt[["Chisq diff"]], 2), pf(lrt[["Pr(>Chisq)"]]), nz(fm$cfi - f1$cfi, 3)), "")
  }

  # Estimates
  add("**Estimates**", "")
  fin_m <- if (cfg$id == 4) m2 else m
  u <- inc$est_unstd; s <- inc$est_std
  if (isTRUE(inc$est_diagram)) {
    imgfile <- sprintf("img/report_%d_estimates.png", cfg$id)
    est_diagram(fin_m, file.path(out_dir, imgfile))
    add(sprintf("![Figure 2. Final model with standardized estimates.](%s){width=60%%}",
                paste0("/", out_dir, "/", imgfile)), "")
  }
  if (u || s) {
    add(if (cfg$id == 4) "Factor loadings (final model):" else "Factor loadings:", "", est_table(fin_m, vars, u, s), "",
        "Variances and covariances:", "", other_est_table(fin_m, u, s), "")
    if (u && !s) add("- Marker-variable loadings were fixed to 1 and so have no standard error.", "")
  }
  if (!u) add(miss("unstandardized estimates"))
  if (!s) add(miss("standardized estimates"))
  add("")

  # Discussion
  add("#### Discussion", "")
  add(cfg$discussion(fin, fin_m), "")

  list(text = paste(out, collapse = "\n"), fit = fm, model = m)
}

# =========================================================================
# Report definitions
# =========================================================================
V <- function(prefix, n) paste0(prefix, seq_len(n))
reports <- list()

# ---- Report 1: student engagement ---------------------------------------
v1 <- V("BEH", 4); v2 <- V("EMO", 4)
reports[[1]] <- list(
  id = 1, estimator = "ML", estimator_text = "ml", cov_dig = 2,
  data = gen(make_pop(c(.78, .72, .70, .66), c(.80, .76, .72, .68), .45, v1, v2, "BEHAV", "EMOT"),
             240, 101, M = c(5.1, 4.8, 4.5, 5.0, 4.6, 4.9, 4.2, 4.4), SD = rep(.9, 8),
             lo = 1, hi = 7, dig = 2, vars = c(v1, v2)),
  syntax = "BEHAV =~ BEH1 + BEH2 + BEH3 + BEH4\nEMOT  =~ EMO1 + EMO2 + EMO3 + EMO4",
  instrument = "School Engagement Questionnaire (SEQ; fictional)",
  param_text = "6 free loadings, 8 residual variances, 2 factor variances, 1 factor covariance",
  background = paste(
    "Student engagement is widely viewed as a key driver of achievement and school completion. Fredricks, Blumenfeld, and Paris (2004) described engagement as a multidimensional construct that includes, at a minimum, a behavioral dimension (what students do: participating, persisting, completing work) and an emotional dimension (how students feel: interest, enjoyment, belonging). Studies that treat engagement as a single score may hide the possibility that students can be behaviorally compliant but emotionally disconnected, or vice versa.",
    "",
    "In secondary school, engagement tends to decline from ninth grade onward, and teachers and counselors often use brief questionnaires to identify students who may need support. For such screening to be useful, a questionnaire must measure the dimensions it claims to measure. If behavioral and emotional engagement items are not empirically distinguishable, a total score would be sufficient and the two subscales would be redundant. If they are distinguishable but related, reporting two subscale scores provides more informative feedback to schools.",
    "",
    "The School Engagement Questionnaire (SEQ) was written by a district research office to provide short subscale scores for teachers. Its developers propose that four subscale scores reflect behavioral engagement and four reflect emotional engagement. Before the district uses the SEQ in schools, the structure implied by this scoring plan needs to be checked in a sample of students. A confirmatory factor analysis (CFA) is an appropriate way to test whether the proposed two-factor structure is consistent with the observed relationships among the eight subscale scores."),
  rq = "Is the proposed two-factor structure (behavioral engagement and emotional engagement) of the SEQ supported by the data from secondary school students?",
  participants = "- Participants were 240 ninth- and tenth-grade students from a single public school district who completed the SEQ on tablets during homeroom, with parental consent and student assent.\n- Participation was voluntary and anonymous; each student completed the questionnaire once, individually.",
  var_text = "four behavioral engagement subscale scores (BEH1 = class participation, BEH2 = homework completion, BEH3 = persistence, BEH4 = attention in class) and four emotional engagement subscale scores (EMO1 = interest, EMO2 = enjoyment, EMO3 = sense of belonging, EMO4 = enthusiasm). Each is the mean of that subscale's items on a 1–7 scale (higher = more engagement).",
  include = list(assump = character(0), skew = FALSE, kurt = TRUE, mv = TRUE, cov = TRUE, means = TRUE, cov_in_means = TRUE,
                 desc = "M", ident = TRUE, spec_params = TRUE, spec_df = TRUE, diagram = FALSE,
                 fit_chisq = TRUE, fit_rmsea = TRUE, est_unstd = TRUE, est_std = FALSE),
  fit_text = function(fm, nm) sprintf("%s fit the data well by all indices (CFI = %s, RMSEA = %s, SRMR = %s).", cap(nm), nz(fm$cfi, 3), nz(fm$rmsea, 3), nz(fm$srmr, 3)),
  discussion = function(fm, m) {
    pe <- parameterEstimates(m); phi <- pe[pe$op == "~~" & pe$lhs != pe$rhs & pe$lhs == "BEHAV", ]
    c("- The two-factor structure proposed for the SEQ was consistent with the data from this sample, which supports reporting separate behavioral and emotional engagement subscale scores.",
      sprintf("- The two factors were positively related (factor covariance = %s, p %s), so students who report higher behavioral engagement also tend to report higher emotional engagement, but the factors are not redundant.", f(phi$est, 2), pf(phi$pvalue)),
      "- Good fit does not prove the model is correct; other structures might fit equally well. The sample comes from one school district, so results may not generalize to other districts or grade levels.",
      "- Next steps include testing the structure in an independent sample before the SEQ is used for screening.")
  })

# ---- Report 2: L2 motivation --------------------------------------------
v1 <- V("IDL", 4); v2 <- V("OUG", 4)
reports[[2]] <- list(
  id = 2, estimator = "ML", estimator_text = "ml", cov_dig = 2,
  data = gen(make_pop(c(.82, .76, .71, .68), c(.74, .70, .65, .60), .32, v1, v2, "IDEAL", "OUGHT"),
             300, 202, M = c(4.4, 4.1, 3.9, 4.2, 3.2, 3.5, 3.0, 3.3), SD = c(1, .95, 1, .9, 1.1, 1, 1.05, 1),
             lo = 1, hi = 6, dig = 2, vars = c(v1, v2)),
  syntax = "IDEAL =~ IDL1 + IDL2 + IDL3 + IDL4\nOUGHT =~ OUG1 + OUG2 + OUG3 + OUG4",
  instrument = "L2 Motivational Self Questionnaire (L2MSQ; fictional)",
  param_text = NULL,
  background = paste(
    "Dörnyei's L2 Motivational Self System proposes that learning a second language (L2) is motivated by the learner's image of themselves as a future L2 user. Two components are especially prominent. The Ideal L2 Self is the person the learner would like to become, such as a fluent speaker who uses English in a satisfying career. The Ought-to L2 Self reflects attributes the learner believes they should have in order to meet expectations or avoid negative outcomes, such as disappointing family members.",
    "",
    "Research on these constructs in many countries has used questionnaires with items that are grouped into scales for each self-guide. A common finding is that the Ideal L2 Self is more strongly related to the effort learners say they will invest in learning, while the Ought-to L2 Self is more weakly related. This pattern only makes sense if the two self-guides are empirically distinct, yet some scholars have questioned whether learners differentiate between internalized aspirations and external obligations when they respond to questionnaires.",
    "",
    "The L2 Motivational Self Questionnaire (L2MSQ) was developed for adult learners of English enrolled in community language programs. It includes four subscale scores intended to reflect the Ideal L2 Self and four intended to reflect the Ought-to L2 Self. Because the instrument is new, evidence is needed that its scores follow the two-factor structure on which its scoring is based. A confirmatory factor analysis (CFA) tests whether the pattern of relationships among the eight subscale scores is consistent with two correlated factors."),
  rq = "Do the L2MSQ subscale scores reflect two correlated factors, Ideal L2 Self and Ought-to L2 Self, in a sample of adult English learners?",
  participants = "- Participants were 300 adults enrolled in English classes at community language programs, recruited individually through flyers and class announcements (no more than one participant per class section was drawn from any program cohort).\n- Participants completed the L2MSQ once, online, in about 15 minutes, and received a small gift card.",
  var_text = "four Ideal L2 Self subscale scores (IDL1 = imagined future use, IDL2 = career goals, IDL3 = fluent future self, IDL4 = admired speaker) and four Ought-to L2 Self subscale scores (OUG1 = family expectations, OUG2 = social obligation, OUG3 = avoiding disapproval, OUG4 = sense of duty). Each is the mean of that subscale's items on a 1–6 scale (higher = stronger agreement).",
  include = list(assump = c("lin", "ss", "ind"), skew = TRUE, kurt = FALSE, mv = TRUE, cov = TRUE, means = TRUE, cov_in_means = TRUE,
                 desc = "M", ident = TRUE, spec_params = FALSE, spec_df = FALSE, diagram = TRUE,
                 fit_chisq = TRUE, fit_rmsea = TRUE, est_unstd = FALSE, est_std = TRUE, est_diagram = TRUE),
  fit_text = function(fm, nm) sprintf("%s fit the data well by all indices (CFI = %s, RMSEA = %s, SRMR = %s).", cap(nm), nz(fm$cfi, 3), nz(fm$rmsea, 3), nz(fm$srmr, 3)),
  discussion = function(fm, m) {
    ss <- standardizedSolution(m); phi <- ss[ss$op == "~~" & ss$lhs == "IDEAL" & ss$rhs == "OUGHT", ]
    c("- The data were consistent with a two-factor structure for the L2MSQ, supporting the use of separate Ideal L2 Self and Ought-to L2 Self scores in this population.",
      sprintf("- The factors were positively but modestly correlated (standardized r = %s), which suggests that learners distinguish their own aspirations from perceived obligations even though the two are related.", nz(phi$est.std, 2)),
      "- All indicators had substantial standardized loadings on their intended factor.",
      "- Limitations: self-report data from adult learners in community programs may not generalize to school-aged learners or other languages. Fit supports the model but does not rule out alternative structures.")
  })

# ---- Report 3: depression & anxiety -------------------------------------
v1 <- V("TSK", 3); v2 <- V("SOC", 3)
reports[[3]] <- list(
  id = 3, estimator = "ML", estimator_text = "ml", cov_dig = 2,
  data = gen(make_pop(c(.80, .74, .68), c(.78, .72, .66), .62, v1, v2, "TASK", "SOCL"),
             200, 303, M = c(9.5, 8.8, 10.2, 10.1, 9.4, 11.0), SD = c(5, 4.6, 5.2, 4.8, 4.4, 5.1),
             lo = 0, hi = 30, dig = 0, vars = c(v1, v2)),
  syntax = "TASK =~ TSK1 + TSK2 + TSK3\nSOCL =~ SOC1 + SOC2 + SOC3",
  instrument = "Team Cohesion Scale for Recreational Sport (TCS-R; fictional)",
  param_text = "4 free loadings, 6 residual variances, 2 factor variances, 1 factor covariance",
  background = paste(
    "Team cohesion is the degree to which members of a group stick together and stay united in pursuit of shared goals. Researchers in sport psychology have long asked whether cohesion is a single quality of a team or has distinguishable parts. Carron's conceptual model separates task cohesion, the commitment of members to achieving the team's performance goals, from social cohesion, the extent to which members like each other and enjoy spending time together. Teams can be high on one and low on the other, for example a team that trains hard together but does not socialize.",
    "",
    "Coaches and league organizers often use short questionnaires that give a score for each type of cohesion. Reporting two scores is only meaningful if the questionnaire items actually separate into two related but distinct factors. If the factors were nearly perfectly correlated, a coach would gain little from having two scores, and decisions based on the separate scores, such as whether to schedule more practices or more team events, would be unwarranted.",
    "",
    "The Team Cohesion Scale for Recreational Sport (TCS-R) is a self-report measure designed for adult recreational leagues. It yields three task cohesion subscale scores (shared goals, commitment to practice, role clarity) and three social cohesion subscale scores (friendship, time together, team spirit). Each subscale score is the sum of five items rated from 0 (strongly disagree) to 6 (strongly agree). The measure has not yet been evaluated in the adult league players for whom it was developed. A confirmatory factor analysis (CFA) provides a direct test of whether the six subscale scores are consistent with a two-factor structure."),
  rq = "Are task cohesion and social cohesion on the TCS-R best represented by two correlated factors in a sample of adult recreational league players?",
  participants = "- Participants were 200 adults playing in community recreational leagues (soccer, volleyball, and softball), recruited through league organizers and notices posted at community sports centers. Players on professional or collegiate teams were not eligible.\n- Each participant completed the TCS-R once, individually and confidentially, online, and received a $10 gift card.",
  var_text = "three task cohesion subscale scores (TSK1 = shared goals, TSK2 = commitment to practice, TSK3 = role clarity) and three social cohesion subscale scores (SOC1 = friendship, SOC2 = time together, SOC3 = team spirit). Each is the sum of five items, with possible scores from 0 to 30 (higher = stronger cohesion).",
  include = list(assump = c("lin", "mc", "ss", "ind"), skew = FALSE, kurt = FALSE, mv = FALSE, cov = FALSE, means = TRUE, cov_in_means = FALSE,
                 desc = c("M", "SD", "Min", "Max"), ident = FALSE, spec_params = TRUE, spec_df = TRUE, diagram = TRUE,
                 fit_chisq = FALSE, fit_rmsea = TRUE, est_unstd = TRUE, est_std = TRUE, est_diagram = TRUE),
  fit_text = function(fm, nm) sprintf("%s showed acceptable fit (CFI = %s, RMSEA = %s, SRMR = %s).", cap(nm), nz(fm$cfi, 3), nz(fm$rmsea, 3), nz(fm$srmr, 3)),
  discussion = function(fm, m) {
    c("- Sport is one of the most popular leisure activities among adults, and community leagues are often run by volunteers with limited resources.",
      "- Participation in team sport is associated with better health, stronger friendships, and a greater sense of belonging, so it is important that people have access to leagues.",
      "- Cities should consider increasing funding for community sports facilities, and coaches should continue to hold regular team events.",
      "- Future research should examine which coaching styles work best for recreational teams.")
  })

# ---- Report 4: test anxiety (non-normal; ad hoc respecification) --------
v1 <- V("WOR", 4); v2 <- V("EMT", 4)
pop4 <- make_pop(c(.80, .75, .72, .70), c(.78, .74, .70, .66), .58, v1, v2, "WORRY", "EMOTION", resid_cov = "WOR4 ~~ 0.30*EMT1")
reports[[4]] <- list(
  id = 4, estimator = "MLR", estimator_text = "mlr", cov_dig = 1,
  data = gen(pop4, 210, 403, M = rep(34, 8), SD = rep(14, 8), lo = 0, hi = 100, dig = 1, vars = c(v1, v2),
             skew = rep(1.1, 8), kurt = rep(3.5, 8)),
  syntax  = "WORRY   =~ WOR1 + WOR2 + WOR3 + WOR4\nEMOTION =~ EMT1 + EMT2 + EMT3 + EMT4",
  syntax2 = "WORRY   =~ WOR1 + WOR2 + WOR3 + WOR4\nEMOTION =~ EMT1 + EMT2 + EMT3 + EMT4\nWOR4 ~~ EMT1",
  instrument = "Student Test Anxiety Scale (STAS; fictional)",
  param_text = "6 free loadings, 8 residual variances, 2 factor variances, 1 factor covariance",
  background = paste(
    "Test anxiety is a situation-specific form of anxiety that can interfere with performance on exams and other evaluative tasks. Liebert and Morris (1967) distinguished between worry, the cognitive component (concern about failing, comparing oneself to others), and emotionality, the physiological component (rapid heartbeat, nausea, tension). This two-component view has shaped both research and the design of test anxiety questionnaires for several decades.",
    "",
    "Testing professionals and school counselors need to know whether the scores they interpret reflect these separate components. If worry and emotionality are distinct but related, a student's profile can guide different interventions: cognitive strategies for worry and relaxation techniques for emotionality. If the two components cannot be separated, a single total score would be appropriate for screening and interpretation, and two subscale scores would be misleading.",
    "",
    "The Student Test Anxiety Scale (STAS) was designed for undergraduate students. Its eight subscale scores are intended to represent four indicators of worry and four indicators of emotionality. Each subscale score is a percentage of the maximum possible score on that subscale, ranging from 0 to 100, with higher values indicating greater test anxiety. Because most students report relatively low levels of test anxiety, scores are expected to be concentrated at the lower end of the scale.",
    "",
    "The purpose of this study was to evaluate whether the eight STAS subscale scores are consistent with the proposed two-factor structure. A confirmatory factor analysis (CFA) was used to test the structure in a sample of undergraduates."),
  rq = "Is the two-factor structure of the STAS (worry and emotionality) supported in a sample of undergraduate students?",
  participants = "- Participants were 210 undergraduate students recruited individually from a university participant pool. Students completed the STAS once, online, in the week before a midterm exam period, and received course credit.\n- No participants were from the same class section.",
  var_text = "four worry subscale scores (WOR1 = fear of failure, WOR2 = social comparison, WOR3 = self-doubt, WOR4 = thoughts of consequences) and four emotionality subscale scores (EMT1 = racing heart, EMT2 = nausea, EMT3 = muscle tension, EMT4 = sweating). Each is a percentage-of-maximum score from 0 to 100 (higher = more test anxiety).",
  include = list(assump = "ind", skew = TRUE, kurt = TRUE, mv = TRUE, cov = TRUE, means = FALSE, cov_in_means = FALSE,
                 desc = character(0), ident = TRUE, spec_params = TRUE, spec_df = TRUE, diagram = FALSE,
                 fit_chisq = TRUE, fit_rmsea = TRUE, est_unstd = TRUE, est_std = TRUE),
  dist_note = "- The indicators were positively skewed and heavy-tailed, and the multivariate normality tests were rejected. For this reason, a robust estimator was used (see Estimation).",
  summary_missing = "indicator means and standard descriptives",
  fit_text = function(fm, nm) sprintf("%s showed acceptable fit (CFI = %s, RMSEA = %s, SRMR = %s).", cap(nm), nz(fm$cfi, 3), nz(fm$rmsea, 3), nz(fm$srmr, 3)),
  discussion = function(fm, m) {
    ss <- standardizedSolution(m); phi <- ss[ss$op == "~~" & ss$lhs == "WORRY" & ss$rhs == "EMOTION", ]
    c("- The data were consistent with a two-factor structure for the STAS, with worry and emotionality as distinct but related components of test anxiety.",
      sprintf("- Worry and emotionality were moderately to strongly correlated (standardized r = %s). This is in line with earlier literature that these components usually go together.", nz(phi$est.std, 2)),
      "- The final model included one residual covariance that was added after seeing the data, so the fit of the final model may be optimistic. The result should be confirmed in a new sample.",
      "- The sample is from one university, so claims about other student populations would be premature.")
  })

# ---- Report 5: mobile app evaluation (non-normal; planned model comparison) -----
v1 <- V("EAS", 4); v2 <- V("USE", 4)
reports[[5]] <- list(
  id = 5, estimator = "MLR", estimator_text = "generic", cov_dig = 1,
  data = gen(make_pop(c(.78, .74, .70, .66), c(.80, .76, .70, .64), .60, v1, v2, "EASE", "USEF"),
             280, 502, M = rep(40, 8), SD = rep(15, 8), lo = 0, hi = 100, dig = 1, vars = c(v1, v2),
             skew = rep(1, 8), kurt = rep(3, 8)),
  syntax  = "EASE =~ EAS1 + EAS2 + EAS3 + EAS4\nUSEF =~ USE1 + USE2 + USE3 + USE4",
  syntax1 = "APP =~ EAS1 + EAS2 + EAS3 + EAS4 + USE1 + USE2 + USE3 + USE4",
  instrument = "Mobile App Evaluation Scale (MAES; fictional)",
  param_text = "6 free loadings, 8 residual variances, 2 factor variances, 1 factor covariance (Model 2)",
  background = paste(
    "When people decide whether to keep using a mobile app, they evaluate it on several grounds. The technology acceptance literature, following Davis (1989), distinguishes perceived ease of use (how effortless the app is to operate) from perceived usefulness (how much the app helps the user accomplish something). On one view, users form a single global impression of an app, so ease and usefulness are not separable in questionnaire responses: an app is simply evaluated more or less favorably. On another view, ease of use and usefulness are distinct judgments, and an app can be easy to use but not useful, or useful but hard to use.",
    "",
    "The distinction matters for practice. If evaluation is unidimensional, a single score would be sufficient and design work would target overall favorability. If the two dimensions are separable, product teams could evaluate ease of use and usefulness separately and tailor improvements, for example by simplifying navigation while adding features that serve user goals.",
    "",
    "The Mobile App Evaluation Scale (MAES) was written for adult smartphone users. It provides four subscale scores for ease of use and four for usefulness, each a percentage-of-maximum score from 0 to 100. Previous work with the MAES has not directly compared the one- and two-dimension views against each other.",
    "",
    "The purpose of this study was to compare two competing theoretical models of the MAES prior to analyzing the data. Model 1 is a one-factor model in which all eight subscale scores reflect a general evaluation of the app. Model 2 is a two-factor model in which four subscale scores reflect ease of use and four reflect usefulness, with the factors allowed to correlate. The models were specified in advance based on the theoretical positions above, and were to be compared using the scaled chi-square difference test and the change in CFI."),
  rq = "Are adults' evaluations of a mobile app better represented by a one-factor model or by a two-factor model (ease of use and usefulness)?",
  participants = "- Participants were 280 adult smartphone users who responded to individual invitations sent through an online research panel. Each participant evaluated the same (fictional) budgeting app after a week of use, completed the MAES once, online, and received a small payment.\n- Responses were collected individually (no group administration).",
  var_text = "four ease of use subscale scores (EAS1 = easy to learn, EAS2 = clear navigation, EAS3 = few errors, EAS4 = quick to operate) and four usefulness subscale scores (USE1 = saves time, USE2 = helps reach goals, USE3 = useful features, USE4 = worth recommending). Each is a percentage-of-maximum score from 0 to 100 (higher = more favorable).",
  include = list(assump = c("lin", "mc", "ss", "ind"), skew = TRUE, kurt = TRUE, mv = TRUE, cov = FALSE, means = FALSE, cov_in_means = FALSE,
                 desc = c("SD", "Min", "Max"), ident = TRUE, spec_params = TRUE, spec_df = FALSE, diagram = TRUE,
                 fit_chisq = TRUE, fit_rmsea = FALSE, est_unstd = TRUE, est_std = TRUE, est_diagram = TRUE),
  dist_note = "- The indicators were positively skewed, and multivariate normality was rejected.",
  dist_missing = "estimator change and rationale for non-normal data",
  summary_missing = "indicator means",
  fit_text = function(fm, nm) sprintf("%s fit the data well (CFI = %s, SRMR = %s).", cap(nm), nz(fm$cfi, 3), nz(fm$srmr, 3)),
  discussion = function(fm, m) {
    c("- Because the two-factor model fit better than the one-factor model, ease of use causes perceived usefulness. Simplifying the interface should therefore make users find the app more useful.",
      "- Because the model fit well, we can conclude it is the true structure of app evaluation, and the MAES measures user evaluations accurately for all apps.",
      "- The two-factor structure was shown to be the same for younger and older users, and also across countries, so companies around the world can use the MAES subscale scores to compare users.",
      "- Product teams can use these results to guarantee that users will keep using their apps.")
  })

# For Report 5, flag the illogical claims for the teacher version
# (applied to the rendered text after build, see below)

# ---------- write everything ---------------------------------------------
for (r in reports) {
  res <- build_report(r)
  txt <- res$text
  if (r$id == 5) {
    d_start <- regexpr("#### Discussion", txt, fixed = TRUE)
    head_txt <- substr(txt, 1, d_start - 1); disc <- substr(txt, d_start, nchar(txt))
    lines <- strsplit(disc, "\n")[[1]]
    lines <- ifelse(grepl("^- ", lines), paste0("- ", vapply(sub("^- ", "", lines), flaw, "")), lines)
    txt <- paste0(head_txt, paste(lines, collapse = "\n"))
  }
  if (r$id == 3) {
    d_start <- regexpr("#### Discussion", txt, fixed = TRUE)
    head_txt <- substr(txt, 1, d_start - 1); disc <- substr(txt, d_start, nchar(txt))
    lines <- strsplit(disc, "\n")[[1]]
    lines <- ifelse(grepl("^- ", lines), paste0("- ", vapply(sub("^- ", "", lines), flaw, "")), lines)
    txt <- paste0(head_txt, paste(lines, collapse = "\n"))
  }
  writeLines(txt, file.path(out_dir, sprintf("_report_%d.qmd", r$id)))
  cat(sprintf("Report %d: chisq=%.2f df=%d CFI=%.3f RMSEA=%.3f\n", r$id, res$fit$chisq, res$fit$df, res$fit$cfi, res$fit$rmsea))
}
