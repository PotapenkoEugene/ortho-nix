# ggplot2 Visualization

## Grammar of Graphics

Every ggplot is built from:
1. **Data** — a data frame (always tidy/long format)
2. **Aesthetics** (`aes()`) — map variables to visual properties
3. **Geoms** — geometric objects (point, line, bar, etc.)
4. **Scales** — control axis ranges, colors, sizes
5. **Facets** — small multiples
6. **Theme** — non-data visual elements

```r
ggplot(data, aes(x = var1, y = var2, color = group)) +
  geom_point(size = 2, alpha = 0.7) +
  scale_color_brewer(palette = "Set1") +
  facet_wrap(~ condition) +
  labs(x = "X label", y = "Y label", title = "Title") +
  theme_bw()
```

## Common Geoms

```r
# Scatter
geom_point(size = 2, alpha = 0.6)

# Line
geom_line(linewidth = 0.8)

# Bar (summary already computed)
geom_col(position = "dodge")

# Histogram
geom_histogram(bins = 30, fill = "steelblue", color = "white")

# Density
geom_density(fill = "steelblue", alpha = 0.4)

# Box plot
geom_boxplot(outlier.shape = NA)  # hide outliers if showing jitter

# Violin + jitter (preferred over plain boxplot for small n)
geom_violin(trim = FALSE) +
geom_jitter(width = 0.2, alpha = 0.4, size = 1)

# Error bars
geom_errorbar(aes(ymin = mean - se, ymax = mean + se), width = 0.2)

# Heatmap
geom_tile(aes(x = sample, y = gene, fill = zscore))

# Volcano plot pattern
geom_point(aes(color = category), size = 1, alpha = 0.6)
```

## Color Scales

```r
# Discrete (categorical)
scale_color_brewer(palette = "Set1")        # max 9 colors
scale_color_manual(values = c("#E41A1C", "#377EB8", "#4DAF4A"))
scale_fill_viridis_d()                       # colorblind-safe

# Continuous
scale_color_viridis_c(option = "plasma")
scale_fill_gradient2(low = "blue", mid = "white", high = "red",
                     midpoint = 0)           # diverging (e.g., log2fc)

# Gradient for heatmaps
scale_fill_gradientn(
  colors = c("#053061", "#2166AC", "#F7F7F7", "#D6604D", "#67001F"),
  limits = c(-3, 3), oob = scales::squish
)
```

## Themes

```r
# Recommended base themes
theme_bw()       # white background, black grid — good for papers
theme_classic()  # white, no grid — minimal, publication-style
theme_minimal()  # white, light grid
theme_void()     # nothing — for maps, dendrograms

# Customize on top
theme_bw() +
theme(
  text            = element_text(size = 12, family = "sans"),
  axis.title      = element_text(size = 13, face = "bold"),
  legend.position = "bottom",
  panel.grid.minor = element_blank(),
  strip.background = element_blank(),     # clean facet labels
  strip.text       = element_text(face = "bold")
)

# Set globally for consistent plots in a script
theme_set(theme_bw(base_size = 12))
```

## Scales and Axes

```r
# Log scales
scale_x_log10() + annotation_logticks(sides = "b")
scale_y_log10(labels = scales::label_log())

# Custom breaks/labels
scale_x_continuous(breaks = c(0, 0.5, 1), labels = c("0", "0.5", "1"))
scale_x_discrete(limits = c("ctrl", "low", "high"))  # reorder

# Clipping / zoom (don't use xlim/ylim — they drop data)
coord_cartesian(xlim = c(0, 100), ylim = c(-5, 5))

# Flip axes
coord_flip()

# Equal aspect
coord_fixed()
```

## Faceting

```r
# Wrap into grid (best for 1 variable)
facet_wrap(~ condition, ncol = 3, scales = "free_y")

# Grid (2 variables)
facet_grid(rows = vars(cell_type), cols = vars(timepoint))

# Free scales for each panel
facet_wrap(~ gene, scales = "free")
```

## Annotations

```r
# Text labels on points (ggrepel avoids overlap)
library(ggrepel)
geom_text_repel(aes(label = gene), size = 3, max.overlaps = 20)

# Horizontal/vertical reference lines
geom_hline(yintercept = 0, linetype = "dashed", color = "grey50")
geom_vline(xintercept = c(-1, 1), linetype = "dashed", color = "grey50")

# Add p-value brackets (ggpubr)
library(ggpubr)
stat_compare_means(comparisons = list(c("ctrl", "trt")),
                   method = "wilcox.test", label = "p.signif")
```

## Saving Publication-Ready Figures

```r
# Always use ggsave — never use RStudio's Export
ggsave(
  here("figures", "volcano_plot.pdf"),
  plot   = p,
  width  = 6,
  height = 5,
  units  = "in",
  device = cairo_pdf   # better font rendering
)

# For SVG (editable in Illustrator/Inkscape)
ggsave(here("figures", "plot.svg"), plot = p, width = 6, height = 5)

# PNG for presentations (high DPI)
ggsave(here("figures", "plot.png"), plot = p,
       width = 8, height = 6, dpi = 300)
```

## Multi-Panel Figures (patchwork)

```r
library(patchwork)

p1 <- ggplot(...) + ...
p2 <- ggplot(...) + ...
p3 <- ggplot(...) + ...

# Side by side
p1 | p2

# Stack
p1 / p2

# Complex layout
(p1 | p2) / p3 + plot_annotation(tag_levels = "A")

# Save
ggsave(here("figures", "fig1.pdf"), width = 12, height = 8)
```
