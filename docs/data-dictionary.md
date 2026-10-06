# Data dictionary

| Field | Meaning and use |
| --- | --- |
| dteday, hr | Recorded calendar day and hour; unique observation key |
| cnt | Total recorded hourly rentals; prediction target |
| casual, registered | Components of cnt; outcomes, excluded from predictors |
| workingday | 1 for a nonholiday weekday; used as day type |
| weekday | Source weekday code 0-6 |
| weathersit | Weather categories; 3 and 4 pooled for modelling |
| temp | Normalised temperature; original source scale retained |
| hum | Normalised humidity; 0-1 source scale |
| windspeed | Normalised wind speed; source scale retained |
| atemp | Apparent temperature; excluded to reduce redundant features |
| season, yr, mnth | Source calendar descriptors; used in exploration, not alongside redundant calendar predictors |
| instant | Source row index; not a prediction feature |

Derived fields include hour factor, day-type factor, grouped weather, trend and calendar harmonics. All definitions and train/test boundaries are recorded in the methodology.
