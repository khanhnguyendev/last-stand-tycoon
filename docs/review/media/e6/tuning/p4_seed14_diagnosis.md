# Seed 14, first tier-3 night: diagnosis (D-304, D-305)

Tool: `tests/sim/study_first_t3.gd` (one real tier-bot run from day 1, flag on in memory, read-only logging).
What-if arguments change the run in memory only: `--hold=1`, `--commit=1`, `--far=1`, `--base=<n>`.
The raw study outputs of the first pass were NOT kept, and the what-if switches were uncommitted edits on top of
`7f4ee46` at the time (they are committed since `397b4ef`). Rows marked (before) are from that pass and cannot be
checked against a committed file. Verified against committed report outputs: the two "shipped bot" rows and the two
`--base=10` rows. A re-run of every row from committed code is under `rerun/` when present (see the end).
In those rows `--base` set `tier_base[3]`, which also moved Spike's quoted base; the shipped change keeps Spike's base at 12,
so a Volley + Spike figure may differ slightly once a Spike fence is owned (not on the first night: one tower branch only).

## What happened (seed 14, Longbow + Stone, day 21, pressure 12, one branch owned)

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

## First tier-3 night, diner HP left (first attempt; R = lost and retried)

| seed | variant | Longbow + Stone | Volley + Spike | unbranched |
|---|---|---|---|---|
| 14 | shipped bot, start pressure 12 (hold-out #1) | 12.7% | R | R |
| 14 | `--hold=1` (before) | 59.3% | 27.3% | R |
| 14 | `--commit=1` (before) | 24.3% | R | R |
| 14 | `--far=1` (before) | 64.0% | 21.3% | R |
| 14 | `--base=11` (before) | 55.3% | 41.7% | 35.3% |
| 14 | `--far=1 --base=11` (before) | 70.0% | 59.3% | 31.0% |
| 14 | `--base=10` (before) | 98.3% | 84.3% | 79.7% |
| 7 | shipped bot, start pressure 12 (round 2 head) | 57.0% | 73.7% | 13.0% |
| 7 | `--base=11` (before) | 81.3% | 97.0% | 7.7% |
| 7 | `--far=1` (before) | 60.3% | not run | R |
| 7 | `--far=1 --base=11` (before) | not run | not run | 32.3% |
| 7 | `--base=10` (before) | 95.0% | 98.3% | 87.3% |

Later nights under the bot what-ifs (seed 14, Longbow + Stone): `--hold=1` reads 3.7% on day 23 (shipped: 51.0%);
`--commit=1` reads 45.7%; `--far=1` reads 45.7%. No bot rule tried was better on every night.

## Reading

- Cause class (ii), balance: tier 3 started at its cap pressure (12) on the night the player owns one branch and
  two new plain buildings. A softer start fixes the night for every policy with the bot unchanged.
- Contributing, class (i): the bot's hero walks to the far side of the diner for a breached lane and arrives
  after the towers have cleared it. Three rules were tried; each fixed one night and broke or missed another.
  The bot is unchanged (docs/E5_FOLLOWUPS.md).
- Start pressure 11 was not enough: the unbranched reference reads 7.7% on seed 7.
