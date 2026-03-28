# R Project Structure

## Recommended Layout

```
project/
├── data/
│   ├── raw/          # NEVER modify — read-only source of truth
│   └── processed/    # outputs of cleaning scripts
├── R/
│   ├── utils.R       # shared helper functions
│   ├── load_data.R   # data loading and cleaning functions
│   └── plotting.R    # reusable plot functions
├── scripts/
│   ├── 01_preprocess.R
│   ├── 02_analysis.R
│   └── 03_figures.R
├── figures/          # saved plots (PDF, SVG, PNG)
├── results/          # tables, RDS objects, text outputs
├── notebooks/        # exploratory Quarto/Rmd (not production)
└── project.Rproj     # always have an RStudio project file
```

**Key rules:**
- `data/raw/` is read-only — never write to it
- Scripts numbered for execution order (`01_`, `02_`)
- Functions go in `R/`, not inline in scripts (reuse via `source()`)
- Figures and results are generated outputs — safe to delete and regenerate

## File Paths — Always Use here::here

```r
library(here)

# here() resolves relative to the project root (where .Rproj lives)
# Works regardless of where you run the script from

# Reading
df <- read_csv(here("data", "raw", "counts.csv"))

# Writing
write_csv(result, here("results", "deg_table.csv"))
ggsave(here("figures", "volcano.pdf"), width = 6, height = 5)

# NEVER use:
setwd("/home/user/project")   # machine-specific, breaks collaboration
read_csv("../data/file.csv")  # relative paths break when sourced
```

## Package Management

### Nix (this system — preferred)

Packages declared in `modules/packages.nix`. No `install.packages()` needed.
Current R packages: `tidyverse`, `ggplot2`, `dplyr`, `data.table`, `gt`, `ggpubr`, `svglite`, `IRkernel`.

For Bioconductor packages (DESeq2, GenomicRanges, etc.) — use **micromamba**:
```bash
micromamba create -n bioc -c conda-forge -c bioconda r-base bioconductor-deseq2
micromamba run -n bioc Rscript analysis.R
```

### renv (for portable/shared projects)

```r
# Initialize renv in project
renv::init()

# Snapshot after adding packages
renv::snapshot()

# Restore on another machine
renv::restore()
```

Use renv when sharing code with collaborators who aren't on Nix.

## Scripts vs Functions vs Packages

| Type | When to use |
|------|-------------|
| **Script** | Linear analysis — runs top-to-bottom, produces outputs |
| **Function (in R/)** | Logic reused across ≥2 scripts |
| **R package** | Shared across multiple projects or published |

```r
# In R/utils.R — define reusable functions
normalize_counts <- function(counts, method = "TMM") {
  # ...
}

# In scripts/01_preprocess.R — source and use
source(here("R", "utils.R"))
normalized <- normalize_counts(raw_counts)
```

## Sourcing and Modular Scripts

```r
# Source helper functions at the top of analysis scripts
source(here("R", "utils.R"))
source(here("R", "plotting.R"))

# Run numbered scripts in order
source(here("scripts", "01_preprocess.R"))
source(here("scripts", "02_analysis.R"))
```

## Reproducibility

```r
# Always set seed for anything random
set.seed(42)

# Record session info in every analysis script
sessionInfo()
# or more structured:
sessioninfo::session_info()

# Save key intermediate objects as RDS (not CSV — preserves factors, classes)
saveRDS(deg_results, here("results", "deg_results.rds"))
deg_results <- readRDS(here("results", "deg_results.rds"))
```

## Quarto / R Markdown

Use `.qmd` or `.Rmd` for:
- Exploratory analysis (narrative + code together)
- Reports / manuscripts
- Parameter sweeps (`params:`)

Use plain `.R` scripts for:
- Production pipelines (easier to source, profile, debug)
- Long-running jobs

```r
# Render from script
quarto::quarto_render("analysis.qmd")
rmarkdown::render("report.Rmd", output_format = "pdf_document")
```
