# Build a CSV with math anxiety, stress resilience, growth mindset, and math score
# from the PISA 2022 subset (see `countries` below). Run locally from the project root.
library(dplyr)

pv_math <- paste0("PV", 1:10, "MATH")

anx_items    <- sprintf("ST292Q%02dJA", 1:6)          # math anxiety items (-> ANXMAT)
stress_items <- sprintf("ST345Q%02dJA", 1:10)         # stress resilience items (-> STRESAGR)
growth_items <- sprintf("ST263Q%02dJA", c(2, 4, 6, 8)) # growth mindset items (-> GROSAGR)

# Country filter. Stress resilience (ST345) was NOT administered in the USA
# (all 97 = "not administered"), so USA alone cannot support the stress factor.
# GBR has stress data. Use c("USA", "GBR", "KSV") to keep all three.
countries <- "GBR"

pisa_subset <- read.csv("data/pisa22_USA_GBR_KSV.csv")

pisa_anx_stress_growth <- pisa_subset %>%
  filter(CNT %in% countries) %>%
  select(
    CNT, CNTSTUID,
    all_of(anx_items),
    all_of(stress_items),
    all_of(growth_items),
    all_of(pv_math)
  ) %>%
  mutate(MATH_AVE = rowMeans(across(all_of(pv_math)))) %>%
  select(-all_of(pv_math))   # keep only the average, drop the individual PVs

# Recode special missing codes to NA. Students are NOT deleted for partial
# missingness: PISA 2022 rotates questionnaire items, so no student answers all
# 20 items. Estimate with FIML (e.g. lavaan: missing = "fiml"). The only rows
# removed are students with no answers on any item (see filter below).
miss_codes <- c(7, 8, 9, 95, 97, 98, 99)
all_items  <- c(anx_items, stress_items, growth_items)

pisa_anx_stress_growth <- pisa_anx_stress_growth %>%
  mutate(across(all_of(all_items), ~ if_else(.x %in% miss_codes, NA_real_, as.numeric(.x)))) %>%
  # remove students with no answers on any of the 20 items (only a math score)
  filter(if_any(all_of(all_items), ~ !is.na(.x)))

write.csv(pisa_anx_stress_growth,
          "data/w12_data_pisa22_GBR_anx_stress_growth.csv",
          row.names = FALSE)

# Smaller random sample for teaching: FIML on all students is slow because the
# rotated items create hundreds of missing-data patterns. Seeded so it is
# reproducible. (Random, NOT chosen to make the results look good.)
set.seed(625)
pisa_sample <- pisa_anx_stress_growth[sample(nrow(pisa_anx_stress_growth), 1000), ]
write.csv(pisa_sample,
          "data/w12_data_pisa22_GBR_anx_stress_growth_n1000.csv",
          row.names = FALSE)
