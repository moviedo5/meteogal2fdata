# Live checks against the MeteoGalicia services. Run explicitly from the
# package root (not part of R CMD check). Writes only under tempdir().
# Requires internet access to servizos.meteogalicia.gal.

stopifnot(requireNamespace("devtools", quietly = TRUE))
devtools::load_all(".")

# 1. Station list (listaEstacionsMeteo.action), base R + jsonlite
inv <- meteogal2inventory()
str(inv)
stopifnot(is.data.frame(inv), nrow(inv) > 50L, "10157" %in% inv$station_id,
          all(inv$lon > -10 & inv$lon < -6, na.rm = TRUE),
          all(inv$lat > 41 & inv$lat < 44.5, na.rm = TRUE))

# 2. Daily JSON with validation codes, a short past interval
x <- meteogal2df(station_ids = "10157", start_date = "2024-01-01",
                 end_date = "2024-01-07", vars = c("temp_mean", "prec"),
                 quality = NULL)
print(x)
print(attr(x, "units"))
stopifnot(nrow(x) == 7L, all(c("qc_temp_mean", "qc_prec") %in% names(x)))
print(table(x$qc_temp_mean, useNA = "ifany"))

# 4. Recent data: how many values are still unvalidated (code 0)?
recent <- meteogal2df(station_ids = "10157", vars = "temp_mean", quality = NULL)
print(table(recent$qc_temp_mean, useNA = "ifany"))
r15 <- meteogal2df(station_ids = "10157", vars = "temp_mean")   # message expected

# 5. Download (rds and csv), manifest, resume
out_dir <- file.path(tempdir(), "meteogal2fdata-smoke")
unlink(out_dir, recursive = TRUE)
log1 <- meteogal2download("2024-01-01", "2024-02-15", station_ids = "10157",
                          vars = c("temp_mean", "prec"), out_dir = out_dir)
log2 <- meteogal2download("2024-01-01", "2024-02-15", station_ids = "10157",
                          vars = c("temp_mean", "prec"), out_dir = out_dir)
print(log1); print(log2)
stopifnot(all(log1$status == "ok"), all(log2$status == "done"))
print(utils::read.csv(file.path(out_dir, "_meteogal_manifest.csv")))
csv_dir <- file.path(tempdir(), "meteogal2fdata-smoke-csv")
unlink(csv_dir, recursive = TRUE)
meteogal2download("2024-01-01", "2024-01-31", station_ids = "10157",
                  out_dir = csv_dir, format = "csv")
y <- meteogal2df(data_dir = csv_dir, quality = NULL)
stopifnot(nrow(y) == 31L, any(grepl("^qc_", names(y))))

# 6. Functional conversion
ld <- meteogal2lfdata(file = out_dir, vars = c("temp_mean", "prec"))
print(ld$df[, c("station_id", "year", "n_days", "n_temp_mean_valid",
                "n_temp_mean_masked", "n_temp_mean_missing")])
print(ld$df$qc_temp_mean)
cat("Live checks completed.\n")
