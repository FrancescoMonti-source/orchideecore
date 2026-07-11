.derive_ecoli_c3g <- function(representatives) {
  c3g_cols <- c("cefotaxime", "ceftazidime", "ceftriaxone")
  values <- as.data.frame(lapply(representatives[c3g_cols], as.character))
  n_tested <- rowSums(values == "S" | values == "R", na.rm = TRUE)
  n_resistant <- rowSums(values == "R", na.rm = TRUE)
  result <- ifelse(n_resistant > 0L, "R", ifelse(n_tested == 0L, "O", "S"))
  data.frame(
    canonical_row_id = representatives[["canonical_row_id"]],
    PATID = as.character(representatives[["PATID"]]),
    dedup_year = representatives[["dedup_year"]],
    phenotype_class = representatives[["phenotype_class"]],
    indicator_id = "ecoli_c3g",
    indicator_result = result,
    n_tested_cells = n_tested,
    n_resistant_cells = n_resistant,
    stringsAsFactors = FALSE
  )
}

.derive_saureus_methicillin <- function(representatives) {
  cefoxitin <- as.character(representatives[["cefoxitine"]])
  oxacillin <- as.character(representatives[["oxacilline"]])
  cefoxitin_tested <- cefoxitin %in% c("S", "R")
  oxacillin_tested <- oxacillin %in% c("S", "R")
  chosen <- rep(NA_character_, nrow(representatives))
  chosen[cefoxitin_tested] <- cefoxitin[cefoxitin_tested]
  fallback <- !cefoxitin_tested & oxacillin_tested
  chosen[fallback] <- oxacillin[fallback]
  tested <- !is.na(chosen)
  result <- ifelse(tested, chosen, "O")

  data.frame(
    canonical_row_id = representatives[["canonical_row_id"]],
    PATID = as.character(representatives[["PATID"]]),
    dedup_year = representatives[["dedup_year"]],
    phenotype_class = representatives[["phenotype_class"]],
    indicator_id = "saureus_meticilline",
    indicator_result = result,
    n_tested_cells = as.integer(tested),
    n_resistant_cells = as.integer(tested & chosen == "R"),
    stringsAsFactors = FALSE
  )
}

.derive_kpneumo_blse <- function(representatives) {
  positive <- as.logical(representatives[["blse_flag"]])
  positive[is.na(positive)] <- FALSE
  result <- ifelse(positive, "R", "S")

  data.frame(
    canonical_row_id = representatives[["canonical_row_id"]],
    PATID = as.character(representatives[["PATID"]]),
    dedup_year = representatives[["dedup_year"]],
    phenotype_class = representatives[["phenotype_class"]],
    indicator_id = "kpneumo_blse",
    indicator_result = result,
    n_tested_cells = rep.int(1L, nrow(representatives)),
    n_resistant_cells = as.integer(positive),
    stringsAsFactors = FALSE
  )
}

.resolve_indicator_id <- function(isolate_results) {
  indicator_ids <- unique(as.character(isolate_results[["indicator_id"]]))
  indicator_ids <- indicator_ids[!is.na(indicator_ids)]
  if (length(indicator_ids) != 1L) {
    .abort("isolate_results must contain exactly one indicator_id.")
  }
  indicator_ids[[1L]]
}

.summarize_resistance_annual <- function(isolate_results) {
  indicator_id <- .resolve_indicator_id(isolate_results)
  years <- sort(unique(isolate_results[["dedup_year"]]))
  rows <- lapply(years, function(year) {
    result <- isolate_results[["indicator_result"]][
      isolate_results[["dedup_year"]] == year
    ]
    n_r <- sum(result == "R", na.rm = TRUE)
    n_s <- sum(result == "S", na.rm = TRUE)
    n_o <- sum(result == "O", na.rm = TRUE)
    n_tested <- n_r + n_s
    data.frame(
      indicator_id = indicator_id,
      dedup_year = as.integer(year),
      scope = "global",
      n_isolates = length(result),
      n_r = n_r,
      n_s = n_s,
      n_o = n_o,
      n_tested = n_tested,
      n_resistant = n_r,
      pct_resistant = if (n_tested > 0L) 100 * n_r / n_tested else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  .bind_rows_base(rows)
}

.summarize_incidence_annual <- function(isolate_results, denominator) {
  indicator_id <- .resolve_indicator_id(isolate_results)
  denominator <- data.frame(
    dedup_year = as.integer(denominator[["calendar_year"]]),
    hospital_nights = as.numeric(denominator[["hospital_nights"]]),
    stringsAsFactors = FALSE
  )
  resistant <- isolate_results[
    isolate_results[["indicator_result"]] == "R", , drop = FALSE
  ]
  counts <- if (nrow(resistant) == 0L) {
    data.frame(dedup_year = integer(), n_resistant = integer())
  } else {
    count_table <- table(resistant[["dedup_year"]])
    data.frame(
      dedup_year = as.integer(names(count_table)),
      n_resistant = as.integer(count_table),
      stringsAsFactors = FALSE
    )
  }
  out <- merge(denominator, counts, by = "dedup_year", all.x = TRUE, sort = TRUE)
  out[["n_resistant"]][is.na(out[["n_resistant"]])] <- 0L
  out[["incidence_density_per_1000"]] <- ifelse(
    out[["hospital_nights"]] > 0,
    1000 * out[["n_resistant"]] / out[["hospital_nights"]],
    NA_real_
  )
  out[["indicator_id"]] <- indicator_id
  out[["scope"]] <- "global"
  out[c(
    "indicator_id", "dedup_year", "scope", "n_resistant",
    "hospital_nights", "incidence_density_per_1000"
  )]
}
