# meteogal2fdata

`meteogal2fdata` downloads daily observations from the **MeteoGalicia**
meteorological-station network, preserves the validation code associated with
each measurement, and converts the resulting daily data to functional data
objects (`fdata` and `ldata`) from
[fda.usc](https://cran.r-project.org/package=fda.usc).

The package deliberately keeps the workflow simple: base R `data.frame`
objects are the intermediate representation, measurements are not imputed,
and quality filtering is separated from downloading so that the same raw files
can be reused with different validation criteria.

**Interactive app:** [meteogal2shiny](https://manueloviedo.shinyapps.io/meteogal2shiny/)
(station map, download, validation codes and functional data, no installation
needed) · **Website:** <https://moviedo5.github.io/meteogal2fdata/>

```r
# install.packages("remotes")
remotes::install_github("moviedo5/meteogal2fdata", build_vignettes = TRUE)
```

**Data source:** MeteoGalicia, Xunta de Galicia. Data may be reused according
to the [MeteoGalicia legal notice](https://www.meteogalicia.gal/aviso-legal),
with MeteoGalicia cited as the source.

## Main functions

| Function | Purpose |
| --- | --- |
| `meteogal2inventory()` | Obtain station metadata or reconstruct an inventory from local data |
| `meteogal2download()` | Resumable station-year downloads with raw values, validation codes and provenance |
| `meteogal2df()` | Read daily observations as a base R `data.frame` and choose the validation criterion |
| `meteogal2fdata()` | Convert one variable to one 365-day functional curve per station-year |
| `meteogal2lfdata()` | Convert several variables to an aligned `ldata` object |
| `meteogal_qc_codes()` | Describe the MeteoGalicia validation codes used by the package |

## Validation codes

Each measurement can be accompanied by `lnCodigoValidacion`. The package keeps
that code in `qc_<variable>` and uses English descriptions consistently:

| code | description | default `quality = c(1, 5)` |
| ---: | --- | --- |
| 0 | Not validated | excluded |
| 1 | Valid original | used |
| 2 | Suspect | excluded |
| 3 | Erroneous | always missing |
| 5 | Valid interpolated | used |
| 9 | Not recorded | always missing |

```r
library(meteogal2fdata)
meteogal_qc_codes()
```

Downloads are **not filtered**. Quality is selected when the files are read:

```r
x <- meteogal2df(data_dir = "meteogal_daily")
# default: quality = c(1, 5)

x_recent <- meteogal2df(
  data_dir = "meteogal_daily",
  quality = c(0, 1, 5)
)
```

Values rejected by `quality` become `NA`, but their `qc_` codes remain
available. Codes 3 and 9 and the sentinel value `-9999` are always treated as
missing. The package does not otherwise impute or interpolate missing values.

## Downloading daily observations

The following example compares two stations with a clearer climatic contrast:
Coruña-Torre de Hércules (`10157`) and Ourense (`10148`).

```r
log <- meteogal2download(
  start_date = "2023-01-01",
  end_date = "2024-12-31",
  station_ids = c("10157", "10148"),
  vars = c("temp_mean", "temp_min", "temp_max", "prec"),
  format = "csv",
  out_dir = "meteogal_daily"
)
```

Files are written by station and year. The file
`meteogal_daily/_meteogal_manifest.csv` records their provenance. RDS files
also store provenance in `attr(x, "meteogal_meta")` and units in
`attr(x, "units")`.

## Functional data

`meteogal2fdata()` creates one 365-day curve per station-year for one variable:

```r
fd <- meteogal2fdata(
  file = "meteogal_daily",
  station_id = c("10157", "10148"),
  var = "temp_mean"
)
plot(fd)
```

`meteogal2lfdata()` creates aligned functional variables plus station-year
metadata:

```r
inv <- meteogal2inventory()
ld <- meteogal2lfdata(
  file = "meteogal_daily",
  station_ids = c("10157", "10148"),
  vars = c("temp_mean", "temp_min", "temp_max", "prec"),
  inventory = inv
)

ld$df[, c("station_id", "station_name", "year", "altitude", "lon", "lat",
          "n_temp_mean_valid")]
plot(ld$temp_mean)
```

February 29 is removed from leap years so that March 1 is always day 60.
Missing measurements remain `NA`. The daily validation-code matrices
`qc_<variable>` and the original date matrix `fecha` are retained in
`ldata$df` and remain aligned when the object is subset.

## Spatial exploration

`meteogal2inventory()` returns longitude, latitude and altitude as ordinary
numeric columns, so simple maps require no additional spatial package. The
spatial vignette illustrates:

* the station network coloured by altitude;
* annual mean daily temperature by station, using the selected validation
  criterion and reporting the number of usable days.

The temperature map is a station-level descriptive map, not an interpolated
surface.

## Real reproducible examples

Run:

```r
source("data-raw/build-example.R")
```

to generate the bundled real-data examples from MeteoGalicia. The script
creates:

* `meteogal_example.csv`: Coruña-Torre de Hércules and Ourense, 2023-2024;
* `meteogal_example_inventory.rds`: metadata for those stations;
* `meteogal_inventory.csv`: current station inventory;
* `meteogal_temperature_2024.csv`: annual mean temperature for the spatial
  example.

No observations in these files are simulated.

## Vignettes

* `daily-data-and-quality`: download, CSV/RDS files, validation codes,
  provenance and missing values.
* `spatial-stations`: station inventory, altitude map and temperature map.
* `functional-data`: conversion to `fdata`/`ldata` and integration with
  `fda.usc`.
* `meteogalicia-es`: complete workflow in Spanish, from download and maps to
  functional data.

## Shiny application

The application is online at
<https://manueloviedo.shinyapps.io/meteogal2shiny/>.

The interactive application **meteogal2shiny** (station map, download,
validation codes and functional data) is kept in a separate folder,
`meteogal2fdata_shiny/`, with the same structure as `aemet2shiny` and
`omie2shiny`, so that this package keeps only base R, `jsonlite` and
`fda.usc` as dependencies. See its `README.md` to run it locally or deploy it
to shinyapps.io.

## Sources

* [Daily station data and validation codes](https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf)
* [Historical hourly station data](https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionHorariosHistoricos_es.pdf)
* [Station list](https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_listaEstacionsMeteo_es.pdf)
* [Current station state](https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_estado_actual_es.pdf)
* [Historical data web form](https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/informes/datos_es.pdf)
* [fda.usc](https://cran.r-project.org/package=fda.usc)
