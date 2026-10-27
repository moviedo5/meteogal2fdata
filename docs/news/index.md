# Changelog

## meteogal2fdata 0.2.0

### Dependencies: base R + jsonlite + fda.usc

- ‘meteospain’ and ‘sf’ are no longer used. The station inventory uses
  the MeteoGalicia station list service (`listaEstacionsMeteo.action`);
  the `control$backend` option has been removed.
- Reading of the author’s earlier `meteogalicia_YYYY.rda` archives (sf
  objects produced by ‘meteospain’, without validation codes) has been
  removed from the package, together with the translation of
  ‘meteospain’ column names. Data should be downloaded again with
  [`meteogal2download()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2download.md)
  so that the codes are kept.
- `jsonlite` and `tools` are now in Imports (both were used).

### Validation codes, unreliable and missing values

- [`meteogal_qc_codes()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal_qc_codes.md)
  now exposes the official codes (0, 1, 2, 3, 5, 9) with a single
  English `description` column and the default use. Package-facing
  variable and validation terminology is consistently in English.
- Default `quality = c(1, 5)` kept. When values are set to `NA` a
  message now reports how many and with which code (and `-9999`). The
  result has attributes `quality` and `units` (units as reported by the
  service, `unidade`).
- The daily parser also keeps `municipality` (`concello`).
- Documentation now states what ‘meteospain’ does (drops codes 0, 3, 9
  and discards the codes) and cites the official documents for codes,
  `-9999` and station fields.

### Downloads and provenance

- Downloads remain unfiltered. New provenance manifest
  `out_dir/_meteogal_manifest.csv` (one row per file written) and
  `attr(x, "meteogal_meta")` in `.rds` files.
- New `format = "csv"` in
  [`meteogal2download()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2download.md):
  UTF-8 station-year CSV files with values and codes.
- CSV files are written and read independently of the session locale
  (accents were lost or the file was truncated in non-UTF-8 locales).
- Cache folders `_tmp*` are always skipped when reading a directory.

### Functional data

- `ldata$df` now has, per variable, `n_<v>_valid`, `n_<v>_interp`,
  `n_<v>_masked`, `n_<v>_missing` and `qc_<v>` (365-column matrix of
  daily codes); per curve, `first_date`, `last_date` and `fecha`
  (365-column matrix of record dates). The matrices (class `mg_daymat`)
  are subset together with the curves and print as one summary per
  curve. This replaces the nine count columns per variable of 0.1.2.
- [`meteogal2fdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2fdata.md)
  keeps `quality_summary` (all counts), `qc` and `fecha` as attributes
  indexed by curve name.

### Examples and vignettes

- The Shiny application meteogal2shiny lives in a separate folder
  (`meteogal2fdata_shiny/`, same design as aemet2shiny: Leaflet station
  map, UDC theme), not inside the package; `shiny` is not a package
  dependency.
- The real two-station example now uses Coruña-Torre de Hércules
  (`10157`) and Ourense (`10148`), giving a clearer coastal-inland
  comparison than the previous pair of nearby stations.
- `data-raw/build-example.R` also creates a compact 2024 station summary
  for mapping annual mean daily temperature.
- The spatial vignette now shows both fixed station metadata (altitude)
  and an observed meteorological quantity (annual mean temperature)
  using base R.
- New Spanish vignette `meteogalicia-es`: complete workflow from station
  inventory and download to validation codes, spatial exploration,
  `fdata` and `ldata`.
- `dev/validate-meteogal2fdata.R` continues to provide live-service
  checks; package vignettes remain reproducible without making live
  requests.

## meteogal2fdata 0.1.2

- Added a dedicated spatial inventory vignette and a dedicated raw CSV
  and validation-quality vignette; retained the functional-data
  vignette.
- Added `dev/build.R` as a reproducible developer workflow; README.md is
  edited directly rather than generated from a nonexistent README.Rmd.
- The original acquisitions vignette is superseded by the CSV/quality
  vignette.

### Preserve MeteoGalicia validation information (2026-10-22)

- Native daily JSON download, using base R HTTP and `jsonlite` for
  parsing. Original quality codes are retained separately for every
  observed variable in `qc_<variable>` columns. Data requests support
  server-side `idParam` filtering using the `vars` argument and optional
  native parameter codes.
- [`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md),
  [`meteogal2fdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2fdata.md)
  and
  [`meteogal2lfdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2lfdata.md)
  accept `quality` (default `c(1, 5)`, original and
  provider-interpolated). Rejected values become `NA` locally;
  downloaded `.rds` files retain raw values and codes. Codes 3 and 9 and
  sentinel -9999 are always missing.
- `ldata$df` now provides variable-specific annual quality counts;
  `fdata` has a `quality_summary` attribute. Older archives without
  codes remain compatible and are counted as unknown validation
  provenance.
- Resumable quality-aware caches are segregated from original
  `meteospain` caches. Incremental downloads preserve unrelated
  previously stored measurement columns. Added offline JSON and quality
  tests.
- README and three vignettes (spatial-stations, daily-data-and-quality,
  functional-data) document provenance and quality selection. Referenced
  official MeteoGalicia URLs have no tracking parameters.

## meteogal2fdata 0.1.1

### Documentation, examples and validation (2026-10-22)

- Renamed the two vignette source files to start with a letter
  (`download-and-manage.Rmd`, `functional-data.Rmd`), fixing the invalid
  `inst/doc` filenames reported by `R CMD check`.

- Validation on R 4.6.0 (2026-10-22): 41 passing `testthat`
  expectations; successful vignette build; live API smoke test returned
  7 daily records for station 10157 and correctly reused the completed
  download on a second run.

- Fixed the non-ASCII source-code warning for degree-Celsius labels
  using a portable Unicode escape; displayed units remain unchanged.

- Added `inst/extdata/meteogal_small.csv`, a six-day extract of verified
  historical station observations (not a complete annual series).

- Added two R Markdown vignettes: acquisition/management and
  functional-data conversion. API calls are optional and never run when
  building the vignettes.

- Added a reproducible `data-raw/build-example.R` script to create a
  larger real-data sample (two stations, 2023-2024) and sample inventory
  from the existing archived `.rda` files. These generated files are
  optional until the script is executed in R; no observations have been
  invented.

- Added offline fixture tests and an explicit live-API smoke-test
  script.

- Added `knitr` and `rmarkdown` under Suggests and
  `VignetteBuilder: knitr`.

## meteogal2fdata 0.1.0

### Initial development version (2026-10-22)

- [`meteogal2inventory()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2inventory.md)
  reads station metadata from the MeteoGalicia service or reconstructs
  an inventory from local archived observations, preserving original
  station codes as character strings.
- [`meteogal2download()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2download.md)
  retrieves daily observations in calendar-month chunks, with retries, a
  resumable window cache, and one `.rds` file per station/year. Archives
  are never written when a requested chunk fails.
- [`meteogal2df()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2df.md)
  reads the original `meteogalicia_YYYY.rda` files from the older
  project, the new station/year `.rds` files, or online data. The output
  is a base R `data.frame` with standardized variable names and no
  spatial geometry or `units` classes. No missing values are imputed.
- [`meteogal2fdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2fdata.md)
  converts a selected numerical measurement into an `fdata` object with
  one curve for each station-year.
- [`meteogal2lfdata()`](https://moviedo5.github.io/meteogal2fdata/reference/meteogal2lfdata.md)
  constructs aligned station-year `fdata` curves for multiple variables
  and their metadata as an `ldata` object.
- Functional curves have 365 observations: February 29 is removed, while
  subsequent days of leap years are shifted back (March 1 is always day
  60). Absent measurements remain `NA`.
- The package uses base R for data handling, `meteospain` for online
  access, and `fda.usc` for functional objects; packages for plots and
  data wrangling are not required.

### Development limitations

- The online requests have not yet been validated in an installed R
  session. The historical-data interface was checked against the
  archived script conventions and a station-year extract provided by the
  user.
