# E5 sweep readings (2026-10-06)

Branch `e5/p4-t16-sweep`, headless, 60 fps, starting balance (no tuning round was needed). One call per seed:

```
"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd -- --seed=<n> --days=14                # planner
"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd -- --seed=<n> --days=20 --bot=tier     # tier bot
```

Raw output: `planner_<seed>.txt|.csv`, `tier_<seed>.txt|.csv`. No `STALL` row, no `SCRIPT ERROR` and no `hard_break_day`
in any run. The lines below are copied as printed.

## Lines

| Run | Lines |
|---|---|
| planner 20260930 | `SWEEP first_fail_day=-1 hard_break_day=-1 unspent_day14=2276` · `RETRIES days=14 median=0.0 max_before_day8=0 max=0 target_ok=true` |
| planner 1 | `SWEEP first_fail_day=-1 hard_break_day=-1 unspent_day14=1620` · `RETRIES days=14 median=0.0 max_before_day8=0 max=0 target_ok=true` |
| planner 2 | `SWEEP first_fail_day=-1 hard_break_day=-1 unspent_day14=2736` · `RETRIES days=14 median=0.0 max_before_day8=0 max=0 target_ok=true` |
| tier 20260930 | `SWEEP first_fail_day=12 hard_break_day=-1 unspent_day14=223` · `RETRIES days=20 median=0.0 max_before_day8=0 max=1 target_ok=true` · `TIER first_tier2_day=13 boss_retries=1 cap_nights=5 cap_retries=0` |
| tier 1 | `SWEEP first_fail_day=13 hard_break_day=-1 unspent_day14=77` · `RETRIES days=20 median=0.0 max_before_day8=0 max=1 target_ok=true` · `TIER first_tier2_day=14 boss_retries=1 cap_nights=4 cap_retries=0` |
| tier 2 | `SWEEP first_fail_day=-1 hard_break_day=-1 unspent_day14=563` · `RETRIES days=20 median=0.0 max_before_day8=0 max=0 target_ok=true` · `TIER first_tier2_day=13 boss_retries=0 cap_nights=5 cap_retries=0` |

## Targets (spec 8.2)

| Target | Seed 20260930 | Seed 1 | Seed 2 |
|---|---|---|---|
| Planner at tier 1 clears days 1 to 14 with 0 retries | PASS (max 0) | PASS (max 0) | PASS (max 0) |
| Tier bot's first failed night is its boss night or later | PASS (first fail day 12 = boss night) | PASS (first fail day 13 = boss night) | PASS (no failed night) |
| Tier-2 nights 1 to 3 need at most 1 retry each | PASS (0, 0, 0) | PASS (0, 0, 0) | PASS (0, 0, 0) |
| Gold sink: unspent gold at close-up on day 14, tier bot < planner | PASS (223 < 2276) | PASS (77 < 1620) | PASS (563 < 2736) |
| Hold the cap: every tier-2 cap night cleared with 0 retries | PASS (5 nights, 0 retries, lowest diner 0.123) | PASS (4 nights, 0 retries, lowest diner 0.380) | PASS (5 nights, 0 retries, lowest diner 0.277) |

Per seed:

| | Seed 20260930 | Seed 1 | Seed 2 |
|---|---|---|---|
| Boss night (day) | 12 | 13 | 12 |
| Boss-night retries | 1 | 1 | 0 |
| First night at tier 2 (day) | 13 | 14 | 13 |
| First day with every tower and fence at level 3, yards included | 13 | 15 | 13 |
| Cap nights before / from that day | 0 / 5 | 0 / 4 | 0 / 5 |

The tier-paid day is not a CSV column; it is the day before the boss night (the payment happens in that day's DAY
phase, the night that follows is the boss night).

## Reading

- **The loop holds on all three seeds with the starting values.** No tuning round was run (D-103 not triggered).
- **Boss night:** lost once and won on the retry on two seeds (mercy 0.85 on the second attempt), won first time on
  the third. The sim's allowance is 2 retries.
- **Tier 1 after the cap:** the planner now clears all 14 days without a retry on every seed (before the cap its
  first failed night was day 9 to 11). Staying at tier 1 is safe, and it leaves 1,600 to 2,700 unspent gold by
  day 14.
- **The known gap (D-245) shows quickly.** On seed 20260930 the tier bot builds both yard towers to level 3 on its
  first tier-2 day and maxes both stations by day 14; unspent gold at close-up then grows 223, 659, 1119, 1579, 2329,
  3089, 3999 from day 14 to day 20. Tier 2 has no sink after about two days in this slice.
- **Thin spot:** the lowest cap night is seed 20260930 day 16, diner at 0.123. Day 19 on that seed started with the
  north fence destroyed and still cleared at 1.000.
- Nothing here measures fun or pacing; only bot outcomes.
