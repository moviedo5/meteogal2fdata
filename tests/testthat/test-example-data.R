test_that("bundled observed rows are readable without an internet connection", {
  f <- system.file("extdata", "meteogal_small.csv", package = "meteogal2fdata")
  expect_true(nzchar(f))
  x <- meteogal2df(data_dir = f, station_ids = "10157",
                   vars = c("temp_mean", "prec"))
  expect_s3_class(x, "data.frame")
  expect_equal(nrow(x), 6L)
  expect_identical(x$station_id, rep("10157", 6L))
  expect_true(inherits(x$fecha, "Date"))
  expect_equal(x$temp_mean[1L], 12.59)
  expect_equal(x$prec[2L], 10.6)
  fd <- meteogal2fdata(df = x, var = "temp_mean")
  expect_identical(dim(fd$data), c(1L, 365L))
  expect_equal(unname(as.numeric(fd$data[1L, 1:6])), x$temp_mean)
  ld <- meteogal2lfdata(df = x, vars = c("temp_mean", "prec"))
  expect_equal(ld$df$n_days, 6L)
  expect_identical(rownames(ld$df), rownames(ld$temp_mean$data))
  expect_identical(rownames(ld$df), rownames(ld$prec$data))
})

test_that("temperature unit uses portable ASCII source with Unicode escape", {
  expect_identical(meteogal2fdata:::.meteogal_var_units("temp_mean"), "\u00B0C")
  # units reported by the service take precedence
  expect_identical(meteogal2fdata:::.meteogal_var_units("prec", c(prec = "mm")), "mm")
})

test_that("bundled CSV keeps accents in any locale", {
  f <- system.file("extdata", "meteogal_small.csv", package = "meteogal2fdata")
  x <- meteogal2df(data_dir = f)
  expect_identical(enc2utf8(x$station_name[1L]),
                   "Coru\u00f1a-Torre de H\u00e9rcules")
})

test_that("optional two-station sample has aligned annual curves", {
  f <- system.file("extdata", "meteogal_example.csv", package = "meteogal2fdata")
  if (!nzchar(f)) skip("Optional historical sample has not been built")
  x <- meteogal2df(data_dir = f, vars = c("temp_mean", "prec"))
  expect_equal(length(unique(x$station_id)), 2L)
  expect_identical(sort(unique(format(x$fecha, "%Y"))), c("2023", "2024"))
  ld <- meteogal2lfdata(df = x, vars = c("temp_mean", "prec"))
  expect_equal(nrow(ld$df), 4L)
  expect_equal(ncol(ld$temp_mean$data), 365L)
  expect_identical(rownames(ld$df), rownames(ld$prec$data))
})
