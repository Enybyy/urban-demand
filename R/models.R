demand_features <- function(data, origin = as.Date("2011-01-01")) {
  data %>% mutate(date = as.Date(dteday),
    timestamp = as.POSIXct(paste(dteday, sprintf("%02d:00:00", hr)), tz = "UTC"),
    hour = factor(hr, levels = 0:23),
    day_type = factor(ifelse(workingday == 1, "Working day", "Weekend or holiday")),
    weekday_f = factor(weekday, levels = 0:6),
    weather = factor(ifelse(weathersit == 1, "Clear", ifelse(weathersit == 2, "Mist", "Adverse")),
      levels = c("Clear", "Mist", "Adverse")),
    trend = as.numeric(date - origin) / 365.25,
    annual_sin = sin(2 * pi * lubridate::yday(date) / 365.25),
    annual_cos = cos(2 * pi * lubridate::yday(date) / 365.25),
    semiannual_sin = sin(4 * pi * lubridate::yday(date) / 365.25),
    semiannual_cos = cos(4 * pi * lubridate::yday(date) / 365.25))
}

model_formula <- function(name) {
  if (name == "Spline negative binomial") {
    cnt ~ hour * day_type + weekday_f + weather + splines::ns(temp, df = 4) +
      splines::ns(hum, df = 3) + windspeed + trend + annual_sin + annual_cos + semiannual_sin + semiannual_cos
  } else {
    cnt ~ hour * day_type + weekday_f + weather + temp + hum + windspeed +
      trend + annual_sin + annual_cos + semiannual_sin + semiannual_cos
  }
}

fit_demand_model <- function(name, train) {
  if (name == "Hour and day-type reference") {
    list(name = name, cells = train %>% group_by(hour, day_type) %>% summarise(prediction = mean(cnt), .groups = "drop"),
      fallback = mean(train$cnt))
  } else if (name == "Poisson") {
    list(name = name, fit = glm(model_formula(name), data = train, family = poisson(), control = glm.control(maxit = 100)))
  } else {
    list(name = name, fit = MASS::glm.nb(model_formula(name), data = train, control = glm.control(maxit = 100)))
  }
}

predict_demand <- function(model, data) {
  if (model$name == "Hour and day-type reference") {
    result <- left_join(data %>% mutate(order_row = row_number()), model$cells, by = c("hour", "day_type")) %>%
      arrange(order_row)
    coalesce(result$prediction, model$fallback)
  } else pmax(0, as.numeric(predict(model$fit, newdata = data, type = "response")))
}

error_metrics <- function(actual, predicted) {
  stopifnot(length(actual) == length(predicted), all(is.finite(predicted)), all(predicted >= 0))
  tibble::tibble(rows = length(actual), mae = mean(abs(actual - predicted)),
    rmse = sqrt(mean((actual - predicted)^2)), wape = sum(abs(actual - predicted)) / sum(actual),
    mean_bias = mean(predicted - actual))
}

validate_models <- function(hourly) {
  candidates <- c("Hour and day-type reference", "Poisson", "Negative binomial", "Spline negative binomial")
  cuts <- as.Date(c("2012-01-01", "2012-04-01", "2012-07-01", "2012-10-01"))
  scores <- list()
  prediction_store <- list()
  index <- 1L
  for (fold in 1:3) {
    train <- filter(hourly, date < cuts[fold])
    val <- filter(hourly, date >= cuts[fold], date < cuts[fold + 1])
    stopifnot(max(train$date) < min(val$date))
    for (name in candidates) {
      cat("Validation fold", fold, "-", name, "\n")
      model <- fit_demand_model(name, train)
      pred <- predict_demand(model, val)
      scores[[index]] <- error_metrics(val$cnt, pred) %>% mutate(model = name, fold = fold,
        train_end = max(train$date), validation_start = min(val$date), validation_end = max(val$date))
      prediction_store[[index]] <- tibble::tibble(model = name, fold = fold, timestamp = val$timestamp,
        actual = val$cnt, predicted = pred)
      index <- index + 1L
    }
  }
  scores <- bind_rows(scores)
  ranking <- scores %>% group_by(model) %>% summarise(mean_validation_mae = mean(mae),
    mean_validation_rmse = mean(rmse), .groups = "drop") %>% arrange(mean_validation_mae, model)
  list(scores = scores, ranking = ranking, selected = ranking$model[1], predictions = bind_rows(prediction_store))
}
