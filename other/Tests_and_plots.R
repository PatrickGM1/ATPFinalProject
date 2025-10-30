# Load libraries
library(ggplot2)
library(dplyr)
library(tidyr)

# Read data
data <- read.csv(file.choose()            
                 , skip = 6, stringsAsFactors = FALSE)

# Clean up column names
names(data) <- make.names(names(data))

# Set proper column names (use the header from line 6)
colnames(data) <- c("run_number", "force_stop", "simulation_time",
                    "num_humans", "num_zombies", "max_group_size", "step",
                    "count_humans", "count_zombies", "human_deaths_combat",
                    "zombie_deaths", "ticks", "initial_loners",
                    "initial_groupers", "alive_loners", "alive_groupers",
                    "mean_fear_loners", "mean_fear_groupers")

# Convert key numeric columns
numeric_cols <- c("step", "alive_loners", "initial_loners",
                  "alive_groupers", "initial_groupers",
                  "num_humans", "num_zombies",
                  "mean_fear_loners", "mean_fear_groupers")
data[numeric_cols] <- lapply(data[numeric_cols], as.numeric)

# Calculate survivability
data <- data %>%
  mutate(loner_survival = alive_loners / initial_loners,
         grouper_survival = alive_groupers / initial_groupers,
         total_survival = count_humans / num_humans)

# ----------  Survivability vs Number of Zombies ----------

# Create nicer bins with round numbers
heat_data <- data %>%
  select(num_zombies, loner_survival, grouper_survival) %>%
  # Create cleaner bins with custom labels
  mutate(zombie_bin = cut(num_zombies, 
                          breaks = seq(0, max(num_zombies), by = 10),
                          include.lowest = TRUE)) %>%
  group_by(zombie_bin) %>%
  summarize(across(c(loner_survival, grouper_survival), 
                   mean, na.rm = TRUE)) %>%
  pivot_longer(cols = c(loner_survival, grouper_survival),
               names_to = "type", values_to = "survival") %>%
  # Clean up type labels
  mutate(type = case_when(
    type == "loner_survival" ~ "Loners",
    type == "grouper_survival" ~ "Groupers"
  ))

# Create cleaner bin labels
bin_labels <- levels(heat_data$zombie_bin)
clean_labels <- gsub("\\(|\\]", "", bin_labels) 
clean_labels <- gsub(",", " - ", clean_labels)   



ggplot(heat_data, aes(x = zombie_bin, y = survival, fill = type)) +
  geom_col(position = "dodge") +
  scale_x_discrete(labels = clean_labels) +
  scale_fill_manual(values = c("Loners" = "steelblue", "Groupers" = "tomato")) +
  labs(title = "Average Survival Rate by Zombie Count Range",
       x = "Number of Zombies",
       y = "Average Survival Rate",
       fill = "Human Type") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# ---------- Fear over Survivability ----------
# Create separate data frames for loners and groupers for clearer plotting
loner_fear_data <- data %>%
  select(survival = loner_survival, fear = mean_fear_loners) %>%
  mutate(type = "Loners") %>%
  filter(!is.na(survival), !is.na(fear))

grouper_fear_data <- data %>%
  select(survival = grouper_survival, fear = mean_fear_groupers) %>%
  mutate(type = "Groupers") %>%
  filter(!is.na(survival), !is.na(fear))

# Combine both types
fear_data_clean <- bind_rows(loner_fear_data, grouper_fear_data)

# Option 1: Faceted histograms for fear distribution by survival ranges
fear_data_clean <- fear_data_clean %>%
  mutate(survival_bin = cut(survival, 
                            breaks = seq(0, 1, by = 0.2),
                            labels = c("0-20%", "20-40%", "40-60%", "60-80%", "80-100%")))

# For Loners
ggplot(loner_fear_data, aes(x = fear)) +
  geom_histogram(fill = "blue", alpha = 0.7, bins = 30) +
  facet_wrap(~cut(survival, breaks = 4), scales = "free_y") +
  labs(title = "Loners: Fear Distribution by Survival Rate Groups",
       x = "Fear Level",
       y = "Frequency") +
  theme_minimal()

# For Groupers
ggplot(grouper_fear_data, aes(x = fear)) +
  geom_histogram(fill = "red", alpha = 0.7, bins = 30) +
  facet_wrap(~cut(survival, breaks = 4), scales = "free_y") +
  labs(title = "Groupers: Fear Distribution by Survival Rate Groups",
       x = "Fear Level",
       y = "Frequency") +
  theme_minimal()

# ----------  Human/Zombie Population over Time ----------
pop_data_avg <- data %>%
  group_by(step) %>%
  summarize(
    avg_humans = mean(count_humans, na.rm = TRUE),
    avg_zombies = mean(count_zombies, na.rm = TRUE),
    sd_humans = sd(count_humans, na.rm = TRUE),
    sd_zombies = sd(count_zombies, na.rm = TRUE)
  ) %>%
  pivot_longer(cols = c(avg_humans, avg_zombies),
               names_to = "species", values_to = "population") %>%
  mutate(species = case_when(
    species == "avg_humans" ~ "Humans",
    species == "avg_zombies" ~ "Zombies"
  ))

# Plot average populations with confidence intervals
ggplot(pop_data_avg, aes(x = step, y = population, color = species)) +
  geom_line(size = 1.2) +
  labs(title = "Average Population Over Time (All Runs)",
       x = "Simulation Step", 
       y = "Average Population Size", 
       color = "Species") +
  theme_minimal() +
  scale_color_manual(values = c("Humans" = "blue", "Zombies" = "red"))



set.seed(123) # for reproducibility
sample_runs <- sample(unique(data$run_number), min(5, length(unique(data$run_number))))

pop_data_sample <- data %>%
  filter(run_number %in% sample_runs) %>%
  select(run_number, step, count_humans, count_zombies) %>%
  pivot_longer(cols = c(count_humans, count_zombies),
               names_to = "species", values_to = "population") %>%
  mutate(species = case_when(
    species == "count_humans" ~ "Humans",
    species == "count_zombies" ~ "Zombies"
  ))

# Plot sampled runs
ggplot(pop_data_sample, aes(x = step, y = population, color = species, group = interaction(run_number, species))) +
  geom_line(alpha = 0.7, size = 0.8) +
  labs(title = "Population Over Time (Sample of 5 Runs)",
       x = "Simulation Step", 
       y = "Population Size", 
       color = "Species") +
  theme_minimal() +
  scale_color_manual(values = c("Humans" = "blue", "Zombies" = "red"))

