# Base R access to the MeteoGalicia JSON services (no httr/curl packages).
#
# Official documentation:
# - Daily data:   https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf
# - Station list: https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_listaEstacionsMeteo_es.pdf
#   (fields also described in JSON_estado_actual_es.pdf)

.meteogal_base_url <- function() "https://servizos.meteogalicia.gal/mgrss/observacion/"

.meteogal_build_url <- function(service, query = NULL) {
  url <- paste0(.meteogal_base_url(), service)
  if (length(query)) {
    enc <- vapply(query, utils::URLencode, character(1), reserved = TRUE)
    url <- paste0(url, "?", paste(paste0(names(query), "=", enc), collapse = "&"))
  }
  url
}

# Download one JSON document and parse it with jsonlite (no simplification,
# so the nested structure is handled explicitly and predictably).
.meteogal_get_json <- function(service, query = NULL, timeout = 60) {
  url <- .meteogal_build_url(service, query)
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  old <- options(timeout = max(getOption("timeout", 60), timeout))
  on.exit(options(old), add = TRUE)
  status <- suppressWarnings(utils::download.file(url, tmp, quiet = TRUE,
                                                 mode = "wb", method = "libcurl"))
  if (!is.numeric(status) || length(status) != 1L || status != 0 ||
      !file.exists(tmp) || file.size(tmp) == 0) {
    stop("MeteoGalicia request failed: ", url, call. = FALSE)
  }
  jsonlite::fromJSON(tmp, simplifyVector = FALSE)
}

# NULL / empty / list-valued JSON fields become NA_character_.
.mg_scalar <- function(x) {
  if (is.null(x) || !length(x) || is.list(x) || is.na(x[[1L]])) return(NA_character_)
  as.character(x[[1L]])
}

# A JSON array with a single element may arrive as one object: normalise.
.mg_nested <- function(x, name, field) {
  y <- x[[name]]
  if (is.null(y) || !length(y)) return(list())
  if (!is.null(names(y)) && field %in% names(y)) return(list(y))
  y
}

.meteogal_version <- function() {
  as.character(tryCatch(utils::packageVersion("meteogal2fdata"),
                        error = function(e) "dev"))
}
