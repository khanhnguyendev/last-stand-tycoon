# E8: tier 4, the night side (sharper specialists, then tier 4)

Status: approved design (brainstorm 2026-10-15, decisions D-313 and D-314). Written for the plan; the author asked
for the rest to run autonomously (D-314.1).

Inputs: `docs/IDEA.md` (pillars, tiers), `docs/superpowers/specs/2026-10-06-e5-tier-ladder-design.md` section 10
(roadmap), `docs/superpowers/specs/2026-10-08-e6-tier3-retune-design.md` (lane character, bench, report),
review queue E6-1 and E6-2, D-307.7 (fresh seed sets), D-312 (the measuring bot).

## 1. Why

E6 shipped lane character but its payoff failed on every unseen set: the threat-matched build leads Longbow + Stone by
+1.5 to +2.7 points (target 5), and with the walk-time bot it is not a bot artefact (D-312.4). The fixed builds sit
within 4 to 5 points of each other: every branch is fine everywhere, so reading the lanes barely matters. The first
tier-3 night is easy (branch builds keep a median 97%, D-312.5). Tier 4 is the next rung of the ladder and the place
the roadmap puts bigger waves and two side lanes at once.

Tier 4 has three subsystems; each gets its own spec: E8 the night side (this), E9 the seller (E2, D-233), E10 passive
equipment (E3). E8 comes first (D-313.1).

## 2. Goals and non-goals

Goals:
1. Reading the lane pays: the threat-matched build leads the best fixed pair by 5 points or more on unseen seeds.
2. A tier's first nights are tight but fair: branch builds keep a median 50% to 80% of the diner on the first night.
3. Tier 4 exists: a tier-3 boss night with a siege boss, the back lot with two towers, nights with two side lanes at
   once and bigger waves, and a full build that holds tier 4's cap with 0 retries.

Non-goals: no new monster kind (D-313.3); no new lane (tier 5); no new fence; the seller and equipment (E9, E10);
no tier-4 boss (tier 4 is the top tier of this build); no change to tiers 1 and 2 (identity); no flag (D-313.6).

## 3. Phase 1: sharper specialists (tier 3; ships on its own)

### 3.1 The rule change (D-313.2)

The E6 bench rule "paying never makes it worse" (every branch at least as good as unbranched on every lane) is
REVERSED off the branch's own lane. New bench rules, per live pressure (10 to 12 in phase 1; 10 to the tier-4 cap
in phase 2), on the full lane-type bench (`tests/bench/`):
- **On-lane:** each specialist beats the unbranched building and the other branch of its kind on its own lane type
  by at least `on_lane_margin` (relative, on the bench's measure for that branch: diner HP lost for towers and
  Spike, fence-stands seconds for the Stone wall).
- **Off-lane:** on the opposite lane type (a siege branch on the hare lane, a hare branch on the siege lane) the
  Longbow, the Volley and the Spike fence are worse than the unbranched building by at least `off_lane_margin`.
- **Neutral:** on the neutral lane each branch is within `neutral_band` of the unbranched building, either way.
- **Stone wall exception (D-314.4):** hares walk past every fence, so on the hare lane a Stone wall equals the
  unbranched fence; its off-lane cost is the gold not spent on Spike. The off-lane rule does not apply to it; its
  on-lane and neutral rules do.
Margins are balance values (`BranchBalance`), starting at `on_lane_margin` 0.15, `off_lane_margin` 0.10,
`neutral_band` 0.15. The bench prints every rule's numbers.

### 3.2 The weaknesses (numbers on existing systems; no new mechanic)

| Branch | Lane | Strength (today) | New weakness | Start | Pre-authorized range |
|---|---|---|---|---|---|
| Longbow | siege | 120 per 2.0 s, x2 against brutes | `kind_mults[hare]` < 1: the heavy arrow deals less to hares | 0.5 | 0.3 to 0.8 |
| Volley | hare | 3 targets x 10 per 0.5 s | `kind_mults[brute]` < 1: light arrows barely scratch brutes | 0.3 | 0.1 to 0.6 |
| Spike fence | hare | thorns 6, pass damage 24 to hares | `damage_taken_mult_by_kind[brute]` > 1: brutes break it fast | 2.0 | 1.5 to 3.0 |
| Stone wall | siege | 640 HP, brutes deal x0.5 | none (3.1) | - | - |

Tuning inside the ranges, and of the strengths within +-25% of today's values, is pre-authorized (as D-292 did for
E6). Anything outside, or a new mechanic, is an escalation logged in the final report (D-314.1).

### 3.3 First nights (D-313.4)

- Tier 3's start pressure moves from 10 toward 11 (`tier_base[3]`, range 10 to 11) once the specialists make the
  right branch matter; it still ramps one per night to the cap 12.
- New report target `FIRST_NIGHT_BAND`: across branch builds, the median diner fraction on the first tier-3 night
  is between 0.50 and 0.80. The floor stays (`FIRST_T3_NIGHT` >= 25% for every policy).

### 3.4 Interface (D-313.7)

The branch card's second line names the weakness, through `tr()`: Longbow "weak against hares", Volley "weak
against brutes", Spike fence "brutes break it fast", Stone wall "no use against hares". The card layout keeps its
obstacle and clipping tests; a shot pack shows the card for all four.

### 3.5 Proof of phase 1

- Bench (CI): the rules of 3.1 at 10, 11, 12.
- Retune report: the tuning set (seeds 1, 3, 4, 7, 14) for tuning; then measurement set #5 (scan positions 10 and
  11 per siege lane) once with `--final` and the walk bot. Targets: THREAT_LEAD >= 5 and ahead on 6 of 8 (set),
  THREAT_LEAD_BY_LANE none negative, RETRY_NIGHTS 0 for branch policies, FIRST_T3_NIGHT >= 25%, FIRST_NIGHT_BAND,
  FENCE_TAX <= 30%, LANE_CAP_GUARD 0. FIXED_SPREAD changes meaning: the fixed pairs are now expected to differ;
  the target becomes "spread >= 5 points" (the builds are no longer interchangeable), reported, not a must-hold.
- Tier-3 sims keep passing; tick budgets updated deliberately.
- Identity: tier 1 and 2 identical; the tier-3 baseline re-recorded once with the reason.
- A failed target on set #5 stops phase 1's merge: the final report carries per-seed data and 2 to 3 options
  (D-314.1); no set is re-used.

## 4. Phase 2: tier 4

### 4.1 Reaching tier 4

- `tier_costs` gains its third entry (the price of tier 4; start 3500, range 3000 to 5000), paid on the tier sign
  standing on the back lot, as every tier (D-240's rule).
- That night is the tier-3 boss night: `boss_kind[3]` = `wrecker`, the siege boss. It leads wave 3's main group on the
  run's siege lane (D-238's shape: boss first, the rest after `boss_lead`).
- Win it: the next dawn plays the tier-4 reveal (land, the two towers, the sign moves on; no lane-character step:
  the character is the run's, already shown at tier 3).
- Loss: the existing retry with the payment kept, mercy as always.

### 4.2 The siege boss ("the Wrecker")

- A `MonsterStats` resource: the brute's rules (fence-on-lane priority, reach) at boss scale: HP about 6 brutes at
  the tier-3 cap, fence damage x3 a brute's, damage to the diner like the Boar King's per second. Every number in
  `balance/`.
- Look: the brute model scaled and recoloured (as the Boar King is the boar's), a world HP bar like the bosses',
  the boss moon. No new art pack. Its look is in the checkpoint shot pack (D-314.3).
- Sim: the boss alone needs at least `boss_min_hold_s` (15 s) to fell the diner from its first hit (sim 2's rule);
  a full tier-3 branch build wins the boss night within the allowed retries.

### 4.3 The back lot

- New land with two tower spots (`TIER_SPOTS[4]`), each a single-lane tower like the tier-2 yard towers, taking
  branches at level 3. Placement rule (D-314.5): after tier 4 every lane is covered by at least two towers, so the
  south-west lane (one tower today) gets one; the second goes to the lane the layout pass finds land for.
- Coordinates are pinned by tests, not here (D-240): clear of lanes by `lateral_spread` + 1 m, of pads, zones,
  slots, posts and the traveler path; on screen at 9:16; the sign stands on the land it sells.
- No new fence.

### 4.4 Nights at tier 4

- `LanePlanner` at tier 4 draws a second side lane per wave AFTER every draw it makes today, and only at tier 4, so
  the RNG order of tiers 1 to 3 is unchanged (identity). The side group's count is split between the two side lanes
  (the extra unit to the first); one of the four lanes rests per wave.
- `tier_base[4]` = 12 (tier 3's cap), `tier_cap[4]` starts at 15 (range 14 to 16): bigger waves through the existing
  wave formulas; it ramps one per night (the first tier-4 night is at 12).
- Lane character unchanged: one siege lane, one hare lane; brute and hare counts per the tier-3 rules at tier 4's
  pressures (`brute_cap_*[4]`, `fast_share*[4]`: start equal to tier 3's).
- `WaveSchedule`, the telegraph and the edge arrows show two side lanes.

### 4.5 Under the hood

- Save schema 8: the two new spots in `buildings`; v7 to v8 migration adds them at level 0; migration test from a
  committed v7 fixture.
- `TierBot` buys tier 4 after the tier-3 ladder and the new towers; every branch policy covers them; the walk rule
  (D-312) is unchanged.
- The retune report and the sweep handle tier 4 (cap nights, the ladder, the first tier-4 night); phase-2 runs are
  45 days (D-314.6) so the bot reaches tier 4's cap.
- A tier-4 identity tool `tools/baseline_t4.sh` once tier 4 is built.

### 4.6 Proof of phase 2

- Tier-4 sims (CI, a sim-tiers suite with tick budgets): the boss night (sim 2's rule and a win), the first tier-4
  night (the band), a full tier-4 branch build at the cap with 0 retries on three seeds.
- Bench at the tier-4 pressures (the 3.1 rules up to the tier-4 cap).
- Retune report on the tuning set, then measurement set #6 (scan positions 12 and 13) once with `--final`. Targets:
  phase 1's, plus FIRST_T4_NIGHT in the band, RETRY_NIGHTS 0 at tier 4.
- Perf once, at the end (D-260): the tier-4 cap night on the iOS Simulator, with the night-3 reference the same day.

## 5. Delivery (D-313.6, D-314.2)

- Two phases, no flag. Phase 1 ships when its hold-out passes and the author approves (checkpoint A); phase 2 after
  its hold-out (checkpoint B). Under D-314.2 the build does not stop at a checkpoint: the checkpoint PR stays open
  (not merged) and the next phase is built on a stacked branch.
- One PR per plan phase, a reviewer on every task, merges per D-137; perf once at the end; strays stopped first.
- Visuals (the card's line, the boss, the back lot) are new; each checkpoint carries a shot pack (D-314.3).

## 6. Risks

- Breaking "paying never makes it worse" may feel punishing; the card's weakness line is the mitigation, the margins
  are balance values.
- Bigger waves with two side lanes may exceed the night frame budget on phones; measured once at the end.
- The tier bot measures everything; its lane rule (D-312) is a measuring tool's choice, not a player's.
- The Stone wall's off-lane cost is opportunity only (3.1); if the payoff target fails, a Stone wall weakness is the
  first lever in the report's options.

## 7. Results

Filled at each checkpoint.
