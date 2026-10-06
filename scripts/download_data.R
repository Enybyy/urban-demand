dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
url <- "https://archive.ics.uci.edu/static/public/275/bike%2Bsharing%2Bdataset.zip"
files <- c("hour.csv", "day.csv", "Readme.txt")
if (!all(file.exists(file.path("data/raw", files)))) {
  download.file(url, "data/raw/bike-sharing.zip", mode = "wb", method = "libcurl")
  unzip("data/raw/bike-sharing.zip", exdir = "data/raw")
}
hashes <- setNames(vapply(file.path("data/raw", files), function(f) digest::digest(file = f, algo = "sha256"), character(1)), files)
manifest_file <- "data/source-manifest.json"
if (file.exists(manifest_file)) {
  manifest <- jsonlite::read_json(manifest_file, simplifyVector = TRUE)
  stopifnot(identical(unname(unlist(manifest$sha256[files])), unname(hashes)))
} else {
  jsonlite::write_json(list(dataset = "UCI Bike Sharing", creator = "Hadi Fanaee-T",
    doi = "https://doi.org/10.24432/C5W894", license = "CC BY 4.0", download_url = url,
    sha256 = as.list(hashes), retrieved_at_utc = format(Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")),
    manifest_file, auto_unbox = TRUE, pretty = TRUE)
}
cat("Hourly, daily and README source checksums verified.\n")
