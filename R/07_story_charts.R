# =============================================================================
# 07_story_charts.R
# Salish Sea whales: the charts for the story
#
#   whale-calendar.png       When each species visits (circular calendars)
#   watchers-vs-whales.png   Growth in watchers versus humpback sightings
#   per-1000-observations.png  Whale sightings per 1,000 iNaturalist records
#   humpbacks-per-orca.png   Humpback sightings for every orca sighting
#
# All saved to story/assets at twice screen resolution. Complete years only:
# the current year is left out of trends because it is not finished.
# =============================================================================

library(tidyverse)
library(here)

story  <- readRDS(here("data", "processed", "story_data.rds"))
effort <- readRDS(here("data", "processed", "effort_by_year.rds"))
last_full_year <- as.integer(format(Sys.Date(), "%Y")) - 1

# --- Shared look -------------------------------------------------------------
species_colours <- c("Humpback whale" = "#2a78d6",
                     "Orca"           = "#eb6834",
                     "Grey whale"     = "#1baf7a")
ink      <- "#1b2733"
ink_soft <- "#5b6670"
grid_col <- "#e6e5e1"
watcher  <- "#7a7f86"   # neutral grey for "people looking"

theme_story <- function() {
  theme_minimal(base_size = 13) +
    theme(
      text                = element_text(colour = ink),
      plot.title          = element_text(family = "serif", size = 19, colour = ink,
                                         margin = margin(0, 0, 4, 0)),
      plot.subtitle       = element_text(colour = ink_soft, size = 12,
                                         margin = margin(0, 0, 12, 0)),
      plot.caption        = element_text(colour = ink_soft, size = 9, hjust = 0,
                                         margin = margin(12, 0, 0, 0)),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      axis.text           = element_text(colour = ink_soft),
      axis.title          = element_text(colour = ink_soft, size = 11),
      panel.grid.major    = element_line(colour = grid_col, linewidth = 0.3),
      panel.grid.minor    = element_blank(),
      legend.position     = "none",
      plot.background     = element_rect(fill = "white", colour = NA),
      plot.margin         = margin(14, 18, 10, 14)
    )
}
save_chart <- function(plot, file, width = 8, height = 5) {
  ggsave(here("story", "assets", file), plot, width = width, height = height,
         dpi = 200, bg = "white")
  message("Saved story/assets/", file)
}
source_note <- "Data: OBIS (Happywhale, iNaturalist). Salish Sea sightings, duplicates removed."

# --- 1. Whale calendar -------------------------------------------------------
calendar <- story$calendar |>
  mutate(common = factor(common, levels = names(species_colours)),
         label  = substr(month.name[month], 1, 1))

# Each panel's title names the species and its peak month
peaks <- calendar |>
  group_by(common) |>
  slice_max(share, n = 1, with_ties = FALSE) |>
  ungroup() |>
  transmute(common, panel = paste0(common, "\npeaks in ", month.name[month]))
calendar <- calendar |>
  left_join(peaks, by = "common") |>
  mutate(panel = factor(panel, levels = peaks$panel[match(names(species_colours), peaks$common)]))
top <- max(calendar$share)

calendar_plot <- ggplot(calendar, aes(month, share, fill = common)) +
  geom_col(width = 0.92) +
  geom_text(aes(y = top * 1.12, label = label), colour = ink_soft, size = 3.2) +
  scale_fill_manual(values = species_colours) +
  scale_x_continuous(limits = c(0.5, 12.5), breaks = NULL) +
  scale_y_continuous(limits = c(-top * 0.35, top * 1.2), breaks = NULL) +
  coord_polar(start = -pi / 12) +
  facet_wrap(~ panel) +
  labs(title = "When each species visits",
       subtitle = "Share of each species' sightings by month, 2018 to 2025. The year runs clockwise from January at the top.",
       caption = str_wrap(paste(source_note, "Summer has more watchers for every species, so compare timing, not size."), 120)) +
  theme_story() +
  theme(panel.grid.major = element_blank(), axis.text = element_blank(),
        axis.title = element_blank(),
        strip.text = element_text(family = "serif", size = 14, colour = ink, lineheight = 1.1),
        panel.spacing = unit(1.5, "lines"))

save_chart(calendar_plot, "whale-calendar.png", width = 9, height = 4.8)

# --- 2. Watchers versus whales (indexed to 2015) -----------------------------
growth <- effort$inat_effort |>
  filter(year >= 2015, year <= last_full_year) |>
  transmute(year, series = "Watchers", value = inat_records) |>
  bind_rows(
    effort$ratio |>
      filter(year >= 2015, year <= last_full_year) |>
      transmute(year, series = "Humpbacks", value = `Humpback whale`)
  ) |>
  group_by(series) |>
  mutate(index = value / value[year == 2015]) |>
  ungroup()

growth_end <- growth |> filter(year == last_full_year) |>
  mutate(label = if_else(series == "Watchers",
                         paste0("Watchers: iNaturalist\nmarine observations\n", round(index), " times 2015"),
                         paste0("Humpback whale\nsightings\n", round(index), " times 2015")))
growth_colours <- c("Watchers" = watcher,
                    "Humpbacks" = species_colours[["Humpback whale"]])

watchers_plot <- ggplot(growth, aes(year, index, colour = series)) +
  geom_hline(yintercept = 1, colour = ink_soft, linewidth = 0.3) +
  geom_line(linewidth = 1.1) +
  geom_point(data = growth_end, size = 2.6) +
  geom_text(data = growth_end, aes(label = label), hjust = 0, nudge_x = 0.25,
            size = 3.6, lineheight = 0.95) +
  scale_colour_manual(values = growth_colours) +
  scale_y_log10(breaks = c(1, 2, 5, 10, 20, 50), labels = function(x) paste0(x, "x")) +
  scale_x_continuous(breaks = seq(2015, last_full_year, 2),
                     expand = expansion(mult = c(0.02, 0.32))) +
  coord_cartesian(clip = "off") +
  labs(title = "The watchers grew faster than the whales",
       subtitle = "Growth since 2015 (log scale: each step up is a multiple)",
       x = NULL, y = "Compared with 2015",
       caption = source_note) +
  theme_story()

save_chart(watchers_plot, "watchers-vs-whales.png")

# --- 3. Sightings per 1,000 iNaturalist observations -------------------------
rate <- effort$effort |>
  filter(year >= 2015, year <= last_full_year) |>
  mutate(common = factor(common, levels = names(species_colours)))
rate_end <- rate |> filter(year == last_full_year)

rate_plot <- ggplot(rate, aes(year, per_1000_observations, colour = common)) +
  annotate("rect", xmin = 2019.6, xmax = 2020.4, ymin = -Inf, ymax = Inf,
           fill = grid_col, alpha = 0.6) +
  annotate("text", x = 2020, y = Inf, label = "2020", vjust = 1.5,
           colour = ink_soft, size = 3.3) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 1.8) +
  geom_text(data = rate_end, aes(label = common), hjust = 0, nudge_x = 0.25, size = 3.8) +
  scale_colour_manual(values = species_colours) +
  scale_x_continuous(breaks = seq(2015, last_full_year, 2),
                     expand = expansion(mult = c(0.02, 0.22))) +
  coord_cartesian(clip = "off") +
  labs(title = "After allowing for watchers, humpbacks still rose",
       subtitle = "Whale sightings per 1,000 iNaturalist marine observations in the Salish Sea",
       x = NULL, y = "Sightings per 1,000 observations",
       caption = str_wrap("Data: OBIS (iNaturalist research-grade observations). As people log more tide pools and birds, every whale rate is diluted over time.", 120)) +
  theme_story()

save_chart(rate_plot, "per-1000-observations.png")

# --- 4. Humpbacks per orca ---------------------------------------------------
ratio <- effort$ratio |>
  filter(year >= 2010, year <= last_full_year)

ratio_plot <- ggplot(ratio, aes(year, humpbacks_per_orca)) +
  geom_col(fill = species_colours[["Humpback whale"]], width = 0.7) +
  geom_hline(yintercept = 1, colour = ink, linewidth = 0.4, linetype = "dashed") +
  scale_x_continuous(breaks = seq(2010, last_full_year, 2)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
  labs(title = "Humpbacks overtook orcas",
       subtitle = "Humpback sightings for every orca sighting, on the same platforms. Dashed line: equal numbers.",
       x = NULL, y = "Humpbacks per orca",
       caption = str_wrap(paste(source_note, "Early years have small numbers, so single years jump around."), 120)) +
  theme_story()

save_chart(ratio_plot, "humpbacks-per-orca.png")
