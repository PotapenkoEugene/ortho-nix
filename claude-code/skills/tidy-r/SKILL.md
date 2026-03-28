---
name: tidy-r
description: Write idiomatic, tidy R code following community best practices. Use when writing R scripts, data analysis, ggplot2 visualizations, tidyverse pipelines, data.table operations, project structure, or reviewing existing R code for style and correctness. Covers tidyverse idioms, ggplot2 grammar, data.table performance patterns, here::here project structure, and common anti-patterns to avoid.
metadata:
  version: "1.0"
---

# Tidy R Programming

Write idiomatic R code following the tidyverse style guide and community best practices. This skill covers data wrangling, visualization, project structure, and performance patterns.

## Quick Start

```r
# Minimal working example — tidy pipeline
library(tidyverse)
library(here)

# Load
df <- read_csv(here("data", "raw", "measurements.csv"))

# Wrangle
result <- df |>
  filter(!is.na(value), group %in% c("A", "B")) |>
  group_by(group, timepoint) |>
  summarise(
    mean_val = mean(value),
    sd_val   = sd(value),
    n        = n(),
    .groups  = "drop"
  ) |>
  mutate(se = sd_val / sqrt(n))

# Plot
ggplot(result, aes(x = timepoint, y = mean_val, color = group)) +
  geom_line() +
  geom_errorbar(aes(ymin = mean_val - se, ymax = mean_val + se), width = 0.2) +
  scale_color_brewer(palette = "Set1") +
  labs(x = "Timepoint", y = "Mean value", color = "Group") +
  theme_bw()
```

## Core Principles

1. **Use the native pipe `|>`** (R 4.1+) instead of `%>%`. Reserve `%>%` only when you need its special features (`.` placeholder, etc.).
2. **Names are snake_case** — variables, functions, file names. Never use dots in function names (`my.function` → `my_function`).
3. **Explicit over implicit** — spell out argument names past the first two positional args.
4. **Tidy data** — one observation per row, one variable per column. Reshape early with `tidyr::pivot_longer/wider`.
5. **No global side effects** — functions take inputs, return outputs. No `<<-` in production code.

## When to Use What

| Task | Package |
|------|---------|
| Data wrangling < 1M rows | `dplyr` + `tidyr` |
| Data wrangling ≥ 1M rows | `data.table` |
| Visualization | `ggplot2` |
| String manipulation | `stringr` |
| Date/time | `lubridate` |
| File paths | `here` |
| Functional iteration | `purrr` |
| Reading/writing CSVs | `readr` |
| Excel files | `readxl` / `writexl` |
| Statistical tests | `stats` (base) + `broom` for tidy output |

## Reference Files

| File | Contents |
|------|----------|
| [style-guide.md](references/style-guide.md) | Naming, spacing, indentation, pipes, tidy eval, assignment |
| [data-wrangling.md](references/data-wrangling.md) | dplyr/tidyr idioms, joins, pivots, `across()`, list-columns, data.table |
| [visualization.md](references/visualization.md) | ggplot2 grammar, themes, scales, facets, annotations, publication-ready |
| [project-structure.md](references/project-structure.md) | File layout, `here::here`, nix vs renv, scripts vs functions |
| [performance.md](references/performance.md) | data.table idioms, vectorization, profiling, memory, parallel |

## Common Anti-Patterns

```r
# WRONG: attach() pollutes global namespace
attach(df)

# RIGHT: use with() or tidy pipelines
df |> pull(column)

# WRONG: growing vectors in a loop
result <- c()
for (i in seq_len(n)) result <- c(result, compute(i))

# RIGHT: vectorize or use purrr
result <- purrr::map_dbl(seq_len(n), compute)

# WRONG: T / F instead of TRUE / FALSE (T and F can be overwritten)
if (T) ...

# RIGHT:
if (TRUE) ...

# WRONG: setwd() hardcodes paths
setwd("/home/user/project/data")
read_csv("file.csv")

# RIGHT: use here::here
read_csv(here("data", "file.csv"))

# WRONG: 1:length(x) breaks on empty vectors
for (i in 1:length(x)) ...

# RIGHT:
for (i in seq_along(x)) ...
```
