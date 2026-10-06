suppressPackageStartupMessages({library(dplyr); library(tidyr); library(ggplot2)})
source("scripts/download_data.R")
source("R/models.R")
source("R/charts.R")
for (path in c("data/processed", "reports/tables", "reports/figures", "site")) dir.create(path, recursive = TRUE, showWarnings = FALSE)
raw_hour <- readr::read_csv("data/raw/hour.csv", show_col_types = FALSE)
daily <- readr::read_csv("data/raw/day.csv", show_col_types = FALSE) %>% mutate(date = as.Date(dteday))
hourly <- demand_features(raw_hour)
coverage <- hourly %>% group_by(date) %>% summarise(observed_hours = n(), hourly_total = sum(cnt), .groups = "drop") %>%
  left_join(select(daily, date, daily_total = cnt), by = "date") %>% mutate(difference = hourly_total - daily_total)
stopifnot(nrow(hourly) == 17379, nrow(daily) == 731,
  !anyDuplicated(hourly[c("date", "hr")]), !anyDuplicated(daily$date),
  all(hourly$casual + hourly$registered == hourly$cnt),
  all(daily$casual + daily$registered == daily$cnt), all(coverage$difference == 0),
  !anyNA(raw_hour), all(hourly$cnt >= 0), all(hourly$hr %in% 0:23),
  all(hourly$temp >= 0 & hourly$temp <= 1), all(hourly$hum >= 0 & hourly$hum <= 1))
validation <- validate_models(hourly)
train <- filter(hourly, date < as.Date("2012-10-01"))
test <- filter(hourly, date >= as.Date("2012-10-01"))
stopifnot(max(train$date) < min(test$date))
model <- fit_demand_model(validation$selected, train)
baseline <- fit_demand_model("Hour and day-type reference", train)
predicted <- predict_demand(model, test)
baseline_pred <- predict_demand(baseline, test)
test_scores <- bind_rows(error_metrics(test$cnt, predicted) %>% mutate(model = validation$selected),
  error_metrics(test$cnt, baseline_pred) %>% mutate(model = "Hour and day-type reference"))
test_predictions <- tibble::tibble(date = test$date, timestamp = test$timestamp, hr = test$hr,
  day_type = test$day_type, weather = test$weather, actual = test$cnt,
  predicted = predicted, baseline = baseline_pred, error = predicted - test$cnt)
interval <- NULL
if (!is.null(model$fit)) {
  if (inherits(model$fit, "negbin")) {
    lower <- qnbinom(.025, mu = predicted, size = model$fit$theta)
    upper <- qnbinom(.975, mu = predicted, size = model$fit$theta)
  } else { lower <- qpois(.025, predicted); upper <- qpois(.975, predicted) }
  test_predictions$lower95 <- lower
  test_predictions$upper95 <- upper
  interval <- tibble::tibble(nominal_coverage = .95, observed_test_coverage = mean(test$cnt >= lower & test$cnt <= upper),
    mean_width = mean(upper - lower), interpretation = "Conditional count distribution; excludes parameter and weather forecast uncertainty")
}
features <- if (is.null(model$fit)) c("hour", "day_type") else all.vars(delete.response(terms(model$fit)))
stopifnot(!any(c("cnt", "casual", "registered") %in% features))
error_by_hour <- test_predictions %>% group_by(hr) %>% summarise(observations = n(),
  mae = mean(abs(error)), mean_bias = mean(error), .groups = "drop")
error_by_weather <- test_predictions %>% group_by(weather) %>% summarise(observations = n(),
  mae = mean(abs(error)), mean_bias = mean(error), .groups = "drop")
profiles <- hourly %>% group_by(hr, day_type) %>% summarise(observations = n(), mean_rentals = mean(cnt), .groups = "drop")
weekday_hour <- hourly %>% group_by(weekday, hr) %>% summarise(observations = n(), mean_rentals = mean(cnt), .groups = "drop") %>%
  mutate(weekday_name = factor(weekday, levels = 0:6, labels = c("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")))
monthly_mix <- hourly %>% mutate(month = lubridate::floor_date(date, "month")) %>% group_by(month) %>%
  summarise(casual = sum(casual), registered = sum(registered), .groups = "drop") %>%
  pivot_longer(c(casual, registered), names_to = "type", values_to = "rentals")
reference_pool <- filter(train, hr == 17, workingday == 1)
reference <- reference_pool[ceiling(nrow(reference_pool) / 2), , drop = FALSE]
reference$temp <- median(train$temp); reference$hum <- median(train$hum); reference$windspeed <- median(train$windspeed)
response <- bind_rows(lapply(levels(hourly$weather), function(w) {
  frame <- reference[rep(1, 80), ]; frame$temp <- seq(min(train$temp), max(train$temp), length.out = 80)
  frame$weather <- factor(w, levels = levels(hourly$weather))
  tibble::tibble(temp = frame$temp, weather = w, predicted = predict_demand(model, frame))
}))
dispersion <- if (!is.null(model$fit)) sum(residuals(model$fit, type = "pearson")^2) / model$fit$df.residual else NA_real_
daily_errors <- test_predictions %>% group_by(date) %>% summarise(rows = n(),
  selected_abs_error = sum(abs(actual - predicted)), reference_abs_error = sum(abs(actual - baseline)), .groups = "drop")
set.seed(20261006)
day_count <- nrow(daily_errors)
bootstrap_delta <- replicate(1000, {
  starts <- sample.int(day_count - 6L, ceiling(day_count / 7), replace = TRUE)
  indices <- unlist(lapply(starts, function(s) s:(s + 6L)))[seq_len(day_count)]
  block <- daily_errors[indices, ]
  sum(block$reference_abs_error - block$selected_abs_error) / sum(block$rows)
})
bootstrap <- tibble::tibble(metric = "Reference MAE minus selected MAE (rentals/hour)",
  observed_difference = test_scores$mae[2] - test_scores$mae[1],
  lower95 = unname(quantile(bootstrap_delta, .025)), upper95 = unname(quantile(bootstrap_delta, .975)),
  method = "1000 moving 7-day block resamples of final-test paired errors; seed 20261006")
metrics <- list(hourly_rows = nrow(hourly), daily_rows = nrow(daily), total_rentals = sum(hourly$cnt),
  source_start = as.character(min(hourly$date)), source_end = as.character(max(hourly$date)),
  missing_source_hours = nrow(daily) * 24 - nrow(hourly), incomplete_days = sum(coverage$observed_hours < 24),
  selected_model = validation$selected, test_rows = nrow(test), test_start = as.character(min(test$date)), test_end = as.character(max(test$date)),
  test_mae = test_scores$mae[1], baseline_mae = test_scores$mae[2], test_wape = test_scores$wape[1],
  mae_improvement_vs_reference = 1 - test_scores$mae[1] / test_scores$mae[2],
  pearson_dispersion = dispersion, registered_rental_share = sum(hourly$registered) / sum(hourly$cnt))
results <- list(metrics = metrics, hourly = hourly, daily = daily, coverage = coverage, validation = validation,
  test_scores = test_scores, test_predictions = test_predictions, profiles = profiles, weekday_hour = weekday_hour,
  monthly_mix = monthly_mix, error_by_hour = error_by_hour, error_by_weather = error_by_weather,
  response = response, response_reference_date = reference$date, intervals = interval, bootstrap = bootstrap)
saveRDS(results, "data/processed/results.rds")
saveRDS(model, "data/processed/model.rds")
tables <- c("coverage", "test_scores", "test_predictions", "profiles", "weekday_hour", "monthly_mix", "error_by_hour", "error_by_weather", "response")
for (name in tables) readr::write_csv(results[[name]], file.path("reports/tables", paste0(name, ".csv")))
readr::write_csv(validation$scores, "reports/tables/validation_folds.csv")
readr::write_csv(validation$ranking, "reports/tables/model_selection.csv")
if (!is.null(interval)) readr::write_csv(interval, "reports/tables/interval_coverage.csv")
readr::write_csv(bootstrap, "reports/tables/paired_error_bootstrap.csv")
jsonlite::write_json(metrics, "reports/tables/metrics.json", pretty = TRUE, auto_unbox = TRUE, digits = NA)
demand_charts(results)
jsonlite::write_json(list(metrics = metrics, daily = select(daily, date, cnt, casual, registered),
  observations = select(hourly, date, hr, workingday, weather, cnt, casual, registered),
  scores = test_scores, predictions = test_predictions, validation = validation$ranking,
  weather_errors = error_by_weather, intervals = interval), "site/data.json", dataframe = "rows", auto_unbox = TRUE, digits = 6)
jsonlite::write_json(list(passed = TRUE, rows = nrow(hourly), daily_rows = nrow(daily),
  checks = "Unique day-hour keys, target decomposition, hourly-daily reconciliation, missingness, chronological folds and excluded leakage features",
  selected_features = features), "reports/verification.json", pretty = TRUE, auto_unbox = TRUE)
writeLines(capture.output(sessionInfo()), "reports/session-info.txt")
cat(jsonlite::toJSON(metrics, auto_unbox = TRUE, pretty = TRUE), "\n")
