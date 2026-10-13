# E6 checkpoint video (retune flag ON, iOS Simulator)

`e6_retune.mp4` (86 s, 720x1566, no audio) and `e6_retune_frames.png` (12 frames, 6x2, at 6, 14, 18.5, 21, 23.5, 26, 38, 50, 61, 66, 74 and 83 s).

## Setup
- **Device:** iPhone 17 Pro Simulator, iOS 26.5 (macOS 26.4.1), Safari, portrait. Recorded with `xcrun simctl io <udid> recordVideo`, then cut and re-encoded with ffmpeg.
- **Build:** the `web_debug` export (debug template, debug overlay on screen: "Fade alpha" button, seed/day text, fps 30 to 50), built from `e6/p4-proof` into a directory outside the repo. A debug build runs at about 30 fps in the Simulator; this is not a perf reading.
- **Flag:** `?retune=1` in the URL (`ui/debug/debug_overlay.gd`, applied from `Main._enter_tree`). `retune_enabled` stays off in every committed file.
- **Self-play:** `?autoplay=tier` (the tier bot, policy `threat`, first card offered after 3 s). Nothing in the video is hand-played: the Simulator has no touch input from the command line.
- **Fixture:** `export/fixtures/retune_respawn.save.json` (real play, seed 3, day 23, the night of the first tier-3 day, `lane_character_shown` false) with ONE change made outside the repo: gold 357 raised to 1500 (checksum recomputed), so the bot can afford branches within the recording. The change is not in the repo.

## Segments (as seen in the video)
| Time | Shows |
|---|---|
| 0 to 17 s | End of night 23: brutes coming down the lanes at the south-west of the diner, the diner standing (the first attempt at this night had ended in "The diner fell", which is not in the cut; the night was replayed from the restore point). |
| 17 to 20 s | Dawn of day 24: "Pick a card" (Fancy Menu, Big Backpack, Running Shoes). |
| 20.5 to 22 s | Pick banner "Fancy Menu Lv 3". |
| 22 to 25 s | Lane-character siege line: "Heavy tracks on the south road...". |
| 25 to 27 s | Lane-character hare line: "Quick paws in the west grass...". |
| 27 to 32 s | Day 24 starts; the lane badges sit at the entrances (bottom-left: a hare count 3, a brute count 2 and a further badge reading 18, partly off screen; I did not identify what the 18 stands for). |
| 32 to 61 s | Cut to later in day 24 (about 2.5 min later, the bot had waited for the day to run down and collected the counter's gold, which rose from 1500 to over 4000): the hero walks to the south-west spots; pad previews appear. |
| 61 to 86 s | Cut to about 5 s after: branch pads and their cards (Longbow "south road", Volley, Stone wall "east road", Spike fence "north path"); gold falls from 1632 to 32 in several steps (several pad payments; the card prices read 300 and 500); the clip ends as night 24 begins. |

Cuts are hard cuts between three recordings of one continuous session (dawn; day; branch buying). The session was not restarted between them. About 5 s are missing at each of the two later joins.

## What the video does NOT show
- **The tier-3 reveal** ("The diner grows!", the badges popping in): this fixture is already at tier 3, so the dawn is an ordinary one that carries the lane-character banners (D-289, a save already at tier 3). The reveal is not in this video.
- **Which branch each pad bought.** The cards and the gold falling are visible; the completed branch of each building was not read out. Not every pad payment was checked to completion.
- The refund of a partial payment, a night won with a branch (the video ends as the night starts), and anything on a real phone.
- Performance: nothing here is a measurement. The 1500-gold start and the cut days are not play as a player would meet it.
