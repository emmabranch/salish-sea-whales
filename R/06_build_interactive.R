# =============================================================================
# 06_build_interactive.R
# Salish Sea whales: build the interactive "A year in the Salish Sea" map
#
# Reads the HTML template (story/hero_template.html), fills in the coastline
# and the whale sightings, and saves one self-contained page:
#   story/year-in-salish-sea.html
# It opens in any browser, with no server needed, and can be embedded in the
# story and on the website.
# =============================================================================

library(tidyverse)
library(here)
library(sf)
library(jsonlite)

story <- readRDS(here("data", "processed", "story_data.rds"))

# --- Coastline as compact GeoJSON --------------------------------------------
# Simplified to about 100 m in metres (BC Albers projection), which keeps the
# islands but makes the file small enough for a web page.
land <- story$land |>
  st_transform(3005) |>
  st_simplify(dTolerance = 100, preserveTopology = TRUE) |>
  st_transform(4326) |>
  st_union()

tmp <- tempfile(fileext = ".geojson")
st_write(st_sf(geometry = land), tmp, driver = "GeoJSON", quiet = TRUE,
         layer_options = "COORDINATE_PRECISION=4")
land_geojson <- paste(readLines(tmp, warn = FALSE), collapse = "")

# --- Sightings as compact arrays: [lon, lat, species, month 0-11] ------------
species_order <- c("Humpback whale", "Orca", "Grey whale")
points <- story$year_in_sea |>
  transmute(lon = round(lon, 4), lat = round(lat, 4),
            species = match(common, species_order) - 1,
            month = month - 1) |>
  filter(!is.na(species))
points_json <- toJSON(as.matrix(points), dataframe = "values", digits = 4)

# --- Fill the template and save ----------------------------------------------
template <- paste(readLines(here("story", "hero_template.html"), warn = FALSE),
                  collapse = "\n")
page <- template |>
  str_replace(fixed("/*LAND_GEOJSON*/"), land_geojson) |>
  str_replace(fixed("/*POINTS_JSON*/"), points_json)

writeLines(page, here("story", "year-in-salish-sea.html"))

message("Saved story/year-in-salish-sea.html (",
        round(file.size(here("story", "year-in-salish-sea.html")) / 1024), " KB, ",
        nrow(points), " sightings)")
