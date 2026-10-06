# Methodology

## Source and quality

The source is UCI Bike Sharing by Hadi Fanaee-T (2013), DOI 10.24432/C5W894, licensed CC BY 4.0. The archive contains 17,379 hourly observations and 731 daily observations for Capital Bikeshare, Washington DC, in 2011-2012. The archive README confirms these counts; the landing page's instance summary differs from the actual hourly file. Per-file SHA-256 checks protect the original CSVs and README.

Keys are recorded calendar date plus hour. The pipeline checks unique hourly and daily keys, missing values, normalised covariate bounds, nonnegative counts and exact target decomposition (`casual + registered = cnt`). Summing the observed hourly counts reproduces every daily total. Across the calendar grid there are 165 absent hour records on 76 days. Missing hours are not imputed as zero; their cause is not established by the file.

Timestamps are constructed as source wall-clock labels stored with UTC to prevent local-machine timezone shifts. This is not a claim that the source timestamps were UTC. Calendar definitions come from the supplied file. Hourly and daily weather transformations are not mixed, and temperature remains on the source's normalised scale.

## Prediction question and feature availability

The target is recorded hourly total rentals. Predictors are hour, working-day type, weekday, grouped weather, normalised temperature, humidity, wind, an elapsed-time trend and annual/semiannual harmonics. Severe weather codes 3 and 4 are pooled as Adverse because code 4 is sparse. Apparent temperature is excluded to avoid duplicating the main temperature covariate.

`cnt`, `casual` and `registered` are never predictors. Registered and casual counts are shown only as historical outcomes. There are no future totals, lags generated with future records or transformations fitted on the test set. Spline bases are fitted within each training period and applied through R's predict method.

Observed contemporaneous weather is supplied at evaluation time. The result is an out-of-time, observed-weather count estimation study, not a verified advance forecast using weather forecasts. Production forecasting requires weather forecast inputs available at the decision time and a new availability-aware evaluation.

## Validation design

| Fold | Training observations | Validation window |
| --- | --- | --- |
| 1 | Dates before 1 January 2012 | January-March 2012 |
| 2 | Dates before 1 April 2012 | April-June 2012 |
| 3 | Dates before 1 July 2012 | July-September 2012 |

The model with lowest mean validation MAE is selected before fitting on all dates before 1 October 2012. October-December 2012 is the final untouched test window. No post-test feature adjustment is made to improve its reported score.

Four candidates are compared: a training mean for each hour/day-type cell, a Poisson log-link regression, a negative-binomial log-link regression and a negative-binomial regression with natural splines for temperature (4 df) and humidity (3 df). Regression candidates include hour-by-day-type interaction. The reference falls back to the overall training mean for an unavailable cell.

MAE and RMSE are in rentals per hour. WAPE divides total absolute error by actual total rentals. Bias is predicted minus actual; positive means overprediction. Percentage errors are not averaged per hour, which avoids unstable division by small hourly counts.

## Uncertainty and model diagnostics

Conditional 95% count-distribution intervals use the fitted Poisson or negative-binomial quantiles. They exclude parameter estimation uncertainty and weather forecast error. Actual test coverage is reported; a nominal 95% label does not establish calibration. Errors are also reported by hour and weather group to expose uneven performance.

A paired moving-block bootstrap estimates uncertainty in the test-window MAE difference between the selected model and reference. It resamples contiguous seven-day blocks 1,000 times with seed 20261006 and weights observations by their recorded hour counts. It is conditional on this historical test period and a seven-day dependence assumption, not a guarantee for other cities or years.

Conditional response plots use a real training calendar reference at 17:00 on a working day. Humidity and wind are fixed at training medians; temperature varies over training support and weather categories are compared. These plots explain the fitted function. They do not estimate causal weather effects.

## Operational limits

The data contains no station capacities, stock-outs, denied rentals, travel routes or rebalancing costs. Recorded demand may itself be constrained by availability. System totals cannot prescribe inventory at a station. Recommended uses are workload profiling, transparent comparison of models and designing a forecasting/rebalancing pilot with richer data.
