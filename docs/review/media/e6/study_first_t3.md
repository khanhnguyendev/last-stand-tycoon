# E6 phase 4 study: the first tier-3 night by policy

A measurement study. No balance, core, actor or world file was changed. The scripts are `tests/sim/study_first_t3.gd` (launcher) and
`tests/sim/study_first_t3_runner.gd` (the runner, loaded at run time because of D-150). Commit under study: `dfb6648`, retune flag ON in memory.
Every run is a real tier-bot run from day 1 (the game has no resume from a day-21 state), with read-only logging added. The runs reproduce the
report's numbers exactly (for example seed 1 threat: night 22 = 0.197, mean over the 11 tier-3 nights = 0.8742, the same as `tuning_r0.log`), so the
logging does not move the simulation.

## How to read this

- "Row N" is the report's row: night N, then the day phase that follows it. A purchase made in the day phase of row N is in place for night N+1.
  Tables say "before night M" (M = N + 1) so there is no mix-up.
- The first tier-3 NIGHT is night 22 for seeds 1 and 4 (the Baron night 21 closes at tier 3) and night 23 for seed 7 (its Baron night is 22).
  The day phase before it is "the tier-3 dawn day".
- Correction to the brief: the first tier-3 night is NOT played with one branch. Seed 1, seed 4 and seed 7 all had two branches in place
  (the table in Q1 lists them). The `branches` column of the CSV counts the purchases of the row's own night and day phase, so "1" in row 22 means the
  purchase made AFTER night 22.
- Shot, hit and kill numbers per shooter are an attribution made by the study, not by the game: a shot is credited to the tower whose `Attacker.fired`
  launched it; a hit is credited to the nearest in-flight projectile aimed at that monster; a projectile with no tower label is "other (hero/guard)".
  Hits can exceed shots by a few percent (two projectiles to one target in one tick). Treat them as +-10%. "Damage" in the shooter tables is the nominal
  damage of the hit, overkill included.
- Diner damage by lane and kind is attributed by matching the damage amount, the attack timer and the monster that has the diner as its target in the
  same physics frame. Unattributed damage is printed as `key=unattributed` in the raw logs; there was none in the tables below (the sums match the
  diner HP lost exactly: for example seed 4 all_a night 23 = 192 + 85 = 277 = 300 x (1 - 0.077)).

## Q1. Purchases, and what decides the threat bot's first buy

Siege and hare lanes per seed: seed 1 east / west, seed 4 west / north, seed 7 north / sw. Tower coverage (MapLayout.TOWER_LANES): tower_nw west+north,
tower_ne north+east, tower_w west, tower_e east, tower_sw sw. Fences cover their own lane. Cost: tower branch 500, fence branch 300. "Gold after" is the
purse after the purchase (refunds included). Unbranched buys no branch. Rows: the tier-3 dawn day and the next two day phases.

| seed (siege/hare) | policy | before night | spot | pad | branch | lanes the spot covers | gold before | gold after |
|---|---|---|---|---|---|---|---|---|
| 1 (east/west) | all_a | 22 | tower_nw | a | longbow | west+north | 893 | 393 |
| 1 (east/west) | all_a | 22 | fence_w | a | stone | west | 393 | 93 |
| 1 (east/west) | all_a | 23 | tower_ne | a | longbow | north+east | 633 | 133 |
| 1 (east/west) | all_a | 24 | fence_e | a | stone | east | 1025 | 725 |
| 1 (east/west) | all_a | 24 | tower_w | a | longbow | west | 725 | 225 |
| 1 (east/west) | all_b | 22 | tower_nw | b | volley | west+north | 893 | 393 |
| 1 (east/west) | all_b | 22 | fence_w | b | spike | west | 393 | 93 |
| 1 (east/west) | all_b | 23 | tower_ne | b | volley | north+east | 633 | 133 |
| 1 (east/west) | all_b | 24 | fence_n | b | spike | north | 885 | 585 |
| 1 (east/west) | all_b | 24 | fence_e | b | spike | east | 585 | 285 |
| 1 (east/west) | threat | 22 | tower_nw | b | volley | west+north | 893 | 393 |
| 1 (east/west) | threat | 22 | fence_w | b | spike | west | 393 | 93 |
| 1 (east/west) | threat | 23 | tower_ne | a | longbow | north+east | 633 | 133 |
| 1 (east/west) | threat | 24 | fence_e | a | stone | east | 1025 | 725 |
| 1 (east/west) | threat | 24 | tower_w | b | volley | west | 725 | 225 |
| 1 (east/west) | unbranched | - | none | | | | | |
| 4 (west/north) | all_a | 22 | tower_nw | a | longbow | west+north | 701 | 201 |
| 4 (west/north) | all_a | 23 | tower_ne | a | longbow | north+east | 741 | 241 |
| 4 (west/north) | all_a | 24 | fence_w | a | stone | west | 1133 | 833 |
| 4 (west/north) | all_a | 24 | fence_n | a | stone | north | 833 | 533 |
| 4 (west/north) | all_a | 24 | fence_e | a | stone | east | 533 | 233 |
| 4 (west/north) | all_b | 22 | tower_nw | b | volley | west+north | 701 | 201 |
| 4 (west/north) | all_b | 23 | tower_ne | b | volley | north+east | 741 | 241 |
| 4 (west/north) | all_b | 24 | fence_w | b | spike | west | 993 | 693 |
| 4 (west/north) | all_b | 24 | fence_n | b | spike | north | 693 | 393 |
| 4 (west/north) | all_b | 24 | fence_e | b | spike | east | 393 | 93 |
| 4 (west/north) | threat | 22 | tower_nw | a | longbow | west+north | 701 | 201 |
| 4 (west/north) | threat | 23 | tower_ne | b | volley | north+east | 741 | 241 |
| 4 (west/north) | threat | 24 | fence_w | a | stone | west | 1133 | 833 |
| 4 (west/north) | threat | 24 | fence_n | b | spike | north | 833 | 533 |
| 4 (west/north) | threat | 24 | fence_e | b | spike | east | 533 | 233 |
| 4 (west/north) | unbranched | - | none | | | | | |
| 7 (north/sw) | all_a | 23 | tower_nw | a | longbow | west+north | 1055 | 555 |
| 7 (north/sw) | all_a | 23 | tower_ne | a | longbow | north+east | 555 | 55 |
| 7 (north/sw) | all_a | 24 | fence_w | a | stone | west | 619 | 319 |
| 7 (north/sw) | all_a | 24 | fence_n | a | stone | north | 319 | 19 |
| 7 (north/sw) | all_a | 25 | fence_n | a | stone | north | 943 | 643 |
| 7 (north/sw) | all_a | 25 | fence_e | a | stone | east | 643 | 343 |
| 7 (north/sw) | all_a | 25 | fence_sw | a | stone | sw | 343 | 43 |
| 7 (north/sw) | all_b | 23 | tower_nw | b | volley | west+north | 1055 | 555 |
| 7 (north/sw) | all_b | 23 | tower_ne | b | volley | north+east | 555 | 55 |
| 7 (north/sw) | all_b | 24 | fence_w | b | spike | west | 619 | 319 |
| 7 (north/sw) | all_b | 24 | fence_n | b | spike | north | 319 | 19 |
| 7 (north/sw) | all_b | 25 | fence_n | b | spike | north | 943 | 643 |
| 7 (north/sw) | all_b | 25 | fence_e | b | spike | east | 643 | 343 |
| 7 (north/sw) | all_b | 25 | fence_sw | b | spike | sw | 343 | 43 |
| 7 (north/sw) | threat | 23 | tower_nw | a | longbow | west+north | 1055 | 555 |
| 7 (north/sw) | threat | 23 | tower_ne | a | longbow | north+east | 555 | 55 |
| 7 (north/sw) | threat | 24 | fence_w | b | spike | west | 619 | 319 |
| 7 (north/sw) | threat | 24 | fence_n | a | stone | north | 319 | 19 |
| 7 (north/sw) | threat | 25 | fence_n | a | stone | north | 943 | 643 |
| 7 (north/sw) | threat | 25 | fence_e | b | spike | east | 643 | 343 |
| 7 (north/sw) | threat | 25 | fence_sw | b | spike | sw | 343 | 43 |
| 7 (north/sw) | unbranched | - | none | | | | | |

(The fence_n purchases of seed 7 before night 25 are re-buys: a fallen fence loses its level and its branch.)

**What decides the threat bot's first purchase.** `TierBot.next_purchase()` (tier_bot.gd:155) first returns whatever the planner wants for tonight
(levels), then yard spots, and only then `_next_branch_pad()` (tier_bot.gd:195). That function walks `MapLayout.spots_for_tier(3)` IN FIXED ORDER
(tower_nw, tower_ne, fence_w, fence_n, fence_e, tower_w, tower_e, tower_sw, fence_sw) and returns the pad of the FIRST spot that can branch and whose branch
price the gold in hand covers (line 205 to 215). The branch at that spot comes from `branch_choices` (line 76): a tower that covers the siege lane gets Longbow,
any other tower Volley, a siege-lane fence Stone wall, any other fence Spike. Nothing ranks spots by how much the siege lane needs them: the order is the
list order, and the only other gate is gold.

So the first buy is not "the tower covering the siege lane" unless that tower happens to be first in the list:

- Seed 1 (siege east): first spot tower_nw (west+north) is affordable (893 >= 500) and does not cover east, so it gets VOLLEY. Then fence_w (third in the
  list, 393 >= 300) gets Spike (west is the hare lane, not siege). That leaves 93 gold; the siege-covering tower_ne (second in the list, Longbow) waits for
  the next day phase. Threat therefore equals all_b on night 22, which is why it gets all_b's 0.197.
- Seed 4 (siege west) and seed 7 (siege north): tower_nw covers the siege lane, so the first buy is a Longbow on it. For these two seeds the first buy IS the
  siege tower.

## Q2. Seed 1, night 22: why 0.197 with a Volley and 0.867 with a Longbow or nothing

What the two runs had at the start of night 22: threat = tower_nw VOLLEY + fence_w Spike; unbranched = nothing; all_a = tower_nw Longbow + fence_w Stone.
The Volley tower is tower_nw: it covers west (the hare lane) and north (neutral). It does NOT cover the siege lane (east). The east lane's tower_ne and tower_e
are unbranched level 3 in both runs and killed the only brute of the night (east, 1 spawned, 0 reached the diner) in both. The Volley tower is not out of action
and keeps range 8.0 (the level-3 range) and interval 0.5 s; it shoots 3 targets x 10 damage instead of 1 target x 18.

Per wave, lane and kind (spawned / reached the diner / killed, diner damage with hits). Waves 0 and 1 and the lanes not shown are identical in the two
runs and leaked nothing except 2 sw hares in wave 0 (0 damage).

| wave | lane | kind | spawned | reached, Volley run | reached, unbranched | killed (both) | diner damage, Volley run | diner damage, unbranched |
|---|---|---|---|---|---|---|---|---|
| w0 | sw | boar | 8 | 0 | 0 | 8 | 0 | 0 |
| w0 | sw | hare | 2 | 2 | 2 | 2 | 0 | 0 |
| w0 | west | boar / hare | 4 / 5 | 0 | 0 | all | 0 | 0 |
| w1 | east | boar / hare | 10 / 2 | 0 | 0 | all | 0 | 0 |
| w1 | north | boar / hare | 8 / 1 | 0 | 0 | all | 0 | 0 |
| w1 | west | hare (extra group) | 8 | 0 | 0 | all | 0 | 0 |
| w2 | east | boar / brute / hare | 9 / 1 / 1 | 0 / 0 / 0 (unbranched: hare 1) | 0 / 0 / 1 | all | 0 | 0 |
| **w2** | **north** | **boar** | **10** | **7** | **4** | all 10 | **225 (45 hits)** | **40 (8 hits)** |
| w2 | north | hare | 2 | 1 | 2 | all 2 | 16 (4) | 0 |
| w2 | west | hare (extra group) | 8 | 0 | 0 | all | 0 | 0 |

The whole difference is one cluster: the 10 north boars of wave 2, 185 diner HP (0.867 against 0.197 is 201 HP, of which 185 is this cluster and 16 the
two hares). Everything else is identical.

Fences (HP at the start of each wave; "fell" = first tick at 0):

| | Volley run | unbranched |
|---|---|---|
| fence_n | 320 at w1, 60 at w2, fell t=87.9 (wave 2) | 320 at w1, fell t=65.9 (wave 1) |
| fence_e | 320 at w1, 280 at w2, fell t=110.7 | 320, 280 at w2, fell t=113.1 |
| fence_w | 310 (Spike) | 280 |
| fence_sw | 130 | 130 |

Shooters (shots / hits with nominal damage / kills):

| shooter | Volley run | unbranched |
|---|---|---|
| tower_nw | 224 shots (149 boar, 75 hare), 210 hits, 2228 dmg, kills: north boar 7, north hare 1, west hare 9, west boar 3, east boar 1 | 80 shots, 81 hits, 1466 dmg, kills: north boar 4, west hare 9, west boar 1 |
| tower_ne | 91 shots, 102 hits, 1726 dmg | 96 shots, 93 hits, 1572 dmg |
| tower_e | 61 shots, 70 hits, 1104 dmg | 62 shots, 65 hits, 1152 dmg |
| tower_w | 36 shots, 20 hits, 354 dmg | 40 shots, 32 hits, 570 dmg |
| tower_sw | 45 shots, 42 hits, 756 dmg | 45 shots, 44 hits, 792 dmg |
| hero and guards | 76 hits, 870 dmg (kills 13) | 115 hits, 1583 dmg (kills 22) |

**Mechanism (what the data shows).** The Volley did NOT make the lane weaker: tower_nw dealt 2228 nominal damage against 1466 for the plain tower
(+52%), it held fence_n 22 s longer (fell at t=87.9 against t=65.9), and every wave before wave 2 was clean. The 0.197 comes from where the hero was when
fence_n finally fell. The bot's night rule (naive_bot.gd `_night`): re-decide once a second; stay if any monster is within the hero's attack range (4.0 m
of its position); otherwise go to the lane with the most live monsters. The `HEROMOVE` log:

- Volley run, t=88.0: the hero stands in zone_north, nothing within 4.0 m (the north boars are still held at the standing fence), alive by lane north 9,
  east 10, west 5, so it walks to zone_east. fence_n falls at t=87.9, one tick before. For the next 11 s nine boars walk to the diner with no hero: diner
  300 -> 242 (t=93) -> 154 (t=96) -> 79 (t=99). The hero returns to the north at t=99.
- Unbranched run: fence_n had already fallen at t=65.9, so the north boars were walking in range of the hero; the hero stayed in zone_north until t=98
  and shot them (hero and guards: 115 hits, 1583 damage against 76 hits, 870 damage in the Volley run).

So: a tie-break in the bot's one-second rule (10 east against 9 north, decided in the same second the fence fell) sends the hero away. The Volley purchase
changed the timing of the fence collapse (it held longer), and the collapse met the hero's decision tick. It is a counterfactual-free reading: the study does not
rerun the Volley night with the hero pinned, so "the hero leaving is the cause" rests on the logged sequence and the matched unbranched run, not on a controlled
test. What can be said without that test is that the tower's own numbers are better in the Volley run, and the loss is 185 diner HP in one 11-second window.

## Q3. Seed 4, night 23: all_a 0.077, threat 0.640, all_b 0.807

All three nights are played with TWO branches in place, not three: tower_nw (bought before night 22) and tower_ne (before night 23). The "3" in the row-23 column
is the three FENCES bought after the night. Siege west, hare north. Plan (identical for all policies): wave 0 sw 10 + north 9 (5 hares), wave 1 sw 12, west 9
(1 brute), north extra 8 hares, wave 2 west 12 (1 brute), sw 10, north extra 8 hares.

| policy | tower_nw | tower_ne (north+east) | night 23 result |
|---|---|---|---|
| all_a | Longbow | Longbow | 0.077 |
| threat | Longbow | Volley | 0.640 |
| all_b | Volley | Volley | 0.807 |
| unbranched | plain | plain | 0.537 |

Diner damage by lane and kind over the night:

| policy | north hares (21 spawned): reached / damage | sw boars: damage | other | diner HP lost |
|---|---|---|---|---|
| all_a | 14 reached / 192 (4 + 64 + 124 by waves 0, 1, 2) | 85 | 0 | 277 |
| threat | 17 reached / 8 | 100 | 0 | 108 |
| all_b | 6 reached / 8 | 50 | 0 | 58 |
| unbranched | not tabulated / 24 | 115 | 0 | 139 |

The lane that killed all_a is the HARE lane (north): 192 of the 277 HP lost came from hares. Hares never stop at a fence (their priority is guard, diner), so they
reach the diner and bite 4 per second each until a tower kills them. tower_ne is the only branched tower that matters for north in these runs besides tower_nw:

- all_a, tower_ne Longbow: 20 shots in the whole night (120 damage every 2.4 s, 17 hares and 3 boars killed). One kill per 2.4 s against a pack of 8 hares that
  arrives together leaves 6 of them biting for seconds: 31 bites in wave 2.
- threat, tower_ne Volley: 103 shots (84 at hares), 12 north hares killed by the tower; 17 hares reach the diner but are dead within a hit or two: 2 bites in the night.

This is the bench's hare-lane result (Longbow 1387 against Volley 395) showing up in real play.

threat against all_b (0.640 against 0.807) is 50 diner HP, and all of it is sw boars (100 against 50: 20 against 10 bites, 10 against 5 per wave); the north hares cost 8 in both.
tower_nw does not cover sw (kills of sw boars by tower_nw: 1 in both runs), the fence_sw fell at t=61.2 in both runs, and the sw tower is the same plain tower. The data
exposed by the game cannot say why the sw lane bit twice as often. The HEROMOVE log shows the hero in threat changed goal between zone_west and zone_sw five times
in wave 1 (t=55, 58, 60, 63, 69) against three times in all_b (t=55, 58, 67), which fits the Q2 reading, but this is a pattern in a log, not a measurement of cause.

## Q4. Seed 7, night 23: the retry

Seed 7's first tier-3 night is 23 (the Baron night 22 ends at 0.207 and leaves fence_n and fence_e as rubble). Siege north, hare sw. Before night 23 each
branched policy has two towers branched with the dawn-day gold of 1055: tower_nw and tower_ne (Longbow for all_a and threat, which are identical here; Volley for all_b).
Unbranched keeps the 1055 gold and buys no branch.

| policy | attempt 1 | final attempt | fence_n at the start of wave 2 | diner at the start of wave 2 |
|---|---|---|---|---|
| all_a = threat | 0.000 (diner fell, wave 2) | 0.796 | 0 HP (fell t=54.1, wave 1) | 237 |
| unbranched | 0.000 (fell, wave 2) | 0.912 | 0 HP (fell t=55.7, wave 1) | 296 |
| all_b | 0.773, no retry | - | 160 HP | 296 |

Which wave and lane killed the diner in the failed attempt (all_a = threat): wave 1 north boars 13 spawned, 5 reached the diner (11 bites, 55 HP) because
fence_n fell in wave 1; in wave 2: sw boars 8 spawned, 5 reached, 27 bites (135 HP); north boars 11 spawned, 8 reached, 17 bites (85 HP); north hares 16 HP. 237 HP at the start
of wave 2 was not enough. Unbranched: same shape (sw boars 175, north boars 90).

Why all_b does not need a retry: both north-covering towers are Volleys. They fire 180 and 207 shots in the night; the two Longbows fire 23 each (one 120-damage shot
every 2.4 s). Against the 13 north boars of wave 1 (80 HP each at multiplier 2.65) a Longbow shot kills one boar and wastes 40 damage; a Volley fires 3 shots of 10.
Result in wave 1: Longbow runs 5 of 13 boars reach the diner, Volley run 0 of 13. The siege brute that the Longbow is made for is ONE monster in this night (wave 2,
north side group, `b1`); its multiplier 2.0 applies to one target.

fence_e: it is not the siege lane (north) and not in tonight's plan at all. It fell on the Baron night 22 together with fence_n (both show level 0 at the start of the
dawn day). The planner (planner_bot.gd, step 3) builds only spots whose lane has threat in tonight's plan, so fence_n, fence_w and fence_sw stand at night 23 and fence_e
stays at 0; even the unbranched run, which kept all 1055 gold, did not buy it. No monster walks east tonight (plan lanes: north, west, sw), so fence_e:0 has no effect on this
night. It matters only on a later night with an east group.

## Q5. Does the bench contradict real play?

Bench at pressure 12, full three waves, one lane, one tower, one fence (run in this study, `BENCH` lines): diner HP lost, then fence-stands seconds.

| lane type | unbranched | Longbow | Volley |
|---|---|---|---|
| siege | 1780 (fence stands 28 s) | 412 (62 s) | 706 (33 s) |
| hare | 1693 (55 s) | 1387 (59 s) | 395 (53 s) |
| neutral | 560 (53 s) | 202 (58 s) | 100 (77 s) |

No contradiction in direction. The bench says a Volley is better than nothing on every lane type, including neutral, and the real seed-1 tower_nw dealt 52% more
damage and held its fence longer, as the bench predicts. What the bench cannot show:

1. The Volley that "made the night worse" was on tower_nw, which covers a hare lane and a neutral lane, not the siege lane. The bench result for a Volley on the siege
   lane (706 against 1780) is not the case in Q2.
2. The bench diner is invulnerable and counts HP lost in the thousands (560 to 1780 unbranched). The real diner has 300 HP: a real lane leaks 0 to 40 HP unbranched
   (seed 1, north, 40 HP). The bench measures a single tower overwhelmed on an entire wave on one lane; a real night splits the wave over 3 to 4 lanes and every lane has
   two towers in reach (north: tower_nw and tower_ne).
3. The hero. The bench parks it 45 m away. In real play the hero and guards dealt 870 to 1583 nominal damage in the seed-1 night (13 to 22 of its 79 kills) and are
   positioned by a one-second rule that can leave a post exactly when a fence falls (Q2). In the seed-1 pair that swings the night by 185 HP.
4. Brutes: the bench puts one brute in each of three waves on the one lane. The real first tier-3 night has 1 or 2 brutes in the whole night, so the Longbow's x2 against
   brutes counts for little (Q4: one brute) while its single 120-damage shot per 2.4 s is a poor answer to 13 boars.
5. Shared fire: a Volley on a two-lane tower spreads its 3 shots over both lanes (seed 1: 75 hare shots west, 149 boar shots north); the bench's tower sees one lane.

The one thing the bench does not model and real play has, that moves a night by more than any branch effect, is bot timing. That is why a single seed can swing 0.197 to
0.867 on a purchase whose own numbers improve.

## Q6. What if threat bought Longbow on the siege-covering tower first?

In memory only (`--force=first`: the first branch bought is a Longbow on the first tower in list order that covers the siege lane; `--force=all`: every siege-covering tower first;
everything else is the threat rule). Full 32 days where marked.

| seed | variant | first buy | night 22 | night 23 | night 24 | mean over the 11 tier-3 nights | lead over all_b (report mean) |
|---|---|---|---|---|---|---|---|
| 1 | threat (as shipped) | tower_nw Volley | 0.197 | 0.933 | 1.000 | 0.8742 (32 d) | -0.0 (all_b 0.8745) |
| 1 | first | tower_ne Longbow | 0.883 | 0.950 | 1.000 | 0.9366 (32 d) | +6.2 |
| 1 | all | tower_ne Longbow, then tower_e Longbow + tower_nw Volley | 0.883 | 0.850 | 1.000 | 0.9261 (32 d) | +5.2 |
| 4 | threat / first | tower_nw Longbow (unchanged) | 0.633 | 0.640 | 0.917 | 0.9106 | -4.3 (all_b 0.9533) |
| 4 | all | tower_nw Longbow, then tower_w Longbow | 0.633 | 0.807 | 0.833 | 0.9205 (32 d) | -3.3 |
| 7 | threat / first / all | tower_nw Longbow, tower_ne Longbow (unchanged) | night 23: 0.796 with 1 retry | 0.830 | 1.000 | 0.9383 | +7.8 |

(Seed 7's two forced variants are identical to threat: both siege towers were bought first already. Seed 4's `first` is identical to threat for the same reason.
The seed-4 and seed-7 rows of night 22/23/24 come from 25-day runs.)

Effect on the failing targets, from these runs only:

- THREAT_LEAD (needs +5.0 mean): with seed 1 at +6.2 and the other three seeds unchanged, the tuning mean is (6.2 + 5.2 - 4.3 + 7.8) / 4 = +3.7, up from +2.2. Still a FAIL.
  The east lane turns from -0.0 to +6.2; west stays at -4.3 (-3.3 with `all`).
- FIRST_T3_NIGHT (needs >= 25.0%): threat's seed-1 night goes from 19.7% to 88.3%, but the target takes the minimum over all 24 runs, and all_b and volley_stone on seed 1
  stay at 19.7% (both put a Volley on tower_nw first by definition). The bot's purchase order for threat cannot fix this target.
- RETRY_NIGHTS (threat 1): unchanged. The one threat retry is seed 7 night 23 and its first buy already is a siege Longbow.

So the purchase order explains about 1.5 of the 2.8 points missing in THREAT_LEAD and one of the two negative lanes, and none of the first-night and retry failures.

## What the game does not expose (not guessed)

- Kills and hits per shooter are an attribution (see "How to read this"), not game data. The game has no kill-credit field.
- The cause of the hero's departure in Q2 is shown by a log sequence; there is no controlled rerun with the hero pinned.
- The sw-lane difference between threat and all_b in Q3 (50 HP) has no mechanism in the data.
