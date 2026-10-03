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
