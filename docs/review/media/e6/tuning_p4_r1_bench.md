# E6 phase 4, tuning round 1: Longbow bench sensitivity

A measurement. No balance, core, actor or world file was changed; every number is an in-memory override of the lane-type bench
(`tests/support/branch_bench.gd`, flag ON, pressure 12, invulnerable diner, the three-wave mix, all other values as committed:
Longbow range 9.98, Spike pass 24 as committed in the retune set, Volley and Stone wall untouched). Numbers are total diner HP lost over the night
(lower is better), the bench's primary measure.

Reproduce (3 processes, 90, 91 and 130 s of wall time each (the log line `LB WALL TIME`), 24 candidates, about 2 minutes elapsed in all):

```
export GODOT=/Users/ryan/Applications/Godot-4.7.2-stable/Godot.app/Contents/MacOS/Godot
for iv in 2.4 2.2 2.0,1.8; do LB_INTERVALS=$iv "$GODOT" --headless --path . --fixed-fps 60 -s res://addons/gut/gut_cmdln.gd \
  -gconfig= -gtest=res://tests/bench_report/test_longbow_p4_r1.gd -gexit > /tmp/lb_$iv.log 2>&1 & done; wait   # then grep CAND /tmp/lb_*.log
```

## Reading

- "3 brutes" is the bench's full siege mix (the last three waves, that is every wave, carry the lane's brute; brute_cap_main[3] is 1 per wave).
  "1 brute" and "2 brutes": only the last 1 or 2 waves carry it (`TierEffects.brute_counts`: the first tier-3 night has 1, the second 2, from the third 3).
  The support file gained the parameter `brutes` (default = all waves, today's behaviour).
- "Boars only": the bench has NO such lane type. The neutral mix has hares (about a third of the monsters). I added an override `boars_only` (test support):
  the neutral mix with every hare replaced by a boar (same monster count, no brutes, no hares).
- Rules: floor (4 configs x 3 lanes), specialist margin (4 rows), identity (6 rules + the "never best" rules), all through the shared rule functions;
  the first failing rule is named. Every candidate passed all of them, so no rule is named.
- The Longbow levers do not touch Volley, Stone or Spike, so those references are the same in every row.

## References (not Longbow)

| lane | unbranched | Volley | Stone wall | Spike fence |
|---|---|---|---|---|
| siege, 3 brutes | 1780 | 706 | 1478 | 1673 |
| siege, 2 brutes | 1573 | 579 | | |
| siege, 1 brute | 1172 | 372 | | |
| hare | 1693 | 395 | 1355 | 855 |
| neutral | 560 | 100 | 315 | 335 |
| boars only | 670 | 110 | | |

## Longbow candidates (diner HP lost)

Today's values are the first row (interval 2.4, damage 120, brute multiplier 2.0). "All rules" = floor, specialist margin and identity.

| interval s | damage | brute mult | siege 3 brutes | siege 2 | siege 1 | hare | neutral | boars only | all bench rules |
|---|---|---|---|---|---|---|---|---|---|
| 2.4 | 120 | 2 | 412 | 414 | 329 | 1387 | 202 | 155 | PASS |
| 2.4 | 120 | 3 | 327 | 338 | 280 | 1387 | 202 | 155 | PASS |
| 2.4 | 144 | 2 | 373 | 373 | 280 | 1387 | 202 | 155 | PASS |
| 2.4 | 144 | 3 | 301 | 302 | 252 | 1387 | 202 | 155 | PASS |
| 2.4 | 168 | 2 | 327 | 338 | 280 | 1387 | 202 | 155 | PASS |
| 2.4 | 168 | 3 | 301 | 302 | 252 | 1387 | 202 | 155 | PASS |
| 2.2 | 120 | 2 | 233 | 254 | 151 | 1092 | 82 | 55 | PASS |
| 2.2 | 120 | 3 | 197 | 195 | 120 | 1092 | 82 | 55 | PASS |
| 2.2 | 144 | 2 | 217 | 215 | 120 | 1092 | 82 | 55 | PASS |
| 2.2 | 144 | 3 | 181 | 177 | 102 | 1092 | 82 | 55 | PASS |
| 2.2 | 168 | 2 | 197 | 195 | 120 | 1092 | 82 | 55 | PASS |
| 2.2 | 168 | 3 | 181 | 177 | 102 | 1092 | 82 | 55 | PASS |
| 2.0 | 120 | 2 | 114 | 84 | 70 | 828 | 0 | 0 | PASS |
| 2.0 | 120 | 3 | 53 | 38 | 50 | 828 | 0 | 0 | PASS |
| 2.0 | 144 | 2 | 98 | 68 | 50 | 828 | 0 | 0 | PASS |
| 2.0 | 144 | 3 | 45 | 30 | 30 | 828 | 0 | 0 | PASS |
| 2.0 | 168 | 2 | 53 | 38 | 50 | 828 | 0 | 0 | PASS |
| 2.0 | 168 | 3 | 45 | 30 | 30 | 828 | 0 | 0 | PASS |
| 1.8 | 120 | 2 | 0 | 14 | 8 | 545 | 8 | 0 | PASS |
| 1.8 | 120 | 3 | 0 | 4 | 8 | 545 | 8 | 0 | PASS |
| 1.8 | 144 | 2 | 0 | 4 | 8 | 545 | 8 | 0 | PASS |
| 1.8 | 144 | 3 | 0 | 4 | 8 | 545 | 8 | 0 | PASS |
| 1.8 | 168 | 2 | 0 | 4 | 8 | 545 | 8 | 0 | PASS |
| 1.8 | 168 | 3 | 0 | 4 | 8 | 545 | 8 | 0 | PASS |

## What the table says

- All 24 candidates pass every bench rule (marked PASS), the committed values included; the bench rules do not separate them. The choice is a balance one.
- The hare lane moves only with the interval (1387, 1092, 828, 545 for 2.4, 2.2, 2.0, 1.8): a hare dies to one shot at every damage tried, so only the firing rate counts. Volley stays far ahead there (395).
- Siege with 3 brutes: Longbow loses 301 to 412 diner HP at interval 2.4 against Volley 706; at 2.0 it is 45 to 114 and at 1.8 it is 0.
- Neutral and boars-only lanes: the Longbow at 2.4 loses 202 (neutral) and 155 (boars only) against Volley 100 and 110 and unbranched 560 and 670; it passes Volley only
  from interval 2.2 (82 and 55) and loses nothing at 2.0 and 1.8 (0 to 8). So the plain boar lane is a Longbow loss at today's interval and a win from 2.2.
- With one brute the Longbow at today's values loses 329 (siege 1) and 414 (siege 2) against Volley 372 and 579.
- Interval 1.8 with any damage clears the siege lane with zero loss in the bench; that is the bench saying the Longbow no longer needs the damage or multiplier levers there, not a recommendation.
- Cost of reading: the bench is one lane, one tower, no hero (D-292.1); it ranks, it does not predict the real night.
