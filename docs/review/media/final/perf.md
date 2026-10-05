# Final perf (iOS Simulator "iPhone 17 Pro", profile builds, `export/perf_night3.sh`)

Branch = `review/final-package` (main 23b7d7b + this commit's debug-only autoplay and the perf script's mid-run sample; the profile pack excludes `ui/debug`, so the game code is main's). Main = S4 `main` at c8cce18 (temporary worktree, removed afterwards).
Both builds were run with the same (new) script and the same fixtures (`export/fixtures` is identical in both trees). Runs alternate branch, main, branch, main, ... one run per call. Day-3 = frozen `PERF phase=DAY` (fixture `night3_closeup`), night-3 = frozen `PERF phase=NIGHT` (fixture `night3_start`).
Crops of the PERF lines: `perf/<run>/day_peak_crop.png`, `night3_80s_crop.png`; full screenshots and the script output (`run.txt`) next to them.
The Mac reached >= 75% idle before every kept run (the script waited up to 10 minutes). `cpu_idle_mid` is new: sampled in a background subshell halfway through each wait (45 s of the day wait, 50 s of the night wait) while Safari is playing, so it includes the Simulator's own load and is always lower than "before".

## Readings
| run | idle before | idle mid (day / night) | idle after | night avg_fps | night worst_ms | day avg_fps | day worst_ms | night top3 |
|---|---|---|---|---|---|---|---|---|
| branch 1 | 79% | 50% / 58% | 65% | 59.9 | 85.0 | 52.9 | 56.0 | 85@0.1s 33@0.2s 32@0.2s |
| main 1 | 81% | 66% / 54% | 68% | 59.8 | 114.0 | 54.1 | 125.0 | n/a (S4 has no top3) |
| branch 2 | 81% | 65% / 61% | 60% | 59.9 | 107.0 | 53.3 | 74.0 | 107@0.1s 34@0.2s 32@0.2s |
| main 2 | 75% | 63% / 51% | 47% | 59.6 | 142.0 | 54.0 | 90.0 | n/a |
| branch 3 | 78% | 66% / 64% | 44% | 59.8 | 106.0 | 52.7 | 71.0 | 106@0.1s 36@0.2s 33@0.2s |
| main 3 | 81% | 64% / 51% | 44% | 59.7 | 119.0 | 53.3 | 90.0 | n/a |
| **branch median** | | | | **59.9** | **106.0** | **52.9** | 71.0 | |
| **main median** | | | | **59.7** | **119.0** | **54.0** | 90.0 | |

Day top3 (branch): run 1 56@0.1s 52@0.1s 38@0.2s; run 2 74@0.1s 38@0.2s 35@0.2s; run 3 71@0.1s 39@0.2s 36@0.1s. The worst frame is at 0.1 s of the window in every branch run (the window's own start), as in S5.

## Gates
- night-3 median avg_fps >= 58: **pass** (59.9; main 59.7).
- night-3 median worst_ms < 60: **FAIL** (106.0; main 119.0). Only branch run 1 is lower (85.0); no run is under 60.
- day-3 median avg_fps >= main median - 1 (54.0 - 1 = 53.0): **FAIL by 0.1** (52.9 vs 54.0; branch range 52.7-53.3, main range 53.3-54.1).

## Invalid runs (discarded, repeated; logs in `perf/invalid/`)
- `branch3_screenshot_timeout`: `simctl io screenshot` failed with "Timeout waiting for screen surfaces" at the night shot; run.txt only.
- `branch3_day_not_frozen`: the day overlay read "win 59s" (not frozen) at the 90 s shot, i.e. the load was slower than the window; its night reading was avg 59.6 / worst 68.0 (idle mid 39% / 45%). Replaced by the third branch run above.
- main 3 waited the full 10 minutes for idle (the script's 40 x 15 s loop) before the kept reading; the tool call outlived its 600 s timeout but the script finished normally (exit 0).
- Idle "mid" and "after" often sit well below "before" (down to 39-47% in some runs) because Safari plus the Simulator's own GPU/CPU work is included; whether other processes also ran mid-run cannot be separated from these figures.
