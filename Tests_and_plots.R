library(ggplot2)

data <- read.csv("C:/Uni/ATP/Project/ATPFinalProject/runs/Rn1/combined.csv",
                 , stringsAsFactors = FALSE)

names(data) <- make.names(names(data))

# Set proper column names (use the header from line 6)
colnames(data) <- c("run_number", "force_stop", "simulation_time", "num_humans", 
                    "num_zombies", "max_group_size", "step", "count_humans", 
                    "count_zombies", "human_deaths_combat", "zombie_deaths", 
                    "ticks", "initial_loners", "initial_groupers", "alive_loners", 
                    "alive_groupers")

# Convert to numeric (important step)
numeric_columns <- c("step", "alive_loners", "initial_loners", "alive_groupers", "initial_groupers")
data[numeric_columns] <- lapply(data[numeric_columns], as.numeric)

print(names(data))

# Calculate survival rates from your dataset
data$loner_survival_rate <- data$alive_loners / data$initial_loners
data$grouper_survival_rate <- data$alive_groupers / data$initial_groupers
data$total_survival_rate <- data$'count_humans' / data$'num_humans'

# Calculate raw deaths for each type
data$loner_deaths <- data$initial_loners - data$alive_loners
data$grouper_deaths <- data$initial_groupers - data$alive_groupers


# Correlation between time and loner survival
cor.test(data$step, data$loner_survival_rate)

# Linear model for loners
loner_model <- lm(loner_survival_rate ~ `step` + `num_zombies` + `max_group_size`, data = data)
summary(loner_model)

# Kaplan-Meier style analysis (grouping by time intervals)
data$time_category <- cut(data$step, breaks = 4)
anova_loners <- aov(loner_survival_rate ~ time_category, data = data)
summary(anova_loners)

# Basic correlation plots

# Plot 1: Loner survival vs time
ggplot(data, aes(x = step, y = loner_survival_rate)) +
  geom_point(alpha = 0.6, color = "red") +
  geom_smooth(method = "lm", color = "darkred", se = TRUE) +
  labs(title = "Loner Survival Rate vs Simulation Time",
       x = "Simulation Steps",
       y = "Loner Survival Rate") +
  theme_minimal()

# Plot 2: Grouper survival vs time
ggplot(data, aes(x = step, y = grouper_survival_rate)) +
  geom_point(alpha = 0.6, color = "blue") +
  geom_smooth(method = "lm", color = "darkblue", se = TRUE) +
  labs(title = "Grouper Survival Rate vs Simulation Time",
       x = "Simulation Steps",
       y = "Grouper Survival Rate") +
  theme_minimal()

# Plot 3: Both strategies on same plot
ggplot(data) +
  geom_point(aes(x = step, y = loner_survival_rate), color = "red", alpha = 0.5) +
  geom_smooth(aes(x = step, y = loner_survival_rate), method = "lm", color = "red", se = TRUE) +
  geom_point(aes(x = step, y = grouper_survival_rate), color = "blue", alpha = 0.5) +
  geom_smooth(aes(x = step, y = grouper_survival_rate), method = "lm", color = "blue", se = TRUE) +
  labs(title = "Survival Rates vs Time: Loners (Red) vs Groupers (Blue)",
       x = "Simulation Steps",
       y = "Survival Rate") +
  theme_minimal()

