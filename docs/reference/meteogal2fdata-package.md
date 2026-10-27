# meteogal2fdata: MeteoGalicia observations and functional data

Download and read daily observations from the MeteoGalicia automatic
station network, keeping the validation code of every measurement, and
convert them to
[`fda.usc::fdata`](https://moviedo5.github.io/fda.usc/reference/fdata.html)
and
[`fda.usc::ldata`](https://moviedo5.github.io/fda.usc/reference/ldata.html)
objects with one 365-point curve per station-year. Only base R,
'jsonlite' (to parse the JSON responses) and 'fda.usc' are used.

## Details

Workflow:
[`meteogal2inventory()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2inventory.md)
(stations) -\>
[`meteogal2download()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2download.md)
(raw station-year files with codes and a provenance manifest) -\>
[`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md)
(daily data.frame, quality chosen with `quality`) -\>
[`meteogal2fdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2fdata.md)
/
[`meteogal2lfdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2lfdata.md)
(functional data). The codes are described by
[`meteogal_qc_codes()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal_qc_codes.md).

## Data sources and licence

Data: MeteoGalicia, Xunta de Galicia. The information may be used freely
provided that MeteoGalicia (Xunta de Galicia) is expressly cited as the
source (<https://www.meteogalicia.gal/aviso-legal>).

Documentation used:

- Daily station data (JSON), parameters and validation codes:
  <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf>

- Hourly historical station data (JSON), same validation codes:
  <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionHorariosHistoricos_es.pdf>

- Station list (JSON):
  <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_listaEstacionsMeteo_es.pdf>

- Current state of stations (JSON), station fields and `-9999` = no
  data:
  <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_estado_actual_es.pdf>

- Historical data through the web form (manual alternative):
  <https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/informes/datos_es.pdf>

## See also

Useful links:

- <https://moviedo5.github.io/meteogal2fdata/>

- <https://github.com/moviedo5/meteogal2fdata>

- <https://manueloviedo.shinyapps.io/meteogal2shiny/>

- Report bugs at <https://github.com/moviedo5/meteogal2fdata/issues>

## Author

**Maintainer**: Manuel Oviedo de la Fuente <manuel.oviedo@udc.es>
([ORCID](https://orcid.org/0000-0001-7360-3249))

Authors:

- Manuel Oviedo de la Fuente <manuel.oviedo@udc.es>
  ([ORCID](https://orcid.org/0000-0001-7360-3249))
