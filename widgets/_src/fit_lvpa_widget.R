# Fit the two LVPA models used by the LVPA matrix playground and write
# widgets/_src/lvpa_fit.json (read by build_lvpa_playground.py).
#
# Run from the project root:  Rscript widgets/_src/fit_lvpa_widget.R
#
# Data: PISA 2022 GBR, 21 variables with rotated (planned) missingness: no
# student answers all items, and there are ~2,200 missing-data patterns, which
# makes lavaan's FIML far too slow. So we get the ML (EM) mean vector and
# covariance matrix under multivariate normality, then fit the models to that
# matrix with N = number of students. Standard errors and chi-square are
# therefore approximate (they treat every student as complete); the point
# estimates are the FIML ones.
#
# Models (marker-indicator scaling; MATH_AVE is the single indicator of `math`):
#   hyp : stress ~ gm; anx ~ gm + stress; math ~ anx; simple-structure measurement
#   noGS: the same without stress ~ gm (and gm ~~ stress fixed to 0)
suppressMessages({ library(lavaan); library(jsonlite) })

d <- read.csv("data/w12_data_pisa22_GBR_anx_stress_growth.csv")
gm <- sprintf("ST263Q%02dJA", c(2, 4, 6, 8))
st <- sprintf("ST345Q%02dJA", 1:10)
an <- sprintf("ST292Q%02dJA", 1:6)
vars <- c(gm, st, an, "MATH_AVE")      # widget indicator order 1..21
Y <- as.matrix(d[, vars]); n <- nrow(Y); p <- ncol(Y)

# ---- EM estimate of mean and covariance with missing data ----
pat <- apply(!is.na(Y), 1, function(r) paste(as.integer(r), collapse = ""))
groups <- split(seq_len(n), pat)
mu <- colMeans(Y, na.rm = TRUE); S <- diag(apply(Y, 2, var, na.rm = TRUE))
for (it in 1:500) {
  sx <- rep(0, p); sxx <- matrix(0, p, p)
  for (g in groups) {
    o <- which(!is.na(Y[g[1], ])); m <- setdiff(seq_len(p), o)
    Yg <- Y[g, , drop = FALSE]; ng <- length(g)
    if (length(m) == 0) { sx <- sx + colSums(Yg); sxx <- sxx + crossprod(Yg); next }
    Soo <- S[o, o, drop = FALSE]; Smo <- S[m, o, drop = FALSE]
    B <- Smo %*% solve(Soo)
    Xh <- Yg
    Xh[, m] <- matrix(mu[m], ng, length(m), byrow = TRUE) +
      (Yg[, o, drop = FALSE] - matrix(mu[o], ng, length(o), byrow = TRUE)) %*% t(B)
    C <- S[m, m, drop = FALSE] - B %*% t(Smo)
    sx <- sx + colSums(Xh); sxx <- sxx + crossprod(Xh); sxx[m, m] <- sxx[m, m] + ng * C
  }
  mu2 <- sx / n; S2 <- sxx / n - tcrossprod(mu2)
  delta <- max(abs(S2 - S)); mu <- mu2; S <- S2
  if (delta < 1e-7) break
}
dimnames(S) <- list(vars, vars)
# MATH_AVE has a variance near 8,400 while the survey items are near 1; that
# spread stalls the optimizer (math ~ anx collapses to R2 = 1). Put the score on
# a /100 scale for estimation. Standardized results do not depend on this.
S["MATH_AVE", ] <- S["MATH_AVE", ] / 100; S[, "MATH_AVE"] <- S[, "MATH_AVE"] / 100

meas <- paste0(
  "gm =~ ", paste(gm, collapse = " + "), "\n",
  "stress =~ ", paste(st, collapse = " + "), "\n",
  "anx =~ ", paste(an, collapse = " + "), "\n",
  "math =~ 1*MATH_AVE\nMATH_AVE ~~ 0*MATH_AVE\n")
mods <- list(
  hyp  = paste0(meas, "stress ~ gm\nanx ~ gm + stress\nmath ~ anx\n"),
  # gm and stress are both exogenous once stress ~ gm is dropped, so lavaan would
  # free their covariance; fix it to 0 to match the widget (psi cells stay 0)
  noGS = paste0(meas, "anx ~ gm + stress\nmath ~ anx\ngm ~~ 0*stress\n"))
fits <- lapply(mods, function(m) sem(m, sample.cov = S, sample.nobs = n, estimator = "ML"))

fac <- c("gm", "stress", "anx", "math")
out <- list(n = n, vars = vars)
for (nm in names(fits)) {
  f <- fits[[nm]]
  fm <- fitMeasures(f, c("chisq", "df", "pvalue", "cfi", "tli", "rmsea", "rmsea.ci.lower",
                         "rmsea.ci.upper", "srmr", "aic", "bic", "npar"))
  ss <- standardizedSolution(f)
  lam <- matrix(NA_real_, p, 4, dimnames = list(vars, fac))
  for (i in which(ss$op == "=~")) lam[ss$rhs[i], ss$lhs[i]] <- ss$est.std[i]
  beta <- matrix(NA_real_, 4, 4, dimnames = list(fac, fac))
  for (i in which(ss$op == "~" & ss$lhs %in% fac)) beta[ss$lhs[i], ss$rhs[i]] <- ss$est.std[i]
  psi <- setNames(sapply(fac, function(z) ss$est.std[ss$op == "~~" & ss$lhs == z & ss$rhs == z]), fac)
  theta <- setNames(sapply(vars, function(z) ss$est.std[ss$op == "~~" & ss$lhs == z & ss$rhs == z]), vars)
  # p-values of the structural paths (approximate, see header)
  bp <- ss[ss$op == "~" & ss$lhs %in% fac, c("lhs", "rhs", "est.std", "pvalue")]
  r2 <- inspect(f, "r2")
  rr <- residuals(f, type = "cor")$cov
  out[[nm]] <- list(
    fit = as.list(fm),
    lambda = unname(lam), beta = unname(beta), psi = unname(psi), theta = unname(theta),
    paths = bp, r2 = as.list(r2[c("stress", "anx", "math")]),
    resid = unname(round(rr, 3)))
}
lr <- anova(fits$noGS, fits$hyp)
out$lrt <- list(chisq = lr$`Chisq diff`[2], df = lr$`Df diff`[2], p = lr$`Pr(>Chisq)`[2])
write_json(out, "widgets/_src/lvpa_fit.json", digits = 4, auto_unbox = TRUE, na = "null")
cat("wrote widgets/_src/lvpa_fit.json\n")
print(round(unlist(out$hyp$fit), 3)); print(round(unlist(out$noGS$fit), 3)); print(out$lrt); print(out$hyp$paths)
