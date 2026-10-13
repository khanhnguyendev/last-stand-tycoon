# E6: tier-3 retune and lane character — checkpoint pack

Status: hold-out set #2 was run once (`--final`, commit `b820c89`, 2026-10-13). It passes five of seven targets
and fails the two lead targets. Stopped for the author (escalation 15, D-306). Nothing was tuned after the run.
Hold-out set #1 (`d3eb6c4`) is retired; its reading stays below as history. No unseen set is left.

Branch `e6/p4b-seed14` (the seed-14 round). On `main`: phases 0 to 4 and A (PRs #61 to #66).
Spec: `docs/superpowers/specs/2026-10-08-e6-tier3-retune-design.md`. Plan: `docs/superpowers/plans/2026-10-08-e6-tier3-retune.md`.
Decisions: D-281 to D-306. Media: `docs/review/media/e6/`. Everything ships behind `retune_enabled` (off).

## 1. What to decide

**Hold-out set #2 passes every target that failed on set #1. It fails the two lead targets, one of them newly, by
0.1 point. I stopped, as you ruled (D-304.5).**

| Target | Tuning set (5 seeds, `f8cea4b`) | Hold-out #2 (8 unseen seeds, `b820c89`) |
|---|---|---|
| Threat-matched lead >= 5, ahead on 6 of 8 | +1.9, fails | **+1.5, ahead on 5 of 8, fails** (accepted as unmet, D-302.2) |
| No lane negative | passes (lowest south-west +0.0) | **fails: south-west -0.1** (east +2.3, west +2.9, north +1.0) |
| Zero retry nights, branch policies | 0, passes | 0, passes (unbranched also 0) |
| First tier-3 night >= 25%, first attempt | 79.7%, passes | 61.0%, passes (every policy, unbranched included) |
| Fence tax <= 30% | 19.4%, passes | 9.7%, passes |
| Fixed pairs within 15 | 5.5, passes | 5.3, passes (seed 16 alone: 15.9) |
| Lane-cap guard | 0, passes | 0, passes |

**What failed on seed 14** (hold-out #1, north siege lane, day 21, the first tier-3 night): 12.7% diner HP left with
a Longbow on the siege lane, a lost night with Volley towers or no branch. The north fence was hit in all three
waves and fell in wave 2. In wave 3 the bot's hero left the south-west main lane for the breached north lane,
arrived when the towers had cleared it, and the south-west fence fell behind it: south-west boars dealt 220 of the
262 damage. Timeline and what-ifs: `media/e6/tuning/p4_seed14_diagnosis.md`.

**Cause class: (ii) balance.** Tier 3 started at its cap pressure on the night the player owns one branch. The
hero's walk is a contributing bot weakness (class (i)); three bot rules were tried in memory, each fixed one night
and broke or missed another, so the bot is unchanged.

**What changed (one round, flag on only):** tier 3 starts at pressure 10 and rises one per night to its cap 12
(D-305). Nothing else: no Longbow, Spike, cap or bot change.

**The two failures on set #2:**
- The lead, +1.5 against 5: the miss you accepted (D-302.2). Per seed: +1.6, +3.0 (east); -0.1, -0.1 (south-west);
  +1.9, +4.0 (west); +5.2, -3.3 (north).
- No lane negative: south-west reads -0.1. On both south-west seeds Longbow + Stone already keeps 99.2% and 99.9% of
  the diner over the tier-3 nights and the threat-matched build 99.0% and 99.8%: there is no room to lead, and the
  difference is one twentieth of the noise band (2 points). It is still a failed target as written. On north seed 19
  the threat-matched build is 3.3 points behind Longbow + Stone (93.2 against 96.5); the north lane as a whole is
  +1.0 and passes.

| # | Question | My recommendation |
|---|---|---|
| 1 | The south-west lane reads -0.1. (a) Accept it with the lead as one unmet target (reading the lane markers pays little; tier-4 input) and treat the checkpoint as passed. (b) Restate the rule as "no lane below -1.0" (half the noise band); the same data then passes, no run needed. (c) Do not accept: the flag stays off and lane reading goes to tier 4 | (a). No run can settle it: no unseen set is left |
| 2 | Flip the flag (Task 22)? | Yes, if 1 is (a) or (b): every must-hold target on survival passes on unseen seeds |
| 3 | The softer start makes the first tier-3 night easy for a branch build (61.0% is the lowest of 48 first nights; most are 95% or more) | Accept for this slice; review queue 44 |
| 4 | Seed 16 (north) is the hardest unseen seed: worst nights 29.7% to 50.3% for branch builds, 0.7% unbranched, no retry | Information; tier-4 input |

## 1b. The first reading (hold-out set #1, superseded; kept as history)

**The hold-out run fails three of seven targets. I recommend NOT flipping the flag yet.**

| Target | Tuning set (4 seeds) | Hold-out #1 (8 unseen seeds) |
|---|---|---|
| Threat-matched lead >= 5 | +1.7, fails | +2.6, fails (accepted as unmet, D-302) |
| No lane negative | passes | passes (south-west +0.3) |
| Zero retry nights, branch policies | 0, passes | **fails**: Volley + Spike and Volley + Stone each retry one night (north seed 14) |
| First tier-3 night >= 25%, first attempt | 13.0% unbranched only | **fails for every policy on seed 14**: the three policies with a Longbow on the siege lane 12.7%, the two Volley policies and unbranched retried; unbranched also retried on seed 10 |
| Fence tax <= 30% | 4.9%, passes | 12.2%, passes (north lane 30.6%, over the bar on its own) |
| Fixed pairs within 15 | 5.2, passes (11.8 on one seed) | 3.8 on the means, passes (south-west seeds 16.7 and 19.7) |
| Lane-cap guard | 0, passes | 0, passes |

The tuning set at the head did not show this: its one north seed (7) read 57.0% on the first night with a Longbow
on the siege lane and 73.7% with Volley towers. But the same reading had been seen before: in tuning round 1
(Longbow 2.2 s) seed 7 read 12.7% for the same three policies (D-297.2). It went away at 2.0 s and with the bot
changes. That fix did not carry to the unseen north seed 14, which reads 12.7% or a retry on its first tier-3 night
(day 21). The other unseen north seed (9) passes (83.0% Longbow, 55.3% Volley, 60.0% unbranched). For the threat and
Longbow policies both hold-out north seeds are the weakest of the eight (threat mean 92.1 and 86.2, against 95.8 or
more elsewhere). The cause is not diagnosed: I did not study seed 14, because the spec (8.1) and D-290.1 forbid
tuning against a hold-out seed.

| # | Question | My recommendation |
|---|---|---|
| 1 | Flip the flag? | No. Two must-hold targets fail on unseen seeds |
| 2 | What next? (a) Diagnose seed 14's first night, one tuning round, then hold-out #2 as the final reading: it is the last unseen set. This needs your waiver of D-290.1 for seed 14 and reverses D-302.2 (no third round); it is the last of the three rounds. (a2) The same inside D-290.1: a round on the tuning seeds only; at the head they no longer show the failure, so the round would be designed blind. (b) Flip as it is and accept. (c) Leave the flag off and carry everything to tier 4 | (a), with the waiver |
| 3 | The unbranched reference trips your flag (D-298.3): 4 retry nights on seed 14 (limit 3); no night needed more than one mercy retry | Review queue 43; no action beyond item 2 |
| 4 | The measuring bot's two changes (section 5) met unseen seeds for the first time here | Open. The lead did not fall (+1.7 to +2.6, inside the noise), but what the bot rules gained on the tuning set did not carry over: unbranched retry nights went 3 to 0 on the tuning set and are 8 on eight unseen seeds; the lowest branch-policy first night went 57.0% to 12.7% or lost; every policy's mean is lower (threat 97.6 to 96.0) |
| 5 | Gold after the ladder: last-day median 8.3k to 12.3k (unbranched 14.5k), above the tuning set's 6.8k to 11.1k, mostly because these seeds reach tier 3 earlier (12.5 tier-3 nights a run against 10.5); the daily median after the ladder barely moves (4.2k to 6.4k against 3.8k to 6.2k) | Tier-4 input (review queue 39) |

Already answered (D-302): Longbow 2.0 s ratified; the lead target accepted as unmet; the unbranched first night
reported in red without a change; phase A merged with its Simulator readings; the fence sink and the ramp accepted
as unmet for this slice. No third tuning round was run.

Noise: two tuning runs that differ only by pad positions moved per-lane leads by about 1 point and one first night
from 4% to 13%. Read differences under 2 points as noise.

## 2. What was built (flag on)

- **Lane character.** Each run draws a siege lane and a hare lane (`LaneCharacter.for_run(run_seed)`). Brutes go to
  the siege lane; the hare lane gets about 70% of the night's hares (measured 72.4%); an extra group can appear on a
  third lane, never more than three active lanes. Save schema 7.
- **Specialists.** Longbow fires every 2.0 s with the flag on (3.0 s off) and hits brutes for double; Spike fence pass
  damage 24. Volley and Stone wall are unchanged.
- **Interface.** Lane badges at the entrances, a third lane arrow, a branch card, the reveal step and three banners
  after the pick, pads with the hero drawn in front and a building's stars covered while its pad is in use.
- **Proof tools.** The lane-type bench (its own CI job), the retune report, flag-on fixtures and sims from real play.

## 3. The bench: "paying never makes it worse"

One lane, an invulnerable diner, diner HP lost at pressure 12 (lower is better):

| Lane type | Unbranched | Longbow | Volley | Stone wall | Spike fence |
|---|---|---|---|---|---|
| Siege | 1780 | 114 | 706 | 1478 | 1673 |
| Hare | 1693 | 828 | 395 | 1355 | 855 |
| Neutral | 560 | 0 | 100 | 315 | 335 |

Every floor, specialist (15%) and identity rule passes. The fence rows are the values of tuning round 1; the tower
rows are at the committed 2.0 s. Notes for you:
- On the siege lane a fence specialist is judged by how long the fence stands (Stone 68 s, Spike 30 s), D-294.6.
- The Spike floor row is a one-sided guard: Spike keeps the level-3 fence HP, so no Spike number can make it worse.
- The Longbow's brute multiplier no longer decides any bench rule at 2.0 s: its siege edge is its rate of fire.
- The Stone wall's bench edge is its HP alone.
- The bench ranks branches; it does not predict nights. Real play has two towers per lane, the hero and a 300 HP diner.

## 4. Tuning history (tuning set: seeds 1 east, 3 south-west, 4 west, 7 north; 24 real 32-day runs each)

| Step | What changed | Lead over best fixed | Retry nights (branch policies) | Lowest first tier-3 night | Fence tax | Spread |
|---|---|---|---|---|---|---|
| Round 0 | as built (Longbow 2.4 s) | +2.2 (west -4.3) | 4 | 19.7% | 19.4% | 10.4 |
| Round 1 | Longbow 2.2 s; threat buys for marked lanes first | +5.6 (west -1.6) | 0 | 12.7% | 9.7% | 4.9 |
| Trial | Longbow 2.0 s | +5.0 | 0 | 19.7% | 4.9% | 5.3 |
| Round 2 | 2.0 s; ONE purchase order for every policy; the hero holds a breached lane | +1.6 | 0 | 58.3% (4.0% unbranched) | 4.9% | 5.0 |
| Trial | round 2 with the pressure cap at 13 | +2.4 (east -0.8) | 0 | 58.3% (4.0% unbranched) | 0.0% | 9.3 |
| Round 2 on the merged branch | phase 3's pad moves included | +1.7 | 0 | 57.0% (13.0% unbranched) | 4.9% | 5.2 |

The "lowest first night" column for round 0, round 1 and the two trials was read from the report before a fault was
fixed: a retried first night was reported by its mercy attempt, and on the north seed the unbranched run's first
night was LOST on the first attempt in those rounds. Round 2 turned that loss into a survived night (4.0%, then 13.0%
with the pad moves); it is an improvement, not a regression. The last row is from the corrected report.

Outputs: `docs/review/media/e6/tuning/` (`p4_r2_tuning_head.txt` is the corrected report at head). Two of three
tuning rounds are used.

## 5. The measuring bot was changed (D-297)

The bots judge the targets, so both changes are shown plainly. Both were designed on nights of the tuning seeds
(seed 1 day 22, seed 7 day 23); the hold-out run was their first test on unseen seeds: their tuning-set gains did not carry over (pack section 6.1).
1. **Purchase order.** The bot bought branches in list order. Now, with a lane character, every branch policy buys
   siege-lane towers, hare-lane towers, the siege fence, the hare fence, then the rest. Given to the threat policy
   alone it produced the +5.0 and +5.6 leads of section 4; shared by all policies the lead is +1.6. The earlier
   leads were mostly buying order, not branch choice.
2. **The hero at night.** Once a second the hero went to the lane with the most enemies and left a lane whose fence
   had just fallen. East seed, day 22, Volley + Spike: 19.7% before; 76.7% with this rule alone; 88.3% with the
   shared purchase order as well. North seed, day 23, threat: 80.7% before, 58.3% after (worse on that night).
   The same round took the unbranched reference from 3 retry nights to 0.
Both rules read only what a player could know (no plan, no future waves, no HP), apply only at tier 3 with a lane
character, and leave the tier-1 and flag-off baselines identical. The hero rule reads fence state on lanes outside
the player's view (review queue 37).

## 6. Where the targets stand

### 6.0 Hold-out set #2 (the final reading; east 8, 11; south-west 21, 23; west 18, 25; north 16, 19)

Run once at `b820c89`: 48 real 32-day runs, flag on in memory, after the suites and the three baselines
(unit 1965, sim 14, sim-tiers-a 7, sim-tiers-b 8, bench 8; `rows 1-7 identical`, `baseline identical`,
`tier-3 off identical e149755`; `b820c89` adds docs only). Record `tests/sim/retune_final.json`; full output
`media/e6/tuning/p4_holdout2_final.txt`. The tuning set before it: `media/e6/tuning/p4_r3_tuning_seed14.txt`.

Mean diner HP kept over the tier-3 nights: Longbow + Stone 95.8, Longbow + Spike 92.8, Volley + Stone 92.6,
Volley + Spike 90.5; threat-matched 97.4 (the mean of its eight runs). Worst single night of a branch build: 29.7%
(Longbow + Spike, seed 16, day 32). Unbranched: no retry night on any seed, worst night 0.7% (seed 16).
Last-day unspent medians 7.2k to 11.5k (unbranched 13.3k).

Not like for like with set #1: the at-cap columns, hence the fence tax, now count from the third tier-3 night
(the first two are below the cap), and the seeds differ.

### 6.1 Hold-out set #1 (retired; east 2, 5; south-west 10, 12; west 6, 13; north 9, 14)

Run once at `d3eb6c4`: 48 real 32-day runs, flag on in memory. Record `tests/sim/retune_final.json`; full output
`docs/review/media/e6/tuning/p4_holdout1_final.txt`.

| Target (D-281, D-285, D-298) | Result | Verdict |
|---|---|---|
| Threat-matched lead >= 5 points, ahead on 6 of 8 | +2.6 over Longbow + Stone; ahead by 1.0 or more on 7 of 8 seeds (seed 10: -1.4); against each seed's own best pair +0.9, ahead on 3, behind on 3 (seeds 2, 10, 12: -1.5, -1.4, -0.3) | fails (accepted as unmet) |
| No lane with a negative lead | east +1.7, south-west +0.3, west +4.3, north +4.1 | passes |
| Zero retry nights (unbranched excluded) | Longbow + Stone 0, Longbow + Spike 0, threat 0; Volley + Spike 1, Volley + Stone 1 (both seed 14, the first tier-3 night) | fails |
| First tier-3 night >= 25%, every policy, first attempt | seed 14: Longbow + Stone, Longbow + Spike and threat (a Longbow on the siege lane) 12.7%; Volley + Spike, Volley + Stone and unbranched retried (0%). Seed 10: unbranched retried. Every other seed 54.7% or more | fails |
| Fence tax <= 30% median | 12.2%; 0.0% with a Longbow on the siege lane, 25.0% without; north seeds 27.8% and 30.6%; lower bounds | passes |
| Fixed pairs within 15 points | 3.8 on the means (93.4 / 89.7 / 91.7 / 89.6); 16.7 and 19.7 on the two south-west seeds | passes |
| Lane-cap guard | 0 hits | passes |

Mean diner HP at dawn: threat 96.0, Longbow + Stone 93.4, Longbow + Spike 91.7, Volley + Spike 89.7, Volley + Stone
89.6, unbranched 66.9. Threat by seed: 95.8, 98.5 (east); 97.6, 98.3 (south-west); 99.4, 99.9 (west); 92.1, 86.2
(north).

Worst single night: seed 14, day 21 (its first tier-3 night) for every branch policy: 12.7% with a Longbow on the
siege lane, a retry for the Volley policies. Unbranched: 0.0% (seeds 10 and 14, day 21).

Unbranched (reference, D-298.3): retry nights per seed 0, 0, 2, 0, 0, 0, 2, 4. Seed 14 has 4 (limit 3): flagged,
review queue 43. No night needed more than one mercy retry.

Where the Volley tower is the wrong tool it shows more than on the tuning set (11.8 there): on the two south-west
seeds the Volley pairs trail the Longbow pairs by 10 to 20 points (82.3 and 86.2 against 99.0 and 96.6 on seed 10;
84.4 and 79.0 against 96.3 and 98.7 on seed 12). The reverse also holds: on all four east and west seeds Volley +
Stone beats Longbow + Stone (by 2.7, 1.9, 2.3 and 4.1), so "Longbow everywhere but the hare lane" was a tuning-set
reading.

Unspent gold at close-up (D-298.4): before the ladder completes, median 167 to 176 a day. After it: median 4,207
to 6,365 (tuning set 3,784 to 6,183); last-day median 8,277 to 12,263 (unbranched 14,517; tuning set 6,784 to
11,120). The last-day rise is mostly more days after the ladder: these seeds reach tier 3 earlier (12.5 tier-3
nights a run against 10.5).

Hare share 0.724 on every seed.

### 6.2 Tuning set (seeds 1, 3, 4, 7; corrected report at the head before the hold-out)


| Target (D-281, D-285, D-298) | Result | Verdict |
|---|---|---|
| Threat-matched lead >= 5 points | +1.7 over Longbow + Stone; lanes east +0.5, south-west +0.2, west +1.9, north +4.1; ahead by 1.0 or more on 2 of 4 seeds, level on 2; against each seed's own best pair +1.0 (east -0.7) | fails |
| No lane with a negative lead | none (against the best pair by mean) | passes |
| Zero retry nights (unbranched excluded) | 0 for every policy, unbranched too | passes |
| First tier-3 night >= 25%, every policy, first attempt | 13.0% unbranched (north); every branch policy 57.0% or more | fails on the reference only |
| Fence tax <= 30% median | 4.9%; 0.0% with a Longbow on the siege lane, 25.0% without; each figure is a lower bound | passes |
| Fixed pairs within 15 points | 5.2 on the means (95.9 / 90.8 / 94.2 / 92.5); 11.8 on the south-west seed alone | passes |
| Lane-cap guard | 0 hits | passes |

Mean diner HP at dawn: threat 97.6, Longbow + Stone 95.9, Longbow + Spike 94.2, Volley + Stone 92.5, Volley + Spike
90.8, unbranched about 70. Worst single night: threat, Longbow + Stone and Longbow + Spike 57.0% (north seed, day
23); the two Volley pairs 68.7% (west seed, day 23); unbranched 6.0% (north seed, day 25).

Why the lead is small (on the tuning set): Longbow everywhere is the wrong tool on the hare lane only, and being wrong there costs about
2 points. A hare has 39.75 to 51.7 HP at pressure 12 and dies to one 120-damage Longbow shot; a second shot would
need a Longbow multiplier of about 0.3 against hares, which is a new rule, not tuning. With every branch policy
above 90%, the best fixed pair leaves at most 4 points of headroom. More pressure opened little: cap 13 gave +2.4
with east at -0.8.

Spec goals not met: "fences stay a recurring sink" (the tax is gone where a Longbow guards the siege lane) and the
ramp above cap 12.

**Watch item (D-298.4): unspent gold at close-up.** Before the ladder completes: median 142 to 189 a day. After it:
median 3,784 to 6,183; on day 32: 6,784 to 11,120 (unbranched 12,598). E5 T3 read 4.6k to 9.0k by day 30; the two
are not like for like (different day, bot and values). Review queue 39.

## 7. Interface

Shot pack: `docs/review/media/e6/interface/final/INDEX.md` (57 images, each with a 40% copy and a blunt "reads at 40%"
column). Review queue 30 to 36. Known and left by design: a badge can be cut by the screen edge or pass under the
HUD's gold number (hiding clipped badges hid them in 48.6% of other-zone views); the reveal's badges, the third arrow,
the stars and the one tether are small at 40%; one pad shows its cost while the hero stands at HOME.

**Video (86 s, iOS Simulator, debug build with `?retune=1`, bot play):** `media/e6/checkpoint/e6_retune.mp4`, contact
sheet `e6_retune_frames.png`, notes in `README.md` there. It shows a tier-3 dawn with the three banners, the lane
badges, the pads and the branch cards with gold falling as pads are paid. It does NOT show the tier-3 reveal (the
save is already at tier 3), and it is not unmodified play: the fixture's gold was raised to 1,500 for the recording,
the dawn is from the session's second night (the first attempt ended with the diner falling), and the later
segments are cut from different moments of the day.

## 8. Performance (phase A, PR #64, merged; iOS Simulator: a proxy, the phone check stays on the final review)

| Reading | fps | Wanted | Worst frame | Draw calls |
|---|---|---|---|---|
| Night entered by play, hero at HOME | 54.9 | 58 | 26 ms | 54 |
| Resumed night | 59.9 | reference | 25 ms | 40 |
| Day at HOME, tier 3, pads shown | 43.2 | 55 | 28 ms | 107 |

- The 117 ms first-fade frame is gone (dithered fade): 21 to 22 ms.
- The earlier "regression" was camera framing: the E5 T3 build also draws 78 calls at HOME.
- Every level pip is one draw (78 to 56 calls at HOME by night); that bought about 1 fps.
- By day the 29 world labels are the one large item (+6.1 fps without them, still 48.6). The night is not
  attributed to one part.
- The attribution is one run per switch with about 1.5 fps of noise.
- Boot warm-up costs 0.76 s to first playable.

## 9. Tests and identity

- CI jobs: `unit`, `sim`, `sim-tiers-a`, `sim-tiers-b`, `bench`, Pages `deploy`.
- With the flag off tier 3 is identical to E5: `tier-3 off identical` at every phase head; tier 1: `rows 1-7
  identical`, `baseline identical`.
- Flag-on sims run on fixtures recorded from real play (seed 3). The flag-on respawn sim is an instrumented scene
  (3000 HP diner): it proves protection against an immediate second knock-out, not the full window at real HP.

## 10. Not done

- No diagnosis of seed 14's first tier-3 night (D-290.1 forbids it without your waiver; item 2).
- The hold-out output is under `media/e6/tuning/`, not `media/e6/balance/final/` as the plan named it.
- No third tuning round, no ramp (D-302).
- No like-for-like E5 T3 comparison for unspent gold (it needs an E5 T3 run to day 32).
- The flip (Task 22) and the cleanup (Task 23) wait for your approval.
