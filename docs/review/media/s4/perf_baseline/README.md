# S4 perf baseline (placeholder art, before P2)

Profile build (`web_profile`) of branch `s4/p1-t05-perf`; fixtures from `tests/sim/make_save.gd` (seed 20260930, day 3).
Readings are the overlay's frozen line. The overlay resets on every `phase_changed`, skips the first 2 s (so the
first wave spawn at 5 s is inside the reading), and freezes once 60 s of counted frames are accumulated. Every field
is computed over those same frames.

| Device | Scenario | Frozen line | Screenshot |
|---|---|---|---|
| iOS Simulator (iPhone Pro, Safari) | night 3 | `PERF phase=NIGHT day=3 window=60s avg_fps=58.9 worst_ms=78.0 proc_ms=15.65 phys_ms=1.15 dc=35 slow_pct=1.9 delta_worst_ms=78.7` | `night3_80s.png` |
| iOS Simulator | day 3 peak (travelers queued) | `PERF phase=DAY day=3 window=60s avg_fps=52.2 worst_ms=66.0 proc_ms=22.64 phys_ms=1.19 dc=59 slow_pct=16.4 delta_worst_ms=68.6` | `day_peak.png` |
| Emulated Pixel 7 (Playwright, software GL on a desktop CPU; not a device number, D-141) | night 3 | `PERF phase=NIGHT day=3 window=60s avg_fps=8.0 worst_ms=290.6 proc_ms=151.70 phys_ms=0.54 dc=34 slow_pct=99.8 delta_worst_ms=147.3` | `night3_80s_emulated.png` |

Fields:
- `avg_fps` = counted frames / their summed raw time; `worst_ms` = the longest raw frame in the window. Raw time comes from `Time.get_ticks_usec()` deltas.
- `proc_ms`, `phys_ms` (`Performance.TIME_PROCESS`, `TIME_PHYSICS_PROCESS`), `dc` (draw calls) are per-frame averages over the same frames. `slow_pct` is the share of frames over 20 ms.
- `delta_worst_ms` is the worst `_process` `delta` over the same frames. The engine clamps `delta` (the emulated run's 147 ms vs a 290 ms raw frame), so a flat 150 ms reading is the clamp, not the frame.

Notes:
- iOS night-3 average is 58.9, above the D-196 target of 58 by a small margin; the worst raw frame is 78 ms. The Simulator uses the Mac's GPU, so it is a rough proxy for a phone.
- The night screenshot is taken 100 s after `openurl`. Night 3 is about 91 s long (headless), so the dawn card pick is on screen by then; the frozen night line stays on screen until the next freeze, so the reading is on the shot.
- Needs load + 2 s warm-up + 60 s window < 100 s for the night line to be frozen before the shot (true on this machine).
