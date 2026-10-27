# MeteoGalicia validation codes

Table of the validation codes (`lnCodigoValidacion`) that MeteoGalicia
attaches to every measurement in its daily and hourly JSON services,
together with the way these codes are treated by the package.

## Usage

``` r
meteogal_qc_codes()
```

## Value

A data.frame with columns `code`, `description`, `default` (`TRUE` when
admitted by the default `quality = c(1, 5)`) and `usable` (`FALSE` for
codes that can never be admitted).

## Details

Each measurement `<variable>` can be accompanied by an integer column
`qc_<variable>`. The `quality` argument of
[`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md),
[`meteogal2fdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2fdata.md)
and
[`meteogal2lfdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2lfdata.md)
specifies which codes are admitted. Values with other codes are set to
`NA` in the returned object, while the original codes are retained.

Codes 3 (erroneous) and 9 (not recorded) are never used. A missing
validation code means that its status is unknown; such observations are
retained and counted as having unknown validation status.

The sentinel value `-9999`, documented by MeteoGalicia as representing
no data, is always treated as missing.

## References

MeteoGalicia. Daily meteorological-station data (JSON):
<https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionsDiarios_es.pdf>.

MeteoGalicia. Historical hourly station data (JSON), same validation
codes:
<https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_EstacionHorariosHistoricos_es.pdf>.

MeteoGalicia. Current station state (JSON), `-9999` = no data:
<https://www.meteogalicia.gal/datosred/infoweb/meteo/docs/rss/JSON_estado_actual_es.pdf>.

## Examples

``` r
meteogal_qc_codes()
#>   code        description default usable
#> 1    0      Not validated   FALSE   TRUE
#> 2    1     Valid original    TRUE   TRUE
#> 3    2            Suspect   FALSE   TRUE
#> 4    3          Erroneous   FALSE  FALSE
#> 5    5 Valid interpolated    TRUE   TRUE
#> 6    9       Not recorded   FALSE  FALSE
```
