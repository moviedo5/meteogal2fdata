#' @encoding UTF-8
#' @title MeteoGalicia daily observations as a base R data.frame
#' @description Download daily observations from MeteoGalicia, or read
#'   previously downloaded files, returning a plain `data.frame` (no `sf`
#'   geometry, no `units` classes). Every measurement keeps its MeteoGalicia
#'   validation code in a `qc_<variable>` column.
#' @details
#'   **Online requests** use the documented daily JSON service
#'   (`datosDiariosEstacionsMeteo.action`) in calendar-month windows. For each
#'   measurement the service returns the value (`valor`), its validation code
#'   (`lnCodigoValidacion`) and its unit (`unidade`); the value goes to
#'   `<variable>`, the code to `qc_<variable>` and the units to
#'   `attr(x, "units")`. Values are never converted or imputed.
#'
#'   **Validation codes** (see [meteogal_qc_codes()]): 0 not validated,
#'   1 valid original, 2 suspect, 3 erroneous, 5 valid interpolated,
#'   9 not recorded. `quality` lists the codes whose values are returned;
#'   the rest are set to `NA` and a message reports how many values were
#'   affected and with which code. The codes always remain in the `qc_`
#'   columns, so the decision can be inspected or changed later. The default
#'   `quality = c(1, 5)` keeps validated values only: recent data, not yet
#'   validated by MeteoGalicia (code 0), will therefore be `NA` unless
#'   `quality = c(0, 1, 5)` (or `NULL`) is used. Codes 3 and 9 and the
#'   value `-9999` are always `NA`. For comparison, 'meteospain' (0.3.1)
#'   removes values with codes 0, 3 and 9 and discards the codes (it keeps
#'   suspect values, code 2).
#'
#'   **Missing data**: a day absent from the service response is absent from
#'   the returned data.frame (no row is invented); a value that is `NA`,
#'   `-9999`, or has code 3 or 9 is `NA`. February 29 is kept here; it is only
#'   removed in the functional representation.
#'
#'   **Local files** (`data_dir`): station-year files written by
#'   [meteogal2download()] (`.rds` or `.csv`, with codes), files saved with
#'   `meteogal2df(file = ...)`, or any `.csv`/`.rds`/`.rda` data.frame with
#'   `fecha`, `station_id` and the variables. Data without `qc_` columns are
#'   accepted: their validation status is unknown and their values are not
#'   modified (except `-9999`). With `data_dir` and no dates,
#'   everything available is read; online, the default is the last
#'   `last_n_days` days.
#' @param station_ids `NULL` for all stations or a character vector of IDs.
#' @param start_date,end_date Optional `Date` or `"YYYY-MM-DD"`. Online, the
#'   default is the last `last_n_days` days. With `data_dir`, `NULL` means
#'   unbounded.
#' @param last_n_days Number of days used if no `start_date` is given online.
#' @param vars `NULL` to keep all measurements, or a character vector of
#'   variable names (e.g. `c("temp_mean", "prec")`) or native parameter codes
#'   (e.g. `"TA_AVG_1.5m"`). Online, they are requested with `idParam`. The
#'   station/date fields and the matching `qc_` columns are always kept.
#' @param file Optional output file (`.rds`, `.rda`/`.RData` or `.csv`). The
#'   saved file contains the **unfiltered** values and codes; `quality` only
#'   affects the returned data.frame.
#' @param data_dir `NULL` for online data, or a local directory or a single
#'   `.rds`/`.rda`/`.csv` file.
#' @param verbose Show progress messages.
#' @param control List with `max_attempts` (3), `retry_wait` (15 seconds),
#'   `sleep_pause` (1 second), `window_days` (`NULL` = calendar months) and
#'   `timeout` (60 seconds).
#' @param quality Validation codes whose values are used (default
#'   `c(1, 5)`); any of 0, 1, 2, 5. `NULL` uses all values except codes 3
#'   and 9.
#' @references
#'   MeteoGalicia, daily JSON service (parameters, structure and validation
#'   codes): <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf>.
#'
#'   MeteoGalicia, historical data through the web form (manual query of
#'   the same network, not used by this package):
#'   <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/informes/datos_es.pdf>.
#'
#'   Legal notice (attribution required): <https://www.meteogalicia.gal/aviso-legal>.
#' @return A data.frame with `fecha` (Date), `station_id` (character),
#'   station metadata (`station_name`, `municipality`, `province`,
#'   `altitude`, `lon`, `lat` when available), `timestamp`, the measurements
#'   and their `qc_` columns. Attributes: `quality` (codes used) and `units`.
#' @examples
#' f <- system.file("extdata", "meteogal_small.csv", package = "meteogal2fdata")
#' x <- meteogal2df(data_dir = f, vars = c("temp_mean", "prec"))
#' head(x)
#' \dontrun{
#' # Online: last 30 days, also using values not yet validated (code 0)
#' x <- meteogal2df(station_ids = "10157", vars = c("temp_mean", "prec"),
#'                  quality = c(0, 1, 5))
#' table(x$qc_temp_mean, useNA = "ifany")
#' }
#' @seealso [meteogal2download()], [meteogal2inventory()], [meteogal_qc_codes()]
#' @export
meteogal2df <- function(station_ids = NULL, start_date = NULL, end_date = NULL,
                        last_n_days = 30L, vars = NULL, file = NULL,
                        data_dir = NULL, verbose = FALSE, control = list(),
                        quality = c(1L, 5L)) {
  quality <- .meteogal_check_quality(quality)
  ctrl <- .meteogal_control(control)
  ids <- .meteogal_ids(station_ids)
  dates <- .meteogal_dates(start_date, end_date, last_n_days,
                            offline = !is.null(data_dir))

  if (is.null(data_dir)) {
    params <- .meteogal_api_params(vars)
    windows <- .meteogal_windows(dates$start, dates$end, ctrl$window_days)
    chunks <- vector("list", nrow(windows))
    failed <- character()
    for (i in seq_len(nrow(windows))) {
      ini <- windows$start[i]; fin <- windows$end[i]
      if (verbose) message("[MeteoGalicia] ", ini, " / ", fin)
      ans <- .meteogal_request(ini, fin, ids, ctrl, params = params)
      if (ans$status == "error") {
        failed <- c(failed, paste(ini, fin, ans$message))
      } else {
        chunks[[i]] <- ans$data
      }
      if (i < nrow(windows)) Sys.sleep(ctrl$sleep_pause)
    }
    if (length(failed)) {
      stop("Incomplete download (no partial result returned):\n",
           paste(failed, collapse = "\n"), call. = FALSE)
    }
    ans <- .meteogal_bind(chunks)
  } else {
    ans <- .meteogal_read(data_dir, ids, dates$start, dates$end, verbose)
  }

  units <- attr(ans, "units")
  ans <- .meteogal_clean(ans)
  if (!is.null(ids) && nrow(ans)) {
    ans <- ans[ans$station_id %in% ids, , drop = FALSE]
  }
  if (nrow(ans) && "fecha" %in% names(ans)) {
    if (!is.null(dates$start)) ans <- ans[!is.na(ans$fecha) & ans$fecha >= dates$start, , drop = FALSE]
    if (!is.null(dates$end)) ans <- ans[!is.na(ans$fecha) & ans$fecha <= dates$end, , drop = FALSE]
  }
  ans <- .meteogal_select(ans, vars)
  if (nrow(ans) && all(c("station_id", "fecha") %in% names(ans))) {
    ans <- ans[order(ans$station_id, ans$fecha), , drop = FALSE]
    ans <- ans[!duplicated(ans[c("station_id", "fecha")], fromLast = TRUE), , drop = FALSE]
  }
  rownames(ans) <- NULL
  attr(ans, "units") <- units[intersect(names(units), names(ans))]
  # Save the unmasked values and codes so a different quality choice remains
  # possible later. Only the returned value is quality-filtered.
  .meteogal_write(ans, file)
  .meteogal_apply_quality(ans, quality, inform = TRUE)
}

# ---- Private helpers shared by the public functions -----------------------
.meteogal_ids <- function(ids) {
  if (is.null(ids)) return(NULL)
  ids <- unique(trimws(as.character(ids)))
  ids <- ids[!is.na(ids) & nzchar(ids)]
  if (length(ids) && any(!grepl("^[A-Za-z0-9_-]+$", ids))) {
    stop("Station IDs must contain only letters, digits, underscores or hyphens.")
  }
  if (!length(ids)) stop("'station_ids' must contain at least one valid ID.")
  ids
}

.meteogal_control <- function(control = list()) {
  if (!is.list(control)) stop("'control' must be a list.")
  defaults <- list(max_attempts = 3L, retry_wait = 15, sleep_pause = 1,
                   window_days = NULL, timeout = 60)
  unknown <- setdiff(names(control), names(defaults))
  if (length(unknown)) stop("Unknown control option(s): ", paste(unknown, collapse = ", "))
  x <- utils::modifyList(defaults, control)
  for (nm in c("max_attempts", "retry_wait", "sleep_pause")) {
    v <- x[[nm]]
    if (length(v) != 1L || !is.numeric(v) || is.na(v) || !is.finite(v) ||
        v < (if (nm == "max_attempts") 1 else 0) ||
        (nm == "max_attempts" && v != as.integer(v))) stop("Invalid control$", nm)
  }
  x$max_attempts <- as.integer(x$max_attempts)
  if (!is.numeric(x$timeout) || length(x$timeout) != 1L ||
      !is.finite(x$timeout) || x$timeout < 1) stop("Invalid control$timeout.")
  if (!is.null(x$window_days)) {
    w <- x$window_days
    if (length(w) != 1L || !is.numeric(w) || is.na(w) ||
        !is.finite(w) || w < 1 || w != as.integer(w)) stop("Invalid control$window_days")
    x$window_days <- as.integer(w)
  }
  x
}

.meteogal_dates <- function(start_date, end_date, last_n_days = 30L, offline = FALSE) {
  if (length(last_n_days) != 1L || !is.numeric(last_n_days) ||
      is.na(last_n_days) || last_n_days < 1 || last_n_days != as.integer(last_n_days)) {
    stop("'last_n_days' must be a positive integer.")
  }
  parse <- function(x) {
    if (is.null(x)) return(NULL)
    if (length(x) != 1L || is.na(x)) stop("Dates must be single valid dates.")
    y <- suppressWarnings(as.Date(x))
    if (is.na(y)) stop("Dates must have format YYYY-MM-DD.")
    y
  }
  start <- parse(start_date); end <- parse(end_date)
  if (!offline) {
    if (is.null(end)) end <- Sys.Date()
    if (is.null(start)) start <- end - as.integer(last_n_days) + 1L
    if (end > Sys.Date()) stop("'end_date' cannot be in the future.")
  }
  if (!is.null(start) && !is.null(end) && end < start) {
    stop("'end_date' must be on or after 'start_date'.")
  }
  list(start = start, end = end)
}

.meteogal_windows <- function(start, end, window_days = NULL) {
  if (is.null(start) || is.null(end)) stop("Both dates are required for downloading.")
  out <- list(); current <- start
  while (current <= end) {
    if (is.null(window_days)) {
      yy <- as.integer(format(current, "%Y")); mm <- as.integer(format(current, "%m"))
      following <- as.Date(sprintf("%04d-%02d-01", yy + (mm == 12L), mm %% 12L + 1L))
      fin <- min(end, following - 1L)
    } else fin <- min(end, current + window_days - 1L)
    out[[length(out) + 1L]] <- data.frame(start = current, end = fin)
    current <- fin + 1L
  }
  do.call(rbind, out)
}

# One window with retries. Errors are returned, never thrown.
.meteogal_request <- function(start, end, station_ids, ctrl, params = NULL) {
  error <- "Unknown download error"
  for (attempt in seq_len(ctrl$max_attempts)) {
    res <- tryCatch(.meteogal_json_request(start, end, station_ids, params, ctrl$timeout),
                    error = function(e) {error <<- conditionMessage(e); NULL})
    if (!is.null(res) && is.data.frame(res)) {
      return(list(status = "ok", data = res, message = ""))
    }
    if (attempt < ctrl$max_attempts) Sys.sleep(ctrl$retry_wait)
  }
  list(status = "error", data = NULL, message = error)
}

.meteogal_clean <- function(x) {
  if (is.null(x) || !NROW(x)) return(data.frame())
  if (!is.data.frame(x)) stop("Expected a data.frame.")
  units <- attr(x, "units")
  if (!identical(class(x), "data.frame")) x <- as.data.frame(x, stringsAsFactors = FALSE)
  if (!"fecha" %in% names(x) && "timestamp" %in% names(x)) {
    x$fecha <- as.Date(x$timestamp, tz = "UTC")
  }
  if ("fecha" %in% names(x)) x$fecha <- as.Date(x$fecha)
  if ("station_id" %in% names(x)) x$station_id <- as.character(x$station_id)
  qc <- grep("^qc_", names(x), value = TRUE)
  for (nm in qc) x[[nm]] <- suppressWarnings(as.integer(x[[nm]]))
  fixed <- intersect(.meteogal_meta_cols(), names(x))
  x <- x[, c(fixed, setdiff(names(x), fixed)), drop = FALSE]
  attr(x, "units") <- units
  x
}

.meteogal_bind <- function(x) {
  x <- Filter(function(z) !is.null(z) && NROW(z) > 0L, x)
  if (!length(x)) return(data.frame())
  x <- lapply(x, .meteogal_clean)
  units <- unlist(lapply(x, function(z) attr(z, "units")))
  units <- units[!duplicated(names(units))]
  allnames <- unique(unlist(lapply(x, names), use.names = FALSE))
  for (i in seq_along(x)) {
    missing <- setdiff(allnames, names(x[[i]]))
    for (nm in missing) x[[i]][[nm]] <- NA
    x[[i]] <- x[[i]][, allnames, drop = FALSE]
  }
  ans <- do.call(rbind, x)
  rownames(ans) <- NULL
  attr(ans, "units") <- units
  ans
}

.meteogal_select <- function(x, vars) {
  if (is.null(vars) || !nrow(x)) return(x)
  if (!is.character(vars)) stop("'vars' must be NULL or a character vector.")
  code_to_name <- .meteogal_parameter_names()
  vars <- vapply(vars, function(v) {
    if (v %in% names(code_to_name)) return(unname(code_to_name[[v]]))
    v
  }, character(1))
  vars <- unique(vars)
  missing <- setdiff(vars, names(x))
  if (length(missing)) stop("Unknown variable(s): ", paste(missing, collapse = ", "),
                            ". Available: ", paste(names(x), collapse = ", "))
  units <- attr(x, "units")
  qc <- paste0("qc_", vars)
  x <- x[, unique(c(intersect(.meteogal_meta_cols(), names(x)), vars,
                    intersect(qc, names(x)))), drop = FALSE]
  attr(x, "units") <- units[intersect(names(units), vars)]
  x
}

# Station-year files ID_YYYY.(rds|csv|rda) as written by meteogal2download().
# Cache folders (_tmp*) and the manifest are skipped.
.meteogal_file_pattern <- function() {
  "^[A-Za-z0-9_-]+_[0-9]{4}\\.(rds|rda|rdata|csv)$"
}

.meteogal_read_file <- function(f) {
  if (grepl("\\.rds$", f, ignore.case = TRUE)) {
    obj <- readRDS(f)
  } else if (grepl("\\.csv$", f, ignore.case = TRUE)) {
    # 'encoding' (not 'fileEncoding') works in any locale, including C/POSIX.
    obj <- utils::read.csv(f, colClasses = c(station_id = "character"),
                           stringsAsFactors = FALSE, encoding = "UTF-8")
  } else {
    e <- new.env(parent = baseenv())
    loaded <- load(f, envir = e)
    candidate <- intersect("data", loaded)   # name used by .meteogal_write()
    nm <- if (length(candidate)) candidate[1L] else if (length(loaded) == 1L) loaded else NA_character_
    if (is.na(nm)) stop("Ambiguous objects in: ", f)
    obj <- e[[nm]]
  }
  if (!is.data.frame(obj)) stop("File does not contain tabular data: ", f)
  .meteogal_clean(obj)
}

.meteogal_read <- function(data_dir, station_ids, start, end, verbose) {
  if (length(data_dir) != 1L || !file.exists(data_dir)) stop("'data_dir' does not exist.")
  if (dir.exists(data_dir)) {
    files <- list.files(data_dir, recursive = TRUE, full.names = TRUE,
                        pattern = "\\.(rds|rda|rdata|csv)$", ignore.case = TRUE)
    files <- files[grepl(.meteogal_file_pattern(), basename(files), ignore.case = TRUE)]
    files <- files[!grepl("(^|[/\\\\])_tmp[^/\\\\]*([/\\\\]|$)", files)]
  } else files <- data_dir
  if (!length(files)) stop("No station-year files (ID_YYYY.rds/.csv/.rda) found in 'data_dir'.")
  yfile <- suppressWarnings(as.integer(sub(".*_([0-9]{4})\\.[^.]+$", "\\1", basename(files))))
  keep <- rep(TRUE, length(files))
  if (!is.null(start)) keep <- keep & (is.na(yfile) | yfile >= as.integer(format(start, "%Y")))
  if (!is.null(end)) keep <- keep & (is.na(yfile) | yfile <= as.integer(format(end, "%Y")))
  if (!is.null(station_ids) && dir.exists(data_dir)) {
    st <- sub("_([0-9]{4})\\.[^.]+$", "", basename(files))
    keep <- keep & st %in% station_ids
  }
  files <- files[keep]
  if (!length(files)) return(data.frame())
  out <- vector("list", length(files))
  for (i in seq_along(files)) {
    if (verbose) message("[MeteoGalicia] Reading ", files[i])
    out[[i]] <- .meteogal_read_file(files[i])
  }
  .meteogal_bind(out)
}

.meteogal_write <- function(x, file) {
  if (is.null(file)) return(invisible(NULL))
  if (length(file) != 1L || is.na(file) || !nzchar(file)) stop("Invalid 'file'.")
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  ext <- tolower(tools::file_ext(file))
  if (ext == "rds") saveRDS(x, file)
  else if (ext %in% c("rda", "rdata")) {data <- x; save(data, file = file)}
  else if (ext == "csv") .meteogal_write_csv(x, file)
  else stop("Unsupported file extension: use .rds, .rda/.RData or .csv.")
  invisible(file)
}

# UTF-8 CSV writer that does not depend on the session locale (write.csv in a
# non-UTF-8 locale would write accents as <U+00F1>). NA is written as "".
.meteogal_write_csv <- function(x, file, append = FALSE) {
  cols <- lapply(x, function(z) {
    if (inherits(z, "Date")) out <- format(z)
    else if (inherits(z, "POSIXt")) out <- format(z, tz = "UTC")
    else if (is.numeric(z)) out <- as.character(z)
    else if (is.logical(z)) out <- as.character(z)
    else {
      out <- enc2utf8(as.character(z))
      out <- ifelse(is.na(out), NA_character_, paste0('"', gsub('"', '""', out, fixed = TRUE), '"'))
    }
    out[is.na(out)] <- ""
    out
  })
  body <- if (nrow(x)) do.call(paste, c(cols, sep = ",")) else character()
  header <- paste0('"', enc2utf8(names(x)), '"', collapse = ",")
  con <- file(file, open = if (append) "ab" else "wb")
  on.exit(close(con))
  writeLines(if (append) body else c(header, body), con, useBytes = TRUE)
  invisible(file)
}
