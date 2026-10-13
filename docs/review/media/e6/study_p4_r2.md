# E6 phase 4 study, round 2: seed 7's first tier-3 night under round 1

A measurement study. No balance, core, actor or world file was changed; every what-if is in memory in the study runner
(`tests/sim/study_first_t3_runner.gd`, launched by `tests/sim/study_first_t3.gd`; new arguments `--interval`, `--variant`, `--pin=<lane>:<from_s>:<row>`).
Commit under study: `5405c99` (round 1: Longbow interval 2.2 s, flag on in memory). Every run is a real tier-bot run from day 1 (no resume exists).
Seeds run: 1, 4, 7 only (no hold-out seed). The runs are deterministic: the unmodified threat, all_b and unbranched runs reproduce the round-1 report's seed-7 numbers
(0.127, 0.773, 0.912). Attribution rules (shots, hits, kills per shooter, diner damage by lane and kind) are those of `study_first_t3.md`: a study attribution, +-10%.
The diner damage tables sum exactly to the HP lost (threat: 12+50+16+4+180 = 262 = 300 x (1 - 0.127)). Raw logs: `tests/sim/out/study/r2/*.stdout` (gitignored).

## Q1. Seed 7 (siege north, hare sw), night 23, round-1 values

Branches in place at the start of the night (both bought in the day phase of row 22 with 1055 gold, tower_sw is plain in these runs):

| run | spot | branch | lanes the spot covers | gold left |
|---|---|---|---|---|
| threat | tower_nw | Longbow | west + north | 555 |
| threat | tower_ne | Longbow | north + east | 55 |
| all_b | tower_nw, tower_ne | Volley, Volley | west + north, north + east | 55 |
| unbranched | none | | | 1055 |

Tower coverage on this map: tower_sw is the ONLY tower that covers sw (the hare lane). No branched tower of these runs covers sw.

The night's plan (identical for the three runs, pressure 12, hp_mult 2.65 / 3.44 in wave 2; observed spawns by kind):

| wave | lane | boars | hares | brutes | note |
|---|---|---|---|---|---|
| w0 | north | 6 | 1 | 0 | main |
| w0 | west | 6 | 1 | 0 | side |
| w0 | sw | 0 | 5 | 0 | extra group (5 fast) |
| w1 | north | 13 | 3 | 0 | main |
| w1 | sw | 5 | 8 | 0 | side |
| w2 | sw | 8 | 8 | 0 | main |
| w2 | north | 11 | 3 | 1 | side, the only brute of the night |

Fences: first fall time per run (s from night start; threat / all_b / unbranched attempt 1 / unbranched attempt 2):

| fence | threat | all_b | unbranched #1 | unbranched #2 |
|---|---|---|---|---|
| fence_n (north) | 58.0 (wave 1) | 95.8 | 55.7 | 89.5 |
| fence_sw | 92.6 | 91.7 | 92.5 | 100.1 |
| fence_w | stands | stands | stands | stands |
| fence_e | level 0, no east group tonight | | | |

Diner damage by lane and kind (HP; the diner has 300):

| run | sw boars | sw hares | north boars | north hares | north brute | total | result |
|---|---|---|---|---|---|---|---|
| threat | **180** (36 bites) | 4 | 50 (10 bites) | 28 | 0 | 262 | **0.127** |
| all_b | 40 (8 bites) | 4 | 0 | 0 | 24 | 68 | 0.773 |
| unbranched #1 | 175 (35 bites) | 12+4 | 90 | 20 | 0 | dead (301) | fail |
| unbranched #2 (retry, mercy 0.85) | 0 | 0 | 13 | 0 | 14 | 27 | 0.912 |

Enemies that reached the diner (target = diner), by kind, whole night: threat 11 boars (sw 4, north 7), 10 hares, 0 brutes; all_b 6 boars (sw 6), 7 hares, 1 brute;
unbranched #1 14 boars (sw 6, north 8), 8 hares, 0 brutes.

**The threat run lost 87% of the diner to the sw lane's wave-2 boars: 180 of 262 HP (69%).** The north boars cost 50 (19%), the hares 32 (12%).
The sw lane is the hare lane; it lost its HP to boars (its 8 wave-2 boars), not to hares.

Shooters (shots; kills attributed):

| shooter | threat | all_b | unbranched #1 |
|---|---|---|---|
| tower_nw | Longbow: 27 shots (20 boar, 5 hare, 2 brute), kills 9 north boars, 2 north hares, 3 west boars, 1 west hare | Volley: 207 shots, kills 15 north boars, 3 north hares, 2 west boars, 1 sw boar | plain: 96 shots, kills 13 north boars, 3 north hares, 3 west boars |
| tower_ne | Longbow: 27 shots, kills 20 north boars, 5 north hares | Volley: 180 shots, kills 12 north boars, 2 hares, 1 brute | plain: 87 shots, kills 9 north boars, 2 north hares |
| tower_sw (plain) | 105 shots, kills 11 sw hares, 13 sw boars, 1 brute | 93 shots, 10 sw hares, 8 sw boars | 101 shots, 11 sw hares, 10 sw boars |
| tower_w (plain) | 13 shots, 3 west boars | 13 shots, 4 | 15 shots, 2 |
| hero and guards | 107 hits, 1418 dmg, kills 10 sw hares, 1 north boar | 94 hits, 1474 dmg, kills 11 sw hares, 4 sw boars, 2 north hares, 2 north boars, 1 west hare | 89 hits, kills 7 north boars, 9 sw hares |

## Q2. Mechanism

The numbers that decide it (seed 7, night 23, threat), all from the `HEROMOVE` and `BOT` logs:

- (b) refuted by the map. No Longbow tower covers sw: tower_nw covers west + north, tower_ne north + east, and the only sw tower, tower_sw, is the same plain tower in
  all three runs (105, 93 and 101 shots, 13, 8 and 10 sw boar kills). The what-if (b) is a no-op on seed 7 (and on seed 1): see Q3, same results to the digit.
- (a) is real but small: the north boars of wave 2 cost 50 HP (10 bites; 7 of 11 reached) against 0 in the Volley run. The north boars of wave 1 (13) all died before the
  diner, with fence_n gone at t = 58.0. One brute spawned: it died before the diner (the Longbow's x2 was used on 2 shots only).
- (c) is the cause of the 180. The hero stood in zone_sw from t = 59 to 93 (diner 288, wave 2 piling up in the sw lane). fence_sw fell at t = 92.6. At the next one-second
  decision, t = 93.0, nothing was within 4.0 m and the lane counts were `{sw: 8, north: 10}`, so the rule sent the hero to zone_north. From t = 93 to 105 the diner went
  288 -> 251 (96) -> 133 (99) -> 73 (102) -> 43 (105): 245 HP in 12 s, with the hero away from the lane that was biting. He returned to sw at t = 100.
  In the all_b run the hero stayed in zone_sw from t = 48 to 99, because the north lane was down to 1 alive monster (the Volleys clear it); sw boars bit 8 times, not 36.
  The unbranched attempt 1 repeats the threat run: hero leaves sw at t = 92 with `{sw: 9, north: 11}`, diner dead at t = 105 (sw boars 175).
- Why north has 10 alive at t = 93: that is where the Longbows enter. A Longbow fires one shot per 2.2 s (27 shots in the whole night) and keeps the north lane's
  count high; the one-second rule counts monsters, not threat. So (a) causes (c): the north boars hurt little themselves (50 HP) but they hold the hero's attention one
  decision too long. This is a reading of logs plus the pin test below, not a game field.
- The pin test (below, seed 7 with the hero pinned to sw from t = 80 of night 23): 0.127 -> 0.440, sw boar damage 180 -> 75. Fence falls are identical to the unpinned run
  (fence_n t = 58.0, fence_sw t = 92.6), so the only change is the hero.

The remaining 75 HP of sw boars with the hero in place, against 40 with Volleys, says the Longbow towers also leave more north monsters and a slower sw clear than Volleys do; but
the pinned hero takes 105 of the 180 sw HP back (the north boars give 15 of it up: net 94 of the 194 HP that separate the threat run from all_b).

## Q3. What-ifs (in memory, threat policy, seeds 7, 1, 4)

Variants: **a** = Longbow interval 2.0 s (damage 120 and the brute multiplier 2.0 as committed); **b** = a tower that covers the hare lane takes Volley even if it also covers
the siege lane; **c** = purchase order "first ONE siege-lane tower (Longbow), then the hare-lane tower(s), then the other siege-lane towers"; **e** = b and c together.
(d is skipped as instructed.) Seed 7 days 22 to 26, seeds 1 and 4 days 22 to 24 (their first three tier-3 nights). Cells are the final night fraction; none of these nights needed a retry.

Seed 7 (siege north, hare sw): first tier-3 night is 23.

| variant | day 22 (Baron) | **day 23** | day 24 | day 25 | day 26 | mean days 23-26 | what was bought before night 23 |
|---|---|---|---|---|---|---|---|
| threat (round 1) | 0.207 | **0.127** | 0.673 | 1.000 | 1.000 | 0.700 | tower_nw Longbow, tower_ne Longbow |
| a (interval 2.0) | 0.207 | **0.807** | 0.887 | 1.000 | 1.000 | **0.924** | same |
| b | 0.207 | **0.127** | 0.673 | 1.000 | 1.000 | 0.700 | same (no tower covers sw and north) |
| c | 0.207 | **0.620** | 0.673 | 1.000 | 1.000 | 0.823 | tower_nw Longbow, tower_sw Volley |
| e (b + c) | 0.207 | **0.620** | 0.673 | 1.000 | 1.000 | 0.823 | same as c |
| (all_b, for reference) | 0.207 | 0.773 | 0.813 | 0.860 | 0.903 | 0.837 | |
| (unbranched, for reference) | 0.207 | 0.912 (1 retry) | 0.800 | 0.720 (1 retry) | 0.577 | 0.752 | |

Seeds 1 and 4, first three tier-3 nights (22, 23, 24):

| seed | variant | night 22 | night 23 | night 24 | mean | purchases of the day phases before nights 22 / 23 |
|---|---|---|---|---|---|---|
| 1 | threat (round 1) | 0.850 | 0.850 | 1.000 | 0.900 | tower_ne Longbow, fence_e Stone / tower_e Longbow |
| 1 | a | 0.820 | 0.983 | 1.000 | 0.934 | same |
| 1 | b | 0.850 | 0.850 | 1.000 | 0.900 | identical to threat (no tower covers east and west) |
| 1 | c | 0.850 | 0.933 | 1.000 | 0.928 | tower_ne Longbow, fence_e Stone / tower_nw Volley |
| 1 | e | 0.850 | 0.933 | 1.000 | 0.928 | same as c |
| 4 | threat (round 1) | 0.763 | 0.740 | 0.850 | 0.784 | tower_nw Longbow / tower_w Longbow |
| 4 | a | 0.880 | 0.850 | 0.883 | 0.871 | same |
| 4 | b | 0.853 | 0.733 | 0.933 | 0.840 | tower_nw Volley (covers west and north) / tower_w Longbow |
| 4 | c | 0.763 | 0.707 | 0.883 | 0.784 | tower_nw Longbow / tower_ne Volley |
| 4 | e | 0.853 | 0.807 | 0.887 | 0.849 | tower_nw Volley / tower_ne Volley |

Readings (from these runs only):

- **a (2.0 s) moves seed 7 day 23 from 0.127 to 0.807** and the mean of days 23-26 from 0.700 to 0.924; on seeds 1 and 4 no night drops below 0.82 (seed 1 night 22
  0.850 -> 0.820, seed 4 night 23 0.740 -> 0.850). Why on seed 7: the north lane clears faster, the north count falls below the sw count at t = 93, and the hero stays at
  sw until t = 101 (sw boars 45 HP, north 5). The same mechanism as Q2, seen from the other side. The bench side of 2.0 s is not measured here (round 1's bench report has it).
- **b changes nothing on seeds 1 and 7** (no tower covers both the siege and the hare lane there; same digits) and is the only variant that touches seed 4's tower_nw (west + north).
- **c** helps seed 7 (+0.49 on night 23, +0.12 on the mean) by moving the second purchase to tower_sw, a Volley on the hare lane; it costs the north lane its second Longbow
  (north boars 90 HP, 18 bites) and keeps day 24 at 0.673. On seed 1 it gains night 23 (0.850 -> 0.933); on seed 4 it loses night 23 by 0.03 (0.740 -> 0.707).
- **e** equals c on seeds 1 and 7 and, on seed 4, 0.849 against 0.784 for threat.
- No variant on any of the three seeds produces a retry, and no night of seeds 1 and 4 falls below 0.707.

## Q4. Seed 1 (siege east), day 22, all_b: the hero pin

The study's mechanism (`study_first_t3.md` Q2): fence_n fell at t = 87.9; the bot's one-second rule sent the hero to zone_east at t = 88.0 (east 10, north 9).
Test: the same run with the hero's lane choice pinned to north from t = 80 of the night of row 22 (the shipped rule's 1 s timer, in-range stay and go_to unchanged; only the lane
is replaced; rows before 22 are not pinned).

| | without the pin | with the pin |
|---|---|---|
| night 22 result | **0.197** | **0.767** |
| diner damage, north boars (wave 2) | 225 (45 bites) | 70 (14 bites) |
| diner damage, north hares | 16 | 0 |
| fence_n fell | t = 87.9 | t = 87.9 |
| fence_e fell | t = 110.7 | t = 109.7 |
| hero and guards, hits / nominal damage | 76 / 870 | 88 / 1076 |

The fence falls at the same time, so the pin changes only where the hero is. 171 of the 241 HP lost come back (71%). It confirms the hero as the main cause and refutes "the
Volley made the lane weaker". It does not restore the unbranched night's 0.867: with the pin 70 HP of north boars still bit (against 40 unbranched), so the rest is the tower and
fence difference, which this test does not separate.

The same pin applied to seed 7 night 23 (sw from t = 80, Q2): 0.127 -> 0.440, sw boar damage 180 -> 75, north boars 50 -> 65, hares 32 -> 28.

## What the game does not expose (not guessed)

- Kills and hits per shooter are the study's attribution, not a game field (see `study_first_t3.md`).
- Seed 7's pin (0.127 -> 0.440) recovers a net 94 of the 194 HP lost beyond all_b's 68 (262 -> 168); the game exposes no way to say which part of the rest is the Longbow's slow clear and which is the lane layout.
- The bench side of the 2.0 s interval (floor, hare lane) is not in this study; variant a was only run on the three real seeds.
