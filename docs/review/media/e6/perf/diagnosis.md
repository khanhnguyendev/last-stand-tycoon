# E6 A1: the worst-frame diagnosis (artifact or real)

Build: profile web export of `3b2eb7e` (branch `e6/pA-worst-frame`, no code change in this task; `grep -a -c "ui/debug" index.pck` printed 0). Device: iOS Simulator "iPhone 17 Pro", iOS 26.5 (macOS 26.4.1), Safari. Fixture: `tier3_cap_threat` (day 24, tier-3 night), `NIGHT_ONLY=1`, `export/perf_night3.sh`. Runs were interleaved (w2, w3, w5, w2, ...) between 11:10 and 11:35 on 2026-10-08. Last measurement run finished 11:35:00.

## Method
`ui/perf_overlay.gd` already has the parameter: `?perfwarm=<s>` sets the length of the warm-up that precedes the window (default `WARMUP_S` = 2.0 s). The window opens when the seconds since the phase change reach `perfwarm`; the in-window time `@t` counts from the first in-window frame. So night time of a frame = `perfwarm` + `@t` (plus at most one frame). Offsets: default (`perfwarm` 2), `perfwarm=3` (+1 s), `perfwarm=5` (+3 s). No code or script change was needed or made. The frozen line also carries `pre3` (the three worst frames before the window, with their seconds since the phase change), which is the extra evidence below.

## Readings (worst three frames: ms @ in-window s -> night s = perfwarm + in-window)
| offset | run | worst 1 | worst 2 | worst 3 | pre3 (ms @ night s) | avg fps | idle before / mid / after |
|---|---|---|---|---|---|---|---|
| default (warm 2 s) | 1 | 128 @0.2 (night 2.2) | 47 @18.9 (20.9) | 41 @0.2 (2.2) | 1736@1.7 61@1.8 28@1.8 | 57.9 | 80 / 54 / 63 |
| default | 2 | 95 @0.1 (2.1) | 54 @0.2 (2.2) | 42 @0.3 (2.3) | 1496@1.5 38@1.6 27@1.6 | 58.8 | 79 / 69 / 67 |
| default | 3 | 133 @0.2 (2.2) | 38 @18.8 (20.8) | 37 @0.3 (2.3) | 1616@1.6 46@1.7 30@1.7 | 58.8 | 79 / 72 / 64 |
| +1 s (`perfwarm=3`) | 1 | 74 @0.1 (3.1) | 38 @17.7 (20.7) | 37 @0.2 (3.2) | 1528@1.5 55@2.4 40@1.6 | 58.8 | 81 / 69 / 70 |
| +1 s | 2 | 72 @0.1 (3.1) | 39 @17.7 (20.7) | 36 @0.3 (3.3) | 1494@1.5 52@2.4 39@1.6 | 58.6 | 76 / 65 / 59 |
| +1 s | 3 | 70 @0.1 (3.1) | 39 @17.7 (20.7) | 36 @0.2 (3.2) | 1523@1.5 56@2.4 40@1.6 | 58.7 | 83 / 68 / 65 |
| +3 s (`perfwarm=5`) | 1 | 46 @15.8 (20.8) | 36 @35.2 (40.2) | 35 @0.1 (5.1) | 1556@1.6 60@3.4 55@2.4 | 58.6 | 78 / 52 / 63 |
| +3 s | 2 (re-run) | 38 @15.7 (20.7) | 36 @0.1 (5.1) | 35 @0.1 (5.1) | 1501@1.5 54@2.4 54@3.4 | 58.3 | 82 / 59 / 67 |
| +3 s | 3 | 40 @15.7 (20.7) | 36 @0.1 (5.1) | 35 @0.3 (5.3) | 1482@1.5 54@2.4 54@3.4 | 58.8 | 82 / 64 / 68 |

(The first `perfwarm=5` run 2 never left the Godot loading screen at the 100 s screenshot: Safari stalled at the loader, no PERF line; its crop is not kept; it was repeated at once. Idle before 75% or more for every kept run; mid-run idle 52 to 72% as always with the Simulator running, not looped on.)

Crops of all nine overlays: `a1/<offset>_r<n>_crop.png` (`w2` = default, `w3` = +1 s, `w5` = +3 s); one full screenshot: `a1/w2_r1_full.png`.

## Verdict: ARTIFACT (for the 110 ms frame), with a smaller real tail
Evidence. In all nine runs one of the top-3 frames sits at 0.1 to 0.3 s INSIDE the window, whatever the offset, so in night time it moved from about 2.1 s to 3.1 s to 5.1 s with the window (the rule's artifact case), and it shrinks as the window opens later: 95 to 133 ms (default), 70 to 74 ms (+1 s), 35 to 36 ms (+3 s, no longer worse than the normal 36 to 47 ms frames). When the window opens at 5 s no spike above 46 ms is left in it; a frame that was a real event at a fixed night time would stay (and does not: the 128 ms of the default runs is absent from the +1 s and +3 s runs, whose `pre3` lists show nothing above 60 ms in night 2.0 to 3.0 s except the 55 ms at 2.4 s). The cost therefore belongs to the window start plus the first seconds after the load freeze (the 1.5 to 1.7 s frame in every `pre3`, the known load freeze, D-215), not to a night event. Part of the first seconds is real, though: `pre3` of the +1 s and +3 s runs shows hitches of 52 to 56 ms at night 2.4 s (6 of 6 runs) and 54 to 60 ms at 3.4 s (3 of 3 `perfwarm=5` runs). They sit around the banner hide (`banner_time` 2.0 s) and are below the 128 ms of the default reading, but at the gate edge (< 60 ms). I could not prove from these runs what the overlay does at the boundary to make the default frame grow to 95 to 133 ms (the overlay's per-frame work is the same before and after the boundary, `_prime_reads`); the overlay has no per-frame log, so isolating the mechanism needs a frame log (A2).

Second and third worst frames. The second frame (36 to 47 ms) lands at a fixed night time, about 20.7 s, in every default, +1 s and +3 s run (18.8 + 2, 17.7 + 3, 15.7 + 5), which is a real game event, 14.4 s after wave 0 started (`w0,+14.4` in the overlay's top3 detail; wave 0 starts at night 5 s of game time, `first_wave_delay`). The wave-0 enemies spawn at 0.8 s spacing from that moment (`world/wave_director.gd`, `core/wave_schedule.gd`), so the likely cause is the first contact 14 s later (first projectile hits, first enemy death, drops); the runs do not log which, so this is unproven. At 36 to 47 ms it passes the < 60 ms gate. The third frame in the later offsets is 35 to 37 ms, at the window start again (0.1 to 0.3 s) or at 35.2 s of the window.

## What a corrected measurement reads
Excluding the window's first 0.3 s (the window-start artifact) from the same default runs' top-3 lists: run 1 = 47 ms, run 3 = 38 ms, run 2 = at most 42 ms (its list holds only frames at 0.1 to 0.3 s above that; the next frame is below 42). Median about 42 ms (38 to 47). The measured reading at the later window (`perfwarm=5`): 46 / 38 / 40 ms, median 40 ms. Both pass the < 60 ms gate; the corrected worst frame is the real wave-0 event at night 20.7 s. The 52 to 60 ms hitches at night 2.4 s and 3.4 s are not in a corrected default or `perfwarm=5` reading (they fall in the warm-up) but they exist in the `pre3` data and may be felt by a player; A2 should look at them.

## Concerns
- The nine readings are one fixture on one Simulator; the default-window spike varied 95 to 133 ms (three runs) and the 2.4 s / 3.4 s hitches appear in the +1 s and +3 s runs but not in the default top-3 (where they would sit at 0.4 s and 1.4 s into the window and would show above 41 ms). That inconsistency means the window start itself changes what is measured around it; it is why the verdict is "artifact" and not "nothing there".
- The wave-0 + 14.4 s event is not identified.
