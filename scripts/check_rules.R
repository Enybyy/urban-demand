suppressPackageStartupMessages(library(dplyr))
source("R/models.R")
fixture <- tibble::tibble(dteday = as.Date(c("2011-01-01", "2011-01-02", "2011-01-03")),
  hr = c(1, 1, 17), workingday = c(0, 0, 1), weekday = c(6, 0, 1),
  weathersit = c(1, 4, 2), temp = c(.2, .3, .4), hum = c(.5, .6, .7), windspeed = c(.1, .2, .3),
  cnt = c(10, 20, 80), casual = c(2, 4, 10), registered = c(8, 16, 70))
x <- demand_features(fixture)
stopifnot(as.character(x$weather[2]) == "Adverse", identical(levels(x$hour), as.character(0:23)),
  all(vapply(c("Poisson", "Negative binomial", "Spline negative binomial"),
    function(name) !any(c("casual", "registered") %in% all.vars(model_formula(name))), logical(1))))
reference <- fit_demand_model("Hour and day-type reference", x[1:2, ])
stopifnot(identical(predict_demand(reference, x), c(15, 15, 15)))
e <- error_metrics(c(10, 20), c(8, 24))
stopifnot(e$mae == 3, abs(e$rmse - sqrt(10)) < 1e-9, e$mean_bias == 1, e$wape == .2)
cat("Weather pooling, target exclusion, reference fallback and error-metric checks passed.\n")
