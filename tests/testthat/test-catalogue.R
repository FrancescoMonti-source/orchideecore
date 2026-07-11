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
