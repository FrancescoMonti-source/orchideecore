.apply_ratb_scope <- function(sir_wide, sample_scope_reference) {
  sir <- sir_wide
  ref <- sample_scope_reference
  sir[["SEJUF"]] <- .trim_or_na(sir[["SEJUF"]])
  ref[["SEJUF"]] <- .trim_or_na(ref[["SEJUF"]])

  matched <- match(sir[["SEJUF"]], ref[["SEJUF"]])
  missing_uf <- is.na(sir[["SEJUF"]])
  unmapped_uf <- !missing_uf & is.na(matched)

  eligible <- ref[["sample_uf_is_eligible_by_ta_de"]][matched]
  status <- as.character(ref[["sample_uf_ta_de_status"]][matched])
  reason <- as.character(ref[["sample_uf_ta_de_reason"]][matched])
  eligible[is.na(eligible)] <- FALSE
  status[missing_uf] <- "review_missing_sample_uf"
  reason[missing_uf] <- "missing_sample_uf"
  status[unmapped_uf] <- "review_unmapped_uf"
  reason[unmapped_uf] <- "uf_absent_from_consores_structure"

  sir[["sample_uf_is_eligible_by_ta_de"]] <- eligible
  sir[["sample_uf_ta_de_status"]] <- status
  sir[["sample_uf_ta_de_reason"]] <- reason

  audit <- data.frame(
    canonical_row_id = sir[["canonical_row_id"]],
    SEJUF = sir[["SEJUF"]],
    scope_reference_matched = !is.na(matched),
    included_in_analytic_scope = eligible,
    scope_status = status,
    scope_reason = reason,
    stringsAsFactors = FALSE
  )

  list(
    data = sir[eligible, , drop = FALSE],
    audit = audit
  )
}

.filter_taxon <- function(df, target_taxon) {
  included <- !is.na(df[["bact_norm"]]) &
    df[["bact_norm"]] == target_taxon
  list(
    data = df[included, , drop = FALSE],
    audit = data.frame(
      canonical_row_id = df[["canonical_row_id"]],
      bact_norm = as.character(df[["bact_norm"]]),
      included_in_target_taxon = included,
      taxon_reason = ifelse(included, "target_taxon", "not_target_taxon"),
      stringsAsFactors = FALSE
    )
  )
}
