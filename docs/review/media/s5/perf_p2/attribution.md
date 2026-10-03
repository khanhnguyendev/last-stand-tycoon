# Stall attribution A/B (S5 Task 7, Step 5)

One profile web export of the branch (Steps 1-4 plus the boot fade), iOS Simulator "iPhone 17 Pro", `export/perf_night3.sh`
(fixture `night3_start`, night-3 60 s window), Mac idle >= 75% before every run (D-209). A = `?warmup=0` (boot fade, no
warm-up), B = no query (warm-up). Runs in the order A1 B1 A2 B2 A3 B3. The flag was verified to reach the game
(desktop Chromium via `seed_save.html`: `?warmup=0` leaves `location.search` = `?warmup=0` and no `WARMUP` console line;
without it the console prints `WARMUP built=12 track=night`).

| run | build | cpu_idle before/after | night-3 avg_fps | night-3 worst_ms |
|---|---|---|---|---|
| A1 | ?warmup=0 | 78% / 66% | 59.7 | 124.0 |
| A2 | ?warmup=0 | 81% / 59% | 59.2 | 136.0 |
| A3 | ?warmup=0 | 78% / 40% | 59.6 | 125.0 |
| B1 | warm-up | 79% / 65% | 59.8 | 104.0 |
| B2 | warm-up | 79% / 64% | 59.7 | 108.0 |
| B3 | warm-up | 76% / 49% | 59.6 | 129.0 |

Medians: unwarmed avg_fps 59.6, worst_ms 125.0; warmed avg_fps 59.7, worst_ms 108.0.

Conclusion: the warmed median worst_ms (108) is lower than the unwarmed one (125), so the stop rule does not fire. The
evidence is modest: the ranges overlap (B3 129 is above A1 124), a 17 ms median gain on three runs each. Both are far above the
60 ms gate (see README.md).
Notes: an earlier set of runs was discarded because the previous run's Safari kept playing during the idle check (idle 57-65%);
`perf_night3.sh` now terminates Safari before it measures idle. Readings were read from the frozen PERF line in each run's screenshot (screenshots not kept).
