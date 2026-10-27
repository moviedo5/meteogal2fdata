#' @encoding UTF-8
#' @title MeteoGalicia station inventory (data.frame)
#' @description Station identifiers, names, municipality, province, altitude
#'   and geographical coordinates, as a base R data.frame. By default the
#'   station list service of MeteoGalicia is queried
#'   (`listaEstacionsMeteo.action`); alternatively, `data_dir` derives the
#'   inventory from local observations, including stations no longer active.
#' @details The online service lists the stations **currently in service**;
#'   it is not a historical inventory. With `data_dir`, `first_date` and
#'   `last_date` are the first and last dates present in the local data,
#'   not official opening/closing dates. Coordinates are WGS84 decimal
#'   degrees (`lon`, `lat`) and altitude is in metres. Data source:
#'   MeteoGalicia, Xunta de Galicia.
#' @param file `NULL`, or a destination `.rds`, `.rda`/`.RData` or `.csv` path.
#' @param data_dir `NULL` (query the service) or a directory/file of
#'   observations readable by [meteogal2df()].
#' @param verbose Show progress messages.
#' @param timeout Seconds allowed for the online request.
#' @return Invisibly, a data.frame with `station_id`, `station_name`,
#'   `municipality`, `province`, `altitude` (m), `lon`, `lat`, `first_date`
#'   and `last_date`.
#' @references MeteoGalicia station list (JSON):
#'   <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_listaEstacionsMeteo_es.pdf>;
#'   station fields are also described in
#'   <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_estado_actual_es.pdf>.
#' @examples
#' f <- system.file("extdata", "meteogal_small.csv", package = "meteogal2fdata")
#' meteogal2inventory(data_dir = f)
#' \dontrun{
#' inv <- meteogal2inventory(file = "meteogal_inventory.rds")
#' plot(inv$lon, inv$lat, asp = 1, pch = 19)
#' }
#' @seealso [meteogal2df()], [meteogal2lfdata()]
#' @export
meteogal2inventory <- function(file = NULL, data_dir = NULL, verbose = FALSE,
                               timeout = 60) {
  if (is.null(data_dir)) {
    if (verbose) message("[MeteoGalicia] Requesting station list")
    json <- .meteogal_get_json("listaEstacionsMeteo.action", timeout = timeout)
    dat <- .meteogal_parse_stations(json)
  } else {
    # Local files only; no request is made. quality = NULL: metadata only.
    dat <- suppressMessages(meteogal2df(data_dir = data_dir, verbose = verbose,
                                        vars = character(), quality = NULL))
  }
  if (!nrow(dat) || !"station_id" %in% names(dat)) {
    stop("No stations found in the selected source.")
  }
  dat <- dat[!is.na(dat$station_id) & nzchar(dat$station_id), , drop = FALSE]
  if (!nrow(dat)) stop("No valid station identifiers found.")

  if ("fecha" %in% names(dat)) {
    dat <- dat[order(dat$station_id, dat$fecha, na.last = TRUE), , drop = FALSE]
  }
  # Latest available metadata record for each station.
  keep <- !duplicated(dat$station_id, fromLast = TRUE)
  fixed <- c("station_id", "station_name", "municipality", "province",
             "altitude", "lon", "lat")
  out <- dat[keep, intersect(fixed, names(dat)), drop = FALSE]
  for (nm in setdiff(fixed, names(out))) out[[nm]] <- NA
  out <- out[, fixed, drop = FALSE]
  for (nm in c("station_id", "station_name", "municipality", "province")) {
    out[[nm]] <- as.character(out[[nm]])
  }
  for (nm in c("altitude", "lon", "lat")) out[[nm]] <- suppressWarnings(as.numeric(out[[nm]]))

  out$first_date <- as.Date(rep(NA_character_, nrow(out)))
  out$last_date <- as.Date(rep(NA_character_, nrow(out)))
  if (!is.null(data_dir) && "fecha" %in% names(dat)) {
    rng <- tapply(as.numeric(dat$fecha), dat$station_id, function(z) {
      z <- z[!is.na(z)]
      if (length(z)) c(min(z), max(z)) else c(NA_real_, NA_real_)
    }, simplify = FALSE)
    rng <- do.call(rbind, rng)
    k <- match(out$station_id, rownames(rng))
    out$first_date <- as.Date(rng[k, 1L], origin = "1970-01-01")
    out$last_date <- as.Date(rng[k, 2L], origin = "1970-01-01")
  }
  out <- out[order(out$station_id), , drop = FALSE]
  rownames(out) <- NULL
  .meteogal_write(out, file)
  if (verbose) message("[MeteoGalicia] ", nrow(out), " stations")
  invisible(out)
}

# listaEstacionsMeteo: one object per station with idEstacion, estacion,
# concello, provincia, altitude, lat, lon (and utmx, utmy).
.meteogal_parse_stations <- function(json) {
  if (!is.list(json)) stop("Unexpected station list JSON.")
  st <- json[["listaEstacionsMeteo"]]
  if (is.null(st)) {
    # Fall back to the first list of objects with idEstacion.
    cand <- Filter(function(z) is.list(z) && length(z) &&
                     is.list(z[[1L]]) && "idEstacion" %in% names(z[[1L]]), json)
    if (!length(cand)) stop("Unexpected station list JSON: no listaEstacionsMeteo.")
    st <- cand[[1L]]
  }
  if (!is.null(names(st)) && "idEstacion" %in% names(st)) st <- list(st)
  if (!length(st)) return(data.frame())
  get <- function(field) vapply(st, function(s) .mg_scalar(s[[field]]), character(1))
  out <- data.frame(station_id = get("idEstacion"), station_name = get("estacion"),
                    municipality = get("concello"), province = get("provincia"),
                    altitude = suppressWarnings(as.numeric(get("altitude"))),
                    lon = suppressWarnings(as.numeric(get("lon"))),
                    lat = suppressWarnings(as.numeric(get("lat"))),
                    stringsAsFactors = FALSE)
  out$altitude[!is.na(out$altitude) & out$altitude == -9999] <- NA_real_
  out
}
