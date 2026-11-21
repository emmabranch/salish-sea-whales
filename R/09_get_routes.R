# =============================================================================
# 09_get_routes.R
# Salish Sea whales: ferry routes and shipping lanes from OpenStreetMap
#
# Downloads two layers from OpenStreetMap (via the Overpass API):
#   - ferry routes (route = ferry)
#   - shipping lanes: the traffic separation scheme (seamark:type =
#     separation_lane), the official one-way lanes for large ships
# Keeps the parts in the Salish Sea, then asks: how many whale sightings
# were within 2 km of a ferry route or a shipping lane?
#
# The download is saved to data/raw/osm_routes.rds, so it only happens once.
# Delete that file to download fresh data.
#
# Data: (c) OpenStreetMap contributors, Open Database Licence (ODbL).
# =============================================================================

library(here)
library(tidyverse)
library(sf)

bbox     <- c(xmin = -125.6, ymin = 46.8, xmax = -121.8, ymax = 50.5)
raw_file <- here("data", "raw", "osm_routes.rds")

# ---- 1. Download from OpenStreetMap (first run only) ------------------------

# Turn one osmdata result into plain lines with a name column
as_lines <- function(osm) {
  parts <- list(osm$osm_lines, osm$osm_multilines)
  if (!is.null(osm$osm_polygons) && nrow(osm$osm_polygons) > 0) {
    parts <- c(parts, list(st_boundary(osm$osm_polygons)))
  }
  parts <- parts[!map_lgl(parts, is.null)]
  parts <- parts[map_int(parts, nrow) > 0]
  map(parts, function(x) {
    nm <- if ("name" %in% names(x)) x$name else NA_character_
    st_sf(name = nm, geometry = st_geometry(x))
  }) |>
    bind_rows() |>
    st_cast("MULTILINESTRING")
}

if (!file.exists(raw_file)) {
  library(osmdata)
  message("Downloading ferry routes from OpenStreetMap (can take a minute)...")
  ferry <- opq(bbox = unname(bbox), timeout = 300) |>
    add_osm_feature(key = "route", value = "ferry") |>
    osmdata_sf()
  
  message("Downloading shipping lanes from OpenStreetMap...")
  lanes <- opq(bbox = unname(bbox), timeout = 300) |>
    add_osm_feature(key = "seamark:type", value = "separation_lane") |>
    osmdata_sf()
  
  saveRDS(list(ferry = as_lines(ferry), lanes = as_lines(lanes)), raw_file)
  message("Saved data/raw/osm_routes.rds")
}

osm <- readRDS(raw_file)

# ---- 2. Keep the parts in the Salish Sea ------------------------------------

sf_use_s2(FALSE)
boundary <- readRDS(here("data", "processed", "salish_sea_boundary.rds"))

routes <- bind_rows(
  osm$ferry |> mutate(layer = "Ferry route"),
  osm$lanes |> mutate(layer = "Shipping lane")
) |>
  st_make_valid() |>
  st_intersection(st_sf(geometry = boundary)) |>
  filter(st_geometry_type(geometry) %in% c("LINESTRING", "MULTILINESTRING")) |>
  st_cast("MULTILINESTRING") |>
  select(layer, name)

saveRDS(routes, here("data", "processed", "routes.rds"))

routes_km <- routes |>
  st_transform(3005) |>
  mutate(km = as.numeric(st_length(geometry)) / 1000) |>
  st_drop_geometry() |>
  group_by(layer) |>
  summarise(pieces = n(), total_km = round(sum(km)))
print(routes_km)

# ---- 3. How many sightings were near a route? --------------------------------

whales <- readRDS(here("data", "processed", "whales.rds")) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326, remove = FALSE) |>
  st_transform(3005)
routes_bc <- st_transform(routes, 3005)

near <- function(layer_name, dist_m = 2000) {
  lines <- routes_bc |> filter(layer == layer_name)
  lengths(st_is_within_distance(whales, lines, dist = dist_m)) > 0
}
whales$near_ferry <- near("Ferry route")
whales$near_lane  <- near("Shipping lane")

near_routes <- whales |>
  st_drop_geometry() |>
  group_by(common) |>
  summarise(
    sightings      = n(),
    pct_near_ferry = round(100 * mean(near_ferry), 1),
    pct_near_lane  = round(100 * mean(near_lane), 1),
    pct_near_either = round(100 * mean(near_ferry | near_lane), 1)
  )
print(near_routes)
saveRDS(near_routes, here("data", "processed", "near_routes.rds"))

# ---- 4. Quick look -------------------------------------------------------------

land <- readRDS(here("data", "processed", "land.rds"))

p <- ggplot() +
  geom_sf(data = land, fill = "#e8e4dc", colour = NA) +
  geom_point(data = st_drop_geometry(whales), aes(lon, lat),
             colour = "#2a78d6", size = 0.3, alpha = 0.15) +
  geom_sf(data = routes, aes(colour = layer, linetype = layer), linewidth = 0.6) +
  scale_colour_manual(values = c("Ferry route" = "#eb6834", "Shipping lane" = "#0b2233"),
                      name = NULL) +
  scale_linetype_manual(values = c("Ferry route" = "solid", "Shipping lane" = "22"),
                        name = NULL) +
  coord_sf(xlim = c(-125.0, -122.0), ylim = c(47.0, 50.3), expand = FALSE) +
  labs(title = "Ferry routes and shipping lanes, with whale sightings in blue",
       caption = "Routes: (c) OpenStreetMap contributors (ODbL)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "top", axis.title = element_blank(),
        panel.background = element_rect(fill = "#f4f8fb", colour = NA))
print(p)