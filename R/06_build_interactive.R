# =============================================================================
# 06_build_interactive.R
# Salish Sea whales: build the interactive "A year in the Salish Sea" map
#
# Reads the HTML template (story/hero_template.html), fills in the coastline,
# the whale sightings, and the ferry routes and shipping lanes, and saves one self-contained page:
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

# --- Ferry routes and shipping lanes (from 09_get_routes.R) -------------------
# layer: 0 = ferry route, 1 = shipping lane. boat: 1 = a little boat sails it.
# Boats go on the longest distinct routes only, so the map stays readable.
routes <- readRDS(here("data", "processed", "routes.rds")) |>
  st_transform(3005) |>
  st_simplify(dTolerance = 100, preserveTopology = TRUE) |>
  st_cast("MULTILINESTRING") |>
  st_cast("LINESTRING", warn = FALSE) |>
  mutate(km = as.numeric(st_length(geometry)) / 1000) |>
  filter(km > 0.5) |>
  st_transform(4326) |>
  mutate(layer = if_else(layer == "Ferry route", 0L, 1L))

# Start and end points, rounded, to spot the same route mapped twice
ends <- st_coordinates(routes) |>
  as_tibble() |>
  group_by(L1) |>
  summarise(key = paste(round(first(X), 2), round(first(Y), 2),
                        round(last(X), 2), round(last(Y), 2)))
routes$key <- ends$key

boat_rows <- routes |>
  st_drop_geometry() |>
  mutate(row = row_number()) |>
  filter((layer == 0 & km >= 5) | (layer == 1 & km >= 10)) |>
  distinct(layer, key, .keep_all = TRUE) |>
  group_by(layer) |>
  mutate(rank = row_number(desc(km))) |>
  filter(rank <= if_else(layer == 0, 18, 8)) |>   # 18 ferries, 8 ships
  pull(row)
routes$boat <- as.integer(seq_len(nrow(routes)) %in% boat_rows)

tmp <- tempfile(fileext = ".geojson")
st_write(routes |> select(layer, boat), tmp, driver = "GeoJSON", quiet = TRUE,
         layer_options = "COORDINATE_PRECISION=4")
routes_geojson <- paste(readLines(tmp, warn = FALSE), collapse = "")

# --- Fill the template and save ----------------------------------------------
template <- paste(readLines(here("story", "hero_template.html"), warn = FALSE),
                  collapse = "\n")
page <- template |>
  str_replace(fixed("/*LAND_GEOJSON*/"), land_geojson) |>
  str_replace(fixed("/*POINTS_JSON*/"), points_json) |>
  str_replace(fixed("/*ROUTES_GEOJSON*/"), routes_geojson)

writeLines(page, here("story", "year-in-salish-sea.html"))

message("Saved story/year-in-salish-sea.html (",
        round(file.size(here("story", "year-in-salish-sea.html")) / 1024), " KB, ",
        nrow(points), " sightings, ", nrow(routes), " route pieces, ",
        sum(routes$boat), " boats)")
