# Why: protects the current S. aureus oxacillin/cefoxitin plausibility rule.
test_that("discordant oxacillin and cefoxitin row is excluded", {
  result <- run_saureus_methicillin_slice(make_saureus_fixture())
  expect_equal(sum(result$plausibility_audit$excluded_by_plausibility_qc), 1L)
  expect_equal(
    as.character(na.omit(result$plausibility_audit$plausibility_reason)),
    "saureus_oxa_cefox_discordance"
  )
})

# Why: protects the specification rule that cefoxitin has priority over oxacillin.
test_that("methicillin uses cefoxitin first and oxacillin as fallback", {
  representatives <- data.frame(
    canonical_row_id = c("a", "b", "c"),
    PATID = c("P1", "P2", "P3"),
    dedup_year = rep(2024L, 3),
    phenotype_class = rep(1L, 3),
    cefoxitine = c("R", "S", NA),
    oxacilline = c("S", "R", "R"),
    stringsAsFactors = FALSE
  )
  result <- orchideecore:::.derive_saureus_methicillin(representatives)
  expect_equal(result$indicator_result, c("R", "S", "R"))
})

# Why: protects the second complete recipe and proves the common runner is not C3G-specific.
test_that("the methicillin slice produces expected annual outputs", {
  result <- run_saureus_methicillin_slice(make_saureus_fixture())
  expect_false(result$manifest$completion_applied)
  expect_equal(
    result$manifest$method_profile,
    "saureus_methicillin_raw_global_patient_year_v1"
  )
  expect_equal(result$population_summary$n_rows, c(7L, 6L, 5L, 4L, 3L))

  resistance <- result$resistance_annual
  expect_equal(resistance$indicator_id, "saureus_meticilline")
  expect_equal(resistance$n_isolates, 3L)
  expect_equal(resistance$n_r, 1L)
  expect_equal(resistance$n_s, 1L)
  expect_equal(resistance$n_o, 1L)
  expect_equal(resistance$pct_resistant, 50)

  incidence <- result$incidence_annual
  expect_equal(incidence$n_resistant, c(1L, 0L))
  expect_equal(incidence$incidence_density_per_1000, c(1, 0))
})
