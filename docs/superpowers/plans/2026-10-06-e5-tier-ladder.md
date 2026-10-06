# E5 Diner Tier Ladder (slice 1: tiers 1 and 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Difficulty follows a diner tier with a per-tier cap; the player buys tier 2 on a sign, wins a boss night, and
the next dawn the diner grows (yards, two towers, a fast monster), while days 1 to 7 of tier 1 stay byte-identical to
today.

**Architecture:** A pure `WaveMath.pressure(day, tier, tier_day)` replaces the day in every wave formula. Tier state
(`tier`, `tier_day`, `tier_paid`, `boss_pending`) lives in `GameState` (save schema 5). `MapLayout` only gains tier
spots and yards (`SPOT_IDS` and `WaypointGraph.create_default()` are untouched). One `Boar` scene carries every monster
kind from a `MonsterBalance` table; a per-kind target priority lets the hare walk past fences (D-148). The boss rides
wave 3; the tier-up dawn is PhaseController's existing dawn plus `complete_tier_up()` and a visual reveal.

**Tech Stack:** Godot 4.7.2 (GDScript, Compatibility renderer), GUT 9.7.1, the sim harness, sweep and perf scripts.

**Spec:** `docs/superpowers/specs/2026-10-06-e5-tier-ladder-design.md` (D-236 to D-247). Read the spec section named
in each task before starting it. Section 15 of the spec (added by this plan) lists what the plan changed.

## Global Constraints

- `export GODOT=/Users/ryan/Applications/Godot-4.7.2-stable/Godot.app/Contents/MacOS/Godot` in the same Bash call as
  any Godot or `./run_tests.sh` command. After creating a worktree, run `"$GODOT" --headless --path . --import` once.
- `./run_tests.sh unit` and `./run_tests.sh sim` pass; they fail on any `SCRIPT ERROR` or GUT error. The sim suite's
  60 s budget is never met by dropping, skipping or weakening a test (D-132); over budget is reported with per-test
  timings and escalated (spec 8.5, D-247).
- **Tier-1 identity (D-237):** after every task from Task 3 on, `tools/baseline_rows.sh 7` prints `rows 1-7 identical`:
  rows 1 to 7 of the planner sweep are byte-identical to `tests/sim/baseline/`. The tier-1 cap arrives with
  `WaveMath.pressure` (Task 3), so from then on `tools/baseline_diff.sh` differs in rows 8 to 14; that is the authorized
  change, and Task 16 re-records those rows once. (Amended during execution: the first draft kept `baseline_diff.sh`
  identical until Task 16, which the cap makes impossible. `tools/baseline_rows.sh` was pulled forward into Task 3.)
- `NaiveBot`, `PlannerBot`, `GuideBot` and `UpgraderBot` never buy the tier-up and never read tier 2 spots. No task
  changes an Rng stream name, an Rng call, its order at tier 1, or `WaypointGraph.create_default()`.
- Gameplay in `_physics_process` only; never depend on frame delta. Only `GameState` methods mutate game data; they
  emit the EventBus signals. Tweens are visual only. Randomness only through `Rng.stream`.
- Every number in `balance/` (gameplay) or `balance/ui_tuning.gd` (visual); every user string through `tr()`.
- Monster kinds are `StringName` (`&"boar"`, `&"hare"`, `&"boss"`); spot ids are `String`; snapshot keys are `String`.
- **Hot files** (D-136, D-139): `project.godot`, `CLAUDE.md`, `run_tests.sh`, `.github/workflows/*`, `autoload/*`,
  `balance/*`, `world/main.gd`, `world/main.tscn`, `world/world.gd`. A task edits and commits a hot file only when its
  **Files** list marks it `(main purpose)`. Any other hot-file change: the implementer writes it, saves it with
  `git diff -- <hot files> > /tmp/wiring_e5_t<NN>.patch`, keeps it applied locally for its test runs, never commits it,
  and pastes the patch text in its report. The main session applies and commits it after review.
- New scripts come with a `.gd.uid` file (Godot writes it on import); commit it with the script. Before each commit
  `git status --short` shows nothing but the wiring patch's hot files.
- **Commits:** one per task on the phase branch; message `feat(e5): …`, `test(e5): …`, `art(e5): …` or `docs(e5): …`;
  trailer = the `Co-Authored-By` line from your own session's attribution, then
  `Claude-Session: https://claude.ai/code/session_01AdSEzP2uJighB8yJ1WRwDj`.
- **Branches (D-133):** `e5/p1-core` (Tasks 1 to 5), `e5/p2-night` (Tasks 6 to 8), `e5/p3-world` (Tasks 9 to 12),
  `e5/p4-sims` (Tasks 13 to 17, 18 gated), each from an up-to-date `main`. P1 to P3 are self-merged by the main session
  when CI is green and every task passed its reviewer (D-137). **P4 ends at a checkpoint:** the author reads the
  baseline re-record diff, the sweep results and the perf readings before the merge.
- Tests create the game with `Main.create()`, never `Main.new()`. Read state after `await get_tree().physics_frame`.
- Direct writes to `GameState` fields are allowed only in test setup, marked `# test-only setup`.
- `balance/balance.tres` holds no values: every default lives in the `.gd` resource script.

## Review Focus

Inputs the spec implies but does not spell out, most likely first. Each has a test in the named task.

1. **A tier-1 save past day 7 loads after the update** (its old `lane_plan` was planned at day 9 pressure). Expected:
   it plays that saved night as saved, and the next dawn plans at the cap; no crash, no rejection. Task 5 (migration
   test on a day-12 state) and Task 8 (dawn re-plan test).
2. **The hero is paying on the tier sign when the payment completes.** Expected: `boss_pending` flips once, the sign
   text changes on that tick, further ticks pay nothing, the autosave writes once. Task 4 and Task 9.
3. **The boss night is lost twice and then won.** Expected: each retry restores `boss_pending = true` and the payment;
   mercy applies to the boss; the win's dawn tiers up with `night_fails` back to 0. Task 8 (controller test with a
   forced fall) and sim 1 (Task 15).
4. **A tier-2 save is loaded by a build that only knows tier 1** (someone rolls `main` back). Expected: the tier is
   clamped to the top the build knows, `tower_w`/`tower_e` are unknown ids and the save is rejected as "building",
   never a crash. Task 5 pins the rejection; it is the documented limit of the clamp rule.
5. **The hare reaches the diner while a boar stands at the fence on the same lane.** Expected: the hare attacks the
   diner, the boar the fence, both at their own interval; killing the fence does not retarget the hare. Task 6.

---

## File structure

| File | Responsibility | Task |
|---|---|---|
| `balance/tier_balance.gd` (new), `balance/monster_stats.gd` (new), `balance/monster_balance.gd` (new), `balance/balance_data.gd` | Tier and monster numbers | 1 |
| `core/tier_effects.gd` (new) | Tier cost, top tier, fast share and counts | 1 |
| `core/map_layout.gd`, `core/waypoint_graph.gd` | Tier spots, yards, the sign, `spots_for_tier`, `create_for_tier` | 2 |
| `core/wave_math.gd`, `core/lane_planner.gd`, `core/wave_schedule.gd` | Pressure, fast counts, boss entry | 3 |
| `autoload/GameState.gd`, `autoload/EventBus.gd` | Tier state, payment, tier-up, signals | 4 |
| `core/save_codec.gd` | Schema 5, migration 4 → 5, validation, tier clamp | 5 |
| `actors/enemy/boar.gd`, `world/target_providers.gd`, `world/wave_director.gd`, `world/guard_roster.gd`, `autoload/EventBus.gd` | Kinds, per-kind priority, boss and hare spawns, `enemy_killed` kind | 6 |
| `art/boar/boar_mesh.gd`, `art/boar/boar_visual.gd`, `actors/enemy/boss_bar.gd` (new), `ui/hud/hud_icons.gd`, `ui/hud/hud.gd` | Hare and boss looks, boss HP bar, boss moon | 7 |
| `world/phase_controller.gd`, `core/pulse.gd`, `world/save/autosave.gd`, `world/fx/reactions.gd`, `world/audio/audio_director.gd`, `ui/guide/guide.gd` | Boss night, tier-up dawn, listeners | 8 |
| `world/stations/tier_sign.gd` (new), `art/env/src/tier_sign_src.tscn` (new), `art/env/tier_sign.tscn` (new) | The sign | 9 |
| `art/env/ground.gd`, `art/env/yard_stones.gd` (new), `world/world.gd` | Yards, stones, tier spots at runtime, the ground rebuild | 10 |
| `art/env/src/diner_t2_src.tscn` (new), `art/env/baked/diner_t2.res` (new), `art/env/diner_t2.tscn` (new), `art/env/bake_manifest.gd` | The tier-2 diner | 11 |
| `world/tier_reveal.gd` (new), `world/camera_rig.gd`, `balance/ui_tuning.gd` | The reveal | 12 |
| `actors/bots/tier_bot.gd` (new) | The tier bot | 13 |
| `tests/sim/make_save.gd`, `export/fixtures/*.save.json` | Fixtures | 14 |
| `tests/sim/test_tier_sims.gd` (new) | The four sims | 15 |
| `tests/sim/sweep_runner.gd`, `tools/baseline_rows.sh` (new), `tools/baseline_diff.sh`, `tests/sim/baseline/*`, `balance/sim_thresholds.gd` | Tier sweep, retired target, baseline re-record | 16 |
| `export/perf_night3.sh`, `docs/*`, `CLAUDE.md` | Readings and docs | 17 |
| `tests/sim_tier/`, `run_tests.sh`, `.github/workflows/ci.yml` | Sim budget split (only if D-247 is accepted) | 18 |

---

# Phase 1: `e5/p1-core`

### Task 1: TierBalance, MonsterBalance, TierEffects

Spec 4.3, 4.4.

**Files:**
- Create: `balance/tier_balance.gd` (main purpose), `balance/monster_stats.gd` (main purpose),
  `balance/monster_balance.gd` (main purpose)
- Modify: `balance/balance_data.gd` (main purpose: the two new exports)
- Create: `core/tier_effects.gd`
- Test: `tests/unit/test_tier_effects.gd`, `tests/unit/test_monster_balance.gd`

**Interfaces:**
- Consumes: `EnemyBalance` (unchanged: it stays the Boar's stats and the shared `lateral_spread`, `drop_scatter`,
  `offset_fade_distance`), `EconomyBalance.steaks_per_kill`, `WaveBalance.target_priority`.
- Produces:
  ```gdscript
  Balance.data.tiers: TierBalance
  Balance.data.monsters: MonsterBalance
  MonsterBalance.KINDS: Array[StringName]                 # [&"boar", &"hare", &"boss"]
  MonsterBalance.stats(kind: StringName) -> MonsterStats  # boar = a view of EnemyBalance (one source)
  MonsterStats: hp, speed, damage, attack_interval, reach, steaks_per_kill, drop_scatter, priority: Array[StringName]
  TierEffects.top_tier(tb: TierBalance) -> int            # tier_costs.size(): the highest tier this build reaches
  TierEffects.tier_cost(tier: int, tb: TierBalance) -> int   # cost to go from `tier` to tier + 1; -1 at or above the top
  TierEffects.fast_share_now(day: int, tier: int, tier_day: int, tb: TierBalance) -> float
  TierEffects.fast_counts(main: int, side: int, share: float) -> Dictionary   # {"fast_main", "fast_side"}
  ```

**Plan change to the spec (recorded in spec section 15):** `EnemyBalance` and `WaveBalance.target_priority` are kept
as the Boar's numbers (about 40 tests read `Balance.data.enemy`); `MonsterBalance.stats(&"boar")` builds its view from
them, so there is still one source per number. The hare and the boss are exported `MonsterStats`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_tier_effects.gd`:

```gdscript
extends GutTest
## E5 spec 4.4: TierBalance shape and TierEffects.

var tb: TierBalance

func before_each() -> void:
	Balance.reset()
	tb = Balance.data.tiers

func test_arrays_cover_every_tier_including_the_top() -> void:
	var n := tb.tier_costs.size() + 2  # index 0 unused, tiers 1..top where top = tier_costs.size() + 1
	for arr in [tb.tier_base, tb.tier_cap, tb.fast_share_start, tb.fast_share, tb.fast_ramp_days]:
		assert_eq((arr as Array).size(), n)

func test_tiers_are_ordered() -> void:
	for t in range(1, tb.tier_costs.size() + 1):
		assert_lte(tb.tier_base[t], tb.tier_cap[t], "tier %d base <= cap" % t)
		assert_lt(tb.tier_cap[t], tb.tier_base[t + 1], "tier %d cap < next base" % t)
	assert_lte(tb.tier_base[tb.tier_costs.size() + 1], tb.tier_cap[tb.tier_costs.size() + 1])

func test_spec_values() -> void:
	assert_eq(Array(tb.tier_costs), [0, 500])
	assert_eq(Array(tb.tier_base), [0, 1, 8])
	assert_eq(Array(tb.tier_cap), [0, 7, 11])
	assert_eq(TierEffects.top_tier(tb), 2)
	assert_eq(TierEffects.tier_cost(1, tb), 500)
	assert_eq(TierEffects.tier_cost(2, tb), -1)
	assert_eq(TierEffects.tier_cost(9, tb), -1)
	assert_eq(tb.boss_min_hold_s, 15.0)

func test_fast_share_ramps_then_caps() -> void:
	assert_almost_eq(TierEffects.fast_share_now(5, 1, 1, tb), 0.0, 1e-6)
	assert_almost_eq(TierEffects.fast_share_now(9, 2, 9, tb), 0.15, 1e-6)
	assert_almost_eq(TierEffects.fast_share_now(10, 2, 9, tb), 0.15 + (0.35 - 0.15) / 3.0, 1e-6)
	assert_almost_eq(TierEffects.fast_share_now(12, 2, 9, tb), 0.35, 1e-6)
	assert_almost_eq(TierEffects.fast_share_now(40, 2, 9, tb), 0.35, 1e-6)

func test_fast_counts_round_and_never_exceed() -> void:
	assert_eq(TierEffects.fast_counts(14, 0, 0.15), {"fast_main": 2, "fast_side": 0})
	assert_eq(TierEffects.fast_counts(21, 7, 0.35), {"fast_main": 7, "fast_side": 2})
	assert_eq(TierEffects.fast_counts(3, 1, 1.0), {"fast_main": 3, "fast_side": 1})
	assert_eq(TierEffects.fast_counts(5, 2, 0.0), {"fast_main": 0, "fast_side": 0})
```

`tests/unit/test_monster_balance.gd`:

```gdscript
extends GutTest
## E5 spec 4.3: one stats table per kind; the boar's is a view of EnemyBalance (one source per number).

func before_each() -> void:
	Balance.reset()

func test_kinds() -> void:
	assert_eq(Array(MonsterBalance.KINDS), [&"boar", &"hare", &"boss"])

func test_boar_view_equals_enemy_balance() -> void:
	var eb := Balance.data.enemy
	var s := Balance.data.monsters.stats(&"boar")
	assert_eq([s.hp, s.speed, s.damage, s.attack_interval, s.reach], [eb.hp, eb.speed, eb.damage, eb.attack_interval, eb.reach])
	assert_eq(s.steaks_per_kill, Balance.data.economy.steaks_per_kill)
	assert_eq(s.drop_scatter, eb.drop_scatter)
	assert_eq(Array(s.priority), Array(Balance.data.wave.target_priority.kinds))

func test_boar_view_follows_a_mutation() -> void:
	Balance.data.enemy.speed = 9.0
	assert_eq(Balance.data.monsters.stats(&"boar").speed, 9.0)

func test_hare_and_boss_spec_values() -> void:
	var h := Balance.data.monsters.stats(&"hare")
	assert_eq([h.hp, h.speed, h.damage, h.attack_interval, h.reach, h.steaks_per_kill], [15.0, 3.6, 4.0, 1.0, 1.2, 2])
	assert_eq(Array(h.priority), [&"guard", &"diner"])
	var b := Balance.data.monsters.stats(&"boss")
	assert_eq([b.hp, b.speed, b.damage, b.attack_interval, b.reach, b.steaks_per_kill], [800.0, 1.2, 15.0, 1.0, 1.6, 100])
	assert_eq(Array(b.priority), [&"fence_on_lane", &"guard", &"diner"])
	assert_eq(b.drop_scatter, 2.5)

func test_unknown_kind_is_rejected() -> void:
	assert_false(Balance.data.monsters.has_kind(&"dragon"))
	assert_true(Balance.data.monsters.has_kind(&"hare"))
```

- [ ] **Step 2: Run them to verify they fail**

Run: `export GODOT=…; "$GODOT" --headless --path . --import >/dev/null 2>&1; "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_tier_effects.gd -gtest=res://tests/unit/test_monster_balance.gd -gexit`
Expected: FAIL (`TierBalance`, `MonsterBalance`, `TierEffects` not found).

- [ ] **Step 3: Write the balance scripts**

`balance/tier_balance.gd`:

```gdscript
class_name TierBalance
extends Resource
## E5 spec 4.4: the diner tier ladder. Index = tier; index 0 is unused (tiers count from 1). Every array has
## tier_costs.size() + 2 entries so the top tier (tier_costs.size() + 1) has its own cap.

## Gold to reach tier index + 1: tier_costs[1] is the cost of tier 2. The highest reachable tier is tier_costs.size().
@export var tier_costs: Array[int] = [0, 500]
## Pressure (the "day" every wave formula sees) at the tier's first night, and where it stops growing.
@export var tier_base: Array[int] = [0, 1, 8]
@export var tier_cap: Array[int] = [0, 7, 11]
## Share of each wave group that spawns as hares: on the tier's first night, at the cap, and the days between.
@export var fast_share_start: Array[float] = [0.0, 0.0, 0.15]
@export var fast_share: Array[float] = [0.0, 0.0, 0.35]
@export var fast_ramp_days: Array[int] = [0, 1, 3]
## Seconds between the boss (first spawn of wave 3) and the rest of that wave.
@export var boss_lead := 3.0
## Sim 2 (spec 8.1): the boss alone must need at least this long to fell the diner from its first hit.
@export var boss_min_hold_s := 15.0
## Dawn after a won boss night: seconds before the card pick opens (the reveal plays meanwhile).
@export var tier_reveal_time := 3.0
## The ladder's length (D-236). A save above the top this build knows is clamped (spec 6.3).
@export var max_tier := 5
```

`balance/monster_stats.gd`:

```gdscript
class_name MonsterStats
extends Resource
## One monster kind's numbers (E5 spec 4.3). The boar's are a view of EnemyBalance (MonsterBalance.stats).

@export var hp := 30.0
@export var speed := 2.0
@export var damage := 5.0
@export var attack_interval := 1.0
@export var reach := 1.2
@export var steaks_per_kill := 2
@export var drop_scatter := 0.6
## Ordered target kinds this monster checks each tick (D-004, D-049, D-148). No &"fence_on_lane" = walks past fences.
@export var priority: Array[StringName] = [&"fence_on_lane", &"guard", &"diner"]
```

`balance/monster_balance.gd`:

```gdscript
class_name MonsterBalance
extends Resource
## E5 spec 4.3: the hare and the boss as resources; the boar is read from EnemyBalance (one source per number).

const KINDS: Array[StringName] = [&"boar", &"hare", &"boss"]

@export var hare: MonsterStats = MonsterBalance._hare()
@export var boss: MonsterStats = MonsterBalance._boss()

static func _hare() -> MonsterStats:
	var s := MonsterStats.new()
	s.hp = 15.0
	s.speed = 3.6
	s.damage = 4.0
	s.attack_interval = 1.0
	s.reach = 1.2
	s.steaks_per_kill = 2
	s.drop_scatter = 0.6
	s.priority = [&"guard", &"diner"]
	return s

static func _boss() -> MonsterStats:
	var s := MonsterStats.new()
	s.hp = 800.0
	s.speed = 1.2
	s.damage = 15.0
	s.attack_interval = 1.0
	s.reach = 1.6
	s.steaks_per_kill = 100
	s.drop_scatter = 2.5
	s.priority = [&"fence_on_lane", &"guard", &"diner"]
	return s

func has_kind(kind: StringName) -> bool:
	return kind in KINDS

## The boar's view is built on every call from the live EnemyBalance, so a mutated value is seen at once.
func stats(kind: StringName) -> MonsterStats:
	assert(has_kind(kind), "unknown monster kind %s" % kind)
	match kind:
		&"hare":
			return hare
		&"boss":
			return boss
	var eb: EnemyBalance = Balance.data.enemy
	var s := MonsterStats.new()
	s.hp = eb.hp
	s.speed = eb.speed
	s.damage = eb.damage
	s.attack_interval = eb.attack_interval
	s.reach = eb.reach
	s.steaks_per_kill = Balance.data.economy.steaks_per_kill
	s.drop_scatter = eb.drop_scatter
	s.priority = Balance.data.wave.target_priority.kinds
	return s
```

`balance/balance_data.gd`: add after `stations`:

```gdscript
@export var tiers: TierBalance = TierBalance.new()
@export var monsters: MonsterBalance = MonsterBalance.new()
```

`core/tier_effects.gd`:

```gdscript
class_name TierEffects
extends RefCounted
## Tier ladder helpers (E5 spec 4.4). Pure: no scene access, no GameState.

## The highest tier this build can reach: tier_costs[t] is the cost of tier t + 1, so the last index is the last buy.
static func top_tier(tb: TierBalance) -> int:
	return tb.tier_costs.size()

## Gold from `tier` to `tier + 1`; -1 when there is no next tier in this build.
static func tier_cost(tier: int, tb: TierBalance) -> int:
	if tier < 1 or tier >= top_tier(tb):
		return -1
	return tb.tier_costs[tier]

## Share of a wave group that spawns as hares on `day` for a tier entered on `tier_day`.
static func fast_share_now(day: int, tier: int, tier_day: int, tb: TierBalance) -> float:
	var ramp := maxi(tb.fast_ramp_days[tier], 1)
	var k := clampf(float(day - tier_day) / float(ramp), 0.0, 1.0)
	return lerpf(tb.fast_share_start[tier], tb.fast_share[tier], k)

## How many of a wave's main and side groups are hares.
static func fast_counts(main: int, side: int, share: float) -> Dictionary:
	return {"fast_main": mini(main, int(round(main * share))), "fast_side": mini(side, int(round(side * share)))}
```

- [ ] **Step 4: Run the tests and `test_balance.gd`**

Run: `./run_tests.sh unit`
Expected: PASS (the new files, and `test_balance.gd` still asserts `d.wave.target_priority.kinds`).

- [ ] **Step 5: Commit**

```bash
git add balance/tier_balance.gd* balance/monster_stats.gd* balance/monster_balance.gd* balance/balance_data.gd core/tier_effects.gd* tests/unit/test_tier_effects.gd* tests/unit/test_monster_balance.gd*
git commit -m "feat(e5): TierBalance, MonsterBalance and TierEffects"
```

### Task 2: MapLayout tier spots, yards, the sign; WaypointGraph.create_for_tier

Spec 5.1, 5.2, 5.3.

**Files:**
- Modify: `core/map_layout.gd` (additions only), `core/waypoint_graph.gd` (a new static function only)
- Test: `tests/unit/test_tier_layout.gd`

**Interfaces:**
- Produces:
  ```gdscript
  MapLayout.TIER_SPOTS: Dictionary                 # {2: ["tower_w", "tower_e"]}
  MapLayout.ALL_SPOT_IDS: Array[String]            # SPOT_IDS + tier lists in tier order
  MapLayout.YARDS: Dictionary                      # {"west": Rect2, "east": Rect2} (x, z, w, h)
  MapLayout.YARD_TIER: Dictionary                  # {"west": 2, "east": 2}
  MapLayout.TIER_SIGN: Vector2
  MapLayout.spots_for_tier(tier: int) -> Array[String]
  MapLayout.yards_for_tier(tier: int) -> Array[String]
  MapLayout.spot_tier(spot_id: String) -> int      # 1 for SPOT_IDS
  WaypointGraph.create_for_tier(tier: int) -> WaypointGraph
  ```
- `TOWER_SPOTS` and `TOWER_LANES` gain the two yard entries; `spot_position`, `spot_kind`, `Economy.base_cost`
  work for them unchanged. `SPOT_IDS` is not touched.

**The coordinates below are drafts.** The tests fix them: if one fails, move the yard edge, the spot or the sign, keep
the test, and report the final numbers in the task report. Never loosen a clearance.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_tier_layout.gd`:

```gdscript
extends GutTest
## E5 spec 5.3: the yards, the yard towers and the tier sign are fixed by these tests, not by eye (D-240).

const MARGIN := 1.0  # on top of lateral_spread

func before_each() -> void:
	Balance.reset()

func _on_screen_from(p: Vector2, hero: Vector2) -> bool:
	var xf := CameraMath.camera_transform(CameraMath.focus_for(hero), Balance.ui)
	return CameraMath.on_screen(MapLayout.to3(p), xf, CameraMath.projection(Balance.ui))

func _lane_clearance(p: Vector2) -> float:
	var best := INF
	for lane in MapLayout.LANE_PATHS:
		var path: Array = MapLayout.LANE_PATHS[lane]
		for i in range(1, path.size()):
			best = minf(best, Geometry.dist_point_segment(p, path[i - 1], path[i]))
	return best

func _rect_lane_clearance(r: Rect2) -> float:
	var best := INF
	for corner in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
		best = minf(best, _lane_clearance(corner))
	# edges: sample every 0.25 m
	var x := r.position.x
	while x <= r.end.x + 1e-6:
		best = minf(best, _lane_clearance(Vector2(x, r.position.y)))
		best = minf(best, _lane_clearance(Vector2(x, r.end.y)))
		x += 0.25
	var z := r.position.y
	while z <= r.end.y + 1e-6:
		best = minf(best, _lane_clearance(Vector2(r.position.x, z)))
		best = minf(best, _lane_clearance(Vector2(r.end.x, z)))
		z += 0.25
	return best

func test_spot_lists() -> void:
	assert_eq(MapLayout.SPOT_IDS, ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e"], "SPOT_IDS is frozen")
	assert_eq(MapLayout.spots_for_tier(1), MapLayout.SPOT_IDS)
	assert_eq(MapLayout.spots_for_tier(2), ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e", "tower_w", "tower_e"])
	assert_eq(MapLayout.ALL_SPOT_IDS, MapLayout.spots_for_tier(2))
	assert_eq([MapLayout.spot_tier("fence_n"), MapLayout.spot_tier("tower_w")], [1, 2])
	assert_eq(MapLayout.spot_kind("tower_w"), "tower")
	assert_eq(MapLayout.TOWER_LANES["tower_w"], ["west"])
	assert_eq(MapLayout.TOWER_LANES["tower_e"], ["east"])
	assert_eq(MapLayout.yards_for_tier(1), [])
	assert_eq(MapLayout.yards_for_tier(2), ["west", "east"])

func test_yards_and_yard_spots_clear_the_lanes() -> void:
	var need: float = Balance.data.enemy.lateral_spread + MARGIN
	for id in MapLayout.YARDS:
		assert_gte(_rect_lane_clearance(MapLayout.YARDS[id]), need, "%s yard clears the lanes by %.2f" % [id, need])
	for id in MapLayout.TIER_SPOTS[2]:
		assert_gte(_lane_clearance(MapLayout.spot_position(id)) - MapLayout.TOWER_VISUAL_RADIUS, need, id)
	assert_gte(_lane_clearance(MapLayout.TIER_SIGN) - MapLayout.STATION_RADIUS, need, "tier sign")

func _keep_clear() -> Array:
	# [centre, radius] pairs everything new must stay outside of
	var out := [[MapLayout.SIGN, MapLayout.STATION_RADIUS], [MapLayout.FREEZER_ZONE, MapLayout.STATION_RADIUS],
		[MapLayout.COUNTER_DROP, MapLayout.STATION_RADIUS], [MapLayout.GOLD_PILE, Balance.data.hero.magnet_radius],
		[MapLayout.HOME, 0.0], [MapLayout.NIGHT1_START, 0.0], [MapLayout.guard_post(&"tank"), Balance.data.guards.tank.body_radius],
		[MapLayout.guard_post(&"archer"), 0.0]]
	for id in MapLayout.SPOT_IDS:
		out.append([MapLayout.spot_position(id), MapLayout.BUILD_RADIUS])
	for id in StationEffects.IDS:
		out.append([MapLayout.STATION_PADS[id], MapLayout.BUILD_RADIUS])
	for s in MapLayout.QUEUE_SLOTS:
		out.append([s, 0.0])
	return out

func _bodies() -> Array:
	return [
		Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2, MapLayout.DINER_HALF * 2),
		Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE),
	]

func test_yards_overlap_nothing_that_exists() -> void:
	for id in MapLayout.YARDS:
		var r: Rect2 = MapLayout.YARDS[id]
		for z in _keep_clear():
			assert_gt(Geometry.dist_point_rect(z[0], r), float(z[1]), "%s yard overlaps %s" % [id, z[0]])
		for b in _bodies():
			assert_false(r.intersects(b.grow(MapLayout.HERO_RADIUS)), "%s yard overlaps a body" % id)
		for lane in MapLayout.ZONE_RECTS:
			assert_false(r.intersects(MapLayout.ZONE_RECTS[lane]), "%s yard overlaps the %s zone" % [id, lane])
		var path := MapLayout.tank_return_path()
		for i in range(1, path.size()):
			var a: Vector2 = path[i - 1]
			var b: Vector2 = path[i]
			for k in 21:
				assert_false(r.has_point(a.lerp(b, k / 20.0)), "%s yard crosses the Tank's return path" % id)

func test_sign_and_yard_spots_overlap_nothing_that_exists() -> void:
	var pts := [[MapLayout.TIER_SIGN, MapLayout.STATION_RADIUS, "tier sign"]]
	for id in MapLayout.TIER_SPOTS[2]:
		pts.append([MapLayout.spot_position(id), MapLayout.BUILD_RADIUS, id])
	for p in pts:
		for z in _keep_clear():
			assert_gt((p[0] as Vector2).distance_to(z[0]), float(p[1]) + float(z[1]), "%s overlaps %s" % [p[2], z[0]])
		for b in _bodies():
			assert_gt(Geometry.dist_point_rect(p[0], b), float(p[1]) + MapLayout.HERO_RADIUS, "%s too close to a body" % p[2])
		for lane in MapLayout.ZONE_RECTS:
			assert_gt(Geometry.dist_point_rect(p[0], MapLayout.ZONE_RECTS[lane]), float(p[1]), "%s overlaps the %s zone" % [p[2], lane])

func test_sign_stands_on_the_west_yard() -> void:
	assert_true((MapLayout.YARDS["west"] as Rect2).has_point(MapLayout.TIER_SIGN), "the sign stands on the land it sells (D-240)")
	for id in MapLayout.TIER_SPOTS[2]:
		var yard: Rect2 = MapLayout.YARDS["west" if id == "tower_w" else "east"]
		assert_true(yard.grow(-MapLayout.TOWER_VISUAL_RADIUS).has_point(MapLayout.spot_position(id)), "%s stands on its yard" % id)

func test_new_points_are_far_from_props() -> void:
	var pts := [MapLayout.TIER_SIGN]
	for id in MapLayout.TIER_SPOTS[2]:
		pts.append(MapLayout.spot_position(id))
	for p in pts:
		for item in PropsLayout.ITEMS:
			assert_gt((p as Vector2).distance_to(item.pos), 3.0, "%s is within 3 m of a prop at %s" % [p, item.pos])

func test_yards_inside_the_bounds_and_the_ground() -> void:
	var play := Rect2(MapLayout.BOUNDS_MIN, MapLayout.BOUNDS_MAX - MapLayout.BOUNDS_MIN)
	for id in MapLayout.YARDS:
		assert_true(play.encloses(MapLayout.YARDS[id]), "%s yard inside BOUNDS" % id)
		assert_true(World.ground_rect().encloses(MapLayout.YARDS[id]), "%s yard on the ground" % id)

func test_on_screen_from_their_stand_points() -> void:
	assert_true(_on_screen_from(MapLayout.TIER_SIGN, MapLayout.TIER_SIGN), "sign")
	assert_true(_on_screen_from(MapLayout.TIER_SIGN + Vector2(0, -2.0), MapLayout.TIER_SIGN), "sign label (2 m up reads as 2 m north at this pitch, conservative)")
	var g := WaypointGraph.create_for_tier(2)
	for id in MapLayout.TIER_SPOTS[2]:
		assert_true(_on_screen_from(MapLayout.spot_position(id), g.position_of(id)), id)

func test_yard_towers_reach_their_lane() -> void:
	var r: float = Balance.data.build.tower_range[0]
	for id in MapLayout.TIER_SPOTS[2]:
		var t := MapLayout.spot_position(id)
		for lane in MapLayout.TOWER_LANES[id]:
			var z: Rect2 = MapLayout.ZONE_RECTS[lane]
			for corner in [z.position, z.end, Vector2(z.position.x, z.end.y), Vector2(z.end.x, z.position.y)]:
				assert_lte(t.distance_to(corner), r, "%s -> %s zone corner %s" % [id, lane, corner])
			assert_lte(t.distance_to(MapLayout.fence_spot(lane)), r, "%s -> %s fence" % [id, lane])

func test_create_for_tier() -> void:
	var d := WaypointGraph.create_default()
	var one := WaypointGraph.create_for_tier(1)
	assert_eq(one.nodes, d.nodes)
	assert_eq(one.edges, d.edges)
	var two := WaypointGraph.create_for_tier(2)
	for n in ["tier_sign", "tower_w", "tower_e"]:
		assert_true(two.nodes.has(n), n)
	assert_eq(two.nodes.size(), d.nodes.size() + 3)
	assert_true(MapLayout.spot_position("tower_w").distance_to(two.position_of("tower_w")) <= MapLayout.BUILD_RADIUS)
	assert_true(MapLayout.spot_position("tower_e").distance_to(two.position_of("tower_e")) <= MapLayout.BUILD_RADIUS)
	for goal in ["tier_sign", "tower_w", "tower_e"]:
		assert_false(two.shortest("home", goal).is_empty(), "home reaches %s" % goal)
	# the frozen default did not change (D-230)
	var names: Array = d.nodes.keys()
	names.sort()
	assert_eq(names.size(), 19)

func test_new_edges_clear_the_colliders() -> void:
	var two := WaypointGraph.create_for_tier(2)
	var d := WaypointGraph.create_default()
	for a in two.edges:
		for b in two.edges[a]:
			if d.edges.has(a) and (d.edges[a] as Array).has(b):
				continue
			var pa: Vector2 = two.position_of(a)
			var pb: Vector2 = two.position_of(b)
			for body in _bodies():
				for k in 41:
					assert_false(body.grow(MapLayout.HERO_RADIUS).has_point(pa.lerp(pb, k / 40.0)), "edge %s-%s crosses a body" % [a, b])
```

- [ ] **Step 2: Run it to verify it fails**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_tier_layout.gd -gexit`
Expected: FAIL (`TIER_SPOTS` not found).

- [ ] **Step 3: Add the layout data**

`core/map_layout.gd`, after `TELEGRAPH_OFFSET_FROM_END`:

```gdscript
## E5 (spec 5.1, D-239, D-240): spots a tier unlocks (appended to spots_for_tier), the side yards (Rect2(x, z, w, h)) and
## the tier sign, which stands on the land it sells. SPOT_IDS stays the tier-1 list; nothing above moves.
const TIER_SPOTS := {2: ["tower_w", "tower_e"]}
const YARDS := {"west": Rect2(-13.5, -2.5, 4.5, 10.5), "east": Rect2(9.5, -2.5, 4.0, 8.0)}
const YARD_TIER := {"west": 2, "east": 2}
const TIER_SIGN := Vector2(-10.0, 7.5)
const ALL_SPOT_IDS: Array[String] = ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e", "tower_w", "tower_e"]

static func spots_for_tier(tier: int) -> Array[String]:
	var out: Array[String] = []
	out.assign(SPOT_IDS)
	for t in range(2, tier + 1):
		if TIER_SPOTS.has(t):
			out.append_array(TIER_SPOTS[t])
	return out

static func yards_for_tier(tier: int) -> Array[String]:
	var out: Array[String] = []
	for id in YARDS:
		if int(YARD_TIER[id]) <= tier:
			out.append(id)
	return out

static func spot_tier(spot_id: String) -> int:
	for t in TIER_SPOTS:
		if spot_id in TIER_SPOTS[t]:
			return t
	return 1
```

Extend the two existing constants (edit in place, keep the old entries first):

```gdscript
const TOWER_SPOTS := {"tower_nw": Vector2(-5, -5), "tower_ne": Vector2(5, -5), "tower_w": Vector2(-11.0, 1.5), "tower_e": Vector2(11.0, 1.5)}
const TOWER_LANES := {"tower_nw": ["west", "north"], "tower_ne": ["north", "east"], "tower_w": ["west"], "tower_e": ["east"]}
```

`core/waypoint_graph.gd`, after `create_default()`:

```gdscript
## E5 (spec 5.2): the default graph plus the tier's sign and yard spots. create_default() stays frozen (D-230);
## only TierBot and tests use this.
static func create_for_tier(tier: int) -> WaypointGraph:
	var g := create_default()
	if tier >= 2:
		g.add_node("tier_sign", MapLayout.TIER_SIGN)
		g.add_node("tower_w", MapLayout.TOWER_SPOTS.tower_w + Vector2(-0.75, 0.75))
		g.add_node("tower_e", MapLayout.TOWER_SPOTS.tower_e + Vector2(0.75, 0.75))
		for e in [["sw", "tier_sign"], ["sw", "tower_w"], ["zone_west", "tower_w"], ["se", "tower_e"], ["zone_east", "tower_e"]]:
			g.add_edge(e[0], e[1])
	return g
```

Note: `TierBot` (Task 13) must reach the sign at tier 1 too, so it uses `create_for_tier(2)` from the start; the
`tier >= 2` guard means "the slice's content", not the player's tier. `create_for_tier(1)` equals the default (test).

- [ ] **Step 4: Run the test and fix the drafts until it passes**

Run: the Task 2 test, then `./run_tests.sh unit`.
Expected: PASS. Existing tests that iterate `TOWER_SPOTS` (`test_geometry.gd` B, C, E, `test_waypoint_graph.gd`
`test_tower_stand_points_inside_build_radius`) now also cover the yard towers; if geometry test E fails for a yard
tower, move the spot, never the lane. Report the final coordinates.

- [ ] **Step 5: Commit**

```bash
git add core/map_layout.gd core/waypoint_graph.gd tests/unit/test_tier_layout.gd*
git commit -m "feat(e5): tier spots, yards and the tier sign in MapLayout; WaypointGraph.create_for_tier"
```

### Task 3: Pressure, fast counts and the boss entry

Spec 4.1, 4.2.

**Files:**
- Modify: `core/wave_math.gd`, `core/lane_planner.gd`, `core/wave_schedule.gd`
- Modify: `autoload/GameState.gd` (two call sites of `LanePlanner.plan`; this task's main purpose is the planner, so the
  two one-line edits are reported as a wiring note; see the note in Step 3)
- Test: `tests/unit/test_wave_math.gd` (add), `tests/unit/test_lane_planner.gd` (add), `tests/unit/test_wave_schedule.gd` (add)

**Interfaces:**
- Consumes: `TierBalance`, `TierEffects` (Task 1).
- Produces:
  ```gdscript
  WaveMath.pressure(day: int, tier: int, tier_day: int, tb: TierBalance) -> int
  # Every other WaveMath function keeps its signature; its first argument is now the pressure, not the day.
  LanePlanner.plan(run_seed: int, day: int, wb: WaveBalance, tier := 1, tier_day := 1, tb: TierBalance = null) -> Array
  # Each wave: {main, side, main_count, side_count, hp_mult, fast_main, fast_side, boss}
  LanePlanner.with_boss(plan: Array) -> Array      # a copy whose last wave has boss = true
  WaveSchedule.build(wave: Dictionary, wb: WaveBalance, tb: TierBalance = null) -> Array
  # Each entry: {t, lane, side, kind: StringName}; the boss entry first at t = 0, the rest shifted by boss_lead.
  ```
- `LanePlanner.plan` with the defaults (`tier` 1, `tier_day` 1) is byte-identical to today for days 1 to 7, and the RNG
  calls (`lane_plan` stream: one `randi_range` for main, one for side when `side > 0`) do not change at any tier.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_wave_math.gd`:

```gdscript
func test_pressure_caps_per_tier() -> void:
	var tb := Balance.data.tiers
	for day in range(1, 8):
		assert_eq(WaveMath.pressure(day, 1, 1, tb), day, "tier 1 day %d is today's day" % day)
	assert_eq(WaveMath.pressure(8, 1, 1, tb), 7)
	assert_eq(WaveMath.pressure(30, 1, 1, tb), 7)
	assert_eq([WaveMath.pressure(9, 2, 9, tb), WaveMath.pressure(10, 2, 9, tb), WaveMath.pressure(12, 2, 9, tb), WaveMath.pressure(13, 2, 9, tb)], [8, 9, 11, 11])
	assert_eq(WaveMath.pressure(40, 2, 40, tb), 8, "a late tier-up starts at the tier's base")

func test_capped_night_kills() -> void:
	# spec 4.1: tier 1 cap 12 + 19 + 25 = 56; tier 2 cap 18 + 27 + 30 = 75
	var k1 := 0
	var k2 := 0
	for w in 3:
		k1 += WaveMath.total_count(7, w, wb)
		k2 += WaveMath.total_count(11, w, wb)
	assert_eq([k1, k2], [56, 75])
```

Append to `tests/unit/test_lane_planner.gd`:

```gdscript
func test_tier1_plan_has_no_hares_and_no_boss_and_is_todays() -> void:
	var tb := Balance.data.tiers
	for day in [1, 2, 5, 7]:
		var p := LanePlanner.plan(555, day, wb, 1, 1, tb)
		var old := LanePlanner.plan(555, day, wb)
		for w in 3:
			for k in ["main", "side", "main_count", "side_count", "hp_mult"]:
				assert_eq(p[w][k], old[w][k], "day %d wave %d %s" % [day, w, k])
			assert_eq([p[w].fast_main, p[w].fast_side, p[w].boss], [0, 0, false])

func test_tier1_day8_is_day7_pressure_with_day8_lanes() -> void:
	var tb := Balance.data.tiers
	var p8 := LanePlanner.plan(555, 8, wb, 1, 1, tb)
	var p7 := LanePlanner.plan(555, 7, wb, 1, 1, tb)
	for w in 3:
		assert_eq([p8[w].main_count, p8[w].side_count, p8[w].hp_mult], [p7[w].main_count, p7[w].side_count, p7[w].hp_mult], "wave %d counts at the cap" % w)
	# lanes still come from the day-8 stream (a save keeps its own lane_plan stream per day)
	var lanes8 := p8.map(func(w): return [w.main, w.side])
	var old8 := LanePlanner.plan(555, 8, wb).map(func(w): return [w.main, w.side])
	assert_eq(lanes8, old8)

func test_tier2_hares_ramp_and_fit_in_the_groups() -> void:
	var tb := Balance.data.tiers
	var first := LanePlanner.plan(555, 9, wb, 2, 9, tb)
	var later := LanePlanner.plan(555, 12, wb, 2, 9, tb)
	var total_first := 0
	var total_later := 0
	for w in 3:
		for p in [first[w], later[w]]:
			assert_lte(int(p.fast_main), int(p.main_count))
			assert_lte(int(p.fast_side), int(p.side_count))
		total_first += int(first[w].fast_main) + int(first[w].fast_side)
		total_later += int(later[w].fast_main) + int(later[w].fast_side)
	assert_gt(total_first, 0, "hares on the first tier-2 night")
	assert_gt(total_later, total_first, "more hares at the cap")
	var expect := TierEffects.fast_counts(int(first[0].main_count), int(first[0].side_count), TierEffects.fast_share_now(9, 2, 9, tb))
	assert_eq([first[0].fast_main, first[0].fast_side], [expect.fast_main, expect.fast_side])

func test_with_boss_marks_only_the_last_wave() -> void:
	var p := LanePlanner.with_boss(LanePlanner.plan(555, 7, wb, 1, 1, Balance.data.tiers))
	assert_eq(p.map(func(w): return w.boss), [false, false, true])
	var again := LanePlanner.plan(555, 7, wb, 1, 1, Balance.data.tiers)
	assert_false(bool(again[2].boss), "with_boss returns a copy")

func test_threat_counts_hares_and_the_boss() -> void:
	var tb := Balance.data.tiers
	var plain := LanePlanner.threat_by_lane(LanePlanner.plan(555, 7, wb, 1, 1, tb), Balance.data.enemy.hp)
	var boss := LanePlanner.threat_by_lane(LanePlanner.with_boss(LanePlanner.plan(555, 7, wb, 1, 1, tb)), Balance.data.enemy.hp)
	var lane: String = LanePlanner.plan(555, 7, wb, 1, 1, tb)[2].main
	assert_gt(boss[lane], plain[lane], "the boss raises its lane's threat")
```

Append to `tests/unit/test_wave_schedule.gd`:

```gdscript
func _wave(main_n: int, side_n: int, fast_main := 0, fast_side := 0, boss := false) -> Dictionary:
	return {"main": "west", "side": "east" if side_n > 0 else "", "main_count": main_n, "side_count": side_n, "hp_mult": 1.0,
		"fast_main": fast_main, "fast_side": fast_side, "boss": boss}

func test_legacy_wave_without_the_new_keys_is_all_boars() -> void:
	var s := WaveSchedule.build({"main": "north", "side": "", "main_count": 2, "side_count": 0, "hp_mult": 1.0}, wb)
	assert_eq(s.map(func(e): return e.kind), [&"boar", &"boar"])

func test_hares_are_the_last_of_each_group() -> void:
	var s := WaveSchedule.build(_wave(4, 3, 2, 1), wb, Balance.data.tiers)
	var main_kinds: Array = s.filter(func(e): return not e.side).map(func(e): return e.kind)
	var side_kinds: Array = s.filter(func(e): return e.side).map(func(e): return e.kind)
	assert_eq(main_kinds, [&"boar", &"boar", &"hare", &"hare"])
	assert_eq(side_kinds, [&"boar", &"boar", &"hare"])

func test_boss_spawns_first_and_shifts_the_rest() -> void:
	var tb := Balance.data.tiers
	var s := WaveSchedule.build(_wave(3, 2, 0, 0, true), wb, tb)
	assert_eq(s.size(), 6)
	assert_eq(s[0].kind, &"boss")
	assert_almost_eq(float(s[0].t), 0.0, 1e-6)
	assert_eq(s[0].lane, "west")
	assert_false(s[0].side)
	assert_almost_eq(float(s[1].t), tb.boss_lead, 1e-6)
	var side_times: Array = s.filter(func(e): return e.side).map(func(e): return float(e.t))
	assert_almost_eq(side_times[0], tb.boss_lead + wb.side_group_delay, 1e-6)

func test_tier1_schedule_is_unchanged() -> void:
	var old := WaveSchedule.build({"main": "west", "side": "east", "main_count": 5, "side_count": 2, "hp_mult": 1.0}, wb)
	var now := WaveSchedule.build(_wave(5, 2), wb, Balance.data.tiers)
	for i in old.size():
		assert_eq([old[i].t, old[i].lane, old[i].side], [now[i].t, now[i].lane, now[i].side])
```

- [ ] **Step 2: Run them to verify they fail**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_wave_math.gd -gtest=res://tests/unit/test_lane_planner.gd -gtest=res://tests/unit/test_wave_schedule.gd -gexit`
Expected: FAIL (`pressure` not found; `fast_main` missing; `kind` missing).

- [ ] **Step 3: Implement**

`core/wave_math.gd`: add at the top of the functions and rename the parameter in the doc comment (the bodies are
unchanged; `day` is renamed `pressure` in the signatures below):

```gdscript
class_name WaveMath
extends RefCounted
## Wave sizes and HP (spec 6.2, D-027, D-053, D-100). Since E5 (spec 4.1) every function takes the PRESSURE, not the
## day: pressure(day, tier, tier_day) ramps from the tier's base and stops at its cap. At tier 1 pressure == day for
## days 1 to 7 (D-237).

static func pressure(day: int, tier: int, tier_day: int, tb: TierBalance) -> int:
	return clampi(tb.tier_base[tier] + (day - tier_day), tb.tier_base[tier], tb.tier_cap[tier])

static func raw_total(pressure: int, w: int, wb: WaveBalance) -> int:
	return int(round(wb.base_counts[w] * (1.0 + wb.count_growth * (pressure - 1))))

static func total_count(pressure: int, w: int, wb: WaveBalance) -> int:
	return mini(raw_total(pressure, w, wb), wb.max_wave_size)

static func hp_mult(pressure: int, w: int, wb: WaveBalance) -> float:
	var m := 1.0 + wb.hp_growth * (pressure - 1)
	var raw := raw_total(pressure, w, wb)
	if raw > wb.max_wave_size:
		m *= float(raw) / float(wb.max_wave_size)
	return m

static func side_share(pressure: int, wb: WaveBalance) -> float:
	if pressure < 2:
		return 0.0
	return minf(wb.side_share_base + wb.side_share_step * (pressure - 2), wb.side_share_cap)

static func split(pressure: int, w: int, wb: WaveBalance) -> Dictionary:
	var total := total_count(pressure, w, wb)
	var side := 0
	if pressure >= 2:
		side = maxi(1, int(round(total * side_share(pressure, wb))))
	return {"main": total - side, "side": side}
```

`core/lane_planner.gd` `plan`:

```gdscript
## E5 (spec 4.1, 4.2): the lanes come from the day's stream exactly as before (so a save keeps its lane order); the
## counts and hp_mult come from the pressure; the hare counts from the tier's ramp. Defaults = tier 1 = today's plan.
static func plan(run_seed: int, day: int, wb: WaveBalance, tier := 1, tier_day := 1, tb: TierBalance = null) -> Array:
	if tb == null:
		tb = Balance.data.tiers
	var pressure := WaveMath.pressure(day, tier, tier_day, tb)
	var share := TierEffects.fast_share_now(day, tier, tier_day, tb)
	var rng := Rng.stream(run_seed, day, &"lane_plan")
	var waves: Array = []
	for w in wb.base_counts.size():
		var main := ""
		if day == 1 and w == 0:
			main = "north"
		else:
			main = LANES[rng.randi_range(0, LANES.size() - 1)]
		var counts := WaveMath.split(pressure, w, wb)
		var side := ""
		if int(counts.side) > 0:
			var others: Array = LANES.filter(func(l): return l != main)
			side = others[rng.randi_range(0, others.size() - 1)]
		var fast := TierEffects.fast_counts(int(counts.main), int(counts.side), share)
		waves.append({
			"main": main, "side": side,
			"main_count": int(counts.main), "side_count": int(counts.side),
			"hp_mult": WaveMath.hp_mult(pressure, w, wb),
			"fast_main": int(fast.fast_main), "fast_side": int(fast.fast_side), "boss": false,
		})
	return waves

## A deep copy of `plan_waves` whose last wave carries the boss (E5 spec 4.2; the boss night is the capped night + 1).
static func with_boss(plan_waves: Array) -> Array:
	var out: Array = plan_waves.duplicate(true)
	if not out.is_empty():
		out[out.size() - 1].boss = true
	return out
```

Keep `threat_by_lane` as it is and add the boss term so the telegraph flag reads the boss lane (spec 3):

```gdscript
static func threat_by_lane(plan_waves: Array, base_hp: float) -> Dictionary:
	var t := {"west": 0.0, "north": 0.0, "east": 0.0}
	for wave in plan_waves:
		var hp := base_hp * float(wave.hp_mult)
		t[wave.main] += int(wave.main_count) * hp
		if String(wave.side) != "":
			t[wave.side] += int(wave.side_count) * hp
		if bool(wave.get("boss", false)):
			t[wave.main] += Balance.data.monsters.stats(&"boss").hp * float(wave.hp_mult)
	return t
```

(`threat_by_lane` reading `Balance.data` keeps `core/` pure of scene access; it already reads `Balance` elsewhere.)

`core/wave_schedule.gd` `build`:

```gdscript
## E5 (spec 4.2): entries carry `kind`. The last fast_main / fast_side entries of each group are hares (they spawn behind
## the boars and overtake them). A boss wave puts one &"boss" entry first at t = 0 and shifts the rest by boss_lead.
## A wave without the new keys (a schema 4 plan before its first dawn) is all boars.
static func build(wave: Dictionary, wb: WaveBalance, tb: TierBalance = null) -> Array:
	var out: Array = []
	var main_n := int(wave.main_count)
	var side_n := int(wave.side_count)
	var fast_main := int(wave.get("fast_main", 0))
	var fast_side := int(wave.get("fast_side", 0))
	var boss := bool(wave.get("boss", false))
	var lead := 0.0
	if boss:
		if tb == null:
			tb = Balance.data.tiers
		lead = tb.boss_lead
		out.append({"t": 0.0, "lane": String(wave.main), "side": false, "kind": &"boss"})
	for i in main_n:
		var kind: StringName = &"hare" if i >= main_n - fast_main else &"boar"
		out.append({"t": lead + i * wb.spawn_interval, "lane": String(wave.main), "side": false, "kind": kind})
	for i in side_n:
		var kind: StringName = &"hare" if i >= side_n - fast_side else &"boar"
		out.append({"t": lead + wb.side_group_delay + i * wb.spawn_interval, "lane": String(wave.side), "side": true, "kind": kind})
	out.sort_custom(func(a, b):
		if not is_equal_approx(a.t, b.t):
			return a.t < b.t
		return not a.side and b.side)
	return out
```

**Wiring note (hot file, not committed by this task):** `autoload/GameState.gd` `new_game` and `advance_day` call
`LanePlanner.plan(run_seed, day, Balance.data.wave)`; both work unchanged (defaults). Task 4 changes them to pass the
tier. No edit here.

- [ ] **Step 4: Run the unit suite and the baseline**

Run: `./run_tests.sh unit && tools/baseline_diff.sh`
Expected: PASS and `baseline identical` (defaults are tier 1; days 1 to 14 of the planner are unchanged until
`GameState` passes the tier in Task 4).

- [ ] **Step 5: Commit**

```bash
git add core/wave_math.gd core/lane_planner.gd core/wave_schedule.gd tests/unit/test_wave_math.gd tests/unit/test_lane_planner.gd tests/unit/test_wave_schedule.gd
git commit -m "feat(e5): WaveMath.pressure, hare counts and the boss entry in the lane plan and schedule"
```

### Task 4: Tier state in GameState and the EventBus signals

Spec 6.1, 6.2.

**Files:**
- Modify: `autoload/GameState.gd` (main purpose), `autoload/EventBus.gd` (main purpose)
- Test: `tests/unit/test_game_state_tier.gd`

**Interfaces:**
- Consumes: `TierEffects`, `MapLayout.spots_for_tier`, `MapLayout.TIER_SPOTS`, `LanePlanner.plan(..., tier, tier_day, tb)`,
  `LanePlanner.with_boss`.
- Produces:
  ```gdscript
  GameState.tier: int, tier_day: int, tier_paid: int, boss_pending: bool
  GameState.tier_next_cost() -> int          # -1 at the top tier this build knows
  GameState.tier_remaining_cost() -> int     # -1 at the top
  GameState.pay_into_tier(amount: int) -> int
  GameState.complete_tier_up() -> void
  GameState.debug_set_tier(tier: int, day_entered: int) -> void
  GameState.pressure() -> int
  GameState.is_boss_night() -> bool          # lane_plan's last wave carries boss
  EventBus.tier_changed(tier: int, paid: int, boss_pending: bool)
  EventBus.tier_paid_up(next_tier: int)
  EventBus.tier_reached(tier: int)
  ```
- `advance_day` plans with the tier and, when `boss_pending`, marks the plan with `with_boss`. `new_game` plans at
  tier 1 (identical to today). `to_dict` / `from_dict` carry the four fields (schema 5 is Task 5; this task bumps
  `SCHEMA_VERSION` to 5 and `from_dict` asserts it; `SaveCodec` catches up in Task 5, so between the two tasks
  `test_save_codec.gd` and the fixture tests fail. **Run Tasks 4 and 5 back to back on the same branch; Task 4's
  commit is allowed to leave those tests red and says so in its message.**)

- [ ] **Step 1: Write the failing test**

`tests/unit/test_game_state_tier.gd`:

```gdscript
extends GutTest
## E5 spec 6.1: tier state, the sign payment, the tier-up.

var _events: Array = []

func before_each() -> void:
	Balance.reset()
	_events.clear()
	GameState.new_game(20260930)
	EventBus.tier_changed.connect(_on_changed)
	EventBus.tier_paid_up.connect(_on_paid_up)
	EventBus.tier_reached.connect(_on_reached)
	EventBus.gold_changed.connect(_on_gold)

func after_each() -> void:
	EventBus.tier_changed.disconnect(_on_changed)
	EventBus.tier_paid_up.disconnect(_on_paid_up)
	EventBus.tier_reached.disconnect(_on_reached)
	EventBus.gold_changed.disconnect(_on_gold)

func _on_changed(t: int, p: int, b: bool) -> void: _events.append(["changed", t, p, b])
func _on_paid_up(n: int) -> void: _events.append(["paid_up", n])
func _on_reached(t: int) -> void: _events.append(["reached", t])
func _on_gold(g: int, d: int) -> void: _events.append(["gold", g, d])

func test_new_game_is_tier_1() -> void:
	assert_eq([GameState.tier, GameState.tier_day, GameState.tier_paid, GameState.boss_pending], [1, 1, 0, false])
	assert_eq(GameState.buildings.keys(), MapLayout.spots_for_tier(1))
	assert_eq(GameState.tier_next_cost(), 500)
	assert_eq(GameState.tier_remaining_cost(), 500)
	assert_eq(GameState.pressure(), 1)
	assert_false(GameState.is_boss_night())

func test_partial_payment_is_capped_by_gold() -> void:
	GameState.add_gold(40)
	_events.clear()
	assert_eq(GameState.pay_into_tier(100), 40)
	assert_eq([GameState.gold, GameState.tier_paid, GameState.boss_pending], [0, 40, false])
	assert_eq(GameState.tier_remaining_cost(), 460)
	assert_eq(_events, [["gold", 0, -40], ["changed", 1, 40, false]])

func test_completing_the_payment_flags_the_boss_night_once() -> void:
	GameState.add_gold(600)
	GameState.pay_into_tier(450)
	_events.clear()
	assert_eq(GameState.pay_into_tier(100), 50, "only the remaining 50 is taken")
	assert_eq([GameState.gold, GameState.tier_paid, GameState.boss_pending, GameState.tier], [100, 0, true, 1])
	assert_eq(_events, [["gold", 100, -50], ["changed", 1, 0, true], ["paid_up", 2]])
	_events.clear()
	assert_eq(GameState.pay_into_tier(100), 0, "nothing more is taken while the boss is pending")
	assert_eq(_events, [])
	assert_eq(GameState.tier_remaining_cost(), 0, "paid in full: remaining 0 until the tier-up")

func test_advance_day_plans_the_boss_night_when_pending() -> void:
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	GameState.advance_day()
	assert_true(GameState.is_boss_night())
	assert_eq(GameState.lane_plan.map(func(w): return w.boss), [false, false, true])
	assert_eq(GameState.pressure(), 2, "the boss night runs at the tier's own pressure (day 2 of tier 1 here)")

func test_complete_tier_up_adds_the_spots_and_replans() -> void:
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	for i in 8:
		GameState.advance_day()  # day 9, pressure capped at 7
	assert_eq(GameState.pressure(), 7)
	_events.clear()
	GameState.complete_tier_up()
	assert_eq([GameState.tier, GameState.tier_day, GameState.boss_pending, GameState.tier_paid], [2, 9, false, 0])
	assert_eq(GameState.buildings.keys(), MapLayout.spots_for_tier(2))
	assert_eq(GameState.buildings["tower_w"], {"level": 0, "paid": 0, "hp": 0.0})
	assert_eq(GameState.pressure(), 8, "tier 2 starts at its base")
	assert_eq(_events.slice(0, 2), [["changed", 2, 0, false], ["reached", 2]].slice(0, 0) + [["changed", 2, 0, false]], "tier_changed first")
	assert_true(_events.has(["reached", 2]))
	assert_eq(GameState.tier_next_cost(), -1, "tier 2 is the top of this build")
	assert_eq(GameState.tier_remaining_cost(), -1)
	assert_false(GameState.is_boss_night(), "the next plan has no boss")
	assert_eq(GameState.pay_into_tier(100), 0, "nothing to buy at the top")

func test_complete_tier_up_emits_building_changed_for_each_new_spot() -> void:
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	watch_signals(EventBus)
	GameState.complete_tier_up()
	assert_signal_emitted_with_parameters(EventBus, "building_changed", [&"tower_w", 0, 0], 0)
	assert_signal_emit_count(EventBus, "building_changed", 2)

func test_snapshot_round_trip_carries_the_tier() -> void:
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	GameState.complete_tier_up()
	GameState.add_gold(70)
	var d := GameState.to_dict()
	assert_eq(int(d.v), 5)
	assert_eq([d.tier, d.tier_day, d.tier_paid, d.boss_pending], [2, 1, 0, false])
	assert_true(d.buildings.has("tower_e"))
	GameState.new_game(5)
	GameState.from_dict(d)
	assert_eq([GameState.tier, GameState.tier_day, GameState.tier_paid, GameState.boss_pending, GameState.gold], [2, 1, 0, false, 70])
	assert_eq(GameState.buildings.keys(), MapLayout.spots_for_tier(2))
	assert_eq(GameState.to_dict(), d)

func test_from_dict_clamps_a_tier_above_the_top() -> void:
	var d := GameState.to_dict()
	d.tier = 4   # a later build's save
	d.tier_day = 1
	GameState.from_dict(d)
	assert_eq(GameState.tier, TierEffects.top_tier(Balance.data.tiers))
	assert_eq(GameState.tier_next_cost(), -1)

func test_debug_set_tier() -> void:
	GameState.debug_set_tier(2, 9)
	assert_eq([GameState.tier, GameState.tier_day, GameState.boss_pending], [2, 9, false])
	assert_eq(GameState.buildings.keys(), MapLayout.spots_for_tier(2))
	assert_eq(GameState.pressure(), 8 if GameState.day == 9 else WaveMath.pressure(GameState.day, 2, 9, Balance.data.tiers))

func test_pay_before_the_first_new_game_window_does_nothing() -> void:
	# GameState.buildings is emptied here to mimic the warm-up window: no new_game yet.
	GameState.buildings = {}  # test-only setup
	GameState.gold = 900      # test-only setup
	assert_eq(GameState.pay_into_tier(10), 0)
	assert_eq(GameState.gold, 900)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_game_state_tier.gd -gexit`
Expected: FAIL (`tier` not found).

- [ ] **Step 3: Implement**

`autoload/EventBus.gd`, after `station_upgraded`:

```gdscript
## E5: GameState -> TierSign, CloseUpSign (pulse), Autosave (dirty). The sign's paid amount or the boss flag changed.
signal tier_changed(tier: int, paid: int, boss_pending: bool)
## E5: GameState -> Autosave (write), AudioDirector, Reactions. The tier-up is paid in full; next_tier arrives after the boss.
signal tier_paid_up(next_tier: int)
## E5: GameState -> World (yards, spots, diner), TierReveal, HUD, Autosave, AudioDirector, TierBot. Emitted after
## building_changed for each new spot, at the dawn after a won boss night.
signal tier_reached(tier: int)
```

`autoload/GameState.gd`:

```gdscript
const SCHEMA_VERSION := 5

## E5: the diner tier (spec 6.1). tier_day = the day the tier was entered; tier_paid = the sign's partial payment;
## boss_pending = paid in full, the coming night is a boss night.
var tier := 1
var tier_day := 1
var tier_paid := 0
var boss_pending := false
```

In `new_game`, replace the `buildings` loop and the plan line:

```gdscript
	tier = 1
	tier_day = 1
	tier_paid = 0
	boss_pending = false
	buildings = {}
	for id in MapLayout.spots_for_tier(tier):
		buildings[id] = {"level": 0, "paid": 0, "hp": 0.0}
	...
	lane_plan = _plan_today()
```

`to_dict`: add `"tier": tier, "tier_day": tier_day, "tier_paid": tier_paid, "boss_pending": boss_pending,` and carry
the three new wave keys in `from_dict`'s lane_plan loop:

```gdscript
		lane_plan.append({
			"main": String(w.main), "side": String(w.side),
			"main_count": int(w.main_count), "side_count": int(w.side_count), "hp_mult": float(w.hp_mult),
			"fast_main": int(w.get("fast_main", 0)), "fast_side": int(w.get("fast_side", 0)), "boss": bool(w.get("boss", false)),
		})
```

`from_dict`, before the `buildings` loop (the clamp is spec 6.3's rule; `SaveCodec` validates the range in Task 5):

```gdscript
	tier = clampi(int(d.tier), 1, TierEffects.top_tier(Balance.data.tiers))
	tier_day = int(d.tier_day)
	boss_pending = bool(d.boss_pending)
	var tcost := TierEffects.tier_cost(tier, Balance.data.tiers)
	# A paid amount at or above the cost would never complete (D-231's rule for pads); 0 at the top or while pending.
	tier_paid = 0 if (tcost < 0 or boss_pending) else clampi(int(d.tier_paid), 0, maxi(tcost - 1, 0))
```

New section after the buildings section:

```gdscript
# --- diner tier (E5) --------------------------------------------------------

func _plan_today() -> Array:
	var p := LanePlanner.plan(run_seed, day, Balance.data.wave, tier, tier_day, Balance.data.tiers)
	return LanePlanner.with_boss(p) if boss_pending else p

func pressure() -> int:
	return WaveMath.pressure(day, tier, tier_day, Balance.data.tiers)

func is_boss_night() -> bool:
	return not lane_plan.is_empty() and bool(lane_plan[lane_plan.size() - 1].get("boss", false))

## -1 when this build has no next tier. Also -1 before the first new_game (buildings is empty while the world warms up).
func tier_next_cost() -> int:
	if buildings.is_empty():
		return -1
	return TierEffects.tier_cost(tier, Balance.data.tiers)

## 0 once paid in full (boss pending), -1 at the top.
func tier_remaining_cost() -> int:
	var cost := tier_next_cost()
	if cost < 0:
		return -1
	return 0 if boss_pending else cost - tier_paid

## The tier sign's stand-still payment. Same rule as pads and spots (_pay_towards). Nothing while the boss is pending.
func pay_into_tier(amount: int) -> int:
	var cost := tier_next_cost()
	if cost < 0 or boss_pending:
		return 0
	var entry := {"paid": tier_paid}
	var pay := _pay_towards(entry, cost, amount)
	if pay <= 0:
		return 0
	tier_paid = int(entry.paid)
	if tier_paid >= cost:
		tier_paid = 0
		boss_pending = true
		EventBus.tier_changed.emit(tier, tier_paid, boss_pending)
		EventBus.tier_paid_up.emit(tier + 1)
	else:
		EventBus.tier_changed.emit(tier, tier_paid, boss_pending)
	return pay

## Dawn after a won boss night (PhaseController, after advance_day). No-op at the top (a clamped save).
func complete_tier_up() -> void:
	assert(boss_pending, "complete_tier_up without a pending boss")
	boss_pending = false
	tier_paid = 0
	if tier >= TierEffects.top_tier(Balance.data.tiers):
		lane_plan = _plan_today()
		EventBus.tier_changed.emit(tier, 0, false)
		return
	tier += 1
	tier_day = day
	for id in MapLayout.TIER_SPOTS.get(tier, []):
		buildings[id] = {"level": 0, "paid": 0, "hp": 0.0}
		EventBus.building_changed.emit(StringName(id), 0, 0)
	lane_plan = _plan_today()
	EventBus.tier_changed.emit(tier, 0, false)
	EventBus.tier_reached.emit(tier)

## Tests, sims and fixtures only: jump to a tier as if it had been entered on `day_entered`.
func debug_set_tier(p_tier: int, day_entered: int) -> void:
	tier = clampi(p_tier, 1, TierEffects.top_tier(Balance.data.tiers))
	tier_day = maxi(day_entered, 1)
	tier_paid = 0
	boss_pending = false
	for id in MapLayout.spots_for_tier(tier):
		if not buildings.has(id):
			buildings[id] = {"level": 0, "paid": 0, "hp": 0.0}
	lane_plan = _plan_today()
	EventBus.tier_changed.emit(tier, 0, false)
```

`advance_day`:

```gdscript
func advance_day() -> void:
	day += 1
	lane_plan = _plan_today()
```

- [ ] **Step 4: Run the new test, then the unit suite**

Run: the Task 4 test, then `./run_tests.sh unit`.
Expected: the new test PASSES. `test_save_codec.gd`, `test_save_store.gd`, `test_perf_fixture.gd`,
`test_lighting_director.gd`, `test_resume.gd` and `test_save_stations.gd` may FAIL on the schema bump (`v` 5 against
`STATE_KEYS` and the built-in table): that is Task 5's work. Every other test passes. Record the failing list in the
commit message.

- [ ] **Step 5: Commit**

```bash
git add autoload/GameState.gd autoload/EventBus.gd tests/unit/test_game_state_tier.gd*
git commit -m "feat(e5): tier state, sign payment and tier-up in GameState; tier signals

Schema 5 lands in the next commit (SaveCodec); until then the save tests are red: <list>."
```

### Task 5: Save schema 5

Spec 6.3.

**Files:**
- Modify: `core/save_codec.gd`
- Test: `tests/unit/test_save_tier.gd`, `tests/unit/test_save_codec.gd` (the "no step registered" assertion and the
  literal `3`/`4` references), `tests/unit/test_perf_fixture.gd` (nothing to change: the fixtures migrate 3 → 4 → 5)

**Interfaces:**
- Consumes: `GameState.SCHEMA_VERSION` 5, `MapLayout.ALL_SPOT_IDS`, `MapLayout.spots_for_tier`, `TierBalance.max_tier`.
- Produces: `SaveCodec.STATE_KEYS` with the four tier keys; `_built_in(4, state)`; validation rules below.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_save_tier.gd`:

```gdscript
extends GutTest
## E5 spec 6.3: schema 5, the 4 -> 5 step, tier validation, the tier clamp.

func before_each() -> void:
	Balance.reset()
	SaveCodec.MIGRATIONS.clear()
	GameState.new_game(20260930)

func _v4_state(day := 12) -> Dictionary:
	# a schema 4 state as E1 wrote it: no tier keys, lane_plan without fast_*/boss
	var s := GameState.to_dict()
	s.v = 4
	s.day = day
	for k in ["tier", "tier_day", "tier_paid", "boss_pending"]:
		s.erase(k)
	for w in s.lane_plan:
		for k in ["fast_main", "fast_side", "boss"]:
			w.erase(k)
	return s

func _decode(s: Dictionary) -> Dictionary:
	return SaveCodec.decode(SaveCodec.encode(s, "t", 0), GameState.SCHEMA_VERSION, Balance.data)

func test_schema_4_migrates_to_5_at_tier_1() -> void:
	var r := _decode(_v4_state(12))
	assert_true(r.ok, r.reason)
	assert_eq([r.state.v, r.state.tier, r.state.tier_day, r.state.tier_paid, r.state.boss_pending], [5, 1, 1, 0, false])
	assert_eq(r.state.buildings.keys(), MapLayout.spots_for_tier(1))
	for w in r.state.lane_plan:
		assert_eq([w.fast_main, w.fast_side, w.boss], [0, 0, false])
	assert_eq(int(r.state.day), 12, "a day-12 tier-1 save keeps its day; it meets day-7 pressure from its next dawn")

func test_built_in_step_survives_a_cleared_hook_table() -> void:
	SaveCodec.MIGRATIONS.clear()
	assert_true(_decode(_v4_state()).ok)

func test_round_trip_at_tier_2() -> void:
	GameState.debug_set_tier(2, 9)
	GameState.add_gold(70)
	var r := _decode(GameState.to_dict())
	assert_true(r.ok, r.reason)
	assert_eq(r.state.tier, 2)
	assert_true(r.state.buildings.has("tower_w"))

func test_rejects_bad_tier_fields() -> void:
	var bad := [
		["tier", 0, "range tier"], ["tier", Balance.data.tiers.max_tier + 1, "range tier"], ["tier", "two", "type tier"],
		["tier_day", 0, "range tier_day"], ["tier_day", 99, "range tier_day"],
		["tier_paid", -1, "range tier_paid"], ["boss_pending", 1, "type boss_pending"],
	]
	for b in bad:
		var s := GameState.to_dict()
		s[b[0]] = b[1]
		assert_eq(SaveCodec.validate(s, Balance.data), b[2], str(b))
	var missing := GameState.to_dict()
	missing.erase("tier_paid")
	assert_eq(SaveCodec.validate(missing, Balance.data), "missing tier_paid")

func test_rejects_spot_tier_mismatches() -> void:
	var s := GameState.to_dict()  # tier 1
	s.buildings["tower_w"] = {"level": 0, "paid": 0, "hp": 0.0}
	assert_eq(SaveCodec.validate(s, Balance.data), "building tier tower_w", "a tier-2 spot in a tier-1 save")
	GameState.debug_set_tier(2, 1)
	var s2 := GameState.to_dict()
	s2.buildings.erase("tower_e")
	assert_eq(SaveCodec.validate(s2, Balance.data), "missing building tower_e")
	s2 = GameState.to_dict()
	s2.buildings["castle"] = {"level": 0, "paid": 0, "hp": 0.0}
	assert_eq(SaveCodec.validate(s2, Balance.data), "building castle")

func test_rejects_bad_wave_keys() -> void:
	var s := GameState.to_dict()
	s.lane_plan[0].fast_main = int(s.lane_plan[0].main_count) + 1
	assert_eq(SaveCodec.validate(s, Balance.data), "lane fast")
	s = GameState.to_dict()
	s.lane_plan[0].boss = true
	assert_eq(SaveCodec.validate(s, Balance.data), "lane boss", "the boss only rides the last wave")
	s = GameState.to_dict()
	s.lane_plan[2].boss = true
	assert_eq(SaveCodec.validate(s, Balance.data), "", "a boss in the last wave is fine without boss_pending (fixtures)")
	s = GameState.to_dict()
	s.lane_plan[0].erase("boss")
	assert_eq(SaveCodec.validate(s, Balance.data), "lane_plan fields")

func test_tier_above_the_top_is_clamped_only_when_its_spots_are_known() -> void:
	var s := GameState.to_dict()
	s.tier = 3
	s.tier_day = 1
	assert_eq(SaveCodec.validate(s, Balance.data), "", "tier 3 is below max_tier: accepted, GameState clamps it")
	var r := _decode(s)
	assert_true(r.ok)
	GameState.from_dict(r.state)
	assert_eq(GameState.tier, 2)

func test_paid_at_or_above_cost_is_clamped_on_load() -> void:
	var s := GameState.to_dict()
	s.tier_paid = 500
	var r := _decode(s)
	assert_true(r.ok, r.reason)
	GameState.from_dict(r.state)
	assert_eq(GameState.tier_paid, 499)
	assert_false(GameState.boss_pending)

func test_schema_3_fixtures_still_load() -> void:
	for stem in ["night3_start", "night3_closeup", "day3_counter5"]:
		var text := FileAccess.get_file_as_string("res://export/fixtures/%s.save.json" % stem)
		var r := SaveCodec.decode(text, GameState.SCHEMA_VERSION, Balance.data)
		assert_true(r.ok, "%s: %s" % [stem, r.reason])
		assert_eq([r.state.v, r.state.tier], [5, 1])
```

- [ ] **Step 2: Run it to verify it fails**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_save_tier.gd -gexit`
Expected: FAIL ("missing tier" from `validate`, the 4 → 5 step missing).

- [ ] **Step 3: Implement**

`core/save_codec.gd`:

```gdscript
const STATE_KEYS := ["v", "resume_phase", "run_seed", "day", "gold", "gold_pile", "freezer_steaks",
	"counter_steaks", "carried_steaks", "diner_hp", "buildings", "lane_plan", "cards", "card_offer", "guards",
	"night_fails", "stations", "tier", "tier_day", "tier_paid", "boss_pending"]
```

`_built_in`:

```gdscript
static func _built_in(from_v: int, state: Dictionary) -> Variant:
	match from_v:
		3:  # E1: station upgrades
			state.stations = fresh_stations()
			state.v = 4
			return state
		4:  # E5: the diner tier. A tier-1 save keeps its day; its next dawn re-plans at the tier-1 cap (D-237).
			state.tier = 1
			state.tier_day = 1
			state.tier_paid = 0
			state.boss_pending = false
			for w in state.get("lane_plan", []):
				if typeof(w) == TYPE_DICTIONARY:
					w.fast_main = 0
					w.fast_side = 0
					w.boss = false
			state.v = 5
			return state
	return null
```

`validate`, in the numeric-type loop add `"tier", "tier_day", "tier_paid"`; then after the `range` check:

```gdscript
	if typeof(s.boss_pending) != TYPE_BOOL:
		return "type boss_pending"
	var tier := int(s.tier)
	if tier < 1 or tier > bd.tiers.max_tier:
		return "range tier"
	if int(s.tier_day) < 1 or int(s.tier_day) > int(s.day):
		return "range tier_day"
	if int(s.tier_paid) < 0:
		return "range tier_paid"
	var known_tier := mini(tier, TierEffects.top_tier(bd.tiers))  # GameState clamps the tier on load (spec 6.3)
```

Replace the two `SPOT_IDS` checks in the buildings section:

```gdscript
	for id in s.buildings:
		if not String(id) in MapLayout.ALL_SPOT_IDS:
			return "building " + str(id)
		if MapLayout.spot_tier(String(id)) > known_tier:
			return "building tier " + str(id)
		...
	for id in MapLayout.spots_for_tier(known_tier):
		if not s.buildings.has(id):
			return "missing building " + str(id)
```

In the lane_plan loop, extend the field check and add the two rules:

```gdscript
		if typeof(w) != TYPE_DICTIONARY or not w.has_all(["main", "side", "main_count", "side_count", "hp_mult", "fast_main", "fast_side", "boss"]):
			return "lane_plan fields"
		...
		for f in ["fast_main", "fast_side"]:
			if not typeof(w[f]) in [TYPE_INT, TYPE_FLOAT] or int(w[f]) < 0:
				return "lane fields"
		if int(w.fast_main) > int(w.main_count) or int(w.fast_side) > int(w.side_count):
			return "lane fast"
		if typeof(w.boss) != TYPE_BOOL:
			return "lane fields"
	for i in s.lane_plan.size() - 1:
		if bool(s.lane_plan[i].boss):
			return "lane boss"
```

`tests/unit/test_save_codec.gd`: the test around line 122 ("no step registered for `SCHEMA_VERSION - 1`") registers a
hook for version 4 that does not raise `v`; it still passes (a hook overrides the built-in). Update the literal `3` in
lines 38 to 40 to `GameState.SCHEMA_VERSION - 2` where it means "two versions back" and leave comments current (E1
follow-up 24 is folded in here).

- [ ] **Step 4: Run the unit suite**

Run: `./run_tests.sh unit && tools/baseline_diff.sh`
Expected: PASS, `baseline identical` (the planner sims still run tier 1, days 1 to 3).

- [ ] **Step 5: Commit**

```bash
git add core/save_codec.gd tests/unit/test_save_tier.gd* tests/unit/test_save_codec.gd
git commit -m "feat(e5): save schema 5 with the 4 to 5 step, tier validation and the tier clamp"
```

**Phase 1 gate (main session):** `./run_tests.sh all` green, `tools/baseline_diff.sh` prints `baseline identical`,
every task reviewed, PR `e5/p1-core` self-merged (D-137).

---

# Phase 2: `e5/p2-night`

### Task 6: Monster kinds, per-kind priority, boss and hare spawns

Spec 4.3, 7.1 (gameplay half).

**Files:**
- Modify: `actors/enemy/boar.gd`, `world/target_providers.gd`, `world/wave_director.gd`, `world/guard_roster.gd`
- Modify: `autoload/EventBus.gd` (main purpose: `enemy_killed` gains `kind`)
- Modify: `world/fx/reactions.gd`, `world/audio/audio_director.gd`, `tests/sim/sim_harness.gd` (the `enemy_killed`
  listeners take the 4th argument), `tests/unit/test_audio_director.gd:33`, `tests/unit/test_reactions.gd:32`
- Modify: `world/world.gd` → **wiring note** (`pool_sizes`: the steak pool for the tier-2 night plus the boss drop)
- Test: `tests/unit/test_monster_kinds.gd`, `tests/unit/test_wave_director.gd` (add)

**Interfaces:**
- Consumes: `MonsterBalance.stats(kind)`, `WaveSchedule.build(..., tb)` entries with `kind`.
- Produces:
  ```gdscript
  Boar.kind: StringName                                    # set by spawn; default &"boar"
  Boar.stats() -> MonsterStats
  Boar.spawn(lane, index, offset, hp_mult, director, kind := &"boar")
  TargetProviders.has_kind(kind: StringName, enemy) -> bool   # registered AND in the enemy's priority
  TargetProviders.find_target(enemy) -> Dictionary            # iterates enemy.stats().priority
  TargetProviders.fence_stop_dist(enemy) -> float             # uses enemy.stats().reach
  WaveDirector._spawn(lane, unit_offset, hp_mult := -1.0, kind := &"boar") -> Boar
  WaveDirector.debug_spawn(lane, unit_offset := 0.0, hp_mult := 1.0, kind := &"boar") -> Boar
  WaveDirector.boss_alive() -> bool
  EventBus.enemy_killed(spawn_index: int, lane: StringName, position: Vector3, kind: StringName)
  World.pool_sizes(bd) -> {"enemy", "steak", "projectile", "fx"}   # steak grows (wiring note)
  ```
- `GuardRoster.guard_target` uses the enemy's reach (`enemy.stats().reach`), so the boss (1.6) hits the Tank from
  farther. Hero and tower targeting are unchanged (`candidate()`).

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_monster_kinds.gd`:

```gdscript
extends GutTest
## E5 spec 4.3, 7.1: one scene per monster; the kind picks the stats and the target list (D-148 for the hare).

class FakeDirector:
	extends RefCounted
	var providers := TargetProviders.new()
	var died: Array = []
	func _init() -> void:
		providers.register(&"fence_on_lane", func(e): return TargetProviders.fence_on_lane(e))
		providers.register(&"diner", func(e): return TargetProviders.diner(e))
	func on_enemy_died(b) -> void:
		died.append([b.spawn_index, b.kind])

const DT := 1.0 / 60.0
var dir: FakeDirector

func before_each() -> void:
	Balance.reset()
	GameState.new_game(7)
	dir = FakeDirector.new()

func _monster(kind: StringName, lane := "north", index := 0) -> Boar:
	var b := Boar.new()
	b.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(b)
	b.spawn(lane, index, 0.0, 1.0, dir, kind)
	return b

func _step(b: Boar, seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		b._physics_process(DT)

func _build_fence_n() -> void:
	GameState.add_gold(GameState.next_level_cost("fence_n"))
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n"))

func test_default_kind_is_boar_and_stats_follow_the_kind() -> void:
	var b := Boar.new()
	add_child_autofree(b)
	assert_eq(b.kind, &"boar")
	var h := _monster(&"hare")
	assert_eq(h.stats().speed, 3.6)
	assert_almost_eq(h.health.max_hp, 15.0, 1e-6)
	var boss := _monster(&"boss")
	assert_almost_eq(boss.health.max_hp, 800.0, 1e-6)

func test_hp_mult_and_mercy_apply_to_every_kind() -> void:
	GameState.set_night_fails(1)
	var h := Boar.new()
	h.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(h)
	h.spawn("north", 0, 0.0, 1.9, dir, &"hare")
	assert_almost_eq(h.health.max_hp, 15.0 * 1.9, 1e-6, "spawn() takes the already-merged multiplier, as WaveDirector passes it")

func test_hare_walks_past_a_standing_fence_and_a_boar_stops() -> void:
	_build_fence_n()
	var hare := _monster(&"hare", "north", 0)
	var boar := _monster(&"boar", "north", 1)
	var walk := MapLayout.path_length("north") / Balance.data.monsters.stats(&"hare").speed
	_step(hare, walk + 0.2)
	_step(boar, MapLayout.path_length("north") / Balance.data.enemy.speed + 0.2)
	assert_true(hare.at_path_end(), "the hare reached the diner")
	var stop := boar.path_length() - MapLayout.FENCE_OFFSET_FROM_END - Balance.data.enemy.reach
	assert_almost_eq(boar.dist, stop, 0.05, "the boar stopped at the fence")
	var hp0 := GameState.diner_hp
	var fence0 := float(GameState.buildings.fence_n.hp)
	_step(hare, 1.0)
	_step(boar, 1.0)
	assert_almost_eq(hp0 - GameState.diner_hp, 4.0, 1e-4, "the hare hits the diner for its own damage")
	assert_lt(float(GameState.buildings.fence_n.hp), fence0, "the boar hits the fence")

func test_hare_keeps_the_diner_when_the_fence_falls() -> void:
	_build_fence_n()
	var hare := _monster(&"hare")
	_step(hare, MapLayout.path_length("north") / 3.6 + 0.2)
	assert_eq(hare.current_target.kind, &"diner")
	GameState.damage_fence("fence_n", 1e9)
	_step(hare, 0.1)
	assert_eq(hare.current_target.kind, &"diner", "Review Focus 5: no retarget")

func test_boss_breaks_a_fence_by_raw_damage() -> void:
	_build_fence_n()
	var boss := _monster(&"boss")
	var stop := boss.path_length() - MapLayout.FENCE_OFFSET_FROM_END - 1.6
	_step(boss, stop / 1.2 + 0.2)
	assert_almost_eq(boss.dist, stop, 0.05, "the boss stops at its own reach")
	var fence0 := float(GameState.buildings.fence_n.hp)
	_step(boss, 1.0)
	assert_almost_eq(fence0 - float(GameState.buildings.fence_n.hp), 15.0, 1e-4)

func test_unknown_kind_asserts() -> void:
	assert_false(Balance.data.monsters.has_kind(&"dragon"))  # Boar.spawn asserts on it; GUT cannot catch asserts, so the guard is tested here
```

Append to `tests/unit/test_wave_director.gd` (it already builds a `Main` with a `WaveDirector`; reuse its helpers):

```gdscript
func test_boss_wave_spawns_the_boss_first_and_reports_it_alive() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	GameState.new_game(20260930)
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	GameState.advance_day()
	var wd := main.world.wave_director
	wd.start_night(GameState.lane_plan)
	wd._start_wave(2)  # jump to the boss wave
	await get_tree().physics_frame
	var alive := wd.alive_enemies()
	assert_eq(alive.size(), 1, "only the boss at t = 0")
	assert_eq((alive[0] as Boar).kind, &"boss")
	assert_true(wd.boss_alive())
	for i in int(ceil(Balance.data.tiers.boss_lead * 60.0)) + 2:
		await get_tree().physics_frame
	assert_gt(wd.alive_count(), 1, "the wave's boars follow after boss_lead")

func test_enemy_killed_carries_the_kind_and_the_boss_drops_its_pile() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	GameState.new_game(20260930)
	var wd := main.world.wave_director
	wd.start_night(GameState.lane_plan)
	var got: Array = []
	var cb := func(i, l, p, k): got.append([i, k])
	EventBus.enemy_killed.connect(cb)
	var boss := wd.debug_spawn("north", 0.0, 1.0, &"boss")
	boss.take_hit(1e9)
	await get_tree().physics_frame
	EventBus.enemy_killed.disconnect(cb)
	assert_eq(got, [[boss.spawn_index, &"boss"]])
	assert_eq(main.world.steak_pool.active().size(), Balance.data.monsters.stats(&"boss").steaks_per_kill)
	for s in main.world.steak_pool.active():
		var d := Vector2((s as Node3D).position.x - boss.position.x, (s as Node3D).position.z - boss.position.z).length()
		assert_lte(d, Balance.data.monsters.stats(&"boss").drop_scatter + 1e-4)

func test_steak_pool_holds_a_tier2_night_plus_the_boss() -> void:
	var sizes := World.pool_sizes(Balance.data)
	var tb := Balance.data.tiers
	var kills := 0
	for w in 3:
		kills += WaveMath.total_count(tb.tier_cap[TierEffects.top_tier(tb)], w, Balance.data.wave)
	var need := int(ceil((kills * Balance.data.economy.steaks_per_kill + Balance.data.monsters.stats(&"boss").steaks_per_kill) * 1.2))
	assert_eq(sizes.steak, need)
	assert_gte(sizes.enemy, Balance.data.wave.max_wave_size + 1 + 10, "the boss is one more spawn")
```

- [ ] **Step 2: Run them to verify they fail**

Run the two files with `-gtest=`.
Expected: FAIL (`spawn` takes 5 arguments; `kind` missing; `enemy_killed` has 3 arguments).

- [ ] **Step 3: Implement**

`autoload/EventBus.gd`:

```gdscript
## WaveDirector -> sims, HUD (boss moon), audio, fx. kind: &"boar" | &"hare" | &"boss" (E5).
signal enemy_killed(spawn_index: int, lane: StringName, position: Vector3, kind: StringName)
```

`actors/enemy/boar.gd`:

```gdscript
## E5: which monster this pooled node is right now (spec 4.3); every number is read through stats().
var kind: StringName = &"boar"

func stats() -> MonsterStats:
	return Balance.data.monsters.stats(kind)

func spawn(p_lane: String, p_index: int, p_offset: float, hp_mult: float, director: Object, p_kind: StringName = &"boar") -> void:
	assert(Balance.data.monsters.has_kind(p_kind), "unknown monster kind %s" % p_kind)
	generation += 1
	kind = p_kind
	lane = p_lane
	...
	health.reset(stats().hp * hp_mult)
	...
	visual.set_kind(kind)   # Task 7 adds set_kind; until then BoarVisual gets a no-op `func set_kind(_k: StringName) -> void: pass`
```

In `_physics_process` replace `var eb := Balance.data.enemy` with `var eb := stats()` and the fence guard with
`_director.providers.has_kind(&"fence_on_lane", self)`. `_update_position` keeps `Balance.data.enemy.offset_fade_distance`
(shared).

`world/target_providers.gd`:

```gdscript
## True when a provider is registered for the kind AND the kind is in this enemy's priority list (E5: per kind).
func has_kind(kind: StringName, enemy) -> bool:
	return _providers.has(kind) and (enemy.stats().priority as Array).has(kind)

func find_target(enemy) -> Dictionary:
	for kind in enemy.stats().priority:
		if _providers.has(kind):
			var t: Dictionary = _providers[kind].call(enemy)
			if not t.is_empty():
				return t
	return {}

static func fence_stop_dist(enemy) -> float:
	var b: Dictionary = GameState.buildings[MapLayout.LANE_FENCE[enemy.lane]]
	if int(b.level) < 1 or float(b.hp) <= 0.0:
		return INF
	return enemy.path_length() - MapLayout.FENCE_OFFSET_FROM_END - enemy.stats().reach
```

`world/guard_roster.gd` `guard_target`: `var reach: float = enemy.stats().reach`.

`world/wave_director.gd`:

```gdscript
func _start_wave(w: int) -> void:
	...
	_schedule = WaveSchedule.build(plan, Balance.data.wave, Balance.data.tiers)

func _spawn_due() -> void:
	while _next < _schedule.size() and float(_schedule[_next].t) <= _t + 1e-6:
		var e: Dictionary = _schedule[_next]
		_spawn(String(e.lane), _spawn_rng.randf_range(-1.0, 1.0), -1.0, StringName(e.get("kind", &"boar")))
		_next += 1
	...

func _spawn(lane: String, unit_offset: float, hp_mult: float = -1.0, kind: StringName = &"boar") -> Boar:
	var boar: Boar = enemy_pool.acquire()
	var mult := hp_mult if hp_mult > 0.0 else float(_plan[maxi(wave_index, 0)].hp_mult) * GameState.mercy_factor()
	boar.spawn(lane, _spawn_counter, unit_offset * Balance.data.enemy.lateral_spread, mult, self, kind)
	...

func on_enemy_died(boar: Boar) -> void:
	...
	EventBus.enemy_killed.emit(boar.spawn_index, StringName(boar.lane), boar.global_position, boar.kind)
	var st := boar.stats()
	for i in st.steaks_per_kill:
		var s: Steak = steak_pool.acquire()
		var a := _drop_rng.randf() * TAU
		var r := _drop_rng.randf() * st.drop_scatter
		s.place(boar.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r))
	boar.play_death(enemy_pool)

func boss_alive() -> bool:
	for b in _alive:
		if (b as Boar).kind == &"boss":
			return true
	return false

func debug_spawn(lane: String, unit_offset: float = 0.0, hp_mult: float = 1.0, kind: StringName = &"boar") -> Boar:
	if _drop_rng == null:
		_drop_rng = Rng.stream(GameState.run_seed, GameState.day, &"drops")
	return _spawn(lane, unit_offset, hp_mult, kind)
```

The boar's `steaks_per_kill` view equals `economy.steaks_per_kill` and its scatter equals `enemy.drop_scatter`, so the
tier-1 drop RNG calls are identical (`baseline identical` must still print).

Listeners: `reactions.gd` `_on_enemy_killed(_spawn_index: int, _lane: StringName, pos: Vector3, _kind: StringName)`;
`audio_director.gd` `func(_i, _l, _p, _k): play(&"poof")`; `sim_harness.gd` `_on_killed(_i, _lane, _p, _kind)`;
the two tests emit with a 4th argument `&"boar"`.

**Wiring note (`world/world.gd`, hot):**

```gdscript
static func pool_sizes(bd: BalanceData) -> Dictionary:
	# E5: the steak pool holds the top tier's capped night plus the boss drop, with the old 20% margin (spec 7.1).
	var top := TierEffects.top_tier(bd.tiers)
	var steaks := 0
	for w in bd.wave.base_counts.size():
		steaks += WaveMath.total_count(bd.tiers.tier_cap[top], w, bd.wave)
	return {
		"enemy": bd.wave.max_wave_size + 1 + 10,
		"steak": int(ceil((steaks * bd.economy.steaks_per_kill + bd.monsters.stats(&"boss").steaks_per_kill) * 1.2)),
		"projectile": 24,
		"fx": 32,
	}
```

- [ ] **Step 4: Run the unit suite and the baseline**

Run: `./run_tests.sh unit && tools/baseline_diff.sh`
Expected: PASS, `baseline identical`. `test_boar.gd` still passes (it mutates `wave.target_priority.kinds`, which the
boar view reads live).

- [ ] **Step 5: Commit**

```bash
git add actors/enemy/boar.gd world/target_providers.gd world/wave_director.gd world/guard_roster.gd autoload/EventBus.gd world/fx/reactions.gd world/audio/audio_director.gd tests/sim/sim_harness.gd tests/unit/test_monster_kinds.gd* tests/unit/test_wave_director.gd tests/unit/test_audio_director.gd tests/unit/test_reactions.gd
git commit -m "feat(e5): monster kinds with per-kind target priority; boss and hare spawns; enemy_killed carries the kind"
```

### Task 7: Hare and boss looks, the boss HP bar, the boss moon

Spec 7.1 (art half), 7.4; `docs/ART_BIBLE.md` R1 to R8.

**Files:**
- Modify: `art/boar/boar_mesh.gd` (a `params(kind)` table and a per-kind cache), `art/boar/boar_visual.gd` (`set_kind`),
  `balance/ui_tuning.gd` → **wiring note** (`hare_hop_hz 6.0`, `hare_hop_height 0.05`, `boss_hop_hz 2.0`,
  `boss_hop_height 0.12`, `boss_lunge 0.5`, `boss_moon_scale 1.3`)
- Create: `actors/enemy/boss_bar.gd` (`class_name BossBar`)
- Modify: `ui/hud/hud_icons.gd`, `ui/hud/hud.gd`
- Modify: `docs/ART_BIBLE.md` section 5 (two rows), `art/budgets.gd` (no change: `res://art/boar` 1500 covers each kind)
- Test: `tests/unit/test_monster_visuals.gd`, `tests/unit/test_hud.gd` (add)

**Interfaces:**
- Consumes: `Boar.kind`, `EventBus.enemy_killed(..., kind)`, `WaveDirector.boss_alive()`, `GameState.is_boss_night()`.
- Produces:
  ```gdscript
  BoarMesh.params(kind: StringName) -> Dictionary   # scale, body, snout, ears, tusks, hop
  BoarMesh.get_mesh(kind: StringName = &"boar") -> ArrayMesh   # cached per kind; &"boar" is byte-identical to today's
  BoarVisual.set_kind(kind: StringName) -> void     # swaps the mesh only when the kind changes
  BossBar.setup(boar: Boar) -> void                 # a child of the Boar; shows while kind == boss and alive
  Hud.boss_moon_index() -> int                      # 2 on a boss night, -1 otherwise
  HudIcons.boss_moon: int, HudIcons.boss_alive: bool
  ```

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_monster_visuals.gd`:

```gdscript
extends GutTest
## E5 spec 7.1: three kinds from one builder; R7 scale table; the boss bar.

func before_each() -> void:
	Balance.reset()

func _height(m: ArrayMesh) -> float:
	return m.get_aabb().size.y

func _length(m: ArrayMesh) -> float:
	return m.get_aabb().size.z

func test_boar_mesh_is_unchanged() -> void:
	assert_eq(BoarMesh.get_mesh(), BoarMesh.get_mesh(&"boar"), "the default is the boar")
	assert_between(_height(BoarMesh.get_mesh(&"boar")), 0.9, 1.1)

func test_scale_table_r7() -> void:
	assert_between(_height(BoarMesh.get_mesh(&"hare")), 0.63, 0.77, "hare 0.7 m ± 10%")
	assert_between(_height(BoarMesh.get_mesh(&"boss")), 1.98, 2.42, "boss 2.2 m ± 10%")
	assert_between(_length(BoarMesh.get_mesh(&"boss")), 2.88, 3.52, "boss 3.2 m long ± 10%")

func test_each_kind_is_within_the_triangle_budget_and_on_palette() -> void:
	for kind in MonsterBalance.KINDS:
		var m := BoarMesh.get_mesh(kind)
		var tris := m.surface_get_array_len(0) / 3 if m.surface_get_format(0) & Mesh.ARRAY_FORMAT_INDEX == 0 else m.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
		assert_lte(tris, ArtBudgets.budget_for("res://art/boar/x"), "%s triangles" % kind)
		var cols: PackedColorArray = m.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var white := Palette.color(&"apron_white")
		var gold := Palette.color(&"gold")
		for c in cols:
			var rgb := Color(c.r, c.g, c.b)
			assert_false(rgb.is_equal_approx(white) or rgb.is_equal_approx(gold), "%s wears a hero colour (R2)" % kind)

func test_visual_swaps_the_mesh_only_when_the_kind_changes() -> void:
	var b := Boar.new()
	add_child_autofree(b)
	var before: Mesh = b.visual._mesh_node.mesh
	b.visual.set_kind(&"boar")
	assert_eq(b.visual._mesh_node.mesh, before)
	b.visual.set_kind(&"hare")
	assert_eq(b.visual._mesh_node.mesh, BoarMesh.get_mesh(&"hare"))
	assert_ne(b.visual._mesh_node.mesh, before)

func test_boss_bar_shows_only_for_a_living_boss() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	GameState.new_game(1)
	var wd := main.world.wave_director
	wd.start_night(GameState.lane_plan)
	var boar := wd.debug_spawn("north")
	await get_tree().process_frame
	assert_false(boar.get_node("BossBar").visible)
	var boss := wd.debug_spawn("north", 0.0, 1.0, &"boss")
	await get_tree().process_frame
	var bar: BossBar = boss.get_node("BossBar")
	assert_true(bar.visible)
	assert_almost_eq(bar.fraction(), 1.0, 1e-6)
	boss.take_hit(400.0)
	await get_tree().process_frame
	assert_almost_eq(bar.fraction(), 0.5, 1e-6)
	assert_eq(bar.fill_color(), Palette.color(&"enemy_red"))
	boss.take_hit(1e9)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_false(bar.visible)
```

Append to `tests/unit/test_hud.gd` (it already creates a `Main` and reads `main.hud`; use the same pattern):

```gdscript
func test_boss_moon_on_a_boss_night() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	main.phase_controller.start_new_game(20260930)
	assert_eq(main.hud.boss_moon_index(), -1)
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	main.phase_controller.debug_skip_to_day()
	main.phase_controller.debug_skip_to_night()
	await get_tree().physics_frame
	assert_eq(main.hud.boss_moon_index(), 2)
	assert_eq(main.hud.icons.boss_moon, 2)
	assert_eq(main.hud.moon_color(2), Palette.color(&"enemy_red"), "unlit boss moon is red, not ink_soft")
	assert_almost_eq(main.hud.icons.moon_scale(2), Balance.ui.boss_moon_scale, 1e-6)
	assert_almost_eq(main.hud.icons.moon_scale(0), 1.0, 1e-6)
```

- [ ] **Step 2: Run them to verify they fail**

Expected: FAIL (`get_mesh` takes no argument; `BossBar` not found; `boss_moon_index` not found).

- [ ] **Step 3: Implement the meshes**

`art/boar/boar_mesh.gd`: replace the single cache with a per-kind table and thread `p: Dictionary` through `_build`:

```gdscript
static var _meshes := {}

## Per-kind proportions (E5 spec 7.1). The boar row reproduces today's constants exactly (D-192).
static func params(kind: StringName) -> Dictionary:
	match kind:
		&"hare":
			return {"scale": 0.7, "body_scale": Vector3(0.8, 0.7, 1.25), "upper": Palette.color(&"enemy_snout"),
				"belly": Palette.color(&"enemy_snout").lerp(Palette.color(&"enemy_maroon"), 0.25), "ears": Palette.color(&"enemy_red"),
				"ear_len": 0.42, "tusks": 0, "ridge": 0, "leg_len": 0.32, "tusk_color": Palette.color(&"stone")}
		&"boss":
			return {"scale": 2.2, "body_scale": Vector3(1.05, 0.8, 1.15), "upper": Palette.color(&"enemy_maroon").lerp(Palette.color(&"enemy_red"), 0.25),
				"belly": Palette.color(&"enemy_maroon"), "ears": Palette.color(&"enemy_snout"),
				"ear_len": 0.18, "tusks": 4, "ridge": 5, "leg_len": 0.25, "tusk_color": Palette.color(&"stone")}
	return {"scale": 1.0, "body_scale": BODY_SCALE, "upper": Palette.color(&"enemy_maroon").lerp(Palette.color(&"enemy_red"), 0.4),
		"belly": Palette.color(&"enemy_red"), "ears": Palette.color(&"enemy_snout"),
		"ear_len": 0.18, "tusks": 2, "ridge": 5, "leg_len": 0.25, "tusk_color": Palette.color(&"apron_white")}

static func get_mesh(kind: StringName = &"boar") -> ArrayMesh:
	if not _meshes.has(kind):
		_meshes[kind] = _build(params(kind))
	return _meshes[kind]
```

In `_build(p)`: use `p.body_scale`, `p.upper`, `p.belly`, `p.ears`; draw `p.ridge` ridge cones (the first `p.ridge`
entries of `rz`/`rh`); draw `p.tusks` tusks (0: none; 2: today's pair; 4: today's pair plus a second, shorter pair
rotated 25° further out and 0.1 lower, colour `p.tusk_color`); ears as today but length `p.ear_len`; legs `p.leg_len`
tall. After the merge, scale every vertex by `p.scale` (y from the ground: multiply positions, not the transform, so
`get_aabb` and the blob shadow read the true size) and leave normals as they are. The boar row's `tusk_color` is the
white today's boar uses (D-192 exception already reviewed); the hare and boss use `stone`.

`art/boar/boar_visual.gd`:

```gdscript
var kind: StringName = &"boar"

func set_kind(k: StringName) -> void:
	if k == kind and _mesh_node != null and _mesh_node.mesh == BoarMesh.get_mesh(k):
		return
	kind = k
	if _mesh_node != null:
		_mesh_node.mesh = BoarMesh.get_mesh(kind)

## Per-kind hop (visual, UiTuning): hare quick and low, boss slow and heavy.
func _hop() -> Vector2:  # (height, hz)
	var ui := Balance.ui
	match kind:
		&"hare":
			return Vector2(ui.hare_hop_height, ui.hare_hop_hz)
		&"boss":
			return Vector2(ui.boss_hop_height, ui.boss_hop_hz)
	return Vector2(ui.boar_hop_height, ui.boar_hop_hz)

func _lunge_dist() -> float:
	return Balance.ui.boss_lunge if kind == &"boss" else Balance.ui.boar_lunge
```

Use `_hop()` in `_process` and `_lunge_dist()` in `attack()`; `_ready` calls `set_kind(kind)` after creating the mesh
node. `Boar.spawn` calls `visual.set_kind(kind)` (Task 6 left the stub).

- [ ] **Step 4: The boss bar and the moon**

`actors/enemy/boss_bar.gd`:

```gdscript
class_name BossBar
extends Node3D
## The boss's world HP bar (E5 spec 7.1): the Guard's bar pattern, enemy_red on ink, 1.6 m wide at 2.6 m. Visual only.

const WIDTH := 1.6
const Y := 2.6
var _boar: Boar
var _fill: MeshInstance3D
var _back: MeshInstance3D

func setup(boar: Boar) -> void:
	_boar = boar
	name = "BossBar"
	_back = _box(Vector3(WIDTH + 0.1, 0.16, 0.06), &"ink")
	_fill = _box(Vector3(WIDTH, 0.1, 0.08), &"enemy_red")
	position.y = Y
	visible = false
	boar.health.damaged.connect(func(_a): _refresh())

func _box(size: Vector3, color: StringName) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.color(color)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func fraction() -> float:
	return 0.0 if _boar.health.max_hp <= 0.0 else _boar.health.hp / _boar.health.max_hp

func fill_color() -> Color:
	return (_fill.material_override as StandardMaterial3D).albedo_color

func _refresh() -> void:
	visible = _boar.kind == &"boss" and _boar.alive
	var f := fraction()
	_fill.scale.x = maxf(f, 0.001)
	_fill.position.x = -WIDTH * 0.5 * (1.0 - f)

func _process(_delta: float) -> void:
	_refresh()
```

(`Health` exposes `hp` and `max_hp`; check `components/health.gd` for the exact names and use those.) `Boar._init`
adds `var bar := BossBar.new(); add_child(bar); bar.setup(self)`.

`ui/hud/hud_icons.gd`:

```gdscript
## E5 spec 7.4: the boss moon's index (-1 = none) and whether the boss still lives (it breathes while it does).
var boss_moon := -1
var boss_alive := false
var _t := 0.0

func moon_color(i: int) -> Color:
	if i == boss_moon and not moon_lit(i):
		return Palette.color(&"enemy_red")
	return MOON_LIT if moon_lit(i) else Palette.color(&"ink_soft")

func moon_scale(i: int) -> float:
	if i != boss_moon:
		return 1.0
	var s: float = Balance.ui.boss_moon_scale
	if boss_alive and not moon_lit(i):
		s *= 1.0 + 0.06 * sin(_t * TAU * Balance.ui.pulse_hz)
	return s

func moon_rect(i: int) -> Rect2:
	var c: Control = moon_cells[i]
	var px := MOON_PX * moon_scale(i)
	return Rect2(c.get_global_rect().position + Vector2.ONE * ((MOON_CELL_PX - px) * 0.5), Vector2(px, px))

func _process(delta: float) -> void:
	if night and boss_moon >= 0 and boss_alive:
		_t += delta
		queue_redraw()
```

`ui/hud/hud.gd`: in `_on_phase_changed` when `night`, set `icons.boss_moon = boss_moon_index()` and
`icons.boss_alive = false`; connect `wave_started` (`icons.boss_alive = w == icons.boss_moon`) and `enemy_killed`
(`if kind == &"boss": icons.boss_alive = false; icons.queue_redraw()`); add:

```gdscript
func boss_moon_index() -> int:
	return GameState.lane_plan.size() - 1 if GameState.is_boss_night() else -1
```

**Wiring note (`balance/ui_tuning.gd`, hot):** `@export var hare_hop_height := 0.05`, `hare_hop_hz := 6.0`,
`boss_hop_height := 0.12`, `boss_hop_hz := 2.0`, `boss_lunge := 0.5`, `boss_moon_scale := 1.3`.

- [ ] **Step 5: Shots for the art review**

Run `tools/shots.sh /tmp/e5_t7` after adding a `monsters` scene to the shot list that spawns one of each kind side by
side at the north lane end by day light and by night (`ui/debug/` scene, excluded from release). Answer R1 to R8 for
the three kinds at full size and at 40% in the task report. Add the two rows to `docs/ART_BIBLE.md` section 5:
`Hare | 0.7 m tall, 1.1 m long`, `Boar King | 2.2 m tall, 3.2 m long`.

- [ ] **Step 6: Run the unit suite, commit**

```bash
git add art/boar/boar_mesh.gd art/boar/boar_visual.gd actors/enemy/boss_bar.gd* actors/enemy/boar.gd ui/hud/hud_icons.gd ui/hud/hud.gd ui/debug/ docs/ART_BIBLE.md tests/unit/test_monster_visuals.gd* tests/unit/test_hud.gd
git commit -m "art(e5): hare and Boar King from the Boar builder, the boss HP bar, the boss moon"
```

### Task 8: The boss night and the tier-up dawn in PhaseController; listeners

Spec 3, 6.4, 7.6, 7.7.

**Files:**
- Modify: `world/phase_controller.gd`, `core/pulse.gd`, `world/save/autosave.gd`, `world/fx/reactions.gd`,
  `world/audio/audio_director.gd`, `ui/guide/guide.gd`, `world/stations/closeup_sign.gd`
- Test: `tests/unit/test_boss_night.gd`, `tests/unit/test_pulse.gd` (add), `tests/unit/test_autosave.gd` (add),
  `tests/unit/test_guide.gd` (add)

**Interfaces:**
- Consumes: `GameState.boss_pending`, `is_boss_night()`, `complete_tier_up()`, `tier_remaining_cost()`,
  `EventBus.tier_paid_up`, `tier_reached`, `tier_changed`, `TierBalance.tier_reveal_time`.
- Produces: `PhaseController.reveal_pending: bool` (true between a tier-up dawn and its card pick);
  `Pulse.should_pulse` counts an affordable tier-up; the `tr()` strings `"The Boar King comes"`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_boss_night.gd`:

```gdscript
extends GutTest
## E5 spec 6.4: boss night banner, retry keeps the payment, the tier-up dawn, the reveal delay.

var main: Main
var banners: Array = []
var phases: Array = []

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	banners.clear()
	phases.clear()
	EventBus.banner_requested.connect(_on_banner)
	EventBus.phase_changed.connect(_on_phase)
	main.phase_controller.start_new_game(20260930)

func after_each() -> void:
	EventBus.banner_requested.disconnect(_on_banner)
	EventBus.phase_changed.disconnect(_on_phase)

func _on_banner(t: String) -> void: banners.append(t)
func _on_phase(p: int, d: int) -> void: phases.append([p, d])

func _pay_and_close() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	banners.clear()
	main.phase_controller.debug_skip_to_night()

func test_boss_night_is_announced_and_planned() -> void:
	_pay_and_close()
	assert_true(GameState.is_boss_night())
	assert_true(banners.has(tr("The Boar King comes")), str(banners))
	assert_true(main.phase_controller.snapshot.boss_pending, "the close-up snapshot carries the pending boss")

func test_lost_boss_night_restores_with_the_payment_kept() -> void:
	_pay_and_close()
	GameState.damage_diner(1e9)
	for i in int(ceil(Balance.ui.banner_time * 60.0)) + 3:
		await get_tree().physics_frame
	assert_eq(main.phase_controller.phase, Phase.DAY)
	assert_true(GameState.boss_pending, "still pending")
	assert_eq(GameState.tier, 1)
	assert_eq(GameState.night_fails, 1, "mercy counts the loss")
	assert_eq(GameState.pay_into_tier(50), 0, "no refund, no double payment")

func test_won_boss_night_tiers_up_at_dawn_and_delays_the_card_pick() -> void:
	_pay_and_close()
	var day0 := GameState.day
	var offered := []
	var cb := func(o): offered.append(o)
	EventBus.card_offered.connect(cb)
	watch_signals(EventBus)
	main.phase_controller.debug_skip_to_day()  # runs the dawn as a win
	EventBus.card_offered.disconnect(cb)
	assert_eq([GameState.tier, GameState.tier_day, GameState.boss_pending], [2, day0 + 1, false])
	assert_signal_emitted(EventBus, "tier_reached")
	assert_true(GameState.buildings.has("tower_w"))
	assert_false(GameState.is_boss_night(), "the next plan has no boss")
	assert_eq(GameState.pressure(), 8)
	assert_eq(GameState.night_fails, 0)
	assert_true(main.phase_controller.reveal_pending)
	assert_eq(offered, [], "the card pick waits for the reveal")
	for i in int(ceil(Balance.data.tiers.tier_reveal_time * 60.0)) + 3:
		await get_tree().physics_frame
	assert_false(main.phase_controller.reveal_pending)
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK")

func test_normal_dawn_has_no_delay_and_no_tier_up() -> void:
	main.phase_controller.debug_skip_to_day()
	assert_eq(GameState.tier, 1)
	assert_false(main.phase_controller.reveal_pending)

func test_resume_during_the_reveal_shows_tier_2_and_opens_the_pick() -> void:
	_pay_and_close()
	main.phase_controller.debug_skip_to_day()
	var mid := GameState.to_dict()   # what the dawn autosave wrote (Autosave writes on card_offered / DAY; see test_autosave)
	mid.resume_phase = "CARD_PICK"
	GameState.set_card_offer(CardOffer.make(GameState.run_seed, GameState.day, GameState.cards, Balance.data.cards))
	mid.card_offer = GameState.card_offer.map(func(id): return String(id))
	main.phase_controller.resume_from(mid)
	assert_eq(GameState.tier, 2)
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK")
	assert_false(main.phase_controller.reveal_pending, "no replay")

func test_old_tier1_save_past_day_7_replans_at_the_cap_on_its_next_dawn() -> void:
	# Review Focus 1: a day-12 plan planned at day-12 pressure (as E1 wrote it) plays once, then the cap applies.
	var s := GameState.to_dict()
	s.day = 12
	s.lane_plan = LanePlanner.plan(s.run_seed, 12, Balance.data.wave, 1, 1, Balance.data.tiers)  # at the cap already
	for w in s.lane_plan:
		w.main_count = 40  # test-only: an oversized old plan
	s.resume_phase = "NIGHT"
	main.phase_controller.resume_from(s)
	assert_eq(GameState.lane_plan[0].main_count, 40, "the saved night plays as saved")
	main.phase_controller.debug_skip_to_day()
	assert_eq(GameState.day, 13)
	assert_eq(GameState.pressure(), 7)
	assert_eq(GameState.lane_plan[0].main_count + GameState.lane_plan[0].side_count, WaveMath.total_count(7, 0, Balance.data.wave))
```

Append to `tests/unit/test_pulse.gd`:

```gdscript
func test_affordable_tier_up_stops_the_pulse() -> void:
	Balance.reset()
	GameState.new_game(1)
	for id in GameState.buildings:  # test-only setup: max every spot
		GameState.buildings[id].level = Balance.data.build.max_level
	GameState.stations[&"counter"].level = Balance.data.stations.max_level
	GameState.stations[&"freezer"].level = Balance.data.stations.max_level
	GameState.gold = 499  # test-only setup
	assert_true(Pulse.should_pulse(GameState.to_dict(), Balance.data))
	GameState.gold = 500  # test-only setup
	assert_false(Pulse.should_pulse(GameState.to_dict(), Balance.data), "500 gold buys the tier")
	GameState.boss_pending = true  # test-only setup
	assert_true(Pulse.should_pulse(GameState.to_dict(), Balance.data), "paid: nothing left to buy")
	var no_tier := GameState.to_dict()
	for k in ["tier", "tier_day", "tier_paid", "boss_pending"]:
		no_tier.erase(k)
	GameState.boss_pending = false  # test-only setup
	assert_true(Pulse.should_pulse(no_tier, Balance.data), "a state without tier keys ignores the tier (the guide's view)")
```

Append to `tests/unit/test_autosave.gd` (use its existing store/harness pattern):

```gdscript
func test_tier_payment_marks_dirty_and_paid_up_writes() -> void:
	# same setup as the other write tests in this file
	...
	GameState.add_gold(500)
	var w0 := autosave.writes
	GameState.pay_into_tier(100)
	assert_true(autosave._dirty, "a partial payment is dirty")
	GameState.pay_into_tier(400)
	assert_eq(autosave.writes, w0 + 1, "paid in full writes at once")
```

Append to `tests/unit/test_guide.gd`:

```gdscript
func test_guide_pulse_view_ignores_the_tier() -> void:
	# the first-day `close` rule must not wait for a 500-gold tier-up (spec 7.7)
	var snap := guide.snapshot()
	GameState.gold = 500  # test-only setup
	for id in GameState.buildings:
		GameState.buildings[id].level = Balance.data.build.max_level  # test-only setup
	GameState.counter_steaks = 0
	GameState.freezer_steaks = 0
	GameState.carried_steaks = 0
	GameState.gold_pile = 0
	snap = guide.snapshot()
	assert_true(bool(snap.should_pulse))
```

- [ ] **Step 2: Run them to verify they fail**

Expected: FAIL (no banner, no tier-up at dawn, `reveal_pending` missing, pulse false at 500 gold).

- [ ] **Step 3: Implement**

`world/phase_controller.gd`:

```gdscript
## E5: true from a tier-up dawn until its card pick opens (the reveal plays meanwhile).
var reveal_pending := false
var _reveal_id := 0

func _enter_night() -> void:
	traveler_spawner.stop()
	phase = Phase.NIGHT
	EventBus.phase_changed.emit(phase, GameState.day)
	if GameState.boss_pending:
		EventBus.banner_requested.emit(tr("The Boar King comes"))
	wave_director.start_night(GameState.lane_plan)

func _run_dawn() -> void:
	wave_director.stop()
	phase = Phase.DAWN
	EventBus.phase_changed.emit(phase, GameState.day)
	var won_boss := GameState.boss_pending
	_steaks_to_freezer()                 # 1 (the boss drop included)
	_recall_all()
	GameState.heal_for_dawn()            # 2
	GameState.reset_destroyed_fences()   # 3
	GameState.clear_night_fails()
	GameState.advance_day()              # 4
	if won_boss:
		GameState.complete_tier_up()     # E5 spec 6.4: the new day's plan is already at the new tier
		reveal_pending = true
		_reveal_id += 1
		var id := _reveal_id
		get_tree().create_timer(Balance.data.tiers.tier_reveal_time, false, true).timeout.connect(_on_reveal_timer.bind(id))
		return
	_card_pick()

func _on_reveal_timer(id: int) -> void:
	if id != _reveal_id or phase != Phase.DAWN:
		return
	reveal_pending = false
	_card_pick()
```

`start_new_game`, `_restore_snapshot` and `resume_from` set `reveal_pending = false` and `_reveal_id += 1` (a stale
timer never opens a pick over a restored state). `debug_skip_to_day` from NIGHT runs `_run_dawn` as today; when it
left `reveal_pending`, the test waits for the timer.

`core/pulse.gd`, before `return true`:

```gdscript
	# E5: an affordable tier-up is something left to do. No `tier` key = ignore the tier (the guide's view).
	if state.has("tier") and not bool(state.get("boss_pending", false)):
		var tcost := TierEffects.tier_cost(int(state.tier), bd.tiers)
		if tcost >= 0 and gold >= tcost - int(state.get("tier_paid", 0)):
			return false
```

`ui/guide/guide.gd` `snapshot`: after `spots_only.erase("stations")` add
`for k in ["tier", "tier_day", "tier_paid", "boss_pending"]: spots_only.erase(k)  # nor for the tier-up (E5 spec 7.7)`.

`world/stations/closeup_sign.gd`: connect `EventBus.tier_changed.connect(func(_t, _p, _b): refresh_pulse())`.

`world/save/autosave.gd`: `EventBus.tier_changed.connect(_mark_dirty.unbind(3))`,
`EventBus.tier_paid_up.connect(func(_n): if phase == Phase.DAY and not failing: _write_live("DAY"))`,
`EventBus.tier_reached.connect(func(_t): if phase == Phase.DAWN and not failing: _write_live("DAY"))` (the dawn
autosave: a tab closed mid-reveal resumes at tier 2 in DAY; the card pick re-opens on the next dawn step as today's
`CARD_PICK` resume does once `card_offered` writes).

`world/fx/reactions.gd`: `tier_paid_up` → `fx_requested(&"sparkle", MapLayout.to3(MapLayout.TIER_SIGN, 1.0))`.
`world/audio/audio_director.gd`: `tier_paid_up` → `play(&"build_done")`.

- [ ] **Step 4: Run the unit suite and the baseline; commit**

```bash
git add world/phase_controller.gd core/pulse.gd world/save/autosave.gd world/fx/reactions.gd world/audio/audio_director.gd ui/guide/guide.gd world/stations/closeup_sign.gd tests/unit/test_boss_night.gd* tests/unit/test_pulse.gd tests/unit/test_autosave.gd tests/unit/test_guide.gd
git commit -m "feat(e5): boss night banner, retry with the payment kept, the tier-up dawn and the reveal delay"
```

**Phase 2 gate (main session):** `./run_tests.sh all` green, `baseline identical`, the Task 7 shots reviewed against
R1 to R8, wiring notes of Tasks 6 and 7 applied, PR `e5/p2-night` self-merged.

---

# Phase 3: `e5/p3-world`

### Task 9: The tier sign

Spec 7.2.

**Files:**
- Create: `world/stations/tier_sign.gd` (`class_name TierSign`), `art/env/src/tier_sign_src.tscn`, `art/env/tier_sign.tscn`
- Modify: `art/env/bake_manifest.gd` (one entry), run `tools/bake_static.gd` for `art/env/baked/tier_sign.res`
- Modify: `world/world.gd` → **wiring note** (`_build_stations` creates the sign; `var tier_sign: TierSign`)
- Test: `tests/unit/test_tier_sign.gd`

**Interfaces:**
- Consumes: `GameState.tier_next_cost/tier_remaining_cost/pay_into_tier/boss_pending`, `EventBus.tier_changed`,
  `tier_reached`, `phase_changed`, `state_restored`, `PayFx.paid_tick`, `Economy.drain_per_tick`, `StationZone`.
- Produces: `TierSign.setup(world: World)`, `TierSign.label: WorldLabel`, `TierSign.zone: StationZone`,
  `TierSign.state() -> StringName` (`&"hidden"`, `&"selling"`, `&"boss"`), `World.tier_sign`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_tier_sign.gd`:

```gdscript
extends GutTest
## E5 spec 7.2: the tier sign's states, payment and night hiding.

var main: Main
var sign: TierSign

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	main.phase_controller.start_new_game(20260930)
	sign = main.world.tier_sign
	main.phase_controller.debug_skip_to_day()
	await get_tree().physics_frame

func test_sells_the_yards_by_day_and_hides_at_night() -> void:
	assert_eq(sign.state(), &"selling")
	assert_true(sign.label.visible)
	assert_eq(sign.label.text, tr("Open the yards") + "\n" + str(500))
	assert_true(sign.position.is_equal_approx(MapLayout.to3(MapLayout.TIER_SIGN)))
	main.phase_controller.debug_skip_to_night()
	await get_tree().physics_frame
	assert_false(sign.label.visible)
	assert_false(sign.zone.ring.visible)

func test_standing_still_pays_and_completes() -> void:
	GameState.add_gold(600)
	await TestHelpers.walk_in(main.hero, MapLayout.TIER_SIGN)
	var ticks := 0
	while not GameState.boss_pending and ticks < 60 * 20:
		await get_tree().physics_frame
		ticks += 1
	assert_true(GameState.boss_pending, "paid in full within 20 s")
	assert_eq(GameState.gold, 100)
	assert_eq(sign.state(), &"boss")
	assert_eq(sign.label.text, tr("Boss tonight"))
	assert_false(sign.zone.ring.visible)
	var g := GameState.gold
	for i in 30:
		await get_tree().physics_frame
	assert_eq(GameState.gold, g, "Review Focus 2: no more gold is taken")

func test_partial_payment_shows_on_the_ring_and_survives_a_restore() -> void:
	GameState.add_gold(120)
	await TestHelpers.walk_in(main.hero, MapLayout.TIER_SIGN)
	while GameState.gold > 0:
		await get_tree().physics_frame
	assert_eq(GameState.tier_paid, 120)
	assert_true(sign.zone.ring.visible)
	assert_almost_eq(sign.zone.ring.progress, 120.0 / 500.0, 1e-6)
	var d := GameState.to_dict()
	GameState.new_game(3)
	GameState.from_dict(d)
	await get_tree().physics_frame
	assert_eq(sign.label.text, tr("Open the yards") + "\n" + str(380))

func test_walking_through_pays_nothing() -> void:
	GameState.add_gold(100)
	main.hero.teleport(MapLayout.TIER_SIGN + Vector2(0, 3.0))
	for i in 90:
		main.hero.input.set_move(Vector2(0, -1))
		await get_tree().physics_frame
	main.hero.input.set_move(Vector2.ZERO)
	assert_eq(GameState.gold, 100)

func test_hidden_at_the_top_tier() -> void:
	GameState.debug_set_tier(TierEffects.top_tier(Balance.data.tiers), GameState.day)
	await get_tree().physics_frame
	assert_eq(sign.state(), &"hidden")
	assert_false(sign.label.visible)
	assert_false(sign.visible)
```

(`ProgressRing` exposes its value as `progress`; check `ui/progress_ring/` for the exact name.)

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL (`tier_sign` is null on `World`).

- [ ] **Step 3: Implement**

`art/env/src/tier_sign_src.tscn`: the close-up sign's source (`closeup_sign_src.tscn`) duplicated, board recoloured
`diner_cream` with a `wood` post and a small `gold` star cap (a reward accent is allowed on UI-like props; R2 keeps
white and gold off characters). Add the entry `{"in": "res://art/env/src/tier_sign_src.tscn", "out":
"res://art/env/baked/tier_sign.res"}` to `bake_manifest.gd`, run
`"$GODOT" --headless --path . -s res://tools/bake_static.gd -- --all` and commit the `.res`. `art/env/tier_sign.tscn`
wraps it under a root `Visual` node like `closeup_sign.tscn`. `test_bake_static.gd`'s committed-bake test covers it.

`world/stations/tier_sign.gd`:

```gdscript
class_name TierSign
extends Node3D
## E5 spec 7.2: stand-still payment for the next diner tier. All state comes from GameState (tier_paid, boss_pending).
## Stands on the land it sells (MapLayout.TIER_SIGN). Hidden when this build has no next tier.

const SIGN_SCENE := preload("res://art/env/tier_sign.tscn")
const MARKER_SCENE := preload("res://art/env/spot_marker.tscn")
const LABEL_Y := 2.0

var label: WorldLabel
var zone: StationZone
var marker: Node3D
var _visual: Node3D
var _fx: FlyFx
var _paid_ticks := 0

func setup(world: World) -> void:
	name = "TierSign"
	_fx = world.fly_fx
	position = MapLayout.to3(MapLayout.TIER_SIGN)
	_visual = SIGN_SCENE.instantiate()
	add_child(_visual)
	label = WorldLabel.make("", 36)
	label.position = Vector3(0, LABEL_Y, 0)
	add_child(label)
	marker = MARKER_SCENE.instantiate()
	add_child(marker)
	zone = StationZone.new()
	zone.radius = MapLayout.STATION_RADIUS
	zone.drive_ring = false
	add_child(zone)
	zone.ticked.connect(_on_tick)
	EventBus.tier_changed.connect(func(_t, _p, _b): refresh())
	EventBus.tier_reached.connect(func(_t): refresh())
	EventBus.phase_changed.connect(func(_p, _d): refresh())
	EventBus.state_restored.connect(refresh)
	refresh()

func state() -> StringName:
	if GameState.tier_next_cost() < 0:
		return &"hidden"
	return &"boss" if GameState.boss_pending else &"selling"

func _on_tick() -> void:
	var cost := GameState.tier_next_cost()
	if cost < 0 or GameState.boss_pending:
		return
	var paid := GameState.pay_into_tier(Economy.drain_per_tick(cost, Balance.data.build))
	if paid > 0:
		_paid_ticks = PayFx.paid_tick(self, _fx, _paid_ticks, GameState.boss_pending, 1.0)

func refresh() -> void:
	var st := state()
	var day := zone != null and zone.is_active()
	visible = st != &"hidden"
	match st:
		&"hidden":
			label.text = ""
		&"boss":
			label.text = tr("Boss tonight")
		_:
			label.text = tr("Open the yards") + "\n" + str(GameState.tier_remaining_cost())
	label.visible = day and st != &"hidden"
	marker.visible = day and st == &"selling"
	if GameState.tier_paid == 0:
		_paid_ticks = 0
	if zone != null:
		var cost := GameState.tier_next_cost()
		var progress := 0.0 if (cost <= 0 or st != &"selling") else float(GameState.tier_paid) / float(cost)
		zone.ring.visible = progress > 0.0 and day
		zone.ring.set_progress(progress)
```

**Wiring note (`world/world.gd`, hot):** `var tier_sign: TierSign`; in `_build_stations` after the close-up sign:
`tier_sign = TierSign.new(); add_child(tier_sign); tier_sign.setup(self)`.

- [ ] **Step 4: Run the unit suite and the baseline; commit**

```bash
git add world/stations/tier_sign.gd* art/env/src/tier_sign_src.tscn art/env/tier_sign.tscn art/env/baked/tier_sign.res art/env/bake_manifest.gd tests/unit/test_tier_sign.gd*
git commit -m "feat(e5): the tier sign: pay standing still, boss tonight, hidden at the top"
```

### Task 10: Yards, yard stones and tier spots at runtime

Spec 7.3 (yards, stones, spots).

**Files:**
- Modify: `art/env/ground.gd` (`terrain_mesh(rect, yards)`), create `art/env/yard_stones.gd` (`class_name YardStones`)
- Modify: `world/world.gd` (**main purpose**: ground per tier, yard stones, spots for the tier, rebuild on
  `tier_reached` and on `state_restored`; the Task 6 and Task 9 wiring notes are applied here too if still pending)
- Test: `tests/unit/test_yards.gd`, `tests/unit/test_ground_art.gd` (add)

**Interfaces:**
- Consumes: `MapLayout.YARDS`, `yards_for_tier`, `spots_for_tier`, `EventBus.tier_reached`, `state_restored`,
  `GroundArt.merge_arrays`, `LaneStrip.STONE_MODEL`, `GroundArt.hash01`.
- Produces:
  ```gdscript
  GroundArt.yard_arrays(rect: Rect2) -> Dictionary        # dirt / dirt_dark hashed cells at y = 0.01
  GroundArt.terrain_mesh(rect: Rect2, yards: Array = []) -> ArrayMesh   # cached per (rect, yards)
  YardStones.transforms(rect: Rect2) -> Array[Transform3D]   # stones along the outline, 1.2 m apart, hash yaw
  YardStones.build(yards: Array) -> MultiMeshInstance3D      # one node for every open yard; no collision
  World.rebuild_for_tier() -> void                           # ground, stones, spots for GameState.tier
  World.yard_ids() -> Array[String]                          # what is open now
  ```

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_yards.gd`:

```gdscript
extends GutTest
## E5 spec 7.3: yards and yard spots appear at tier 2, on tier_reached and on restore; one ground draw, one stone draw.

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	main.phase_controller.start_new_game(20260930)

func _ground_meshes() -> Array:
	return main.world.find_children("Ground", "MeshInstance3D", true, false)

func test_tier1_has_no_yards_no_stones_and_five_spots() -> void:
	assert_eq(main.world.yard_ids(), [])
	assert_null(main.world.get_node_or_null("YardStones"))
	assert_eq(main.world.build_spots.keys(), MapLayout.spots_for_tier(1))
	assert_eq(_ground_meshes().size(), 1)
	assert_eq((_ground_meshes()[0] as MeshInstance3D).mesh, GroundArt.terrain_mesh(World.ground_rect(), []))

func test_tier_reached_opens_the_yards_and_adds_the_spots() -> void:
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	GameState.complete_tier_up()
	await get_tree().process_frame
	assert_eq(main.world.yard_ids(), ["west", "east"])
	var stones := main.world.get_node_or_null("YardStones") as MultiMeshInstance3D
	assert_not_null(stones)
	assert_gt(stones.multimesh.instance_count, 10)
	assert_eq(main.world.build_spots.keys(), MapLayout.spots_for_tier(2))
	assert_true(main.world.build_spots["tower_w"] is TowerSpot)
	assert_eq(_ground_meshes().size(), 1, "still one ground draw")
	assert_eq((_ground_meshes()[0] as MeshInstance3D).mesh, GroundArt.terrain_mesh(World.ground_rect(), ["west", "east"]))
	assert_eq(main.world.find_children("*", "StaticBody3D", true, false).filter(func(b): return b.name.begins_with("Yard")).size(), 0, "no collision on yards or stones")

func test_restore_rebuilds_for_the_saved_tier() -> void:
	GameState.debug_set_tier(2, 9)
	var d := GameState.to_dict()
	GameState.new_game(5)
	await get_tree().process_frame
	assert_eq(main.world.yard_ids(), [])
	GameState.from_dict(d)
	await get_tree().process_frame
	assert_eq(main.world.yard_ids(), ["west", "east"])
	assert_true(main.world.build_spots.has("tower_e"))
	GameState.new_game(6)
	await get_tree().process_frame
	assert_eq(main.world.yard_ids(), [], "a new game closes them again")
	assert_false(main.world.build_spots.has("tower_e"))

func test_yard_spots_take_payment_like_any_tower() -> void:
	GameState.debug_set_tier(2, GameState.day)
	main.phase_controller.debug_skip_to_day()
	await get_tree().process_frame
	GameState.add_gold(40)
	await TestHelpers.walk_in(main.hero, WaypointGraph.create_for_tier(2).position_of("tower_w"))
	while GameState.gold > 0:
		await get_tree().physics_frame
	assert_eq(int(GameState.buildings["tower_w"].level), 1)
```

Append to `tests/unit/test_ground_art.gd`:

```gdscript
func test_yard_cells_are_dirt_and_inside_the_rect() -> void:
	var r := Rect2(2, 2, 4, 6)
	var a := GroundArt.yard_arrays(r)
	assert_gt((a.v as PackedVector3Array).size(), 0)
	var dirt := Palette.color(&"dirt")
	var dark := Palette.color(&"dirt_dark")
	for i in (a.v as PackedVector3Array).size():
		var v: Vector3 = a.v[i]
		assert_true(r.grow(1e-4).has_point(Vector2(v.x, v.z)), str(v))
		assert_almost_eq(v.y, GroundArt.YARD_Y, 1e-6)
		var c: Color = a.c[i]
		assert_true(c.is_equal_approx(dirt) or c.is_equal_approx(dirt.lerp(dark, GroundArt.hash01(v.x, v.z))), "palette only")

func test_terrain_with_yards_is_one_surface_and_cached() -> void:
	var m := GroundArt.terrain_mesh(World.ground_rect(), ["west"])
	assert_eq(m.get_surface_count(), 1)
	assert_eq(m, GroundArt.terrain_mesh(World.ground_rect(), ["west"]))
	assert_ne(m, GroundArt.terrain_mesh(World.ground_rect(), []))

func test_yard_stones_ring_the_outline() -> void:
	var r: Rect2 = MapLayout.YARDS["west"]
	var xfs := YardStones.transforms(r)
	assert_gt(xfs.size(), 10)
	for xf in xfs:
		var p := Vector2(xf.origin.x, xf.origin.z)
		assert_lte(Geometry.dist_point_rect(p, r), 0.4, "on the outline")
		assert_gte(Geometry.dist_point_rect(p, r.grow(-0.5)), 0.1, "not inside the yard")
```

- [ ] **Step 2: Run them to verify they fail**

Expected: FAIL (`yard_ids`, `yard_arrays`, `YardStones` missing).

- [ ] **Step 3: Implement**

`art/env/ground.gd`:

```gdscript
const YARD_Y := 0.01

## E5 spec 7.3: a yard is a dirt patch in the merged ground, hashed toward dirt_dark like the grass.
static func yard_arrays(rect: Rect2, cell := CELL) -> Dictionary:
	var a := ground_arrays(rect, cell)
	var cols: PackedColorArray = a.c
	var verts: PackedVector3Array = a.v
	var dirt := Palette.color(&"dirt")
	var dark := Palette.color(&"dirt_dark")
	for i in verts.size():
		var v := verts[i]
		verts[i] = Vector3(v.x, YARD_Y, v.z)
		cols[i] = dirt.lerp(dark, hash01(v.x, v.z) * 0.5)
	a.v = verts
	a.c = cols
	return a

## ONE mesh for the ground, the road, the lane strips and the open yards (D-201). `yards` = MapLayout.YARDS keys.
static func terrain_mesh(rect: Rect2, yards: Array = []) -> ArrayMesh:
	var key := "t%s%s" % [rect, yards]
	if not _cache.has(key):
		var parts := [ground_arrays(rect), road_arrays(Vector2(MapLayout.BOUNDS_MAX.x - MapLayout.BOUNDS_MIN.x, 2.0), MapLayout.ROAD_Z)]
		for id in MapLayout.LANE_PATHS:
			parts.append(LaneStrip.strip_arrays(MapLayout.LANE_PATHS[id]))
		for y in yards:
			parts.append(yard_arrays(MapLayout.YARDS[y], 1.0))
		_cache[key] = mesh_from(merge_arrays(parts))
	return _cache[key]
```

(The test in `test_ground_art.gd` that asserts "palette only" uses `hash01 * 0.5`; write the assertion to match
`dirt.lerp(dark, hash01 * 0.5)`.)

`art/env/yard_stones.gd`:

```gdscript
class_name YardStones
extends RefCounted
## E5 spec 7.3 (D-240): the yard ring is small stones, not a fence model (fences are a defense). One MultiMesh, no
## collision, fixed by position hash (no Rng).

const SPACING := 1.2
const SCALE := 0.55

static func transforms(rect: Rect2) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var n := int(floor(a.distance_to(b) / SPACING))
		for k in n:
			var p := a.lerp(b, (k + 0.5) / float(n))
			var yaw := GroundArt.hash01(p.x, p.y) * TAU
			out.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * SCALE), Vector3(p.x, 0.0, p.y)))
	return out

static func build(yards: Array) -> MultiMeshInstance3D:
	var xfs: Array[Transform3D] = []
	for id in yards:
		xfs.append_array(transforms(MapLayout.YARDS[id]))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = load(LaneStrip.STONE_MODEL) as Mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "YardStones"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
```

`world/world.gd`:

```gdscript
var ground: MeshInstance3D
var yard_stones: MultiMeshInstance3D

func _ready() -> void:
	...
	EventBus.tier_reached.connect(func(_t): rebuild_for_tier())
	EventBus.state_restored.connect(rebuild_for_tier)

## The yards open now; empty before the first new_game.
func yard_ids() -> Array[String]:
	return MapLayout.yards_for_tier(GameState.tier) if not GameState.buildings.is_empty() else [] as Array[String]

func _build_ground() -> void:
	var rect := ground_rect()
	ground = GroundArt.instance(GroundArt.terrain_mesh(rect, yard_ids()), "Ground")
	add_child(ground)
	...

## E5 spec 7.3: the ground mesh, the yard stones and the spot set follow GameState.tier (tier_reached, restore, new game).
func rebuild_for_tier() -> void:
	var yards := yard_ids()
	var mesh := GroundArt.terrain_mesh(ground_rect(), yards)
	if ground.mesh != mesh:
		ground.mesh = mesh
	if yard_stones != null:
		remove_child(yard_stones)
		yard_stones.queue_free()
		yard_stones = null
	if not yards.is_empty():
		yard_stones = YardStones.build(yards)
		add_child(yard_stones)
	var want: Array[String] = MapLayout.spots_for_tier(GameState.tier) if not GameState.buildings.is_empty() else MapLayout.spots_for_tier(1)
	for id in build_spots.keys():
		if not id in want:
			var s: BuildSpot = build_spots[id]
			build_spots.erase(id)
			remove_child(s)
			s.queue_free()
	for id in want:
		if not build_spots.has(id):
			var s: BuildSpot = TowerSpot.new() if MapLayout.spot_kind(id) == "tower" else FenceSpot.new()
			add_child(s)
			s.setup(id, self)
			s.zone.sync_phase(_phase_now())
			build_spots[id] = s
```

`_build_spots` becomes `for id in MapLayout.spots_for_tier(1)` at build time (GameState is empty then) and
`rebuild_for_tier()` runs on the first `state_restored`. `_phase_now()` reads the PhaseController's phase through the
`Main` parent (`get_parent().phase_controller.phase`), or the World keeps `_phase` from `phase_changed`; a spot created
mid-day must know it is day (`StationZone.sync_phase`). `BuildSpot.setup` already connects `state_restored`; a spot
removed on a downgrade (new game) disconnects in `_exit_tree` if it does not already (check `build_spot.gd`).

- [ ] **Step 4: Run the unit suite and the baseline; commit**

```bash
git add art/env/ground.gd art/env/yard_stones.gd* world/world.gd tests/unit/test_yards.gd* tests/unit/test_ground_art.gd
git commit -m "feat(e5): yards in the merged ground, yard stones and tier spots rebuilt per tier"
```

### Task 11: The tier-2 diner mesh

Spec 7.3 (diner); `docs/ART_BIBLE.md`.

**Files:**
- Create: `art/env/src/diner_t2_src.tscn`, `art/env/diner_t2.tscn` (root `DinerArt` with the same `diner_art.gd` and
  `Board` label), baked `art/env/baked/diner_t2.res`
- Modify: `art/env/bake_manifest.gd`, `world/world.gd` → **wiring note** (`_build_diner` picks the mesh by tier and
  `rebuild_for_tier` swaps it)
- Test: `tests/unit/test_diner_art.gd` (add)

**Interfaces:**
- Produces: `World.DINER_ART_T2: PackedScene`, `World.diner_scene_for(tier: int) -> PackedScene`, the swap inside
  `rebuild_for_tier` (`diner_body.get_node("Visual")` keeps `OccluderFade` as its child; only the `DinerArt` child is
  replaced, then `occluder_fade.refresh_bounds()`).

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_diner_art.gd`:

```gdscript
func test_tier2_diner_keeps_the_footprint_and_adds_the_flanks() -> void:
	var t1: ArrayMesh = load("res://art/env/baked/diner.res")
	var t2: ArrayMesh = load("res://art/env/baked/diner_t2.res")
	var a1 := t1.get_aabb()
	var a2 := t2.get_aabb()
	assert_almost_eq(a2.size.y, a1.size.y, 0.3, "same height class")
	assert_gt(a2.size.x, a1.size.x + 1.0, "awnings and terrace widen the look")
	assert_lte(a2.size.x, 8.0 + 2.0 * 1.6, "but stay inside the yards' inner edges")
	assert_lte(_triangles(t2), ArtBudgets.budget_for("res://art/env/diner"))

func test_tier2_diner_surfaces_use_shared_materials() -> void:
	var t2: ArrayMesh = load("res://art/env/baked/diner_t2.res")
	for i in t2.get_surface_count():
		var m := t2.surface_get_material(i)
		assert_not_null(m)
		assert_true(m.resource_path.begins_with("res://art/materials/"), m.resource_path)

func test_world_swaps_the_diner_on_tier_reached() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	main.phase_controller.start_new_game(1)
	var body := main.world.diner_body.get_node("Visual").get_node("DinerArt").get_node("Body") as MeshInstance3D
	assert_eq(body.mesh.resource_path, "res://art/env/baked/diner.res")
	GameState.debug_set_tier(2, 1)
	GameState.complete_tier_up.call_deferred() if false else null  # debug_set_tier emits tier_changed, not tier_reached: rebuild directly
	main.world.rebuild_for_tier()
	await get_tree().process_frame
	body = main.world.diner_body.get_node("Visual").get_node("DinerArt").get_node("Body") as MeshInstance3D
	assert_eq(body.mesh.resource_path, "res://art/env/baked/diner_t2.res")
	assert_not_null(main.world.diner_body.get_node("Visual").get_node("OccluderFade"), "the fade survives the swap")
	var shape: BoxShape3D = main.world.diner_body.find_children("*", "CollisionShape3D", false, false)[0].shape
	assert_eq(shape.size, Vector3(8, 3, 8), "collision never changes")
```

(`_triangles` exists in this file already for the tier-1 budget test; reuse it. Remove the no-op line in the third
test when writing it; it is here only to say that `debug_set_tier` does not emit `tier_reached`.)

- [ ] **Step 2: Build the art**

`art/env/src/diner_t2_src.tscn`: instance `diner_src.tscn`'s content (copy the nodes, not an inherited scene, so the
bake sees them), add on each flank (x = ±4.0 to ±5.6, z from −3 to 3) a `detail-awning-wide` from
`assets/kenney-city-commercial/` with the shared `kenney-city-commercial__colormap.tres`, rotated to hang off the wall
at y 2.4, and a terrace: a flat `BoxMesh` 1.6 × 0.12 × 6.0 in `diner_cream` via the shared palette material at y 0.06.
Nothing above y 3.4 (the occluder boxes), nothing past x ±5.6 (the yards start at ±9.0 / 9.5). Add the manifest entry
and bake: `"$GODOT" --headless --path . -s res://tools/bake_static.gd -- --all`. `art/env/diner_t2.tscn` = `diner.tscn`
with the mesh path swapped. Shots: `tools/shots.sh /tmp/e5_t11` from `HOME` at tier 2 by day and night (add a tier-2
shot to the shot list, using `debug_set_tier`); answer R1 to R8 in the report.

**Wiring note (`world/world.gd`, hot):**

```gdscript
const DINER_ART_T2 := preload("res://art/env/diner_t2.tscn")

static func diner_scene_for(tier: int) -> PackedScene:
	return DINER_ART_T2 if tier >= 2 else DINER_ART

# in rebuild_for_tier(), after the spots:
	var vis := diner_body.get_node("Visual")
	var want_scene := diner_scene_for(GameState.tier if not GameState.buildings.is_empty() else 1)
	var art := vis.get_node_or_null("DinerArt")
	if art == null or art.scene_file_path != want_scene.resource_path:
		if art != null:
			vis.remove_child(art)
			art.queue_free()
		var fresh := want_scene.instantiate()
		vis.add_child(fresh)
		vis.move_child(fresh, 0)
		occluder_fade.refresh_bounds()
```

- [ ] **Step 3: Run the unit suite; commit**

```bash
git add art/env/src/diner_t2_src.tscn art/env/diner_t2.tscn art/env/baked/diner_t2.res art/env/bake_manifest.gd tests/unit/test_diner_art.gd
git commit -m "art(e5): the tier-2 diner: flank awnings and a terrace, baked, swapped per tier"
```

### Task 12: The reveal

Spec 7.5.

**Files:**
- Create: `world/tier_reveal.gd` (`class_name TierReveal`)
- Modify: `world/camera_rig.gd` (`reveal`), `balance/ui_tuning.gd` → **wiring note** (`tier_reveal_zoom 1.25`,
  `tier_reveal_in_s 0.6`, `tier_reveal_out_s 0.8`, `tier_reveal_step_s 0.35`)
- Modify: `world/world.gd` → **wiring note** (create `TierReveal` after `Reactions`; expose `yard_stones`, `ground`,
  `diner_body`, `build_spots` which it reads)
- Test: `tests/unit/test_tier_reveal.gd`, `tests/unit/test_camera_rig.gd` (add)

**Interfaces:**
- Consumes: `EventBus.tier_reached`, `state_restored`, `banner_requested`, `sfx_requested`, `fx_requested`, `PopFx`,
  `World.rebuild_for_tier` (runs first: World connects `tier_reached` before TierReveal is created, and Godot calls
  connections in order).
- Produces: `CameraRig.reveal(seconds_in: float, seconds_out: float, zoom: float)`, `CameraRig.zoom_now() -> float`;
  `TierReveal.steps_left() -> int`, `TierReveal.running() -> bool`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_tier_reveal.gd`:

```gdscript
extends GutTest
## E5 spec 7.5: the reveal is visual, ordered, killed by a restore, and the state is already saved before it starts.

var main: Main
var banners: Array = []
var sfx: Array = []

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	main.phase_controller.start_new_game(20260930)
	banners.clear()
	sfx.clear()
	EventBus.banner_requested.connect(func(t): banners.append(t))
	EventBus.sfx_requested.connect(func(id): sfx.append(id))

func _tier_up() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	main.phase_controller.debug_skip_to_night()
	main.phase_controller.debug_skip_to_day()  # the won boss night's dawn

func test_reveal_runs_the_steps_in_order() -> void:
	_tier_up()
	var reveal: TierReveal = main.world.get_node("TierReveal")
	assert_true(reveal.running())
	assert_true(banners.has(tr("The diner grows!")))
	assert_gt(main.camera_rig.zoom_now(), 1.0, "pulled back")
	var builds0 := sfx.count(&"build_done")
	for i in int(ceil(Balance.ui.tier_reveal_step_s * 6.0 * 60.0)) + 5:
		await get_tree().physics_frame
	assert_false(reveal.running())
	assert_gte(sfx.count(&"build_done") - builds0, 5, "one sound per step")
	assert_almost_eq(main.camera_rig.zoom_now(), 1.0, 0.02, "back at rest")

func test_restore_kills_the_reveal() -> void:
	_tier_up()
	var reveal: TierReveal = main.world.get_node("TierReveal")
	assert_true(reveal.running())
	GameState.new_game(3)
	await get_tree().process_frame
	assert_false(reveal.running())
	assert_almost_eq(main.camera_rig.zoom_now(), 1.0, 1e-6)

func test_state_is_tier_2_before_the_first_step() -> void:
	_tier_up()
	assert_eq(GameState.tier, 2)
	assert_eq(main.world.yard_ids(), ["west", "east"], "World rebuilt before the reveal pops things in")
```

Append to `tests/unit/test_camera_rig.gd`:

```gdscript
func test_reveal_zooms_out_and_back_and_is_visual_only() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	var hero := Hero.new()
	add_child_autofree(hero)
	rig.setup(hero)
	rig.reveal(0.2, 0.2, 1.25)
	rig._process(0.1)
	assert_between(rig.zoom_now(), 1.0, 1.25)
	rig._process(0.1)
	assert_almost_eq(rig.zoom_now(), 1.25, 0.02)
	rig._process(0.3)
	assert_almost_eq(rig.zoom_now(), 1.0, 0.02)
	var d0 := Balance.ui.camera_distance
	assert_eq(Balance.ui.camera_distance, d0, "UiTuning is never written")
```

- [ ] **Step 2: Run them to verify they fail**

Expected: FAIL (`TierReveal`, `reveal`, `zoom_now` missing).

- [ ] **Step 3: Implement**

`world/camera_rig.gd`:

```gdscript
var _zoom := 1.0
var _zoom_goal := 1.0
var _zoom_in_left := 0.0
var _zoom_out_left := 0.0
var _zoom_in_s := 0.0
var _zoom_out_s := 0.0
var _zoom_target := 1.0

## E5 spec 7.5: a visual pull-back (camera_distance x zoom) eased out over seconds_in, held, back over seconds_out.
func reveal(seconds_in: float, seconds_out: float, zoom: float) -> void:
	_zoom_target = zoom
	_zoom_in_s = maxf(seconds_in, 1e-3)
	_zoom_out_s = maxf(seconds_out, 1e-3)
	_zoom_in_left = _zoom_in_s
	_zoom_out_left = _zoom_out_s

func zoom_now() -> float:
	return _zoom

func _zoom_step(delta: float) -> void:
	if _zoom_in_left > 0.0:
		_zoom_in_left = maxf(_zoom_in_left - delta, 0.0)
		_zoom = lerpf(1.0, _zoom_target, ease(1.0 - _zoom_in_left / _zoom_in_s, -2.0))
	elif _zoom_out_left > 0.0:
		_zoom_out_left = maxf(_zoom_out_left - delta, 0.0)
		_zoom = lerpf(_zoom_target, 1.0, ease(1.0 - _zoom_out_left / _zoom_out_s, -2.0))
	else:
		_zoom = 1.0
```

In `_process`, call `_zoom_step(delta)` and build the transform with a zoomed copy of the tuning:
`var xf := CameraMath.camera_transform(_focus, Balance.ui)` becomes

```gdscript
	var xf := CameraMath.camera_transform(_focus, Balance.ui)
	if not is_equal_approx(_zoom, 1.0):
		var dir := (xf.origin - Vector3(_focus.x, 0.0, _focus.y))
		xf.origin = Vector3(_focus.x, 0.0, _focus.y) + dir * _zoom
```

`_on_state_restored` also sets `_zoom = 1.0`, `_zoom_in_left = 0.0`, `_zoom_out_left = 0.0`. (`CameraRig.new()` without
a hero returns early in `_process`; the test's `setup(hero)` gives it one.)

`world/tier_reveal.gd`:

```gdscript
class_name TierReveal
extends Node
## E5 spec 7.5 (D-243): the morning after a won boss night. Visual only: the state is saved before the first step; a
## restore kills everything. Steps 0.35 s apart: west yard ground pop, west stones, the tier-2 diner, east yard, east
## stones, the yard spot markers; each with the build sound and a dust puff.

var _world: World
var _tween: Tween
var _steps: Array = []

func setup(world: World) -> void:
	_world = world
	name = "TierReveal"
	EventBus.tier_reached.connect(_on_tier_reached)
	EventBus.state_restored.connect(_cancel)

func running() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()

func steps_left() -> int:
	return _steps.size()

func _cancel() -> void:
	PopFx.kill(_tween)
	_tween = null
	_steps = []
	if _world.yard_stones != null:
		_world.yard_stones.scale = Vector3.ONE
	_world.ground.scale = Vector3.ONE

func _on_tier_reached(_tier: int) -> void:
	_cancel()
	EventBus.banner_requested.emit(tr("The diner grows!"))
	var ui := Balance.ui
	var main := _world.get_parent() as Main
	if main != null and main.camera_rig != null:
		main.camera_rig.reveal(ui.tier_reveal_in_s, ui.tier_reveal_out_s + ui.tier_reveal_step_s * 6.0, ui.tier_reveal_zoom)
	var west: Rect2 = MapLayout.YARDS["west"]
	var east: Rect2 = MapLayout.YARDS["east"]
	var art := _world.diner_body.get_node("Visual").get_node_or_null("DinerArt") as Node3D
	_steps = [
		[_world.ground, MapLayout.to3(west.get_center())],
		[_world.yard_stones, MapLayout.to3(west.get_center(), 0.3)],
		[art, Vector3(0, 3.5, 0)],
		[_world.ground, MapLayout.to3(east.get_center())],
		[_world.yard_stones, MapLayout.to3(east.get_center(), 0.3)],
		[null, MapLayout.to3(MapLayout.spot_position("tower_w"), 1.0)],
	]
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	for i in _steps.size():
		_tween.tween_callback(_step.bind(i)).set_delay(ui.tier_reveal_step_s if i > 0 else 0.0)

func _step(i: int) -> void:
	if i >= _steps.size():
		return
	var target: Node3D = _steps[i][0]
	var at: Vector3 = _steps[i][1]
	EventBus.sfx_requested.emit(&"build_done")
	EventBus.fx_requested.emit(&"dust", at)
	if target != null and is_instance_valid(target):
		var base := Vector3.ONE
		target.scale = base * 0.98
		var t := create_tween()
		t.tween_property(target, "scale", base, Balance.ui.build_pop_time)
	if i == _steps.size() - 1:
		for id in MapLayout.TIER_SPOTS.get(GameState.tier, []):
			var s: BuildSpot = _world.build_spots.get(id)
			if s != null:
				PopFx.pop(self, s.marker, Vector3.ONE, null)
		_steps = []
```

(Scaling the whole ground mesh by 0.98 about the origin is a 2% breathing of the terrain for 0.2 s; it reads as "the
land settles". If the shots show the horizon edge, pop only the stones and the diner and leave the ground steps as
sound and dust.)

**Wiring notes (hot):** `balance/ui_tuning.gd`: `@export var tier_reveal_zoom := 1.25`, `tier_reveal_in_s := 0.6`,
`tier_reveal_out_s := 0.8`, `tier_reveal_step_s := 0.35`. `world/world.gd` `_ready`, after `Reactions`:
`var reveal := TierReveal.new(); add_child(reveal); reveal.setup(self)`.

- [ ] **Step 4: Run the unit suite and the baseline; commit**

```bash
git add world/tier_reveal.gd* world/camera_rig.gd tests/unit/test_tier_reveal.gd* tests/unit/test_camera_rig.gd
git commit -m "feat(e5): the tier-up reveal: banner, camera pull-back, yards and diner popping in"
```

**Phase 3 gate (main session):** `./run_tests.sh all` green, `baseline identical`, the Task 11 shots reviewed, wiring
notes of Tasks 9 to 12 applied, device check on the preview URL (the sign, the yards, the tier-2 diner from `HOME`),
PR `e5/p3-world` self-merged.

---

# Phase 4: `e5/p4-sims` (ends at a checkpoint)

### Task 13: TierBot

Spec 8.1 (bots).

**Files:**
- Create: `actors/bots/tier_bot.gd` (`class_name TierBot`)
- Test: `tests/unit/test_tier_bot.gd`

**Interfaces:**
- Consumes: `UpgraderBot` (`idle_goal` buys the cheapest station level), `PlannerBot.next_purchase` (over
  `GameState.buildings.keys()`: check it iterates `MapLayout.SPOT_IDS` in `rest` and `_spot_threat`; TierBot overrides
  `next_purchase` to run the same scoring over `buildings.keys()`), `WaypointGraph.create_for_tier(2)`,
  `GameState.tier_remaining_cost`, `pay_into_tier`, `EventBus.tier_reached`.
- Produces: `TierBot` with `choose_card` = planner's, night = naive, day order: planner defense → tier-up → yard
  towers (inside the planner's scoring once unlocked) → stations → close up. `TierBot.tier_ups: int` (times it paid in
  full), `TierBot.boss_nights_won: int`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_tier_bot.gd`:

```gdscript
extends GutTest
## E5 spec 8.1: the tier bot pays the tier-up before stations, builds the yard towers once they exist, and routes to them.

func before_each() -> void:
	Balance.reset()

func test_graph_has_the_tier_nodes_and_the_default_is_untouched() -> void:
	var bot := TierBot.new()
	for n in ["tier_sign", "tower_w", "tower_e"]:
		assert_true(bot.graph.nodes.has(n), n)
	assert_eq(WaypointGraph.create_default().nodes.size(), 19)
	bot.free()

func test_idle_goal_prefers_the_tier_up_when_affordable() -> void:
	GameState.new_game(1)
	var bot := TierBot.new()
	GameState.add_gold(500)
	assert_eq(bot.idle_goal(), "tier_sign")
	GameState.gold = 499  # test-only setup
	assert_eq(bot.idle_goal(), UpgraderBot.new().idle_goal(), "below the cost it behaves as the upgrader")
	GameState.add_gold(1)
	GameState.pay_into_tier(500)
	assert_ne(bot.idle_goal(), "tier_sign", "paid: nothing more to do at the sign")
	bot.free()

func test_next_purchase_includes_the_yard_towers_at_tier_2() -> void:
	GameState.new_game(1)
	GameState.debug_set_tier(2, 1)
	for id in MapLayout.SPOT_IDS:  # test-only setup: tier-1 defense maxed
		GameState.buildings[id].level = Balance.data.build.max_level
	GameState.add_gold(40)
	var bot := TierBot.new()
	var p := bot.next_purchase()
	assert_true(p in ["tower_w", "tower_e"], p)
	bot.free()

func test_keeps_standing_on_the_sign_mid_payment() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	var bot := TierBot.new()
	main.add_child(bot)
	bot.setup(main)
	main.phase_controller.start_new_game(20260930)
	main.phase_controller.debug_skip_to_day()
	for id in MapLayout.SPOT_IDS:
		GameState.buildings[id].level = Balance.data.build.max_level  # test-only setup
	GameState.stations[&"counter"].level = Balance.data.stations.max_level  # test-only setup
	GameState.stations[&"freezer"].level = Balance.data.stations.max_level  # test-only setup
	GameState.add_gold(500)
	var ok := false
	for i in 60 * 40:
		await get_tree().physics_frame
		if GameState.boss_pending:
			ok = true
			break
	assert_true(ok, "the bot walked to the sign and paid in full")
	assert_eq(bot.tier_ups, 1)
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL (`TierBot` not found).

- [ ] **Step 3: Implement**

`actors/bots/tier_bot.gd`:

```gdscript
class_name TierBot
extends UpgraderBot
## E5 spec 8.1: UpgraderBot that buys the tier-up before station levels and builds the yard towers once they exist.
## Day order: the planner's defense for tonight, then the tier sign when affordable, then stations, then close up.

var tier_ups := 0
var boss_nights_won := 0

func _init() -> void:
	graph = WaypointGraph.create_for_tier(2)   # the slice's content, so the sign is reachable at tier 1
	# the upgrader's pads (its _init added them to the default graph; redo on this graph)
	graph.add_node("pad_counter", MapLayout.STATION_PADS[&"counter"])
	graph.add_edge("pad_counter", "front_e")
	graph.add_edge("pad_counter", "home")
	graph.add_node("pad_freezer", MapLayout.STATION_PADS[&"freezer"])
	graph.add_edge("pad_freezer", "se")
	graph.add_edge("pad_freezer", "freezer")

func setup(m: Main) -> void:
	super.setup(m)
	EventBus.tier_paid_up.connect(func(_n): tier_ups += 1)
	EventBus.tier_reached.connect(func(_t): boss_nights_won += 1)

func day_think(delta: float) -> void:
	if goal == "tier_sign" and arrived() and GameState.tier_paid > 0 and GameState.gold > 0 and GameState.tier_remaining_cost() > 0:
		return
	super.day_think(delta)

## The tier-up first, then the upgrader's cheapest station level, then the sign.
func idle_goal() -> String:
	var rem := GameState.tier_remaining_cost()
	if rem > 0 and rem <= GameState.gold:
		return "tier_sign"
	return super.idle_goal()

## The planner's scoring over every spot the tier has (the planner itself stays on SPOT_IDS, D-237).
func next_purchase() -> String:
	var threat := LanePlanner.threat_by_lane(GameState.lane_plan, Balance.data.enemy.hp)
	var best := ""
	var best_t := -1.0
	for id in GameState.buildings.keys():
		var rem := GameState.remaining_cost(id)
		if rem <= 0 or rem > GameState.gold:
			continue
		var t := _spot_threat(id, threat)
		if t > best_t + 1e-6 or (is_equal_approx(t, best_t) and MapLayout.ALL_SPOT_IDS.find(id) < MapLayout.ALL_SPOT_IDS.find(best)):
			best = id
			best_t = t
	if best != "":
		return best
	return super.next_purchase()
```

(`_spot_threat` is the planner's helper; it takes a spot id and the threat dictionary and uses `TOWER_LANES` /
`FENCE_LANE`, which already know the yard towers. If it is private to the planner, make it protected by name only: GDScript
has no access control, so the call works.) The planner's own `next_purchase` runs on `SPOT_IDS` as before; TierBot's
first pass covers the yard towers and any affordable spot by threat, then falls back to the planner's ordering.

- [ ] **Step 4: Run the unit suite and the baseline; commit**

```bash
git add actors/bots/tier_bot.gd* tests/unit/test_tier_bot.gd*
git commit -m "feat(e5): TierBot buys the tier-up before stations and builds the yard towers"
```

### Task 14: Fixtures

Spec 8.1 (fixtures), 8.4.

**Files:**
- Modify: `tests/sim/make_save.gd` (new `--fixture=` values), `export/perf_night3.sh` (nothing: it already takes a
  fixture name; confirm with `grep -n FIXTURE export/perf_night3.sh`)
- Create: `export/fixtures/boss_night_tier1.save.json`, `boss_only.save.json`, `tier2_night1.save.json`,
  `tier2_full.save.json`, `tier2_night.save.json` (perf: the full build at the cap, resume NIGHT)
- Test: `tests/unit/test_tier_fixtures.gd`

**Interfaces:**
- Produces: the five fixtures at schema 5; `make_save.gd` runs a `TierBot` to the first boss-night close-up (seed
  20260930) and derives every fixture from that snapshot with `debug_set_*`-style edits on the dictionary.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_tier_fixtures.gd`:

```gdscript
extends GutTest
## E5 spec 8.1: the tier fixtures are valid schema 5 saves with the states the sims rely on.

func before_each() -> void:
	Balance.reset()

func _decode(stem: String) -> Dictionary:
	var text := FileAccess.get_file_as_string("res://export/fixtures/%s.save.json" % stem)
	return SaveCodec.decode(text, GameState.SCHEMA_VERSION, Balance.data)

func test_boss_night_tier1() -> void:
	var r := _decode("boss_night_tier1")
	assert_true(r.ok, r.reason)
	var s := r.state
	assert_eq([s.resume_phase, s.tier, s.boss_pending, s.night_fails], ["NIGHT", 1, true, 0])
	assert_gte(int(s.day), 8)
	assert_true(bool(s.lane_plan[2].boss))
	assert_gt(int(s.cards.get("tank", 0)), 0)
	assert_gt(int(s.cards.get("archer", 0)), 0)
	var levels := 0
	for id in MapLayout.SPOT_IDS:
		levels += int(s.buildings[id].level)
	assert_gte(levels, 12, "most of the tier-1 defense is built")

func test_boss_only() -> void:
	var r := _decode("boss_only")
	assert_true(r.ok, r.reason)
	var s := r.state
	assert_eq(s.resume_phase, "NIGHT")
	for w in 2:
		assert_eq([s.lane_plan[w].main_count, s.lane_plan[w].side_count], [0, 0])
	assert_eq([s.lane_plan[2].main_count, s.lane_plan[2].side_count, s.lane_plan[2].boss], [0, 0, true])
	for id in s.buildings:
		assert_eq(int(s.buildings[id].level), 0, "no builds")
	assert_eq(s.cards, {}, "no guards")

func test_tier2_night1_and_full_and_perf() -> void:
	var n1 := _decode("tier2_night1").state
	assert_eq([n1.resume_phase, n1.tier, n1.tier_day, n1.day], ["NIGHT", 2, 9, 9])
	assert_eq([n1.buildings.tower_w.level, n1.buildings.tower_e.level], [0, 0])
	assert_false(bool(n1.lane_plan[2].boss))
	for stem in ["tier2_full", "tier2_night"]:
		var f := _decode(stem).state
		assert_eq([f.resume_phase, f.tier], ["NIGHT", 2])
		assert_gte(int(f.day) - int(f.tier_day), 3, "at the cap")
		for id in MapLayout.spots_for_tier(2):
			assert_eq(int(f.buildings[id].level), Balance.data.build.max_level, id)
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL (files missing).

- [ ] **Step 3: Extend `make_save.gd`**

Accept `--fixture=tier` (writes all five). Run a `TierBot` from seed 20260930 and capture the close-up snapshot
(`resume_phase DAY`) of the first day with `boss_pending` true; call it `base` (its `day` is the boss night's day).
Then:

```gdscript
func _write_tier_fixtures(base: Dictionary) -> void:
	var tb = root.get_node("Balance").data.tiers
	var bb = root.get_node("Balance").data.build
	var boss := base.duplicate(true)
	boss.resume_phase = "NIGHT"
	boss.night_fails = 0
	_write("boss_night_tier1", boss)

	var only := boss.duplicate(true)
	for id in only.buildings:
		only.buildings[id] = {"level": 0, "paid": 0, "hp": 0.0}
	only.cards = {}
	only.guards = {}
	only.card_offer = []
	for w in only.lane_plan:
		w.main_count = 0
		w.side_count = 0
		w.fast_main = 0
		w.fast_side = 0
	only.lane_plan[2].boss = true
	_write("boss_only", only)

	# tier 2 entered the morning after the boss night: day + 1, pressure at the tier's base, yard spots at 0
	var t2 := base.duplicate(true)
	t2.resume_phase = "NIGHT"
	t2.tier = 2
	t2.boss_pending = false
	t2.tier_paid = 0
	t2.day = int(base.day) + 1
	t2.tier_day = t2.day
	for id in MapLayout.TIER_SPOTS[2]:
		t2.buildings[id] = {"level": 0, "paid": 0, "hp": 0.0}
	t2.lane_plan = _plan(t2)
	_write("tier2_night1", t2)

	var full := t2.duplicate(true)
	full.day = int(t2.tier_day) + tb.fast_ramp_days[2]
	for id in full.buildings:
		var lvl: int = bb.max_level
		full.buildings[id] = {"level": lvl, "paid": 0, "hp": bb.fence_hp[lvl - 1] if MapLayout.spot_kind(id) == "fence" else 0.0}
	full.lane_plan = _plan(full)
	_write("tier2_full", full)
	_write("tier2_night", full)

func _plan(s: Dictionary) -> Array:
	return LanePlanner.plan(int(s.run_seed), int(s.day), root.get_node("Balance").data.wave, int(s.tier), int(s.tier_day), root.get_node("Balance").data.tiers)
```

(`make_save.gd` extends `SceneTree` and names no autoloads at parse time (D-150): reach `Balance` through
`root.get_node("Balance")` as the file already does, and `MapLayout` / `LanePlanner` are `class_name`s, fine to call.)
`tier2_night1` keeps the base's stations; the sims that start from it do not care. If the `TierBot` never pays the tier
within 30 game-minutes, the script fails loudly; then lower `tier_costs[1]` is **not** the answer: report it (the bot
should afford 500 by day 8 or 9 with defense first).

Run: `"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/make_save.gd -- --fixture=tier`

- [ ] **Step 4: Run the unit suite; commit**

```bash
git add tests/sim/make_save.gd export/fixtures/boss_night_tier1.save.json export/fixtures/boss_only.save.json export/fixtures/tier2_night1.save.json export/fixtures/tier2_full.save.json export/fixtures/tier2_night.save.json tests/unit/test_tier_fixtures.gd*
git commit -m "test(e5): tier fixtures (boss night, boss only, tier-2 first night, tier-2 full build)"
```

### Task 15: The four tier sims

Spec 8.1 (sims), success criterion 5.

**Files:**
- Create: `tests/sim/test_tier_sims.gd`
- Modify: `tests/sim/sim_harness.gd` (`start_from(fixture_stem, bot_script)`; `boss_hits: Array` of `(elapsed, kind)`)
- Modify: `balance/sim_thresholds.gd` → **wiring note** (`boss_night_max_retries := 2`)

**Interfaces:**
- Produces: `SimHarness.start_from(stem: String, bot_script: GDScript)` (creates `Main`, adds the bot, decodes the
  fixture, `resume_from`); `SimHarness.first_boss_hit_s: float` (elapsed at the first `diner_damaged` while
  `wave_director.boss_alive()` and no other monster is alive) and `fell_s: float` (elapsed at `diner_fell`).

- [ ] **Step 1: Write the sims**

`tests/sim/test_tier_sims.gd`:

```gdscript
extends GutTest
## E5 spec 8.1 sims 1 to 4 (D-242, D-244). Each starts from an injected fixture (tests/sim/make_save.gd --fixture=tier).

const SEED := 20260930
var h: SimHarness

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)

func after_each() -> void:
	h.finish()

func test_1_the_tier_bot_wins_the_boss_night_within_the_allowed_retries() -> void:
	h.start_from("boss_night_tier1", TierBot)
	var max_r: int = Balance.data.sim.boss_night_max_retries
	var retries := 0
	var n := await h.run_night()
	while n.failed and retries < max_r:
		retries += 1
		var restored := await h.run_until(func(): return not h.main.phase_controller.failing, Balance.ui.banner_time + 1.0)
		assert_true(restored, "the fail flow restores")
		assert_true(GameState.boss_pending, "the boss is still pending after a loss")
		var d := await h.run_day()
		assert_true(d.closed, "the bot closes up again")
		n = await h.run_night()
	gut.p("boss night won after %d retries (max %d); diner_frac %.3f" % [retries, max_r, n.diner_frac])
	assert_true(n.cleared, "the boss night is won within %d retries" % max_r)
	assert_eq(GameState.tier, 2, "the dawn tiered up")
	assert_true(GameState.buildings.has("tower_w"))

func test_2_the_boss_alone_needs_at_least_boss_min_hold_s_to_fell_the_diner() -> void:
	h.start_from("boss_only", ParkedBot)
	var n := await h.run_night(400.0)
	assert_true(n.failed, "with no defense the boss fells the diner")
	var hold := h.fell_s - h.first_boss_hit_s
	gut.p("boss alone: first hit at %.1f s, diner fell at %.1f s, hold %.1f s (min %.1f)" % [h.first_boss_hit_s, h.fell_s, hold, Balance.data.tiers.boss_min_hold_s])
	assert_gte(hold, Balance.data.tiers.boss_min_hold_s)

func test_3_the_tier_bot_holds_the_first_tier2_night() -> void:
	h.start_from("tier2_night1", TierBot)
	var n := await h.run_night()
	gut.p("tier-2 night 1: %s" % n)
	assert_true(n.cleared, "no retry on the first tier-2 night (D-241)")

func test_4_a_full_tier2_build_clears_the_cap_with_0_retries_on_three_seeds() -> void:
	for seed in [20260930, 1, 2]:
		h.finish()
		await get_tree().process_frame
		Balance.reset()
		h = SimHarness.new(self)
		h.start_from("tier2_full", NaiveBot, seed)
		var n := await h.run_night()
		gut.p("tier-2 cap, seed %d: %s" % [seed, n])
		assert_true(n.cleared, "seed %d holds the cap (D-244)" % seed)
```

`SimHarness`:

```gdscript
var first_boss_hit_s := -1.0
var fell_s := -1.0

## E5: start from an injected fixture. `seed` != 0 re-seeds the run (the lane plan is re-made for that seed and day).
func start_from(stem: String, bot_script: GDScript, seed := 0) -> void:
	main = Main.create()
	parent.add_child(main)
	bot = bot_script.new()
	bot.name = "Bot"
	main.add_child(bot)
	bot.setup(main)
	EventBus.diner_damaged.connect(_on_diner_damaged)
	EventBus.enemy_killed.connect(_on_killed)
	EventBus.night_failed.connect(_on_failed)
	EventBus.diner_fell.connect(_on_fell)
	var text := FileAccess.get_file_as_string("res://export/fixtures/%s.save.json" % stem)
	var r := SaveCodec.decode(text, GameState.SCHEMA_VERSION, Balance.data)
	assert(r.ok, "fixture %s: %s" % [stem, r.reason])
	var state: Dictionary = r.state
	if seed != 0:
		state.run_seed = seed
		state.lane_plan = LanePlanner.plan(seed, int(state.day), Balance.data.wave, int(state.tier), int(state.tier_day), Balance.data.tiers)
	main.phase_controller.resume_from(state)

func _on_diner_damaged(_amount: float, hp_left: float) -> void:
	diner_min = minf(diner_min, hp_left)
	if first_boss_hit_s < 0.0 and main.world.wave_director.boss_alive():
		first_boss_hit_s = elapsed

func _on_fell() -> void:
	fell_s = elapsed
```

(`finish()` disconnects `diner_fell` too. `run_night` resets `first_boss_hit_s` and `fell_s` to -1.)

- [ ] **Step 2: Run the sim suite**

Run: `./run_tests.sh sim`
Expected: the four sims print their lines; `SIM SUITE: Ns (budget 60s)`. Record N per test (GUT prints per-script
times; add `gut.p` timestamps if needed). If a sim fails on balance (not on a bug), stop and report the numbers: tuning
is Task 16b (main session, D-103).

- [ ] **Step 3: Commit**

```bash
git add tests/sim/test_tier_sims.gd* tests/sim/sim_harness.gd
git commit -m "test(e5): boss night, boss-only hold, tier-2 first night and tier-2 cap sims"
```

### Task 16: Tier sweep, retired target, baseline re-record

Spec 8.2, 8.3; D-237.

**Files:**
- Modify: `tests/sim/sweep_runner.gd`, `tools/baseline_diff.sh`, `balance/sim_thresholds.gd` (**main purpose**: remove
  `break_day_target`, `break_day_tolerance`; add `boss_night_max_retries` if Task 15's wiring note is still pending),
  `tests/unit/test_balance.gd:68`
- Create: `tools/baseline_rows.sh`
- Re-record: `tests/sim/baseline/s4_sweep_<seed>.csv|.txt` for 20260930, 11, 777

**Interfaces:**
- Produces: `sweep.gd -- --bot=tier [--days=20]` → `tests/sim/out/sweep_tier.csv` with the upgrader columns plus
  `tier,boss_night,boss_retries`; the `SWEEP` line reads `SWEEP first_fail_day=%d hard_break_day=%d` (no target);
  for the tier bot a `TIER` line: `TIER first_tier2_day=%d boss_retries=%d unspent_day14=%d`; the planner's line also
  prints `unspent_day14=%d` so the gold criterion is read from two lines. `tools/baseline_rows.sh <rows>` diffs only
  the first `<rows>` data rows of each seed's CSV against the baseline and prints `rows 1-<rows> identical`.

- [ ] **Step 1: Sweep runner**

```gdscript
	if not String(args.bot) in ["planner", "upgrader", "tier"]:
		push_error("unknown --bot=%s (planner|upgrader|tier)" % args.bot)
	...
	var tier_mode := String(args.bot) == "tier"
	var upgrader := String(args.bot) == "upgrader" or tier_mode
	h.start(int(args.seed), TierBot if tier_mode else (UpgraderBot if upgrader else PlannerBot))
	var rows := ["day,...,picked" + (",stations" if upgrader else "") + (",tier,boss_night,boss_retries" if tier_mode else "")]
```

Per day, before `run_night`: `var boss_night := GameState.is_boss_night()`; after the retry loop append
`_tier_cols(tier_mode, boss_night, retries)` = `",%d,%d,%d" % [GameState.tier, 1 if boss_night else 0, retries if boss_night else 0]`
(and `""` when not tier mode). Track `first_tier2_day` (the first row with tier 2), `boss_retries` (the sum over boss
nights) and `unspent_day14` (the `unspent_gold_at_closeup` value of the day-14 row, -1 if the run never reached it).
Output file: `sweep_tier.csv` in tier mode. Lines:

```gdscript
	print("SWEEP first_fail_day=%d hard_break_day=%d unspent_day14=%d" % [first_fail_day, hard_break_day, unspent_day14])
	if tier_mode:
		print("TIER first_tier2_day=%d boss_retries=%d" % [first_tier2_day, boss_retries])
```

`_builds()` iterates `GameState.buildings.keys()` in `MapLayout.ALL_SPOT_IDS` order so the tier bot's row shows the
yard towers; the planner's row is unchanged (it never has them).

- [ ] **Step 2: Retire the target**

`balance/sim_thresholds.gd`: delete `break_day_target` and `break_day_tolerance` and their comment; add
`## E5 sim 1 (spec 8.1): retries the tier bot may need on the boss night.` `@export var boss_night_max_retries := 2`.
`tests/unit/test_balance.gd:68` becomes `assert_eq(Balance.data.sim.boss_night_max_retries, 2)`.

- [ ] **Step 3: `tools/baseline_rows.sh`**

```bash
#!/usr/bin/env bash
# E5 (D-237): the tier-1 identity. Re-runs the planner sweep for the 3 baseline seeds and diffs only the first N data
# rows (default 7) of each CSV against tests/sim/baseline/. Rows past N are allowed to differ (the tier-1 cap).
set -euo pipefail
: "${GODOT:?Set GODOT}"
N="${1:-7}"
cd "$(dirname "$0")/.."
T=$(mktemp -d); rc=0
for s in 20260930 11 777; do
  rm -f tests/sim/out/sweep.csv
  "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd -- --seed=$s > "$T/$s.log" 2>&1 || rc=1
  ! grep -q 'SCRIPT ERROR' "$T/$s.log" || { echo "SCRIPT ERROR in sweep $s"; rc=1; }
  [ -f tests/sim/out/sweep.csv ] || { echo "no sweep.csv for $s"; rc=1; continue; }
  head -n $((N + 1)) tests/sim/baseline/s4_sweep_$s.csv > "$T/base_$s.csv"
  head -n $((N + 1)) tests/sim/out/sweep.csv > "$T/now_$s.csv"
  diff -u "$T/base_$s.csv" "$T/now_$s.csv" || rc=1
done
[ $rc -eq 0 ] && echo "rows 1-$N identical" || echo "ROWS 1-$N DIFFER (logs: $T)"
exit $rc
```

`tools/baseline_diff.sh`: header comment → `# Determinism proof (S4 spec 6.3; re-recorded once for E5, D-237: rows 1 to 7
are the tier-1 identity, see baseline_rows.sh).`

- [ ] **Step 4: Re-record (one commit, its own)**

Before re-recording, run `tools/baseline_rows.sh 7` on the current head: it must print `rows 1-7 identical` against the
**old** baseline. Then for each seed: run the planner sweep and copy `tests/sim/out/sweep.csv` to
`tests/sim/baseline/s4_sweep_<seed>.csv`, and the `SWEEP` + `RETRIES` lines (as `baseline_diff.sh` greps them) to
`s4_sweep_<seed>.txt`. Produce the explanation for the PR: for each seed `diff -u old new`, and state that rows 1 to 7 are
untouched and which columns change in rows 8 to 14 (`enemy_count`, `kills`, `steaks`, `gold_earned`, `failed_retries`,
`diner_frac`, `night_seconds`, `day_seconds`, `unspent_gold_at_closeup`, `picked` may shift). Then `tools/baseline_diff.sh`
prints `baseline identical` again.

- [ ] **Step 5: Run the tier sweep and the planner sweep on the three target seeds**

```bash
for s in 20260930 1 2; do "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd -- --seed=$s --days=20 --bot=tier > /tmp/e5_tier_$s.txt; cp tests/sim/out/sweep_tier.csv /tmp/e5_tier_$s.csv; done
for s in 20260930 1 2; do "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd -- --seed=$s --days=14 > /tmp/e5_planner_$s.txt; cp tests/sim/out/sweep.csv /tmp/e5_planner_$s.csv; done
```

Read against spec 8.2's table: planner 0 retries on days 1 to 14; tier bot's first failure on its boss night or later;
tier-2 nights 1 to 3 at most 1 retry; `unspent_day14` tier < planner on every seed; every cap night after the full
build at 0 retries. Paste the `SWEEP`, `RETRIES` and `TIER` lines in the task report. A miss is a tuning input for Task
16b, not a reason to edit a target.

- [ ] **Step 6: Commit**

```bash
git add tests/sim/sweep_runner.gd tools/baseline_rows.sh tools/baseline_diff.sh balance/sim_thresholds.gd tests/unit/test_balance.gd
git commit -m "feat(e5): tier sweep mode, retired the first-fail target, baseline_rows.sh"
git add tests/sim/baseline/
git commit -m "test(e5): re-record the determinism baseline rows 8 to 14 for the tier-1 cap (D-237)

Rows 1 to 7 are byte-identical to the S4 baseline (tools/baseline_rows.sh 7 before the re-record). <per-seed summary>"
```

### Task 16b: Tuning (main session, D-103)

Only if Task 15 or 16 missed a target. Inputs: the sim prints and the sweep lines. Knobs, in the order to try: boss
`hp` (sim 1 and 2 pull opposite ways: raise HP for sim 2's hold, lower for sim 1's win), `tier_cap[2]` (sim 4: lower it
before anything else, D-244), `fast_share_start[2]` (sim 3), `tier_costs[1]` (the gold criterion and the tier bot's
first tier-2 day). Three rounds, then escalate with the numbers. Every changed default goes with its `test_balance.gd`
and `test_tier_effects.gd` / `test_monster_balance.gd` pins in the same commit, and spec section 4 is amended.

### Task 17: Perf readings and documents (main session)

Spec 8.4, 12; D-236 to D-247.

- [ ] **Step 1: Perf**

Rebuild the profile web export from the branch head (`export/README.md`), then, with the Mac at the D-199 idle level:

```bash
for f in tier2_night boss_night; do NIGHT_ONLY=1 DAY_FIXTURE=night3_closeup NIGHT_FIXTURE=$f export/perf_night3.sh build/web_profile /tmp/e5_perf_$f; done
```

(Check `export/perf_night3.sh` for the exact variable that names the night fixture; it took `DAY_FIXTURE` for E1. If it
has no night-fixture variable, add `NIGHT_FIXTURE` with the same pattern and commit it.) Median of 3 per fixture, the
frozen `PERF phase=NIGHT` line, draw calls. Gate: average within ±1 fps of D-221's 59.9; worst frame no worse than
106 ms. Record under `docs/review/media/e5/perf/`. Also record load time and the pck size (`export/load_size`), as D-235
did.

- [ ] **Step 2: Device check**

`export/device_check.sh <preview url> docs/review/media/e5/device` from the `tier2_full` fixture (the debug build takes
`?fixture=` if it exists; otherwise inject through the debug panel) and from `boss_night_tier1`: the sign, the boss bar,
the boss moon, the yards, the tier-2 diner from `HOME`, 100 steaks on the ground after the boss death. Label the
Android run **emulated** (D-141).

- [ ] **Step 3: Documents**

Apply spec section 12 word for word: `docs/IDEA.md` (the day loop line, the new "Diner tiers" section, "bosses" out of
"Later"), `docs/DECISIONS.md` (D-236 to D-247, D-247 marked pending or decided), `docs/REVIEW_QUEUE.md` (the "E5 tier
ladder (2026-10-06)" section with the playtest question), `CLAUDE.md` (the `MonsterBalance` line is **not** added since
`EnemyBalance` stays; the sweep line gains `--bot=tier`; the baseline line; the sim budget line only if D-247 is
accepted), `docs/E1_FOLLOWUPS.md` (strike item 24, folded into Task 5). Add the sweep results table (spec 8.2's rows
with the measured values and the `unspent_day14` numbers per seed) to the spec as section 16, "Results".

- [ ] **Step 4: Commit and open the checkpoint PR**

```bash
git add docs/ CLAUDE.md export/
git commit -m "docs(e5): decisions D-236 to D-247, IDEA tiers, review queue, perf and sweep readings"
```

The PR body carries: the baseline re-record explanation (Task 16), the sweep lines, the sim prints, the perf table, the
device shots. **Stop here: the author reads the PR before the merge (checkpoint).**

### Task 18 (gated on D-247): Split the sim suite

Only after the author accepts the proposal in spec 8.5. Otherwise this task is skipped and the plan says so in the PR.

**Files:**
- Create: `tests/sim_tier/` (move `tests/sim/test_tier_sims.gd` there; `tests/sim/make_save.gd`, `sim_harness.gd`,
  fixtures stay)
- Modify: `run_tests.sh` (main purpose), `.github/workflows/ci.yml` (main purpose), `CLAUDE.md` (main purpose)

- [ ] **Step 1: `run_tests.sh`**

```bash
  sim-tier)
    start=$SECONDS
    rc=0; run_gut -gdir=res://tests/sim_tier || rc=$?
    elapsed=$((SECONDS - start))
    echo "SIM-TIER SUITE: ${elapsed}s (budget 60s)"
    [ "$rc" -eq 0 ] || exit "$rc"
    if [ "$elapsed" -gt 60 ]; then echo "SIM-TIER SUITE OVER BUDGET"; exit 1; fi ;;
  all) "$SELF" unit && "$SELF" sim && "$SELF" sim-tier ;;
```

and the usage line. `--quick` is unchanged.

- [ ] **Step 2: CI**

Copy the `sim` job as `sim-tier` running `./run_tests.sh sim-tier`. The author adds `sim-tier` to the required checks
(agents never change branch protection, CLAUDE.md). `CLAUDE.md`: the layout line gains `tests/sim_tier/`, the commands
line gains `./run_tests.sh sim-tier`, the CI paragraph names three jobs, and D-247 is marked decided in DECISIONS.md.

- [ ] **Step 3: Run `./run_tests.sh all`; commit**

```bash
git add run_tests.sh .github/workflows/ci.yml CLAUDE.md tests/sim_tier/ tests/sim/
git commit -m "ci(e5): a third sim job with its own 60 s budget for the tier sims (D-247)"
```

---

## Self-review notes

- **Spec coverage:** 4.1 to 4.4 → Tasks 1, 3; 5.1 to 5.3 → Task 2; 6.1 to 6.2 → Task 4; 6.3 → Task 5; 6.4 → Task 8;
  7.1 → Tasks 6, 7; 7.2 → Task 9; 7.3 → Tasks 10, 11; 7.4 → Task 7; 7.5 → Task 12; 7.6, 7.7 → Task 8; 8.1 → Tasks
  13 to 15; 8.2, 8.3 → Task 16; 8.4 → Task 17; 8.5 → Task 18 (gated); 9 → the asserts and no-ops in Tasks 4, 6, 8;
  10, 11 → spec only; 12 → Task 17; 13 → the hot-file rule above; 14 → every task's tests.
- **Plan changes to the spec (spec section 15):** `EnemyBalance` and `WaveBalance.target_priority` are kept (Task 1);
  `enemy_killed` gains `kind` (Task 6, as the spec's 6.2 says); the reveal's camera pull-back lasts the whole step
  sequence (Task 12); the sweep prints `unspent_day14` on the `SWEEP` line and a `TIER` line (Task 16); the yard stones
  are spaced 1.2 m (Task 10); `SimThresholds.boss_night_max_retries` holds sim 1's allowance.
- **Type consistency checked:** `pay_into_tier(amount) -> int`, `tier_remaining_cost() -> int` (0 when pending, -1 at
  the top) in Tasks 4, 8, 9, 13; `Boar.spawn(..., kind)` in Tasks 6, 7, 15; `WaveSchedule.build(wave, wb, tb)` in
  Tasks 3, 6; `WaypointGraph.create_for_tier(tier)` in Tasks 2, 10, 13; `World.rebuild_for_tier()` in Tasks 10, 11, 12;
  `enemy_killed(i, lane, pos, kind)` in Tasks 6, 7, 15.
- **Review Focus coverage:** 1 → Task 5 (`test_schema_4_migrates_to_5_at_tier_1`) and Task 8
  (`test_old_tier1_save_past_day_7_replans_at_the_cap_on_its_next_dawn`); 2 → Task 4
  (`test_completing_the_payment_flags_the_boss_night_once`) and Task 9 (`test_standing_still_pays_and_completes`);
  3 → Task 8 (`test_lost_boss_night_restores_with_the_payment_kept`) and sim 1; 4 → Task 5
  (`test_rejects_spot_tier_mismatches`: an unknown id is "building"; a known tier above the top is clamped); 5 → Task 6
  (`test_hare_keeps_the_diner_when_the_fence_falls`).
