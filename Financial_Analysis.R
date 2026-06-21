setwd('/Users/lavikasingh/Documents/SFU/Hackathons/Beedie RBC 2026 Hackathon/hackathon files')

# 0. Setup — Load Libraries and Data

library(tidyverse)    # dplyr, ggplot2, tidyr, readr, purrr
library(lubridate)    # date handling
library(scales)       # axis formatting
library(corrplot)     # correlation matrix
library(RColorBrewer) # colour palettes



sensor      <- read_csv("daily_sensor_readings.csv")
costs       <- read_csv("daily_input_costs.csv")
plots       <- read_csv("plots.csv")
farms       <- read_csv("farms.csv")
greenhouses <- read_csv("greenhouses.csv")
inputs      <- read_csv("input_applications.csv")
season      <- read_csv("season_summary.csv")
scouting    <- read_csv("scouting_observations.csv")
prices      <- read_csv("market_and_input_prices.csv")

# Parse dates
sensor   <- sensor   %>% mutate(date = as.Date(date))
costs    <- costs    %>% mutate(date = as.Date(date))
inputs   <- inputs   %>% mutate(date = as.Date(date))
scouting <- scouting %>% mutate(date = as.Date(date))
prices   <- prices   %>% mutate(date = as.Date(date))

# Add time fields
sensor <- sensor %>%
  mutate(
    week_num   = isoweek(date),
    year       = year(date),
    month      = month(date, label = TRUE),
    week_label = paste0("Week ", week_num)
  )

cat("Data loaded successfully\n")
cat("Sensor rows     :", nrow(sensor), "\n")
cat("Date range      :", as.character(min(sensor$date)),
    "to", as.character(max(sensor$date)), "\n")
cat("Unique plots    :", n_distinct(sensor$plot_id), "\n")
cat("Unique weeks    :", n_distinct(sensor$week_num), "\n")






# 4. Financial Analysis

## 4.1 Season Profitability by Crop


cat("=== Season Financial Summary by Crop ===\n")
season %>%
  left_join(plots %>% select(plot_id, crop, treatment), by = "plot_id") %>%
  group_by(crop) %>%
  summarise(
    avg_yield        = round(mean(season_yield_kg_m2), 2),
    avg_marketable   = round(mean(marketable_ratio) * 100, 1),
    avg_revenue      = round(mean(season_revenue_cad), 0),
    avg_cost         = round(mean(total_cost_cad), 0),
    avg_profit       = round(mean(season_profit_cad), 0),
    avg_roi          = round(mean(season_roi), 3),
    avg_prec_benefit = round(mean(precision_benefit_cad), 0),
    .groups = "drop"
  ) %>%
  print()





# roi-by-treatment
season %>%
  left_join(plots %>% select(plot_id, treatment), by = "plot_id") %>%
  group_by(treatment) %>%
  summarise(avg_roi = mean(season_roi), .groups = "drop") %>%
  arrange(desc(avg_roi)) %>%
  ggplot(aes(x = reorder(treatment, avg_roi),
             y = avg_roi, fill = avg_roi)) +
  geom_col(alpha = 0.85) +
  geom_text(aes(label = round(avg_roi, 3)), hjust = -0.2, size = 3.5) +
  scale_fill_gradient(low = "#E05A4E", high = "#0F6E56") +
  coord_flip() +
  labs(
    title = "Average Season ROI by Treatment",
    x = "Treatment", y = "Average Season ROI"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none")





## 4.2 Market Price Trends


prices %>%
  ggplot(aes(x = date, y = price, colour = item)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.5, alpha = 0.6) +
  facet_wrap(~item, scales = "free_y", ncol = 2) +
  scale_colour_brewer(palette = "Set1") +
  labs(
    title = "Market Input Price Trends — Full Season",
    x = "Date", y = "Price (CAD)"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")




