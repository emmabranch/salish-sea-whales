# Whales of the Salish Sea: more whales, or more watchers?

An interactive data story about humpback whales, orcas, and grey whales in the Salish Sea, and how much of the rise in sightings is really more people watching.

**Live site:** [emmabranch.github.io/salish-sea-whales](https://emmabranch.github.io/salish-sea-whales/) | **Code:** this repository | **More projects:** [github.com/emmabranch](https://github.com/emmabranch)

![A year in the Salish Sea: whale sightings in July on a dark map of the Salish Sea](story/assets/year-in-salish-sea.png)

## What it does

- Downloads open occurrence records for three whale species from OBIS and cleans them to a Salish Sea boundary, removing records on land and likely duplicates (13,000+ sightings).
- Builds an interactive map of a typical year, month by month, with play, pause, a month slider, and species toggles (D3).
- Shows when each species visits with circular month calendars.
- Tests whether the rise in sightings reflects more whales or more watchers, using two comparisons: sightings per 1,000 iNaturalist marine observations, and humpback sightings per orca sighting on the same platforms.
- Tells the story as a scrollytelling page (Quarto with the closeread extension), with the key numbers calculated from the data at render time.

## Data and licences

- **Whale records:** Ocean Biodiversity Information System (OBIS), Intergovernmental Oceanographic Commission of UNESCO, www.obis.org, accessed November 2026. Contributing datasets include Happywhale, iNaturalist research-grade observations, and the British Columbia Cetacean Sightings Network. Individual datasets carry their own licences; see each dataset's page on OBIS.
- **Coastline, British Columbia:** Statistics Canada, 2021 Census cartographic boundary file (provinces and territories), under the Open Government Licence (Canada). Not included in this repository; see How to reproduce.
- **Coastline, Washington:** US Census Bureau cartographic boundary file (states, 1:500,000), downloaded with the tigris package.
- **Code:** see LICENSE.

## How to reproduce

1. Install R (4.3 or later), Quarto, and these packages: `tidyverse`, `here`, `sf`, `robis`, `jsonlite`, `tigris`, `av`.
2. Download the Statistics Canada 2021 cartographic boundary file for provinces and territories (shapefile) and put the zip file in `data/raw/`.
3. Run the scripts in `R/` in order:
   - `01_check_obis.R` downloads the OBIS records
   - `02_clean.R` cleans them to the Salish Sea boundary
   - `03_effort.R` builds the watcher comparisons
   - `04_prepare_story_data.R` builds the coastline and story data
   - `05_hero_animation.R` makes the video and still image
   - `06_build_interactive.R` builds the interactive map
   - `07_story_charts.R` makes the story charts
4. Install the closeread extension with `quarto add qmd-lab/closeread`, then run `quarto render`. The site is written to `docs/`.

## Limitations

- These are opportunistic sightings, not systematic surveys. They show change in sightings relative to effort, not population size or trends in abundance.
- iNaturalist activity is a partial measure of effort. It does not capture whale-watching boats or Happywhale contributors directly, and its growing mix of non-whale records dilutes every whale rate over time.
- Orcas are an imperfect comparison species: Bigg's killer whales have also become more common in the Salish Sea, so the humpback-per-orca comparison is conservative.
- Early years have small numbers. The current year is left out of trends because it is incomplete.
- The Salish Sea boundary is approximate.

## About me

I'm Emma Branch, an epidemiologist and data analyst in British Columbia, and a PhD candidate in Population and Public Health at the University of British Columbia. I've spent about 10 years working with health research data, including registry analytics, REDCap database design, data governance, and performance measurement. I mostly work in R, SAS, and SQL, and build reports and tools with Quarto, Shiny, leaflet, and Power BI. Lately I've been applying the same habits to environmental and ocean data, mostly because I like maps and fish.
