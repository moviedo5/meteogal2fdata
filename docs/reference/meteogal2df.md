# MeteoGalicia daily observations as a base R data.frame

Download daily observations from MeteoGalicia, or read previously
downloaded files, returning a plain `data.frame` (no `sf` geometry, no
`units` classes). Every measurement keeps its MeteoGalicia validation
code in a `qc_<variable>` column.

## Usage

``` r
meteogal2df(
  station_ids = NULL,
  start_date = NULL,
  end_date = NULL,
  last_n_days = 30L,
  vars = NULL,
  file = NULL,
  data_dir = NULL,
  verbose = FALSE,
  control = list(),
  quality = c(1L, 5L)
)
```

## Arguments

- station_ids:

  `NULL` for all stations or a character vector of IDs.

- start_date, end_date:

  Optional `Date` or `"YYYY-MM-DD"`. Online, the default is the last
  `last_n_days` days. With `data_dir`, `NULL` means unbounded.

- last_n_days:

  Number of days used if no `start_date` is given online.

- vars:

  `NULL` to keep all measurements, or a character vector of variable
  names (e.g. `c("temp_mean", "prec")`) or native parameter codes (e.g.
  `"TA_AVG_1.5m"`). Online, they are requested with `idParam`. The
  station/date fields and the matching `qc_` columns are always kept.

- file:

  Optional output file (`.rds`, `.rda`/`.RData` or `.csv`). The saved
  file contains the **unfiltered** values and codes; `quality` only
  affects the returned data.frame.

- data_dir:

  `NULL` for online data, or a local directory or a single
  `.rds`/`.rda`/`.csv` file.

- verbose:

  Show progress messages.

- control:

  List with `max_attempts` (3), `retry_wait` (15 seconds), `sleep_pause`
  (1 second), `window_days` (`NULL` = calendar months) and `timeout` (60
  seconds).

- quality:

  Validation codes whose values are used (default `c(1, 5)`); any of 0,
  1, 2, 5. `NULL` uses all values except codes 3 and 9.

## Value

A data.frame with `fecha` (Date), `station_id` (character), station
metadata (`station_name`, `municipality`, `province`, `altitude`, `lon`,
`lat` when available), `timestamp`, the measurements and their `qc_`
columns. Attributes: `quality` (codes used) and `units`.

## Details

**Online requests** use the documented daily JSON service
(`datosDiariosEstacionsMeteo.action`) in calendar-month windows. For
each measurement the service returns the value (`valor`), its validation
code (`lnCodigoValidacion`) and its unit (`unidade`); the value goes to
`<variable>`, the code to `qc_<variable>` and the units to
`attr(x, "units")`. Values are never converted or imputed.

**Validation codes** (see
[`meteogal_qc_codes()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal_qc_codes.md)):
0 not validated, 1 valid original, 2 suspect, 3 erroneous, 5 valid
interpolated, 9 not recorded. `quality` lists the codes whose values are
returned; the rest are set to `NA` and a message reports how many values
were affected and with which code. The codes always remain in the `qc_`
columns, so the decision can be inspected or changed later. The default
`quality = c(1, 5)` keeps validated values only: recent data, not yet
validated by MeteoGalicia (code 0), will therefore be `NA` unless
`quality = c(0, 1, 5)` (or `NULL`) is used. Codes 3 and 9 and the value
`-9999` are always `NA`. For comparison, 'meteospain' (0.3.1) removes
values with codes 0, 3 and 9 and discards the codes (it keeps suspect
values, code 2).

**Missing data**: a day absent from the service response is absent from
the returned data.frame (no row is invented); a value that is `NA`,
`-9999`, or has code 3 or 9 is `NA`. February 29 is kept here; it is
only removed in the functional representation.

**Local files** (`data_dir`): station-year files written by
[`meteogal2download()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2download.md)
(`.rds` or `.csv`, with codes), files saved with
`meteogal2df(file = ...)`, or any `.csv`/`.rds`/`.rda` data.frame with
`fecha`, `station_id` and the variables. Data without `qc_` columns are
accepted: their validation status is unknown and their values are not
modified (except `-9999`). With `data_dir` and no dates, everything
available is read; online, the default is the last `last_n_days` days.

## References

MeteoGalicia, daily JSON service (parameters, structure and validation
codes):
<https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf>.

MeteoGalicia, historical data through the web form (manual query of the
same network, not used by this package):
<https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/informes/datos_es.pdf>.

Legal notice (attribution required):
<https://www.meteogalicia.gal/aviso-legal>.

## See also

[`meteogal2download()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2download.md),
[`meteogal2inventory()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2inventory.md),
[`meteogal_qc_codes()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal_qc_codes.md)

## Examples

``` r
f <- system.file("extdata", "meteogal_small.csv", package = "meteogal2fdata")
x <- meteogal2df(data_dir = f, vars = c("temp_mean", "prec"))
head(x)
#>        fecha station_id             station_name province altitude       lon
#> 1 2024-01-01      10157 Coruña-Torre de Hércules A Coruña       21 -8.409202
#> 2 2024-01-02      10157 Coruña-Torre de Hércules A Coruña       21 -8.409202
#> 3 2024-01-03      10157 Coruña-Torre de Hércules A Coruña       21 -8.409202
#> 4 2024-01-04      10157 Coruña-Torre de Hércules A Coruña       21 -8.409202
#> 5 2024-01-05      10157 Coruña-Torre de Hércules A Coruña       21 -8.409202
#> 6 2024-01-06      10157 Coruña-Torre de Hércules A Coruña       21 -8.409202
#>        lat temp_mean prec
#> 1 43.38276     12.59  0.0
#> 2 43.38276     15.10 10.6
#> 3 43.38276     14.04  0.0
#> 4 43.38276     12.52 16.4
#> 5 43.38276     11.49  4.1
#> 6 43.38276      9.90  0.5
if (FALSE) { # \dontrun{
# Online: last 30 days, also using values not yet validated (code 0)
x <- meteogal2df(station_ids = "10157", vars = c("temp_mean", "prec"),
                 quality = c(0, 1, 5))
table(x$qc_temp_mean, useNA = "ifany")
} # }
```
