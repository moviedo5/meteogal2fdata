# Development workflow: run from package root. No absolute paths.
stopifnot(file.exists("DESCRIPTION"))
stopifnot(requireNamespace("devtools", quietly = TRUE))

# Roxygen generates NAMESPACE and man/*.Rd: do not edit those manually.
devtools::document()
for (f in list.files("man", "\\.Rd$", full.names = TRUE)) tools::checkRd(f)

# README.md is intentionally maintained directly. build_readme() would
# require README.Rmd or README.qmd; do not call it for this package.
devtools::test()
devtools::check()
devtools::install(build_vignettes = TRUE)


# Generar el paquete distribuible
devtools::build()
# Only if pkgdown is installed / a site is wanted:
# pkgdown::build_site()
# Optional online smoke test, kept outside R CMD check:
# source("dev/validate-meteogal2fdata.R")

# Vignettes after installation:
# vignette(package = "meteogal2fdata")
# vignette("spatial-stations", package = "meteogal2fdata")
# vignette("daily-data-and-quality", package = "meteogal2fdata")
# vignette("functional-data", package = "meteogal2fdata")

# shiny
# shiny::runApp("meteogal2fdata_shiny")
# Para publicarla: source("deploy.R"). 
# Antes, el paquete tiene que estar en GitHub (moviedo5/meteogal2fdata), igual que con aemet2fdata.
