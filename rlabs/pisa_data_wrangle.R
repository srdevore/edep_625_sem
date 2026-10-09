# note that the original pisa dataset was too large to be uploaded, so you only updloaded the subste. 
library(haven)
library(dplyr)

pv_read <- paste0("PV", 1:10, "READ")
pv_math <- paste0("PV", 1:10, "MATH")
pv_scie <- paste0("PV", 1:10, "SCIE")

pisa_subset <- read.csv("data/pisa22_USA_GBR_KSV.csv")

pisa_us_cfa_examples <- pisa_subset %>%
  filter(CNT == "USA") %>%
  select(
    PARENTED  = PAREDINT,
    BOOKSHOME = ST255Q01JA,
    TECHHOME  = ICTRES,
    IMMIG, WORKPAY, WORKHOME, EFFORT1, STUDYHMW, MISSSC,
    all_of(c(pv_read, pv_math, pv_scie))
  ) %>%
  mutate(across(everything(), zap_labels)) %>%
  mutate(
    PARENTED    = na_if(PARENTED, 9999),
    BOOKSHOME   = if_else(BOOKSHOME %in% c(5, 95, 99), NA_real_, as.numeric(BOOKSHOME)),
    READING_AVE = rowMeans(across(all_of(pv_read))),
    MATH_AVE    = rowMeans(across(all_of(pv_math))),
    SCIENCE_AVE = rowMeans(across(all_of(pv_scie)))
  ) %>%
  select(PARENTED, BOOKSHOME, TECHHOME, IMMIG, WORKPAY, WORKHOME,
         READING_AVE, MATH_AVE, SCIENCE_AVE, EFFORT1, STUDYHMW, MISSSC)

write.csv(pisa_us_cfa_examples,
          "data/w07_data_pisa22_USA_cln_cfa.csv",
          row.names = FALSE)
