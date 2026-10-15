# E8: tier 4, the night side (sharper specialists, then tier 4)

Status: approved design (brainstorm 2026-10-15, D-313), revised after the spec review (D-314). The author asked for
the rest to run without questions (D-314.1).

Inputs: `docs/IDEA.md`, `docs/superpowers/specs/2026-10-06-e5-tier-ladder-design.md` section 10 (roadmap),
`docs/superpowers/specs/2026-10-08-e6-tier3-retune-design.md` (lane character, bench, report), review queue E6-1 and
E6-2, D-307.7 (fresh seed sets), D-312 (the measuring bot).

## 1. Why

E6 shipped lane character, but its payoff failed on every unseen set: the threat-matched build leads Longbow + Stone
by +1.5 to +2.7 points (target 5), and with the walk-time bot this is not a bot artefact (D-312.4). The fixed builds
sit within 4 to 5 points of each other, so every branch is fine everywhere and reading the lanes barely matters.
The first tier-3 night is easy (branch builds keep a median 97%, D-312.5). Tier 4 is the next rung of the ladder,
where the roadmap puts bigger waves and two side lanes at once.

Tier 4 has three subsystems, each with its own spec: E8 the night side (this one), E9 the seller (E2, D-233) and
E10 passive equipment (E3). E8 comes first (D-313.1).

## 2. Goals and non-goals

Goals:
1. Reading the lane pays: on unseen seeds the threat-matched build leads the best fixed pair by 5 points or more.
2. A tier's first nights are tight but fair: branch builds keep a median 50% to 80% of the diner on the first night.
3. Tier 4 exists: a tier-3 boss night with a siege boss, the back lot with two towers, nights with two side lanes at
   once and bigger waves, and a full build that holds tier 4's cap with 0 retries.

Non-goals: no new regular monster, only one new boss (D-313.3); no new lane (tier 5); no new fence; the seller and
equipment (E9, E10); no tier-4 boss (tier 4 is this build's top tier); no change to tiers 1 and 2 (identity); no
flag (D-313.6).

## 3. Phase 1: sharper specialists (tier 3; ships on its own)

### 3.1 Bench rules (D-313.2, replacing E6's FLOOR rule)

The E6 rule "paying never makes it worse" (FLOOR: every branch at least as good as unbranched on every lane) is
replaced. A measure where lower is better is written L (diner HP lost; hares reaching the zone). A measure where
higher is better is written H (seconds the fence stands).

| Rule | Branches | Lane type | Measure | Bound |
|---|---|---|---|---|
| ON | Longbow | siege | L diner lost | L <= (1 - m_on) x min(unbranched, Volley) |
| ON | Volley | hare | L diner lost | L <= (1 - m_on) x min(unbranched, Longbow) |
| ON | Stone wall | siege | H fence stands | H >= (1 + m_on) x max(unbranched, Spike) |
| ON | Spike fence | hare | L hares in zone | L <= (1 - m_on) x min(unbranched, Stone wall) |
| OFF | Longbow | hare | L diner lost | L >= (1 + m_off) x unbranched + a_floor |
| OFF | Volley | siege | L diner lost | L >= (1 + m_off) x unbranched + a_floor |
| OFF | Spike fence | siege | H fence stands | H <= (1 - m_off) x unbranched |
| NEUTRAL | all four | neutral | L diner lost | L <= (1 + m_neu) x unbranched + a_floor |

- Ties and infinities (D-314.14): ON and OFF keep E6's strictness. A tie on the primary measure fails ON unless E6's
  tie-breakers (`BranchBench.beats_by_margin`: fence HP left, hares in zone, clear time) separate the runs in the
  branch's favour. OFF fails when both runs give INF (`fence_stands_s` never falling) or both give 0. E6's
  SPECIALISTS rows stay, as written, beside ON.
- Margins are fixed for E8: `m_on` 0.15, `m_off` 0.10, `m_neu` 0.15, `a_floor` 20 HP (the absolute term covers a
  reference of 0). They are balance values only so the bench reads them. Changing one is an escalation (D-314.8).
- The Stone wall has no OFF rule (D-314.4): hares walk past every fence, so its off-lane cost is the gold not spent
  on Spike. NEUTRAL is one-sided: a branch may be far better than unbranched on the neutral lane, as today (Longbow
  0, Volley 100, unbranched 560 HP lost at pressure 12, D-297.3).
- Pressures: from `tier_base[3]` to `tier_cap[3]`, derived from the balance, never literals.
- CI runs the rules at the tier's base and cap (two pressures, about 80 s with today's per-pressure cost); the
  middle pressures run in the bench report (`tests/bench_report/`). The bench prints every rule's numbers.
- Tests replaced, not dropped (D-314.9): the FLOOR loops of `tests/bench/test_branch_bench_full.gd` and of the unit
  subset `tests/unit/test_branch_bench.gd` become the ON, OFF and NEUTRAL rules. The IDENTITY rule "unbranched is
  never best" is restated as "never best on the siege and hare lanes" (the neutral lane is NEUTRAL's job).
  `test_spike_and_unbranched_take_full_brute_damage` (`tests/unit/test_branch_state.gd`) and the Spike line of
  `test_branch_spec_values` take the new Spike values. Every FAILS_WHEN mutation table is restated so each rule
  still has a mutation that fails it. A table of every changed test goes in the phase-1 PR.

### 3.2 The weaknesses (numbers on existing systems; no new mechanic)

| Branch | Strength (today) | Weakness | Start | Pre-authorized range |
|---|---|---|---|---|
| Longbow | 120 per 2.0 s, x2 against brutes | `kind_mults[hare]`: the heavy arrow fails against hares | 0.3 | 0.15 to 0.42 |
| Volley | 3 targets x 10 per 0.5 s | `kind_mults[brute]`: light arrows barely scratch brutes | 0.3 | 0.1 to 0.6 |
| Spike fence | thorns 6, pass damage 24 to hares | `damage_taken_mult_by_kind[brute]`: brutes break it fast | 4.0 (D-314.18) | 1.5 to 4.0 (widened, D-314.18) |
| Stone wall | 640 HP, brutes deal x0.5 | none (3.1) | - | - |

- The Longbow weakness works in shots to kill. Tier-3 hare HP is 35.25 to 51.675 at pressures 10 to 12. Below 0.43,
  a pressure-12 last-wave hare (51.675) needs two arrows; below 0.29, every tier-3 hare does. 0.3 makes most hares
  take two arrows.
- Kind classes (D-314.10): the multipliers are looked up by kind class. `wrecker` is class `brute` and `baron` is
  class `hare`, so the new boss and the tier-2 boss meet the same strengths and weaknesses as their kin. Every reader
  uses the class: the attack path, Spike's `pass_kinds`, and the tier bot's clear-time estimate
  (`actors/bots/tier_bot.gd`).
- Pre-authorized tuning: inside the ranges, and the strengths within +-25% of today's values (as D-292 did for E6).
  Anything outside, or a new mechanic, is an escalation in the final report.

### 3.3 First nights (D-313.4)

- Order: the weaknesses are tuned first; then `tier_base[3]` moves from 10 to 11 if the first-night band needs it
  (range 10 to 11). It still ramps one per night to the cap 12.
- New report target `FIRST_NIGHT_BAND`: over the branch policies (all_a, all_b, mixed, volley_stone, threat), the
  median of each run's first tier-3 night is between 0.50 and 0.80. A first night lost and retried counts 0, as in
  `FIRST_T3_NIGHT`. The floor stays: `FIRST_T3_NIGHT` >= 25% for every policy.

### 3.4 Interface (D-313.7)

The branch card gets a sixth row, on a fourth line between the middle line and the guarded-lanes line, for the
weakness, at most 3 words, through `tr()`:
- Longbow: "weak to hares";
- Volley: "weak to brutes";
- Spike fence: "brutes smash it";
- Stone wall: "useless on hares".

The specialty row and the fence's "lost if broken" note stay where they are. The card grows by one row. Its obstacle
and clipping tests are updated to the new height. A shot pack shows all four cards (D-314.3).

### 3.5 Proof of phase 1

- Bench (CI): 3.1 at the tier's base and cap.
- Retune report:
  - the tuning set (seeds 1, 3, 4, 7, 14) for tuning;
  - then measurement set #5 (scan positions 10 and 11 per siege lane), once, `--final`, walk bot, 32 days.
- Targets:
  - THREAT_LEAD >= 5, ahead on 6 of 8;
  - THREAT_LEAD_BY_LANE none negative;
  - RETRY_NIGHTS 0 for branch policies;
  - FIRST_T3_NIGHT >= 25%;
  - FIRST_NIGHT_BAND;
  - FENCE_TAX <= 30%;
  - LANE_CAP_GUARD 0.
- FIXED_SPREAD turns around: the builds should now differ. It is reported as "spread >= 5", not a must-hold.
- Report changes: sets #5 and #6 in the scan check (`SCAN_PER_LANE` 13), `final_gate` accepts sets 5 and 6 and the
  days of their phase (32, 45), the FIRST_NIGHT_BAND line.
- Tier-3 sims keep passing; tick budgets are updated deliberately with the reason.
- Identity: tiers 1 and 2 identical; the tier-3 baseline re-recorded once, with the reason.
- If a target fails on set #5, the phase-1 PR is not merged. The final report gives per-seed data and 2 to 3
  options. No set is reused.

## 4. Phase 2: tier 4

### 4.1 Reaching tier 4

- The full tier-4 column of `TierBalance` (index 4; every array gains it):
  - `tier_costs` gains a fourth entry, index 3: the price of tier 4. Start 3500, range 3000 to 5000; it becomes
    `[0, 500, 1500, 3500]`.
  - `tier_base[4]` 12, `tier_cap[4]` 15 (range 14 to 16).
  - `fast_share_start[4]` 0.35, `fast_share[4]` 0.35, `fast_ramp_days[4]` 1.
  - `brute_cap_main[4]` 1, `brute_cap_side[4]` 0 (start equal to tier 3; tuning may raise them).
  - `brute_ramp_days[4]` 1, so tier 4's first night is not below tier 3's cap night.
  - `boss_kind` becomes `[&"", &"boss", &"baron", &"wrecker", &""]`. Tier 4 is the top, so it has no boss.
- The tier-4 sign stands on the back lot (`TIER_SIGNS[4]`: the sign of tier N sells tier N, D-240). Paying it starts the tier-3
  boss night.
- The boss rides wave 3 as every boss does (D-238). On a run with a lane character the Wrecker walks the siege lane:
  `LanePlanner.with_boss(plan, character)` takes the character and, when wave 3's siege lane is its side (or side2)
  group, swaps that group and the main group whole (lane, count, fast, brute); there is no draw. A unit test pins
  `brute_lane(wave 3) == siege` on the boss night. Its banner reads `tr("The Wrecker comes")`
  (`world/phase_controller.gd` today shows the Boar King's line for every boss but the Baron).
- The win: the next dawn plays the tier-4 reveal (land and yards, the two towers; no diner storey, no lane-character
  step), and the sign is removed (no tier above). A loss is the existing retry with the payment kept, mercy as always.

### 4.2 The siege boss ("the Wrecker")

- A `MonsterStats` resource with the brute's rules (fence-on-lane priority, reach) at boss scale:
  - HP 1440 (6 times the brute's 240; `hp_mult` scales it per night);
  - `fence_damage_mult` 12 (3 times the brute's 4);
  - diner damage per second like the Boar King's.
  - Every number lives in `balance/`.
- Kind class `brute` (3.2).
- Look: the brute model scaled and recoloured (as the Boar King is the boar's), the world HP bar, the boss moon. No
  new art pack. The look goes in the checkpoint shot pack.
- Targets:
  - Sim 2's rule: the boss alone needs at least `boss_min_hold_s` (15 s) to fell the diner from its first hit.
  - `BOSS_NIGHT`: every branch policy wins the tier-3 boss night within `boss_night_max_retries` (the existing sim
    allowance).
  - Boss nights are left out of RETRY_NIGHTS, as today.

### 4.3 The back lot

- Two tower spots (`TIER_SPOTS[4]`), single-lane towers like the tier-2 yard towers, branching at level 3.
- Placement rule (D-314.5): after tier 4, every lane is covered by at least two towers. The south-west lane (one
  tower today) gets one; the second goes to a lane where land is found.
- New entries, following D-271 (the shared tables are tier-1 and 2 data and never change): `TIER_SPOTS[4]`,
  `TOWER_SPOTS_T4`, `TOWER_LANES_T4`, `YARDS_T4` with `YARD_TIER_T4`, `BRANCH_PADS` (two pads per tower),
  `ALL_SPOT_IDS`, `TIER_SIGNS[4]`. The accessors (`tower_spot`, `tower_lanes`, `yard_rect`, `yard_tier`, `all_yards`,
  `yards_for_tier`) read the new tables. Pinned layout tests that change (`tests/unit/test_tier3_layout.gd`: the sign
  keys and the spot lists) are extended for tier 4, not loosened; the plan lists each one.
- Graph (D-314.12): the bot's graph gains the tier-4 sign node only when the bot may buy tier 4, and the new spots
  and pads only at tier 4, so a bot capped at tier 3 walks the same graph as today.
- Coordinates are pinned by tests, not here (D-240):
  - clear of lanes by `lateral_spread` + 1 m, and of pads, zones, slots, posts, the queue and the traveler path;
  - on screen at 9:16;
  - the sign stands on the land it sells.
- Fallback if the south-west lane has no free land (it is the old road at z = 11, near the queue): its tower may
  stand where it covers the lane from farther away, within its range. If none passes the clearance tests, both
  towers go where land exists, and it is logged in the final report.
- No new fence.

### 4.4 Nights at tier 4

- Wave fields: tier-4 waves add `side2`, `side2_count`, `fast_side2` and `brute_side2`.
  - Below tier 4 these keys are absent, so tier 1 to 3 plans are unchanged.
  - `SaveCodec.validate` requires all four on every tier-4 wave and accepts them only at tier 4 and above: `side2` a
    lane of the tier, different from main and side; whole numbers; `fast_side2 <= side2_count`.
  - Readers: `threat_by_lane`, `composition_by_lane`, the wave director's spawning and side delays, `WaveSchedule`,
    the telegraph, the edge arrows, `from_dict` and `validate`.
- The draw (D-314.11): at tier 4 the planner draws, per wave, the resting lane among the neutral lanes (those that
  are neither siege nor hare). It uses its own stream `Rng.stream(run_seed, day, &"lane_plan_t4")`, so the existing
  stream and tiers 1 to 3 are untouched. Main, side and side2 are the other three lanes. The main lane comes from
  today's draw when it is not the resting lane, otherwise it is redrawn from the three.
  - Lane order: of the two lanes left after main, side and side2 follow `LANES_TIER3` order. The redraw of main uses
    the `lane_plan_t4` stream too; today's stream is consumed exactly as at tier 3.
  - Splits: the side count, `fast_side` and `brute_side` are split between side and side2, the odd unit to side.
  - Lane character: step a moves brutes to the siege lane whichever of the three groups it is. Step b gains a
    three-group rule: the hare lane's group takes min(T, its count) hares as today, the rest come from the other two
    groups in main, side, side2 order, and never as an extra group at tier 4. `_lane_set` and `active_lanes` count
    `side2`, so the 3-lane guard and LANE_CAP_GUARD count right.
  - Effect: every tier-4 wave contains the siege and the hare lane and three lanes in all.
- Pressure: `tier_base[4]` 12 up to `tier_cap[4]` 15, one per night (the first tier-4 night is at 12). The waves grow
  through the existing formulas.
- Lane character is unchanged: one siege lane and one hare lane per run.

### 4.5 Under the hood

- Save schema 8 exists for the tier-4 wave fields. v7 to v8 adds no building. The two spots arrive at the tier-4
  dawn, as tier 3's did (`GameState.complete_tier_up`). There is a migration test from a committed v7 save.
- `TierBot` buys tier 4 after the tier-3 ladder is complete; once tier 4 is open it builds and branches the two new
  towers. Every branch policy covers them. The walk rule (D-312) is unchanged.
- Bench: `BranchBench.mix` takes the tier. At tier 4 a lane's mix is that lane's group from the planner's split
  (4.4): the siege lane's group with its brutes, the hare lane's group with its hares after step b, a neutral lane's
  group of boars; the bench builds these from `WaveMath.split` and the same split and step-b rules, in one helper
  shared with the planner's tests. CI runs the
  tier-4 cap only (about 40 s more); the tier-4 base runs in the bench report.
- Report and sweep: tier-4 nights are counted apart from tier-3 nights (section 4.6); `--days=45`; set #6.
- Tier-3 identity through phase 2 (D-314.12):
  - Once tier 4 has a price, the bot pays into it, which would change tier-3 gold flow.
  - The tier-3 sims and `tools/baseline_t3.sh` therefore cap the bot at tier 3 (`TierBot.max_tier = 3`; the sweep's
    `--bot-max-tier=3` sets it), so they stay what phase 1 recorded.
  - `tools/baseline_t4.sh` pins the tier-4 game.
- Tier-4 sims start from fixtures (`make_save --fixture=tier4`, captured from bot play) and go in `sim-tiers-b`,
  within its 150 s and tick budgets; a split into a new job would need the author's permission for the required
  checks (D-301 pattern). Estimate: three cap nights and one boss night, about 25k ticks.

### 4.6 Proof of phase 2

- Tier-4 sims (CI):
  - the boss night (sim 2's rule and a win);
  - the first tier-4 night (the band);
  - a full tier-4 branch build at the cap with 0 retries on three seeds.
- Bench at the tier-4 cap (CI) and base (report).
- Retune report: the tuning set for tuning, then measurement set #6 (scan positions 12 and 13), once, `--final`,
  45 days.
- Targets on tier-4 nights:
  - THREAT_LEAD >= 5, ahead on 6 of 8, and no lane negative;
  - RETRY_NIGHTS 0 for branch policies;
  - FIRST_T4_NIGHT >= 25%;
  - the first-night band (FIRST_NIGHT_BAND on the first tier-4 night);
  - FENCE_TAX <= 30%;
  - LANE_CAP_GUARD 0;
  - BOSS_NIGHT.
- Tier-3 check: set #5's seeds re-run on the phase-2 build with the bot capped at tier 3, 32 days, must give output
  identical to phase 1's set-#5 reading (D-314.12). It is a plain report run, not a new `--final` (the set is
  spent; the run reads nothing new).
- Perf once, at the end (D-260): the tier-4 cap night on the iOS Simulator, with the night-3 reference the same day.

## 5. Delivery (D-313.6, D-314.2)

- Two phases, no flag:
  - phase 1 ships when its hold-out passes and the author approves (checkpoint A);
  - phase 2 after its own hold-out (checkpoint B).
- Under D-314.2 the build does not stop at a checkpoint: the checkpoint PR stays open (not merged), and the next
  phase is built on a stacked branch.
- One PR per plan phase, a reviewer on every task, merges per D-137.
- Perf once at the end; strays stopped first.
- New visuals (the card's row, the boss, the back lot) go in a shot pack at each checkpoint (D-314.3).
- `docs/IDEA.md` gains a tier-4 line.

## 6. Risks

- Breaking "paying never makes it worse" may feel punishing. The card's weakness row is the mitigation; the
  weaknesses are balance values.
- Bigger waves with two side lanes may pass the night frame budget on phones. It is measured once, at the end.
- The tier bot measures everything, and its lane rule (D-312) is a measuring tool's choice, not a player's.
- The Stone wall's off-lane cost is opportunity only. If the payoff target fails, a Stone wall weakness is the first
  option in the report.
- Bench wall time: phase 1's bench is about 80 s; phase 2's adds about 40 s (warning above 150 s).

## 7. Results

Filled at each checkpoint.
