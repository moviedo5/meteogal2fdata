# Offline tests: the HTTP request is replaced by a fixed JSON response.

fixture_json <- function(start, end) {
  days <- seq(start, end, by = "day")
  list(listDatosDiarios = lapply(seq_along(days), function(i) list(
    data = paste0(format(days[i]), "T00:00:00"),
    listaEstacions = list(list(
      idEstacion = 10157, estacion = "Coru\u00f1a", concello = "A Coru\u00f1a",
      provincia = "A Coru\u00f1a", utmx = -8.41, utmy = 43.38,
      listaMedidas = list(
        list(codigoParametro = "TA_AVG_1.5m", valor = 10 + i,
             lnCodigoValidacion = if (i == 2L) 2L else 1L, unidade = "\u00baC"),
        list(codigoParametro = "PP_SUM_1.5m", valor = if (i == 3L) -9999 else 0,
             lnCodigoValidacion = if (i == 3L) 9L else 5L, unidade = "L/m2")))))))
}

mock_request <- function(start, end, station_ids, params, timeout) {
  meteogal2fdata:::.meteogal_parse_json(fixture_json(start, end))
}

test_that("download stores raw values, codes, units and a manifest", {
  testthat::local_mocked_bindings(.meteogal_json_request = mock_request,
                                  .package = "meteogal2fdata")
  out <- file.path(tempdir(), "mg-dl-rds")
  unlink(out, recursive = TRUE)
  log <- meteogal2download("2024-01-01", "2024-01-05", out_dir = out,
                           station_ids = "10157", vars = c("temp_mean", "prec"),
                           verbose = FALSE, control = list(sleep_pause = 0))
  expect_identical(log$status, "ok")
  f <- file.path(out, "10157", "10157_2024.rds")
  expect_true(file.exists(f))
  raw <- readRDS(f)
  # Nothing filtered at download time
  expect_equal(raw$temp_mean[2L], 12)
  expect_identical(raw$qc_temp_mean[2L], 2L)
  expect_equal(raw$prec[3L], -9999)
  expect_identical(raw$municipality[1L], "A Coru\u00f1a")
  expect_identical(attr(raw, "units")[["prec"]], "L/m2")
  expect_identical(attr(raw, "meteogal_meta")$quality_filter,
                   "none (raw values with lnCodigoValidacion)")
  man <- utils::read.csv(file.path(out, "_meteogal_manifest.csv"),
                         stringsAsFactors = FALSE)
  expect_identical(man$file, file.path("10157", "10157_2024.rds"))
  expect_identical(man$id_param, "TA_AVG_1.5m,PP_SUM_1.5m")
  expect_true(man$qc_codes)

  # Second run: everything from cache, manifest gets a second row
  log2 <- meteogal2download("2024-01-01", "2024-01-05", out_dir = out,
                            station_ids = "10157", vars = c("temp_mean", "prec"),
                            verbose = FALSE, control = list(sleep_pause = 0))
  expect_identical(log2$status, "done")
  expect_equal(nrow(utils::read.csv(file.path(out, "_meteogal_manifest.csv"))), 2L)

  # Quality decided when reading; the manifest is not read as data
  expect_message(x <- meteogal2df(data_dir = out), "code 2")
  expect_equal(nrow(x), 5L)
  expect_true(is.na(x$temp_mean[2L]))
  expect_true(is.na(x$prec[3L]))
  expect_identical(x$qc_temp_mean[2L], 2L)
  y <- meteogal2df(data_dir = out, quality = c(1, 2, 5))
  expect_equal(y$temp_mean[2L], 12)
  expect_true(is.na(y$prec[3L]))            # code 9 / -9999: always NA
  expect_identical(attr(y, "units")[["temp_mean"]], "\u00baC")
})

test_that("CSV format keeps codes and accents and is readable back", {
  testthat::local_mocked_bindings(.meteogal_json_request = mock_request,
                                  .package = "meteogal2fdata")
  out <- file.path(tempdir(), "mg-dl-csv")
  unlink(out, recursive = TRUE)
  meteogal2download("2024-12-30", "2025-01-02", out_dir = out,
                    station_ids = "10157", format = "csv",
                    verbose = FALSE, control = list(sleep_pause = 0))
  expect_true(file.exists(file.path(out, "10157", "10157_2024.csv")))
  expect_true(file.exists(file.path(out, "10157", "10157_2025.csv")))
  x <- suppressMessages(meteogal2df(data_dir = out, quality = NULL))
  expect_equal(nrow(x), 4L)
  expect_type(x$qc_temp_mean, "integer")
  expect_identical(enc2utf8(x$station_name[1L]), "Coru\u00f1a")
  ld <- suppressMessages(meteogal2lfdata(file = out, vars = "temp_mean"))
  expect_identical(rownames(ld$df), c("10157_2024", "10157_2025"))
})

test_that("failed windows do not write files", {
  testthat::local_mocked_bindings(
    .meteogal_json_request = function(...) stop("HTTP 503"),
    .package = "meteogal2fdata")
  out <- file.path(tempdir(), "mg-dl-fail")
  unlink(out, recursive = TRUE)
  expect_warning(log <- meteogal2download("2024-01-01", "2024-01-03", out_dir = out,
                                          station_ids = "10157", verbose = FALSE,
                                          control = list(sleep_pause = 0, retry_wait = 0,
                                                         max_attempts = 1)),
                 "Incomplete")
  expect_identical(log$status, "incomplete")
  expect_false(file.exists(file.path(out, "10157", "10157_2024.rds")))
  expect_false(file.exists(file.path(out, "_meteogal_manifest.csv")))
})

test_that("station list JSON is parsed in base R", {
  js <- list(listaEstacionsMeteo = list(
    list(idEstacion = 10157, estacion = "Coru\u00f1a-Dique", concello = "A Coru\u00f1a",
         provincia = "A Coru\u00f1a", altitude = 5, lat = 43.36, lon = -8.39),
    list(idEstacion = 10045, estacion = "Mabegondo", concello = "Abegondo",
         provincia = "A Coru\u00f1a", altitude = 94, lat = 43.24, lon = -8.26)),
    idTipo = NULL)
  inv <- meteogal2fdata:::.meteogal_parse_stations(js)
  expect_identical(inv$station_id, c("10157", "10045"))
  expect_equal(inv$altitude, c(5, 94))
  expect_identical(inv$municipality[2L], "Abegondo")
})

test_that("ldata metadata (counts, codes, dates) stay aligned when subsetting", {
  d <- data.frame(fecha = as.Date(c("2023-01-01", "2023-01-02", "2024-01-01")),
                  station_id = c("001", "001", "002"),
                  temp_mean = c(10, 11, 12), qc_temp_mean = c(1L, 0L, 5L))
  ld <- suppressMessages(meteogal2lfdata(df = d, vars = "temp_mean"))
  expect_true(fda.usc::is.ldata(ld))
  expect_true(inherits(ld$df$qc_temp_mean, "mg_daymat"))
  expect_identical(unname(format(ld$df$qc_temp_mean)), c("0:1 1:1 NA:363", "5:1 NA:364"))
  s <- subset(ld, ld$df$station_id == "002")
  expect_identical(rownames(s$df), rownames(s$temp_mean$data))
  expect_identical(dim(unclass(s$df$qc_temp_mean)), c(1L, 365L))
  expect_identical(unname(unclass(s$df$qc_temp_mean)[1, 1]), 5L)
  expect_identical(unname(unclass(s$df$fecha)[1, 1]), "2024-01-01")
  expect_equal(s$df$first_date, as.Date("2024-01-01"))
  expect_equal(s$df$n_temp_mean_interp, 1L)
  r <- ld[2, row = TRUE]
  expect_identical(unname(as.matrix(r$df$qc_temp_mean)[1, 1]), 5L)
})

test_that("validation-code table and quality argument checks", {
  qc <- meteogal_qc_codes()
  expect_identical(qc$code, c(0L, 1L, 2L, 3L, 5L, 9L))
  expect_identical(qc$code[qc$default], c(1L, 5L))
  d <- data.frame(fecha = as.Date("2024-01-01"), station_id = "1", prec = 1)
  expect_error(meteogal2lfdata(df = d, quality = 3), "always")
  expect_error(meteogal2lfdata(df = d, quality = 9), "always")
})
