# Validation codes, parameters, JSON parsing and quality filtering (base R).
# Official daily JSON specification (lnCodigoValidacion, codigoParametro):
# https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf

#' MeteoGalicia validation codes
#'
#' Table of the validation codes (`lnCodigoValidacion`) that MeteoGalicia
#' attaches to every measurement in its daily and hourly JSON services,
#' together with the way these codes are treated by the package.
#'
#' @details Each measurement `<variable>` can be accompanied by an integer
#'   column `qc_<variable>`. The `quality` argument of [meteogal2df()],
#'   [meteogal2fdata()] and [meteogal2lfdata()] specifies which codes are
#'   admitted. Values with other codes are set to `NA` in the returned
#'   object, while the original codes are retained.
#'
#'   Codes 3 (erroneous) and 9 (not recorded) are never used. A missing
#'   validation code means that its status is unknown; such observations are
#'   retained and counted as having unknown validation status.
#'
#'   The sentinel value `-9999`, documented by MeteoGalicia as representing
#'   no data, is always treated as missing.
#'
#' @return A data.frame with columns `code`, `description`, `default`
#'   (`TRUE` when admitted by the default `quality = c(1, 5)`) and `usable`
#'   (`FALSE` for codes that can never be admitted).
#' @references
#'   MeteoGalicia. Daily meteorological-station data (JSON):
#'   <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf>.
#'
#'   MeteoGalicia. Historical hourly station data (JSON), same validation
#'   codes:
#'   <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionHorariosHistoricos_es.pdf>.
#'
#'   MeteoGalicia. Current station state (JSON), `-9999` = no data:
#'   <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_estado_actual_es.pdf>.
#' @examples
#' meteogal_qc_codes()
#' @export
meteogal_qc_codes <- function() {
  data.frame(
    code = c(0L, 1L, 2L, 3L, 5L, 9L),
    description = c(
      "Not validated",
      "Valid original",
      "Suspect",
      "Erroneous",
      "Valid interpolated",
      "Not recorded"
    ),
    default = c(FALSE, TRUE, FALSE, FALSE, TRUE, FALSE),
    usable = c(TRUE, TRUE, TRUE, FALSE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
}

# Codes that can be requested in `quality`; 3 and 9 never.
.meteogal_usable_codes <- function() c(0L, 1L, 2L, 5L)

.meteogal_check_quality <- function(quality) {
  if (is.null(quality)) return(NULL)
  if (!is.numeric(quality) || !length(quality) || anyNA(quality) ||
      any(!quality %in% .meteogal_usable_codes())) {
    stop("'quality' must be NULL or a vector of codes from 0, 1, 2, 5 ",
         "(3 = erroneous and 9 = not recorded are always NA). ",
         "See meteogal_qc_codes().", call. = FALSE)
  }
  sort(unique(as.integer(quality)))
}

# Daily parameter codes (codigoParametro = abbreviation_function_height),
# as returned by the daily JSON service, and the column names used here.
.meteogal_parameter_names <- function() {
  c("TA_AVG_1.5m" = "temp_mean", "TA_MIN_1.5m" = "temp_min",
    "TA_MAX_1.5m" = "temp_max", "TS_AVG_-0.1m" = "soil_temp_mean",
    "HR_AVG_1.5m" = "hum_mean", "HR_MIN_1.5m" = "hum_min",
    "HR_MAX_1.5m" = "hum_max", "PP_SUM_1.5m" = "prec",
    "ET0_SUM_1.5m" = "reference_evapotranspiration",
    "DVP_MODA_2m" = "wind_dir", "VV_AVG_2m" = "wind_speed",
    "VV_MAX_2m" = "max_wind_speed", "DV_CONDICION_2m" = "max_wind_direction",
    "HSOL_SUM_1.5m" = "insolation", "IUVX_MAX_1.5m" = "uv_radiation_index",
    "INS_RATIO_1.5m" = "insolation_ratio",
    "IRD_SUM_1.5m" = "global_solar_irradiation",
    "PR_AVG_1.5m" = "mean_atmospheric_pressure",
    "PRED_AVG_1.5m" = "atmospheric_pressure_reduced",
    "HS_CV_AVG_-0.2m" = "soil_moisture")
}

# Fallback units (no conversion is ever applied). Units reported by the
# service in `unidade` take precedence when available (attribute "units").
.meteogal_default_units <- function() {
  c(temp_mean = "\u00b0C", temp_min = "\u00b0C", temp_max = "\u00b0C",
    soil_temp_mean = "\u00b0C", hum_mean = "%", hum_min = "%", hum_max = "%",
    prec = "L/m2", reference_evapotranspiration = "L/m2",
    wind_dir = "\u00b0", max_wind_direction = "\u00b0",
    wind_speed = "m/s", max_wind_speed = "m/s", insolation = "h",
    insolation_ratio = "%", mean_atmospheric_pressure = "hPa",
    atmospheric_pressure_reduced = "hPa")
}

.meteogal_api_params <- function(vars) {
  if (is.null(vars)) return(NULL)
  if (!is.character(vars) || !length(vars) || anyNA(vars) || any(!nzchar(vars))) {
    stop("'vars' must be a nonempty character vector.")
  }
  codes <- .meteogal_parameter_names()
  result <- vapply(vars, function(v) {
    if (v %in% names(codes)) return(v)
    found <- names(codes)[codes == v]
    if (length(found)) return(found[1L])
    if (grepl("^[A-Z][A-Z0-9]*_[A-Z][A-Z0-9]*_-?[0-9.]+m$", v)) return(v)
    stop("Unknown API parameter/variable: ", v,
         ". Supply the native MeteoGalicia 'codigoParametro' if necessary.")
  }, character(1))
  unique(unname(result))
}

.meteogal_cache_tag <- function(params) {
  if (is.null(params)) return("all")
  f <- tempfile("mg-params-")
  on.exit(unlink(f))
  writeLines(paste(sort(params), collapse = ","), f, useBytes = TRUE)
  paste0("p", unname(tools::md5sum(f)))
}

.meteogal_json_request <- function(start, end, station_ids, params, timeout) {
  query <- c(dataIni = format(start, "%d/%m/%Y"),
             dataFin = format(end, "%d/%m/%Y"))
  if (!is.null(station_ids)) query <- c(query, idEst = paste(station_ids, collapse = ","))
  if (!is.null(params)) query <- c(query, idParam = paste(params, collapse = ","))
  json <- .meteogal_get_json("datosDiariosEstacionsMeteo.action", query, timeout)
  .meteogal_parse_json(json)
}

# Parse the daily JSON (listDatosDiarios > listaEstacions > listaMedidas).
# Every measurement gives two columns: <variable> (valor) and
# qc_<variable> (lnCodigoValidacion). Units (unidade) are kept in attr "units".
.meteogal_parse_json <- function(json) {
  if (!is.list(json) || !"listDatosDiarios" %in% names(json)) {
    stop("Unexpected daily JSON: missing listDatosDiarios; response not cached.")
  }
  days <- json$listDatosDiarios
  if (is.null(days) || !length(days)) return(data.frame())
  if (!is.null(names(days)) && "data" %in% names(days)) days <- list(days)
  names_map <- .meteogal_parameter_names()
  rows <- list()
  units <- character()
  for (day in days) {
    ds <- .mg_scalar(day$data)
    date <- substr(ds, 1L, 10L)
    if (is.na(date) || is.na(suppressWarnings(as.Date(date)))) {
      stop("Unexpected or missing daily date in MeteoGalicia JSON.")
    }
    for (st in .mg_nested(day, "listaEstacions", "idEstacion")) {
      sid <- .mg_scalar(st$idEstacion)
      if (is.na(sid) || !nzchar(sid)) next
      lon <- suppressWarnings(as.numeric(.mg_scalar(st$utmx)))
      lat <- suppressWarnings(as.numeric(.mg_scalar(st$utmy)))
      # utmx/utmy are documented as longitude/latitude; if projected values
      # are ever returned they must not be mislabelled as degrees.
      if (is.na(lon) || lon < -11 || lon > -6) lon <- NA_real_
      if (is.na(lat) || lat < 41 || lat > 45) lat <- NA_real_
      row <- list(fecha = date, station_id = sid,
                  station_name = .mg_scalar(st$estacion),
                  municipality = .mg_scalar(st$concello),
                  province = .mg_scalar(st$provincia), altitude = NA_character_,
                  lon = as.character(lon), lat = as.character(lat),
                  service = "meteogalicia")
      for (measure in .mg_nested(st, "listaMedidas", "codigoParametro")) {
        code <- .mg_scalar(measure$codigoParametro)
        if (is.na(code) || !nzchar(code)) next
        vname <- if (code %in% names(names_map)) unname(names_map[[code]]) else code
        qname <- paste0("qc_", vname)
        # Duplicated parameters can occur: keep the first one, as meteospain.
        if (!is.null(row[[qname]])) next
        row[[vname]] <- .mg_scalar(measure$valor)
        row[[qname]] <- .mg_scalar(measure$lnCodigoValidacion)
        u <- .mg_scalar(measure$unidade)
        if (!is.na(u) && nzchar(u) && !vname %in% names(units)) units[vname] <- u
      }
      rows[[length(rows) + 1L]] <- row
    }
  }
  if (!length(rows)) return(data.frame())
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  out <- lapply(cols, function(nm) vapply(rows, function(r) {
    z <- r[[nm]]
    if (is.null(z) || !length(z)) NA_character_ else as.character(z)
  }, character(1)))
  names(out) <- cols
  out <- as.data.frame(out, check.names = FALSE, stringsAsFactors = FALSE)
  out$fecha <- as.Date(out$fecha)
  out$timestamp <- as.POSIXct(format(out$fecha), tz = "UTC")
  for (nm in intersect(c("altitude", "lon", "lat"), names(out))) {
    out[[nm]] <- suppressWarnings(as.numeric(out[[nm]]))
  }
  qc <- grep("^qc_", names(out), value = TRUE)
  for (nm in qc) out[[nm]] <- suppressWarnings(as.integer(out[[nm]]))
  measures <- setdiff(names(out), c(.meteogal_meta_cols(), qc))
  for (nm in measures) out[[nm]] <- suppressWarnings(as.numeric(out[[nm]]))
  attr(out, "units") <- units
  .meteogal_clean(out)
}

# Non-measurement columns of a daily data frame.
.meteogal_meta_cols <- function() {
  c("fecha", "station_id", "station_name", "municipality", "province",
    "altitude", "lon", "lat", "timestamp", "service", "year")
}

# Mask values not admitted by `quality` (codes kept); codes 3 and 9 and the
# sentinel -9999 always become NA. With `inform = TRUE` a message summarises
# how many available values were set to NA, by code.
.meteogal_apply_quality <- function(x, quality = c(1L, 5L), inform = FALSE) {
  quality <- .meteogal_check_quality(quality)
  qc_cols <- grep("^qc_", names(x), value = TRUE)
  masked <- integer()
  for (nm in qc_cols) {
    var <- substring(nm, 4L)
    if (!var %in% names(x) || !is.numeric(x[[var]])) next
    qc <- x[[nm]]
    discard <- !is.na(qc) & (qc %in% c(3L, 9L) |
               (!is.null(quality) & !qc %in% quality))
    hit <- discard & !is.na(x[[var]])
    if (any(hit)) {
      tab <- table(qc[hit])
      masked[names(tab)] <- ifelse(is.na(masked[names(tab)]), 0L,
                                   masked[names(tab)]) + as.integer(tab)
    }
    x[[var]][discard] <- NA_real_
  }
  n_sentinel <- 0L
  variables <- setdiff(names(x)[vapply(x, is.numeric, logical(1))],
                       c(.meteogal_meta_cols(), qc_cols))
  for (var in variables) {
    bad <- !is.na(x[[var]]) & x[[var]] == -9999
    n_sentinel <- n_sentinel + sum(bad)
    x[[var]][bad] <- NA_real_
  }
  if (inform && (length(masked) || n_sentinel)) {
    msg <- character()
    if (length(masked)) {
      masked <- masked[order(as.integer(names(masked)))]
      lab <- meteogal_qc_codes()
      lab <- lab$description[match(as.integer(names(masked)), lab$code)]
      lab[is.na(lab)] <- "undocumented code"
      msg <- paste0(masked, " with code ", names(masked), " (", lab, ")")
    }
    if (n_sentinel) msg <- c(msg, paste0(n_sentinel, " equal to -9999 (no data)"))
    message("[MeteoGalicia] quality = ",
            if (is.null(quality)) "NULL" else paste0("c(", paste(quality, collapse = ", "), ")"),
            ": values set to NA: ", paste(msg, collapse = "; "),
            ". Codes are kept in the qc_ columns; see meteogal_qc_codes().")
  }
  attr(x, "quality") <- if (is.null(quality)) "all except 3 and 9" else quality
  x
}

# Per station-year counts for one variable. `idx$data` holds values AFTER
# the quality filter and the original codes.
.meteogal_quality_summary <- function(idx, var, quality = c(1L, 5L)) {
  n <- length(idx$keys)
  qc_nm <- paste0("qc_", var)
  qc <- if (qc_nm %in% names(idx$data)) idx$data[[qc_nm]] else rep(NA_integer_, nrow(idx$data))
  val <- idx$data[[var]]
  count <- function(test) tabulate(idx$row[which(test %in% TRUE)], nbins = n)
  admitted <- if (is.null(quality)) .meteogal_usable_codes() else quality
  tab <- data.frame(n_original = count(!is.na(qc) & qc == 1L),
                    n_interpolated = count(!is.na(qc) & qc == 5L),
                    n_suspect = count(!is.na(qc) & qc == 2L),
                    n_unvalidated = count(!is.na(qc) & qc == 0L),
                    n_erroneous = count(!is.na(qc) & qc == 3L),
                    n_not_registered = count(!is.na(qc) & qc == 9L),
                    n_unknown = count(is.na(qc) & !is.na(val)),
                    n_valid = count(!is.na(val)),
                    n_interp = count(!is.na(val) & !is.na(qc) & qc == 5L),
                    n_masked = count(!is.na(qc) & qc != 9L & !qc %in% admitted))
  tab$n_missing <- 365L - tab$n_valid
  rownames(tab) <- idx$keys
  tab
}

# Update only measurements present in the new download on overlapping days;
# preserve previously downloaded variables not requested this time.
.meteogal_merge_station <- function(old, new) {
  if (!nrow(old)) return(new)
  if (!nrow(new)) return(old)
  old <- .meteogal_clean(old)
  new <- .meteogal_clean(new)
  new_cols <- names(new)
  for (nm in setdiff(new_cols, names(old))) old[[nm]] <- NA
  for (nm in setdiff(names(old), names(new))) new[[nm]] <- NA
  new <- new[, names(old), drop = FALSE]
  old_key <- paste(old$station_id, old$fecha)
  new_key <- paste(new$station_id, new$fecha)
  m <- match(new_key, old_key)
  overlap <- which(!is.na(m))
  if (length(overlap)) {
    for (col in new_cols) old[[col]][m[overlap]] <- new[[col]][overlap]
  }
  fresh <- which(is.na(m))
  if (length(fresh)) old <- rbind(old, new[fresh, , drop = FALSE])
  old <- old[order(old$station_id, old$fecha), , drop = FALSE]
  rownames(old) <- NULL
  old
}
