# P2 perf checkpoint (S5 Task 7, Step 6)

Profile builds of this branch (`s5/p2-t07-warmup`, base `0a61bb1` plus Task 7) and of origin/main (`37d14b3`, S5-P1 merged),
iOS Simulator "iPhone 17 Pro", `export/perf_night3.sh`, Mac idle >= 75% before each run. Branch runs B1-B3 are the
warm-up runs of attribution.md (same build, no query). Day-3 reading = frozen `PERF phase=DAY` line of `day_peak.png`
(fixture `night3_closeup`, 90 s after launch).

| run | cpu_idle before/after | night-3 avg_fps | night-3 worst_ms | day-3 avg_fps | day-3 worst_ms |
|---|---|---|---|---|---|
| branch 1 | 79% / 65% | 59.8 | 104.0 | 52.3 | 119.0 |
| branch 2 | 79% / 64% | 59.7 | 108.0 | 53.0 | 57.0 |
| branch 3 | 76% / 49% | 59.6 | 129.0 | 53.1 | 70.0 |
| **branch median** | | **59.7** | **108.0** | **53.0** | 70.0 |
| main 1 | 79% / 58% | 59.6 | 134.0 | 52.6 | 98.0 |
| main 2 | 77% / 41% | 59.2 | 131.0 | 52.8 | 94.0 |
| main 3 | 79% / 49% | 59.6 | 142.0 | 52.7 | 106.0 |
| **main median** | | **59.6** | **134.0** | **52.7** | 98.0 |

(cpu_idle_after is taken while Safari is still playing the game, so it is always lower; only "before" gates validity.)

## Gates (superseded by "Gate reading after the boot-fade hold and overlay priming" below, median 71)
Readings from the build before the fade hold and the overlay priming:
- night-3 median avg_fps >= 58: **pass** (59.7).
- night-3 median worst_ms < 60: **FAIL** (108.0). Branch vs main: -26 ms (main 134.0); same-build A/B (warm-up vs `?warmup=0`): -17 ms.
  Not tuned; for the main session (spec 5.4 fallback or section 11 FX cuts).
- day-3 median avg_fps >= main median - 1 (51.7): **pass** (53.0 vs 52.7). This day reading predates the fade hold and the
  overlay priming and was not repeated.

Phase-change music registration hitch: not visible. The PERF line holds one worst_ms per 60 s window (the same reading with
or without the warm-up, 104-142 ms on all builds), the night fixture resumes straight into night, and the window starts 2 s
after the phase, so a registration at the first dawn or night start cannot be told apart from the other stalls with this
instrument. The warm-up now registers the resume phase's track behind the boot fade.

## Desktop draw calls with FX active
Real renderer (macOS, Compatibility), `tests/sim/capture.gd` (a temporary copy that printed
`RENDER_TOTAL_DRAW_CALLS_IN_FRAME` after the 3 frames of the `--fx` burst), 720x1280:

| scene | no FX | FX active |
|---|---|---|
| night (`--phase=night`) | 27 | 28 (poof 8 quads, hit 4 quads) |
| day (`--phase=day`) | 49 | 50 (poof 8, coin 5) |

FX adds exactly 1 draw call (the single FxField). Day is 49 here against the 48 S4 recorded; the extra call predates this
task (P1/P2 content), the FX increment is the expected +1.

## Where the worst frames happen
`ui/perf_overlay.gd` now appends `top3=<ms>@<s into the 60 s window>(w<last started wave, -1 none>,+<s since that
wave_started, -1 none>)` for the 3 worst frames of the window (the window starts 2 s after the phase change, so `@0.1s` is
about 2.1 s after the night began). Three night-3 runs of the warm-up build (`export/perf_night3.sh`, both phases ran and only the night screenshot was read, idle before
78%, 79%, 80%; screenshots in `runs/top3_run<N>.png`):

| run | avg_fps | worst_ms | top3 |
|---|---|---|---|
| 1 | 59.8 | 75.0 | `75@0.1s(w-1,-1) 38@0.2s(w-1,-1) 36@0.2s(w-1,-1)` |
| 2 | 59.7 | 109.0 | `109@0.1s(w-1,-1) 35@0.2s(w-1,-1) 34@0.2s(w-1,-1)` |
| 3 | 59.7 | 121.0 | `121@0.2s(w-1,-1) 42@0.2s(w-1,-1) 31@58.2s(w1,+20.7)` |

Reading: the single ~75-121 ms frame is in the first 0.2 s of the window (about 2.1-2.2 s after the phase change), before any
`wave_started` (the first wave starts about 5 s into the phase), so it is not tied to a wave start, its banner, a lane's
first spawn or tank behaviour. The next two worst frames are also in that 0.2 s span (31-42 ms). Everything later in the window
is below about 31 ms (run 3's third frame, 31 ms at 58.2 s, is 20.7 s after wave 1 started). So the remaining stall is a one-off
just after the window opens, not a recurring in-wave one. The instrument cannot say what runs then; candidates to check are
whatever completes about 2 s after the phase change (the boot fade-out/free, the first frame after the loading/resume work, an
unflushed GPU upload). Nothing was fixed or tuned.

### Experiment: warm-up length (`?perfwarm=4`)
`ui/perf_overlay.gd` reads `?perfwarm=<s>` (default 2.0) and appends `pre3=<ms>@<s since the phase change>s ...` (the 3 worst
frames inside the warm-up) after `top3`. Three night-3 runs with `QUERY=perfwarm=4` (both phases ran; only the night screenshot was read) (idle before 77%, 75%, 75%;
screenshots `runs/perfwarm4_run<N>.png`):

| run | avg_fps | worst_ms | top3 (window) | pre3 (warm-up, 0 to 4 s) |
|---|---|---|---|---|
| 1 | 59.4 | 52.0 | `52@0.1s 43@50.5s(w1,+15.1) 30@0.2s` | `874@0.9s 53@1.6s 52@2.6s` |
| 2 | 59.7 | 50.0 | `50@0.1s 35@0.2s 30@35.2s(w0,+33.5)` | `829@0.8s 52@2.0s 41@1.0s` |
| 3 | 59.7 | 56.0 | `56@0.1s 33@59.3s(w1,+24.0) 32@0.1s` | `806@0.8s 55@2.1s 36@3.1s` |

Reading (no fix applied):
- The 75-121 ms frame at about 2.1 s is gone: with a 4 s warm-up no frame in the 2.0-2.6 s span is above 55 ms.
- Both warm-ups show a worst frame 0.1 s after their own boundary (`@0.1s` in top3), now 50-56 ms instead of 75-121 ms. That
  frame follows the overlay's boundary when the boundary moves, so part of the stall is tied to what the overlay itself starts at
  the boundary (first `Performance.get_monitor` calls, label/state change, `_track_top`). It is smaller here, and a 50 ms frame
  also sits at 2.0-2.6 s inside the warm-up in each run (52, 52, 55 ms), so a real ~50 ms event about 2 s after the night starts
  is not excluded.
- The warm-up now holds the largest frame by far: 806-874 ms at 0.8-0.9 s after the phase change (the resume/first-night load),
  outside every window.
- All three window worst_ms values (50-56) are under the 60 ms gate when the window opens at 4 s; this is a measurement
  observation, not a result for the gate, which is defined with the 2 s warm-up.

### Experiment: the pre-window stall with and without the warm-up (`?warmup=0&perfwarm=4`)
Same build, `QUERY="warmup=0%26perfwarm=4"` (both phases ran; the `&` was encoded by hand as `%26`, the script now does it; checked in desktop Chromium that the
game URL becomes `/?warmup=0&perfwarm=4` and prints no `WARMUP` line). Idle before 78%, 80%, 80%; screenshots
`runs/nowarmup_perfwarm4_run<N>.png`. For comparison, the warmed `perfwarm=4` runs are in the table above.

| run | avg_fps | worst_ms | top3 (window) | pre3 (warm-up, 0 to 4 s) |
|---|---|---|---|---|
| 1 | 59.7 | 122.0 | `122@7.0s(w0,+4.1) 94@11.2s(w0,+8.3) 70@0.1s(w-1,-1)` | `2169@2.2s 62@2.9s 51@3.9s` |
| 2 | 59.7 | 129.0 | `129@6.9s(w0,+4.1) 96@11.1s(w0,+8.3) 46@0.1s(w-1,-1)` | `2094@2.1s 54@4.0s 45@2.2s` |
| 3 | 59.6 | 119.0 | `119@7.0s(w0,+4.1) 101@11.2s(w0,+8.3) 52@0.1s(w-1,-1)` | `2179@2.2s 52@3.0s 51@2.3s` |

Reading (no fix applied):
- The big pre-window frame exists without the warm-up and is larger: 2094-2179 ms at 2.1-2.2 s after the phase change, against
  806-874 ms at 0.8-0.9 s with it. It is not caused by the warm-up (freeing its nodes, the stream registration); the warm-up
  moves part of the first-use cost behind the boot fade, and about 0.85 s still remains after the fade.
- Without the warm-up two more frames appear inside the window, both after wave 0 started: about 120 ms at +4.1 s and about
  95 ms at +8.3 s (about 7.0 s and 11.2 s into the window). The warmed runs have no frame in that range above 43 ms, so these look
  like first-use costs the warm-up covers. The instrument does not say which asset they are.

## Gate reading after the boot-fade hold and overlay priming (D-215 amendment)
Changes: `BootFade` stays opaque after `fade_out()` until `boot_fade_stable_frames` (10) consecutive frames are each under
`boot_fade_stable_ms` (50), or `boot_fade_max_s` (4.0) after `fade_out()`; then it fades over `boot_fade_out_s`. It prints
`BOOTFADE done=<s> frames=<n>` once. The perf overlay now does the same `Performance.get_monitor` reads during its warm-up
(values discarded). Fresh `web_profile` build, default 2 s overlay warm-up, both phases ran (only the night screenshot was read), idle before 76%, 78%, 76%
(screenshots `runs/gate_run<N>.png`):

| run | avg_fps | worst_ms | top3 (window) | pre3 (warm-up, 0 to 2 s) |
|---|---|---|---|---|
| 1 | 59.8 | 70.0 | `70@0.1s(w-1,-1) 33@0.2s(w-1,-1) 28@20.1s(w0,+16.4)` | `861@0.9s 54@2.0s 35@1.0s` |
| 2 | 59.7 | 87.0 | `87@0.1s(w-1,-1) 35@0.2s(w-1,-1) 34@0.2s(w-1,-1)` | `917@0.9s 35@1.1s 21@0.9s` |
| 3 | 59.8 | 71.0 | `71@0.1s(w-1,-1) 34@0.1s(w-1,-1) 33@0.2s(w-1,-1)` | `882@0.9s 33@2.0s 28@0.9s` |
| **median** | **59.8** | **71.0** | | |

Gates (night-3, the 2 s window): median `avg_fps` >= 58 **pass** (59.8); median `worst_ms` < 60 **FAIL** (71.0, was 108.0 before
this change and 134.0 on main). The day-3 gate was not read in these runs. The frame at `@0.1s` of the window (70-87 ms)
is still there: priming the reads did not remove it, so it is not explained by the first `get_monitor` calls; it remains at
about 2.1 s after the phase change. Nothing else tuned.

The 806-917 ms load frame (`pre3`, 0.9 s after the phase change) is unchanged by the overlay; what changed is the cover:
- Simulator, one-off run with a screenshot about every second from launch (`runs/early_s11..s15.png`, 302 px wide): after the
  Godot splash (s11), s12 and s13 are the plain night-sky fade colour with no HUD or world, s14 is the fade half dissolved
  (the "The monsters return" banner shows through), s15 is clear. So the cover is still opaque after the phase started and the
  freeze is no longer seen by the player.
- Desktop Chromium (Playwright Pixel 7, software GL, so frames are never stable): `WARMUP built=12 track=night`,
  `BOOTFADE done=4.01 frames=12` and `done=4.05 frames=11` in two loads, i.e. the 4.0 s cap lifted it. On a device the
  stable-frames rule decides; this Chromium run only shows the cap and the print work. The Simulator console is not readable,
  so the device `BOOTFADE` line is not captured; the screenshots above are its evidence.

### Correction (Task 7 review)
The earlier runs labelled `NIGHT_ONLY=1` above were made before that flag existed in the committed script (the local edit that was meant
to add it did not apply). Both the day and the night half ran each time, the day screenshot was ignored, and the night readings
are valid as recorded. `export/perf_night3.sh` now has `NIGHT_ONLY=1` and encodes `&` in `QUERY`.
