# MeteoGalicia station inventory (data.frame)

Station identifiers, names, municipality, province, altitude and
geographical coordinates, as a base R data.frame. By default the station
list service of MeteoGalicia is queried (`listaEstacionsMeteo.action`);
alternatively, `data_dir` derives the inventory from local observations,
including stations no longer active.

## Usage

``` r
meteogal2inventory(file = NULL, data_dir = NULL, verbose = FALSE, timeout = 60)
```

## Arguments

- file:

  `NULL`, or a destination `.rds`, `.rda`/`.RData` or `.csv` path.

- data_dir:

  `NULL` (query the service) or a directory/file of observations
  readable by
  [`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md).

- verbose:

  Show progress messages.

- timeout:

  Seconds allowed for the online request.

## Value

Invisibly, a data.frame with `station_id`, `station_name`,
`municipality`, `province`, `altitude` (m), `lon`, `lat`, `first_date`
and `last_date`.

## Details

The online service lists the stations **currently in service**; it is
not a historical inventory. With `data_dir`, `first_date` and
`last_date` are the first and last dates present in the local data, not
official opening/closing dates. Coordinates are WGS84 decimal degrees
(`lon`, `lat`) and altitude is in metres. Data source: MeteoGalicia,
Xunta de Galicia.

## References

MeteoGalicia station list (JSON):
<https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_listaEstacionsMeteo_es.pdf>;
station fields are also described in
<https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_estado_actual_es.pdf>.

## See also

[`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md),
[`meteogal2lfdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2lfdata.md)

## Examples

``` r
f <- system.file("extdata", "meteogal_small.csv", package = "meteogal2fdata")
meteogal2inventory(data_dir = f)
if (FALSE) { # \dontrun{
inv <- meteogal2inventory(file = "meteogal_inventory.rds")
plot(inv$lon, inv$lat, asp = 1, pch = 19)
} # }
```
