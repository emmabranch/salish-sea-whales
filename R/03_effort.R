# =============================================================================
# 03_effort.R
# Salish Sea whales: more whales, or more watchers?
#
# Builds two ways of separating real change from changes in how hard people
# are looking:
#
#   A. Watcher index: all iNaturalist research-grade marine observations
#      (every species, not just whales) inside the Salish Sea boundary each
#      year, from OBIS. More observations means more people looking.
#      Whale sightings are then expressed per 1,000 of those observations.
#
#   B. Comparison species: humpback sightings per orca sighting each year,
#      within the same platforms (Happywhale and iNaturalist). Both species
#      are reported by the same watchers, so changes in watching partly
#      cancel out.
#
# Outputs (in data/processed/):
#   inat_effort_by_year.rds   iNaturalist marine observations per year
#   effort_by_year.rds        whale sightings, watcher index, and ratios
# =============================================================================

library(tidyverse)
library(here)
library(sf)
library(jsonlite)

whales_raw <- readRDS(here("data", "raw", "obis_whales_raw.rds"))
whales     <- readRDS(here("data", "processed", "whales.rds"))
salish_sea <- readRDS(here("data", "processed", "salish_sea_boundary.rds"))

# --- A. Watcher index from OBIS ----------------------------------------------

effort_path <- here("data", "processed", "inat_effort_by_year.rds")

if (file.exists(effort_path)) {
  message("Using the saved iNaturalist counts. Delete the file to download again.")
  inat_effort <- readRDS(effort_path)
} else {
  # The OBIS identifier for the iNaturalist dataset, taken from the download
  inat_id <- whales_raw |>
    filter(str_detect(datasetName, "iNaturalist")) |>
    distinct(dataset_id) |>
    pull(dataset_id)
  stopifnot("Could not find the iNaturalist dataset id" = length(inat_id) == 1)

  # Ask OBIS for the number of records per year, for that dataset, inside the
  # Salish Sea boundary. This returns counts only, so it is quick.
  wkt <- st_as_text(st_geometry(salish_sea)[[1]])
  url <- paste0(
    "https://api.obis.org/v3/statistics/years",
    "?datasetid=", inat_id,
    "&geometry=", URLencode(wkt, reserved = TRUE)
  )
  message("Asking OBIS for iNaturalist records per year ...")
  response <- fromJSON(url)

  # The response is a table with a year column and a record count column
  inat_effort <- as_tibble(response) |>
    transmute(year = as.integer(year), inat_records = as.integer(records)) |>
    arrange(year)

  saveRDS(inat_effort, effort_path)
}

# --- Whale sightings per year from the same platforms -------------------------

platform_sightings <- whales |>
  filter(source %in% c("Happywhale", "iNaturalist")) |>
  count(year, common) |>
  pivot_wider(names_from = common, values_from = n, values_fill = 0)

inat_sightings <- whales |>
  filter(source == "iNaturalist") |>
  count(year, common, name = "inat_whale_sightings")

# --- B. Combine --------------------------------------------------------------

effort <- inat_sightings |>
  left_join(inat_effort, by = "year") |>
  mutate(per_1000_observations = 1000 * inat_whale_sightings / inat_records) |>
  select(year, common, inat_whale_sightings, inat_records, per_1000_observations)

ratio <- platform_sightings |>
  mutate(humpbacks_per_orca = if_else(Orca > 0, `Humpback whale` / Orca, NA_real_))

saveRDS(list(effort = effort, ratio = ratio, inat_effort = inat_effort),
        here("data", "processed", "effort_by_year.rds"))

# --- Report ------------------------------------------------------------------

this_year <- as.integer(format(Sys.Date(), "%Y"))

cat("\n== A. iNaturalist marine observations in the Salish Sea (the watchers) ==\n")
print(filter(inat_effort, year >= 2010), n = 30)

cat("\n== A. Whale sightings per 1,000 iNaturalist marine observations ==\n")
print(effort |>
        filter(year >= 2015) |>
        select(year, common, per_1000_observations) |>
        mutate(per_1000_observations = round(per_1000_observations, 1)) |>
        pivot_wider(names_from = common, values_from = per_1000_observations),
      n = 30)

cat("\n== B. Humpback sightings per orca sighting (Happywhale and iNaturalist) ==\n")
print(ratio |>
        filter(year >= 2010) |>
        mutate(humpbacks_per_orca = round(humpbacks_per_orca, 2)),
      n = 30)

cat("\nNote:", this_year, "is a partial year.\n")

p <- effort |>
  filter(year >= 2015, year < this_year) |>
  ggplot(aes(year, per_1000_observations, colour = common)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  labs(title = "Whale sightings per 1,000 iNaturalist marine observations",
       subtitle = "Salish Sea, complete years only",
       x = NULL, y = "Sightings per 1,000 observations", colour = NULL) +
  theme_minimal()
print(p)
