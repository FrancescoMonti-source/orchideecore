.normalize_noninformative <- function(x, zit_values = "ZIT") {
  out <- as.character(x)
  out[out %in% zit_values] <- NA_character_
  out
}

.discord_matrix <- function(df, columns, zit_values = "ZIT") {
  n <- nrow(df)
  if (n <= 1L) {
    return(matrix(FALSE, nrow = n, ncol = n))
  }
  values <- as.data.frame(
    lapply(df[columns], .normalize_noninformative, zit_values = zit_values),
    stringsAsFactors = FALSE
  )
  r_matrix <- as.matrix((!is.na(values)) & values == "R")
  s_matrix <- as.matrix((!is.na(values)) & values == "S")
  discord <- (r_matrix %*% t(s_matrix)) + (s_matrix %*% t(r_matrix))
  diag(discord) <- 0
  discord > 0
}

.time_sort_key <- function(x) {
  x_chr <- trimws(as.character(x))
  x_chr[x_chr %in% c("", "NA", "N/A")] <- NA_character_
  out <- rep(NA_character_, length(x_chr))
  idx <- !is.na(x_chr)
  if (!any(idx)) {
    return(out)
  }
  token <- x_chr[idx]
  token <- sub(".*?(\\d{1,2}:\\d{2}(?::\\d{2})?).*", "\\1", token, perl = TRUE)
  has_token <- grepl("^\\d{1,2}:\\d{2}(?::\\d{2})?$", token)
  token[!has_token] <- x_chr[idx][!has_token]
  parsed_hms <- strptime(token, format = "%H:%M:%S", tz = "UTC")
  parsed_hm <- strptime(token, format = "%H:%M", tz = "UTC")
  normal <- rep(NA_character_, length(token))
  ok_hms <- !is.na(parsed_hms)
  normal[ok_hms] <- format(parsed_hms[ok_hms], "%H:%M:%S")
  ok_hm <- is.na(normal) & !is.na(parsed_hm)
  normal[ok_hm] <- format(parsed_hm[ok_hm], "%H:%M:%S")
  normal[is.na(normal)] <- token[is.na(normal)]
  out[idx] <- normal
  out
}

.derive_evt_order <- function(df, date_sort, time_sort, document_sort, row_sort) {
  n <- nrow(df)
  out <- rep(NA_real_, n)
  if ("evt_order" %in% names(df)) {
    out <- suppressWarnings(as.numeric(as.character(df[["evt_order"]])))
    if (!any(is.na(out))) {
      return(out)
    }
  }
  evtid <- as.character(df[["EVTID"]])
  valid <- which(!is.na(evtid) & evtid != "")
  if (length(valid) == 0L) {
    return(out)
  }
  levels <- unique(evtid[valid])
  representatives <- integer(length(levels))
  for (i in seq_along(levels)) {
    idx <- valid[evtid[valid] == levels[[i]]]
    idx <- idx[order(
      date_sort[idx], time_sort[idx], document_sort[idx], row_sort[idx],
      na.last = TRUE
    )]
    representatives[[i]] <- idx[[1L]]
  }
  level_order <- order(
    date_sort[representatives], time_sort[representatives],
    document_sort[representatives], row_sort[representatives], levels,
    na.last = TRUE
  )
  ranks <- seq_along(levels)
  names(ranks) <- levels[level_order]
  derived <- unname(ranks[evtid])
  out[is.na(out)] <- derived[is.na(out)]
  out
}

.derive_elt_order <- function(
    df, evt_order_sort, date_sort, time_sort, document_sort, row_sort
  ) {
  n <- nrow(df)
  out <- rep(NA_real_, n)
  if ("elt_order" %in% names(df)) {
    out <- suppressWarnings(as.numeric(as.character(df[["elt_order"]])))
    if (!any(is.na(out))) {
      return(out)
    }
  }
  evtid <- as.character(df[["EVTID"]])
  evtid[is.na(evtid)] <- ""
  eltid <- as.character(df[["ELTID"]])
  valid <- which(!is.na(eltid) & eltid != "")
  if (length(valid) == 0L) {
    return(out)
  }
  key <- paste(evtid[valid], eltid[valid], sep = "\r")
  levels <- unique(key)
  representatives <- integer(length(levels))
  key_evt <- key_elt <- character(length(levels))
  for (i in seq_along(levels)) {
    idx <- valid[key == levels[[i]]]
    idx <- idx[order(date_sort[idx], time_sort[idx], row_sort[idx], na.last = TRUE)]
    representatives[[i]] <- idx[[1L]]
    key_evt[[i]] <- evtid[representatives[[i]]]
    key_elt[[i]] <- eltid[representatives[[i]]]
  }
  key_table <- data.frame(
    key = levels,
    evt = key_evt,
    eltid = key_elt,
    evt_order = evt_order_sort[representatives],
    date_sort = date_sort[representatives],
    time_sort = time_sort[representatives],
    row_sort = row_sort[representatives],
    stringsAsFactors = FALSE
  )
  key_table <- key_table[order(
    key_table[["evt_order"]], key_table[["date_sort"]],
    key_table[["time_sort"]], key_table[["eltid"]],
    key_table[["row_sort"]], na.last = TRUE
  ), , drop = FALSE]
  evt_block <- paste(key_table[["evt_order"]], key_table[["evt"]], sep = "\r")
  key_table[["elt_rank"]] <- stats::ave(
    seq_len(nrow(key_table)), evt_block, FUN = seq_along
  )
  elt_rank <- key_table[["elt_rank"]]
  names(elt_rank) <- key_table[["key"]]
  derived <- rep(NA_real_, n)
  derived[valid] <- unname(
    elt_rank[paste(evtid[valid], eltid[valid], sep = "\r")]
  )
  out[is.na(out)] <- derived[is.na(out)]
  out
}

.order_keys <- function(df, completeness_col) {
  date_sort <- as.Date(df[["DATEPRELEV"]])
  time_sort <- .time_sort_key(df[["HEUREPRELEV"]])
  document_sort <- as.character(df[["ELTID"]])
  row_sort <- df[[".row_id_global"]]
  evt_order <- .derive_evt_order(
    df, date_sort, time_sort, document_sort, row_sort
  )
  elt_order <- .derive_elt_order(
    df, evt_order, date_sort, time_sort, document_sort, row_sort
  )
  list(
    completeness = suppressWarnings(as.numeric(df[[completeness_col]])),
    souche = as.character(df[["souche_id"]]),
    eltid = as.character(df[["ELTID"]]),
    row = row_sort,
    evt = evt_order,
    elt = elt_order
  )
}

.class_order <- function(df, completeness_col) {
  keys <- .order_keys(df, completeness_col)
  order(
    keys$evt, keys$elt, keys$souche, -keys$completeness,
    keys$eltid, keys$row, na.last = TRUE
  )
}

.representative_order <- function(df, completeness_col) {
  keys <- .order_keys(df, completeness_col)
  order(
    -keys$completeness, keys$evt, keys$elt, keys$eltid,
    keys$souche, keys$row, na.last = TRUE
  )
}

.assign_first_fit <- function(discord, order_index) {
  n <- nrow(discord)
  classes <- integer(n)
  members <- list()
  n_classes <- 0L
  for (idx in order_index) {
    placed <- FALSE
    if (n_classes > 0L) {
      for (class_id in seq_len(n_classes)) {
        if (!any(discord[idx, members[[class_id]]])) {
          classes[[idx]] <- class_id
          members[[class_id]] <- c(members[[class_id]], idx)
          placed <- TRUE
          break
        }
      }
    }
    if (!placed) {
      n_classes <- n_classes + 1L
      classes[[idx]] <- n_classes
      members[[n_classes]] <- idx
    }
  }
  classes
}

.phenotype_proxy_columns <- function(df) {
  out <- df
  sources <- list(
    blse = intersect(c("blse_status_final", "blse_status_row"), names(out)),
    carbapenemase = intersect(
      c("carbapenemase_status_final", "carbapenemase_status_row"),
      names(out)
    )
  )
  columns <- character()
  if (length(sources$blse) > 0L) {
    source <- sources$blse[[1L]]
    out[[".pheno_blse_sr"]] <- ifelse(
      tolower(as.character(out[[source]])) == "positive", "R", "S"
    )
    columns <- c(columns, ".pheno_blse_sr")
  }
  if (length(sources$carbapenemase) > 0L) {
    source <- sources$carbapenemase[[1L]]
    out[[".pheno_carba_sr"]] <- ifelse(
      tolower(as.character(out[[source]])) == "positive", "R", "S"
    )
    columns <- c(columns, ".pheno_carba_sr")
  }
  list(data = out, columns = columns)
}

.finalize_class_phenotypes <- function(group, classes, representatives) {
  out <- representatives
  status_definitions <- list(
    blse = c("blse_status_final", "blse_status_row"),
    carbapenemase = c(
      "carbapenemase_status_final", "carbapenemase_status_row"
    )
  )

  for (phenotype in names(status_definitions)) {
    source_candidates <- intersect(status_definitions[[phenotype]], names(group))
    if (length(source_candidates) == 0L) {
      next
    }
    source <- source_candidates[[1L]]
    final_status <- vapply(
      seq_len(max(classes)),
      function(class_id) {
        values <- tolower(trimws(as.character(
          group[[source]][classes == class_id]
        )))
        if (any(values == "positive", na.rm = TRUE)) "positive" else "negative"
      },
      character(1)
    )
    status_col <- paste0(phenotype, "_status_final")
    flag_col <- paste0(phenotype, "_flag")
    out[[status_col]] <- final_status
    out[[flag_col]] <- final_status == "positive"
  }
  out
}

.deduplicate_raw_patient_year <- function(
    df,
    atb_cols,
    group_cols = c("PATID", "dedup_year", "bact_norm")
  ) {
  work <- df
  work[["dedup_year"]] <- .calendar_year(work[["DATEPRELEV"]])
  .assert_columns(work, group_cols, "deduplication data")
  if (!all(c("PATID", "dedup_year", "bact_norm") %in% group_cols)) {
    .abort(
      "group_cols must include PATID, dedup_year, and bact_norm."
    )
  }
  work[[".row_id_global"]] <- seq_len(nrow(work))
  if (!"nb_resultats" %in% names(work)) {
    work[["nb_resultats"]] <- rowSums(
      work[atb_cols] == "S" | work[atb_cols] == "R",
      na.rm = TRUE
    )
  }
  phenotype <- .phenotype_proxy_columns(work)
  work <- phenotype$data
  conflict_cols <- unique(c(atb_cols, phenotype$columns))

  group_key <- do.call(paste, c(work[group_cols], sep = "\r"))
  groups <- split(work, group_key, drop = TRUE)

  representatives <- class_maps <- episode_summaries <- vector(
    "list", length(groups)
  )
  index <- 0L
  for (group in groups) {
    index <- index + 1L
    discord <- .discord_matrix(group, conflict_cols)
    class_order <- .class_order(group, "nb_resultats")
    classes <- .assign_first_fit(discord, class_order)
    reverse_classes <- .assign_first_fit(discord, rev(class_order))

    representative_local <- integer(max(classes))
    for (class_id in seq_len(max(classes))) {
      candidates <- which(classes == class_id)
      selected <- .representative_order(
        group[candidates, , drop = FALSE], "nb_resultats"
      )[[1L]]
      representative_local[[class_id]] <- candidates[[selected]]
    }

    map <- group[group_cols]
    map[["canonical_row_id"]] <- group[["canonical_row_id"]]
    map[["phenotype_class"]] <- classes
    map[["is_representative"]] <-
      seq_len(nrow(group)) %in% representative_local
    map <- map[c(
      "canonical_row_id", group_cols, "phenotype_class", "is_representative"
    )]
    class_maps[[index]] <- map

    reps <- group[representative_local, , drop = FALSE]
    reps <- .finalize_class_phenotypes(group, classes, reps)
    reps[["phenotype_class"]] <- seq_len(nrow(reps))
    representatives[[index]] <- reps

    episode_summary <- group[1L, group_cols, drop = FALSE]
    episode_summary[["n_docs"]] <- nrow(group)
    episode_summary[["n_classes"]] <- length(unique(classes))
    episode_summary[["has_multiple_classes"]] <-
      length(unique(classes)) > 1L
    episode_summary[["n_within_class_discord_pairs"]] <- sum(vapply(
        split(seq_len(nrow(group)), classes),
        function(member_index) {
          if (length(member_index) < 2L) return(0L)
          sub <- discord[member_index, member_index, drop = FALSE]
          sum(sub[upper.tri(sub)])
        },
        numeric(1)
      ))
    episode_summary[["order_sensitive"]] <- length(unique(classes)) !=
      length(unique(reverse_classes))
    episode_summaries[[index]] <- episode_summary
  }

  representatives <- .bind_rows_base(representatives)
  proxy_cols <- c(".pheno_blse_sr", ".pheno_carba_sr")
  representatives[intersect(proxy_cols, names(representatives))] <- NULL

  list(
    representatives = representatives,
    class_map = .bind_rows_base(class_maps),
    episode_summary = .bind_rows_base(episode_summaries)
  )
}
