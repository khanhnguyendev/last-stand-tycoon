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

## Gates
- night-3 median avg_fps >= 58: **pass** (59.7).
- night-3 median worst_ms < 60: **FAIL** (108.0; main is 134.0, so this is not new in P2, and the warm-up lowered it by 26 ms).
  Not tuned; for the main session (spec 5.4 fallback or section 11 FX cuts).
- day-3 median avg_fps >= main median - 1 (51.7): **pass** (53.0 vs 52.7).

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
about 2.1 s after the night began). Three night-3 runs of the warm-up build (`NIGHT_ONLY=1 export/perf_night3.sh`, idle before
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
frames inside the warm-up) after `top3`. Three night-3 runs with `QUERY=perfwarm=4 NIGHT_ONLY=1` (idle before 77%, 75%, 75%;
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
