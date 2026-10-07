# E5 Diner Tier Ladder, slice 1 (tiers 1 and 2): Design Spec

- **Project:** Last Stand Tycoon (see `docs/IDEA.md`). This builds on the S1 to S5 and E1 specs. Their conventions,
  architecture and rules still apply.
- **Precondition:** `main` after the E1 follow-ups (D-234, D-235): GameState schema 4, the built-in migration table,
  the S4 determinism baseline, the upgrader sweep, the E1 perf fixtures.
- **Status:** brainstormed with the author on 2026-10-06. The author chose every option in sections 1 to 3 and the
  design below; the numbers are starting values for the sims.
  **Built on 2026-10-06 (phases 1 to 4). Sections 15 and 16 record what the build changed and measured; where they
  differ from sections 1 to 14, sections 15 and 16 are current.**
- **Decision log:** `docs/DECISIONS.md` D-236 to D-247 (the texts are in section 12).
- **Name:** the tier ladder is its own expansion (D-233). It is E5; E2, E3 and E4 become content it unlocks.

---

## 1. Goal and success criteria

The author wants the diner to keep growing and the player to always know where they are heading. Three recorded
problems drive it:

- Defense has a ceiling (2 towers, 3 fences, 3 levels each) and monsters scale with the day without limit. The planner
  bot first fails at day 9 or 10 and afterwards clears nights only through mercy (`docs/review/media/final/sweep.md`).
- Gold has no use from about day 7, and the game has no goal or end state (REVIEW_QUEUE 24, 25).
- One monster type, so every night plays the same.

**The spine is the diner tier, 1 to 5.** Tier 1 is today's game. Difficulty follows the tier, not the day; inside a
tier it ramps a little and stops at a cap. Income comes only from kills, so a low tier is safe and earns little; that
is the whole incentive to tier up. Tiering up is three steps: pay gold standing still on a sign, win that night's boss,
and the next morning the diner grows (land, build spots, a monster type, more customers). The game stays permanent:
nothing built is ever lost, there is no reset, and tier 5 is the long-term goal. Mercy stays as it is, hidden. One
thumb: no new buttons or menus.

**This slice** proves the loop "pay, beat the boss, the diner grows" with the tier system plus tier 2 only: side
yards, two yard towers, the fast monster, one boss night, the diner changing shape. Tiers 3 to 5 are a roadmap
(section 10).

E5 slice 1 is done when:

1. **Days 1 to 7 at tier 1 are today's game.** Rows 1 to 7 of the planner sweep for seeds 20260930, 11 and 777 are
   byte-identical to `tests/sim/baseline/`; rows 8 to 14 change (the tier-1 cap) and the baseline is re-recorded once,
   with the diff explained in the PR (section 8.3).
2. A schema 4 save loads at tier 1 with its day and buildings intact; a save past day 7 then faces day-7 pressure
   (accepted, section 6.3).
3. The tier sign takes gold by standing still, like a pad; a full payment makes the coming night a boss night; a won
   boss night makes the next dawn tier 2: yards, `tower_w` and `tower_e`, hares in the waves, the tier-2 pressure ramp.
4. A lost boss night retries through the existing fail flow with the payment kept and the boss still pending.
5. Sims on seed 20260930 (section 8.1): the tier bot wins the boss night from the fixture within 2 retries (the
   actual count is printed); the boss alone needs at least `boss_min_hold_s` (15 s) to fell the diner from the moment
   it reaches it; the tier bot holds the first tier-2 night with no retry; a full tier-2 build clears the tier-2 cap
   with 0 retries on all three sweep seeds.
6. Sweep targets (section 8.2) hold on seeds 20260930, 1 and 2: the planner clears days 1 to 14 with 0 retries; the
   tier bot's first failed night is its boss night or later; tier-2 nights 1 to 3 need at most 1 retry; the tier bot's
   unspent gold at close-up on day 14 is lower than the planner's.
7. Perf (section 8.4): the `tier2_night` and `boss_night` fixtures read within the D-199 spread of the D-221 night
   reading, worst frame no worse than 106 ms.
8. Unit, sim and CI green, every task reviewed, the sim suite inside its budget (section 8.5 brings the budget
   decision to the author).

## 2. Scope

**In:**
- `TierBalance`, `MonsterBalance`; `WaveMath.pressure`; per-kind monster stats and target priorities.
- Tier state in GameState, the tier sign, the boss night, the tier-up dawn, save schema 5.
- `MapLayout` tier spots and yards; `WaypointGraph.create_for_tier`; the yard towers.
- The hare (fast monster) and the Boar King (boss), procedural; the tier-2 diner mesh; the yards; the boss moon.
- `TierBot`, four sims, the `--bot=tier` sweep, two perf fixtures, the baseline re-record.
- IDEA.md, DECISIONS.md (D-222 amendment), REVIEW_QUEUE.md updates.

**Out:**
- Tiers 3 to 5 (roadmap only), staff, new equipment, a second map, a second branch.
- Any change to mercy, to the Guide, to the card pool, to the tier-1 planner bot.
- Hero HP (D-161 stands). The boss threatens the diner, never the player.
- A reset or "new game plus". Nothing built is ever lost.

## 3. Player flow

**Tier 1 (today).** Nothing changes until day 7. From day 8 the nights stop growing. A new sign stands on the west
yard's edge: `tr("Open the yards")` over the cost (500). It pulses with the Close-up sign's rule: an affordable tier-up
counts as a purchase, so the Close-up sign does not pulse while the tier is affordable.

**Paying.** Standing still on the tier sign drains gold at the build spots' rate; the ring shows paid / cost; a
partial payment stays and is saved. When the payment completes, the label reads `tr("Boss tonight")`, the sparkle and
build sound play, and the autosave writes. Nothing else changes until the night.

**Boss night.** The player closes up as usual. The night-start banner reads `tr("The Boar King comes")`. The night
runs at the tier's capped pressure (today's day 7). Wave 3's main lane carries the boss: it spawns first, alone, and the
wave's regular monsters follow `boss_lead` (3.0 s) later. The edge arrow and telegraph flag mark that lane as today; the
flag scales with the wave's threat, so it is the night's biggest. The third moon is a boss moon (section 7.4). The boss
walks at 1.2 m/s (about 20 s up the lane), stops at a standing fence and breaks it by raw damage, then hits the diner
for 15 every second. A world HP bar hangs over it. It dies into a large scatter of steaks (100).

**Lost boss night.** The diner fell banner, the flavour line, back to the day before: the payment is kept, the sign
still says `tr("Boss tonight")`, the player may build more and close up again. Mercy weakens the boss and the waves as
today. No refund.

**The tier-up dawn.** Steaks to the freezer (the boss drop included), heal, destroyed fences gone, day advances, then
`complete_tier_up`: tier 2, the yards and both yard spots exist, the save is written. Then the reveal (visual, section
7.5): banner `tr("The diner grows!")`, a camera pull-back, the west yard, its stones and awning pop in, then the east,
then the yard spot markers; the card pick opens `tier_reveal_time` (3.0 s) later. If the tab closes mid-reveal, resume
shows the yards already there and opens the card pick; nothing replays.

**Tier 2.** Day pressure starts at today's day 8 and ramps to day 11 over 3 nights, then stops. Hares join every wave:
few on the first night, more each night. Two more towers to build (280 gold each to L3). The tier sign hides: no
tier 3 exists in this slice (section 11, known gap).

## 4. Difficulty: pressure, mix, boss

### 4.1 Pressure (replaces the day in every wave formula)

`WaveMath.pressure(day, tier, tier_day, tb) -> int`:

```
pressure = clamp(tier_base[tier] + (day - tier_day), tier_base[tier], tier_cap[tier])
```

`tier_day` is the day the tier was entered (1 for tier 1). Every `WaveMath` function (`raw_total`, `total_count`,
`hp_mult`, `side_share`, `split`) takes the pressure where it took the day; `LanePlanner.plan(run_seed, day, pressure,
wb, tb, tier)` passes it. `max_wave_size` (30) and the side-share curve are unchanged. Tier 1: base 1, cap 7; days 1
to 7 are byte-identical to today, days 8 and later sit at day-7 pressure.

| Tier | base | cap | First-night kills | Cap kills | Cap gold per night |
|---|---|---|---|---|---|
| 1 | 1 | 7 | 18 | 12 + 19 + 25 = 56 | 336 |
| 2 | 8 | 11 | 14 + 21 + 28 = 63 | 18 + 27 + 30 = 75 | 450 |

Gold = kills × `steaks_per_kill` (2 for boars and hares) × 3 (`gold_per_steak`, no cards). Tier 2 pays 34% more per
night than tier 1; the boss night pays 336 + 300 (the drop) = 636.

### 4.2 Monster mix

Each lane-plan wave gains `fast_main` and `fast_side`: how many of `main_count` and `side_count` spawn as hares.
`fast = round(count × fast_share_now)`, with `fast_share_now = lerp(fast_share_start[tier], fast_share[tier],
min(1, (day - tier_day) / fast_ramp_days[tier]))`. Tier 1: both shares 0. Tier 2: start 0.15, cap 0.35, ramp 3 days.
No RNG: in `WaveSchedule.build` the last `fast_main` entries of the main group and the last `fast_side` of the side group
are hares, so they spawn behind the boars and overtake them (the player sees "the fast ones slip past"). The tier-1
schedule and RNG call order do not change.

Boss night: the plan's wave 3 carries `boss: true`; `WaveSchedule.build` prepends one `boss` entry at `t = 0` on the
main lane and shifts the rest by `boss_lead`. `WaveSchedule.is_cleared` counts it like any spawn.

### 4.3 Kinds

`MonsterBalance` (`balance/monster_balance.gd`), one `MonsterStats` per kind, index by `MonsterBalance.KINDS =
[&"boar", &"hare", &"boss"]`. Boar values are today's `EnemyBalance` values (that resource is folded into the boar
entry; `lateral_spread`, `drop_scatter`, `offset_fade_distance` stay shared):

| Kind | hp | speed | damage | interval | reach | steaks_per_kill | priority | scatter |
|---|---|---|---|---|---|---|---|---|
| boar | 30 | 2.0 | 5 | 1.0 | 1.2 | 2 | fence_on_lane, guard, diner | 0.6 |
| hare | 15 | 3.6 | 4 | 1.0 | 1.2 | 2 | guard, diner | 0.6 |
| boss | 800 | 1.2 | 15 | 1.0 | 1.6 | 100 | fence_on_lane, guard, diner | 2.5 |

Every monster's HP and damage take the wave's `hp_mult` and `GameState.mercy_factor()` as today. The hare has no
`fence_on_lane` in its list, so under D-148 it walks past a standing fence: not a wall, not a target, no new rule.
`TargetPriority.kinds` moves into `MonsterStats.priority`; `TargetProviders.has_kind(kind, enemy)` and `find_target`
read the enemy's list. `WaveBalance.target_priority` is removed.

**Boss by hand.** At the tier-1 cap `hp_mult` = 1 + 0.15 × 6 = 1.9, so the boss has 1,520 HP. The `boss_night_tier1`
fixture's defense on one target: hero 10 / 0.5 s = 20 dps (more with damage cards), tower L3 18 / 0.5 s = 36 dps each,
Archer L1 4.0 / 0.6 s = 6.7 dps, Tank L1 5 / 0.8 s = 6.25 dps in melee. North lane (both towers): about 99 dps, boss
dead in about 15 s once in range, so it reaches the diner with roughly 40% HP after its 16 s lane walk under fire and
hits the diner about 6 times (90 HP) with no fence. West or east lane (one tower): about 69 dps, 22 s; a L3 fence
(320 HP) holds it 21 s and the diner another 20 s. So the number is winnable with a maxed tier-1 defense and lost by a
parked player. Boss alone, no defense: 300 / 15 = 20 s from reaching the diner to the fall; `boss_min_hold_s` (15 s) is
the sim floor. All of this is tuned by the sims (D-103: 3 rounds, then escalate).

### 4.4 Balance resources

`balance/tier_balance.gd`, `class_name TierBalance`, exported on `BalanceData` as `tiers`. Index = tier; index 0 unused
(tiers count from 1). Every array has `tier_costs.size() + 1` entries so tier `tier_costs.size()` (the top) has a
cap:

```gdscript
@export var tier_costs: Array[int] = [0, 500]            # cost to reach tier index + 1; tier_costs[1] = tier 2
@export var tier_base: Array[int] = [0, 1, 8]
@export var tier_cap: Array[int] = [0, 7, 11]
@export var fast_share_start: Array[float] = [0.0, 0.0, 0.15]
@export var fast_share: Array[float] = [0.0, 0.0, 0.35]
@export var fast_ramp_days: Array[int] = [0, 1, 3]
@export var boss_lead := 3.0
@export var boss_min_hold_s := 15.0
@export var tier_reveal_time := 3.0        # dawn: seconds before the card pick on a tier-up dawn
@export var max_tier := 5                  # the ladder's length; the sign hides above tier_costs.size()
```

`TierEffects` (`core/tier_effects.gd`, pure): `top_tier(tb) = tier_costs.size()` (the highest tier this build can
reach; 2 here), `tier_cost(tier, tb) -> int` (−1 at or above the top), `fast_share_now(day, tier, tier_day, tb)`,
`fast_counts(main, side, share) -> Dictionary`. A unit test checks every array length and that
`tier_base[t] <= tier_cap[t] < tier_base[t + 1]`.

## 5. Map

### 5.1 MapLayout

Every existing constant is unchanged (`BOUNDS`, `LANE_PATHS`, `SPOT_IDS`, `TOWER_SPOTS` entries, `TOWER_LANES`
entries, zones, stations, pads). Additions, drafts fixed by the tests of 5.3:

```gdscript
const TIER_SPOTS := {2: ["tower_w", "tower_e"]}        # spots a tier unlocks; appended to spots_for_tier
TOWER_SPOTS += {"tower_w": Vector2(-10.6, 0.6), "tower_e": Vector2(8.8, 1.1)}   # final (tests moved the drafts)
TOWER_LANES += {"tower_w": ["west"], "tower_e": ["east"]}
const YARDS := {"west": Rect2(-13.5, -2.5, 4.5, 10.5), "east": Rect2(8.0, -0.5, 5.0, 3.5)}   # final
const YARD_TIER := {"west": 2, "east": 2}
const TIER_SIGN := Vector2(-10.0, 7.5)                   # on the west yard: the sign stands on the next land
const ALL_SPOT_IDS: Array[String]                        # SPOT_IDS + every TIER_SPOTS list, in tier order
static func spots_for_tier(tier: int) -> Array[String]
static func yards_for_tier(tier: int) -> Array[String]
static func spot_tier(spot_id: String) -> int             # 1 for SPOT_IDS
```

`SPOT_IDS` stays the tier-1 list, so every test that pins it passes. `GameState.buildings` holds `spots_for_tier(tier)`;
`SaveCodec.validate`, `World._build_spots`, `Pulse`, `GuideRules`' spots array (unchanged in content at tier 1) and the
bots iterate `buildings.keys()` or `spots_for_tier`, never `SPOT_IDS`, except the planner bot, which stays tier-1 only
and keeps `SPOT_IDS`.

The coordinates above are the final ones (D-240); the tests of 5.3 moved the drafts. The east yard is small
(5.0 x 3.5 m) because the props near the diner and the 3 m prop rule left that much room for `tower_e`, and it stays
clear of the freezer pad (7.9, 7.0, radius 1.2). The west yard's inner edge is x = -9.0, so its north-inner corner
clears the west lane by about 2.2 m. The yards do not mirror each other.

### 5.2 WaypointGraph

`create_default()` is frozen (D-230) and pinned. New `create_for_tier(tier) -> WaypointGraph`: the default graph plus,
for tier 2, nodes `tier_sign` (`TIER_SIGN`), `tower_w` (its spot + (−0.75, 0.75)), `tower_e` (+ (0.75, 0.75)) and
edges `sw`–`tier_sign`, `sw`–`tower_w`, `se`–`tower_e`, `zone_west`–`tower_w`, `zone_east`–`tower_e`. `TierBot` and
`UpgraderBot` keep their own copies; `BotBase.graph` stays the default.

### 5.3 Pinned by tests (`tests/unit/test_tier_layout.gd`), not by this spec

- Each yard rectangle and each yard tower spot keep at least `lateral_spread` + 1.0 m (2.0 m) from every lane path
  segment and from every enemy stop point sampled as in geometry test D.
- Yards and the tier sign's zone (radius `STATION_RADIUS`) overlap none of: station zones, build spots (`BUILD_RADIUS`),
  station pads, queue slots, `HOME`, `NIGHT1_START`, `SIGN`, the gold pile's `magnet_radius`, the Tank post, every
  segment of `tank_return_path()`, the diner, counter and freezer bodies grown by `HERO_RADIUS`.
- The tier sign and the yard spots are more than 3.0 m from every prop (`test_props_layout.gd`'s rule).
- Camera: both yard spots, the tier sign and its label are on screen at 9:16 (`CameraMath.on_screen`) with the hero
  at the spot's or sign's stand point.
- Each yard tower reaches its lane's whole zone rectangle and its fence spot at L1 range (geometry tests B and C
  extended to `ALL_SPOT_IDS`); geometry tests D and E re-run with the new spots.
- `create_default()` is unchanged (node and edge pin, `test_station_layout.gd`); `create_for_tier(1)` equals it;
  `create_for_tier(2)`'s new edges clear every collider.

## 6. State and save

### 6.1 GameState

```gdscript
var tier := 1
var tier_day := 1           # the day the tier was entered
var tier_paid := 0          # partial payment on the tier sign
var boss_pending := false   # paid in full; the coming night is a boss night

func tier_next_cost() -> int          # -1 at the top tier
func tier_remaining_cost() -> int     # -1 at the top tier
func pay_into_tier(amount: int) -> int
func complete_tier_up() -> void       # dawn after a won boss night
func debug_set_tier(tier: int, day_entered: int) -> void   # tests, sims, fixtures
func pressure() -> int                # WaveMath.pressure(day, tier, tier_day, Balance.data.tiers)
```

- `pay_into_tier` uses `_pay_towards` on `{"paid": tier_paid}`; it takes at most the gold held and the remaining cost,
  emits `gold_changed`, then `tier_changed(tier, tier_paid, boss_pending)`; when the payment completes it sets
  `boss_pending = true`, `tier_paid = 0`, and emits `tier_changed` then `tier_paid_up(tier + 1)`. Paying while
  `boss_pending`, at night or at the top tier does nothing.
- `complete_tier_up`: asserts `boss_pending`; `tier += 1`, `tier_day = day`, `boss_pending = false`; adds every spot of
  `TIER_SPOTS[tier]` to `buildings` at `{level 0, paid 0, hp 0}`; emits `building_changed` for each new spot, then
  `tier_reached(tier)`. Called by `PhaseController._run_dawn` after `advance_day` (so the new day's plan uses the new
  pressure) and before the card pick.
- `new_game`: tier 1, tier_day 1, tier_paid 0, boss_pending false; `buildings` = `spots_for_tier(1)`.
- `advance_day` plans with `pressure()` and the tier (`LanePlanner.plan` signature above). The plan carries
  `fast_main`, `fast_side` and `boss` per wave.
- Snapshots carry the four fields; `lane_plan` entries carry the three new keys.

### 6.2 EventBus

`tier_changed(tier: int, paid: int, boss_pending: bool)` (the sign, the pulse, the autosave's dirty mark),
`tier_paid_up(next_tier: int)` (sound, sparkle, autosave write), `tier_reached(tier: int)` (World, HUD, sound,
autosave). Boss spawn and death reuse `wave_started` and `enemy_killed`; `enemy_killed` gains a `kind: StringName`
argument so the HUD boss moon and the sweep can tell the boss apart.

### 6.3 Save schema 5

- `SCHEMA_VERSION` 5. `STATE_KEYS` gains `tier`, `tier_day`, `tier_paid`, `boss_pending`.
- Built-in 4 to 5 step (`SaveCodec._built_in`): adds `tier 1, tier_day 1, tier_paid 0, boss_pending false`, adds
  `fast_main 0, fast_side 0, boss false` to every lane-plan wave, sets `v` 5. `buildings` keeps its 5 spots.
- Validation: `tier` in `[1, max_tier]`, `tier_day` in `[1, day]`, `tier_paid >= 0` (clamped to `cost - 1` on load,
  D-231; 0 when `boss_pending` or at the top), `boss_pending` bool; every spot id in `ALL_SPOT_IDS`; every spot of
  `spots_for_tier(tier)` present (a tier-2 save without `tower_w` is "missing building"); a spot above the save's tier
  is rejected ("building tier"); each wave has the three new keys with `fast_main <= main_count`, `fast_side <=
  side_count`, `boss` bool; `boss` may be true only in the last wave (it is not tied to `boss_pending`: the plan is
  re-made at dawn, and a `boss_only` fixture carries it without a payment).
- **A tier above `top_tier(tb)` is clamped on load, not rejected** (the same rule as D-234): a save from a later build
  that reached tier 3 loads at the top tier this build knows, keeping its buildings; `complete_tier_up` is then a no-op
  at the top. A spot whose tier is above the top this build knows is rejected ("building tier <id>"), and an id the
  build does not know at all is rejected ("building <id>"): there is nothing to place either on.
- **Accepted effect:** a tier-1 save past day 7 faces day-7 pressure after the update (its old `lane_plan` is used for
  one night as saved, then `advance_day` re-plans at the cap). The `export/fixtures/*.save.json` stay at schema 3 and 4
  and prove the chain 3 → 4 → 5.

### 6.4 Phase flow

- `close_up` snapshots as today; the snapshot carries `boss_pending`, so a lost boss night restores to the day with
  the payment kept and the boss pending. `_enter_night` emits `banner_requested(tr("The Boar King comes"))` when
  `boss_pending` (after the phase change, so the HUD moons are set first).
- `_run_dawn`: steps 1 to 4 as today, then `if was_boss_night: GameState.complete_tier_up()`, then the card pick,
  delayed by `tier_reveal_time` on a tier-up dawn (a physics-time timer, D-118, cancelled by `_fail_id` like the fail
  timer). `was_boss_night` is read from `GameState.boss_pending` at the start of the dawn step.
- Resume during the reveal: `resume_phase` is `CARD_PICK` or `DAY` (the autosave at dawn wrote the tier-2 state), so
  resume shows tier 2 and opens the card pick at once. No reveal replays.

## 7. World, UI, art

### 7.1 Monsters (one scene, one pool, one shader)

- `Boar` (class name kept; the comment says it is every monster) gains `kind: StringName` set in `spawn(lane, index,
  offset, hp_mult, director, kind)`; it reads `Balance.data.monsters.stats(kind)` for speed, damage, interval, reach
  and priority; `health.reset(stats.hp × hp_mult)`. The pool holds `Boar`s; the factory is unchanged.
- `BoarVisual` takes a `kind` and rebuilds its mesh from `BoarMesh` with a per-kind parameter table (D-192's builder
  grows a `params(kind)` function): hare 0.7 m tall and lean, long ears, `enemy_snout` body with `enemy_red` ears,
  hop 0.05 m at 6 Hz; boss 2.2 m tall, `enemy_maroon` with the D-192 lerp, four bone tusks (`apron_white` is banned:
  the tusks are `stone`), hop 0.12 m at 2 Hz, attack lunge 0.5 m. The visual is rebuilt only when the kind changes
  between spawns (a pooled Boar usually keeps its kind). Scale table additions: hare 0.7 m, boss 2.2 m tall, 3.2 m
  long (`docs/ART_BIBLE.md` section 5; `ArtBudgets["res://art/boar"]` stays 1500 triangles per monster).
- Boss HP bar: the Guard's bar pattern (`_bar_box`, `guard_green` fill on `ink`), `enemy_red` fill, 1.6 m wide at
  2.6 m; shown while the boss lives; 2 draws.
- Death: every kind squashes and pops as today; the boss's scatter radius is 2.5 m. `World.pool_sizes` sizes the enemy
  pool from `max_wave_size + 10` as today (the boss is one more spawn) and the steak pool from the tier-2 capped night
  plus the boss drop: `ceil((kills_at(tier_cap[top]) × 2 + boss steaks) × 1.2)` (about 300). `PickupField` grows with
  it (one draw).
- Dawn: `steak_pool.recall_all()` sweeps the boss steaks into the freezer like any others; a unit test places 100
  ground steaks and asserts `freezer_steaks` gains 100.
- The hero's magnet and carry rules are unchanged: with a full carry the magnet does not pull (today's rule), so 100
  steaks on the ground are only a visual density question, checked in the device shots.

### 7.2 Tier sign

`world/stations/tier_sign.gd`, `class_name TierSign`: a `StationZone` (radius `STATION_RADIUS`, `drive_ring = false`),
the build-spot ring marker, a `WorldLabel` with the state text, the post model from `closeup_sign.tscn` with a
`diner_cream` board (`art/env/tier_sign.tscn`, kitbash of the existing sign source, baked). It pays through
`GameState.pay_into_tier` at `Economy.drain_per_tick(cost, build)`, uses `PayFx` for coins and dust, refreshes on
`tier_changed`, `phase_changed`, `state_restored`, `tier_reached`. Label: `tr("Open the yards")` + cost; while paying
the ring shows paid / cost; `tr("Boss tonight")` when `boss_pending`; hidden at night and when `tier_next_cost() < 0`.
The sign and its label are created by `World` only when `MapLayout.TIER_SIGN` has a tier to sell; at the top tier the
node exists but is hidden (so a later tier can show it without a scene change).

### 7.3 Yards, yard spots, the tier-2 diner

- `World` builds the ground from `GroundArt.terrain_mesh(rect, yards)`: yard rectangles are `dirt` cells with a
  `dirt_dark` hash variation inside the merged mesh. The ground is rebuilt once on `tier_reached` and on
  `state_restored` when the yard set changed (a node swap, visual only, under the boot fade on resume).
- Yard ring: Kenney `rocks-small` instances along each yard's outline, one MultiMesh with `LaneStrip.edge_stones`'
  pattern, no collision. The wooden fence model is not used (it reads as a defense).
- Yard spots: `TowerSpot` nodes created by `World._build_spots` for `spots_for_tier(tier)` at build time and added on
  `tier_reached`; the planner's `next_purchase` never sees them (tier 1 only).
- The diner: a second baked mesh `art/env/baked/diner_t2.res` from `art/env/src/diner_t2_src.tscn`: today's diner plus
  an awning (`detail-awning-wide`) on each flank and a `diner_cream` terrace strip along the east and west walls inside
  the yards' edge. `World._build_diner` instances the mesh for the current tier and swaps it on `tier_reached`; the
  collision box, `occluder_boxes` and the DINER board do not change, so the fade and camera rules hold. 0 extra draws.
- Camera: `CameraMath.FOCUS_MIN`/`FOCUS_MAX` (−17..17, −20..8) already contain the yards and the sign; the ground margin
  test and the lane-visibility test are unchanged; a test checks each yard's corners are inside `ground_rect()` and
  inside `BOUNDS` (the yards are inside today's bounds: x ≤ 13.5 < 24).
- HUD: unchanged layout; everything new is in the world.

### 7.4 HUD boss moon

`HudIcons` draws the third moon on a boss night (`GameState.lane_plan[2].boss`) 1.3× larger in `enemy_red`, with a
`Pulse`-rate breath (visual, `_process`) while the boss lives (`wave_started(2)` to `enemy_killed(…, &"boss")`); it fills
on `wave_cleared(2)` as today. A unit test pins the colour and scale; the moon count stays `lane_plan.size()` (3).

### 7.5 The reveal (visual, D-214 style: existing tools only)

Owner: `world/tier_reveal.gd`, `class_name TierReveal`, a World child listening to `tier_reached`. Sequence, all tweens
in physics process mode and killed on `state_restored`:

1. `banner_requested(tr("The diner grows!"))`.
2. `CameraRig.reveal(seconds, zoom)`: `camera_distance × tier_reveal_zoom` (1.25) eased out over 0.6 s and back over
   0.8 s, in `_process`, cancelled by `_on_state_restored` like a shake. Visual only; `CameraMath` is unchanged.
3. 0.35 s apart: west yard ground (the swapped ground mesh pops from 0.98 to 1.0 scale, `PopFx`), west stones, the
   tier-2 diner mesh swap with a pop, east yard, east stones, then both yard spot markers; each step plays the build
   sound (`sfx_requested(&"build")`) and a dust puff at its centre.
4. The card pick opens after `tier_reveal_time` (PhaseController, section 6.4).

### 7.6 Audio and feel

Reuse: `build` sound and sparkle on `tier_paid_up` and on each reveal step; `hit` and death as other monsters; the boss
gets no new sound in this slice (REVIEW_QUEUE). `Autosave` writes on `tier_paid_up` and `tier_reached`, marks dirty on
`tier_changed`.

### 7.7 Guide and pulse

`GuideRules` is unchanged: its rules run only on night 1 and day 2, and the tier sign is never affordable then. `Guide`
passes a spots-only, tier-1 pulse value as it does for stations (E1 5.4). `Pulse.should_pulse` treats an affordable
tier-up (`tier_remaining_cost` in `(0, gold]`) as an affordable purchase; a state without the tier keys means not
affordable (the existing fixtures keep their meaning).

## 8. Bots, sims, sweep, perf, budget

### 8.1 Bots and sims

- `PlannerBot`, `NaiveBot`, `GuideBot`, `UpgraderBot`: unchanged; tier 1 only. `UpgraderBot` stays the E1 bot.
- `TierBot` extends `UpgraderBot`: at the planner's "no purchase left for tonight" point it buys, in order, the tier-up
  when `tier_remaining_cost() <= gold`, then yard towers by threat (the planner's scoring over `buildings.keys()`),
  then station levels, then closes up. Graph: `WaypointGraph.create_for_tier(GameState.tier)`, rebuilt on
  `tier_reached`.
- Fixtures (`tests/sim/make_save.gd --fixture=…`, schema 5, seed 20260930, written from a `TierBot` run and edited by
  `debug_set_*`):
  - `boss_night_tier1`: `resume_phase` NIGHT, day 12 (the day the tier bot's boss night falls on), tier 1,
    `boss_pending`, the tier bot's own defense (every tower and fence at level 3) and
    stations, Tank and Archer, `night_fails` 0.
  - `boss_only`: the same day, no builds, no guards, `lane_plan` with `main_count 0`, `side_count 0` in waves 1 and 2
    and `boss` only in wave 3 (an explicitly constructed plan; `validate` allows zero counts).
  - `tier2_night1`: `resume_phase` NIGHT, day 13, tier 2 entered day 13, yards open, yard towers at level 0.
  - `tier2_full`: tier 2, day 16 with `tier_day` 13 (pressure at cap), every tower and fence at L3 including the yards, stations as the
    tier sweep has them at that day, Tank and Archer at the sweep's levels.
- Sims (`tests/sim/test_tier_sims.gd`, one night each):
  1. `boss_night_tier1` + `TierBot`: wins within 2 retries; prints `boss night won after N retries`.
  2. `boss_only` + `ParkedBot`: from the first `diner_damaged` by the boss to `diner_fell` at least `boss_min_hold_s`
     (15 s); prints the measured seconds. (With regular waves a parked diner falls to the boars first, so the boss is
     isolated.)
  3. `tier2_night1` + `TierBot`: holds with 0 retries.
  4. `tier2_full` + `NaiveBot` at night, seeds 20260930, 1 and 2: clears the tier-2 cap with 0 retries on each. If it
     fails, `tier_cap[2]` is lowered, never leaned on mercy (D-103 rounds).
- Unit: a hare walks past a standing L3 fence and reaches the diner while a boar on the same lane stops; hares take
  `hp_mult` and mercy; the boss entry is first in the wave-3 schedule and the rest start at `boss_lead`; pressure pins
  (day 7 and 8 at tier 1 both give 7; tier 2 day 9 to 13 gives 8, 9, 10, 11, 11); `fast_counts` at tier 2 nights 1 to 4.

### 8.2 Sweep

`sweep.gd` takes `--bot=tier` and writes `tests/sim/out/sweep_tier.csv` with the upgrader columns plus `tier`,
`boss_night` (0/1) and `boss_retries`; `--days=20` is supported (the tier bot needs days at the tier-2 cap). The
planner CSV columns are unchanged. Retired: `break_day_target 10 ± 1` (`SimThresholds` fields removed; the `SWEEP`
line prints `first_fail_day` and `hard_break_day` without a target). New targets, reported by the `SWEEP` line and
checked by the author's reading (CI does not run the sweep):

| Target | Seeds | Rule |
|---|---|---|
| Planner at tier 1 | 20260930, 1, 2 | Clears days 1 to 14 with 0 retries |
| Tier bot first failure | 20260930, 1, 2 | Its first failed night is its boss night or later |
| Tier-2 ramp | 20260930, 1, 2 | Tier-2 nights 1 to 3 need at most 1 retry each |
| Gold sink | 20260930, 1, 2 | `unspent_gold_at_closeup` on day 14, tier bot < planner (printed in the spec's results) |
| Hold the cap | 20260930, 1, 2 (20 days) | The tier bot at a full tier-2 build clears every cap night with 0 retries |

### 8.3 Baseline re-record (authorized, D-237)

`tests/sim/baseline/s4_sweep_<seed>.csv|.txt` are re-recorded once, in their own task, from the planner sweep at the
head of the E5 branch. The PR shows: `diff` of each CSV restricted to rows 1 to 7 is empty (a `tools/baseline_rows.sh`
helper prints it); rows 8 to 14 differ only in the columns the cap changes (`enemy_count`, kills, steaks, gold,
retries, `diner_frac`, `night_seconds`, `day_seconds`, `unspent_gold_at_closeup`, `guard_knockouts`); the `.txt` `SWEEP` lines lose the target. `tools/baseline_diff.sh` keeps
working against the new files; its header comment changes from "never re-record" to "re-recorded once for E5
(D-237); rows 1 to 7 are the tier-1 identity".

### 8.4 Perf

`make_save.gd` also writes `export/fixtures/tier2_night.save.json` (tier 2 at the cap, yard towers L3, `resume_phase`
NIGHT) and `boss_night.save.json` (the `boss_night_tier1` state). `export/perf_night3.sh` already takes a fixture
name. Protocol D-199 (median of 3, Mac idle), gate: average fps within the ±1 spread of D-221's 59.9, worst frame no
worse than 106 ms; draw calls recorded (expected: night 36 + up to 2 for the boss bar + 1 for the stones). Load time
and memory with the bigger steak pool are recorded next to D-235's readings (no gate; memory still has no tool).

### 8.5 Sim budget (decision for the author)

Today 35 s of 60 s on CI. This slice adds four nights, about 15 to 20 s, so tiers 3 to 5 will not fit under one 60 s
job. Nothing is trimmed (D-132). Proposal, applied only after the author's decision because it changes CLAUDE.md and
the required checks:

- Split the sim tests into `tests/sim/` (today's) and `tests/sim_tier/` (E5 and later tiers). `run_tests.sh` gains
  `sim-tier` with its own 60 s budget line (`SIM-TIER SUITE: Ns (budget 60s)`); `all` runs both.
- CI gets a third parallel job `sim-tier`; branch protection requires it next to `unit`, `sim` and `deploy`.
- `./run_tests.sh --quick` is unchanged. The per-job budget stays 60 s; `tests/sim_tier/` is where tiers 3 to 5 add
  their nights, and a fourth job is the next step if that one fills.

Until decided, E5's sims go into `tests/sim/` and the plan has a task that moves them if the author says yes.

## 9. Error handling

- The sign never takes more gold than held or than the remaining cost; paying at night, when `boss_pending`, or at the
  top tier does nothing.
- `complete_tier_up` without `boss_pending` is an assert; at the top tier it is a no-op (a clamped save).
- A boss spawn when the enemy pool is empty grows it (today's `grew` path), reported by the pool test; the sizes above
  make it unreachable.
- A `kind` outside `MonsterBalance.KINDS` is an assert at spawn.
- A lane-plan wave with `boss` outside the last wave is rejected by `validate`.
- The reveal is interrupted by a restore (tween kill, camera reset) exactly like a shake; the state is already saved.

## 10. Roadmap: tiers 3 to 5 (each a later spec)

| Tier | Unlocks | Monsters | Slots this slice leaves for it |
|---|---|---|---|
| 3 | A 4th lane, tower and fence branching at L3 | A big fence-breaker (reach beyond fences, high fence damage) | `tier_base[3]`, `tier_cap[3]`, `fast_*[3]`, `TIER_SPOTS[3]`, `YARDS` with `YARD_TIER 3`, a `MonsterStats` kind, a sign position on the new land |
| 4 | Passive equipment, a seller at the counter (E2, D-233) | Bigger waves, two side lanes at once | The same slots; `LanePlanner` gains a second side lane; E3 equipment spots use `TIER_SPOTS` with a new spot kind |
| 5 | A 5th lane, a hauler from the freezer (E2) | All kinds mixed, the final boss | The same; a `boss` per tier becomes `boss_kind[tier]` in `TierBalance` |

Rules carried forward: the sign stands on the next piece of land; a full build for a tier always holds that tier's cap
with 0 retries (sim 4's rule, per tier); every tier's cap is a balance value; tier 1 identity (rows 1 to 7) is never
touched again. **Open question for the tier-3 spec, not solved here:** a south-west 4th lane runs through the traveler
road (z = 11), the queue and the diner's service side; the lane set, `LanePlanner.LANES`, the HUD arrows and the
traveler route have to be designed together.

## 11. Known gap and risks

- **Tier 2 is the top in this slice.** The sign hides at tier 2, so gold piles up again at the cap (450 a night).
  Sinks left: the two yard towers (280 each to L3, 560) and unfinished station levels (up to 1,705 from level 0). That
  is 1 to 5 days of spending before the E1 problem returns at a higher tier. Accepted by the author for the slice;
  tier 3 removes it. Logged as D-245 and REVIEW_QUEUE.
- **Boss tuning** may need rounds: the hand numbers in 4.3 are the starting point; D-103 applies (3 rounds, then
  escalate with the sim prints).
- **Hare and fences:** a side-lane hare share makes fences worth less on that lane; the first tier-2 night's share is
  small (0.15) so the night teaches before it punishes. If sim 3 fails, lower `fast_share_start` first.
- **Steak density:** 100 steaks in a 2.5 m ring may hide the boss's death spot and the hero; the device shot decides;
  fallback is a wider `scatter` (balance). The dawn sweep guarantees nothing is lost.
- **Day perf** is already at the E1 known issue. This slice adds, on every day, the tier sign (a mesh, a label, a
  marker and a stand-still zone), and at tier 2 the yard stones (1 draw) and two tower spots with their labels.
  Not measured (section 16).
- **Baseline re-record** is a one-time trust event; the row 1 to 7 proof is the guard against hiding an accidental
  change inside it.

## 12. Updates to other documents

**IDEA.md.** Core loop, day: "spend it on towers, fences, station upgrades (D-222) and the diner tier (E5)". New
section "Diner tiers" before "Hero cards": five tiers, tier 1 is the first game, difficulty follows the tier, pay on
the sign, boss night, the diner grows, tier 5 is the long-term goal, nothing is ever lost. "Later" loses "bosses".

**DECISIONS.md** (new entries, dated 2026-10-06, "E5 tier ladder (brainstorm with the author)"):

- **D-236 The diner tier is the progression spine (author; amends D-222 and D-233).** Five tiers; tier 1 is today's
  game; difficulty follows the tier (a small per-day ramp to a per-tier cap in `balance/`), not the day; income only
  from kills; tier-up = pay on a sign, win the boss night, the diner grows next dawn; permanent, no reset; mercy
  unchanged and hidden; one thumb. D-222's E2, E3, E4 are no longer independent expansions ordered by the playtest:
  they are content unlocked by tier (E4 land and spots from tier 2, E2 seller at tier 4 and hauler at tier 5, E3
  equipment at tier 4). D-232's "the playtest decides the order of E3 and E4" is void. Slice 1 = the tier system plus
  tier 2.
- **D-237 Tier-1 cap at day 7 and a one-time baseline re-record (author).** Rows 1 to 7 of the planner sweep are the
  tier-1 identity and stay byte-identical; rows 8 to 14 change and the S4 baseline is re-recorded once, with the diff
  explained in the PR. The "sweep CSV identical to today's" rule and the "first fail day 10 ± 1" target are retired;
  the new targets are spec 8.2.
- **D-238 Boss rides wave 3 (author).** A boss night is the tier's capped night plus the boss first in wave 3's main
  group; 3 moons, the third a boss moon; a world HP bar; nothing from the next tier appears before the win; a loss is
  the existing retry with the payment kept; mercy applies; the boss drops a night's worth of steaks, swept to the
  freezer at dawn like any others.
- **D-239 Tier 2 unlocks two single-lane yard towers (author).** `tower_w` and `tower_e` on the side yards; towers
  answer the hare, which fences cannot stop.
- **D-240 Yards and the sign are pinned by tests, not by the spec (author).** Clearance from lanes by
  `lateral_spread` + 1 m, from every pad, zone, slot, post and path; on screen at 9:16; the yard ring is stones, not the
  wooden fence model; the tier sign stands on the land it sells.
- **D-241 The hare's share ramps (author).** Small on the first tier-2 night, rising over `fast_ramp_days`, so the
  first night teaches the threat.
- **D-242 Boss tuned for a long readable fight (author).** From the boss reaching the diner, at least 15 s to save the
  night, sim-checked on a boss-only fixture; HP high, damage per hit low.
- **D-243 The tier-up dawn is the game's biggest moment (author).** Banner, camera pull-back, yards and awnings popping
  in one after another, then the card pick; all visual on top of the saved state; no replay on resume.
- **D-244 Sim criteria for tiers.** A full build for a tier always holds that tier's cap with 0 retries, on three
  seeds; the planner never tiers up; the tier bot's unspent gold on day 14 is below the planner's.
- **D-245 Known gap: tier 2 is the top of slice 1 (author).** The sign hides at tier 2 and gold piles up again after
  1 to 5 days (yard towers 560, station levels up to 1,705). Accepted; tier 3 removes it.
- **D-246 Procedural hare and Boar King.** No monster models exist in the CC0 packs in use; both are built by the Boar's
  mesh builder and shader (D-192). Reversible; REVIEW_QUEUE.
- **D-247 Sim budget split (pending the author).** Proposal: `tests/sim_tier/`, `run_tests.sh sim-tier`, a third CI
  job and required check, each job 60 s. Recorded when the author answers.

**REVIEW_QUEUE.md**, new section "E5 tier ladder (2026-10-06)": the hare's look and name; the Boar King's look, crown of
stone tusks and HP bar; the boss moon; the yards as dirt with a stone ring, the terrace and flank awnings on the
tier-2 diner; the tier sign's look and texts ("Open the yards", "Boss tonight", "The Boar King comes", "The diner
grows!"); the reveal's timing and camera pull-back; the tier-2 cost 500 against about 336 gold a night; tier 2 being
the top (gold piles up again); no boss sound in this slice. Playtest question: "Did you understand what the sign was
selling, and did the boss night feel like a test you could prepare for?"

**CLAUDE.md:** `MonsterBalance` replaces `EnemyBalance` in the balance list; the sweep line gains `--bot=tier`; the
baseline line reads "re-recorded once for E5 (D-237), rows 1 to 7 are the tier-1 identity"; the sim budget line
changes only if D-247 is accepted.

## 13. Hot files and wiring (D-136, D-139)

`autoload/GameState.gd`, `autoload/EventBus.gd`, `balance/*`, `world/world.gd`, `world/main.gd`, `world/main.tscn`,
`project.godot`, `run_tests.sh`, `.github/workflows/*` are edited by implementers only in tasks where the file is the
task's main purpose; those tasks are serialized. Every other touch (World creating the sign, the yards, the reveal
node, the tier spots; the pool sizes) is a wiring note applied by the main session after review. `main.tscn` does not
change in this slice (no new orchestrated node: `TierReveal` and `TierSign` are World children built in code).

## 14. Testing summary

**Unit:** `TierEffects` and `TierBalance` lengths and ordering; `WaveMath.pressure` pins; `LanePlanner` fast counts and
the boss entry; `WaveSchedule` order; `MonsterBalance` boar values equal today's `EnemyBalance`; hare passes a fence,
boar stops; `GameState` tier payment (partial, complete, capped, night, top tier), `complete_tier_up` adds spots and
emits in order; save 4 → 5 (also after `MIGRATIONS.clear()`), round trip at tier 2, each validation rule, the tier
clamp, the schema 3 and 4 fixtures; `MapLayout` and graph pins of 5.3; `TierSign` states and night hiding; `Pulse`
with an affordable tier; boss moon colour and scale; 100 steaks swept at dawn; the reveal is killed on restore; the
camera `reveal` returns to rest; `Autosave` writes on `tier_paid_up` and `tier_reached`; `TierBot` buys the tier-up
before stations.

**Sim:** section 8.1's four sims; the existing sims unchanged; `tools/baseline_diff.sh` prints `baseline identical`
against the re-recorded files; rows 1 to 7 proven identical to the old files.

**Device:** `export/device_check.sh` on the preview URL: the tier sign, the boss bar and the boss moon readable at
720×1280 on the notch iPhone; the yards and the tier-2 diner visible from `HOME`; 100 steaks on the ground do not hide
the hero (section 11).

## 15. Changes made while planning (2026-10-06)

The implementation plan (`docs/superpowers/plans/2026-10-06-e5-tier-ladder.md`) departs from the text above in these
points; the design and every number are unchanged.

- **`EnemyBalance` and `WaveBalance.target_priority` stay** as the Boar's numbers (about 40 tests read
  `Balance.data.enemy`). `MonsterBalance.stats(&"boar")` is a live view built from them, so each number still has one
  source; the hare and the boss are exported `MonsterStats`. Section 4.3's "that resource is folded" and
  "`WaveBalance.target_priority` is removed" do not apply.
- **`LanePlanner.plan(run_seed, day, wb, tier := 1, tier_day := 1, tb := null)`**: the day stays the second argument
  (the lanes still come from the day's stream) and the pressure is derived inside; `LanePlanner.with_boss(plan)` marks
  the last wave. Section 4.1's signature is replaced by this one.
- **The reveal's camera** eases in over 0.6 s, holds for 1.6 s and eases back over 0.8 s (3.0 s in all); see the
  building changes below for the framing.
- **The sweep** prints `unspent_day14` on the `SWEEP` line and a `TIER` line (`first_tier2_day`, `boss_retries`) in
  tier mode, so the gold criterion and the boss retries are read from the lines, not only the CSV.
- **`SimThresholds.boss_night_max_retries`** (2) holds sim 1's allowance; the retired `break_day_*` fields are removed.
- **The yard stones** are spaced 1.2 m along the outline, scale 0.55, yaw by position hash.
- **Save validation** accepts a `tier` up to `max_tier` and `GameState.from_dict` clamps it to the top this build
  knows; a spot id the build does not know is still rejected ("building"). A tier-2 save on a build that only knows
  tier 1 is therefore rejected, not clamped: the limit of the clamp rule, pinned by a test.
- **TierBalance array length** is `tier_costs.size() + 1` (index 0 unused, tiers 1 to the top = `tier_costs.size()`);
  the first draft said `+ 2`, an off-by-one caught in Task 1 (ruling in the SDD ledger).

### Changes made while building (2026-10-06, D-248 to D-259)

Each line names the section it supersedes.

- **4.3, 7.1 Monster stats are cached at spawn** on the `Boar` (`_stats`), not read per call. The hare is scale 0.6
  (0.72 m tall, 1.02 m long), `enemy_snout` body, two flat `enemy_red` ears laid back; the boss's upper body is the
  D-192 lerp at 0.25, with four `stone` tusks.
- **6.1 Paying the tier in full marks the CURRENT lane plan's last wave with the boss** (`with_boss`), so the night
  that follows the payment is the boss night. `advance_day` keeps the mark while pending; `from_dict` re-applies it.
- **6.1, 6.4 `GameState.stash_card_offer(offer)`** stores the dawn offer without a signal. On a won boss night
  `_run_dawn` draws the offer once, stashes it, calls `complete_tier_up()`, and the autosave on `tier_reached` writes
  `CARD_PICK` (or `DAY` when the offer is empty). A top-tier no-op opens the pick at once.
- **6.3 Validation** also checks the types of the wave keys; the 4 → 5 step ignores a `lane_plan` that is not an array.
- **7.2 The tier sign** is a small procedural sign (cream board, wood posts, a gold star; `tools/make_tier_sign_src.gd`),
  not a kitbash; its label sits at 2.9 m.
- **7.3 The tier-2 diner has no awnings**: the tier-1 diner plus two `diner_cream` terraces, top at y 0.015
  (D-254). Props within 1 m of an open yard are hidden. The world also rebuilds on `tier_changed` when the tier
  differs (so `debug_set_tier` updates it).
- **7.5 The reveal**: `EventBus.camera_reveal_requested(in_s, hold_s, out_s, zoom, focus)`; the camera frames the
  diner and the new yards (zoom fitted at 9:16, 2.15 at tier 2, cap 2.25) and returns to the hero; steps at 0.60,
  0.95, 1.30, 1.65, 2.00 s (dust at the first yard, stones appear, diner pop, dust at the next yard, spot markers
  pop); the reveal ends at `tier_reveal_time`; the ground is never scaled; `CameraMath` gained one pure helper
  (`zoomed_transform`). The sound id is `build_done`.
- **8.1 Bots and sims**: `TierBot.next_purchase()` is the planner's first, then the yard spots; its graph is
  `create_for_tier(2)` from the start. Sim 1 resumes `boss_night_tier1` as DAY and retries through the day. Fixtures:
  `boss_night_tier1`, `boss_only`, `tier2_night1`, `tier2_full`, `tier2_night` (8.4's `boss_night` is
  `boss_night_tier1`).
- **8.2 The sweep** prints `SWEEP first_fail_day hard_break_day unspent_day14` and, in tier mode,
  `TIER first_tier2_day boss_retries cap_nights cap_retries`; `enemy_count` sums the night's plan.
- **8.5 Sim budget: D-247 was applied after the merge.** The suite fitted on the PR runs (27 to 52 s) but failed on
  `main` on slower runners (61 to 71 s, every sim passing). The tier sims now run in a third job (`sim-tiers`), wall
  time warns at 60 s and fails at 150 s, and a per-sim physics-tick budget (`tests/sim_ticks.golden.json`, +20%) is
  the deterministic gate.
- **13 Hot files**: for speed the main session authorized implementers to commit specific hot-file lines in several
  tasks (each named in the task's dispatch) instead of applying uncommitted wiring patches; phases were stacked and
  not merged one by one (D-259).

> **Later change (2026-10-07, D-276):** the tier-2 pressure cap in this document (11; 75 kills and 450 gold on a cap
> night) became 10 (72 kills, 432 gold) after a ten-seed margin study. The numbers below are the slice-1 measurements.

## 16. Results (2026-10-06, starting values, no tuning round)

| Criterion (section 1) | Result |
|---|---|
| 1 Days 1 to 7 are today's game | `tools/baseline_rows.sh 7` → `rows 1-7 identical` on seeds 20260930, 11, 777 after every task from Task 3; baseline rows 8 to 14 re-recorded once (`docs/review/media/e5/baseline/`) |
| 2 Schema 4 save loads at tier 1 | Unit tests; the schema 3 and 4 fixtures load through 3 → 4 → 5 |
| 3, 4 Pay, boss night, tier 2; a lost boss night keeps the payment | Unit tests (`test_boss_night.gd`, `test_tier_sign.gd`, `test_yards.gd`) and sim 1 |
| 5 Sims, seed 20260930 (macOS and Linux CI give the same numbers, digit for digit) | Boss night won after 1 retry (2 allowed), diner 0.193; boss alone 19.0 s (minimum 15); first tier-2 night 0 retries, diner 0.397; full tier-2 build at the cap: 0 retries on 20260930 / 1 / 2, diner 0.037 / 0.59 / 0.933 |
| 6 Sweep targets, seeds 20260930, 1, 2 | All met: planner 0 retries over 14 days; tier bot's first failed night is its boss night (none on seed 2); tier-2 nights 1 to 3: 0 retries; unspent gold on day 14: 223 / 77 / 563 against the planner's 2,276 / 1,620 / 2,736; 5 / 4 / 5 cap nights with 0 retries (`docs/review/media/e5/sweep/README.md`) |
| 7 Perf | Not measured: see the phase-4 PR |
| 8 Suites | Unit and sim green on every phase head, locally and on Linux CI (PRs #50 to #53); sim suite 47 s of 60 on CI (42 s locally) |

Gold per capped night as measured by the sweep's kill counts: tier 1 56 kills (336 gold without cards), tier 2
75 kills (450), boss night 57 kills with the 100-steak drop (636).
