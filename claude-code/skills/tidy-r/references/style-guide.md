# R Style Guide

Based on the [tidyverse style guide](https://style.tidyverse.org/). Key rules for writing readable, idiomatic R.

## Naming

```r
# Variables and functions: snake_case
day_one      <- 1
compute_mean <- function(x) mean(x)

# Constants: UPPER_SNAKE_CASE
MAX_ITER <- 1000

# Data frames: descriptive nouns
patient_data <- read_csv(...)
gene_counts  <- read_tsv(...)

# Boolean variables: is_/has_/can_ prefix
is_valid   <- TRUE
has_header <- FALSE

# Private functions (not exported): .prefix
.compute_internal <- function(x) { ... }
```

**Never:**
- `myVariable` (camelCase)
- `my.variable` (dots — conflicts with S3 methods)
- Single letters except loop indices (`i`, `j`) and math (`x`, `y`, `n`)

## Assignment

```r
# Use <- for assignment (not = or ->)
x <- 42

# = is fine for function arguments only
mean(x, na.rm = TRUE)

# Never:
42 -> x        # confusing direction
x = 42         # works but breaks convention
```

## Spacing

```r
# Spaces around operators
x <- 1 + 2
df |> filter(x > 0)

# No space before comma, space after
f(x, y, z)

# No space inside parentheses
mean(x)         # not mean( x )

# Space before { in control flow
if (condition) {
  ...
}

# Align assignment blocks for readability (optional but nice)
short_name    <- 1
longer_name   <- 2
very_long_one <- 3
```

## Line Length and Indentation

```r
# Max ~100 chars per line; break long pipelines
result <- data |>
  filter(condition) |>
  group_by(group) |>
  summarise(
    mean = mean(value),
    sd   = sd(value),
    .groups = "drop"
  )

# Indent 2 spaces (not 4, not tabs)
if (x > 0) {
  do_something(x)
}

# Closing brace on its own line
my_function <- function(arg1, arg2) {
  body
}
```

## Pipes

```r
# Use native |> (R 4.1+) for simple pipelines
x |> mean()

# Use magrittr %>% only when you need the . placeholder
list(1:5, 6:10) %>% purrr::map(~ mean(.))

# Each step on its own line when chaining 3+
result <- df |>
  filter(!is.na(value)) |>
  mutate(log_val = log(value)) |>
  group_by(group) |>
  summarise(mean_log = mean(log_val))

# Avoid intermediate assignments for simple pipelines
# (keep as one chain, not split into many named objects)
```

## Tidy Eval (dplyr programming)

When writing functions that wrap dplyr verbs:

```r
# Use {{ }} (curly-curly) for column arguments
compute_mean <- function(df, col) {
  df |>
    summarise(mean = mean({{ col }}, na.rm = TRUE))
}
compute_mean(df, value)

# Use .data[[ ]] for string column names
compute_mean_str <- function(df, col_name) {
  df |>
    summarise(mean = mean(.data[[col_name]], na.rm = TRUE))
}
compute_mean_str(df, "value")

# Use .env$var to refer to local variables (not columns)
threshold <- 0.05
df |> filter(.data$pvalue < .env$threshold)
```

## Control Flow

```r
# if/else: braces always, even for one-liners
if (x > 0) {
  pos(x)
} else {
  neg(x)
}

# Inline ifelse() for vectorized conditionals
x_sign <- ifelse(x > 0, "positive", "negative")

# dplyr::if_else() is stricter (type-safe), prefer it in pipelines
df |> mutate(label = if_else(value > 0, "pos", "neg"))

# switch() for multi-branch on a string
method_fn <- switch(
  method,
  "mean"   = mean,
  "median" = median,
  stop("Unknown method: ", method)
)
```

## Comments

```r
# Comments explain WHY, not WHAT
x <- x + 1  # compensate for 0-based index from API

# Section headers use ----- (at least 4 dashes)
# Load data ---------------------------------------------------------------

# TODO: mark pending work
# TODO: handle NA in edge case
```

## Functions

```r
# Document with roxygen2 for any reusable function
#' Compute group means
#'
#' @param df A data frame with `value` and `group` columns.
#' @param na_rm Logical. Remove NAs before computing mean?
#' @return A summarised data frame.
compute_group_means <- function(df, na_rm = TRUE) {
  df |>
    group_by(group) |>
    summarise(mean = mean(value, na.rm = na_rm), .groups = "drop")
}

# Fail fast with informative errors
check_input <- function(x) {
  if (!is.numeric(x)) stop("`x` must be numeric, got ", class(x))
  if (any(is.na(x)))  warning("`x` contains NAs — they will be removed")
  x
}
```
