# R/page_setup.R
# Shared setup for every page of the website: loads the processed data and
# works out the numbers quoted in the text. Each page runs source() on this.

library(tidyverse)
library(here)

whales <- readRDS(here("data", "processed", "whales.rds"))
effort <- readRDS(here("data", "processed", "effort_by_year.rds"))
story  <- readRDS(here("data", "processed", "story_data.rds"))

last_full_year <- as.integer(format(Sys.Date(), "%Y")) - 1
fmt <- function(x) format(round(x), big.mark = ",")

# Watchers and humpbacks, growth since 2015
inat <- effort$inat_effort
watchers_x <- with(inat, inat_records[year == last_full_year] / inat_records[year == 2015])
hump <- effort$ratio
humpback_x <- with(hump, `Humpback whale`[year == last_full_year] / `Humpback whale`[year == 2015])

# Humpbacks per 1,000 iNaturalist observations
rate <- effort$effort |> filter(common == "Humpback whale")
rate_2015 <- rate$per_1000_observations[rate$year == 2015]
rate_recent <- mean(rate$per_1000_observations[rate$year %in% (last_full_year - 1):last_full_year])

# Calendar shares
cal <- story$calendar
share <- function(sp, months) round(100 * sum(cal$share[cal$common == sp & cal$month %in% months]))
grey_spring  <- share("Grey whale", 3:5)
hump_summer  <- share("Humpback whale", 6:10)

# Records downloaded before cleaning (quoted on the About the data page)
n_raw <- nrow(readRDS(here("data", "raw", "obis_whales_raw.rds")))
