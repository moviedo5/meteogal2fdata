test_that(".rda station-year file and offline filters work", {
  d <- data.frame(fecha = as.Date(c("2024-01-01", "2024-01-02")),
                  station_id = c("001", "002"), temp_mean = c(1, 2))
  td <- tempfile("meteogal-")
  dir.create(td)
  data <- d
  save(data, file = file.path(td, "001_2024.rda"))
  x <- meteogal2df(data_dir = td, station_ids = "001")
  expect_equal(nrow(x), 1)
  expect_identical(x$station_id, "001")
  fd <- meteogal2fdata(file = td, station_id = "001", var = "temp_mean")
  expect_equal(fd$data[1, 1], 1)
})

test_that("CSV keeps station codes with leading zeros", {
  f <- tempfile(fileext = ".csv")
  d <- data.frame(fecha = "2024-01-01", station_id = "001",
                  temp_mean = 13.5)
  utils::write.csv(d, f, row.names = FALSE)
  x <- meteogal2df(data_dir = f, station_ids = "001")
  expect_identical(x$station_id, "001")
  expect_s3_class(x$fecha, "Date")
})
