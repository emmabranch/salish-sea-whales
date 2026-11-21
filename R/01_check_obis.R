# =============================================================================
# 01_check_obis.R
# Salish Sea whales: what does OBIS hold?
#
# Downloads OBIS occurrence records for three whale species in a box around
# the Salish Sea, saves them locally so later scripts never re-download, and
# prints summaries to help decide the story's design.
# =============================================================================

library(tidyverse)
library(here)
library(robis)

# --- Study area --------------------------------------------------------------
# A simple box around the Salish Sea: Strait of Georgia, Haro Strait,
# Juan de Fuca Strait, and Puget Sound. Longitude -125.0 to -122.0,
# latitude 47.0 to 50.3. Written as WKT (well-known text), which OBIS expects.
salish_sea_wkt <- paste0(
  "POLYGON((-125.0 47.0, -122.0 47.0, -122.0 50.3, ",
  "-125.0 50.3, -125.0 47.0))"
)

species <- c(
  "Megaptera novaeangliae",  # humpback whale
  "Orcinus orca",            # killer whale (orca)
  "Eschrichtius robustus"    # grey whale
)

# --- Download (this can take a few minutes) ----------------------------------
raw_path <- here("data", "raw", "obis_whales_raw.rds")

if (file.exists(raw_path)) {
  message("Using the saved download in data/raw. Delete it to download again.")
  whales_raw <- readRDS(raw_path)
} else {
  whales_raw <- map(species, \(sp) {
    message("Downloading ", sp, " ...")
    occurrence(scientificname = sp, geometry = salish_sea_wkt)
  }) |>
    bind_rows()
  saveRDS(whales_raw, raw_path)
  message("Saved ", nrow(whales_raw), " records to data/raw/obis_whales_raw.rds")
}

# --- Tidy the columns we need ------------------------------------------------
whales <- whales_raw |>
  transmute(
    species   = scientificName,
    lon       = decimalLongitude,
    lat       = decimalLatitude,
    date      = as.Date(str_sub(eventDate, 1, 10)),
    year      = coalesce(as.integer(date_year), as.integer(format(date, "%Y"))),
    month     = as.integer(format(date, "%m")),
    dataset   = datasetName,
    basis     = basisOfRecord
  )

# --- Summaries ---------------------------------------------------------------
cat("\n== Records by species ==\n")
print(count(whales, species, sort = TRUE))

cat("\n== Records with a usable date (year and month) ==\n")
print(whales |>
        group_by(species) |>
        summarise(records = n(),
                  with_month = sum(!is.na(month)),
                  first_year = min(year, na.rm = TRUE),
                  last_year  = max(year, na.rm = TRUE)))

cat("\n== Records by 5-year period ==\n")
print(whales |>
        filter(!is.na(year), year >= 1970) |>
        mutate(period = paste0(year %/% 5 * 5, "-", year %/% 5 * 5 + 4)) |>
        count(period, species) |>
        pivot_wider(names_from = species, values_from = n, values_fill = 0),
      n = 20)

cat("\n== Top 10 source datasets ==\n")
print(count(whales, dataset, sort = TRUE) |> head(10), width = 120)

cat("\n== Type of record ==\n")
print(count(whales, basis, sort = TRUE))

# --- Quick look at where the records are -------------------------------------
p <- ggplot(whales, aes(lon, lat, colour = species)) +
  geom_point(size = 0.6, alpha = 0.4) +
  coord_quickmap() +
  labs(title = "OBIS whale records in the Salish Sea box", x = NULL, y = NULL) +
  theme_minimal()
print(p)