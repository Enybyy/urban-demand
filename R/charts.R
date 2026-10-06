demand_theme <- function() theme_minimal(base_size = 12) + theme(
  plot.title = element_text(face = "bold", size = 19, colour = "#24352C"),
  plot.subtitle = element_text(colour = "#57635C", margin = margin(b = 14)),
  plot.caption = element_text(hjust = 0, colour = "#57635C", margin = margin(t = 14)),
  panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
  plot.background = element_rect(fill = "white", colour = NA),
  plot.margin = margin(18, 22, 18, 18), legend.position = "bottom")

demand_charts <- function(x) {
  month_labels <- function(d) paste(c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")[as.integer(format(d, "%m"))], format(d, "%Y"))
  cap <- "Source: UCI Bike Sharing | Capital Bikeshare 2011-2012 | Historical system-level observations"
  val <- x$validation$ranking
  errors <- x$test_predictions
  daily <- errors %>% group_by(date) %>% summarise(actual = sum(actual), predicted = sum(predicted), .groups = "drop") %>%
    tidyr::pivot_longer(c(actual, predicted), names_to = "series", values_to = "rentals")
  charts <- list(
    daily_demand = ggplot(x$daily, aes(date, cnt)) + geom_line(colour = "#276749", linewidth = .55) +
      geom_vline(xintercept = as.Date("2012-10-01"), linetype = "dashed", colour = "#7B61A8") +
      labs(title = "Two years of observed bicycle demand", subtitle = "Daily totals | Dashed line starts the final model test window",
        x = NULL, y = "Recorded rentals per day", caption = cap) + demand_theme(),
    hourly_profiles = ggplot(x$profiles, aes(hr, mean_rentals, colour = day_type)) + geom_line(linewidth = 1) +
      scale_colour_manual(values = c("#7B61A8", "#276749"), name = NULL) +
      labs(title = "Working days and weekends have different peaks", subtitle = "Mean rentals per observed hour; missing hours are not filled with zero",
        x = "Hour", y = "Mean recorded rentals", caption = cap) + demand_theme(),
    weekday_heatmap = ggplot(x$weekday_hour, aes(hr, weekday_name, fill = mean_rentals)) +
      geom_tile(colour = "white", linewidth = .3) + scale_fill_gradient(low = "#F3F7F3", high = "#4C9270", name = "Mean rentals",
        guide = guide_colourbar(barwidth = grid::unit(9, "cm"), barheight = grid::unit(.35, "cm"))) +
      labs(title = "Demand by weekday and hour", subtitle = "Each cell uses only observed hours",
        x = "Hour", y = NULL, caption = cap) + demand_theme(),
    weather_demand = ggplot(x$hourly, aes(weather, cnt, fill = weather)) +
      geom_boxplot(outlier.shape = NA, width = .55) + coord_cartesian(ylim = c(0, 800)) +
      scale_fill_manual(values = c("#276749", "#9BBBAA", "#7B61A8"), guide = "none") +
      labs(title = "Weather groups have different observed distributions", subtitle = "Unadjusted associations also reflect season, calendar and hour composition",
        x = NULL, y = "Recorded rentals per hour", caption = cap) + demand_theme(),
    rider_mix = ggplot(x$monthly_mix, aes(month, rentals, fill = type)) + geom_col(width = 23) +
      scale_fill_manual(values = c(casual = "#9BBBAA", registered = "#276749"), name = NULL) +
      scale_y_continuous(labels = scales::comma) +
      labs(title = "Registered and casual rental volumes", subtitle = "These counts are outcomes and are excluded from prediction features",
        x = NULL, y = "Recorded rentals", caption = cap) + demand_theme(),
    model_validation = ggplot(val, aes(reorder(model, mean_validation_mae), mean_validation_mae)) +
      geom_col(fill = "#7B61A8", width = .6) + coord_flip() +
      labs(title = "Model selection uses earlier time windows", subtitle = "Mean MAE over three expanding-window validation folds; lower is better",
        x = NULL, y = "Mean absolute error (rentals/hour)", caption = cap) + demand_theme(),
    heldout_daily = ggplot(daily, aes(date, rentals, colour = series)) + geom_line(linewidth = .7) +
      scale_colour_manual(values = c(actual = "#276749", predicted = "#7B61A8"), name = NULL) +
      labs(title = "Daily totals during the final test", subtitle = "Hourly predictions summed by day | Observed weather inputs | October-December 2012",
        x = NULL, y = "Recorded / predicted rentals", caption = cap) + demand_theme(),
    residual_by_hour = ggplot(x$error_by_hour, aes(hr, mean_bias)) + geom_hline(yintercept = 0, colour = "#8C9890") +
      geom_col(fill = "#7B61A8") + labs(title = "Prediction bias changes with the hour",
        subtitle = "Final test only | Positive values indicate overprediction", x = "Hour", y = "Mean predicted minus actual",
        caption = cap) + demand_theme(),
    temperature_response = ggplot(x$response, aes(temp, predicted, colour = weather)) + geom_line(linewidth = 1) +
      scale_colour_manual(values = c("#276749", "#9BBBAA", "#7B61A8"), name = NULL) +
      labs(title = "Conditional temperature response", subtitle = "Reference working day at 17:00; humidity and wind at training medians",
        x = "Normalised temperature (source scale)", y = "Predicted rentals per hour", caption = cap) + demand_theme(),
    hour_coverage = ggplot(x$coverage, aes(date, observed_hours)) + geom_col(fill = "#9BBBAA", width = 1) +
      geom_hline(yintercept = 24, linetype = "dashed", colour = "#57635C") +
      labs(title = "Hourly observation coverage", subtitle = "Missing source hours remain missing; they are not assumed to have zero demand",
        x = NULL, y = "Observed hours per day", caption = cap) + demand_theme())
  for (name in c("daily_demand", "rider_mix", "heldout_daily", "hour_coverage")) charts[[name]] <- charts[[name]] + scale_x_date(labels = month_labels)
  for (name in names(charts)) ggsave(file.path("reports/figures", paste0(name, ".png")), charts[[name]],
    width = 11, height = 6.5, dpi = 160, bg = "white")
}
