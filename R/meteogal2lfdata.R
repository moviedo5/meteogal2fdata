#' @title Convert MeteoGalicia daily observations to an ldata object
#' @description Create an `fda.usc::ldata` object: a metadata data.frame `df`
#'   with one row per station-year, and one `fdata` element per variable.
#' @details All curves use `argvals = 1:365`: February 29 is removed and day
#'   60 is always March 1. Days without a record and values not admitted by
#'   `quality` are `NA` (never imputed). Row names (`station_year`) are shared
#'   by `df` and every `fdata` element.
#'
#'   **Columns of `ldata$df`**
#'   * Station: `station_id`, `station_name`, `municipality`, `province`,
#'     `altitude` (m), `lon`, `lat` (completed from `inventory` if given).
#'   * Curve: `year`, `n_days` (calendar dates with a record, after removing
#'     February 29, whatever the variable), `first_date`, `last_date`, and
#'     `fecha`: a 365-column matrix with the date of each record (`NA` = no
#'     record that day).
#'   * For each variable `v`: `n_v_valid` (days with a value used in the
#'     curve), `n_v_interp` (of these, interpolated by MeteoGalicia, code 5),
#'     `n_v_masked` (days whose value was set to `NA` because its code is not
#'     in `quality`, e.g. 0, 2 or 3), `n_v_missing` (`365 - n_v_valid`), and
#'     `qc_v`: a 365-column matrix with the validation code of each day
#'     (`NA` = no code: day absent, or data without codes).
#'
#'   The matrices have class `mg_daymat` (see [mg_daymat]): they print as one
#'   summary per curve and are subset with the rows, so
#'   `subset(ld, ld$df$n_temp_mean_valid >= 330)` keeps curves, metadata,
#'   codes and dates aligned. Use `unclass(ld$df$qc_temp_mean)` for the plain
#'   matrix. Source: MeteoGalicia, Xunta de Galicia.
#' @param station_ids Optional character vector of station codes.
#' @param vars `NULL` for all numeric measurements present, or a character
#'   vector such as `c("temp_mean", "prec")`.
#' @param start_date,end_date Optional initial and final date (`Date` or
#'   `YYYY-MM-DD`).
#' @param last_n_days Number of days for the default online interval (30).
#' @param df Optional data.frame as returned by [meteogal2df()].
#' @param file Optional `.csv`, `.rds`, `.rda` input file(s) or directory.
#' @param inventory Optional station metadata as a data.frame (e.g. from
#'   [meteogal2inventory()]) or a `.csv`/`.rds` file. It completes missing
#'   metadata (coordinates, altitude, ...). It is not downloaded automatically.
#' @param output_file Optional `.rds`, `.rda` or `.RData` output path.
#' @param verbose Print status messages.
#' @param control List forwarded to [meteogal2df()] when downloading.
#' @param quality Validation codes whose values are used (default `c(1, 5)`);
#'   see [meteogal2df()] and [meteogal_qc_codes()].
#' @return An `ldata` object (`fda.usc::ldata()`): `df` and the named `fdata`
#'   components, all with identical row order.
#' @seealso [meteogal2fdata()], [meteogal2inventory()], [meteogal_qc_codes()]
#' @references MeteoGalicia daily JSON service documentation:
#'   <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf>.
#' @examples
#' f <- system.file("extdata", "meteogal_small.csv", package = "meteogal2fdata")
#' ld <- meteogal2lfdata(file = f, vars = c("temp_mean", "prec"))
#' names(ld)
#' ld$df[, c("station_id", "year", "n_days", "first_date", "last_date",
#'           "n_temp_mean_valid", "n_temp_mean_missing")]
#' ld$df$qc_temp_mean   # codes per curve (NA: this extract has no codes)
#' ld$df$fecha
#' @export
meteogal2lfdata <- function(station_ids = NULL, vars = NULL,
                             start_date = NULL, end_date = NULL,
                             last_n_days = 30L, df = NULL, file = NULL,
                             inventory = NULL, output_file = NULL,
                             verbose = FALSE, control = list(),
                             quality = c(1L, 5L)) {
  quality <- .meteogal_check_quality(quality)
  dat <- .meteogal_input(df = df, file = file, station_ids = station_ids,
                         start_date = start_date, end_date = end_date,
                         last_n_days = last_n_days, verbose = verbose,
                         control = control, quality = quality)
  vars <- .meteogal_numeric_vars(dat, vars = vars)
  if (!length(vars)) stop("No numeric meteorological variables available.")
  units <- attr(dat, "units")
  idx <- .meteogal_curve_index(dat)
  meta <- .meteogal_curve_metadata(idx, inventory)
  fd_list <- lapply(vars, function(v) .meteogal_build_fdata(idx, v, units, quality))
  names(fd_list) <- vars
  for (v in vars) {
    qcol <- .meteogal_quality_columns(idx, v, quality)
    for (nm in names(qcol)) meta[[nm]] <- qcol[[nm]]
  }
  result <- fda.usc::ldata(df = meta, mfdata = fd_list)
  .meteogal_save_object(result, output_file)
  result
}
