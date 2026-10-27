test_that("station/year curves align leap and non-leap dates", {
  dates <- as.Date(c("2023-02-28", "2023-03-01", "2024-02-28",
                     "2024-02-29", "2024-03-01"))
  d <- data.frame(fecha = dates, station_id = "10157",
                  temp_mean = c(11, 13, 21, 22, 23),
                  prec = c(0, 1, 2, NA, 3))
  fd <- meteogal2fdata(df = d, var = "temp_mean")
  expect_s3_class(fd, "fdata")
  expect_identical(dim(fd$data), c(2L, 365L))
  expect_identical(rownames(fd$data), c("10157_2023", "10157_2024"))
  expect_equal(unname(fd$data[, 59:60]), rbind(c(11, 13), c(21, 23)))
  expect_true(all(is.na(fd$data[, 61])))
  expect_equal(fd$argvals, seq_len(365))
})

test_that("ldata metadata and curves share station/year keys", {
  d <- data.frame(fecha = as.Date(c("2023-01-01", "2024-01-01",
                                      "2024-01-01", "2024-01-02")),
                  station_id = c("001", "001", "002", "002"),
                  station_name = c("A", "A", "B", "B"),
                  temp_mean = c(10, 12, 8, 9), prec = c(1, 0, 2, NA))
  ld <- meteogal2lfdata(df = d, vars = c("temp_mean", "prec"))
  expect_true(fda.usc::is.ldata(ld))
  expect_identical(names(ld), c("df", "temp_mean", "prec"))
  expect_identical(rownames(ld$df), rownames(ld$temp_mean$data))
  expect_identical(rownames(ld$df), rownames(ld$prec$data))
  expect_equal(ld$df$n_days, c(1, 1, 2))
  expect_true(is.na(ld$prec$data["002_2024", 2]))
  expect_identical(ld$df$station_id, c("001", "001", "002"))
})

test_that("duplicated days keep last observation, not two days", {
  d <- data.frame(fecha = as.Date(c("2024-01-01", "2024-01-01")),
                  station_id = "10157", temp_mean = c(2, 7))
  expect_warning(ld <- meteogal2lfdata(df = d), "duplicate")
  expect_equal(ld$temp_mean$data[1, 1], 7)
  expect_equal(ld$df$n_days, 1)
})

test_that("numeric metadata are not functional variables", {
  d <- data.frame(fecha = as.Date("2024-01-01"), station_id = "001",
                  altitude = 80, lon = -8.5, lat = 43.3,
                  temp_mean = NA_real_, prec = 0)
  ld <- meteogal2lfdata(df = d)
  expect_identical(names(ld), c("df", "temp_mean", "prec"))
  expect_error(meteogal2fdata(df = d, var = "altitude"), "non-numeric")
})
