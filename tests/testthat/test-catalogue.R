# Why: protects the published catalogue boundary copied from ORCHIDEE 1.
test_that("the packaged catalogue has the complete closed vocabulary", {
  spec <- ratb_indicator_catalogue()
  expect_equal(nrow(spec), 140L)
  expect_equal(anyDuplicated(spec$indicator_id), 0L)
  expect_equal(
    as.integer(table(spec$indicator_kind)[c(
      "class_any_r", "molecule_direct", "molecule_priority",
      "phenotype_flag"
    )]),
    c(19L, 111L, 1L, 9L)
  )
  expect_equal(sum(spec$publish_proportion), 136L)
  expect_equal(sum(spec$publish_incidence), 135L)
})

# Why: protects the intentionally small public package interface.
test_that("only the bundle, catalogue, and complete runner are exported", {
  expect_equal(
    sort(getNamespaceExports("orchideecore")),
    sort(c(
      "read_orchidee_bundle", "ratb_indicator_catalogue",
      "run_ratb_catalogue"
    ))
  )
})

# Why: protects the versioned output contract and its stable analytical keys.
test_that("the complete runner returns the ratb catalogue result v1 contract", {
  result <- run_ratb_catalogue(make_catalogue_fixture())
  expect_s3_class(result, "orchidee_ratb_catalogue")
  expect_named(result, c(
    "manifest", "catalogue", "population_summary", "scope_audit",
    "plausibility_audit", "plausibility_unavailable_rules", "dedup",
    "isolate_results", "proportion_annual", "incidence_annual"
  ))
  expect_identical(
    result$manifest$output_contract,
    "ratb_catalogue_result_v1"
  )
  expect_identical(result$manifest$canonical_contract, "v1")
  expect_equal(
    anyDuplicated(result$proportion_annual[c(
      "indicator_id", "scope", "sample_type", "dedup_year"
    )]),
    0L
  )
  expect_equal(
    anyDuplicated(result$incidence_annual[c(
      "indicator_id", "scope", "sample_type", "dedup_year"
    )]),
    0L
  )
  expect_equal(
    anyDuplicated(result$isolate_results[c(
      "canonical_row_id", "scope", "sample_type", "indicator_id"
    )]),
    0L
  )
  expect_true(all(
    result$isolate_results$indicator_result %in% c("R", "S", "O")
  ))
  expect_false(".row_id_global" %in% names(
    result$dedup$global$representatives
  ))
  expect_false(".row_id_global" %in% names(
    result$dedup$by_type$representatives
  ))
})

# Why: protects the closed canonical input contract and truthful provenance.
test_that("the runners recognize only valid canonical bundle v2 metadata", {
  bundle <- make_catalogue_fixture()
  bundle$sir_wide_meta$contract_version <- "v2"
  bundle$sir_wide_meta$sejuf_semantics <-
    "hospitalization_unit_at_sampling"

  result <- run_ratb_catalogue(bundle)
  expect_identical(result$manifest$canonical_contract, "v2")
  expect_identical(result$manifest$output_contract, "ratb_catalogue_result_v1")
  focused <- run_saureus_methicillin_slice(bundle)
  expect_identical(focused$manifest$canonical_contract, "v2")

  bundle$sir_wide_meta$sejuf_semantics <- "microbiology_unit_at_sampling"
  expect_error(
    run_ratb_catalogue(bundle),
    "sejuf_semantics must equal 'hospitalization_unit_at_sampling'"
  )

  bundle$sir_wide_meta$sejuf_semantics <- NULL
  expect_error(run_ratb_catalogue(bundle), "sejuf_semantics must equal")

  bundle$sir_wide_meta$contract_version <- "v3"
  expect_error(run_ratb_catalogue(bundle), "contract_version must be one of")
})

# Why: protects the output contract when a valid bundle has no eligible rows.
test_that("empty catalogue results retain their typed schemas", {
  bundle <- make_catalogue_fixture()
  bundle$sample_scope_reference$sample_uf_is_eligible_by_ta_de[] <- FALSE
  result <- run_ratb_catalogue(bundle)

  expect_equal(nrow(result$isolate_results), 0L)
  expect_named(result$isolate_results, c(
    "canonical_row_id", "PATID", "dedup_year", "phenotype_class", "scope",
    "sample_type", "indicator_id", "indicator_result", "n_tested_cells",
    "n_resistant_cells"
  ))
  expect_equal(nrow(result$proportion_annual), 0L)
  expect_named(result$proportion_annual, c(
    "indicator_id", "dataset", "organism_section", "organism_label",
    "report_taxon_label", "indicator_label", "indicator_kind",
    "numerator_kind", "denominator_kind", "display_order", "scope",
    "sample_type", "dedup_year", "n_isolates", "n_r", "n_s", "n_o",
    "n_tested", "n_resistant", "pct_resistant"
  ))
})

# Why: protects the current S. aureus catalogue recipe beyond methicillin alone.
test_that("the catalogue executes all S. aureus indicator kinds", {
  result <- run_ratb_catalogue(make_catalogue_fixture())
  expect_false(result$manifest$completion_applied)
  expect_equal(result$manifest$n_indicators, 140L)
  expect_equal(result$manifest$dedup_scopes, c("global", "by_type"))

  saureus <- result$proportion_annual[
    result$proportion_annual$organism_section == "staphylococcus_aureus",
    , drop = FALSE
  ]
  expect_equal(length(unique(saureus$indicator_id)), 19L)
  expect_equal(sort(unique(saureus$scope)), c("by_type", "global"))

  methicillin <- saureus[
    saureus$indicator_id == "saureus_meticilline" &
      saureus$scope == "global",
    , drop = FALSE
  ]
  expect_equal(methicillin$n_r, 1L)
  expect_equal(methicillin$n_s, 1L)
  expect_equal(methicillin$n_o, 1L)

  gentamicin <- saureus[
    saureus$indicator_id == "saureus_gentamicine" &
      saureus$scope == "global",
    , drop = FALSE
  ]
  expect_equal(gentamicin$n_s, 1L)
  expect_equal(gentamicin$n_o, 2L)
})

# Why: protects the method contract that by-type deduplication includes sample type.
test_that("global and by-type scopes use different patient-year keys", {
  bundle <- make_catalogue_fixture()
  bundle$sir_wide$naturepvt_norm[2] <- "urines"
  result <- run_ratb_catalogue(bundle)

  global <- result$dedup$global$representatives
  by_type <- result$dedup$by_type$representatives
  global_p1 <- global[
    global$PATID == "P1" & global$bact_norm == "staphylococcus_aureus",
    , drop = FALSE
  ]
  by_type_p1 <- by_type[
    by_type$PATID == "P1" & by_type$bact_norm == "staphylococcus_aureus",
    , drop = FALSE
  ]
  expect_equal(nrow(global_p1), 1L)
  expect_equal(nrow(by_type_p1), 2L)
  expect_equal(sort(by_type_p1$naturepvt_norm), c("hemoculture", "urines"))
})

# Why: protects the publication contract that incidence has a complete year grid.
test_that("catalogue incidence keeps zero years and incidence-only IDs", {
  result <- run_ratb_catalogue(make_catalogue_fixture())
  incidence <- result$incidence_annual
  expect_equal(length(unique(incidence$indicator_id)), 135L)
  expect_true("kpneumo_blse_inc_global" %in% incidence$indicator_id)
  kpneumo <- incidence[
    incidence$indicator_id == "kpneumo_blse_inc_global", , drop = FALSE
  ]
  expect_equal(kpneumo$n_resistant, c(0L, 0L))
  expect_equal(kpneumo$dedup_year, c(2024L, 2025L))
})
