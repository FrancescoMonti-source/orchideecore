#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
  stop(
    "Usage: Rscript compare_reference.R <orchidee1_root> <bundle_dir>",
    call. = FALSE
  )
}

orchidee1_root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
bundle_dir <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)

suppressPackageStartupMessages(library(orchideecore))

isolate_results_equal <- function(reference_results, new_results) {
  columns <- c(
    "canonical_row_id", "indicator_result", "n_tested_cells",
    "n_resistant_cells"
  )
  lhs <- reference_results[order(reference_results$canonical_row_id), columns]
  rhs <- new_results[order(new_results$canonical_row_id), columns]
  row.names(lhs) <- NULL
  row.names(rhs) <- NULL
  identical(lhs, rhs)
}

comparison_key <- function(df, columns) {
  do.call(
    paste,
    c(
      lapply(df[columns], function(x) ifelse(is.na(x), "<NA>", as.character(x))),
      sep = "\r"
    )
  )
}

class_partition_by_row <- function(class_map) {
  group_key <- paste(
    class_map$PATID,
    class_map$dedup_year,
    class_map$bact_norm,
    class_map$phenotype_class,
    sep = "\r"
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

class_partitions_equal <- function(reference_map, new_map, target_taxon) {
  lhs <- reference_map[reference_map$bact_norm == target_taxon, , drop = FALSE]
  rhs <- new_map[new_map$bact_norm == target_taxon, , drop = FALSE]
  identical(class_partition_by_row(lhs), class_partition_by_row(rhs))
}

bundle <- read_orchidee_bundle(bundle_dir)
new_result <- run_ecoli_c3g_slice(bundle)
new_saureus_result <- run_saureus_methicillin_slice(bundle)
new_kpneumo_result <- run_kpneumo_blse_slice(bundle)
dedup_path <- file.path(orchidee1_root, "data", "dedup_results")
if (!file.exists(dedup_path)) {
  stop("Missing ORCHIDEE 1 dedup artifact: ", dedup_path, call. = FALSE)
}
reference <- readRDS(dedup_path)
if (!all(c("sir_wide_raw") %in% names(reference))) {
  stop("ORCHIDEE 1 dedup_results has no sir_wide_raw dataset.", call. = FALSE)
}
old_representatives <- reference[["sir_wide_raw"]][["global"]][["dedup"]]
old_representatives <- old_representatives[
  old_representatives[["bact_norm"]] == "escherichia_coli", , drop = FALSE
]
old_representatives[["canonical_row_id"]] <-
  orchideecore:::.make_canonical_row_id(old_representatives)

old_ids <- sort(unique(old_representatives[["canonical_row_id"]]))
new_ids <- sort(unique(new_result$representatives[["canonical_row_id"]]))
missing_from_new <- setdiff(old_ids, new_ids)
extra_in_new <- setdiff(new_ids, old_ids)

old_representatives[["dedup_year"]] <-
  orchideecore:::.calendar_year(old_representatives[["DATEPRELEV"]])
old_representatives[["phenotype_class"]] <- NA_integer_
old_isolates <- orchideecore:::.derive_ecoli_c3g(old_representatives)
old_annual <- orchideecore:::.summarize_resistance_annual(old_isolates)
new_annual <- new_result$resistance_annual
ecoli_isolates_equal <- isolate_results_equal(
  old_isolates,
  new_result$isolate_results
)

scope_cache_path <- file.path(orchidee1_root, "data", "ratb_scope_cache")
completion_path <- file.path(orchidee1_root, "data", "completion_datasets")
if (!file.exists(scope_cache_path) || !file.exists(completion_path)) {
  stop("ORCHIDEE 1 scope or raw completion artifact is missing.", call. = FALSE)
}
scope_cache <- readRDS(scope_cache_path)
completion_datasets <- readRDS(completion_path)
reference_class_map <- reference[["sir_wide_raw"]][["global"]][["class_map"]]
raw_reference <- completion_datasets[["sir_wide_raw"]]
raw_reference[["dedup_year"]] <-
  orchideecore:::.calendar_year(raw_reference[["DATEPRELEV"]])
raw_reference[["canonical_row_id"]] <-
  orchideecore:::.make_canonical_row_id(raw_reference)
class_match_columns <- setdiff(
  intersect(names(reference_class_map), names(raw_reference)),
  "phenotype_class"
)
reference_match_key <- comparison_key(reference_class_map, class_match_columns)
raw_match_key <- comparison_key(raw_reference, class_match_columns)
if (anyDuplicated(reference_match_key) || anyDuplicated(raw_match_key)) {
  stop("ORCHIDEE 1 class-map reconstruction key is not unique.", call. = FALSE)
}
reference_match <- match(reference_match_key, raw_match_key)
if (any(is.na(reference_match))) {
  stop("ORCHIDEE 1 class-map rows cannot be mapped to canonical rows.", call. = FALSE)
}
reference_class_map[["canonical_row_id"]] <-
  raw_reference[["canonical_row_id"]][reference_match]

ecoli_classes_equal <- class_partitions_equal(
  reference_class_map,
  new_result$dedup_class_map,
  "escherichia_coli"
)
saureus_classes_equal <- class_partitions_equal(
  reference_class_map,
  new_saureus_result$dedup_class_map,
  "staphylococcus_aureus"
)
kpneumo_classes_equal <- class_partitions_equal(
  reference_class_map,
  new_kpneumo_result$dedup_class_map,
  "klebsiella_pneumoniae"
)
old_scope_rows <- nrow(scope_cache[["sir_wide_ratb_analytic_scope"]])
old_raw_ecoli_rows <- sum(
  completion_datasets[["sir_wide_raw"]][["bact_norm"]] == "escherichia_coli",
  na.rm = TRUE
)
new_scope_rows <- new_result$population_summary$n_rows[
  new_result$population_summary$stage == "analytic_scope"
]
new_raw_ecoli_rows <- new_result$population_summary$n_rows[
  new_result$population_summary$stage == "plausibility_qc"
]
scope_equal <- identical(as.integer(old_scope_rows), as.integer(new_scope_rows))
raw_ecoli_equal <- identical(
  as.integer(old_raw_ecoli_rows), as.integer(new_raw_ecoli_rows)
)

old_incidence <- orchideecore:::.summarize_incidence_annual(
  old_isolates,
  scope_cache[["incidence_denominator_by_year"]]
)
new_incidence <- new_result$incidence_annual

old_saureus_representatives <- reference[["sir_wide_raw"]][["global"]][["dedup"]]
old_saureus_representatives <- old_saureus_representatives[
  old_saureus_representatives[["bact_norm"]] == "staphylococcus_aureus",
  , drop = FALSE
]
old_saureus_representatives[["canonical_row_id"]] <-
  orchideecore:::.make_canonical_row_id(old_saureus_representatives)
old_saureus_representatives[["dedup_year"]] <-
  orchideecore:::.calendar_year(old_saureus_representatives[["DATEPRELEV"]])
old_saureus_representatives[["phenotype_class"]] <- NA_integer_

old_saureus_ids <- sort(unique(
  old_saureus_representatives[["canonical_row_id"]]
))
new_saureus_ids <- sort(unique(
  new_saureus_result$representatives[["canonical_row_id"]]
))
saureus_missing_from_new <- setdiff(old_saureus_ids, new_saureus_ids)
saureus_extra_in_new <- setdiff(new_saureus_ids, old_saureus_ids)

old_saureus_isolates <- orchideecore:::.derive_saureus_methicillin(
  old_saureus_representatives
)
old_saureus_annual <- orchideecore:::.summarize_resistance_annual(
  old_saureus_isolates
)
old_saureus_incidence <- orchideecore:::.summarize_incidence_annual(
  old_saureus_isolates,
  scope_cache[["incidence_denominator_by_year"]]
)
new_saureus_annual <- new_saureus_result$resistance_annual
new_saureus_incidence <- new_saureus_result$incidence_annual
saureus_isolates_equal <- isolate_results_equal(
  old_saureus_isolates,
  new_saureus_result$isolate_results
)

old_kpneumo_representatives <- reference[["sir_wide_raw"]][["global"]][["dedup"]]
old_kpneumo_representatives <- old_kpneumo_representatives[
  old_kpneumo_representatives[["bact_norm"]] == "klebsiella_pneumoniae",
  , drop = FALSE
]
old_kpneumo_representatives[["canonical_row_id"]] <-
  orchideecore:::.make_canonical_row_id(old_kpneumo_representatives)
old_kpneumo_representatives[["dedup_year"]] <-
  orchideecore:::.calendar_year(old_kpneumo_representatives[["DATEPRELEV"]])
old_kpneumo_representatives[["phenotype_class"]] <- NA_integer_

old_kpneumo_ids <- sort(unique(
  old_kpneumo_representatives[["canonical_row_id"]]
))
new_kpneumo_ids <- sort(unique(
  new_kpneumo_result$representatives[["canonical_row_id"]]
))
kpneumo_missing_from_new <- setdiff(old_kpneumo_ids, new_kpneumo_ids)
kpneumo_extra_in_new <- setdiff(new_kpneumo_ids, old_kpneumo_ids)

old_kpneumo_isolates <- orchideecore:::.derive_kpneumo_blse(
  old_kpneumo_representatives
)
old_kpneumo_annual <- orchideecore:::.summarize_resistance_annual(
  old_kpneumo_isolates
)
old_kpneumo_annual[["indicator_id"]] <- "kpneumo_blse_prop_global"
old_kpneumo_incidence <- orchideecore:::.summarize_incidence_annual(
  old_kpneumo_isolates,
  scope_cache[["incidence_denominator_by_year"]]
)
old_kpneumo_incidence[["indicator_id"]] <- "kpneumo_blse_inc_global"
new_kpneumo_annual <- new_kpneumo_result$resistance_annual
new_kpneumo_incidence <- new_kpneumo_result$incidence_annual
kpneumo_isolates_equal <- isolate_results_equal(
  old_kpneumo_isolates,
  new_kpneumo_result$isolate_results
)

old_raw_kpneumo_rows <- sum(
  completion_datasets[["sir_wide_raw"]][["bact_norm"]] ==
    "klebsiella_pneumoniae",
  na.rm = TRUE
)
new_raw_kpneumo_rows <- new_kpneumo_result$population_summary$n_rows[
  new_kpneumo_result$population_summary$stage == "plausibility_qc"
]
raw_kpneumo_equal <- identical(
  as.integer(old_raw_kpneumo_rows), as.integer(new_raw_kpneumo_rows)
)
kpneumo_scope_equal <- identical(
  as.integer(old_scope_rows),
  as.integer(new_kpneumo_result$population_summary$n_rows[
    new_kpneumo_result$population_summary$stage == "analytic_scope"
  ])
)

old_raw_saureus_rows <- sum(
  completion_datasets[["sir_wide_raw"]][["bact_norm"]] ==
    "staphylococcus_aureus",
  na.rm = TRUE
)
new_raw_saureus_rows <- new_saureus_result$population_summary$n_rows[
  new_saureus_result$population_summary$stage == "plausibility_qc"
]
raw_saureus_equal <- identical(
  as.integer(old_raw_saureus_rows), as.integer(new_raw_saureus_rows)
)
saureus_scope_equal <- identical(
  as.integer(old_scope_rows),
  as.integer(new_saureus_result$population_summary$n_rows[
    new_saureus_result$population_summary$stage == "analytic_scope"
  ])
)

annual_equal <- identical(
  old_annual[order(old_annual$dedup_year), names(old_annual)],
  new_annual[order(new_annual$dedup_year), names(old_annual)]
)
incidence_equal <- identical(
  old_incidence[order(old_incidence$dedup_year), names(old_incidence)],
  new_incidence[order(new_incidence$dedup_year), names(old_incidence)]
)
saureus_annual_equal <- identical(
  old_saureus_annual[
    order(old_saureus_annual$dedup_year), names(old_saureus_annual)
  ],
  new_saureus_annual[
    order(new_saureus_annual$dedup_year), names(old_saureus_annual)
  ]
)
saureus_incidence_equal <- identical(
  old_saureus_incidence[
    order(old_saureus_incidence$dedup_year), names(old_saureus_incidence)
  ],
  new_saureus_incidence[
    order(new_saureus_incidence$dedup_year), names(old_saureus_incidence)
  ]
)
kpneumo_annual_equal <- identical(
  old_kpneumo_annual[
    order(old_kpneumo_annual$dedup_year), names(old_kpneumo_annual)
  ],
  new_kpneumo_annual[
    order(new_kpneumo_annual$dedup_year), names(old_kpneumo_annual)
  ]
)
kpneumo_incidence_equal <- identical(
  old_kpneumo_incidence[
    order(old_kpneumo_incidence$dedup_year), names(old_kpneumo_incidence)
  ],
  new_kpneumo_incidence[
    order(new_kpneumo_incidence$dedup_year), names(old_kpneumo_incidence)
  ]
)

cat("Analytic scope row count equal: ", scope_equal, "\n", sep = "")
cat("Post-QC E. coli row count equal: ", raw_ecoli_equal, "\n", sep = "")
cat("ORCHIDEE 1 representatives: ", length(old_ids), "\n", sep = "")
cat("New core representatives: ", length(new_ids), "\n", sep = "")
cat("Missing from new core: ", length(missing_from_new), "\n", sep = "")
cat("Extra in new core: ", length(extra_in_new), "\n", sep = "")
cat("E. coli SPARES class partitions equal: ", ecoli_classes_equal, "\n", sep = "")
cat("E. coli isolate-level C3G results equal: ", ecoli_isolates_equal, "\n", sep = "")
cat("Annual C3G panel equal: ", annual_equal, "\n", sep = "")
cat("Annual C3G incidence equal: ", incidence_equal, "\n", sep = "")
cat("S. aureus analytic scope row count equal: ", saureus_scope_equal, "\n", sep = "")
cat("Post-QC S. aureus row count equal: ", raw_saureus_equal, "\n", sep = "")
cat("ORCHIDEE 1 S. aureus representatives: ", length(old_saureus_ids), "\n", sep = "")
cat("New core S. aureus representatives: ", length(new_saureus_ids), "\n", sep = "")
cat("S. aureus missing from new core: ", length(saureus_missing_from_new), "\n", sep = "")
cat("S. aureus extra in new core: ", length(saureus_extra_in_new), "\n", sep = "")
cat("S. aureus SPARES class partitions equal: ", saureus_classes_equal, "\n", sep = "")
cat("S. aureus isolate-level methicillin results equal: ", saureus_isolates_equal, "\n", sep = "")
cat("Annual methicillin panel equal: ", saureus_annual_equal, "\n", sep = "")
cat("Annual methicillin incidence equal: ", saureus_incidence_equal, "\n", sep = "")
cat("K. pneumoniae analytic scope row count equal: ", kpneumo_scope_equal, "\n", sep = "")
cat("Post-QC K. pneumoniae row count equal: ", raw_kpneumo_equal, "\n", sep = "")
cat("ORCHIDEE 1 K. pneumoniae representatives: ", length(old_kpneumo_ids), "\n", sep = "")
cat("New core K. pneumoniae representatives: ", length(new_kpneumo_ids), "\n", sep = "")
cat("K. pneumoniae missing from new core: ", length(kpneumo_missing_from_new), "\n", sep = "")
cat("K. pneumoniae extra in new core: ", length(kpneumo_extra_in_new), "\n", sep = "")
cat("K. pneumoniae SPARES class partitions equal: ", kpneumo_classes_equal, "\n", sep = "")
cat("K. pneumoniae isolate-level BLSE results equal: ", kpneumo_isolates_equal, "\n", sep = "")
cat("Annual K. pneumoniae BLSE panel equal: ", kpneumo_annual_equal, "\n", sep = "")
cat("Annual K. pneumoniae BLSE incidence equal: ", kpneumo_incidence_equal, "\n", sep = "")

if (length(missing_from_new) > 0L) {
  cat("First missing IDs:\n")
  print(utils::head(missing_from_new, 10L))
}
if (length(extra_in_new) > 0L) {
  cat("First extra IDs:\n")
  print(utils::head(extra_in_new, 10L))
}
if (length(saureus_missing_from_new) > 0L) {
  cat("First missing S. aureus IDs:\n")
  print(utils::head(saureus_missing_from_new, 10L))
}
if (length(saureus_extra_in_new) > 0L) {
  cat("First extra S. aureus IDs:\n")
  print(utils::head(saureus_extra_in_new, 10L))
}
if (length(kpneumo_missing_from_new) > 0L) {
  cat("First missing K. pneumoniae IDs:\n")
  print(utils::head(kpneumo_missing_from_new, 10L))
}
if (length(kpneumo_extra_in_new) > 0L) {
  cat("First extra K. pneumoniae IDs:\n")
  print(utils::head(kpneumo_extra_in_new, 10L))
}

if (
  !scope_equal || !raw_ecoli_equal || length(missing_from_new) > 0L ||
    length(extra_in_new) > 0L || !ecoli_classes_equal ||
    !ecoli_isolates_equal || !annual_equal || !incidence_equal ||
    !saureus_scope_equal || !raw_saureus_equal ||
    length(saureus_missing_from_new) > 0L ||
    length(saureus_extra_in_new) > 0L || !saureus_classes_equal ||
    !saureus_isolates_equal || !saureus_annual_equal ||
    !saureus_incidence_equal || !kpneumo_scope_equal || !raw_kpneumo_equal ||
    length(kpneumo_missing_from_new) > 0L ||
    length(kpneumo_extra_in_new) > 0L || !kpneumo_classes_equal ||
    !kpneumo_isolates_equal || !kpneumo_annual_equal ||
    !kpneumo_incidence_equal
) {
  quit(status = 1L)
}
