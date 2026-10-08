# E6: tier-3 retune and lane character — design

Date: 2026-10-08. Author decisions: D-281 to D-291 (`docs/DECISIONS.md`). Predecessor: E5 slice 2
(`docs/superpowers/specs/2026-10-07-e5-tier3-design.md`, checkpoint pack `docs/review/E5_T3.md`).

## 1. Why

The tier-3 checkpoint showed five problems (D-281):

1. One branch pair dominates (Volley + Stone 87.2 points against Longbow + Spike 55.8), and the two Longbow policies
   still need retries. Longbow and Spike fence were tuned for pressure 15, which the game no longer reaches.
2. Reading the telegraph only ties a fixed choice. Root cause (author): branches are permanent but lane threats
   change every night, so one night's telegraph cannot inform a permanent choice.
3. Fences cost 31% to 35% of a night's income at the cap (threshold 30%).
4. Twelve on-pad label overlaps and several near-stage ones remain.
5. The worst frame is 110 ms, always 0.1 to 0.2 s into the measured window; two early tier-3 nights on one seed
   were held at 1% and 4%; three sim fixtures are constructed, not recorded.

## 2. Goals and non-goals

Goals, judged on the final report (section 8):

| Target | Rule |
|---|---|
| Reading pays | threat-matched beats the best fixed pair by a mean of at least 5 points of diner HP, ahead on at least 6 of 8 seeds, and its mean lead is not negative on any siege lane |
| Non-punishing | zero retry nights at the tier-3 cap for every policy, unbranched included |
| Balance between pairs | the four fixed pairs are within 15 points |
| First nights | no first tier-3 night below 25% diner HP |
| Fence tax | at most 30% median at the cap; fences stay a recurring sink |
| Readability | zero label overlaps in the near stage and on the pad; everything checked at about 40% scale |
| Ramp | restore a modest pressure ramp (cap 13 or 14) if every target above still holds |
| Worst frame | diagnosed as artifact or real; fixed by warm-up if real; the boot warm-up's cost measured |

Non-goals: tiers 4 and 5; a second siege lane; the card for non-branch pads (a REVIEW_QUEUE idea only); a respec
feature; any change to tier-1 or tier-2 play (rows 1 to 7 and the pinned plans stay byte-identical).

If the 5-point lead and the zero-retry or 15-point rules cannot hold together, that is an escalation to the author
with the data. Nothing is relaxed silently (D-282.6, D-281.6).

## 3. Lane character (D-282, D-287)

### 3.1 The draw

- `core/lane_character.gd`, class `LaneCharacter`, pure static.
- `for_run(run_seed: int) -> Dictionary` returns `{"siege": String, "hare": String}`.
- Stream: `Rng.stream(run_seed, 0, &"lane_character")`. The siege lane is drawn from `LanePlanner.lanes_for_tier(3)`
  (four lanes); the hare lane from the other three. No existing stream is read or shifted.
- Exactly one siege lane and one hare lane at tier 3. "One or two siege lanes" is a lever for later tiers.
- Lane types: siege, hare, neutral (the other two).
- `GameState.lane_character()` returns it at tier 3 or above with the flag on, and `{}` otherwise.

### 3.2 The plan step

`LaneCharacter.apply(plan: Array, character: Dictionary, tb: TierBalance) -> Array` is pure and deterministic, with
no draws. It runs after `LanePlanner.plan` (and before `with_boss`) only at tier 3 or above with the flag on. Per
wave, in this order:

a. **Brutes.** The wave's brute count is unchanged (as tuned: `brute_cap_main`, `brute_ramp_days`). All of them
   walk the siege lane. If the wave has brutes and the siege lane is neither its main nor its side lane, the SIDE
   lane becomes the siege lane: the whole side group moves there.
b. **Hares.** The wave's hare count is unchanged. The hare lane takes `round(hare_lane_share x hares)`
   (`hare_lane_share` = 0.7, a Balance value). If the hare lane is the wave's main or side lane, hares move between
   the two groups; that group's hares are capped at its count, and what does not fit stays in the other group. If it is neither, its share comes as an EXTRA group on the hare lane, and the moved hares are
   taken from the main and side hare counts proportionally, by deterministic largest-remainder rounding, never
   negative; the main and side group counts shrink by what they gave.
c. **Guard.** At most three active lanes per wave, never four. Given (a) this cannot be exceeded; it is kept as an
   asserted guard. If it would be exceeded, that wave's hares stay split between main and side, and the report
   counts the event (`LANE_CAP_GUARD`, expected 0).
d. Extra groups use the side-group delay.

Invariants: per-wave totals of enemies, hares and brutes equal the plan before the step; every brute is on the siege
lane; a group's hares never exceed its count.

### 3.3 Plan format and consumers

- A wave gains an optional `extra: [{lane, count, fast}]`. `brute_main` / `brute_side` stay in the format; with the
  flag on the brutes of a wave are carried by whichever of its groups is on the siege lane.
- `LanePlanner.composition_by_lane` and `threat_by_lane`, `WaveSchedule`, `WaveDirector`, the telegraph count rows
  and the HUD arrows read the extra group, so tonight's counts stay truthful.
- `World.pool_sizes` covers the worst case with an extra group; the no-runtime-growth checks stay.

### 3.4 Saves

- Schema 7. The save stores the character. On load the character is derived from `run_seed`; if a stored one
  differs, the derived one is used and a warning is logged (debug overlay).
- A v6 tier-3 save loads with its character derived from `run_seed`, the same on every load.
- A stored night plan made under the old rules is replaced by the plan under the new rules when the flag is on. A
  night-start snapshot may therefore replay differently after the flip. This is accepted and documented.

### 3.5 Tests

- Deterministic per seed; siege and hare lanes differ; over seeds 1 to 200 each lane is the siege lane at least 30
  times.
- Stream identity: the first values of every existing named stream are unchanged; tier-1 and tier-2 plans equal the
  pinned plans (`tests/fixtures/plans_tier12.json`).
- Over the 200-seed scan and days at every brute-ramp stage: every brute on the siege lane; a wave whose drawn main
  and side are other lanes still delivers its brutes; at most 3 active lanes; totals unchanged; the largest-remainder
  split never negative and sums exactly.
- The night-level hare-lane share is reported per seed (target about 0.7; flagged below 0.6).
- Migration from a real v6 fixture; the mismatch warning; a flag-off save loaded with the flag on.

## 4. The specialists (D-283, D-288)

### 4.1 Values (all in `balance/`)

| Branch | Today | Change | Start, tuning range |
|---|---|---|---|
| Longbow | 120 damage per 3.0 s, range 9.98 | `kind_mult {brute: x}` | 2.0; 1.5 to 3.0 |
| Stone wall | 640 HP, brutes do half damage | none | |
| Spike fence | pass damage 10 on hares, thorns 6 | pass damage up | 16; 12 to 24 |
| Volley | 3 targets, 10 damage per 0.5 s | none unless data demands | |

- No Longbow bonus against the Baron unless data demands it (the Baron night is at tier 2, before any branch); a
  change is logged.
- Spike's scaling with the night's HP multiplier (D-272) stays.

### 4.2 The lane-type bench: "paying never makes it worse"

- `tests/support/branch_bench.gd`: a micro-sim of ONE lane (its fence, the tower covering it, no hero, no guards)
  against a fixed wave mix per lane type. Siege: boars with the full brute count. Hare: boars with 70% of the
  night's hares. Neutral: boars with the leftover hares.
- Measures, in order:

| Lane type | Primary | Then | Then |
|---|---|---|---|
| Siege | diner HP lost | fence HP left (more is better) | |
| Hare | diner HP lost | hares reaching the diner's attack zone (fewer) | time to clear |
| Neutral | diner HP lost | time to clear | |

- **Floor:** every branch is no worse than the unbranched level 3 on every lane type: no worse on the primary
  measure and, when tied there, no worse on that lane type's first tie-breaker.
- **Specialist:** on its own lane type the specialist beats the other branch by at least 15% on the first measure
  that separates them. Own lane types: Longbow and Stone wall on siege; Volley and Spike fence on hare.
- Runs at pressure 12 and at the final cap (13 or 14 too if the ramp returns). With the flag off it pins today's
  values. It lives in the unit suite and costs about 10 s at most.

### 4.3 Identity (D-272, restated)

On the bench measures: Longbow is best against the siege mix; Volley against the hare mix; Stone wall keeps the most
fence HP against brutes; Spike fence kills the most hares; unbranched is never the best at any named measure.

### 4.4 Threat-matched

| Building | Choice |
|---|---|
| Fence on the siege lane | Stone wall |
| Any other fence | Spike fence |
| Tower covering the siege lane (also when it covers the hare lane) | Longbow |
| Any other tower | Volley |

The bot reads the lane character, not tonight's plan, with the flag on. With the flag off the policy `threat` keeps
today's meaning.

## 5. Readability (D-284, D-289)

### 5.1 The lane-character marker

- At each tier-3 lane entrance, beside tonight's count row: a siege icon on the siege lane, a hare icon on the hare
  lane, nothing on neutral lanes. By day and night from the tier-3 dawn on. It does not hide under the HUD bar.
- The icons differ by SHAPE, not only colour; checked in grayscale at 40% scale.

### 5.2 The branch card

A HUD card shown when the hero enters an armed branch pad; hidden on exit or completion.

| Row | Content |
|---|---|
| 1 | Branch icon and name |
| 2 | Specialty, at most 3 words, with its character icon: Longbow "breaks brutes", Stone wall "holds brutes" (siege icon); Volley "hits 3 targets", Spike fence "hurts hares" (hare icon) |
| 3 | The guarded lane or lanes, each with its character icon (none if neutral) |
| 4 | Cost with the payment bar |
| 5 | Fences only: broken-fence icon, "lost if broken" |

- 640 x 170 px on the 720 x 1280 base, 24 px above the bottom safe inset. It never covers the hero at any focus
  inside the camera clamp: a projection test with the hero on each of the 9 spots' pads at 9:21, 9:16 and 16:9.
- It never intercepts input (mouse filter ignore). Test: a drag starting on the card moves the hero.
- Every string through `tr()`. Pseudo-locale test: strings about 40% longer and a Vietnamese sample with diacritics;
  rows shrink or wrap inside the card without overflow or overlap; the font renders the sample (D-079).
- Lane names for row 3 and the banners: west "west road", north "north path", east "east road", sw "south road".

### 5.3 The world side of the pads

- On a pad the world shows only the ring, the icon and the preview shape. In the near stage: ring, icon, cost.
- The pads of `tower_e`, `tower_ne`, `tower_nw` and `fence_sw` move so no near-stage block touches another or clips
  the screen. Pad clearance rules and the layout probe apply.
- The overlap test asserts ZERO overlaps in both stages against the hero, pips, "Close up", station labels, count
  rows, the tier sign, the HUD bar and the new markers.
- All of this sits behind the flag: with it off, pad positions, world labels and the pinned overlap counts stay as
  on today's main.

### 5.4 The reveal and banners

- One new reveal step after the south-west lane step: both markers pop with the build sound and a flavour banner
  shows for 2 s. Six steps at 0.35 s end at 2.35 s, inside the 3.0 s reveal. Tap-to-skip applies all.
- Eight flavour lines (four lanes x siege or hare), at most 6 words each, for example "Heavy tracks on the west
  road..." They go to REVIEW_QUEUE for the author's tone check.
- A save already at tier 3 when the flag flips shows the markers and the banner once, at its first dawn after
  loading.

### 5.5 Arrows

A third active lane gets its own small arrow at the side-arrow scale. The brute mark sits only on the siege lane's
arrow. Tests cover three simultaneous arrows without overlap at 720 x 1280 and at the narrowest supported aspect.

## 6. The flag (D-286)

- `Balance.data.tiers.retune_enabled`, false until the flip. The only flag.
- New values sit beside the old ones in `balance/`; one accessor picks the set. Lane character, the specialist
  values, the card, markers, labels, pad positions, the reveal step and any restored cap all read it through that
  accessor.
- Debug builds: `?retune=1` turns it on at runtime. A test proves no production file sets the flag; the release
  export check proves `ui/debug` is absent.
- **Off-state identity:** with the flag off tier 3 behaves exactly as on main at the start of the slice. A real-play
  tier-3 sweep (32 days, CI seed, threat) is recorded from that main as `tests/sim/baseline/tier3_off.csv`;
  `tools/baseline_t3_off.sh` must print `tier-3 off identical`. Its output, with the commit, is in EVERY phase PR
  body beside the two existing baseline outputs; a phase PR without it is not self-mergeable.
- In CI the existing tier-3 sims run with the flag off and keep their exact pins.
- **Saves across the flip:** a flag-off save loads correctly with the flag on; the replay of a night-start snapshot
  may differ. Both tested.

## 7. Worst frame (independent, first)

1. Artifact or real: the same night measured with the window starting 1 s and 3 s later. If the 110 ms frame moves
   with the window, it belongs to the measurement's start; if it stays at the same moment of the night, it is real.
2. If real: log first-use draws around that moment in a debug build, add them to the warm-up, re-measure.
3. Measure the boot warm-up's cost: load to first playable frame with and without the warm-up.

These diagnostic runs are extra to the single final reading at the end of the slice (D-260).

## 8. Proof

### 8.1 The retune report (`tests/sim/report_retune.gd`, a script, not CI)

- **Seeds:** scan upward from 1. The first seed per siege lane forms the tuning set (4). Continuing the scan, the
  next two per siege lane form hold-out set #1 (8). The sets are disjoint. The report prints the rule and the seeds.
- **Runs:** six policies per seed (Longbow + Stone, Longbow + Spike, Volley + Stone, Volley + Spike,
  threat-matched, unbranched), real 32-day tier-bot play, three processes at a time.
- **Verdict lines,** each also per seed and per siege lane:

| Line | Passes when |
|---|---|
| `THREAT_LEAD` | mean lead over the best fixed pair >= 5 points and ahead on >= 6 of 8 seeds |
| `THREAT_LEAD_BY_LANE` | the mean lead is not negative on any siege lane |
| `RETRY_NIGHTS` | zero for every policy |
| `FIRST_T3_NIGHT` | no first tier-3 night below 25% |
| `FENCE_TAX` | <= 30% median at the cap, shown with and without Longbow on the siege lane |
| `FIXED_SPREAD` | the four fixed pairs within 15 points |
| `HARE_SHARE` | night-level share per seed; flagged below 0.6 |
| `LANE_CAP_GUARD` | count of guard hits; expected 0 |

- **Hold-out integrity:** the final set runs only with `--final` and records its commit and set number. If it fails
  any target: escalate with the data, no further tuning against those seeds. More tuning means the next final run
  uses hold-out set #2 (the next two seeds per siege lane). Earlier results stay in the report history.

### 8.2 Tuning procedure

1. Make the bench pass, adjusting inside the ranges of 4.1.
2. Run the tuning set.
3. At most three tuning rounds (D-103); then stop and bring the data.
4. Fence tax, if still above 30%: measure what Longbow on the siege lane saves; then the branch re-buy cost; then
   fence HP.
5. Ramp attempt: cap 13, then 14, keeping every target.
6. The hold-out set, once.

Each round is one commit by the main session with its report output beside it.

### 8.3 CI

- Three new sims with the flag on, on fixtures recorded from real play: a tier-3 night where the siege lane is
  neither the drawn main nor side lane in at least one wave, held by the threat-matched build; the first tier-3
  night; the respawn sim.
- The constructed fixtures of sims 5 and 7 are replaced by recordings. Sim 4 (the Baron alone) keeps a constructed
  night with gear from the real Baron-night capture.
- `sim-tiers` (55 s on the runner, warning at 60 s) is split into `sim-tiers-a` and `sim-tiers-b`; the required
  checks are updated (D-274.4).

## 9. Delivery (D-291)

Slice E6, branches `e6/p<N>-<slug>`.

| Phase | Content | Merge |
|---|---|---|
| 0 Setup | spec, plan, D-281 to D-291, the off-state baseline and its tool | self-merge |
| A Worst frame | section 7 | self-merge, first, on its own |
| 1 Lane character | sections 3 and 6 (flag), the bot's threat-matched rule | self-merge |
| 2 Specialists | section 4 | self-merge |
| 3 Interface | section 5 | self-merge |
| 4 Proof | section 8, the final reading, the pack `docs/review/E6_RETUNE.md` | checkpoint: stop for the author |
| 5 Flip | the flag set to true; the Pages deploy check; a post-deploy smoke run on the live main build (simulator and emulated Pixel): the tier-3 dawn shows the lane-character step on a migrated v6 save | after approval |
| 6 Cleanup | remove the flag, the off-state paths, the superseded values, `tools/baseline_t3_off.sh` and its files; re-record the tier-3 baseline under a new tool name with its output in the PR; keep every flag-on test; update REVIEW_QUEUE, DECISIONS (D-286's flag retired) and section 11 | same slice, right after the flip |

Process: implementers run touched tests and the unit suite; the main session runs sims and the three baselines once
per wave; one fix round per task unless an Important finding stays open; minors batched per phase. Anything the
author approved in D-281 to D-291 that proves unbuildable or wrong is escalated at that moment with the evidence.

## 10. Constraint map

| Decision | Requirement | Test or report |
|---|---|---|
| D-282.1, D-287.2 | every brute on the siege lane; brutes still arrive when the siege lane was not drawn; <= 3 active lanes | `test_lane_character` (200-seed scan) |
| D-282.2, D-287.1 | hare lane takes 0.7; proportional largest-remainder split; totals unchanged | `test_lane_character`; `HARE_SHARE` |
| D-282.3 | no stream shifts; tier-1/2 identity | `test_rng` stream identity; pinned plans; `baseline_rows.sh 7` |
| D-282.4, D-287.4 | schema 7; v6 migration; mismatch warning | `test_save_v7` |
| D-283.2, D-288 | the floor and the 15% specialist margin per lane type | `test_branch_bench` |
| D-272, D-283.2 | identity on lane-type measures | `test_branch_identity` |
| D-288 | threat-matched table | `test_tier_bot` |
| D-284 | card content, input, projection, pseudo-locale | `test_branch_card` |
| D-284.5, D-289.1 | zero overlaps with the flag on; pinned counts with it off | `test_branch_pads` |
| D-289 | marker, icons by shape, reveal step, banners <= 6 words, one-time banner | `test_lane_marker`, `test_tier_reveal`; 40% and grayscale shots |
| D-287.3 | three arrows without overlap | `test_hud` |
| D-286 | one flag; no production setter; off-state identity; saves across the flip | `test_retune_flag`; `baseline_t3_off.sh`; `test_save_v7` |
| D-285, D-290 | seed scan, hold-out, verdict lines | `test_sweep_math`; `report_retune.gd` |
| D-281 | worst frame; first tier-3 nights; real-play fixtures | section 7 report; `FIRST_T3_NIGHT`; `make_save.gd` |

## 11. Results

Filled at the end of phase 4 and updated at the cleanup.
