# E8 perf (D-260): NOT measured

The one-time perf run (spec 4.6) was started on 2026-10-16 and stopped before any reading: the Mac was not idle
(the author's own Steam and Slay the Spire 2 were running; idle 71%, below the script's 75% gate, D-209). Those
apps were not closed. A median taken beside them is not a gate reading (D-199). D-314.32.

Ready for one run on an idle machine:
- Profile build of this branch: `build/web_profile` (gitignored; the `ui/debug` check passes).
- Night-3 reference (the same day): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer export/perf_night3.sh build/web_profile <out>`.
- Tier-4 cap night entered by play: make the day fixture with
  `"$GODOT" --headless --path . -s res://tests/sim/make_save.gd -- --fixture=tier3_cap_day --from=tier4_cap_s1`
  (move its output to a folder outside the repo, with the other fixtures beside it), then
  `FIXTURE_DIR=<that folder> PLAY_ENTERED=1 NIGHT_FIXTURE=tier4_cap_s1 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer export/perf_night3.sh build/web_profile <out>`.
- Warm-up cost of the tier-4 caches: the `WARMUP` line prints no duration. Without a code change, compare
  `?perflog=` `phase_msec` on this build and on `main` with `night3_start`.
Each gate reading is the median of 3 runs.
