# Tier-3 checkpoint perf (iOS Simulator "iPhone 17 Pro", iOS 26.5, profile web build, `export/perf_night3.sh`)

Build: profile export of `32b4f95` (the phase branch head; this task's only code change is under `ui/debug/`, which the profile pack excludes: `grep -a -c "ui/debug" index.pck` printed 0). Fixture: `tier3_cap_threat` (day 24, tier-3 night, full build with branches), `NIGHT_ONLY=1`. Measured once (D-260). The gate reading is the frozen `PERF phase=NIGHT` line, median of three runs (D-199).

## Readings
| run | idle before | idle mid (night) | idle after | avg_fps | worst_ms | proc_ms | phys_ms | dc | slow_pct | top3 |
|---|---|---|---|---|---|---|---|---|---|---|
| run 1 (`att1`) | 76% | 60% | 46% | 58.8 | 110.0 | 21.88 | 1.05 | 48 | 0.5 | 110@0.1s 38@18.7s 37@0.2s |
| run 2 (`att2`) | 81% | 69% | 68% | 58.9 | 153.0 | 16.69 | 1.12 | 48 | 0.5 | 153@0.2s 38@18.8s 27@11.2s |
| run 3 (`att3`) | 82% | 58% | 66% | 58.5 | 110.0 | 20.89 | 1.10 | 48 | 1.1 | 110@0.1s 39@18.7s 35@0.2s |
| **median of runs 1-3 (the gate reading)** | | | | **58.8** | **110.0** | 20.89 | 1.10 | 48 | 0.5 | |
| extra run (`att4`) | 81% | 70% | 57% | 58.7 | 144.0 | 19.74 | 1.13 | 48 | 1.2 | 144@0.2s 38@18.7s 27@57.1s |
| extra run (`att5`) | 79% | 68% | 63% | 58.6 | 137.0 | 19.39 | 1.10 | 48 | 1.0 | 137@0.2s 47@18.7s 35@0.2s |
| median of all five | | | | 58.7 | 137.0 | | | | | |
| discarded (`disturbed_a`) | 78% | 71% | 62% | 58.6 | 125.0 | 18.02 | 1.07 | 48 | 1.2 | 125@0.2s 39@18.7s 33@0.2s |
| tier-2 comparison (`tier2`, `tier2_night`, day 16) | 78% | 65% | 64% | 59.4 | 110.0 | 16.05 | 1.03 | 43 | 0.4 | 110@47.5s 110@48.3s 107@50.5s |

Raw lines are in each `attN/night3_80s_crop.png` (crop of the overlay) and `attN/night3_80s.png` (full screenshot), the script output in `attN/run.txt`.

## What the runs say
- All three gate runs and both extra runs read 58.5 to 58.9 average fps: a spread of 0.4 fps. Worst frame 110 to 153 ms; in every tier-3 run it lands at 0.1 to 0.2 s of the window (the window's own start, the known issue below). Apart from it the next frames are 37 to 47 ms at about 18.7 s (the same moment each run: a wave spawn).
- Draw calls 48 at tier 3 against 43 at tier 2 (the extra tier-3 spots and their pads).
- No tuning was done.

## Idle caveat (read before trusting "mid")
The script waits for 75% idle before it starts; every kept run began at 76 to 82%. The mid-run sample (halfway through the wait, Safari playing) never reached 75% in any run (58 to 71%) because it includes the Simulator's own load; the previous final reading shows the same pattern (idle mid 51 to 66% at night, down to 39 to 47% in some runs, `docs/review/media/final/perf.md`). A literal "repeat any run whose mid-run idle is under 75%" rule cannot be met on this Mac, so the criterion applied was idle before >= 75%. Seven readings were taken in all (five tier-3 runs, `disturbed_a`, one tier-2 run): `disturbed_a` (taken while `corespotlightd` held about 100% of a core, which also held the idle-before wait for 9 cycles) is listed but not used; runs 1 to 5 followed it.

## Previous reference (quoted)
From `docs/review/media/final/perf.md` (branch `review/final-package`, fixture `night3_start`, a tier-1 night 3): night-3 median avg_fps 59.9 (main 59.7), median worst_ms 106.0 (85.0 / 107.0 / 106.0; S4 main 119.0; gate < 60 failed); day-3 median 52.9 (main 54.0).
From `docs/REVIEW_QUEUE.md` "Known issues": item 1: the day phase runs at about 53 fps in the iOS Simulator and night about 59.9; item 2: night-3 worst frame 106 ms in the final reading (71 ms at the S5 P2 checkpoint, 108 ms at the end of S5), landing about 2.1 s after the night starts at the moment the first banner hides and the overlay's window opens, cause unproven.

## Comparison in one line
Tier-3 night (`tier3_cap_threat`) median 58.8 fps / 110 ms worst against the final tier-1 night-3 reading of 59.9 fps / 106 ms: 1.1 fps lower, worst frame about the same. The tier-2 night (`tier2_night`, one run) read 59.4 fps / 110 ms. The fixtures differ (tier, day, enemy count), so this is a comparison of readings, not of builds. The night-3 worst-frame gate (< 60 ms) stays failed, as in the final reading.
