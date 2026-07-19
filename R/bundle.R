.slice_required_sir_columns <- function() {
  c(
    "PATID", "EVTID", "ELTID", "DATEPRELEV", "HEUREPRELEV",
    "souche_id", "naturepvt_norm", "bact_norm", "SEJUF",
    "amoxicilline_ampicilline", "cefotaxime", "ceftazidime",
    "ceftriaxone", "cefoxitine", "oxacilline", "blse_status_row",
    "carbapenemase_status_row"
  )
}

.resolve_atb_cols <- function(bundle) {
  meta <- bundle[["sir_wide_meta"]]
  sir <- bundle[["sir_wide"]]
  atb_cols <- meta[["atb_cols"]]
  if (is.null(atb_cols) || length(atb_cols) == 0L) {
    atb_cols <- meta[["supported_atb_cols"]]
  }
  atb_cols <- intersect(as.character(atb_cols), names(sir))
  if (length(atb_cols) == 0L) {
    .abort("sir_wide_meta does not identify any observed antibiotic columns.")
  }
  atb_cols
}

.canonical_contract_version <- function(bundle) {
  meta <- bundle[["sir_wide_meta"]]
  if (!is.list(meta)) {
    .abort("sir_wide_meta must be a list.")
  }

  version <- meta[["contract_version"]]
  if (is.null(version)) {
    return("v1")
  }
  if (
    !is.character(version) || length(version) != 1L || is.na(version) ||
      !version %in% c("v1", "v2")
  ) {
    .abort("sir_wide_meta$contract_version must be one of: v1, v2.")
  }
  if (identical(version, "v2")) {
    semantics <- meta[["sejuf_semantics"]]
    if (
      !is.character(semantics) || length(semantics) != 1L ||
        is.na(semantics) ||
        !identical(semantics, "hospitalization_unit_at_sampling")
    ) {
      .abort(
        "sir_wide_meta$sejuf_semantics must equal ",
        "'hospitalization_unit_at_sampling' for contract v2."
      )
    }
  }
  version
}

.validate_slice_bundle <- function(bundle) {
  required_names <- c(
    "sir_wide", "sir_wide_meta", "sample_scope_reference",
    "denominator_bundle"
  )
  if (!is.list(bundle) || !all(required_names %in% names(bundle))) {
    .abort(
      "bundle must contain: ", paste(required_names, collapse = ", ")
    )
  }

  .canonical_contract_version(bundle)

  sir <- bundle[["sir_wide"]]
  scope <- bundle[["sample_scope_reference"]]
  denominator_bundle <- bundle[["denominator_bundle"]]
  .assert_data_frame(sir, "sir_wide")
  .assert_columns(sir, .slice_required_sir_columns(), "sir_wide")
  .assert_data_frame(scope, "sample_scope_reference")
  .assert_columns(
    scope,
    c(
      "SEJUF", "sample_uf_is_eligible_by_ta_de",
      "sample_uf_ta_de_status", "sample_uf_ta_de_reason"
    ),
    "sample_scope_reference"
  )

  row_ids <- .make_canonical_row_id(sir)
  if (anyDuplicated(row_ids)) {
    .abort("sir_wide canonical row grain is not unique.")
  }
  .calendar_year(sir[["DATEPRELEV"]])

  scope_sejuf <- .trim_or_na(scope[["SEJUF"]])
  if (any(is.na(scope_sejuf)) || anyDuplicated(scope_sejuf)) {
    .abort("sample_scope_reference must contain one non-missing row per SEJUF.")
  }
  eligible <- scope[["sample_uf_is_eligible_by_ta_de"]]
  if (!is.logical(eligible) || any(is.na(eligible))) {
    .abort("sample_scope_reference eligibility must be logical without NA.")
  }

  if (!is.list(denominator_bundle)) {
    .abort("denominator_bundle must be a list.")
  }
  denominator <- denominator_bundle[["incidence_denominator_by_year"]]
  .assert_data_frame(
    denominator,
    "denominator_bundle$incidence_denominator_by_year"
  )
  .assert_columns(
    denominator,
    c("calendar_year", "hospital_nights"),
    "denominator_bundle$incidence_denominator_by_year"
  )
  if (
    any(is.na(denominator[["calendar_year"]])) ||
      any(is.na(denominator[["hospital_nights"]])) ||
      anyDuplicated(denominator[["calendar_year"]]) ||
      any(denominator[["hospital_nights"]] < 0)
  ) {
    .abort("The annual incidence denominator violates the canonical invariants.")
  }

  .resolve_atb_cols(bundle)
  invisible(bundle)
}

#' Read a validated ORCHIDEE canonical bundle
#'
#' @param bundle_dir Directory containing the four canonical v1 or v2 RDS files.
#' @return A named list containing the canonical bundle objects.
#' @export
read_orchidee_bundle <- function(bundle_dir) {
  if (length(bundle_dir) != 1L || is.na(bundle_dir) || !dir.exists(bundle_dir)) {
    .abort("bundle_dir must identify an existing directory.")
  }
  files <- c(
    sir_wide = "sir_wide.rds",
    sir_wide_meta = "sir_wide_meta.rds",
    sample_scope_reference = "sample_scope_reference.rds",
    denominator_bundle = "denominator_bundle.rds"
  )
  paths <- file.path(bundle_dir, files)
  missing <- files[!file.exists(paths)]
  if (length(missing) > 0L) {
    .abort("Missing canonical bundle files: ", paste(missing, collapse = ", "))
  }
  bundle <- lapply(paths, readRDS)
  names(bundle) <- names(files)
  .validate_slice_bundle(bundle)
  bundle
}
