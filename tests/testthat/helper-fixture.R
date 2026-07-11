make_slice_fixture <- function() {
  sir <- data.frame(
    PATID = c("P1", "P1", "P2", "P3", "P4", "P5", "P6"),
    EVTID = paste0("E", seq_len(7)),
    ELTID = paste0("L", seq_len(7)),
    DATEPRELEV = as.Date(c(
      "2024-01-02", "2024-02-02", "2024-03-02", "2024-04-02",
      "2024-05-02", "2024-06-02", "2024-07-02"
    )),
    HEUREPRELEV = rep("09:00:00", 7),
    souche_id = paste0("S", seq_len(7)),
    naturepvt_norm = rep("urines", 7),
    bact_norm = c(rep("escherichia_coli", 6), "klebsiella_pneumoniae"),
    SEJUF = c(rep("UF1", 5), "UF2", "UF1"),
    amoxicilline_ampicilline = c("R", "R", "R", "R", "S", "R", "R"),
    cefotaxime = c("R", NA, "S", NA, "R", "R", "R"),
    ceftazidime = rep(NA_character_, 7),
    ceftriaxone = c(NA, "R", NA, NA, NA, NA, NA),
    cefoxitine = rep(NA_character_, 7),
    oxacilline = rep(NA_character_, 7),
    gentamicine = c("S", NA, NA, NA, NA, NA, NA),
    blse_status_row = rep("negative", 7),
    carbapenemase_status_row = rep("negative", 7),
    blse_flag = rep(FALSE, 7),
    carbapenemase_flag = rep(FALSE, 7),
    stringsAsFactors = FALSE
  )
  atb_cols <- c(
    "amoxicilline_ampicilline", "cefotaxime", "ceftazidime",
    "ceftriaxone", "gentamicine"
  )
  sir[["nb_resultats"]] <- rowSums(
    sir[atb_cols] == "S" | sir[atb_cols] == "R",
    na.rm = TRUE
  )
  list(
    sir_wide = sir,
    sir_wide_meta = list(
      atb_cols = atb_cols,
      supported_atb_cols = unique(c(atb_cols, "cefoxitine", "oxacilline"))
    ),
    sample_scope_reference = data.frame(
      SEJUF = c("UF1", "UF2"),
      sample_uf_is_eligible_by_ta_de = c(TRUE, FALSE),
      sample_uf_ta_de_status = c("eligible_ta_de", "excluded_ta"),
      sample_uf_ta_de_reason = c("eligible_ta_de", "ta_not_03_20"),
      stringsAsFactors = FALSE
    ),
    denominator_bundle = list(
      incidence_denominator_by_year = data.frame(
        calendar_year = c(2024L, 2025L),
        hospital_nights = c(1000L, 2000L)
      )
    )
  )
}

make_saureus_fixture <- function() {
  sir <- data.frame(
    PATID = c("P1", "P1", "P2", "P3", "P4", "P5", "P6"),
    EVTID = paste0("SE", seq_len(7)),
    ELTID = paste0("SL", seq_len(7)),
    DATEPRELEV = as.Date(c(
      "2024-01-03", "2024-02-03", "2024-03-03", "2024-04-03",
      "2024-05-03", "2024-06-03", "2024-07-03"
    )),
    HEUREPRELEV = rep("10:00:00", 7),
    souche_id = paste0("SS", seq_len(7)),
    naturepvt_norm = rep("hemoculture", 7),
    bact_norm = c(rep("staphylococcus_aureus", 6), "escherichia_coli"),
    SEJUF = c(rep("UF1", 5), "UF2", "UF1"),
    amoxicilline_ampicilline = rep(NA_character_, 7),
    cefotaxime = rep(NA_character_, 7),
    ceftazidime = rep(NA_character_, 7),
    ceftriaxone = rep(NA_character_, 7),
    cefoxitine = c(NA, NA, NA, NA, "R", NA, NA),
    oxacilline = c("R", "R", "S", NA, "S", "R", "R"),
    gentamicine = c("S", NA, NA, NA, NA, NA, NA),
    blse_status_row = rep("negative", 7),
    carbapenemase_status_row = rep("negative", 7),
    blse_flag = rep(FALSE, 7),
    carbapenemase_flag = rep(FALSE, 7),
    stringsAsFactors = FALSE
  )
  atb_cols <- c(
    "amoxicilline_ampicilline", "cefotaxime", "ceftazidime",
    "ceftriaxone", "oxacilline", "gentamicine"
  )
  sir[["nb_resultats"]] <- rowSums(
    sir[atb_cols] == "S" | sir[atb_cols] == "R",
    na.rm = TRUE
  )
  list(
    sir_wide = sir,
    sir_wide_meta = list(
      atb_cols = atb_cols,
      supported_atb_cols = unique(c(atb_cols, "cefoxitine"))
    ),
    sample_scope_reference = data.frame(
      SEJUF = c("UF1", "UF2"),
      sample_uf_is_eligible_by_ta_de = c(TRUE, FALSE),
      sample_uf_ta_de_status = c("eligible_ta_de", "excluded_ta"),
      sample_uf_ta_de_reason = c("eligible_ta_de", "ta_not_03_20"),
      stringsAsFactors = FALSE
    ),
    denominator_bundle = list(
      incidence_denominator_by_year = data.frame(
        calendar_year = c(2024L, 2025L),
        hospital_nights = c(1000L, 2000L)
      )
    )
  )
}

make_kpneumo_blse_fixture <- function() {
  sir <- data.frame(
    PATID = c("P1", "P1", "P2", "P3", "P4", "P5", "P6"),
    EVTID = paste0("KE", seq_len(7)),
    ELTID = paste0("KL", seq_len(7)),
    DATEPRELEV = as.Date(c(
      "2024-01-04", "2024-02-04", "2024-03-04", "2024-04-04",
      "2024-05-04", "2024-06-04", "2024-07-04"
    )),
    HEUREPRELEV = rep("11:00:00", 7),
    souche_id = paste0("KS", seq_len(7)),
    naturepvt_norm = rep("urines", 7),
    bact_norm = c(rep("klebsiella_pneumoniae", 6), "escherichia_coli"),
    SEJUF = c(rep("UF1", 5), "UF2", "UF1"),
    amoxicilline_ampicilline = c("R", "R", "R", "R", "S", "R", "R"),
    cefotaxime = rep(NA_character_, 7),
    ceftazidime = rep(NA_character_, 7),
    ceftriaxone = rep(NA_character_, 7),
    cefoxitine = rep(NA_character_, 7),
    oxacilline = rep(NA_character_, 7),
    gentamicine = c("S", NA, NA, NA, NA, NA, NA),
    blse_status_row = c(
      "positive", "positive", "negative", "no_signal", "positive",
      "positive", "negative"
    ),
    carbapenemase_status_row = rep("negative", 7),
    blse_flag = c(TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE),
    carbapenemase_flag = rep(FALSE, 7),
    stringsAsFactors = FALSE
  )
  atb_cols <- c(
    "amoxicilline_ampicilline", "cefotaxime", "ceftazidime",
    "ceftriaxone", "gentamicine"
  )
  sir[["nb_resultats"]] <- rowSums(
    sir[atb_cols] == "S" | sir[atb_cols] == "R",
    na.rm = TRUE
  )
  list(
    sir_wide = sir,
    sir_wide_meta = list(
      atb_cols = atb_cols,
      supported_atb_cols = unique(c(atb_cols, "cefoxitine", "oxacilline"))
    ),
    sample_scope_reference = data.frame(
      SEJUF = c("UF1", "UF2"),
      sample_uf_is_eligible_by_ta_de = c(TRUE, FALSE),
      sample_uf_ta_de_status = c("eligible_ta_de", "excluded_ta"),
      sample_uf_ta_de_reason = c("eligible_ta_de", "ta_not_03_20"),
      stringsAsFactors = FALSE
    ),
    denominator_bundle = list(
      incidence_denominator_by_year = data.frame(
        calendar_year = c(2024L, 2025L),
        hospital_nights = c(1000L, 2000L)
      )
    )
  )
}

make_catalogue_fixture <- function() {
  bundle <- make_saureus_fixture()
  spec <- ratb_indicator_catalogue()
  requested <- unique(unlist(strsplit(
    spec$molecule_values[!is.na(spec$molecule_values)],
    "|",
    fixed = TRUE
  )))
  requested <- requested[nzchar(requested)]
  for (column in setdiff(requested, names(bundle$sir_wide))) {
    bundle$sir_wide[[column]] <- NA_character_
  }
  bundle$sir_wide$SEJUF[7] <- "UF2"
  bundle$sir_wide_meta$supported_atb_cols <- requested
  bundle
}
