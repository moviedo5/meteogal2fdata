test_that("native JSON parser preserves all quality classes", {
  vals <- list(
    list(codigoParametro = "TA_AVG_1.5m", valor = 12.3, lnCodigoValidacion = 1L),
    list(codigoParametro = "PP_SUM_1.5m", valor = 0, lnCodigoValidacion = 5L),
    list(codigoParametro = "VV_AVG_2m", valor = 3.5, lnCodigoValidacion = 2L),
    list(codigoParametro = "HR_AVG_1.5m", valor = 90, lnCodigoValidacion = 0L),
    list(codigoParametro = "TA_MIN_1.5m", valor = -9999, lnCodigoValidacion = 9L),
    list(codigoParametro = "TA_MAX_1.5m", valor = 99, lnCodigoValidacion = 3L))
  js <- list(listDatosDiarios = list(list(
    data = "2024-01-01T00:00:00Z",
    listaEstacions = list(list(idEstacion = 10157, estacion = "Sample",
                              provincia = "A Coruna", listaMedidas = vals)))))
  raw <- meteogal2fdata:::.meteogal_parse_json(js)
  expect_equal(nrow(raw), 1L)
  expect_identical(raw$station_id, "10157")
  expect_equal(raw$temp_mean, 12.3)
  expect_equal(raw$qc_temp_mean, 1L)
  expect_equal(raw$qc_prec, 5L)
  expect_equal(raw$qc_wind_speed, 2L)
  expect_equal(raw$qc_hum_mean, 0L)
  expect_equal(raw$qc_temp_min, 9L)
  expect_equal(raw$qc_temp_max, 3L)
  default <- meteogal2fdata:::.meteogal_apply_quality(raw)
  expect_equal(default$temp_mean, 12.3)
  expect_equal(default$prec, 0)
  expect_true(is.na(default$wind_speed))
  expect_true(is.na(default$hum_mean))
  expect_true(is.na(default$temp_max))
  expect_true(is.na(default$temp_min))
  expect_identical(default$qc_wind_speed, 2L)
  any <- meteogal2fdata:::.meteogal_apply_quality(raw, quality = NULL)
  expect_equal(any$wind_speed, 3.5)
  expect_equal(any$hum_mean, 90)
  expect_true(is.na(any$temp_max))
  expect_true(is.na(any$temp_min))
})

test_that("selection of variables keeps their corresponding codes", {
  d <- data.frame(fecha = as.Date("2024-01-01"), station_id = "001",
                  temp_mean = 14, qc_temp_mean = 1L, prec = 0,
                  qc_prec = 5L, max_wind_speed = 4, qc_max_wind_speed = 2L)
  path <- tempfile(fileext = ".rds")
  on.exit(unlink(path))
  saveRDS(d, path)
  dat <- meteogal2df(data_dir = path, vars = c("temp_mean", "prec"))
  expect_true(all(c("temp_mean", "qc_temp_mean", "prec", "qc_prec") %in% names(dat)))
  expect_false("qc_max_wind_speed" %in% names(dat))
  expect_equal(dat$prec, 0)
  expect_equal(meteogal2df(data_dir = path, vars = "prec", quality = 1)$prec, NA_real_)
  expect_equal(meteogal2df(data_dir = path, vars = "prec", quality = NULL)$prec, 0)
})

test_that("quality summaries are aligned with station-year curves", {
  d <- data.frame(fecha = as.Date(c("2024-01-01", "2024-01-02", "2024-01-03")),
                  station_id = "001", temp_mean = c(10, 11, 12),
                  qc_temp_mean = c(1L, 5L, 2L))
  ld <- meteogal2lfdata(df = d, vars = "temp_mean")
  expect_true(fda.usc::is.ldata(ld))
  expect_equal(ld$temp_mean$data[1, 1], 10)
  expect_equal(ld$temp_mean$data[1, 2], 11)
  expect_true(is.na(ld$temp_mean$data[1, 3]))
  expect_equal(ld$df$n_temp_mean_valid, 2)
  expect_equal(ld$df$n_temp_mean_interp, 1)
  expect_equal(ld$df$n_temp_mean_masked, 1)
  expect_equal(ld$df$n_temp_mean_missing, 363)
  qc <- unclass(ld$df$qc_temp_mean)
  expect_identical(dim(qc), c(1L, 365L))
  expect_identical(unname(qc[1, 1:4]), c(1L, 5L, 2L, NA))
  expect_identical(unname(unclass(ld$df$fecha)[1, 1:4]),
                   c("2024-01-01", "2024-01-02", "2024-01-03", NA))
  expect_message(only_original <- meteogal2fdata(df = d, var = "temp_mean", quality = 1),
                 "code 5")
  expect_true(is.na(only_original$data[1, 2]))
  expect_equal(attr(only_original, "quality_summary")$n_interpolated, 1L)
  expect_equal(attr(only_original, "quality_summary")$n_masked, 2L)
  expect_identical(unname(attr(only_original, "qc")[1, 1:3]), c(1L, 5L, 2L))
})

test_that("data without codes are not falsely labelled invalid", {
  d <- data.frame(fecha = as.Date("2024-01-01"), station_id = "001", prec = 4)
  ld <- meteogal2lfdata(df = d, vars = "prec", quality = 1)
  expect_equal(ld$prec$data[1, 1], 4)
  expect_equal(ld$df$n_prec_valid, 1L)
  expect_equal(ld$df$n_prec_masked, 0L)
  expect_true(is.na(unclass(ld$df$qc_prec)[1, 1]))
})

test_that("quality codes are never treated as functional measurements", {
  d <- data.frame(fecha = as.Date("2023-01-01"), station_id = "001",
                  temp_mean = 10, qc_temp_mean = 1L)
  ld <- meteogal2lfdata(df = d)
  expect_identical(names(ld), c("df", "temp_mean"))
  expect_error(meteogal2fdata(df = d, var = "qc_temp_mean"), "non-numeric")
})

test_that("incremental download merges measurement columns without data loss", {
  d1 <- data.frame(fecha = as.Date("2024-01-01"), station_id = "001",
                   temp_mean = 10, qc_temp_mean = 1L, prec = 5, qc_prec = 1L)
  d2 <- data.frame(fecha = as.Date(c("2024-01-01", "2024-01-02")),
                   station_id = "001", temp_mean = c(11, 12),
                   qc_temp_mean = c(5L, 1L))
  got <- meteogal2fdata:::.meteogal_merge_station(d1, d2)
  expect_equal(got$temp_mean, c(11, 12))
  expect_equal(got$prec[1L], 5)
  expect_equal(got$qc_prec[1L], 1L)
  expect_true(is.na(got$prec[2L]))
})

test_that("parameter request maps standardized and native names", {
  out <- meteogal2fdata:::.meteogal_api_params(c("temp_mean", "prec"))
  expect_identical(out, c("TA_AVG_1.5m", "PP_SUM_1.5m"))
  expect_identical(meteogal2fdata:::.meteogal_api_params("PP_SUM_1.5m"), "PP_SUM_1.5m")
  expect_error(meteogal2fdata:::.meteogal_api_params("not_a_parameter"), "Unknown")
})

test_that("saving via meteogal2df preserves unmasked source values", {
  raw <- data.frame(fecha = as.Date("2024-01-01"), station_id = "001",
                    temp_mean = 10, qc_temp_mean = 5L)
  input <- tempfile(fileext = ".rds")
  output <- tempfile(fileext = ".rds")
  on.exit(unlink(c(input, output)))
  saveRDS(raw, input)
  original_only <- meteogal2df(data_dir = input, quality = 1, file = output)
  expect_true(is.na(original_only$temp_mean))
  expect_equal(readRDS(output)$temp_mean, 10)
  expect_equal(readRDS(output)$qc_temp_mean, 5L)
})
