.catalogue_file <- function(name) {
  installed <- system.file("extdata", name, package = "orchideecore")
  if (nzchar(installed)) {
    return(installed)
  }
  development <- file.path("inst", "extdata", name)
  if (file.exists(development)) {
    return(development)
  }
  .abort("Missing packaged catalogue file: ", name)
}

.parse_catalogue_flag <- function(x, default = TRUE) {
  value <- tolower(trimws(as.character(x)))
  missing <- is.na(x) | !nzchar(value)
  out <- value %in% c("true", "t", "1", "yes", "y")
  out[missing] <- default
  out
}

.split_catalogue_values <- function(x) {
  value <- .trim_or_na(x)
  if (length(value) == 0L || is.na(value[[1L]])) {
    return(character())
  }
  out <- trimws(strsplit(value[[1L]], "|", fixed = TRUE)[[1L]])
  unique(out[nzchar(out)])
}

.read_ratb_indicator_catalogue <- function() {
  spec <- utils::read.table(
    .catalogue_file("ratb_indicator_spec.csv"),
    header = TRUE,
    sep = ";",
    quote = "\"",
    comment.char = "",
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fill = TRUE,
    encoding = "UTF-8"
  )
  required <- c(
    "indicator_id", "wave", "enabled", "display_order",
    "organism_section", "organism_label", "organism_filter_type",
    "organism_filter_values", "report_taxon_label", "indicator_label",
    "indicator_kind", "molecule_values", "phenotype_flag", "scope_mode",
    "sample_type_mode", "sample_type_values", "analysis_period",
    "publish_proportion", "publish_incidence", "numerator_kind",
    "denominator_kind", "notes"
  )
  .assert_columns(spec, required, "RATB indicator catalogue")
  spec[required] <- lapply(spec[required], function(x) {
    if (is.factor(x)) as.character(x) else x
  })
  spec[["wave"]] <- suppressWarnings(as.integer(spec[["wave"]]))
  spec[["display_order"]] <-
    suppressWarnings(as.integer(spec[["display_order"]]))
  spec[["enabled"]] <- .parse_catalogue_flag(spec[["enabled"]], FALSE)
  spec[["publish_proportion"]] <-
    .parse_catalogue_flag(spec[["publish_proportion"]], TRUE)
  spec[["publish_incidence"]] <-
    .parse_catalogue_flag(spec[["publish_incidence"]], TRUE)
  char_cols <- setdiff(
    required,
    c(
      "wave", "enabled", "display_order", "publish_proportion",
      "publish_incidence"
    )
  )
  spec[char_cols] <- lapply(spec[char_cols], .trim_or_na)
  spec <- spec[order(spec[["display_order"]], spec[["indicator_id"]]), ]
  row.names(spec) <- NULL
  spec
}

#' Return the packaged RATB indicator catalogue
#'
#' The catalogue is data, not executable R. Indicator behavior is limited to
#' the four explicit kinds implemented by `run_ratb_catalogue()`.
#'
#' @return A data frame with one row per published indicator definition.
#' @export
ratb_indicator_catalogue <- function() {
  .read_ratb_indicator_catalogue()
}

.read_species_taxonomy <- function() {
  taxonomy <- utils::read.csv(
    .catalogue_file("species_taxonomy.csv"),
    stringsAsFactors = FALSE
  )
  .assert_columns(taxonomy, c("bact_norm", "bact_order"), "taxonomy")
  if (anyDuplicated(taxonomy[["bact_norm"]])) {
    .abort("Packaged species taxonomy contains duplicate bact_norm values.")
  }
  taxonomy
}

.catalogue_supported_molecules <- function(spec) {
  unique(unlist(lapply(spec[["molecule_values"]], .split_catalogue_values)))
}

.validate_catalogue_bundle <- function(bundle, spec) {
  .validate_slice_bundle(bundle)
  sir <- bundle[["sir_wide"]]
  supported <- as.character(
    bundle[["sir_wide_meta"]][["supported_atb_cols"]]
  )
  requested <- .catalogue_supported_molecules(spec)
  missing_supported <- setdiff(requested, supported)
  missing_columns <- setdiff(requested, names(sir))
  if (length(missing_supported) > 0L || length(missing_columns) > 0L) {
    .abort(
      "The canonical bundle cannot execute the packaged RATB catalogue. ",
      "Unsupported molecules: ",
      paste(missing_supported, collapse = ", "),
      "; missing columns: ", paste(missing_columns, collapse = ", ")
    )
  }
  phenotype_cols <- c("blse_flag", "carbapenemase_flag")
  .assert_columns(sir, phenotype_cols, "sir_wide")
  for (column in phenotype_cols) {
    if (!is.logical(sir[[column]]) || any(is.na(sir[[column]]))) {
      .abort(column, " must be logical without NA for catalogue execution.")
    }
  }
  allowed_kinds <- c(
    "class_any_r", "molecule_direct", "molecule_priority",
    "phenotype_flag"
  )
  allowed_sample_modes <- c(
    "global_only", "by_type_only", "global_and_by_type"
  )
  invalid <-
    is.na(spec[["indicator_id"]]) |
      duplicated(spec[["indicator_id"]]) |
      !(spec[["indicator_kind"]] %in% allowed_kinds) |
      !(spec[["sample_type_mode"]] %in% allowed_sample_modes) |
      spec[["scope_mode"]] != "patient_year_dedup" |
      spec[["analysis_period"]] != "annual"
  if (any(invalid)) {
    .abort(
      "The packaged RATB catalogue contains invalid rows: ",
      paste(spec[["indicator_id"]][invalid], collapse = ", ")
    )
  }
  invisible(bundle)
}

.taxonomy_order <- function(bact_norm, taxonomy) {
  taxonomy[["bact_order"]][match(bact_norm, taxonomy[["bact_norm"]])]
}

.apply_catalogue_plausibility_qc <- function(df, taxonomy) {
  value <- function(column) {
    if (column %in% names(df)) as.character(df[[column]]) else
      rep(NA_character_, nrow(df))
  }
  any_r <- function(columns) {
    columns <- intersect(columns, names(df))
    if (length(columns) == 0L) return(rep(FALSE, nrow(df)))
    rowSums(df[columns] == "R", na.rm = TRUE) > 0L
  }
  bact_order <- .taxonomy_order(as.character(df[["bact_norm"]]), taxonomy)
  saureus <-
    df[["bact_norm"]] == "staphylococcus_aureus" &
      !is.na(value("oxacilline")) & !is.na(value("cefoxitine")) &
      value("oxacilline") != value("cefoxitine")
  enterobacterales_c3g <-
    bact_order == "Enterobacterales" &
      value("amoxicilline_ampicilline") == "S" &
      any_r(c("cefotaxime", "ceftazidime", "ceftriaxone"))
  enterobacterales_fq <-
    bact_order == "Enterobacterales" &
      value("acide_nalidixique") == "S" &
      any_r(c(
        "ofloxacine", "levofloxacine", "moxifloxacine",
        "ciprofloxacine"
      ))
  intrinsic <-
    df[["bact_norm"]] %in%
      c("klebsiella_pneumoniae", "enterobacter_cloacae_complex") &
      value("amoxicilline_ampicilline") == "S"
  flags <- data.frame(
    qc_saureus_oxa_cefox_discordance = saureus,
    qc_enterobacterales_amoxampi_s_c3g_r = enterobacterales_c3g,
    qc_enterobacterales_nalidixic_s_fq_r = enterobacterales_fq,
    qc_klebsiella_enterobacter_amoxampi_s = intrinsic,
    stringsAsFactors = FALSE
  )
  flags[] <- lapply(flags, function(x) {
    x[is.na(x)] <- FALSE
    x
  })
  excluded <- rowSums(flags) > 0L
  audit <- data.frame(
    canonical_row_id = df[["canonical_row_id"]],
    flags,
    excluded_by_plausibility_qc = excluded,
    stringsAsFactors = FALSE
  )
  list(
    data = df[!excluded, , drop = FALSE],
    excluded = df[excluded, , drop = FALSE],
    audit = audit,
    unavailable_rules = if ("acide_nalidixique" %in% names(df)) {
      data.frame(rule_id = character(), reason = character())
    } else {
      data.frame(
        rule_id = "qc_enterobacterales_nalidixic_s_fq_r",
        reason = paste(
          "acide_nalidixique is not present in the canonical bundle contract"
        ),
        stringsAsFactors = FALSE
      )
    }
  )
}

.catalogue_scope_names <- function(sample_type_mode, publish_incidence) {
  scopes <- switch(
    sample_type_mode,
    global_only = "global",
    by_type_only = "by_type",
    global_and_by_type = c("global", "by_type")
  )
  if (isTRUE(publish_incidence)) unique(c(scopes, "global")) else scopes
}

.filter_catalogue_organism <- function(df, spec_row, taxonomy) {
  filter_type <- spec_row[["organism_filter_type"]][[1L]]
  values <- .split_catalogue_values(
    spec_row[["organism_filter_values"]][[1L]]
  )
  bact_norm <- as.character(df[["bact_norm"]])
  bact_order <- .taxonomy_order(bact_norm, taxonomy)
  included <- switch(
    filter_type,
    bact_norm = bact_norm %in% values,
    bact_order = bact_order %in% values,
    enterobacterales_other =
      bact_order == "Enterobacterales" & !(bact_norm %in% values),
    .abort("Unsupported organism_filter_type: ", filter_type)
  )
  included[is.na(included)] <- FALSE
  df[included, , drop = FALSE]
}

.compute_catalogue_indicator <- function(df, spec_row, supported_atb_cols) {
  kind <- spec_row[["indicator_kind"]][[1L]]
  if (kind == "phenotype_flag") {
    column <- spec_row[["phenotype_flag"]][[1L]]
    .assert_columns(df, column, "deduplicated representatives")
    positive <- as.logical(df[[column]])
    result <- ifelse(positive, "R", "S")
    return(list(
      result = result,
      n_tested_cells = rep.int(1L, nrow(df)),
      n_resistant_cells = as.integer(positive)
    ))
  }
  molecules <- .split_catalogue_values(
    spec_row[["molecule_values"]][[1L]]
  )
  columns <- intersect(molecules, intersect(supported_atb_cols, names(df)))
  if (length(columns) == 0L) {
    .abort(
      "No supported molecule columns for indicator ",
      spec_row[["indicator_id"]][[1L]], "."
    )
  }
  values <- as.matrix(data.frame(
    lapply(df[columns], as.character),
    check.names = FALSE,
    stringsAsFactors = FALSE
  ))
  if (kind == "molecule_priority") {
    chosen <- rep(NA_character_, nrow(df))
    for (column in seq_len(ncol(values))) {
      use <- is.na(chosen) & values[, column] %in% c("S", "R")
      chosen[use] <- values[use, column]
    }
    tested <- !is.na(chosen)
    return(list(
      result = ifelse(tested, chosen, "O"),
      n_tested_cells = as.integer(tested),
      n_resistant_cells = as.integer(tested & chosen == "R")
    ))
  }
  n_tested <- rowSums(values == "S" | values == "R", na.rm = TRUE)
  n_resistant <- rowSums(values == "R", na.rm = TRUE)
  list(
    result = ifelse(n_resistant > 0L, "R", ifelse(n_tested > 0L, "S", "O")),
    n_tested_cells = n_tested,
    n_resistant_cells = n_resistant
  )
}

.empty_catalogue_isolate_results <- function() {
  data.frame(
    canonical_row_id = character(),
    PATID = character(),
    dedup_year = integer(),
    phenotype_class = integer(),
    scope = character(),
    sample_type = character(),
    indicator_id = character(),
    indicator_result = character(),
    n_tested_cells = numeric(),
    n_resistant_cells = numeric(),
    stringsAsFactors = FALSE
  )
}

.empty_catalogue_proportion <- function() {
  data.frame(
    indicator_id = character(),
    dataset = character(),
    organism_section = character(),
    organism_label = character(),
    report_taxon_label = character(),
    indicator_label = character(),
    indicator_kind = character(),
    numerator_kind = character(),
    denominator_kind = character(),
    display_order = integer(),
    scope = character(),
    sample_type = character(),
    dedup_year = integer(),
    n_isolates = integer(),
    n_r = integer(),
    n_s = integer(),
    n_o = integer(),
    n_tested = integer(),
    n_resistant = integer(),
    pct_resistant = numeric(),
    stringsAsFactors = FALSE
  )
}

.build_catalogue_isolate_results <- function(
    dedup,
    spec,
    taxonomy,
    supported_atb_cols
  ) {
  parts <- list()
  part_index <- 0L
  for (indicator_index in seq_len(nrow(spec))) {
    spec_row <- spec[indicator_index, , drop = FALSE]
    scopes <- .catalogue_scope_names(
      spec_row[["sample_type_mode"]][[1L]],
      spec_row[["publish_incidence"]][[1L]]
    )
    for (scope in scopes) {
      representatives <- dedup[[scope]][["representatives"]]
      representatives <- .filter_catalogue_organism(
        representatives, spec_row, taxonomy
      )
      sample_type <- if (scope == "global") {
        rep("all_types", nrow(representatives))
      } else {
        as.character(representatives[["naturepvt_norm"]])
      }
      requested_types <- .split_catalogue_values(
        spec_row[["sample_type_values"]][[1L]]
      )
      if (scope == "by_type" && length(requested_types) > 0L) {
        keep <- !is.na(sample_type) & sample_type %in% requested_types
        representatives <- representatives[keep, , drop = FALSE]
        sample_type <- sample_type[keep]
      }
      if (nrow(representatives) == 0L) next
      result <- .compute_catalogue_indicator(
        representatives, spec_row, supported_atb_cols
      )
      part_index <- part_index + 1L
      parts[[part_index]] <- data.frame(
        canonical_row_id = representatives[["canonical_row_id"]],
        PATID = as.character(representatives[["PATID"]]),
        dedup_year = as.integer(representatives[["dedup_year"]]),
        phenotype_class = as.integer(representatives[["phenotype_class"]]),
        scope = scope,
        sample_type = sample_type,
        indicator_id = spec_row[["indicator_id"]][[1L]],
        indicator_result = result$result,
        n_tested_cells = result$n_tested_cells,
        n_resistant_cells = result$n_resistant_cells,
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(parts) == 0L) {
    return(.empty_catalogue_isolate_results())
  }
  .bind_rows_base(parts)
}

.catalogue_panel_metadata <- function(spec_row) {
  data.frame(
    dataset = "sir_wide_raw",
    organism_section = spec_row[["organism_section"]][[1L]],
    organism_label = spec_row[["organism_label"]][[1L]],
    report_taxon_label = spec_row[["report_taxon_label"]][[1L]],
    indicator_label = spec_row[["indicator_label"]][[1L]],
    indicator_kind = spec_row[["indicator_kind"]][[1L]],
    numerator_kind = spec_row[["numerator_kind"]][[1L]],
    denominator_kind = spec_row[["denominator_kind"]][[1L]],
    display_order = spec_row[["display_order"]][[1L]],
    stringsAsFactors = FALSE
  )
}

.summarize_catalogue_proportion <- function(isolate_results, spec) {
  if (nrow(isolate_results) == 0L) {
    return(.empty_catalogue_proportion())
  }
  parts <- list()
  part_index <- 0L
  result_key <- paste(
    isolate_results[["indicator_id"]], isolate_results[["scope"]], sep = "\r"
  )
  result_index <- split(seq_len(nrow(isolate_results)), result_key, drop = TRUE)
  for (indicator_index in which(spec[["publish_proportion"]])) {
    spec_row <- spec[indicator_index, , drop = FALSE]
    indicator_id <- spec_row[["indicator_id"]][[1L]]
    scopes <- switch(
      spec_row[["sample_type_mode"]][[1L]],
      global_only = "global",
      by_type_only = "by_type",
      global_and_by_type = c("global", "by_type")
    )
    for (scope in scopes) {
      indices_for_result <- result_index[[paste(indicator_id, scope, sep = "\r")]]
      if (is.null(indices_for_result)) next
      rows <- isolate_results[indices_for_result, , drop = FALSE]
      if (nrow(rows) == 0L) next
      group_data <- rows[c("dedup_year", "sample_type")]
      groups <- split(
        seq_len(nrow(rows)),
        .make_key(group_data, c("dedup_year", "sample_type")),
        drop = TRUE
      )
      for (indices in groups) {
        result <- rows[["indicator_result"]][indices]
        n_r <- sum(result == "R", na.rm = TRUE)
        n_s <- sum(result == "S", na.rm = TRUE)
        n_o <- sum(result == "O", na.rm = TRUE)
        n_tested <- n_r + n_s
        part_index <- part_index + 1L
        metadata <- .catalogue_panel_metadata(spec_row)
        parts[[part_index]] <- data.frame(
          indicator_id = indicator_id,
          metadata,
          scope = scope,
          sample_type = rows[["sample_type"]][indices[[1L]]],
          dedup_year = rows[["dedup_year"]][indices[[1L]]],
          n_isolates = length(indices),
          n_r = n_r,
          n_s = n_s,
          n_o = n_o,
          n_tested = n_tested,
          n_resistant = n_r,
          pct_resistant = if (n_tested > 0L) {
            100 * n_r / n_tested
          } else {
            NA_real_
          },
          stringsAsFactors = FALSE
        )
      }
    }
  }
  out <- .bind_rows_base(parts)
  if (nrow(out) == 0L) return(out)
  out <- out[order(
    out[["display_order"]], out[["report_taxon_label"]],
    out[["indicator_label"]], out[["dataset"]], out[["scope"]],
    out[["sample_type"]], out[["dedup_year"]], na.last = TRUE
  ), ]
  row.names(out) <- NULL
  out
}

.summarize_catalogue_incidence <- function(
    isolate_results,
    spec,
    denominator
  ) {
  denominator <- data.frame(
    dedup_year = as.integer(denominator[["calendar_year"]]),
    hospital_nights = as.numeric(denominator[["hospital_nights"]]),
    stringsAsFactors = FALSE
  )
  parts <- vector("list", sum(spec[["publish_incidence"]]))
  part_index <- 0L
  global_rows <- isolate_results[["scope"]] == "global"
  result_index <- split(
    which(global_rows),
    isolate_results[["indicator_id"]][global_rows],
    drop = TRUE
  )
  for (indicator_index in which(spec[["publish_incidence"]])) {
    spec_row <- spec[indicator_index, , drop = FALSE]
    indicator_id <- spec_row[["indicator_id"]][[1L]]
    indices_for_result <- result_index[[indicator_id]]
    rows <- if (is.null(indices_for_result)) {
      isolate_results[FALSE, , drop = FALSE]
    } else {
      isolate_results[indices_for_result, , drop = FALSE]
    }
    counts <- data.frame(
      dedup_year = integer(), n_isolates = integer(), n_r = integer(),
      n_s = integer(), n_o = integer(), n_tested = integer(),
      n_resistant = integer()
    )
    if (nrow(rows) > 0L) {
      groups <- split(seq_len(nrow(rows)), rows[["dedup_year"]], drop = TRUE)
      counts <- .bind_rows_base(lapply(groups, function(indices) {
        result <- rows[["indicator_result"]][indices]
        n_r <- sum(result == "R", na.rm = TRUE)
        n_s <- sum(result == "S", na.rm = TRUE)
        n_o <- sum(result == "O", na.rm = TRUE)
        data.frame(
          dedup_year = rows[["dedup_year"]][indices[[1L]]],
          n_isolates = length(indices), n_r = n_r, n_s = n_s, n_o = n_o,
          n_tested = n_r + n_s, n_resistant = n_r
        )
      }))
    }
    yearly <- merge(
      denominator, counts, by = "dedup_year", all.x = TRUE, sort = TRUE
    )
    count_cols <- c(
      "n_isolates", "n_r", "n_s", "n_o", "n_tested", "n_resistant"
    )
    yearly[count_cols] <- lapply(yearly[count_cols], function(x) {
      as.integer(ifelse(is.na(x), 0L, x))
    })
    metadata <- .catalogue_panel_metadata(spec_row)
    metadata[["denominator_kind"]] <- "hospital_days"
    part_index <- part_index + 1L
    parts[[part_index]] <- data.frame(
      indicator_id = indicator_id,
      metadata,
      scope = "global",
      sample_type = "all_types",
      yearly,
      incidence_density_per_1000 = ifelse(
        yearly[["hospital_nights"]] > 0,
        1000 * yearly[["n_resistant"]] / yearly[["hospital_nights"]],
        NA_real_
      ),
      metric_name = "incidence_density_per_1000",
      stringsAsFactors = FALSE
    )
  }
  out <- .bind_rows_base(parts)
  out <- out[order(
    out[["display_order"]], out[["report_taxon_label"]],
    out[["indicator_label"]], out[["dataset"]], out[["dedup_year"]]
  ), ]
  row.names(out) <- NULL
  out
}

#' Run the complete raw RATB indicator catalogue
#'
#' Executes the packaged ORCHIDEE 1 catalogue from a validated canonical v1 or
#' v2 bundle. Completion, reporting, caching, and hospital-specific extraction
#' are deliberately excluded.
#'
#' @param bundle A list returned by `read_orchidee_bundle()` or an equivalent
#'   in-memory canonical bundle.
#' @return An object of class `orchidee_ratb_catalogue`. Its primary results
#'   are `proportion_annual` and `incidence_annual`; the remaining elements
#'   contain the executed catalogue, manifest, stage counts, and row-level
#'   audit evidence. The exact result contract is identified by
#'   `manifest$output_contract`.
#' @export
run_ratb_catalogue <- function(bundle) {
  spec <- .read_ratb_indicator_catalogue()
  spec <- spec[
    spec[["enabled"]] & spec[["wave"]] == 1L &
      spec[["analysis_period"]] == "annual",
    , drop = FALSE
  ]
  .validate_catalogue_bundle(bundle, spec)
  canonical_contract <- .canonical_contract_version(bundle)
  taxonomy <- .read_species_taxonomy()
  sir <- bundle[["sir_wide"]]
  sir[["canonical_row_id"]] <- .make_canonical_row_id(sir)
  scope <- .apply_ratb_scope(sir, bundle[["sample_scope_reference"]])
  plausibility <- .apply_catalogue_plausibility_qc(scope[["data"]], taxonomy)
  atb_cols <- .resolve_atb_cols(bundle)
  dedup <- list(
    global = .deduplicate_raw_patient_year(
      plausibility[["data"]], atb_cols,
      c("PATID", "dedup_year", "bact_norm")
    ),
    by_type = .deduplicate_raw_patient_year(
      plausibility[["data"]], atb_cols,
      c("PATID", "dedup_year", "naturepvt_norm", "bact_norm")
    )
  )
  supported_atb_cols <- as.character(
    bundle[["sir_wide_meta"]][["supported_atb_cols"]]
  )
  isolate_results <- .build_catalogue_isolate_results(
    dedup, spec, taxonomy, supported_atb_cols
  )
  proportion <- .summarize_catalogue_proportion(isolate_results, spec)
  incidence <- .summarize_catalogue_incidence(
    isolate_results,
    spec,
    bundle[["denominator_bundle"]][["incidence_denominator_by_year"]]
  )
  out <- list(
    manifest = list(
      method_profile = "ratb_catalogue_raw_patient_year_v1",
      canonical_contract = canonical_contract,
      output_contract = "ratb_catalogue_result_v1",
      completion_applied = FALSE,
      n_indicators = nrow(spec),
      n_proportion_indicators = sum(spec[["publish_proportion"]]),
      n_incidence_indicators = sum(spec[["publish_incidence"]]),
      dedup_scopes = c("global", "by_type")
    ),
    catalogue = spec,
    population_summary = data.frame(
      stage = c(
        "canonical_bundle", "analytic_scope", "plausibility_qc",
        "dedup_global_representatives", "dedup_by_type_representatives"
      ),
      n_rows = c(
        nrow(sir), nrow(scope[["data"]]), nrow(plausibility[["data"]]),
        nrow(dedup[["global"]][["representatives"]]),
        nrow(dedup[["by_type"]][["representatives"]])
      ),
      stringsAsFactors = FALSE
    ),
    scope_audit = scope[["audit"]],
    plausibility_audit = plausibility[["audit"]],
    plausibility_unavailable_rules = plausibility[["unavailable_rules"]],
    dedup = dedup,
    isolate_results = isolate_results,
    proportion_annual = proportion,
    incidence_annual = incidence
  )
  class(out) <- c("orchidee_ratb_catalogue", "list")
  out
}
