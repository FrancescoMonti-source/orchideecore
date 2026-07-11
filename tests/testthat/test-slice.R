# Why: protects the canonical scope contract for missing and unmapped units.
test_that("scope decisions are explicit", {
  bundle <- make_slice_fixture()
  bundle$sir_wide$SEJUF[c(1, 2)] <- c(NA, "UF_UNKNOWN")
  bundle$sir_wide$EVTID[c(1, 2)] <- c("E_missing", "E_unmapped")
  result <- run_ecoli_c3g_slice(bundle)
  audit <- result$scope_audit[1:2, ]
  expect_false(any(audit$included_in_analytic_scope))
  expect_equal(
    audit$scope_reason,
    c("missing_sample_uf", "uf_absent_from_consores_structure")
  )
})

# Why: protects the current scientific exclusion applied before deduplication.
test_that("implausible E. coli C3G pattern is excluded", {
  result <- run_ecoli_c3g_slice(make_slice_fixture())
  expect_equal(sum(result$plausibility_audit$excluded_by_plausibility_qc), 1L)
  expect_equal(
    as.character(na.omit(result$plausibility_audit$plausibility_reason)),
    "enterobacterales_amoxampi_s_c3g_r"
  )
})

# Why: protects the raw SPARES compatibility and representative-selection rule.
test_that("compatible sparse rows share a class and keep the most complete row", {
  result <- run_ecoli_c3g_slice(make_slice_fixture())
  p1 <- result$dedup_class_map[result$dedup_class_map$PATID == "P1", ]
  expect_equal(length(unique(p1$phenotype_class)), 1L)
  expect_equal(sum(p1$is_representative), 1L)
  expect_true(grepl("2:L1", p1$canonical_row_id[p1$is_representative], fixed = TRUE))
})

# Why: protects the engine invariant that overlapping S/R conflicts cannot mix.
test_that("antibiotic conflict creates separate classes", {
  bundle <- make_slice_fixture()
  bundle$sir_wide$cefotaxime[2] <- "S"
  bundle$sir_wide$nb_resultats[2] <- 3L
  result <- run_ecoli_c3g_slice(bundle)
  p1 <- result$dedup_class_map[result$dedup_class_map$PATID == "P1", ]
  expect_equal(length(unique(p1$phenotype_class)), 2L)
  expect_equal(sum(p1$is_representative), 2L)
})

# Why: protects the current phenotype compatibility boundary during deduplication.
test_that("positive and non-positive phenotype signals do not mix", {
  bundle <- make_slice_fixture()
  bundle$sir_wide$blse_status_row[2] <- "positive"
  bundle$sir_wide$blse_flag[2] <- TRUE
  result <- run_ecoli_c3g_slice(bundle)
  p1 <- result$dedup_class_map[result$dedup_class_map$PATID == "P1", ]
  expect_equal(length(unique(p1$phenotype_class)), 2L)
})

# Why: protects the complete current recipe from canonical rows to published metrics.
test_that("the bounded slice produces expected annual proportion and incidence", {
  result <- run_ecoli_c3g_slice(make_slice_fixture())
  expect_false(result$manifest$completion_applied)
  expect_equal(result$population_summary$n_rows, c(7L, 6L, 5L, 4L, 3L))

  resistance <- result$resistance_annual
  expect_equal(resistance$n_isolates, 3L)
  expect_equal(resistance$n_r, 1L)
  expect_equal(resistance$n_s, 1L)
  expect_equal(resistance$n_o, 1L)
  expect_equal(resistance$n_tested, 2L)
  expect_equal(resistance$pct_resistant, 50)

  incidence <- result$incidence_annual
  expect_equal(incidence$n_resistant, c(1L, 0L))
  expect_equal(incidence$incidence_density_per_1000, c(1, 0))
})
