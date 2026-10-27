# Download MeteoGalicia daily observations to station-year files

Download original daily values **and their validation codes** in
calendar-month windows and save one file per station and year (`.rds` or
`.csv`). Completed windows are cached, so a repeated call resumes an
interrupted download without repeating successful requests. Every file
written is recorded in a provenance manifest.

## Usage

``` r
meteogal2download(
  start_date,
  end_date,
  out_dir = "meteogal_daily",
  station_ids = NULL,
  vars = NULL,
  window_days = NULL,
  format = c("rds", "csv"),
  overwrite = FALSE,
  verbose = TRUE,
  control = list()
)
```

## Arguments

- start_date, end_date:

  `Date` or `"YYYY-MM-DD"`; not in the future.

- out_dir:

  Destination folder (relative path recommended).

- station_ids:

  `NULL` for all stations, or station codes. With explicit IDs, each
  station is requested separately for safe resumption.

- vars:

  `NULL` for all variables, or names / native parameter codes requested
  with `idParam` (e.g. `c("temp_mean", "prec")`).

- window_days:

  `NULL` (calendar months) or a positive integer.

- format:

  `"rds"` (default) or `"csv"` (UTF-8, empty string for `NA`).

- overwrite:

  If `TRUE`, request the windows again (ignoring the cache) and replace
  those dates in existing files.

- verbose:

  Show messages.

- control:

  List of `max_attempts` (3), `retry_wait` (15 s), `sleep_pause` (1 s)
  and `timeout` (60 s). See
  [`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md).

## Value

Invisibly, a data.frame with `station_id`, `year`, `status` (`ok`,
`done` = everything from cache, `nodata`, `incomplete`), `n_windows`,
`n_failed`, `n_files` and `n_rows`.

## Details

Files are stored as `out_dir/STATION/STATION_YYYY.rds` (or `.csv`). Each
contains a base R data.frame with `fecha`, station metadata, the daily
values and one `qc_<variable>` column per variable with the MeteoGalicia
validation code (see
[`meteogal_qc_codes()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal_qc_codes.md)).

**Nothing is filtered at download time**: suspect, unvalidated or
erroneous values are stored as delivered, with their codes. The quality
criterion is chosen later, when reading, with the `quality` argument of
[`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md),
[`meteogal2fdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2fdata.md)
or
[`meteogal2lfdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2lfdata.md),
so it can be changed without downloading again. No missing value is
imputed.

**Provenance.** `out_dir/_meteogal_manifest.csv` gets one row per file
written: file, station, year, format, rows, first and last date, the
requested parameters (`idParam`), whether validation codes are present,
`quality_filter = "none (raw values with lnCodigoValidacion)"`, the
download time (UTC), the service URL and the package version. `.rds`
files also carry this information in `attr(x, "meteogal_meta")` and the
units reported by the service in `attr(x, "units")`.

Existing station-year files are merged by `station_id` and `fecha`:
variables downloaded now replace those dates, other variables and dates
are kept. If any window of a station-year fails, its final file is not
written (successful windows stay cached); re-run to resume.

Stations are taken from the observations returned in each window, so
stations opening or closing during the year are included. No request
quota is stated in the service documentation; monthly windows and pauses
(`control$sleep_pause`) keep the load low.

Data source: MeteoGalicia, Xunta de Galicia. Reuse requires citing
MeteoGalicia as the source (<https://www.meteogalicia.gal/aviso-legal>).

## References

MeteoGalicia daily JSON service documentation:
<https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf>.

## See also

[`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md),
[`meteogal2inventory()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2inventory.md),
[`meteogal_qc_codes()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal_qc_codes.md)

## Examples

``` r
if (FALSE) { # \dontrun{
log <- meteogal2download("2024-01-01", "2024-12-31", station_ids = "10157",
                         vars = c("temp_mean", "prec"), format = "csv",
                         out_dir = "meteogal_daily")
log
read.csv(file.path("meteogal_daily", "_meteogal_manifest.csv"))
# Quality is chosen when reading (no new download needed)
x1 <- meteogal2df(data_dir = "meteogal_daily", quality = c(1, 5))
x0 <- meteogal2df(data_dir = "meteogal_daily", quality = c(0, 1, 5))
} # }
```
