# =============================================================================
# 08_prepare_audio.R
# Salish Sea whales: prepare the sound clips for the "Listen" section
#
# Converts the downloaded recordings (Ogg, WAV, or MP3) in data/raw/audio to
# small M4A files that play in every browser, including Safari, trimmed to the
# part with calls in it and mixed down to mono. Saves them in story/assets/audio.
#
# Start and length (in seconds) were chosen by looking at the spectrograms:
#   orca:              calls from about 1 to 18 seconds, then only noise
#   humpback song:     NOAA clip, used from the start
#   humpback and ship: the whole 9-second clip
# =============================================================================

library(here)
library(av)

clips <- tibble::tribble(
  ~input,               ~output,                 ~start, ~length,
  "Killer_whale.ogg",   "orca-calls.m4a",        0,      18,
  "humpback_song.mp3",  "humpback-song.m4a",     0,      30,
  "humpback_ship.wav",  "humpback-and-ship.m4a", 0,      30
)

dir.create(here("story", "assets", "audio"), recursive = TRUE, showWarnings = FALSE)

# Remove the old humpback file from the first version of this script
old <- here("story", "assets", "audio", "humpback-calls.m4a")
if (file.exists(old)) file.remove(old)

for (i in seq_len(nrow(clips))) {
  input  <- here("data", "raw", "audio", clips$input[i])
  output <- here("story", "assets", "audio", clips$output[i])
  if (!file.exists(input)) {
    message("Missing: data/raw/audio/", clips$input[i], " (skipped)")
    next
  }
  av_audio_convert(input, output, channels = 1, sample_rate = 22050,
                   start_time = clips$start[i], total_time = clips$length[i],
                   verbose = FALSE)
  info <- av_media_info(output)
  message("Saved story/assets/audio/", clips$output[i], " (",
          round(info$duration), " seconds, ", round(file.size(output) / 1024), " KB)")
}