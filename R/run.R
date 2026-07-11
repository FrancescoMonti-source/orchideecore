.run_raw_indicator_slice <- function(
    bundle,
    target_taxon,
    plausibility_function,
    derivation_function,
    method_profile,
    indicator_inputs,
    resistance_indicator_id,
    incidence_indicator_id
  ) {
  .validate_slice_bundle(bundle)
  sir <- bundle[["sir_wide"]]
  sir[["canonical_row_id"]] <- .make_canonical_row_id(sir)
  atb_cols <- .resolve_atb_cols(bundle)

  scope <- .apply_ratb_scope(
    sir,
    bundle[["sample_scope_reference"]]
  )
  target <- .filter_taxon(scope$data, target_taxon)
  plausibility <- plausibility_function(target$data)
  dedup <- .deduplicate_raw_patient_year(plausibility$data, atb_cols)
  isolate_results <- derivation_function(dedup$representatives)
  resistance <- .summarize_resistance_annual(isolate_results)
  incidence <- .summarize_incidence_annual(
    isolate_results,
    bundle[["denominator_bundle"]][["incidence_denominator_by_year"]]
  )
  resistance[["indicator_id"]] <- resistance_indicator_id
  incidence[["indicator_id"]] <- incidence_indicator_id

  population_summary <- data.frame(
    stage = c(
      "canonical_bundle", "analytic_scope", "target_taxon",
      "plausibility_qc", "dedup_representatives"
    ),
    n_rows = c(
      nrow(sir), nrow(scope$data), nrow(target$data),
      nrow(plausibility$data), nrow(dedup$representatives)
    ),
    stringsAsFactors = FALSE
  )

  out <- list(
    manifest = list(
      method_profile = method_profile,
      canonical_contract = "v1",
      completion_applied = FALSE,
      indicator_inputs = indicator_inputs,
      resistance_indicator_id = resistance_indicator_id,
      incidence_indicator_id = incidence_indicator_id
    ),
    population_summary = population_summary,
    scope_audit = scope$audit,
    taxon_audit = target$audit,
    plausibility_audit = plausibility$audit,
    dedup_class_map = dedup$class_map,
    dedup_episode_summary = dedup$episode_summary,
    representatives = dedup$representatives,
    isolate_results = isolate_results,
    resistance_annual = resistance,
    incidence_annual = incidence
  )
  class(out) <- c("orchidee_core_slice", "list")
  out
}

#' Run the raw E. coli C3G experimental slice
#'
#' @param bundle A list returned by [read_orchidee_bundle()] or an equivalent
#'   in-memory canonical bundle.
#' @return A named list containing results and stage-level audit artifacts.
#' @keywords internal
run_ecoli_c3g_slice <- function(bundle) {
  .run_raw_indicator_slice(
    bundle = bundle,
    target_taxon = "escherichia_coli",
    plausibility_function = .apply_ecoli_c3g_plausibility_qc,
    derivation_function = .derive_ecoli_c3g,
    method_profile = "ecoli_c3g_raw_global_patient_year_v1",
    indicator_inputs = c("cefotaxime", "ceftazidime", "ceftriaxone"),
    resistance_indicator_id = "ecoli_c3g",
    incidence_indicator_id = "ecoli_c3g"
  )
}

#' Run the raw S. aureus methicillin experimental slice
#'
#' @param bundle A list returned by [read_orchidee_bundle()] or an equivalent
#'   in-memory canonical bundle.
#' @return A named list containing results and stage-level audit artifacts.
#' @keywords internal
run_saureus_methicillin_slice <- function(bundle) {
  .run_raw_indicator_slice(
    bundle = bundle,
    target_taxon = "staphylococcus_aureus",
    plausibility_function = .apply_saureus_methicillin_plausibility_qc,
    derivation_function = .derive_saureus_methicillin,
    method_profile = "saureus_methicillin_raw_global_patient_year_v1",
    indicator_inputs = c("cefoxitine", "oxacilline"),
    resistance_indicator_id = "saureus_meticilline",
    incidence_indicator_id = "saureus_meticilline"
  )
}

#' Run the raw K. pneumoniae BLSE experimental slice
#'
#' @param bundle A list returned by [read_orchidee_bundle()] or an equivalent
#'   in-memory canonical bundle.
#' @return A named list containing results and stage-level audit artifacts.
#' @keywords internal
run_kpneumo_blse_slice <- function(bundle) {
  .run_raw_indicator_slice(
    bundle = bundle,
    target_taxon = "klebsiella_pneumoniae",
    plausibility_function = .apply_kpneumo_blse_plausibility_qc,
    derivation_function = .derive_kpneumo_blse,
    method_profile = "kpneumo_blse_raw_global_patient_year_v1",
    indicator_inputs = "blse_flag",
    resistance_indicator_id = "kpneumo_blse_prop_global",
    incidence_indicator_id = "kpneumo_blse_inc_global"
  )
}
