# Internal helpers for converting daily observations to functional data.

.meteogal_input <- function(df = NULL, file = NULL, station_ids = NULL,
                            start_date = NULL, end_date = NULL,
                            last_n_days = 30L, verbose = FALSE,
                            control = list(), quality = c(1L, 5L)) {
  quality <- .meteogal_check_quality(quality)
  if (!is.null(df) && !is.null(file)) {
    stop("Use only one data source: 'df' or 'file'.", call. = FALSE)
  }
  ids <- .meteogal_ids(station_ids)
  if (!is.null(df)) {
    if (!is.data.frame(df)) stop("'df' must be a data.frame.", call. = FALSE)
    out <- .meteogal_clean(df)
  } else if (!is.null(file)) {
    if (!is.character(file) || !length(file) || anyNA(file)) {
      stop("'file' must specify one or more existing files or a directory.")
    }
    parts <- lapply(file, function(f) meteogal2df(
      station_ids = ids, start_date = start_date, end_date = end_date,
      data_dir = f, verbose = verbose, quality = quality))
    out <- .meteogal_bind(parts)
  } else {
    out <- meteogal2df(station_ids = ids, start_date = start_date,
                       end_date = end_date, last_n_days = last_n_days,
                       verbose = verbose, control = control,
                       quality = quality)
  }
  if (!nrow(out)) stop("No meteorological observations found.", call. = FALSE)
  if (!all(c("fecha", "station_id") %in% names(out))) {
    stop("Input must contain 'fecha' (or 'timestamp') and 'station_id'.")
  }
  units <- attr(out, "units")
  out$fecha <- as.Date(out$fecha)
  out$station_id <- as.character(out$station_id)
  sel <- !is.na(out$fecha) & !is.na(out$station_id) & nzchar(out$station_id)
  if (!is.null(ids)) sel <- sel & out$station_id %in% ids
  if (!is.null(start_date)) {
    start <- .meteogal_dates(start_date, NULL, offline = TRUE)$start
    sel <- sel & out$fecha >= start
  }
  if (!is.null(end_date)) {
    end <- .meteogal_dates(NULL, end_date, offline = TRUE)$end
    sel <- sel & out$fecha <= end
  }
  out <- out[sel, , drop = FALSE]
  # Values already filtered by meteogal2df() are NA, so nothing is reported twice.
  out <- .meteogal_apply_quality(out, quality, inform = TRUE)
  if (!nrow(out)) stop("No observations remain after filtering.", call. = FALSE)
  attr(out, "units") <- units
  out
}

.meteogal_curve_index <- function(dat) {
  dat$year <- as.integer(format(dat$fecha, "%Y"))
  # Common 365-point grid: February 29 removed, day 60 is always March 1.
  mmdd <- format(dat$fecha, "%m-%d")
  dat <- dat[mmdd != "02-29", , drop = FALSE]
  if (!nrow(dat)) stop("No dates remain after removing February 29.")
  dat <- dat[order(dat$station_id, dat$fecha), , drop = FALSE]
  duplicate <- duplicated(dat[c("station_id", "fecha")], fromLast = TRUE)
  if (any(duplicate)) {
    warning(sum(duplicate), " duplicate station-date row(s) removed; ",
            "the last observation was retained.", call. = FALSE)
    dat <- dat[!duplicate, , drop = FALSE]
  }
  rownames(dat) <- NULL
  key <- paste(dat$station_id, dat$year, sep = "_")
  keys <- unique(key)
  year <- as.integer(sub("^.*_([0-9]{4})$", "\\1", keys))
  station <- sub("_[0-9]{4}$", "", keys)
  pos <- as.integer(format(dat$fecha, "%j"))
  leap <- (dat$year %% 4L == 0L & dat$year %% 100L != 0L) |
    (dat$year %% 400L == 0L)
  pos <- pos - as.integer(leap & as.integer(format(dat$fecha, "%m")) >= 3L)
  if (anyNA(pos) || any(pos < 1L | pos > 365L)) stop("Invalid daily grid position.")
  list(data = dat, key = key, keys = keys, station_id = station, year = year,
       row = match(key, keys), day = pos,
       n_days = tabulate(match(key, keys), nbins = length(keys)))
}

.meteogal_numeric_vars <- function(dat, vars = NULL) {
  non_vars <- c(.meteogal_meta_cols(), grep("^qc_", names(dat), value = TRUE))
  available <- setdiff(names(dat)[vapply(dat, is.numeric, logical(1))], non_vars)
  if (is.null(vars)) return(available)
  if (!is.character(vars) || !length(vars) || anyNA(vars)) {
    stop("'vars' must be a non-empty character vector of variable names.")
  }
  vars <- unique(vars)
  bad <- setdiff(vars, available)
  if (length(bad)) {
    stop("Variables missing or non-numeric: ", paste(bad, collapse = ", "),
         ". Available: ", paste(available, collapse = ", "), call. = FALSE)
  }
  vars
}

# Units reported by the service (attr "units") take precedence.
.meteogal_var_units <- function(var, units = NULL) {
  if (!is.null(units) && var %in% names(units) && !is.na(units[[var]])) return(unname(units[[var]]))
  def <- .meteogal_default_units()
  if (var %in% names(def)) def[[var]] else ""
}

# n_curves x 365 matrix of one column of idx$data on the common grid.
.meteogal_grid <- function(idx, values, na = NA) {
  mat <- matrix(na, nrow = length(idx$keys), ncol = 365L,
                dimnames = list(idx$keys, as.character(seq_len(365L))))
  mat[cbind(idx$row, idx$day)] <- values
  mat
}

.meteogal_build_fdata <- function(idx, var, units = NULL, quality = c(1L, 5L)) {
  mat <- .meteogal_grid(idx, as.numeric(idx$data[[var]]), NA_real_)
  unit <- .meteogal_var_units(var, units)
  ylab <- if (nzchar(unit)) paste0(var, " (", unit, ")") else var
  fd <- fda.usc::fdata(mat, argvals = seq_len(365L), rangeval = c(1, 365),
                       names = list(main = var, xlab = "Day of year", ylab = ylab))
  attr(fd, "var_name") <- var
  attr(fd, "var_units") <- unit
  attr(fd, "quality_codes") <- if (is.null(quality)) "all except 3 and 9" else quality
  attr(fd, "source") <- "MeteoGalicia (Xunta de Galicia)"
  fd
}

# Day-level matrices stored as columns of ldata$df: class "mg_daymat" keeps
# rows aligned when ldata is subset (subset(), [ with row = TRUE) and prints
# as one compact summary per curve.
.mg_daymat <- function(x, kind) structure(x, class = "mg_daymat", kind = kind)

#' Day-level matrices in `ldata$df`
#'
#' [meteogal2lfdata()] stores the validation code of every day
#' (`qc_<variable>`) and the date of every record (`fecha`) as
#' `n_curves x 365` matrices in columns of `ldata$df`, so they stay aligned
#' with the curves when the object is subset. These methods print them as a
#' one-line summary per curve and keep the class when rows are selected. Use
#' `unclass()` (or `as.matrix()`) to obtain the plain matrix.
#'
#' @param x An object of class `mg_daymat`.
#' @param ... Indices (`[`) or ignored (`format`).
#' @return `format()`: a character vector, one element per row; `print()`:
#'   `x`, invisibly; `as.matrix()`: the plain matrix; `[`: an
#'   `mg_daymat` when the result is a matrix, otherwise a plain vector.
#' @examples
#' d <- data.frame(fecha = as.Date(c("2024-01-01", "2024-01-02")),
#'                 station_id = "10157", temp_mean = c(10, 11),
#'                 qc_temp_mean = c(1L, 5L))
#' ld <- meteogal2lfdata(df = d, vars = "temp_mean")
#' ld$df$qc_temp_mean            # compact summary
#' unclass(ld$df$qc_temp_mean)[, 1:3]
#' @name mg_daymat
#' @keywords internal
NULL

#' @rdname mg_daymat
#' @export
format.mg_daymat <- function(x, ...) {
  kind <- attr(x, "kind")
  m <- unclass(x)
  attr(m, "kind") <- NULL
  if (!length(m)) return(character())
  if (identical(kind, "date")) {
    apply(m, 1L, function(r) {
      r <- r[!is.na(r)]
      if (!length(r)) "no records" else paste0(min(r), "..", max(r), " (", length(r), ")")
    })
  } else {
    apply(m, 1L, function(r) {
      t <- table(factor(ifelse(is.na(r), "NA", r),
                        levels = c("0", "1", "2", "3", "5", "9", "NA",
                                   setdiff(unique(as.character(r[!is.na(r)])),
                                           c("0", "1", "2", "3", "5", "9")))))
      t <- t[t > 0L]
      paste0(names(t), ":", t, collapse = " ")
    })
  }
}

#' @rdname mg_daymat
#' @export
`[.mg_daymat` <- function(x, ...) {
  kind <- attr(x, "kind")
  r <- unclass(x)
  attr(r, "kind") <- NULL
  r <- r[...]
  if (length(dim(r)) == 2L) .mg_daymat(r, kind) else r
}

#' @rdname mg_daymat
#' @export
print.mg_daymat <- function(x, ...) {
  out <- format(x)
  if (is.null(names(out))) names(out) <- rownames(unclass(x))
  print(out, quote = FALSE)
  invisible(x)
}

#' @rdname mg_daymat
#' @export
as.matrix.mg_daymat <- function(x, ...) {
  m <- unclass(x)
  attr(m, "kind") <- NULL
  m
}

.meteogal_curve_metadata <- function(idx, inventory = NULL) {
  cols <- c("station_id", "station_name", "municipality", "province",
            "altitude", "lon", "lat")
  source <- idx$data[!duplicated(idx$key, fromLast = TRUE), , drop = FALSE]
  source <- source[match(idx$keys, paste(source$station_id, source$year, sep = "_")), ,
                   drop = FALSE]
  for (nm in setdiff(cols, names(source))) source[[nm]] <- NA
  meta <- source[, cols, drop = FALSE]
  meta$year <- idx$year
  meta$n_days <- idx$n_days
  rng <- tapply(as.numeric(idx$data$fecha), idx$row, range)
  rng <- do.call(rbind, rng)
  meta$first_date <- as.Date(rng[, 1L], origin = "1970-01-01")
  meta$last_date <- as.Date(rng[, 2L], origin = "1970-01-01")
  if (!is.null(inventory)) {
    inv <- if (is.data.frame(inventory)) inventory else if (
      is.character(inventory) && length(inventory) == 1L && file.exists(inventory)) {
      ext <- tolower(tools::file_ext(inventory))
      if (ext == "rds") readRDS(inventory) else if (ext == "csv") {
        utils::read.csv(inventory, colClasses = c(station_id = "character"),
                        stringsAsFactors = FALSE, encoding = "UTF-8")
      } else stop("Inventory file must be .csv or .rds.")
    } else stop("'inventory' must be a data.frame or an existing .rds/.csv path.")
    if (!is.data.frame(inv) || !"station_id" %in% names(inv)) {
      stop("Invalid inventory: 'station_id' column is required.")
    }
    inv$station_id <- as.character(inv$station_id)
    inv <- inv[!duplicated(inv$station_id), , drop = FALSE]
    k <- match(meta$station_id, inv$station_id)
    for (nm in intersect(setdiff(cols, "station_id"), names(inv))) {
      fill <- is.na(meta[[nm]])
      if (is.character(meta[[nm]])) fill <- fill | !nzchar(meta[[nm]])
      fill <- fill & !is.na(k)
      if (any(fill)) {
        if (is.logical(meta[[nm]])) meta[[nm]] <- as.vector(meta[[nm]], mode = typeof(inv[[nm]]))
        meta[[nm]][fill] <- inv[[nm]][k[fill]]
      }
    }
  }
  # Date of every record on the 365-day grid (NA = no record that day).
  meta$fecha <- .mg_daymat(.meteogal_grid(idx, format(idx$data$fecha), NA_character_),
                           "date")
  rownames(meta) <- idx$keys
  meta
}

# Per-variable columns of ldata$df: 4 counts and the n x 365 code matrix.
.meteogal_quality_columns <- function(idx, var, quality = c(1L, 5L)) {
  qs <- .meteogal_quality_summary(idx, var, quality)
  qc_nm <- paste0("qc_", var)
  codes <- if (qc_nm %in% names(idx$data)) idx$data[[qc_nm]] else rep(NA_integer_, nrow(idx$data))
  out <- list(qs$n_valid, qs$n_interp, qs$n_masked, qs$n_missing,
              .mg_daymat(.meteogal_grid(idx, as.integer(codes), NA_integer_), "qc"))
  names(out) <- paste0(c("n_", "n_", "n_", "n_", "qc_"), var,
                       c("_valid", "_interp", "_masked", "_missing", ""))
  out
}

.meteogal_save_object <- function(x, output_file) {
  if (is.null(output_file)) return(invisible(NULL))
  if (length(output_file) != 1L || !is.character(output_file) ||
      is.na(output_file) || !nzchar(output_file)) stop("Invalid 'output_file'.")
  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  ext <- tolower(tools::file_ext(output_file))
  if (ext == "rds") saveRDS(x, output_file)
  else if (ext %in% c("rda", "rdata")) {
    result <- x
    save(result, file = output_file)
  } else stop("'output_file' must end in .rds, .rda or .RData.")
  invisible(output_file)
}
