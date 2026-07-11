.apply_ecoli_c3g_plausibility_qc <- function(df) {
  c3g_cols <- c("cefotaxime", "ceftazidime", "ceftriaxone")
  c3g_r <- rowSums(df[c3g_cols] == "R", na.rm = TRUE) > 0L
  excluded <- !is.na(df[["amoxicilline_ampicilline"]]) &
    df[["amoxicilline_ampicilline"]] == "S" & c3g_r

  audit <- data.frame(
    canonical_row_id = df[["canonical_row_id"]],
    excluded_by_plausibility_qc = excluded,
    plausibility_reason = ifelse(
      excluded,
      "enterobacterales_amoxampi_s_c3g_r",
      NA_character_
    ),
    stringsAsFactors = FALSE
  )

  list(
    data = df[!excluded, , drop = FALSE],
    excluded = df[excluded, , drop = FALSE],
    audit = audit
  )
}

.apply_saureus_methicillin_plausibility_qc <- function(df) {
  oxacillin <- as.character(df[["oxacilline"]])
  cefoxitin <- as.character(df[["cefoxitine"]])
  excluded <- !is.na(oxacillin) & !is.na(cefoxitin) &
    oxacillin != cefoxitin

  audit <- data.frame(
    canonical_row_id = df[["canonical_row_id"]],
    excluded_by_plausibility_qc = excluded,
    plausibility_reason = ifelse(
      excluded,
      "saureus_oxa_cefox_discordance",
      NA_character_
    ),
    stringsAsFactors = FALSE
  )

  list(
    data = df[!excluded, , drop = FALSE],
    excluded = df[excluded, , drop = FALSE],
    audit = audit
  )
}

.apply_kpneumo_blse_plausibility_qc <- function(df) {
  excluded <- !is.na(df[["amoxicilline_ampicilline"]]) &
    df[["amoxicilline_ampicilline"]] == "S"

  audit <- data.frame(
    canonical_row_id = df[["canonical_row_id"]],
    excluded_by_plausibility_qc = excluded,
    plausibility_reason = ifelse(
      excluded,
      "klebsiella_enterobacter_amoxampi_s",
      NA_character_
    ),
    stringsAsFactors = FALSE
  )

  list(
    data = df[!excluded, , drop = FALSE],
    excluded = df[excluded, , drop = FALSE],
    audit = audit
  )
}
