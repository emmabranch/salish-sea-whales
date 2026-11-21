# =============================================================================
# 04_prepare_story_data.R
# Salish Sea whales: prepare data for the story's maps and charts
#
# 1. Builds a detailed coastline for BC and Washington, including the San
#    Juan and Gulf Islands, cropped to the Salish Sea, for every map.
# 2. "A year in the Salish Sea": sightings by month, pooling 2018 to 2025.
# 3. Whale calendar: for each species, the share of its sightings that fall
#    in each month.
# 4. "The comeback": humpback sightings year by year, 2010 to 2025.
#
# Saves everything to data/processed/story_data.rds and draws a 12-month
# preview so the hero animation can be checked before it is built.
# =============================================================================

library(tidyverse)
library(here)
library(sf)

sf_use_s2(FALSE)   # simpler geometry rules make cropping reliable

whales     <- readRDS(here("data", "processed", "whales.rds")) |> as_tibble()
salish_sea <- readRDS(here("data", "processed", "salish_sea_boundary.rds"))

# Species colours, used in every map and chart (a colourblind-checked set)
species_colours <- c(
  "Humpback whale" = "#2a78d6",
  "Orca"           = "#eb6834",
  "Grey whale"     = "#1baf7a"
)

# --- 1. Coastline ------------------------------------------------------------
# Detailed coastlines that include the San Juan and Gulf Islands:
#   British Columbia: Statistics Canada 2021 cartographic boundary file for
#     provinces (downloaded by hand into data/raw; see the README).
#   Washington: US Census Bureau cartographic boundary file (1:500,000),
#     downloaded automatically with the tigris package.
# Both are clipped to the shoreline, so they work as land for the maps.
land_path <- here("data", "processed", "land.rds")
box <- c(xmin = -125.6, xmax = -121.8, ymin = 46.8, ymax = 50.5)

if (file.exists(land_path)) {
  land <- readRDS(land_path)
} else {
  # British Columbia from the Statistics Canada zip file
  zip_file <- list.files(here("data", "raw"), pattern = "^lpr_.*\\.zip$",
                         full.names = TRUE)
  stopifnot("Put the Statistics Canada provinces zip file in data/raw first" =
              length(zip_file) == 1)
  unzip_dir <- here("data", "raw", "statcan_provinces")
  unzip(zip_file, exdir = unzip_dir)
  shp <- list.files(unzip_dir, pattern = "\\.shp$", full.names = TRUE,
                    recursive = TRUE)
  bc <- st_read(shp[1], quiet = TRUE) |>
    filter(PRUID == "59") |>             # 59 is British Columbia
    st_transform(4326)

  # Washington from the US Census Bureau
  message("Downloading the Washington State coastline ...")
  wa <- tigris::states(cb = TRUE, resolution = "500k", year = 2023,
                       progress_bar = FALSE) |>
    filter(STUSPS == "WA") |>
    st_transform(4326)

  land <- c(st_geometry(bc), st_geometry(wa)) |>
    st_make_valid() |>
    st_crop(box) |>
    st_union() |>
    st_simplify(dTolerance = 0.0003) |>   # about 30 m: keeps islands, smaller file
    st_as_sf()
  saveRDS(land, land_path)
}

# --- 2. A year in the Salish Sea (2018 to 2025 pooled) -----------------------
months <- month.name
year_in_sea <- whales |>
  filter(year >= 2018, year <= 2025) |>
  mutate(month_name = factor(month.name[month], levels = months))

# --- 3. Whale calendar -------------------------------------------------------
calendar <- year_in_sea |>
  count(common, month) |>
  complete(common, month = 1:12, fill = list(n = 0)) |>
  group_by(common) |>
  mutate(share = n / sum(n)) |>
  ungroup() |>
  mutate(month_name = factor(month.name[month], levels = months))

# --- 4. The comeback (humpbacks, 2010 to 2025) -------------------------------
comeback <- whales |>
  filter(common == "Humpback whale", year >= 2010, year <= 2025)

# --- Save --------------------------------------------------------------------
story_data <- list(
  land            = land,
  salish_sea      = salish_sea,
  species_colours = species_colours,
  year_in_sea     = year_in_sea,
  calendar        = calendar,
  comeback        = comeback
)
saveRDS(story_data, here("data", "processed", "story_data.rds"))

# --- Report ------------------------------------------------------------------
cat("\n== Whale calendar: share of each species' sightings by month (%) ==\n")
print(calendar |>
        mutate(share = round(100 * share)) |>
        select(month, common, share) |>
        pivot_wider(names_from = common, values_from = share),
      n = 12)

cat("\n== Humpback sightings per year (the comeback) ==\n")
print(count(comeback, year), n = 20)

# --- Preview of the 12 animation frames --------------------------------------
p <- ggplot() +
  geom_sf(data = land, fill = "#e6e5e1", colour = NA) +
  geom_point(data = year_in_sea, aes(lon, lat, colour = common),
             size = 0.4, alpha = 0.5) +
  scale_colour_manual(values = species_colours) +
  coord_sf(xlim = c(-125.4, -122.0), ylim = c(47.0, 50.3), expand = FALSE) +
  facet_wrap(~ month_name, ncol = 4) +
  guides(colour = guide_legend(override.aes = list(size = 3, alpha = 1))) +
  labs(title = "Preview: a year in the Salish Sea (2018 to 2025 pooled)",
       x = NULL, y = NULL, colour = NULL) +
  theme_void() +
  theme(legend.position = "top",
        panel.background = element_rect(fill = "#f4f8fb", colour = NA),
        strip.text = element_text(size = 9, margin = margin(2, 0, 2, 0)))
print(p)
