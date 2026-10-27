#' meteogal2fdata: MeteoGalicia observations and functional data
#'
#' Download and read daily observations from the MeteoGalicia automatic
#' station network, keeping the validation code of every measurement, and
#' convert them to `fda.usc::fdata` and `fda.usc::ldata` objects with one
#' 365-point curve per station-year. Only base R, 'jsonlite' (to parse the
#' JSON responses) and 'fda.usc' are used.
#'
#' Workflow: [meteogal2inventory()] (stations) -> [meteogal2download()]
#' (raw station-year files with codes and a provenance manifest) ->
#' [meteogal2df()] (daily data.frame, quality chosen with `quality`) ->
#' [meteogal2fdata()] / [meteogal2lfdata()] (functional data). The codes are
#' described by [meteogal_qc_codes()].
#'
#' @section Data sources and licence:
#'   Data: MeteoGalicia, Xunta de Galicia. The information may be used freely
#'   provided that MeteoGalicia (Xunta de Galicia) is expressly cited as the
#'   source (<https://www.meteogalicia.gal/aviso-legal>).
#'
#'   Documentation used:
#'   * Daily station data (JSON), parameters and validation codes:
#'     <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf>
#'   * Hourly historical station data (JSON), same validation codes:
#'     <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionHorariosHistoricos_es.pdf>
#'   * Station list (JSON):
#'     <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_listaEstacionsMeteo_es.pdf>
#'   * Current state of stations (JSON), station fields and `-9999` = no data:
#'     <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_estado_actual_es.pdf>
#'   * Historical data through the web form (manual alternative):
#'     <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/informes/datos_es.pdf>
#'
#' @docType package
#' @name meteogal2fdata-package
#' @keywords internal
"_PACKAGE"
