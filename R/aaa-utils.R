.abort <- function(...) {
  stop(..., call. = FALSE)
}

.assert_data_frame <- function(x, name) {
  if (!is.data.frame(x)) {
    .abort(name, " must be a data frame.")
  }
  invisible(x)
}

.assert_columns <- function(x, columns, name) {
  missing <- setdiff(columns, names(x))
  if (length(missing) > 0L) {
    .abort(name, " is missing columns: ", paste(missing, collapse = ", "))
  }
  invisible(x)
}

.trim_or_na <- function(x) {
  out <- trimws(as.character(x))
  out[is.na(x) | !nzchar(out)] <- NA_character_
  out
}

.encode_key_component <- function(x) {
  x <- enc2utf8(as.character(x))
  missing <- is.na(x)
  out <- paste0(nchar(x, type = "bytes", allowNA = TRUE), ":", x)
  out[missing] <- "-1:"
  out
}

.make_key <- function(df, columns) {
  .assert_columns(df, columns, "key data")
  encoded <- lapply(df[columns], .encode_key_component)
  do.call(paste, c(encoded, sep = "\u001f"))
}

.make_canonical_row_id <- function(df) {
  .make_key(
    df,
    c(
      "PATID", "EVTID", "ELTID", "DATEPRELEV", "souche_id",
      "naturepvt_norm", "bact_norm"
    )
  )
}

.calendar_year <- function(x) {
  dates <- as.Date(x)
  out <- suppressWarnings(as.integer(format(dates, "%Y")))
  if (any(is.na(out))) {
    .abort("DATEPRELEV must be non-missing and coercible to Date.")
  }
  out
}

.bind_rows_base <- function(parts) {
  parts <- Filter(function(x) !is.null(x) && nrow(x) > 0L, parts)
  if (length(parts) == 0L) {
    return(data.frame())
  }
  out <- do.call(rbind, parts)
  row.names(out) <- NULL
  out
}
