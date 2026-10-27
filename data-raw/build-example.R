# Build the real-data examples shipped in inst/extdata.
# Run from the package root with internet access.
#
# Nothing is simulated. Observations are downloaded from MeteoGalicia and
# validation codes are retained in the qc_ columns.
#
# Creates:
#   inst/extdata/meteogal_example.csv
#       Coruna-Torre de Hercules and Ourense, 2023-2024
#   inst/extdata/meteogal_example_inventory.rds
#       metadata for those two stations
#   inst/extdata/meteogal_inventory.csv
#       all stations currently in service
#   inst/extdata/meteogal_temperature_2024.csv
#       station metadata, annual mean temperature and number of usable days;
#       used by the spatial vignette

stopifnot(file.exists("DESCRIPTION"))
stopifnot(requireNamespace("devtools", quietly = TRUE))
devtools::load_all(".")

dir.create(file.path("inst", "extdata"), recursive = TRUE, showWarnings = FALSE)

# -------------------------------------------------------------------------
# 1. Two contrasting stations: Atlantic coast and inland Galicia
# -------------------------------------------------------------------------

stations <- c("10157", "10148")
vars <- c("temp_mean", "temp_min", "temp_max", "hum_mean", "prec")
tmp <- file.path(tempdir(), "meteogal-example")

log <- meteogal2download(
  start_date = "2023-01-01",
  end_date = "2024-12-31",
  station_ids = stations,
  vars = vars,
  out_dir = tmp,
  control = list(sleep_pause = 2)
)
print(log)
stopifnot(all(log$status %in% c("ok", "done")))

# The saved example is raw: original values and validation codes are retained.
raw <- suppressMessages(
  meteogal2df(
    data_dir = tmp,
    quality = NULL,
    vars = vars,
    file = file.path("inst", "extdata", "meteogal_example.csv")
  )
)

print(table(raw$station_id, format(raw$fecha, "%Y")))
for (v in vars) {
  cat("\n", v, " validation codes:\n", sep = "")
  print(table(raw[[paste0("qc_", v)]], useNA = "ifany"))
}

# -------------------------------------------------------------------------
# 2. Station inventory
# -------------------------------------------------------------------------

inv <- meteogal2inventory(
  file = file.path("inst", "extdata", "meteogal_inventory.csv")
)

inv_example <- inv[inv$station_id %in% stations, , drop = FALSE]
saveRDS(
  inv_example,
  file.path("inst", "extdata", "meteogal_example_inventory.rds")
)
print(inv_example)

# -------------------------------------------------------------------------
# 3. Annual mean temperature for the spatial vignette
# -------------------------------------------------------------------------

# A single year for the complete network is enough to illustrate how an
# observed meteorological variable can be represented spatially. Downloads
# remain raw; the quality criterion is applied only when reading.
tmp_map <- file.path(tempdir(), "meteogal-temperature-2024")

log_map <- meteogal2download(
  start_date = "2024-01-01",
  end_date = "2024-12-31",
  station_ids = NULL,
  vars = "temp_mean",
  out_dir = tmp_map,
  control = list(sleep_pause = 2)
)
print(log_map)

mg2024 <- suppressMessages(
  meteogal2df(
    data_dir = tmp_map,
    vars = "temp_mean",
    quality = c(1, 5)
  )
)

ids <- unique(mg2024$station_id)
temp2024 <- data.frame(
  station_id = ids,
  temp_mean_2024 = vapply(ids, function(id) {
    z <- mg2024$temp_mean[mg2024$station_id == id]
    if (any(!is.na(z))) mean(z, na.rm = TRUE) else NA_real_
  }, numeric(1)),
  n_temp_mean_2024 = vapply(ids, function(id) {
    sum(!is.na(mg2024$temp_mean[mg2024$station_id == id]))
  }, integer(1)),
  stringsAsFactors = FALSE
)

temp2024 <- merge(
  inv[, c("station_id", "station_name", "municipality", "province",
          "altitude", "lon", "lat"), drop = FALSE],
  temp2024,
  by = "station_id",
  all.y = TRUE,
  sort = FALSE
)
temp2024 <- temp2024[order(temp2024$station_id), , drop = FALSE]

# Package writer: UTF-8 whatever the session locale, NA as "".
.meteogal_write(temp2024, file.path("inst", "extdata", "meteogal_temperature_2024.csv"))

cat("\nInventory:", nrow(inv), "stations in service\n")
cat("Temperature map:", sum(is.finite(temp2024$temp_mean_2024)),
    "stations with usable temperature data\n")
cat("\nRebuild and check:\n",
    "devtools::document()\n",
    "devtools::test()\n",
    "devtools::check()\n", sep = "")
