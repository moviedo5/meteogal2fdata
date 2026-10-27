#' @encoding UTF-8
#' @title Download MeteoGalicia daily observations to station-year files
#' @description Download original daily values **and their validation codes**
#'   in calendar-month windows and save one file per station and year
#'   (`.rds` or `.csv`). Completed windows are cached, so a repeated call
#'   resumes an interrupted download without repeating successful requests.
#'   Every file written is recorded in a provenance manifest.
#' @details
#'   Files are stored as `out_dir/STATION/STATION_YYYY.rds` (or `.csv`). Each
#'   contains a base R data.frame with `fecha`, station metadata, the daily
#'   values and one `qc_<variable>` column per variable with the
#'   MeteoGalicia validation code (see [meteogal_qc_codes()]).
#'
#'   **Nothing is filtered at download time**: suspect, unvalidated or
#'   erroneous values are stored as delivered, with their codes. The quality
#'   criterion is chosen later, when reading, with the `quality` argument of
#'   [meteogal2df()], [meteogal2fdata()] or [meteogal2lfdata()], so it can be
#'   changed without downloading again. No missing value is imputed.
#'
#'   **Provenance.** `out_dir/_meteogal_manifest.csv` gets one row per file
#'   written: file, station, year, format, rows, first and last date, the
#'   requested parameters (`idParam`), whether validation codes are present,
#'   `quality_filter = "none (raw values with lnCodigoValidacion)"`, the
#'   download time (UTC), the service URL and the package version. `.rds`
#'   files also carry this information in `attr(x, "meteogal_meta")` and the
#'   units reported by the service in `attr(x, "units")`.
#'
#'   Existing station-year files are merged by `station_id` and `fecha`:
#'   variables downloaded now replace those dates, other variables and dates
#'   are kept. If any window of a station-year fails, its final file is not
#'   written (successful windows stay cached); re-run to resume.
#'
#'   Stations are taken from the observations returned in each window, so
#'   stations opening or closing during the year are included. No request
#'   quota is stated in the service documentation; monthly windows and
#'   pauses (`control$sleep_pause`) keep the load low.
#'
#'   Data source: MeteoGalicia, Xunta de Galicia. Reuse requires citing
#'   MeteoGalicia as the source (<https://www.meteogalicia.gal/aviso-legal>).
#' @param start_date,end_date `Date` or `"YYYY-MM-DD"`; not in the future.
#' @param out_dir Destination folder (relative path recommended).
#' @param station_ids `NULL` for all stations, or station codes. With explicit
#'   IDs, each station is requested separately for safe resumption.
#' @param vars `NULL` for all variables, or names / native parameter codes
#'   requested with `idParam` (e.g. `c("temp_mean", "prec")`).
#' @param window_days `NULL` (calendar months) or a positive integer.
#' @param format `"rds"` (default) or `"csv"` (UTF-8, empty string for `NA`).
#' @param overwrite If `TRUE`, request the windows again (ignoring the cache)
#'   and replace those dates in existing files.
#' @param verbose Show messages.
#' @param control List of `max_attempts` (3), `retry_wait` (15 s),
#'   `sleep_pause` (1 s) and `timeout` (60 s). See [meteogal2df()].
#' @return Invisibly, a data.frame with `station_id`, `year`, `status`
#'   (`ok`, `done` = everything from cache, `nodata`, `incomplete`),
#'   `n_windows`, `n_failed`, `n_files` and `n_rows`.
#' @references MeteoGalicia daily JSON service documentation:
#'   <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf>.
#' @examples
#' \dontrun{
#' log <- meteogal2download("2024-01-01", "2024-12-31", station_ids = "10157",
#'                          vars = c("temp_mean", "prec"), format = "csv",
#'                          out_dir = "meteogal_daily")
#' log
#' read.csv(file.path("meteogal_daily", "_meteogal_manifest.csv"))
#' # Quality is chosen when reading (no new download needed)
#' x1 <- meteogal2df(data_dir = "meteogal_daily", quality = c(1, 5))
#' x0 <- meteogal2df(data_dir = "meteogal_daily", quality = c(0, 1, 5))
#' }
#' @seealso [meteogal2df()], [meteogal2inventory()], [meteogal_qc_codes()]
#' @export
meteogal2download <- function(start_date, end_date, out_dir = "meteogal_daily",
                              station_ids = NULL, vars = NULL, window_days = NULL,
                              format = c("rds", "csv"), overwrite = FALSE,
                              verbose = TRUE, control = list()) {
  format <- match.arg(format)
  if (!is.null(window_days)) control <- utils::modifyList(control, list(window_days = window_days))
  ctrl <- .meteogal_control(control)
  ids <- .meteogal_ids(station_ids)
  params <- .meteogal_api_params(vars)
  if (missing(start_date) || missing(end_date) || is.null(start_date) || is.null(end_date)) {
    stop("Both 'start_date' and 'end_date' must be provided.")
  }
  dates <- .meteogal_dates(start_date, end_date)
  if (length(out_dir) != 1L || is.na(out_dir) || !nzchar(out_dir)) stop("Invalid 'out_dir'.")
  if (length(overwrite) != 1L || is.na(overwrite) || !is.logical(overwrite)) {
    stop("'overwrite' must be TRUE or FALSE.")
  }
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  # Window cache with validation codes, one folder per parameter set.
  tmp_dir <- file.path(out_dir, "_tmp_qc", "json", .meteogal_cache_tag(params))
  dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)

  groups <- if (is.null(ids)) NA_character_ else ids
  years <- seq.int(as.integer(format(dates$start, "%Y")),
                   as.integer(format(dates$end, "%Y")))
  log <- list()
  for (st in groups) for (yr in years) {
    ini <- max(dates$start, as.Date(sprintf("%04d-01-01", yr)))
    fin <- min(dates$end, as.Date(sprintf("%04d-12-31", yr)))
    win <- .meteogal_windows(ini, fin, ctrl$window_days)
    tag <- if (is.na(st)) "all" else st
    chunks <- vector("list", nrow(win)); failed <- character()
    n_new <- 0L
    for (i in seq_len(nrow(win))) {
      cache <- file.path(tmp_dir, paste0("meteogal_", tag, "_", win$start[i],
                                          "_", win$end[i], ".rds"))
      if (!overwrite && file.exists(cache)) {
        cached <- tryCatch(readRDS(cache), error = function(e) NULL)
        if (!is.null(cached)) {
          chunks[[i]] <- cached
          next
        }
      }
      if (verbose) message("[MeteoGalicia] ", tag, " ", win$start[i], " / ", win$end[i])
      ans <- .meteogal_request(win$start[i], win$end[i],
                              if (is.na(st)) NULL else st, ctrl, params = params)
      if (ans$status == "error") {
        failed <- c(failed, paste(win$start[i], win$end[i], ans$message))
        if (verbose) message("  ERROR: ", ans$message)
      } else {
        chunks[[i]] <- ans$data
        saveRDS(ans$data, cache)
        n_new <- n_new + 1L
      }
      Sys.sleep(ctrl$sleep_pause)
    }
    status <- if (length(failed)) "incomplete" else "nodata"
    n_files <- 0L; n_rows <- 0L
    if (!length(failed)) {
      dat <- .meteogal_select(.meteogal_bind(chunks), vars)
      if (!is.na(st) && nrow(dat)) dat <- dat[dat$station_id == st, , drop = FALSE]
      if (nrow(dat)) {
        if (!"station_id" %in% names(dat) || !"fecha" %in% names(dat)) {
          stop("Downloaded data lack station_id or fecha; nothing saved.")
        }
        units <- attr(dat, "units")
        for (id in unique(dat$station_id[!is.na(dat$station_id)])) {
          cur <- dat[dat$station_id == id, , drop = FALSE]
          n_cur <- nrow(cur)
          dest <- file.path(out_dir, id, paste0(id, "_", yr, ".", format))
          dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
          if (file.exists(dest)) {
            old <- .meteogal_read_file(dest)
            units <- c(units, attr(old, "units"))
            units <- units[!duplicated(names(units))]
            cur <- .meteogal_merge_station(old, cur)
          }
          cur <- cur[order(cur$fecha), , drop = FALSE]
          cur <- cur[!duplicated(cur[c("station_id", "fecha")], fromLast = TRUE), , drop = FALSE]
          rownames(cur) <- NULL
          meta <- .meteogal_download_meta(dest, id, yr, format, cur, params)
          attr(cur, "units") <- units[intersect(names(units), names(cur))]
          attr(cur, "meteogal_meta") <- as.list(meta)
          if (format == "rds") saveRDS(cur, dest) else .meteogal_write(cur, dest)
          .meteogal_manifest_append(out_dir, meta)
          n_rows <- n_rows + n_cur
          n_files <- n_files + 1L
        }
        status <- if (n_files > 0L) {if (n_new) "ok" else "done"} else "nodata"
      }
    } else {
      warning("Incomplete download for ", tag, " / ", yr, ": ",
              length(failed), " failed window(s). Re-run to resume.", call. = FALSE)
    }
    log[[length(log) + 1L]] <- data.frame(
      station_id = if (is.na(st)) NA_character_ else st,
      year = yr, status = status, n_windows = nrow(win),
      n_failed = length(failed), n_files = n_files, n_rows = n_rows)
  }
  out <- do.call(rbind, log)
  rownames(out) <- NULL
  invisible(out)
}

# One manifest row describing a station-year file just written.
.meteogal_download_meta <- function(dest, id, year, format, x, params) {
  qc <- grep("^qc_", names(x), value = TRUE)
  data.frame(
    file = file.path(id, basename(dest)), station_id = id, year = as.integer(year),
    format = format, n_rows = nrow(x),
    first_date = format(min(x$fecha, na.rm = TRUE)),
    last_date = format(max(x$fecha, na.rm = TRUE)),
    id_param = if (is.null(params)) "all" else paste(params, collapse = ","),
    variables = paste(sub("^qc_", "", qc), collapse = ","),
    qc_codes = length(qc) > 0L,
    quality_filter = "none (raw values with lnCodigoValidacion)",
    downloaded_utc = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    source = paste0(.meteogal_base_url(), "datosDiariosEstacionsMeteo.action"),
    package_version = .meteogal_version(),
    stringsAsFactors = FALSE)
}

.meteogal_manifest_append <- function(out_dir, meta) {
  f <- file.path(out_dir, "_meteogal_manifest.csv")
  exists <- file.exists(f)
  .meteogal_write_csv(meta, f, append = exists)
  invisible(f)
}
