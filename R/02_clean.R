# =============================================================================
# 02_clean.R
# Salish Sea whales: clean the OBIS records
#
# 1. Merges subspecies into species and adds common names.
# 2. Removes records OBIS flags as on land.
# 3. Keeps only records inside an approximate Salish Sea boundary, which
#    drops the outer Washington coast and the waters north of the Strait of
#    Georgia that the rough download box included.
# 4. Removes likely duplicates: the same species, on the same day, within
#    about one kilometre (often the same encounter uploaded more than once).
# 5. Groups the many source datasets into a few readable source types.
#
# Output: data/processed/whales.rds (and a CSV copy)
# =============================================================================

library(tidyverse)
library(here)
library(sf)

whales_raw <- readRDS(here("data", "raw", "obis_whales_raw.rds"))
n_start <- nrow(whales_raw)

# Some OBIS downloads lack the quality-flag or id columns; add them if missing
if (!"flags" %in% names(whales_raw)) whales_raw$flags <- NA_character_
if (!"id" %in% names(whales_raw)) whales_raw$id <- as.character(seq_len(n_start))

# --- 1. Species and common names ---------------------------------------------
whales <- whales_raw |>
  transmute(
    obis_id  = id,
    species  = word(scientificName, 1, 2),   # drops subspecies names
    lon      = decimalLongitude,
    lat      = decimalLatitude,
    date     = as.Date(str_sub(eventDate, 1, 10)),
    dataset  = coalesce(datasetName, "Unnamed dataset"),
    basis    = basisOfRecord,
    flags    = coalesce(as.character(flags), "")
  ) |>
  mutate(
    common = recode(species,
                    "Megaptera novaeangliae" = "Humpback whale",
                    "Orcinus orca"           = "Orca",
                    "Eschrichtius robustus"  = "Grey whale"),
    year  = as.integer(format(date, "%Y")),
    month = as.integer(format(date, "%m"))
  ) |>
  filter(!is.na(date), !is.na(lon), !is.na(lat))
n_dated <- nrow(whales)

# --- 2. Remove records on land -----------------------------------------------
whales <- whales |> filter(!str_detect(str_to_lower(flags), "on_land"))
n_water <- nrow(whales)

# --- 3. Keep records inside an approximate Salish Sea boundary ---------------
# Corners run clockwise from the western entrance of Juan de Fuca Strait.
# The boundary includes some land (Vancouver Island, the Olympic Peninsula),
# which does not matter because land records were removed in step 2.
salish_sea <- st_polygon(list(rbind(
  c(-124.80, 48.30),   # western entrance of Juan de Fuca Strait (south side)
  c(-124.55, 48.65),   # western entrance (north side, near Port Renfrew)
  c(-125.30, 50.10),   # northern Strait of Georgia, Discovery Passage
  c(-124.40, 50.30),   # Desolation Sound
  c(-123.50, 50.00),   # Jervis Inlet and Howe Sound
  c(-122.00, 49.40),   # Fraser Valley edge
  c(-122.00, 47.00),   # southern Puget Sound (east)
  c(-123.30, 47.00),   # southern Puget Sound and Hood Canal (west)
  c(-124.00, 48.00),   # Olympic Peninsula
  c(-124.80, 48.30)    # back to the start
))) |>
  st_sfc(crs = 4326)

saveRDS(salish_sea, here("data", "processed", "salish_sea_boundary.rds"))

inside <- whales |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326, remove = FALSE) |>
  st_within(salish_sea, sparse = FALSE)
whales <- whales[inside[, 1], ]
n_inside <- nrow(whales)

# --- 4. Remove likely duplicate sightings ------------------------------------
# Same species, same day, and within roughly 1 km (0.01 degrees of latitude
# and 0.015 degrees of longitude at this latitude). The first record is kept.
whales <- whales |>
  mutate(cell_lat = round(lat / 0.01), cell_lon = round(lon / 0.015)) |>
  distinct(species, date, cell_lat, cell_lon, .keep_all = TRUE) |>
  select(-cell_lat, -cell_lon)
n_final <- nrow(whales)

# --- 5. Source types ---------------------------------------------------------
whales <- whales |>
  mutate(source = case_when(
    str_detect(dataset, "Happywhale")                 ~ "Happywhale",
    str_detect(dataset, "iNaturalist")                ~ "iNaturalist",
    str_detect(dataset, "Cetacean Sightings Network") ~ "BC Cetacean Sightings Network",
    str_detect(dataset, regex("survey|cruise", ignore_case = TRUE)) ~ "Scientific surveys",
    TRUE                                              ~ "Other sources"
  )) |>
  select(obis_id, common, species, date, year, month, lon, lat, source, dataset, basis) |>
  arrange(date)

# --- Save and report ---------------------------------------------------------
saveRDS(whales, here("data", "processed", "whales.rds"))
write_csv(whales, here("data", "processed", "whales.csv"))

steps <- tibble(
  step = c("Downloaded from OBIS", "With a date and location", "Not on land",
           "Inside the Salish Sea boundary", "After removing likely duplicates"),
  records = c(n_start, n_dated, n_water, n_inside, n_final)
)
cat("\n== Cleaning steps ==\n");        print(steps)
cat("\n== Records by species ==\n");    print(count(whales, common, sort = TRUE))
cat("\n== Records by source ==\n");     print(count(whales, source, sort = TRUE))

p <- ggplot(whales, aes(lon, lat, colour = common)) +
  geom_sf(data = salish_sea, inherit.aes = FALSE, fill = NA, colour = "grey50") +
  geom_point(size = 0.5, alpha = 0.4) +
  labs(title = "Cleaned whale records and the Salish Sea boundary",
       x = NULL, y = NULL, colour = NULL) +
  theme_minimal()
print(p)
