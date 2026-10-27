#' @title Convert MeteoGalicia daily observations to functional data
#' @description Construct an `fda.usc::fdata` object from one numeric
#'   meteorological variable, with one curve per station-year.
#' @details Each curve has 365 common evaluation points (`argvals = 1:365`).
#'   February 29 is removed, and subsequent dates in leap years are shifted
#'   so that position 60 always represents March 1. Days without a record,
#'   and values not admitted by `quality`, are `NA`; nothing is imputed.
#'   Different stations and years are never combined in the same curve.
#'
#'   Supply either `df` (for example, from [meteogal2df()]), `file`
#'   (a `.rda`, `.rds`, `.csv`, or a directory), or neither to query
#'   MeteoGalicia online. `output_file` saves the result.
#'
#'   **Per-curve information** is attached as attributes whose row names are
#'   the curve names (`station_year`): `quality_summary` (counts per curve:
#'   original, interpolated, suspect, unvalidated, erroneous, not registered,
#'   unknown, valid, interp, masked, missing), `qc` (365-column matrix of
#'   validation codes) and `fecha` (365-column matrix with the date of every
#'   record). fda.usc subsetting (`fd[i]`) does **not** subset attributes, so
#'   after subsetting use `attr(fd, "qc")[rownames(fd$data), ]`. For analyses
#'   that need this metadata, [meteogal2lfdata()] is preferable: it keeps it
#'   in `ldata$df`, which is subset together with the curves.
#'
#'   Source: MeteoGalicia, Xunta de Galicia.
#' @param station_id Optional station code(s); used to filter local data or
#'   to select stations for online requests.
#' @param var A single numeric variable, e.g. `"temp_mean"` or `"prec"`.
#' @param start_date,end_date Optional initial and final date (`YYYY-MM-DD`
#'   or `Date`). For online requests, omitted dates default to the last 30 days.
#' @param last_n_days Positive integer, for the default online interval.
#' @param df Optional data.frame of daily observations.
#' @param file Optional input file(s) or directory (outputs of
#'   [meteogal2download()], or files saved with `meteogal2df(file = ...)`).
#' @param output_file Optional `.rds`, `.rda` or `.RData` output path.
#' @param verbose Print download or reading messages.
#' @param control List of options passed to [meteogal2df()] for online data.
#' @param quality Validation codes whose values are used (default `c(1, 5)`);
#'   see [meteogal2df()] and [meteogal_qc_codes()]. Values without a code
#'   (data without codes) are kept.
#' @return An `fdata` object with one row per station-year (row names
#'   `station_year`), 365 columns, and attributes `quality_summary`, `qc`,
#'   `fecha`, `quality_codes`, `var_name`, `var_units` and `source`.
#' @seealso [meteogal2lfdata()], [meteogal2df()], [meteogal_qc_codes()]
#' @references MeteoGalicia daily JSON service documentation:
#'   <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf>.
#' @examples
#' d <- data.frame(fecha = as.Date(c("2024-02-28", "2024-02-29", "2024-03-01")),
#'                 station_id = "10157", temp_mean = c(11, 12, 13),
#'                 qc_temp_mean = c(1L, 1L, 2L))
#' fd <- meteogal2fdata(var = "temp_mean", df = d)
#' dim(fd$data)
#' fd$data[1, 59:60]       # 11 (Feb 28), NA (Mar 1 is suspect, code 2)
#' attr(fd, "qc")[1, 59:60]
#' attr(fd, "quality_summary")
#' @export
meteogal2fdata <- function(station_id = NULL, var,
                            start_date = NULL, end_date = NULL,
                            last_n_days = 30L, df = NULL, file = NULL,
                            output_file = NULL, verbose = FALSE,
                            control = list(), quality = c(1L, 5L)) {
  if (missing(var) || !is.character(var) || length(var) != 1L ||
      is.na(var) || !nzchar(var)) stop("'var' must be one variable name.")
  quality <- .meteogal_check_quality(quality)
  dat <- .meteogal_input(df = df, file = file, station_ids = station_id,
                         start_date = start_date, end_date = end_date,
                         last_n_days = last_n_days, verbose = verbose,
                         control = control, quality = quality)
  .meteogal_numeric_vars(dat, vars = var)
  idx <- .meteogal_curve_index(dat)
  fd <- .meteogal_build_fdata(idx, var, attr(dat, "units"), quality)
  qcol <- .meteogal_quality_columns(idx, var, quality)
  attr(fd, "quality_summary") <- .meteogal_quality_summary(idx, var, quality)
  attr(fd, "qc") <- as.matrix(qcol[[paste0("qc_", var)]])
  attr(fd, "fecha") <- .meteogal_grid(idx, format(idx$data$fecha), NA_character_)
  .meteogal_save_object(fd, output_file)
  fd
}
