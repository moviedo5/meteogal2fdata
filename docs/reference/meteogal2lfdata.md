# Convert MeteoGalicia daily observations to an ldata object

Create an
[`fda.usc::ldata`](https://moviedo5.github.io/fda.usc/reference/ldata.html)
object: a metadata data.frame `df` with one row per station-year, and
one `fdata` element per variable.

## Usage

``` r
meteogal2lfdata(
  station_ids = NULL,
  vars = NULL,
  start_date = NULL,
  end_date = NULL,
  last_n_days = 30L,
  df = NULL,
  file = NULL,
  inventory = NULL,
  output_file = NULL,
  verbose = FALSE,
  control = list(),
  quality = c(1L, 5L)
)
```

## Arguments

- station_ids:

  Optional character vector of station codes.

- vars:

  `NULL` for all numeric measurements present, or a character vector
  such as `c("temp_mean", "prec")`.

- start_date, end_date:

  Optional initial and final date (`Date` or `YYYY-MM-DD`).

- last_n_days:

  Number of days for the default online interval (30).

- df:

  Optional data.frame as returned by
  [`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md).

- file:

  Optional `.csv`, `.rds`, `.rda` input file(s) or directory.

- inventory:

  Optional station metadata as a data.frame (e.g. from
  [`meteogal2inventory()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2inventory.md))
  or a `.csv`/`.rds` file. It completes missing metadata (coordinates,
  altitude, ...). It is not downloaded automatically.

- output_file:

  Optional `.rds`, `.rda` or `.RData` output path.

- verbose:

  Print status messages.

- control:

  List forwarded to
  [`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md)
  when downloading.

- quality:

  Validation codes whose values are used (default `c(1, 5)`); see
  [`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md)
  and
  [`meteogal_qc_codes()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal_qc_codes.md).

## Value

An `ldata` object
([`fda.usc::ldata()`](https://moviedo5.github.io/fda.usc/reference/ldata.html)):
`df` and the named `fdata` components, all with identical row order.

## Details

All curves use `argvals = 1:365`: February 29 is removed and day 60 is
always March 1. Days without a record and values not admitted by
`quality` are `NA` (never imputed). Row names (`station_year`) are
shared by `df` and every `fdata` element.

**Columns of `ldata$df`**

- Station: `station_id`, `station_name`, `municipality`, `province`,
  `altitude` (m), `lon`, `lat` (completed from `inventory` if given).

- Curve: `year`, `n_days` (calendar dates with a record, after removing
  February 29, whatever the variable), `first_date`, `last_date`, and
  `fecha`: a 365-column matrix with the date of each record (`NA` = no
  record that day).

- For each variable `v`: `n_v_valid` (days with a value used in the
  curve), `n_v_interp` (of these, interpolated by MeteoGalicia, code 5),
  `n_v_masked` (days whose value was set to `NA` because its code is not
  in `quality`, e.g. 0, 2 or 3), `n_v_missing` (`365 - n_v_valid`), and
  `qc_v`: a 365-column matrix with the validation code of each day (`NA`
  = no code: day absent, or data without codes).

The matrices have class `mg_daymat` (see
[mg_daymat](https://moviedo5.github.io/meteogal2fdata/reference/mg_daymat.md)):
they print as one summary per curve and are subset with the rows, so
`subset(ld, ld$df$n_temp_mean_valid >= 330)` keeps curves, metadata,
codes and dates aligned. Use `unclass(ld$df$qc_temp_mean)` for the plain
matrix. Source: MeteoGalicia, Xunta de Galicia.

## References

MeteoGalicia daily JSON service documentation:
<https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf>.

## See also

[`meteogal2fdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2fdata.md),
[`meteogal2inventory()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2inventory.md),
[`meteogal_qc_codes()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal_qc_codes.md)

## Examples

``` r
f <- system.file("extdata", "meteogal_small.csv", package = "meteogal2fdata")
ld <- meteogal2lfdata(file = f, vars = c("temp_mean", "prec"))
names(ld)
#> [1] "df"        "temp_mean" "prec"     
ld$df[, c("station_id", "year", "n_days", "first_date", "last_date",
          "n_temp_mean_valid", "n_temp_mean_missing")]
#>            station_id year n_days first_date  last_date n_temp_mean_valid
#> 10157_2024      10157 2024      6 2024-01-01 2024-01-06                 6
#>            n_temp_mean_missing
#> 10157_2024                 359
ld$df$qc_temp_mean   # codes per curve (NA: this extract has no codes)
#> 10157_2024 
#>     NA:365 
ld$df$fecha
#>                 10157_2024 
#> 2024-01-01..2024-01-06 (6) 
```
