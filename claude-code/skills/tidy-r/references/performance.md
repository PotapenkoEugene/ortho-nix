# R Performance

## When to Optimize

Profile first, optimize second. Only optimize hot paths.

```r
# Profile a script
profvis::profvis({
  source(here("scripts", "slow_analysis.R"))
})

# Benchmark two approaches
bench::mark(
  dplyr  = df |> group_by(group) |> summarise(m = mean(value)),
  dt     = dt[, .(m = mean(value)), by = group],
  check  = FALSE,
  iterations = 100
)
```

## Vectorization Over Loops

```r
# SLOW: loop over rows
result <- numeric(nrow(df))
for (i in seq_len(nrow(df))) {
  result[i] <- df$value[i] * 2
}

# FAST: vectorized (no loop)
result <- df$value * 2

# SLOW: growing a vector
out <- c()
for (x in data) out <- c(out, f(x))

# FAST: pre-allocate or use purrr/vapply
out <- vector("numeric", length(data))
for (i in seq_along(data)) out[i] <- f(data[i])
# or:
out <- vapply(data, f, numeric(1))
out <- purrr::map_dbl(data, f)
```

## purrr for Functional Iteration

```r
library(purrr)

# Apply f to each element, collect results by type
map(list, f)           # returns list
map_dbl(list, f)       # returns numeric vector
map_chr(list, f)       # returns character vector
map_lgl(list, f)       # returns logical vector
map_dfr(list, f)       # bind_rows — collect data frames

# Two inputs in parallel
map2(x_list, y_list, f)
map2_dbl(x_list, y_list, f)

# Multiple inputs
pmap(list(a, b, c), f)

# Side effects only (not collecting output)
walk(plots, ~ ggsave(paste0("fig_", .y, ".pdf"), .x))

# With anonymous functions (R 4.1+ shorthand)
map_dbl(data, \(x) mean(x, na.rm = TRUE))
```

## data.table for Large Data

See [data-wrangling.md](data-wrangling.md) for full syntax. Key performance notes:

```r
library(data.table)

# fread is 5-20x faster than read_csv for large files
dt <- fread("big_file.tsv", nThread = 4)

# Modify in-place (no copy) with :=
dt[, new_col := old_col * 2]

# Keys for fast joins (like database index)
setkey(dt1, gene_id)
setkey(dt2, gene_id)
dt1[dt2]   # keyed join — very fast

# Select columns by reference (no copy)
dt[, .(gene, value)]      # returns new dt
dt[, c("gene", "value")]  # same

# Chaining
dt[condition, .(mean = mean(value)), by = group][mean > 0]
```

## Memory Management

```r
# Check memory usage
object.size(df) |> format(units = "MB")
lobstr::obj_size(df)

# Remove large objects when done
rm(large_matrix)
gc()   # trigger garbage collection

# Read only needed columns
df <- read_csv("big.csv", col_select = c(gene, value, group))
# data.table:
dt <- fread("big.tsv", select = c("gene", "value", "group"))

# Process in chunks if too large for RAM
library(arrow)
ds <- open_dataset("big.parquet")
ds |> filter(value > 0) |> collect()
```

## Parallel Processing

```r
library(furrr)   # parallel purrr

# Set up parallel workers
plan(multisession, workers = 4)

# Same API as purrr, runs in parallel
results <- future_map(gene_list, run_analysis)
results <- future_map_dfr(file_list, read_and_process)

# Reset to sequential
plan(sequential)

# For data.table: nThread argument
dt <- fread("big.tsv", nThread = 4)
dt[, sum(value), by = group]  # auto-uses multiple threads
```

## Vectorized String Operations (stringr)

```r
library(stringr)

# Vectorized over entire column (fast)
df |> mutate(
  clean  = str_trim(raw_name),
  upper  = str_to_upper(gene),
  match  = str_detect(id, "^ENSG"),
  extract = str_extract(description, "GO:\\d+")
)
```
