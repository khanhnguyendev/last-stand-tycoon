# Seed 14, first tier-3 night: diagnosis (D-304, D-305)

Tool: `tests/sim/study_first_t3.gd` (one real tier-bot run from day 1, flag on in memory, read-only logging).
What-if arguments change the run in memory only: `--hold=1`, `--commit=1`, `--far=1`, `--base=<n>`.
Every row below is backed by a file under `rerun/` (re-run from committed code at `519490e`, see "Commands"; the first pass came
from uncommitted edits and its raw output was not kept). The last column keeps the first-pass value wherever it differs from the re-run.
In those rows `--base` set `tier_base[3]`, which also moved Spike's quoted base; the shipped change keeps Spike's base at 12,
so a Volley + Spike figure may differ slightly once a Spike fence is owned (not on the first night: one tower branch only).

## What happened (seed 14, Longbow + Stone, day 21, pressure 12, one branch owned; re-run: `rerun/s14_all_a_b12.txt`)

Re-run check: every time and number in this table reproduces from `rerun/s14_all_a_b12.txt` (no correction needed; the fence reads
145 at 36.1 s, the goal changes are at 48, 49, 50, 54 and 58 s, hero positions at 90 s and 98 s are the south-west side and the north side).

Plan: wave 1 main west 7, side north 7; wave 2 main north 12, side south-west 9; wave 3 main south-west 12,
side north 10 with the brute; 5 to 8 hares on east in every wave.

| time | event |
|---|---|
| 0 to 14 s | hero on west (the main lane); the north fence drops from 320 to 145 unattended |
| 48 to 58 s | the hero changes goal five times between north and south-west and attacks nothing |
| 53.1 s | the north fence falls (wave 2) |
| 76.7 s | wave 3 starts: north fence 0, south-west fence 120 of 320 |
| 90 s | hero on south-west with 11 monsters coming; the breached north lane pulls it away (the bot's rule, D-297) |
| 94.3 s | the south-west fence falls behind it |
| 96 to 98 s | the hero reaches north: 1 monster left there; it turns back |
| end | diner 38 of 300 (12.7%); south-west boars dealt 220 of the 262 damage |

## First tier-3 night, diner HP left (first attempt; R = lost and retried, the frac in brackets is the retry row's `final_frac`)

Columns are the policies all_a (Longbow + Stone), all_b (Volley + Spike) and unbranched. Every value is the `final_frac` of the first
`ROW` with `night_start_tier=3` (day 21 on seed 14, day 23 on seed 7). Re-run result: all 32 values reproduce the first pass exactly
(the first pass only recorded "R" for a retried row; the bracketed fractions are new).

| seed | variant | Longbow + Stone (all_a) | Volley + Spike (all_b) | unbranched | first pass (not kept) |
|---|---|---|---|---|---|
| 14 | shipped bot, start pressure 12 (hold-out #1) | 12.7% | R (72.8%) | R (72.5%) | identical |
| 14 | `--hold=1`, base 12 | 59.3% | 27.3% | R (56.4%) | identical |
| 14 | `--commit=1`, base 12 | 24.3% | R (74.2%) | R (72.5%) | identical |
| 14 | `--far=1`, base 12 | 64.0% | 21.3% | R (55.5%) | identical |
| 14 | `--base=11` | 55.3% | 41.7% | 35.3% | identical |
| 14 | `--far=1 --base=11` | 70.0% | 59.3% | 31.0% | identical |
| 14 | `--base=10` | 98.3% | 84.3% | 79.7% | identical |
| 7 | shipped bot, start pressure 12 (round 2 head) | 57.0% | 73.7% | 13.0% | identical |
| 7 | `--base=11` | 81.3% | 97.0% | 7.7% | identical |
| 7 | `--far=1`, base 12 | 60.3% | not run | R (90.6%) | identical |
| 7 | `--far=1 --base=11` | not run | not run | 32.3% | identical |
| 7 | `--base=10` | 95.0% | 98.3% | 87.3% | identical |

Later nights (re-run, seed 14, Longbow + Stone, days 22 to 26; shipped = base 12, bot unchanged):

| day | shipped | `--hold=1` | `--commit=1` | `--far=1` |
|---|---|---|---|---|
| 21 | 12.7% | 59.3% | 24.3% | 64.0% |
| 22 | 80.3% | 64.7% | 78.0% | 77.3% |
| 23 | 51.0% | 3.7% | 45.7% | 45.7% |
| 24 | 77.0% | 69.3% | 77.0% | 77.0% |
| 25 | 94.0% | 80.3% | 84.3% | 85.3% |
| 26 | 97.3% | 81.7% | 95.3% | 84.0% |

Re-run: `--hold=1` reads 3.7% on day 23 (shipped: 51.0%); `--commit=1` reads 45.7%; `--far=1` reads 45.7%. These match the first
pass. No bot rule tried was better than the shipped bot on every night (each is better on day 21 and not better on any later night).

## Reading

- Cause class (ii), balance: tier 3 started at its cap pressure (12) on the night the player owns one branch and
  two new plain buildings. A softer start fixes the night for every policy with the bot unchanged.
- Contributing, class (i): the bot's hero walks to the far side of the diner for a breached lane and arrives
  after the towers have cleared it. Three rules were tried; each fixed one night and broke or missed another.
  The bot is unchanged (docs/E5_FOLLOWUPS.md).
- Start pressure 11 was not enough: the unbranched reference reads 7.7% on seed 7.

## Commands

Run at commit `519490e` (HEAD of `e6/p4b-seed14` before this commit; the study tool is unchanged since). One run, from the repo root:

```
"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/study_first_t3.gd -- --seed=<S> --policy=<all_a|all_b|unbranched> --days=26 [--hold=1|--commit=1|--far=1] --base=<10|11|12> --out=<name>.txt > <name>.raw
```

33 runs (up to 3 at once). From each stdout only the `RUN` and `ROW` lines, and for the first tier-3 night the attempt-1 `PLAN`,
`HEROMOVE`, `FENCE_HP`, `FENCE_FALL`, `NIGHT_END` and `DMG` lines, are kept in `rerun/s<seed>_<policy>_b<base>[_hold|_commit|_far].txt`.
