# Sweep (tests/sim/sweep.gd, PlannerBot, 14 days, headless, 60 fps)

Branch review/final-package at 23b7d7b. The sweep has one bot (PlannerBot: NaiveBot at night, haul/sell/build by day, card preference tank > archer > hero_damage ...) and takes `--seed=N` and `--days=N`;
it prints a CSV (also `tests/sim/out/sweep.csv`), a `SWEEP` line and a `RETRIES` line. NaiveBot is not swept (it is covered by the night sims). Three seeds were run, one call each (about 92 s per seed). Raw output: `sweep_seed<N>.txt`, `.csv`.

`diner_frac` = the lowest diner HP fraction reached during the night's last attempt; `retries` = failed-night retries (mercy, D-175) that night; the `SWEEP` and `RETRIES` lines below are copied as printed.

## Seed 20260930
`SWEEP first_fail_day=10 hard_break_day=-1 target=10±1`  
`RETRIES days=14 median=0.0 max_before_day8=0 max=3 target_ok=true`

| day | diner_frac | retries | kills | steaks | gold earned | unspent gold at close-up | knockouts | card picked |
|---|---|---|---|---|---|---|---|---|
| 1 | 0.667 | 0 | 18 | 36 | 108 | 8 | 0 | tank |
| 2 | 1.000 | 0 | 24 | 48 | 144 | 32 | 0 | archer |
| 3 | 1.000 | 0 | 31 | 62 | 186 | 38 | 0 | hero_damage |
| 4 | 0.983 | 0 | 36 | 72 | 216 | 34 | 0 | tank |
| 5 | 0.817 | 0 | 43 | 86 | 258 | 12 | 0 | tank |
| 6 | 1.000 | 0 | 50 | 100 | 300 | 32 | 0 | tank |
| 7 | 0.850 | 0 | 56 | 112 | 448 | 260 | 0 | gold_per_steak |
| 8 | 0.417 | 0 | 63 | 126 | 504 | 484 | 0 | archer |
| 9 | 0.083 | 0 | 68 | 136 | 544 | 748 | 0 | tank |
| 10 | 0.802 | 2 | 72 | 144 | 576 | 1044 | 0 | hero_damage |
| 11 | 0.463 | 2 | 75 | 150 | 600 | 1364 | 0 | hero_damage |
| 12 | 0.102 | 2 | 78 | 156 | 624 | 1708 | 0 | hero_damage |
| 13 | 0.707 | 3 | 81 | 162 | 648 | 2076 | 0 | archer |
| 14 | 0.242 | 2 | 82 | 164 | 656 | 2312 | 0 | archer |

## Seed 1
`SWEEP first_fail_day=9 hard_break_day=-1 target=10±1`  
`RETRIES days=14 median=0.0 max_before_day8=0 max=3 target_ok=true`

| day | diner_frac | retries | kills | steaks | gold earned | unspent gold at close-up | knockouts | card picked |
|---|---|---|---|---|---|---|---|---|
| 1 | 0.667 | 0 | 18 | 36 | 108 | 8 | 0 | tank |
| 2 | 0.883 | 0 | 24 | 48 | 144 | 32 | 0 | hero_damage |
| 3 | 0.817 | 0 | 31 | 62 | 186 | 18 | 0 | attack_speed |
| 4 | 0.900 | 0 | 36 | 72 | 216 | 34 | 0 | archer |
| 5 | 1.000 | 0 | 43 | 86 | 258 | 12 | 0 | hero_damage |
| 6 | 1.000 | 0 | 50 | 100 | 300 | 52 | 0 | tank |
| 7 | 0.850 | 0 | 56 | 112 | 336 | 248 | 0 | tank |
| 8 | 1.000 | 0 | 63 | 126 | 378 | 486 | 0 | tank |
| 9 | 0.618 | 1 | 68 | 136 | 408 | 614 | 0 | tank |
| 10 | 0.633 | 0 | 72 | 144 | 432 | 766 | 1 | archer |
| 11 | 0.759 | 1 | 75 | 150 | 450 | 936 | 1 | archer |
| 12 | 0.008 | 1 | 78 | 156 | 468 | 984 | 0 | attack_speed |
| 13 | 0.798 | 3 | 81 | 162 | 486 | 1330 | 0 | hero_damage |
| 14 | 0.468 | 3 | 82 | 164 | 492 | 1542 | 0 | archer |

## Seed 2
`SWEEP first_fail_day=9 hard_break_day=-1 target=10±1`  
`RETRIES days=14 median=0.0 max_before_day8=0 max=3 target_ok=true`

| day | diner_frac | retries | kills | steaks | gold earned | unspent gold at close-up | knockouts | card picked |
|---|---|---|---|---|---|---|---|---|
| 1 | 0.667 | 0 | 18 | 36 | 108 | 8 | 0 | tank |
| 2 | 0.983 | 0 | 24 | 48 | 144 | 32 | 0 | tank |
| 3 | 0.800 | 0 | 31 | 62 | 186 | 18 | 0 | archer |
| 4 | 1.000 | 0 | 36 | 72 | 216 | 14 | 0 | archer |
| 5 | 1.000 | 0 | 43 | 86 | 258 | 32 | 0 | archer |
| 6 | 1.000 | 0 | 50 | 100 | 300 | 132 | 0 | archer |
| 7 | 1.000 | 0 | 56 | 112 | 448 | 580 | 0 | gold_per_steak |
| 8 | 1.000 | 0 | 63 | 126 | 504 | 804 | 0 | tank |
| 9 | 0.688 | 1 | 68 | 136 | 544 | 1068 | 0 | tank |
| 10 | 0.367 | 0 | 72 | 144 | 576 | 1224 | 0 | archer |
| 11 | 0.848 | 2 | 75 | 150 | 600 | 1684 | 0 | tank |
| 12 | 0.043 | 2 | 78 | 156 | 624 | 2028 | 0 | hero_damage |
| 13 | 0.265 | 2 | 81 | 162 | 648 | 2396 | 0 | attack_speed |
| 14 | 0.716 | 3 | 82 | 164 | 656 | 2912 | 0 | hero_damage |

## Reading
- Retries-per-night target (author: median 0 and no night needing more than 2 retries before day 8): the sweep's own `RETRIES` line says `median=0.0 max_before_day8=0 target_ok=true` for all three seeds. Max retries on any night is 3 (days 13-14, past the horizon of the target).
- All 14 days were played on every seed: no `hard_break_day` (the diner never fell through all four retries), no STALL rows.
- `first_fail_day` (first night that failed at least once): 10 (seed 20260930), 9 (seed 1), 9 (seed 2); the balance target printed by the sweep is 10 +/- 1, so all three are inside it.
- Diner margins: nights 1-8 are cleared without a retry on every seed. Lowest `diner_frac` before day 9: 0.417 (seed 20260930, day 8), then 0.667 on day 1 for all seeds (night 1 is the only night with no towers or cards). From day 9 on the margin collapses on every seed (lowest 0.008 seed 1 day 12, 0.043 seed 2 day 12, 0.083 seed 20260930 day 9), which is where retries start.
- Nothing here measures fun or pacing; only PlannerBot outcomes.
