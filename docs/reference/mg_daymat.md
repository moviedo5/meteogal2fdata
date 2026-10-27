# Day-level matrices in `ldata$df`

[`meteogal2lfdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2lfdata.md)
stores the validation code of every day (`qc_<variable>`) and the date
of every record (`fecha`) as `n_curves x 365` matrices in columns of
`ldata$df`, so they stay aligned with the curves when the object is
subset. These methods print them as a one-line summary per curve and
keep the class when rows are selected. Use
[`unclass()`](https://rdrr.io/r/base/class.html) (or
[`as.matrix()`](https://rdrr.io/r/base/matrix.html)) to obtain the plain
matrix.

## Usage

``` r
# S3 method for class 'mg_daymat'
format(x, ...)

# S3 method for class 'mg_daymat'
x[...]

# S3 method for class 'mg_daymat'
print(x, ...)

# S3 method for class 'mg_daymat'
as.matrix(x, ...)
```

## Arguments

- x:

  An object of class `mg_daymat`.

- ...:

  Indices (`[`) or ignored (`format`).

## Value

[`format()`](https://rdrr.io/r/base/format.html): a character vector,
one element per row; [`print()`](https://rdrr.io/r/base/print.html):
`x`, invisibly; [`as.matrix()`](https://rdrr.io/r/base/matrix.html): the
plain matrix; `[`: an `mg_daymat` when the result is a matrix, otherwise
a plain vector.

## Examples

``` r
d <- data.frame(fecha = as.Date(c("2024-01-01", "2024-01-02")),
                station_id = "10157", temp_mean = c(10, 11),
                qc_temp_mean = c(1L, 5L))
ld <- meteogal2lfdata(df = d, vars = "temp_mean")
ld$df$qc_temp_mean            # compact summary
#>     10157_2024 
#> 1:1 5:1 NA:363 
unclass(ld$df$qc_temp_mean)[, 1:3]
#>  1  2  3 
#>  1  5 NA 
```
