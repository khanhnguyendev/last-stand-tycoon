# E5 slice 2: diner tier 3 (design)

- **Date:** 2026-10-07. **Status:** approved section by section by the author (D-261 to D-274).
- **Builds on:** `docs/superpowers/specs/2026-10-06-e5-tier-ladder-design.md` (slice 1: the tier system and tier 2).
- **Decision log:** `docs/DECISIONS.md` D-261 to D-274. Where this spec and a decision differ, the decision wins and
  this spec is corrected.
- **Process rules in force:** sim suites and the tick budget (D-247); perf and device checks once, at the end of
  phase 5 (D-260, D-270.5); never drop, skip or weaken a test (D-132); tier-1 identity (D-237).

## 1. What this slice delivers

Tier 3 of the diner ladder, and before it a fix of how tier 2 looks.

1. **Growth readability (phase 1, tier 2):** the diner visibly grows, the yards read as owned land, the tier sign is
   readable at phone size (D-262, D-268).
2. **The tier-3 gate:** pay 1,500 on the tier sign standing on the south-west plot; that night is a boss night at the
   tier-2 cap with **Baron von Hop**, a giant hare (D-267, D-273.1); win it and the next dawn brings tier 3.
3. **Tier 3:** the front lot with one tower and one fence (D-266); a fourth lane from the south-west to the south
   wall (D-261, D-271); the siege brute (D-265); level-3 branching on two pads per building (D-263, D-264); a
   tier-dependent service layout (D-271); respawn protection for guards (D-271).

Out of scope: tiers 4 and 5 (roadmap, slice-1 spec section 10); everything in section 12.

### 1.1 Done means

Every row of section 10 has its test or report green, the checkpoint pack exists (section 11), and CI is green on
`unit`, `sim`, `sim-tiers` (or its split) and `deploy`.

## 2. Phases and the switch

| Phase | Branch | Content | Merge |
|---|---|---|---|
| 1 Growth readability | `e5/p6-growth` | Tier-2 roof, chimney, sign board; paved yards; tier sign size; fade on the whole building and on guards | self |
| 2 Data and rules | `e5/p7-t3-data` | Margin study and cap decision; tier-3 balance; monster and branch stats; lanes per tier; plan fields; schema 6; GameState branch API | self |
| 3 Night | `e5/p8-t3-night` | SW lane and zone; brute; Baron; branch effects; respawn protection; telegraph composition (the boss tuning step was dropped with the cap change, D-278) | self |
| 4 World and interface | `e5/p9-t3-world` | Plot, tier-dependent layout, branch pads with preview and refund, models, tier-3 diner, reveal with tap-skip, fourth arrow; **last task adds the tier-3 cost** | self |
| 5 Proof | `e5/p10-t3-proof` | Tier bot policies, fixtures, tier sims, report scripts, sweep, perf, checkpoint pack | **author's checkpoint** |

**The switch (D-270.1).** `TierBalance.tier_costs` gets its third entry (1,500) only in the last task of phase 4.
Until then the highest reachable tier is 2, so no sign sells tier 3 and no tier-3 content can be reached on the live
site. All tier-3 arrays may be longer than `tier_costs.size() + 1` before the switch; the rule "the top tier is
`tier_costs.size()`" is what gates content.

- Test: with the tier-3 cost absent, no sign offers tier 3, and a full tier sweep shows no brute, no SW lane spawn and
  no branch pad.
- Debug forcing: `GameState.debug_set_tier` clamps to the top tier, so it cannot pass the switch. Before the switch,
  tier 3 can be forced only from the debug overlay (`ui/debug/`), which adds the cost entry in memory and then calls
  `debug_set_tier(3, day)`. `ui/debug` is absent from the release and profile packs (the `deploy` job's existing
  check, which fails on any `ui/debug` entry). A unit test greps the sources: `debug_set_tier` and any write to
  `tier_costs` have no caller outside `tests/`, `tools/` and `ui/debug/`.

## 3. Data model

### 3.1 Lanes per tier (D-261.6, D-270.3)

- `LanePlanner.LANES` stays `["west", "north", "east"]` (tiers 1 and 2: the same list, the same `randi_range` calls,
  so every existing plan is byte-identical).
- `LanePlanner.lanes_for_tier(tier)` returns `LANES` below tier 3 and `["west", "north", "east", "sw"]` from tier 3.
  `plan()` draws from that list. Only the `lane_plan` stream is used; no other stream (spawns, travelers, drops)
  shifts.
- The tier-3 map entries live in `*_T3` constants in `core/map_layout.gd` behind accessors (`lane_path`, `zone_rect`,
  `zone_axis`, `tower_spot`, `tower_lanes`, `fence_spot`, `yard_rect`, `lanes_for_tier`, `spots_for_tier`, ...). The
  old dictionaries keep only the tier-1/2 entries (art code iterates them by key). A source-scan test bans direct
  reads of those dictionaries outside `core/map_layout.gd` (D-277).

### 3.2 Plan fields

Each wave of a plan made for tier 3 or above gains `brute_main` and `brute_side` (ints), next to `fast_main` and
`fast_side`. Tier-1/2 plans do not carry the keys, so their saved shape is unchanged; readers use `.get(key, 0)` (D-277). `LanePlanner.threat_by_lane` adds brute HP. A new `LanePlanner.composition_by_lane(plan)` returns, per
lane, `{boar, hare, brute, boss}` counts for the telegraph (section 6.5).

### 3.3 TierBalance (starting values)

| Field | Value | Note |
|---|---|---|
| `tier_costs` | `[0, 500]`, then `[0, 500, 1500]` | third entry = the switch |
| `tier_base` | `[0, 1, 8, 12]` | |
| `tier_cap` | `[0, 7, 10, 12]` | index 2 was 11 until the margin study (section 9.1, D-276); index 3 was 15 until real-play tuning (D-280) |
| `fast_share_start`, `fast_share`, `fast_ramp_days` | index 3: 0.35, 0.35, 1 | hares stay at the tier-2 share |
| `brute_cap_main`, `brute_cap_side` | index 3: 1, 0 | per wave; the side cap was 1 until real-play tuning (D-280) |
| `brute_ramp_days` | index 3: 3 | first night: one brute, on the last wave's main lane |
| `boss_kind` | `[&"", &"boss", &"baron", &""]` | the boss fought to LEAVE that tier; the top tier's entry is empty |
| `respawn_protect_s` | 1.5 | in `GuardBalance` |

### 3.4 Monsters (`MonsterBalance`, starting values)

| Kind | HP | Speed | Damage | Reach | Steaks | Priority | Special |
|---|---|---|---|---|---|---|---|
| `brute` | 240 | 1.2 | 8 | 1.2 (the Boar's) | 8 | fence on lane, guard, diner | `fence_damage_mult` 4.0 |
| `baron` | 500 | 2.4 | 12 | 1.6 | 150 | guard, diner (the hare's) | walks past fences; boss marker |

The roadmap's "reach beyond fences" is replaced by "wrecks fences" (D-265): the brute keeps the Boar's reach, so stop
points and test A' stay valid. Boss reward rule (D-274.2): a boss drops one cap night of the tier being finished
(tier 2: 450 gold = 150 steaks).

### 3.5 Branches (`BranchBalance`, new resource; starting values)

| Branch | Range | Per shot | Interval | Other |
|---|---|---|---|---|
| Tower level 3 (today) | 8.0 | 18 | 0.5 s | reference |
| `longbow` | 9.98 | 120 | 3.0 s | |
| `volley` | 8.0 | 3 x 10 | 0.5 s | first 3 targets of `Targeting.select`, one projectile each, no splash |

| Branch | HP | Other |
|---|---|---|
| Fence level 3 (today) | 320 | reference |
| `stone` | 640 | damage taken from kind `brute` x 0.5 (`damage_taken_mult_by_kind`) |
| `spike` | 320 | `thorn_damage` 6 per hit taken; `pass_damage` 10 once per passing hare kind (hare, baron) |

- Spike values are the ones at the tier-3 base; both scale with the night's HP multiplier relative to the tier-3
  base multiplier (D-272.1), so Spike does not fade at the cap.
- Longbow differs from section 3 of the brainstorm (45 per 1.0 s): with real hare HP (39.75 to 51.7 at pressure 12,
  46.5 to 72.85 at 15, the wave-size factor included) the D-272.3 ordering needs a slow, heavy shot. 120 per 3.0 s
  gives single-target 40 per second (unbranched 36, Volley 20) and the fewest hares per second at every wave (D-276).
- Costs: `tower_branch_cost` 500, `fence_branch_cost` 300.
- Longbow range rule (D-271): at any range a tower may reach the stop points OR the fence spot of at most 2 lanes.
  Probe maximum 10.28 m (bound by `tower_nw` and a SW stop point); Longbow = maximum minus 0.3 = 9.98.

### 3.6 Buildings and save schema 6

- `GameState.buildings[id]` gains `branch` (`""`, or a branch id) and `branch_paid` (`{branch_id: int}`).
- API: `pay_into_branch(spot_id, branch_id, amount)`, `branch_of(spot_id)`, `branch_cost(spot_id)`. Commitment only
  on full payment (D-263.1). On completion the other pad's partial payment is refunded to gold and
  `EventBus.branch_refunded(spot_id, amount)` fires for the coin flight. `reset_destroyed_fences` clears `branch` and
  `branch_paid` (D-263.2). Partial payments persist through close-up, night and save/load (D-273.3).
- `SCHEMA_VERSION` 6 with a built-in step 5 to 6 (adds the two building fields; nothing else). The fail/quit
  snapshot carries branch state and pad payments. A saved pad payment at or above the branch cost clamps to cost - 1
  on load (D-234: a balance change never loses a save). Partial pad payments on a fence destroyed at night are
  refunded to gold at dawn (D-277).
- Migration fixtures: the eight committed fixtures as they were before the cap change, in `tests/fixtures/v5/` (five
  are schema 5, one schema 4, two schema 3); the migration test loads every one (D-270.2).

## 4. The map at tier 3 (D-271)

All coordinates were produced by a headless probe that calls the game's camera, path and geometry code. The plan
pins each by a test.

### 4.1 Lane, zone, fence, tower, plot

| Item | Value |
|---|---|
| `LANE_PATHS["sw"]` | `[(-24, 11), (-3.5, 11.0), (-2.75, 5.2)]`, 26.35 m |
| `ZONE_RECTS["sw"]` | `Rect2(-4.0, 4.0, 2.5, 1.2)`; stop points x -3.75 to -1.75 at z 5.2 |
| `ZONE_AXIS["sw"]` | `(1, 0)` |
| Fence spot `fence_sw` | 4.0 m back from the end: (-3.26, 9.17) |
| `tower_sw` | (-6.6, 5.6); its lanes are `["sw"]` (the west fence, 9.15 m, and the west zone's far corner, 7.56 m, are beyond level-1 range; west is its second lane by distance only) |
| `TIER_SPOTS[3]` | `["tower_sw", "fence_sw"]` |
| Plot (`YARDS["front"]`, `YARD_TIER` 3) | `Rect2(-7.6, 5.6, 6.1, 4.3)` |
| `TIER_SIGNS` | `{2: (-10.0, 7.5), 3: (-4.7, 8.5)}` (the sign of tier N is shown at tier N - 1) |

Probe results (the tests re-derive them):

- **Visibility (D-261.1):** 2.45 s at aspect 0.30, 3.25 s at 9:21 and 9:16, 8.9 s or more wider. A flat road approach
  gives 1.60 s on a phone; only bends at x >= -4.5 pass every aspect.
- **Coverage (D-261.2):** no reachable position reaches 3 lanes. 2-lane positions: west+sw 142, west+north 16,
  north+east 16.
- **Tower (D-261.5, D-266.1):** SW zone farthest corner 5.35 m and SW fence 4.88 m (range 7.0 at level 1); lane with
  offsets 2.77 m (1.5 needed); guard return path 1.89 m; third lane (north) 12.17 m by the Longbow rule.
- **Path:** nearest diner wall 1.25 m (reach 1.2).

### 4.2 Tier-dependent service layout

Tiers 1 and 2 are unchanged. From tier 3:

- `MapLayout.queue_slots(tier)`: `[(0, 6.0), (1.1, 6.9), (1.3, 8.0), (1.4, 9.1), (1.8, 10.3), (3.0, 10.3),
  (4.2, 10.3), (5.4, 10.3), (6.6, 10.3)]` (today's slots 2 to 4 sit on the lane or in the fence; the worst is 0.12 m
  from the bar). Nearest items: counter pad 1.53 m, close-up sign 1.30 m, HOME 1.46 m.
- `MapLayout.traveler_exit(tier)`: `TRAVELER_ENTER`'s point, (24, 11) (constraint 3: east reuses the entry line and
  clears the fence by 3.80 m; today's west exit passes 1.74 m from `tower_sw` and crosses the plot).
- HOME, the close-up sign, the gold pile and the diner door stay. The gold pile is 0.29 m from the lane line and is
  empty at night; a test proves it is empty from close-up until dawn at every tier.
- The switch happens at the tier-3 dawn, when no traveler exists. A mid-day save/load at tier 3 restores the tier-3
  layout.

### 4.3 Branch pads (D-263.4, D-266.2)

- Radius 0.9 m (`MapLayout.BRANCH_PAD_RADIUS`). `MapLayout.BRANCH_PADS: {spot_id: [pos_a, pos_b]}` for all nine
  spots, within 2.8 m of the spot.
- Clearance rules, each pad: lanes (line distance >= spread + radius), attack zones, fence bars, towers, other pads
  (>= 2 radii), the close-up sign, station zones and pads, the gold pile, HOME, the door, tier-3 queue slots,
  traveler entry and exit lines, hero colliders, map bounds.
- Fixed in Task 8 with the probe (`tools/probe_t3_layout.gd`): 18 coordinates in `MapLayout.BRANCH_PADS`. Yard props
  and kerbs count as obstacles too, so the pads sit tight: the worst clearance is 0.15 m (the test's extra margin is
  0.1 m). The pads of `tower_nw`, `tower_ne`, `tower_w` and `tower_e` do not sit on both sides of their tower. The
  pad geometry test proves every rule; pads also join the waypoint graph (`WaypointGraph.create_for_tier(3)`).
  Task 17 judges them on screenshots.

## 5. Phase 1: growth readability (D-262, D-268)

- **Diner per tier, inside the footprint, nothing overhanging:** tier 2 = a wood roof, a second chimney and a
  cream sign board, placed so they hide nothing tier 1 does not hide; it is not taller than tier 1 (D-276). Tier 3 =
  a set-back second storey with lanterns (phase 4), which carries the height change. The terraces of slice 1 stay.
- **Land:** yards and the plot get a paved tint with a low border instead of lane dirt and edge stones. Small props
  (crates, barrels, a bench) on owned land only, outside every lane, zone, fence spot, pad, station, sign, HOME, queue
  slot and traveler path; non-colliding; in the geometry tests.
- **Tier sign:** a larger board and label, judged on a 40% screenshot.
- **Occlusion:** the occluder fade covers the whole building at every tier, and guards trigger it as the hero and
  monsters do. Camera tests at tier 3 (phase 4): hero, monster and guard at the north zone are visible; the taller
  diner adds no occlusion of static things (the Archer, tower pads, fence spots, world labels) compared with tier 1,
  and any ground it newly hides lies inside a fade box (D-276; tier 1 already hides the `tower_nw` and `tower_ne`
  pad centres from some north-lane positions).
- **Evidence:** before/after screenshots at full and 40% scale under `docs/review/media/e5t3/growth/`; REVIEW_QUEUE
  entries.
- Tier-1 identity: phase 1 is visual only; `tools/baseline_rows.sh 7` must print `rows 1-7 identical`.

## 6. The night at tier 3

### 6.1 Pressure and waves

Pressure 12 (it was 12 to 15, and brutes came on the side lane too, until D-280: sections below that say
"pressure 15" or "side lane brute" describe the values before that ruling). One main lane and at most one side lane per wave, drawn from four lanes. Brutes: night 1 of tier 3
has one, on the last wave's main lane; each day one more wave (from the last backwards) carries a main-lane brute,
and from `brute_ramp_days` on every wave has 1 main + 1 side (1, 2, 3 brutes, then 3 plus the sides).
Brutes replace no Boar: they are added (their HP is in the threat total and their steaks in the economy).

### 6.2 The siege brute (D-265)

Boar target order. Damage x `fence_damage_mult` against fences, normal against guards and the diner. A brute lane
with no fence behaves as a tanky Boar. Procedural mesh in the Boar family (preferred path, D-265.6): big,
cute-dangerous, heavy slow walk; a ground-thump effect and sound on each fence hit; readable at 40% scale.

### 6.3 Baron von Hop (D-267)

- The boss of the tier-2 boss night (`boss_kind[2]`): the hare's rules at boss scale. It walks past fences; Spike
  pass damage applies once. It leads the last wave on its main lane by `boss_lead` (3 s).
- The boss lane is in the seeded plan and shown in the telegraph before close-up with the boss icon. Mercy applies.
- Catchable: a hero starting at that lane's attack zone reaches melee range before the Baron reaches the zone (test,
  every lane of tier 2).
- Hare builder, clearly bigger, a crown-style marker consistent with the Boar King's; the bar name "Baron von Hop"
  (name check logged in D-273.1).
- 150 steaks. The steak pool is sized for the boss drop plus a full cap wave. If the profile build shows a frame cost,
  the drop is bundled visually (fewer pieces, each worth k steaks); freezer and economy counts stay exact (test).

### 6.4 Branch effects

- **Longbow / Volley:** `TowerSpot` reads its stats through one function that returns the branch's range, damage,
  interval and projectile count (the unbranched level-3 values when `branch == ""`). Volley fires at the first
  `count` entries of `Targeting.select`'s order (stable spawn-index tie-break).
- **Stone:** `GameState.damage_fence(spot_id, amount, attacker_kind)` applies `damage_taken_mult_by_kind`.
- **Spike:** thorns hit the attacker on each hit the fence takes; a hare-kind monster crossing the fence's line takes
  `pass_damage` once (a per-monster flag, reset on pool reuse). Hares still walk past: their path and timing are
  unchanged (test).
- **Identity test on Balance (D-272.3, D-273.0).** Named measures, computed in whole shots against real monster HP at
  pressure 12 and 15:
  1. single-target DPS (raw damage over interval): Longbow highest; in whole shots against a lone brute Longbow is
     never slower than the unbranched tower;
  2. range: Longbow longest;
  3. DPS against 3 targets (raw): Volley highest;
  4. hares killed per second (3 or more in range): Volley most, Longbow fewest;
  5. seconds a fence holds against one brute: Stone longest;
  6. damage to a passing hare: only Spike is above 0;
  7. the unbranched level 3 is the best at none of measures 1 to 6, a shared top included.

### 6.5 Telegraph and arrows (D-264, D-265.3)

Each lane shows a row of per-kind counts (Boar, hare, brute icons with numbers) and the boss icon on the boss lane,
from `composition_by_lane`. The rows sit up the lanes in a free band (z = -15; south of the road for sw), clear of
pad labels and the hero (D-278). A fourth edge arrow serves the SW lane; an arrow whose lane carries a brute gets a
distinct heavy mark. All judged at 40% scale.

### 6.6 Guards (D-271)

A respawned guard is untargetable for `respawn_protect_s` (1.5 s) and walks to its post, on every lane. The diner
door stays the respawn point. The hero has no HP, so nothing changes for the hero.

## 7. World and interface at tier 3 (D-273)

- **Reveal:** the tier-2 reveal system with a per-tier step list (plot paving, fence spot, tower spot, lane strip with
  its arrow, second storey); the camera frames the diner and the plot. Branch pads are day-only, so they are not a
  reveal step: they appear with the first tier-3 day (D-279). A tap anywhere fast-forwards it after a 0.6 s guard;
  the joystick stays disabled until it ends or is skipped. A tab closed mid-reveal resumes at the card pick at tier 3.
- **Branch pads:** at a level-3 building at tier 3 or above, the single pad is replaced by two pads. Information
  shows in stages (D-279): far away a ring and an icon; within 3.5 m of the building also the cost; on the pad the
  name, the effect line and the preview, while the sibling pad shows only its ring. Standing on a pad shows the preview before any gold is committed: Longbow's range ring,
  "x3", a shield, spikes. Fence pads add a broken-fence icon and "lost if broken". Arming (D-121) and the stand-still
  threshold apply; a hero walking across both pads commits nothing. On completion the other pad vanishes and its
  partial payment flies back to the hero as coins.
- **Models:** four branch variants readable at phone size (Longbow taller and slimmer, Volley multi-barreled, stone
  and spiked fences), through the art pipeline and ART_BIBLE.
- **Sounds:** the brute and the Baron reuse existing monster sounds; one new thump from a CC0 pack already in the
  repo, logged in `docs/ASSET_LICENSES.md`.
- **Onboarding:** the first time branch pads appear, the pointer points at one pad once.
- **Texts** (all through `tr()`): "Longbow", "Volley", "Stone wall", "Spike fence", their preview lines, "lost if
  broken", "Buy the lot" (D-279: "Buy the front lot" did not fit the sign), "Baron von Hop".

## 8. Economy (D-274)

Income: 6 gold per kill before cards. Cap nights: tier 1 336, tier 2 450, tier 3 about 650 with brutes (estimate; the
sweep measured 1,260 to 1,440 per night with cards, section 13).

| Purchase | Cost | Count | Total |
|---|---|---|---|
| The plot (the tier-3 cost) | 1,500 | 1 | 1,500 |
| `tower_sw` to level 3 | 40 + 80 + 160 | 1 | 280 |
| `fence_sw` to level 3 | 20 + 40 + 80 | 1 | 140 |
| Tower branch | 500 | 5 | 2,500 |
| Fence branch | 300 | 4 | 1,200 |
| **Total** | | | **5,620** |

Sweep targets and reports (`--bot=tier`, the same card policy as the slice-1 tier sweep, seeds 20260930, 1, 2):

- from the tier-3 dawn until the ladder completes, `unspent_gold_at_closeup` <= 650;
- reported: the plot purchase day, the day the ladder completes, `fence_rebuild_gold` per night (REVIEW_QUEUE "brutes
  make fences a tax" if its median at the tier-3 cap exceeds 30% of nightly income);
- after the ladder, gold piles up again: the accepted known gap (REVIEW_QUEUE: "tier 3 has no sink after the ladder;
  tier 4 must provide one").

## 9. Proof

### 9.1 The tier-2 cap margin (D-269, D-270.4)

Done in phase 2 (`tests/sim/report_margin.gd`, ten seeds). Cap 11: held on 8 of 10 seeds, median diner HP left 0.393,
lowest quarter 0.014, two real falls. Cap 10: held on 10 of 10, median 0.688, minimum 0.177. The author lowered
`tier_cap[2]` to 10 (D-276); fixtures, pins and the tick budget were re-recorded. The Baron must still fail the
no-yard-towers run. Three tuning rounds at most for the Baron (D-103).

### 9.2 Tier sims in CI (`tests/sim_tier/`, each with a tick-budget entry)

| # | Sim | Assertion |
|---|---|---|
| 2 | Baron night, full tier-2 build (fixture) | held, 0 retries |
| 3 | Baron night, no yard towers (fixture) | fails or needs mercy retries |
| 4 | Baron alone | the hero at the lane's zone reaches melee range first |
| 5 | First tier-3 night, tier bot | held, 0 retries |
| 6 | Tier-3 cap, full build, policies A, B, mixed, threat-matched (CI seed) | each holds with 0 retries. The ordering "threat-matched >= each other policy" was NOT built into CI (D-280: on the CI night threat is third; the multi-seed report says tie) |
| 7 | Respawn | a guard respawning into an occupied SW zone is not knocked out again within 5 s; no actor is knocked out more than twice in any 15 s window |
| 8 | Identity | tier 1 and 2 plans, sweep rows 1 to 7, and one tier-2 fixture night are unchanged by the slice |

Slice 1's four tier sims stay. Sim 1 (the margin study) and sim 6's multi-seed ranking are report scripts, not CI
tests (D-274.4): `tests/sim/report_margin.gd` and `tests/sim/report_policies.gd`, run like the sweep; results go into
section 13 and the checkpoint pack. A policy gap above 15 points of diner HP: REVIEW_QUEUE "possible dominant branch".
Threat-matched not best: REVIEW_QUEUE "branches don't reward reading the telegraph".

### 9.3 CI time

Wall time warns at 60 s and fails at 150 s per job. If `sim-tiers` nears 150 s it is split into `sim-tiers-a` and
`sim-tiers-b` before any test is touched, and the main session updates the required checks (authorized, D-274.4).

### 9.4 Bots and fixtures

- The tier bot gains: paying tier 3 as it paid tier 2; building `tower_sw` and `fence_sw`; a branch policy
  (`all_a`, `all_b`, `mixed`, `threat`), deterministic. `threat` reads `composition_by_lane` for tonight: a fence on a
  lane with a brute takes Stone, otherwise Spike; a tower whose lanes carry a brute takes Longbow, otherwise Volley.
- PlannerBot is untouched (tier 1, byte-identical days 1 to 7).
- Fixtures through `make_save.gd --fixture=tier3`: the Baron night with the full tier-2 build, the same without yard
  towers, the Baron alone, the first tier-3 night, a full tier-3 build at the cap (one per policy).
- Pools: brute and boss pools are sized from the new caps; the runtime-growth warning applies (D-270.6).

## 10. Constraint map

| Decision | Requirement | Test or report |
|---|---|---|
| D-261.1 | SW visibility >= 2.0 s, every aspect | `test_lane_visibility` over `lanes_for_tier(3)`; `e5t3/telegraph/day_tier3_sw.png` |
| D-261.2 | no position reaches 3 lanes | `test_geometry` A' over 4 lanes, pairs printed |
| D-261.3 | travelers never walk through a fence | `test_tier3_layout`: exit and entry lines vs every fence bar, per tier |
| D-261.4 | nothing in the SW zone or on its fence spot | `test_tier3_layout`: stations, signs, HOME, queue slots |
| D-261.5, D-266.1 | `tower_sw` reaches zone and fence; <= 2 lanes | `test_geometry` B, C; `test_longbow_reach` |
| D-261.6, D-270.3 | tier-1 identity, RNG identity | `tools/baseline_rows.sh 7`; `test_lane_planner` tier 1/2 literals; sim 8 |
| D-262, D-268 | growth readability | `docs/review/media/e5t3/growth/`; `test_occluder_fade`; `test_diner_art` |
| D-263.1 | commit on full payment; refund; walk-across | `test_branch_pads`, `test_branch_state` |
| D-263.2 | branch lost with the fence | `test_branch_state` |
| D-263.3, D-273.4 | preview and labels readable | `test_branch_pads`; `e5t3/pads/*_40.png` |
| D-263.4, D-266.2 | pad geometry | `test_branch_pad_layout`; `e5t3/pads/sw_corner.png` |
| D-263.5, D-264 | policies hold; ranking | sim 6; `report_policies` |
| D-264 | branch definitions | `test_branch_effects`; `test_branch_identity` |
| D-264, D-271 | Longbow rule and range | `test_longbow_reach` (all tower spots x all lanes) |
| D-264, D-274.3 | sink sizing | tier sweep `LADDER` line |
| D-265 | brute rules | `test_brute`; sims 5, 6 |
| D-267 | Baron rules; examines tier 2 | `test_baron`; sims 2, 3, 4 |
| D-269, D-270.4 | cap margin | `report_margin`; REVIEW_QUEUE |
| D-270.1 | the switch | `test_tier3_switch`; sweep assertion |
| D-270.2, D-273.3 | schema 6 | `test_save_v6` (v5 fixtures, round trip, snapshot) |
| D-270.6 | pools | `test_wave_director`, `test_boar`, `test_branch_effects` (pool sizes); sims 5 and 6 (no runtime growth) |
| D-271 | gold pile empty at night | `test_piles`, `test_tier3_world_layout` (no test file of the planned name exists) |
| D-271 | respawn protection | `test_guards`; sim 7 |
| D-271 | layout restored after load | `test_tier3_layout` save/load case |
| D-272.1 | Spike scaling | `test_branch_effects` |
| D-272.2, D-274.2 | boss drop and pool; bundling | `test_baron`; `test_wave_director` |
| D-273.2 | reveal skip and resume | `test_tier_reveal` |
| D-274.3 | fence rebuild, ladder days | tier sweep `LADDER` line |

## 11. Checkpoint pack (D-270.5)

`docs/review/E5_T3.md` plus media under `docs/review/media/e5t3/`: a 60 to 90 s iOS Simulator video (the Baron night,
the dawn reveal, a tier-3 night with a brute lane and a branch purchase); before/after growth screenshots; the SW
corner shot with all pads; tier sim results, the policy comparison and the margin study; the profile-build perf
reading at a tier-3 night (taken once, at the end of phase 5); this slice's REVIEW_QUEUE entries, top first.

## 12. Post-tier-3 ideas (not in this slice)

Paid respec as a gold sink (D-263.6). Slow and control branches (D-264). A thrower enemy with ranged attacks for tier
4 or 5 (D-265). Several bosses at once (D-267). Movable guard posts (IDEA.md "Later"). A sink after the tier-3 ladder
(tier 4).

## 13. Results

Filled at the end of phase 5 (2026-10-08). Full pack: `docs/review/E5_T3.md`. Decisions: D-279, D-280.

- **Tier-2 cap (sim 1, margin study):** cap 11 held on 8 of 10 seeds, cap 10 on 10 of 10 (median diner 69%, lowest
  18%). Applied: 10 (D-276).
- **Tier-3 difficulty (real play, three seeds, 32 days, threat policy):** with the approved values (cap 15, brutes
  on both lanes) 23 of 40 tier-3 nights needed a retry. Applied: `tier_cap[3]` 12 and `brute_cap_side[3]` 0, with 0
  of 40. Tier 3 no longer ramps in pressure. Two early nights on one seed are held at 1% and 4% (D-280).
- **Baron night:** held with 0 retries on all three seeds (diner 52% to 68%).
- **Policies (mean diner HP at dawn, points):** Volley + Stone 87.2, Volley + Spike 76.7, threat-matched 75.4,
  Longbow + Stone 67.2, Longbow + Spike 55.8. Tower effect +20.4 (Volley), fence effect +10.9 (Stone), interaction
  +1.0. `DOMINANT_BRANCH: yes` (gap 20.9 over the four spec policies; 31.4 over the 2 x 2). `THREAT_BEST: tie`.
  Retry nights of 40: 0, 0, 0, 1, 6. Both go to the review queue (entries 26, 6); nothing was retuned.
- **Ladder:** the front lot is paid in sweep row 16 to 20; everything is bought 5 to 8 tier-3 days later; peak
  unspent gold 267 to 565 (`UNSPENT_TARGET: PASS`, limit 650); `FENCE_TAX: yes` (30.6% to 34.9% of the night's
  income; threshold 30%); 4,600 to 9,000 gold unspent by day 30.
- **CI sims 2 to 8:** all pass. Sim 6 asserts that each policy holds one cap night; the threat ordering was not
  built (D-280). Sim 7's "no actor knocked out more than twice in 15 s" never sees a second knockout with
  protection on; the ladder runs show 0 or 1 guard knockouts per night.
- **Performance (profile build, iOS Simulator, a tier-3 night, median of 3):** 58.8 fps, worst frame 110 ms, 48 draw
  calls; a tier-2 night in the same session 59.4 fps, 43 draw calls. The worst-frame gate (under 60 ms) fails as
  before (known issue 2).
