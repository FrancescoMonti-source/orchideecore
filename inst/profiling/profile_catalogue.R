#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3L || !(args[[1L]] %in% c("new", "v1"))) {
  stop(
    paste(
      "Usage: Rscript profile_catalogue.R <new|v1>",
      "<orchidee1_root> <bundle_dir>"
    ),
    call. = FALSE
  )
}

mode <- args[[1L]]
orchidee1_root <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
bundle_dir <- normalizePath(args[[3L]], winslash = "/", mustWork = TRUE)
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

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("The profiling harness requires pkgload.", call. = FALSE)
}
pkgload::load_all(core_root, quiet = TRUE)

measurements <- list()
measure <- function(stage, expression) {
  gc(reset = TRUE)
  timing <- system.time(value <- force(expression))
  memory <- gc()
  peak_mb <- sum(memory[, ncol(memory)])
  measurements[[length(measurements) + 1L]] <<- data.frame(
    implementation = mode,
    stage = stage,
    elapsed_seconds = unname(timing[["elapsed"]]),
    user_seconds = unname(timing[["user.self"]]),
    system_seconds = unname(timing[["sys.self"]]),
    peak_mb = peak_mb,
    stringsAsFactors = FALSE
  )
  cat(sprintf(
    "PROFILE_STAGE implementation=%s stage=%s elapsed=%.2f peak_mb=%.1f\n",
    mode, stage, timing[["elapsed"]], peak_mb
  ))
  flush.console()
  value
}

bundle <- measure("read_bundle", read_orchidee_bundle(bundle_dir))

if (mode == "new") {
  spec <- orchideecore:::.read_ratb_indicator_catalogue()
  spec <- spec[
    spec$enabled & spec$wave == 1L & spec$analysis_period == "annual",
    , drop = FALSE
  ]
  taxonomy <- orchideecore:::.read_species_taxonomy()
  prepared <- measure("scope_and_plausibility_qc", {
    orchideecore:::.validate_catalogue_bundle(bundle, spec)
    sir <- bundle$sir_wide
    sir$canonical_row_id <- orchideecore:::.make_canonical_row_id(sir)
    scope <- orchideecore:::.apply_ratb_scope(
      sir, bundle$sample_scope_reference
    )
    plausibility <- orchideecore:::.apply_catalogue_plausibility_qc(
      scope$data, taxonomy
    )
    list(scope = scope, plausibility = plausibility)
  })
  atb_cols <- orchideecore:::.resolve_atb_cols(bundle)
  global <- measure("spares_global", {
    orchideecore:::.deduplicate_raw_patient_year(
      prepared$plausibility$data,
      atb_cols,
      c("PATID", "dedup_year", "bact_norm")
    )
  })
  by_type <- measure("spares_by_type", {
    orchideecore:::.deduplicate_raw_patient_year(
      prepared$plausibility$data,
      atb_cols,
      c("PATID", "dedup_year", "naturepvt_norm", "bact_norm")
    )
  })
  dedup <- list(global = global, by_type = by_type)
  isolate_results <- measure("isolate_results_140", {
    orchideecore:::.build_catalogue_isolate_results(
      dedup,
      spec,
      taxonomy,
      bundle$sir_wide_meta$supported_atb_cols
    )
  })
  proportion <- measure("proportion_panel_136", {
    orchideecore:::.summarize_catalogue_proportion(isolate_results, spec)
  })
  incidence <- measure("incidence_panel_135", {
    orchideecore:::.summarize_catalogue_incidence(
      isolate_results,
      spec,
      bundle$denominator_bundle$incidence_denominator_by_year
    )
  })
  counts <- data.frame(
    global_representatives = nrow(global$representatives),
    by_type_representatives = nrow(by_type$representatives),
    isolate_results = nrow(isolate_results),
    proportion_rows = nrow(proportion),
    incidence_rows = nrow(incidence)
  )
} else {
  suppressPackageStartupMessages({
    library(dplyr)
    library(purrr)
    library(tibble)
    library(lubridate)
  })
  old_wd <- getwd()
  setwd(orchidee1_root)
  source(file.path("R", "spares_dedup.R"))
  source(file.path("R", "ratb_indicator_helpers.R"))
  setwd(old_wd)

  raw <- measure("read_raw_reference", {
    readRDS(file.path(orchidee1_root, "data", "completion_datasets"))[[
      "sir_wide_raw"
    ]]
  })
  raw <- measure("prepare_dedup_year", {
    raw$dedup_year <- lubridate::year(as.Date(raw$DATEPRELEV))
    raw
  })
  atb_cols <- intersect(bundle$sir_wide_meta$atb_cols, names(raw))
  global <- measure("spares_global", {
    spares_dedup(
      raw,
      atb_cols,
      c("PATID", "dedup_year", "bact_norm"),
      time_col = "HEUREPRELEV",
      date_col = "DATEPRELEV",
      document_id_col = "ELTID",
      completeness_col = "nb_resultats",
      zit_values = "ZIT",
      keep_class_members = TRUE,
      keep_audit = TRUE
    )
  })
  by_type <- measure("spares_by_type", {
    spares_dedup(
      raw,
      atb_cols,
      c("PATID", "dedup_year", "naturepvt_norm", "bact_norm"),
      time_col = "HEUREPRELEV",
      date_col = "DATEPRELEV",
      document_id_col = "ELTID",
      completeness_col = "nb_resultats",
      zit_values = "ZIT",
      keep_class_members = TRUE,
      keep_audit = TRUE
    )
  })
  dedup_results <- list(
    sir_wide_raw = list(global = global, by_type = by_type)
  )
  spec <- load_ratb_indicator_spec(file.path(
    orchidee1_root, "documentation", "ratb_indicator_spec.csv"
  ))
  taxonomy <- build_species_taxonomy_map(file.path(
    orchidee1_root, "dictionaries", "species_regex_map.csv"
  ))
  supported_atb_cols <- intersect(
    bundle$sir_wide_meta$supported_atb_cols, names(global$dedup)
  )
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
  proportion <- measure("proportion_panel_136", {
    build_ratb_indicator_panel_annual(
      dedup_results,
      spec_proportion,
      atb_cols,
      supported_atb_cols,
      taxonomy
    )
  })
  incidence <- measure("incidence_panel_135", {
    build_ratb_indicator_panel_incidence_annual(
      dedup_results,
      spec_incidence,
      atb_cols,
      supported_atb_cols,
      taxonomy,
      bundle$denominator_bundle$incidence_denominator_by_year
    )
  })
  counts <- data.frame(
    global_representatives = nrow(global$dedup),
    by_type_representatives = nrow(by_type$dedup),
    isolate_results = NA_integer_,
    proportion_rows = nrow(proportion),
    incidence_rows = nrow(incidence)
  )
}

profile <- do.call(rbind, measurements)
profile <- rbind(
  profile,
  data.frame(
    implementation = mode,
    stage = "TOTAL_MEASURED_STAGES",
    elapsed_seconds = sum(profile$elapsed_seconds),
    user_seconds = sum(profile$user_seconds),
    system_seconds = sum(profile$system_seconds),
    peak_mb = max(profile$peak_mb, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
)
print(profile, row.names = FALSE)
print(counts, row.names = FALSE)
