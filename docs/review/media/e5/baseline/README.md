# E5 baseline re-record (D-237)

Rows 1 to 7 are untouched. Proof, `tools/baseline_rows.sh 7` against the OLD baseline, before the re-record:

```
seed 20260930: SWEEP first_fail_day=-1 hard_break_day=-1 unspent_day14=2276
seed 20260930: RETRIES days=14 median=0.0 max_before_day8=0 max=0 target_ok=true
seed 11: SWEEP first_fail_day=-1 hard_break_day=-1 unspent_day14=2320
seed 11: RETRIES days=14 median=0.0 max_before_day8=0 max=0 target_ok=true
seed 777: SWEEP first_fail_day=-1 hard_break_day=-1 unspent_day14=1740
seed 777: RETRIES days=14 median=0.0 max_before_day8=0 max=0 target_ok=true
rows 1-7 identical
```

Rows 8 to 14 changed because pressure stops at 7 at tier 1 (the tier-1 cap). In the old CSV `enemy_count` was computed from the day (`Economy.night_kills(day)`), so it printed uncapped counts; the new column sums the night's own plan. Other columns that moved in rows 8 to 14 (see the `.csv.diff` files): `steaks`, `gold_earned`, `builds_defending`, `night_seconds`, `day_seconds`, `cards`, `picked`. Format of each cell: before -> after.

## Seed 20260930

| day | enemy_count | kills | failed_retries | diner_frac | unspent_gold_at_closeup |
|---|---|---|---|---|---|
| 8 | 63 -> 56 | 63 -> 56 | 0 -> 0 | 0.417 -> 0.917 | 484 -> 428 |
| 9 | 68 -> 56 | 68 -> 56 | 0 -> 0 | 0.083 -> 0.983 | 748 -> 736 |
| 10 | 72 -> 56 | 72 -> 56 | 2 -> 0 | 0.802 -> 0.850 | 1044 -> 1044 |
| 11 | 75 -> 56 | 75 -> 56 | 2 -> 0 | 0.463 -> 0.900 | 1364 -> 1212 |
| 12 | 78 -> 56 | 78 -> 56 | 2 -> 0 | 0.102 -> 0.800 | 1708 -> 1520 |
| 13 | 81 -> 56 | 81 -> 56 | 3 -> 0 | 0.707 -> 0.850 | 2076 -> 1828 |
| 14 | 82 -> 56 | 82 -> 56 | 2 -> 0 | 0.242 -> 1.000 | 2312 -> 2276 |

Before (`old/s4_sweep_20260930.txt`):
```
SWEEP first_fail_day=10 hard_break_day=-1 target=10±1
RETRIES days=14 median=0.0 max_before_day8=0 max=3 target_ok=true
```
After:
```
SWEEP first_fail_day=-1 hard_break_day=-1 unspent_day14=2276
RETRIES days=14 median=0.0 max_before_day8=0 max=0 target_ok=true
```

## Seed 11

| day | enemy_count | kills | failed_retries | diner_frac | unspent_gold_at_closeup |
|---|---|---|---|---|---|
| 8 | 63 -> 56 | 63 -> 56 | 0 -> 0 | 0.850 -> 0.983 | 486 -> 584 |
| 9 | 68 -> 56 | 68 -> 56 | 0 -> 0 | 0.700 -> 1.000 | 614 -> 920 |
| 10 | 72 -> 56 | 72 -> 56 | 0 -> 0 | 0.567 -> 1.000 | 766 -> 1256 |
| 11 | 75 -> 56 | 75 -> 56 | 1 -> 0 | 0.787 -> 1.000 | 936 -> 1592 |
| 12 | 78 -> 56 | 78 -> 56 | 2 -> 0 | 0.288 -> 0.850 | 1264 -> 1788 |
| 13 | 81 -> 56 | 81 -> 56 | 3 -> 0 | 0.771 -> 0.883 | 1610 -> 1984 |
| 14 | 82 -> 56 | 82 -> 56 | 2 -> 0 | 0.253 -> 1.000 | 1822 -> 2320 |

Before (`old/s4_sweep_11.txt`):
```
SWEEP first_fail_day=11 hard_break_day=-1 target=10±1
RETRIES days=14 median=0.0 max_before_day8=0 max=3 target_ok=true
```
After:
```
SWEEP first_fail_day=-1 hard_break_day=-1 unspent_day14=2320
RETRIES days=14 median=0.0 max_before_day8=0 max=0 target_ok=true
```

## Seed 777

| day | enemy_count | kills | failed_retries | diner_frac | unspent_gold_at_closeup |
|---|---|---|---|---|---|
| 8 | 63 -> 56 | 63 -> 56 | 0 -> 0 | 0.867 -> 0.583 | 186 -> 144 |
| 9 | 68 -> 56 | 68 -> 56 | 0 -> 0 | 0.650 -> 1.000 | 314 -> 340 |
| 10 | 72 -> 56 | 72 -> 56 | 1 -> 0 | 0.150 -> 0.950 | 466 -> 536 |
| 11 | 75 -> 56 | 75 -> 56 | 1 -> 0 | 0.632 -> 1.000 | 496 -> 872 |
| 12 | 78 -> 56 | 78 -> 56 | 2 -> 0 | 0.802 -> 1.000 | 684 -> 1208 |
| 13 | 81 -> 56 | 81 -> 56 | 2 -> 0 | 0.498 -> 1.000 | 890 -> 1544 |
| 14 | 82 -> 56 | 82 -> 56 | 3 -> 0 | 0.807 -> 0.950 | 1102 -> 1740 |

Before (`old/s4_sweep_777.txt`):
```
SWEEP first_fail_day=10 hard_break_day=-1 target=10±1
RETRIES days=14 median=0.0 max_before_day8=0 max=3 target_ok=true
```
After:
```
SWEEP first_fail_day=-1 hard_break_day=-1 unspent_day14=1740
RETRIES days=14 median=0.0 max_before_day8=0 max=0 target_ok=true
```

`tools/baseline_diff.sh` after the re-record:
```
baseline identical
```
