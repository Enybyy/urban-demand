options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 600)
packages <- c("renv", "dplyr", "tidyr", "ggplot2", "scales", "lubridate", "readr",
              "jsonlite", "digest", "MASS", "knitr", "rmarkdown")
if (file.exists("renv.lock")) {
  renv::restore(prompt = FALSE)
} else {
  missing <- setdiff(packages, rownames(installed.packages()))
  if (length(missing)) install.packages(missing, type = "binary")
  renv::init(bare = TRUE, restart = FALSE)
  renv::hydrate(packages = setdiff(packages, "renv"), prompt = FALSE)
  renv::snapshot(packages = packages, prompt = FALSE)
}
