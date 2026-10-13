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

# E6 tier-3 reveal clip (STAGED)

`e6_tier3_reveal.mp4` (19.9 s, 720x1566, H.264, no audio, 1.7 MB) and `e6_tier3_reveal_frames.png` (6 frames with timestamps). Author decision D-304.8: the real tier-3 reveal, which `e6_retune.mp4` does not show.

## What it shows
Two pieces of ONE continuous run, joined by one hard cut; no cut inside the reveal.
| Time | Shows |
|---|---|
| 0 to 2 s | Day 18, tier 2: the hero stands at the tier sign and pays the last of the 1500 gold (gold 300 to 200; the sign label changes from "Buy the lot 100" to "Boss tonight"). The first frames are the game's fade-in, so they look dim. |
| cut | The Baron night (about 100 s of real time in the recording: night 18, the boss, the diner holds) is NOT in the clip. |
| 2 to 5 s | Dawn of day 19: "The diner grows!" banner over the grown diner. |
| 5 to 9 s | "Pick a card" (Running Shoes, Fancy Menu, Big Backpack) and the pick banner "Running Shoes Lv 1". |
| 9 to 17 s | Lane-character step: lane badges at the entrances (17 and 4, 7 and 4) and the banners "Heavy tracks on the west road..." (siege) and "Quick paws in the north grass..." (hare). |
Frames (`e6_tier3_reveal_frames.png`): 0.4 s purchase in progress (dim fade-in, gold 300), 1.6 s paid ("Boss tonight", gold 200), 3.2 s the reveal banner, 7.0 s the card pick, 12.2 s lane-character siege banner with badges, 14.6 s lane-character hare banner.

## STAGED: how it differs from play
- Debug web build (`web_debug`, debug overlay visible), iOS Simulator iPhone 17 Pro, Safari, `?retune=1` (flag ON) and `?autoplay=tier` (the tier bot drove the hero: walked to the sign, paid, fought the Baron night, picked the first card). No taps by hand.
- Fixture: `export/fixtures/tier3_baron_full.save.json` (real play, tier 2, day 18, boss night, schema 7), edited in a local copy at `/tmp/t3reveal/fixtures/t3reveal_day.save.json` (outside the repo, NOT committed; checksum recomputed with FNV-1a 32 over the state JSON). Every changed field:
  - `resume_phase`: "NIGHT" to "DAY"
  - `boss_pending`: true to false (so the sign can still be paid)
  - `lane_plan[2].boss`: true to false (the payment sets it again)
  - `tier_paid`: 0 to 1400 (so only the last 100 of the 1500 remain; the clip shows the last instalment, not the whole payment)
  - `gold`: 31 to 300
  Nothing else changed. The first-time reveal runs because the flag is on and `lane_character_shown` is false in the fixture.
- Trimmed from a 233 s recording: segment A is 18.3 to 20.3 s of the raw file (purchase), segment B is 117.6 to 135.4 s (reveal to the hare banner). Fixed 30 fps, scaled 1206x2622 to 720x1566, `-crf 29`.
- A debug build runs at 20 to 50 fps in the Simulator (the overlay shows it); nothing here is a perf reading.

## Reproduce
```bash
export GODOT=/Users/ryan/Applications/Godot-4.7.2-stable/Godot.app/Contents/MacOS/Godot
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
B=/tmp/t3reveal/web_debug; mkdir -p $B/fixtures
"$GODOT" --headless --path . --export-debug "web_debug" $B/index.html
cp export/seed_save.html $B/
sed -i '' 's#</head>#<script>window.LST_BUILD="local";</script></head>#' $B/index.html
# build the edited fixture (python3: copy tier3_baron_full, apply the five edits above, recompute check = fnv1a32(state_json)) into $B/fixtures/t3reveal_day.save.json
python3 export/serve_nocache.py 8766 $B &
UDID=8330DBA8-60B9-4B1F-B177-3410424F28C1; xcrun simctl boot $UDID; open -a Simulator
xcrun simctl io $UDID recordVideo --codec=h264 --force raw.mov &   # stop with SIGINT after about 140 s
xcrun simctl openurl $UDID "http://localhost:8766/seed_save.html?f=t3reveal_day&to=/%3Fretune=1%26autoplay=tier"
ffmpeg -ss 18.3 -t 2.0 -i raw.mov -vf fps=30 a.mp4; ffmpeg -ss 117.6 -t 17.8 -i raw.mov -vf fps=30 b.mp4
ffmpeg -i a.mp4 -i b.mp4 -filter_complex "[0][1]concat=n=2:v=1,scale=720:-2,format=yuv420p[v]" -map "[v]" -c:v libx264 -crf 29 -preset slow -movflags +faststart -an e6_tier3_reveal.mp4
```
The edited fixture is not in the repo; the bot's timing varies, so the cut points move by a few seconds between runs.
