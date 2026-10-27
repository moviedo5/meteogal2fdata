# Convert MeteoGalicia daily observations to functional data

Construct an
[`fda.usc::fdata`](https://moviedo5.github.io/fda.usc/reference/fdata.html)
object from one numeric meteorological variable, with one curve per
station-year.

## Usage

``` r
meteogal2fdata(
  station_id = NULL,
  var,
  start_date = NULL,
  end_date = NULL,
  last_n_days = 30L,
  df = NULL,
  file = NULL,
  output_file = NULL,
  verbose = FALSE,
  control = list(),
  quality = c(1L, 5L)
)
```

## Arguments

- station_id:

  Optional station code(s); used to filter local data or to select
  stations for online requests.

- var:

  A single numeric variable, e.g. `"temp_mean"` or `"prec"`.

- start_date, end_date:

  Optional initial and final date (`YYYY-MM-DD` or `Date`). For online
  requests, omitted dates default to the last 30 days.

- last_n_days:

  Positive integer, for the default online interval.

- df:

  Optional data.frame of daily observations.

- file:

  Optional input file(s) or directory (outputs of
  [`meteogal2download()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2download.md),
  or files saved with `meteogal2df(file = ...)`).

- output_file:

  Optional `.rds`, `.rda` or `.RData` output path.

- verbose:

  Print download or reading messages.

- control:

  List of options passed to
  [`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md)
  for online data.

- quality:

  Validation codes whose values are used (default `c(1, 5)`); see
  [`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md)
  and
  [`meteogal_qc_codes()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal_qc_codes.md).
  Values without a code (data without codes) are kept.

## Value

An `fdata` object with one row per station-year (row names
`station_year`), 365 columns, and attributes `quality_summary`, `qc`,
`fecha`, `quality_codes`, `var_name`, `var_units` and `source`.

## Details

Each curve has 365 common evaluation points (`argvals = 1:365`).
February 29 is removed, and subsequent dates in leap years are shifted
so that position 60 always represents March 1. Days without a record,
and values not admitted by `quality`, are `NA`; nothing is imputed.
Different stations and years are never combined in the same curve.

Supply either `df` (for example, from
[`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md)),
`file` (a `.rda`, `.rds`, `.csv`, or a directory), or neither to query
MeteoGalicia online. `output_file` saves the result.

**Per-curve information** is attached as attributes whose row names are
the curve names (`station_year`): `quality_summary` (counts per curve:
original, interpolated, suspect, unvalidated, erroneous, not registered,
unknown, valid, interp, masked, missing), `qc` (365-column matrix of
validation codes) and `fecha` (365-column matrix with the date of every
record). fda.usc subsetting (`fd[i]`) does **not** subset attributes, so
after subsetting use `attr(fd, "qc")[rownames(fd$data), ]`. For analyses
that need this metadata,
[`meteogal2lfdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2lfdata.md)
is preferable: it keeps it in `ldata$df`, which is subset together with
the curves.

Source: MeteoGalicia, Xunta de Galicia.

## References

MeteoGalicia daily JSON service documentation:
<https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf>.

## See also

[`meteogal2lfdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2lfdata.md),
[`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md),
[`meteogal_qc_codes()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal_qc_codes.md)

## Examples

``` r
d <- data.frame(fecha = as.Date(c("2024-02-28", "2024-02-29", "2024-03-01")),
                station_id = "10157", temp_mean = c(11, 12, 13),
                qc_temp_mean = c(1L, 1L, 2L))
fd <- meteogal2fdata(var = "temp_mean", df = d)
#> [MeteoGalicia] quality = c(1, 5): values set to NA: 1 with code 2 (Suspect). Codes are kept in the qc_ columns; see meteogal_qc_codes().
dim(fd$data)
#> [1]   1 365
fd$data[1, 59:60]       # 11 (Feb 28), NA (Mar 1 is suspect, code 2)
#> 59 60 
#> 11 NA 
attr(fd, "qc")[1, 59:60]
#> 59 60 
#>  1  2 
attr(fd, "quality_summary")
#>            n_original n_interpolated n_suspect n_unvalidated n_erroneous
#> 10157_2024          1              0         1             0           0
#>            n_not_registered n_unknown n_valid n_interp n_masked n_missing
#> 10157_2024                0         0       1        0        1       364
```
