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


# 3. Trend Analysis

## 3.1 Weekly Stress Trend


weekly_stress <- sensor %>%
  group_by(week_num) %>%
  summarise(
    avg_stress   = mean(plant_stress_index),
    max_stress   = max(plant_stress_index),
    alert_count  = sum(alert_flag),
    action_count = sum(action_taken, na.rm = TRUE),
    action_rate  = mean(action_taken[alert_flag == 1], na.rm = TRUE),
    .groups = "drop"
  )

ggplot(weekly_stress, aes(x = week_num)) +
  geom_ribbon(aes(ymin = avg_stress - 0.05, ymax = avg_stress + 0.05),
              fill = "#E05A4E", alpha = 0.2) +
  geom_line(aes(y = avg_stress), colour = "#E05A4E", linewidth = 1.2) +
  geom_point(aes(y = avg_stress, size = alert_count),
             colour = "#E05A4E", alpha = 0.7) +
  geom_hline(yintercept = 0.6, linetype = "dashed", colour = "darkred") +
  annotate("text", x = max(weekly_stress$week_num), y = 0.62,
           label = "High stress threshold", hjust = 1,
           size = 3, colour = "darkred") +
  scale_size_continuous(name = "Alert count", range = c(2, 8)) +
  scale_x_continuous(breaks = seq(7, 37, by = 2)) +
  labs(
    title    = "Weekly Average Plant Stress Index — Full Season",
    subtitle = "Point size = number of alerts that week",
    x = "Week Number", y = "Avg Plant Stress Index"
  ) +
  theme_minimal(base_size = 13)


## 3.2 Weekly Response Rate Trend

ggplot(weekly_stress, aes(x = week_num)) +
  geom_col(aes(y = alert_count / max(alert_count)),
           fill = "#AFA9EC", alpha = 0.5) +
  geom_line(aes(y = action_rate), colour = "#0F6E56", linewidth = 1.2) +
  geom_point(aes(y = action_rate), colour = "#0F6E56", size = 2) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "red") +
  scale_x_continuous(breaks = seq(7, 37, by = 2)) +
  labs(
    title    = "Weekly Action Rate vs Alert Volume — Full Season",
    subtitle = "Green line = action rate | Purple bars = alert volume | Red = 50% threshold",
    x = "Week Number",
    y = "Action Rate / Normalised Alert Count"
  ) +
  theme_minimal(base_size = 13)




## 3.3 Delay Impact on Stress Outcomes


delay_analysis <- sensor %>%
  filter(action_taken == 1, !is.na(post_action_stress_delta_3d)) %>%
  mutate(
    delay_bucket = case_when(
      action_delay_days == 0 ~ "Same day (0d)",
      action_delay_days == 1 ~ "1 day later",
      action_delay_days == 2 ~ "2 days later",
      TRUE ~ "Other"
    )
  ) %>%
  filter(delay_bucket != "Other") %>%
  group_by(delay_bucket) %>%
  summarise(
    count        = n(),
    avg_delta    = mean(post_action_stress_delta_3d),
    pct_improved = mean(post_action_stress_delta_3d < 0) * 100,
    .groups = "drop"
  ) %>%
  mutate(delay_bucket = factor(delay_bucket,
                               levels = c("Same day (0d)", "1 day later", "2 days later")))

cat("=== Delay Impact on Stress Outcomes ===\n")
print(delay_analysis)

ggplot(delay_analysis, aes(x = delay_bucket, y = avg_delta,
                           fill = delay_bucket)) +
  geom_col(alpha = 0.9, width = 0.6) +
  geom_text(aes(label = round(avg_delta, 3)),
            vjust = 1.5, colour = "white",
            fontface = "bold", size = 4.5) +
  geom_hline(yintercept = 0, colour = "black", linewidth = 0.8) +
  scale_fill_manual(values = c(
    "Same day (0d)" = "#0F6E56",
    "1 day later"   = "#F5A623",
    "2 days later"  = "#E05A4E"
  )) +
  labs(
    title    = "Impact of Response Speed on Stress Reduction",
    subtitle = "Same-day response is 78% more effective than a 2-day delay",
    x       = "Response Speed",
    y       = "Avg Stress Delta (3 days post-action)",
    caption = "Negative = stress improved. Green = best, Red = worst."
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none")



## 3.4 Season ROI by Action Rate Quartile


week14_summary <- sensor %>%
  filter(week_num == 14) %>%
  group_by(plot_id) %>%
  summarise(
    alert_count  = sum(alert_flag),
    action_count = sum(action_taken, na.rm = TRUE),
    max_stress   = max(plant_stress_index),
    avg_stress   = mean(plant_stress_index),
    avg_delay    = mean(action_delay_days, na.rm = TRUE),
    avg_delta    = mean(post_action_stress_delta_3d, na.rm = TRUE),
    days         = n(),
    .groups = "drop"
  ) %>%
  mutate(
    alert_rate      = alert_count / days,
    action_rate     = ifelse(alert_count > 0, action_count / alert_count, 0),
    action_quartile = ntile(action_rate, 4)
  ) %>%
  left_join(season, by = "plot_id")

roi_by_quartile <- week14_summary %>%
  group_by(action_quartile) %>%
  summarise(
    avg_roi           = round(mean(season_roi, na.rm = TRUE), 3),
    avg_prec_benefit  = round(mean(precision_benefit_cad, na.rm = TRUE), 0),
    n_plots           = n(),
    .groups = "drop"
  ) %>%
  mutate(label = c("Q1 Low","Q2","Q3","Q4 High"))

cat("=== Season ROI by Action Rate Quartile ===\n")
print(roi_by_quartile)

ggplot(roi_by_quartile, aes(x = label, y = avg_roi, fill = label)) +
  geom_col(alpha = 0.85, width = 0.6) +
  geom_text(aes(label = round(avg_roi, 3)), vjust = -0.5, size = 4) +
  scale_fill_manual(values = c(
    "Q1 Low" = "#E05A4E",
    "Q2"     = "#F5A623",
    "Q3"     = "#78C96B",
    "Q4 High"= "#0F6E56"
  )) +
  labs(
    title    = "Season ROI by Alert Response Rate Quartile — Week 14",
    subtitle = "Plots responding to more alerts earned higher end-of-season ROI",
    x = "Action Rate Quartile", y = "Average Season ROI"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none")



## 3.5 Precision vs Routine Actions


cat("=== Stress Outcomes: Precision vs Routine Actions ===\n")
inputs %>%
  left_join(
    sensor %>% select(date, plot_id, post_action_stress_delta_3d),
    by = c("date","plot_id")
  ) %>%
  filter(!is.na(post_action_stress_delta_3d)) %>%
  mutate(action_type = ifelse(
    is_precision_action == 1, "Precision", "Routine")) %>%
  group_by(action_type) %>%
  summarise(
    avg_delta    = round(mean(post_action_stress_delta_3d), 4),
    pct_improved = round(mean(post_action_stress_delta_3d < 0) * 100, 1),
    avg_cost     = round(mean(total_cost, na.rm = TRUE), 2),
    count        = n(),
    .groups = "drop"
  ) %>%
  print()
