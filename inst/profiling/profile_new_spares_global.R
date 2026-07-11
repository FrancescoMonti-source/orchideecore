#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
  stop(
    "Usage: Rscript profile_new_spares_global.R <bundle_dir>",
    call. = FALSE
  )
}

bundle_dir <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
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
pkgload::load_all(core_root, quiet = TRUE)

bundle <- read_orchidee_bundle(bundle_dir)
spec <- orchideecore:::.read_ratb_indicator_catalogue()
taxonomy <- orchideecore:::.read_species_taxonomy()
orchideecore:::.validate_catalogue_bundle(bundle, spec)
sir <- bundle$sir_wide
sir$canonical_row_id <- orchideecore:::.make_canonical_row_id(sir)
scope <- orchideecore:::.apply_ratb_scope(sir, bundle$sample_scope_reference)
plausibility <- orchideecore:::.apply_catalogue_plausibility_qc(
  scope$data, taxonomy
)
atb_cols <- orchideecore:::.resolve_atb_cols(bundle)

profile_path <- tempfile(pattern = "orchideecore_spares_", fileext = ".out")
Rprof(
  profile_path,
  interval = 0.01,
  memory.profiling = TRUE,
  line.profiling = TRUE
)
timing <- system.time({
  result <- orchideecore:::.deduplicate_raw_patient_year(
    plausibility$data,
    atb_cols,
    c("PATID", "dedup_year", "bact_norm")
  )
})
Rprof(NULL)

summary <- summaryRprof(profile_path, memory = "both", lines = "both")
cat(sprintf(
  "elapsed_seconds=%.2f representatives=%d\n",
  timing[["elapsed"]], nrow(result$representatives)
))
cat("\nTop functions by self time:\n")
print(utils::head(summary$by.self, 20L))
cat("\nTop functions by total time:\n")
print(utils::head(summary$by.total, 20L))
