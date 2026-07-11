#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
  stop(
    "Usage: Rscript compare_catalogue_reference.R <orchidee1_root> <bundle_dir>",
    call. = FALSE
  )
}

script_arg <- commandArgs(trailingOnly = FALSE)
script_arg <- script_arg[startsWith(script_arg, "--file=")]
script_path <- normalizePath(
  sub("--file=", "", script_arg[[1L]], fixed = TRUE),
  winslash = "/",
  mustWork = TRUE
)
core_root <- normalizePath(
  file.path(dirname(script_path), "..", ".."),
  winslash = "/",
  mustWork = TRUE
)
orchidee1_root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
bundle_dir <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(tibble)
  library(lubridate)
})
if (file.exists(file.path(core_root, "DESCRIPTION")) &&
    requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(core_root, quiet = TRUE)
} else {
  library(orchideecore)
}

source(file.path(orchidee1_root, "R", "ratb_indicator_helpers.R"))

comparison_key <- function(df, columns) {
  do.call(
    paste,
    c(
      lapply(df[columns], function(x) ifelse(is.na(x), "<NA>", as.character(x))),
      sep = "\r"
    )
  )
}

canonicalize_reference_class_map <- function(class_map, raw_reference) {
  match_columns <- setdiff(
    intersect(names(class_map), names(raw_reference)),
    "phenotype_class"
  )
  reference_key <- comparison_key(class_map, match_columns)
  raw_key <- comparison_key(raw_reference, match_columns)
  if (anyDuplicated(reference_key) || anyDuplicated(raw_key)) {
    stop("Reference class-map reconstruction key is not unique.", call. = FALSE)
  }
  matched <- match(reference_key, raw_key)
  if (any(is.na(matched))) {
    stop("Reference class-map rows cannot be mapped to canonical rows.", call. = FALSE)
  }
  class_map$canonical_row_id <-
    orchideecore:::.make_canonical_row_id(raw_reference)[matched]
  class_map
}

class_partition_by_row <- function(class_map, group_columns) {
  group_key <- comparison_key(
    class_map,
    c(group_columns, "phenotype_class")
  )
  members <- split(class_map$canonical_row_id, group_key, drop = TRUE)
  signatures <- vapply(
    members,
    function(ids) paste(sort(ids), collapse = "\n"),
    character(1)
  )
  out <- data.frame(
    canonical_row_id = class_map$canonical_row_id,
    class_signature = unname(signatures[group_key]),
    stringsAsFactors = FALSE
  )
  out <- out[order(out$canonical_row_id), , drop = FALSE]
  row.names(out) <- NULL
  out
}

compare_panel <- function(reference, current, columns, sort_columns) {
  lhs <- reference[reference$dataset == "sir_wide_raw", columns, drop = FALSE]
  rhs <- current[columns]
  lhs <- lhs[do.call(order, c(lhs[sort_columns], list(na.last = TRUE))), ]
  rhs <- rhs[do.call(order, c(rhs[sort_columns], list(na.last = TRUE))), ]
  row.names(lhs) <- NULL
  row.names(rhs) <- NULL
  isTRUE(all.equal(lhs, rhs, tolerance = 0, check.attributes = FALSE))
}

build_reference_isolate_results <- function(
    dedup_results,
    spec,
    atb_cols,
    supported_atb_cols,
    taxonomy
  ) {
  parts <- list()
  part_index <- 0L
  for (indicator_index in seq_len(nrow(spec))) {
    spec_row <- spec[indicator_index, , drop = FALSE]
    scopes <- resolve_ratb_scope_names(spec_row$sample_type_mode[[1L]])
    if (isTRUE(spec_row$publish_incidence[[1L]])) {
      scopes <- unique(c(scopes, "global"))
    }
    for (scope in scopes) {
      representatives <- dedup_results$sir_wide_raw[[scope]]$dedup
      representatives <- apply_ratb_organism_filter(
        representatives, spec_row, taxonomy
      )
      sample_type <- if (scope == "global") {
        rep("all_types", nrow(representatives))
      } else {
        as.character(representatives$naturepvt_norm)
      }
      requested_types <- spec_row$sample_type_values_list[[1L]]
      if (scope == "by_type" && length(requested_types) > 0L) {
        keep <- !is.na(sample_type) & sample_type %in% requested_types
        representatives <- representatives[keep, , drop = FALSE]
        sample_type <- sample_type[keep]
      }
      if (nrow(representatives) == 0L) next
      result <- compute_ratb_indicator_result(
        representatives, spec_row, atb_cols, supported_atb_cols
      )
      part_index <- part_index + 1L
      parts[[part_index]] <- data.frame(
        canonical_row_id = orchideecore:::.make_canonical_row_id(
          representatives
        ),
        scope = scope,
        sample_type = sample_type,
        indicator_id = spec_row$indicator_id[[1L]],
        indicator_result = result$indicator_result,
        n_tested_cells = result$n_tested_cells,
        n_resistant_cells = result$n_resistant_cells,
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, parts)
  row.names(out) <- NULL
  out
}

compare_isolate_results <- function(reference, current) {
  columns <- c(
    "canonical_row_id", "scope", "sample_type", "indicator_id",
    "indicator_result", "n_tested_cells", "n_resistant_cells"
  )
  sort_columns <- c(
    "indicator_id", "scope", "sample_type", "canonical_row_id"
  )
  lhs <- reference[columns]
  rhs <- current[columns]
  lhs <- lhs[do.call(order, c(lhs[sort_columns], list(na.last = TRUE))), ]
  rhs <- rhs[do.call(order, c(rhs[sort_columns], list(na.last = TRUE))), ]
  row.names(lhs) <- NULL
  row.names(rhs) <- NULL
  isTRUE(all.equal(lhs, rhs, tolerance = 0, check.attributes = FALSE))
}

bundle <- read_orchidee_bundle(bundle_dir)
current_timing <- system.time(current <- run_ratb_catalogue(bundle))
reference_dedup <- readRDS(file.path(orchidee1_root, "data", "dedup_results"))
reference_raw <- readRDS(file.path(orchidee1_root, "data", "completion_datasets"))[[
  "sir_wide_raw"
]]
reference_dedup <- list(sir_wide_raw = reference_dedup[["sir_wide_raw"]])

spec <- load_ratb_indicator_spec(file.path(
  orchidee1_root, "documentation", "ratb_indicator_spec.csv"
))
spec_proportion <- spec[
  spec$enabled & spec$wave == 1L & spec$analysis_period == "annual" &
    spec$publish_proportion,
  , drop = FALSE
]
spec_incidence <- spec[
  spec$enabled & spec$wave == 1L & spec$analysis_period == "annual" &
    spec$publish_incidence,
  , drop = FALSE
]
taxonomy <- build_species_taxonomy_map(file.path(
  orchidee1_root, "dictionaries", "species_regex_map.csv"
))
atb_cols <- intersect(
  bundle$sir_wide_meta$atb_cols,
  names(reference_dedup$sir_wide_raw$global$dedup)
)
supported_atb_cols <- intersect(
  bundle$sir_wide_meta$supported_atb_cols,
  names(reference_dedup$sir_wide_raw$global$dedup)
)
reference_proportion <- build_ratb_indicator_panel_annual(
  reference_dedup, spec_proportion, atb_cols, supported_atb_cols, taxonomy
)
reference_incidence <- build_ratb_indicator_panel_incidence_annual(
  reference_dedup,
  spec_incidence,
  atb_cols,
  supported_atb_cols,
  taxonomy,
  bundle$denominator_bundle$incidence_denominator_by_year
)
reference_isolate_results <- build_reference_isolate_results(
  reference_dedup, spec, atb_cols, supported_atb_cols, taxonomy
)

representatives_equal <- vapply(
  c("global", "by_type"),
  function(scope) {
    lhs <- sort(orchideecore:::.make_canonical_row_id(
      reference_dedup$sir_wide_raw[[scope]]$dedup
    ))
    rhs <- sort(current$dedup[[scope]]$representatives$canonical_row_id)
    identical(lhs, rhs)
  },
  logical(1)
)

reference_raw$dedup_year <-
  orchideecore:::.calendar_year(reference_raw$DATEPRELEV)
class_partitions_equal <- vapply(
  c("global", "by_type"),
  function(scope) {
    group_columns <- if (scope == "global") {
      c("PATID", "dedup_year", "bact_norm")
    } else {
      c("PATID", "dedup_year", "naturepvt_norm", "bact_norm")
    }
    lhs <- canonicalize_reference_class_map(
      reference_dedup$sir_wide_raw[[scope]]$class_map,
      reference_raw
    )
    rhs <- current$dedup[[scope]]$class_map
    identical(
      class_partition_by_row(lhs, group_columns),
      class_partition_by_row(rhs, group_columns)
    )
  },
  logical(1)
)

proportion_columns <- c(
  "dataset", "scope", "sample_type", "indicator_id", "dedup_year",
  "n_isolates", "n_r", "n_s", "n_o", "n_tested", "n_resistant",
  "pct_resistant"
)
incidence_columns <- c(
  "dataset", "scope", "sample_type", "indicator_id", "dedup_year",
  "n_isolates", "n_r", "n_s", "n_o", "n_tested", "n_resistant",
  "hospital_nights", "incidence_density_per_1000"
)
panel_sort <- c("indicator_id", "scope", "sample_type", "dedup_year")
proportion_equal <- compare_panel(
  reference_proportion,
  current$proportion_annual,
  proportion_columns,
  panel_sort
)
incidence_equal <- compare_panel(
  reference_incidence,
  current$incidence_annual,
  incidence_columns,
  panel_sort
)
isolate_results_equal <- compare_isolate_results(
  reference_isolate_results, current$isolate_results
)

cat("Indicators: ", current$manifest$n_indicators, "\n", sep = "")
cat("New-core elapsed seconds: ", current_timing[["elapsed"]], "\n", sep = "")
cat("Global representatives equal: ", representatives_equal[["global"]], "\n", sep = "")
cat("By-type representatives equal: ", representatives_equal[["by_type"]], "\n", sep = "")
cat("Global class partitions equal: ", class_partitions_equal[["global"]], "\n", sep = "")
cat("By-type class partitions equal: ", class_partitions_equal[["by_type"]], "\n", sep = "")
cat("All isolate-level indicator results equal: ", isolate_results_equal, "\n", sep = "")
cat("Complete annual proportion panel equal: ", proportion_equal, "\n", sep = "")
cat("Complete annual incidence panel equal: ", incidence_equal, "\n", sep = "")

if (!all(representatives_equal) || !all(class_partitions_equal) ||
    !isolate_results_equal || !proportion_equal || !incidence_equal) {
  quit(status = 1L)
}
