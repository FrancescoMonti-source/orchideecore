# Why: protects the K. pneumoniae intrinsic-resistance plausibility exclusion.
test_that("K. pneumoniae susceptible to ampicillin is excluded", {
  result <- run_kpneumo_blse_slice(make_kpneumo_blse_fixture())
  expect_equal(sum(result$plausibility_audit$excluded_by_plausibility_qc), 1L)
  expect_equal(
    as.character(na.omit(result$plausibility_audit$plausibility_reason)),
    "klebsiella_enterobacter_amoxampi_s"
  )
})

# Why: protects the dedup invariant that public phenotype flags are finalized per class.
test_that("BLSE status is finalized on retained classes", {
  result <- run_kpneumo_blse_slice(make_kpneumo_blse_fixture())
  representatives <- result$representatives
  expect_true(all(c("blse_status_final", "blse_flag") %in% names(representatives)))
  expect_equal(
    representatives$blse_flag,
    representatives$blse_status_final == "positive"
  )
})

# Why: protects the phenotype_flag recipe and its distinct publication IDs.
test_that("the BLSE slice produces all-isolate proportion and incidence", {
  result <- run_kpneumo_blse_slice(make_kpneumo_blse_fixture())
  expect_false(result$manifest$completion_applied)
  expect_equal(
    result$manifest$method_profile,
    "kpneumo_blse_raw_global_patient_year_v1"
  )
  expect_equal(result$population_summary$n_rows, c(7L, 6L, 5L, 4L, 3L))

  resistance <- result$resistance_annual
  expect_equal(resistance$indicator_id, "kpneumo_blse_prop_global")
  expect_equal(resistance$n_isolates, 3L)
  expect_equal(resistance$n_r, 1L)
  expect_equal(resistance$n_s, 2L)
  expect_equal(resistance$n_o, 0L)
  expect_equal(resistance$n_tested, 3L)
  expect_equal(resistance$pct_resistant, 100 / 3)

  incidence <- result$incidence_annual
  expect_equal(incidence$indicator_id, rep("kpneumo_blse_inc_global", 2))
  expect_equal(incidence$n_resistant, c(1L, 0L))
  expect_equal(incidence$incidence_density_per_1000, c(1, 0))
})
