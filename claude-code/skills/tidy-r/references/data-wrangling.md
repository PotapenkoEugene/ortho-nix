# Data Wrangling in R

## Core dplyr Verbs

```r
library(tidyverse)

# Select columns
df |> select(gene, log2fc, padj)
df |> select(starts_with("sample_"), ends_with("_raw"))
df |> select(where(is.numeric))

# Filter rows
df |> filter(padj < 0.05, abs(log2fc) > 1)
df |> filter(gene %in% gene_list)
df |> filter(!is.na(value))

# Mutate: add/modify columns
df |>
  mutate(
    log2fc_abs = abs(log2fc),
    sig        = padj < 0.05 & abs(log2fc) > 1,
    category   = case_when(
      log2fc > 1  & sig ~ "up",
      log2fc < -1 & sig ~ "down",
      TRUE              ~ "ns"
    )
  )

# Summarise
df |>
  group_by(condition) |>
  summarise(
    n        = n(),
    mean_exp = mean(expression, na.rm = TRUE),
    .groups  = "drop"
  )

# Arrange
df |> arrange(padj, desc(abs(log2fc)))
```

## across() — Apply the Same Operation to Many Columns

```r
# Normalize all numeric columns
df |>
  mutate(across(where(is.numeric), ~ (. - mean(.)) / sd(.)))

# Round specific columns
df |>
  mutate(across(c(log2fc, log2cpm), round, digits = 3))

# Summarise all numeric cols
df |>
  group_by(condition) |>
  summarise(across(where(is.numeric), list(mean = mean, sd = sd), na.rm = TRUE))
```

## Joins

```r
# Inner join: keep only matching rows
inner_join(deg_results, gene_annotation, by = "gene_id")

# Left join: keep all from left, fill NAs for non-matches
left_join(samples, metadata, by = c("sample" = "sample_id"))

# Anti join: rows in x NOT in y (useful for filtering)
anti_join(all_genes, blacklist, by = "gene_id")

# Many-to-many: explicit (avoids surprise row multiplication)
left_join(df1, df2, by = "key", relationship = "many-to-many")
```

## Pivoting

```r
# Wide → long (for ggplot2, most analyses)
counts_long <- counts_wide |>
  pivot_longer(
    cols      = starts_with("sample_"),
    names_to  = "sample",
    values_to = "count"
  )

# Long → wide
counts_wide <- counts_long |>
  pivot_wider(
    names_from  = sample,
    values_from = count,
    values_fill = 0
  )

# Multiple value columns
df |>
  pivot_longer(
    cols            = c(mean, sd),
    names_to        = "stat",
    values_to       = "value"
  )
```

## List Columns and Nested Data

```r
# Nest by group (store sub-data-frames as list column)
nested <- df |>
  group_by(gene) |>
  nest()

# Apply model to each group
models <- nested |>
  mutate(
    fit     = map(data, ~ lm(expression ~ timepoint, data = .x)),
    tidy    = map(fit, broom::tidy),
    glance  = map(fit, broom::glance)
  )

# Unnest results
models |>
  unnest(tidy) |>
  filter(term == "timepoint")
```

## Useful Patterns

```r
# Count distinct values
df |> count(category, sort = TRUE)
df |> distinct(gene_id, .keep_all = TRUE)

# Top N per group
df |>
  group_by(condition) |>
  slice_max(abs(log2fc), n = 10)

# Replace NAs
df |> replace_na(list(log2fc = 0, padj = 1))

# Separate a column
df |> separate(gene_isoform, into = c("gene", "isoform"), sep = "\\.")

# Recode factors
df |>
  mutate(
    condition = fct_recode(condition, "Control" = "ctrl", "Treatment" = "trt"),
    condition = fct_relevel(condition, "Control")  # set reference level
  )
```

## data.table — For Large Data (>1M rows)

Use when dplyr is too slow or uses too much memory.

```r
library(data.table)

# Convert
dt <- as.data.table(df)
# or read directly:
dt <- fread("large_file.tsv")   # much faster than read_tsv

# Syntax: dt[i, j, by]
#   i = row filter
#   j = column operations
#   by = grouping

# Filter
dt[padj < 0.05 & abs(log2fc) > 1]

# Select columns
dt[, .(gene, log2fc, padj)]

# Add/modify columns (modify in-place with :=)
dt[, log2fc_abs := abs(log2fc)]
dt[, c("mean", "sd") := .(mean(value), sd(value)), by = group]

# Summarise
dt[, .(mean_exp = mean(expression), n = .N), by = condition]

# Join
merge(dt1, dt2, by = "gene_id", all.x = TRUE)  # left join

# Fast read + filter + aggregate
result <- fread("big.tsv")[value > 0, .(mean = mean(value)), by = group]
```

### dplyr → data.table equivalents

| dplyr | data.table |
|-------|------------|
| `filter(x > 0)` | `dt[x > 0]` |
| `select(a, b)` | `dt[, .(a, b)]` |
| `mutate(y = x*2)` | `dt[, y := x*2]` |
| `group_by(g) |> summarise(m = mean(x))` | `dt[, .(m = mean(x)), by = g]` |
| `arrange(x)` | `setorder(dt, x)` |
| `left_join(a, b, by="k")` | `merge(a, b, by="k", all.x=TRUE)` |
