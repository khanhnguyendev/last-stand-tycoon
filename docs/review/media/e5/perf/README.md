# E5 perf readings (spec 8.4): OWED

Not measured on 2026-10-06. The method (D-199, D-209) needs the Mac at 75% idle or more before each run; during the
E5 build it was at about 35% (sweeps, test suites and other programs), the same situation as E1's postponed re-run
(D-235). No number was recorded, so none can be mistaken for a gate reading.

## What to run (one-time, on an idle Mac)

1. Build the profile web export from the E5 head (see `export/README.md`) into `build/web_profile`.
2. Three runs each, read the frozen `PERF phase=NIGHT` line, take the median:

```
NIGHT_ONLY=1 NIGHT_FIXTURE=tier2_night      export/perf_night3.sh build/web_profile docs/review/media/e5/perf/tier2_night_<n>
NIGHT_ONLY=1 NIGHT_FIXTURE=boss_night_tier1 export/perf_night3.sh build/web_profile docs/review/media/e5/perf/boss_night_<n>
                                            export/perf_night3.sh build/web_profile docs/review/media/e5/perf/night3_<n>
```

`NIGHT_FIXTURE` is new in this branch (default `night3_start`, so the old invocation is unchanged). The third line is
the same-machine, same-day reference for D-221's readings, and it runs the DAY half too (no `NIGHT_ONLY`): the day
phase is the one already 0.1 fps under its gate (known issue 1), and every day now carries the tier sign.

## Gate (spec 8.4)

Average fps within the ±1 fps spread of the night-3 reference taken the same day (D-221: 59.9); worst frame no worse
than 106 ms. Record draw calls (expected at tier 2: night 36 as before, +1 for the yard stones, + the two yard towers
and their labels; on a boss night +2 for the boss bar while the boss lives).

## Limits of these fixtures

- The overlay's window is the first 60 s after a 2 s warm-up. On `boss_night_tier1` the boss arrives with wave 3,
  after that window, so the reading covers waves 1 and 2 of a day-12 night, not the boss. `boss_only` puts the boss
  on screen about 25 s in, but with no other monster; it measures the boss mesh and its bar only.
- `tier2_night` is the cap night (75 monsters, 27 hares, four towers and three fences at level 3): the heaviest night in this slice.
- The tier-up dawn (ground mesh swap, props re-merge, five pops, camera move) is not covered by any perf fixture. The
  warm-up pre-builds the tier-2 terrain and props; whether the dawn hitches on a phone is a checkpoint question.
- Load time and memory with the larger steak pool (300, was 173) are unmeasured.
