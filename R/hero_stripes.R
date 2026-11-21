# R/hero_stripes.R
# Background stripes for the home page hero: one stripe per year from 2000,
# brighter in years with more humpback whale sightings (log scale, because
# sightings run from a handful to about 2,000 a year).
hero_stripes <- function(whales, last_full_year) {
  per_year <- whales |>
    filter(common == "Humpback whale", year >= 2000, year <= last_full_year) |>
    count(year) |>
    complete(year = 2000:last_full_year, fill = list(n = 0))
  pal <- scales::col_numeric(c("#22324a", "#5e3a58", "#8a4a72", "#cf86ae", "#f0bcd8"),
                             domain = range(log1p(per_year$n)))
  rects <- paste0(sprintf('<rect x="%d" y="0" width="1" height="1" fill="%s"/>',
                          seq_len(nrow(per_year)) - 1, pal(log1p(per_year$n))),
                  collapse = "")
  sprintf('<div class="hero-bg"><svg viewBox="0 0 %d 1" preserveAspectRatio="none" aria-hidden="true">%s</svg></div>',
          nrow(per_year), rects)
}
