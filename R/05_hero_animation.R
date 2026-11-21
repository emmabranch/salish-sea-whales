# =============================================================================
# 05_hero_animation.R
# Salish Sea whales: the hero animation, "A year in the Salish Sea"
#
# Twelve months of whale sightings (2018 to 2025 pooled), fading from one
# month to the next on a dark ocean background, with a one-line caption per
# month shown under the month name. Each frame is drawn with ggplot2 and the frames are joined into a
# video with the av package. Saves:
#   story/assets/year-in-salish-sea.mp4   the animation (loops on the site)
#   story/assets/year-in-salish-sea.png   a still of July, shown before the
#                                         video loads and when motion is off
# =============================================================================

library(tidyverse)
library(here)
library(sf)
library(av)

story <- readRDS(here("data", "processed", "story_data.rds"))

# --- Look --------------------------------------------------------------------
ocean   <- "#0d2436"   # deep navy water
land_c  <- "#1e3446"   # land, a shade lighter than the water
ink     <- "#f2f5f7"   # light text
ink_dim <- "#a9b8c4"   # secondary text

# Species colours stepped for a dark background (colourblind-checked)
dark_colours <- c(
  "Humpback whale" = "#3987e5",
  "Orca"           = "#d95926",
  "Grey whale"     = "#199e70"
)

# --- One caption per month (each matches the whale calendar) -----------------
captions <- tibble(
  month_name = factor(month.name, levels = month.name),
  caption = c(
    "Winter. A handful of sightings of each species.",
    "The quietest month of the year.",
    "Grey whales arrive in northern Puget Sound.",
    "Grey whale season peaks.",
    "Orcas spread out and the first humpbacks return.",
    "Humpbacks arrive in force.",
    "Humpbacks fill Juan de Fuca Strait and the Strait of Georgia.",
    "Peak humpback season.",
    "Humpbacks linger into autumn.",
    "Sightings begin to fall.",
    "Most humpbacks have left for the winter.",
    "Back to winter quiet."
  )
)

# gganimate works best with plain polygons, so the coastline is converted from
# an sf object to a table of outline points (one group per island or shore,
# with holes for lakes kept as separate rings)
land_df <- story$land |>
  st_cast("POLYGON") |>
  st_coordinates() |>
  as_tibble() |>
  rename(lon = X, lat = Y, ring = L1, poly = L2)

points <- story$year_in_sea |>
  mutate(common = factor(common, levels = names(dark_colours)))

# --- The map ---------------------------------------------------------------
xlim <- c(-125.4, -122.0)
ylim <- c(47.0, 50.3)

# Draws one frame. `months` is one or two months; `fade` (0 to 1) is how far
# the picture has moved from the first month to the second.
draw_frame <- function(months, fade = 0) {
  weights <- tibble(month_name = factor(months, levels = month.name),
                    weight = if (length(months) == 1) 1 else c(1 - fade, fade))
  shown   <- inner_join(points, weights, by = "month_name")
  current <- months[if (fade < 0.5) 1 else length(months)]

  ggplot() +
    geom_polygon(data = land_df, aes(lon, lat, group = poly, subgroup = ring),
                 fill = land_c, colour = NA) +
    geom_point(data = shown, aes(lon, lat, colour = common, alpha = weight * 0.75),
               size = 0.9) +
    scale_colour_manual(values = dark_colours, name = NULL, drop = FALSE) +
    scale_alpha_identity() +
    coord_quickmap(xlim = xlim, ylim = ylim, expand = FALSE) +
    guides(colour = guide_legend(override.aes = list(size = 4, alpha = 1))) +
    labs(title = current,
         subtitle = str_wrap(captions$caption[captions$month_name == current], 48),
         caption = str_wrap(paste("Whale sightings 2018 to 2025, pooled by month.",
                                  "Data: OBIS (Happywhale, iNaturalist, BC Cetacean",
                                  "Sightings Network, and others)."), 70)) +
    theme_void(base_size = 14) +
    theme(
      plot.background   = element_rect(fill = ocean, colour = NA),
      panel.background  = element_rect(fill = ocean, colour = NA),
      plot.title        = element_text(family = "serif", size = 30, colour = ink,
                                       margin = margin(14, 0, 4, 14)),
      plot.subtitle     = element_text(colour = ink, size = 15, lineheight = 1.1,
                                       margin = margin(0, 0, 8, 14)),
      plot.caption      = element_text(colour = ink_dim, size = 9, hjust = 0,
                                       margin = margin(8, 14, 10, 14)),
      legend.position   = "top",
      legend.justification = "left",
      legend.text       = element_text(colour = ink, size = 13),
      legend.margin     = margin(0, 0, 6, 8),
      plot.title.position   = "plot",
      plot.caption.position = "plot"
    )
}

# --- Still image (July) for loading and reduced motion -----------------------
ggsave(here("story", "assets", "year-in-salish-sea.png"),
       draw_frame("July"),
       width = 6.4, height = 8.4, dpi = 150, bg = ocean)

# --- Animation ---------------------------------------------------------------
# Each month is held for 2 seconds, then fades into the next over 1 second.
fps        <- 12
hold       <- 2 * fps
fade_steps <- 1 * fps

frame_dir <- file.path(tempdir(), "whale_frames")
unlink(frame_dir, recursive = TRUE)
dir.create(frame_dir)

frame_no <- 0
save_frame <- function(p) {
  frame_no <<- frame_no + 1
  ggsave(file.path(frame_dir, sprintf("frame_%04d.png", frame_no)), p,
         width = 6.4, height = 8.4, dpi = 150, bg = ocean)
}

message("Drawing frames (this takes a few minutes) ...")
for (m in seq_along(month.name)) {
  this_month <- month.name[m]
  next_month <- month.name[if (m == 12) 1 else m + 1]   # December fades to January
  still_frame <- draw_frame(this_month)
  for (h in seq_len(hold)) save_frame(still_frame)
  for (f in seq_len(fade_steps)) {
    save_frame(draw_frame(c(this_month, next_month), fade = f / fade_steps))
  }
  message("  ", this_month, " done")
}

frames <- list.files(frame_dir, full.names = TRUE)
av_encode_video(frames, here("story", "assets", "year-in-salish-sea.mp4"),
                framerate = fps, verbose = FALSE)
unlink(frame_dir, recursive = TRUE)
message("Saved story/assets/year-in-salish-sea.mp4 and year-in-salish-sea.png")
