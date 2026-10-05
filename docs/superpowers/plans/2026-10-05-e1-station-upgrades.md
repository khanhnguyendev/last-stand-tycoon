# E1 Station Upgrades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The counter and the freezer can each be upgraded from level 0 to 5 with gold, by standing still on a pad;
level 0 is byte-identical to today's game.

**Architecture:** Station state lives in `GameState.stations`, apart from `buildings`. All numbers are in a new
`StationBalance` resource and are read only through the pure `StationEffects` helper. An `UpgradePad` node per station
takes the payment; the counter, the freezer and the traveler spawner read their values through `StationEffects` at the
moment they use them. Save schema 4 with a built-in 3-to-4 migration.

**Tech Stack:** Godot 4.7.2 (GDScript, Compatibility renderer), GUT 9.7.1, the existing sim harness and sweep.

**Spec:** `docs/superpowers/specs/2026-10-05-e1-station-upgrades-design.md` (D-222 to D-230). Read the spec section
named in each task before starting it.

## Global Constraints

- `export GODOT=/Users/ryan/Applications/Godot-4.7.2-stable/Godot.app/Contents/MacOS/Godot` in the same Bash call as
  any Godot or `./run_tests.sh` command. After creating a worktree, run `"$GODOT" --headless --path . --import` once.
- `./run_tests.sh unit` and `./run_tests.sh sim` pass; they fail on any `SCRIPT ERROR` or GUT error. The sim suite stays
  under 60 s (D-132); never drop, skip or weaken a test.
- **Level 0 is today's game:** `tools/baseline_diff.sh` prints `baseline identical` after every task from Task 3 on.
  The baseline in `tests/sim/baseline/` is never re-recorded. `NaiveBot`, `PlannerBot` and `GuideBot` never buy a
  station upgrade. No task changes an Rng call, its order, or `WaypointGraph.create_default()`.
- Gameplay in `_physics_process` only. Only `GameState` methods mutate game data. Tweens are visual only.
- Every number in `balance/`; every user string through `tr()`.
- Station ids are `StringName` (`&"counter"`, `&"freezer"`) everywhere in memory and `String` in snapshots.
- **Hot files** (D-136, D-139): `project.godot`, `CLAUDE.md`, `run_tests.sh`, `.github/workflows/*`, `autoload/*`,
  `balance/*`, `world/main.gd`, `world/main.tscn`, `world/world.gd`. A task edits and commits a hot file only when its
  **Files** list marks it `(main purpose)`. Any other hot-file change: the implementer writes it, saves it with
  `git diff -- <hot files> > /tmp/wiring_e1_t<NN>.patch`, keeps it applied locally for its test runs, never commits
  it, and pastes the patch text in its report. The main session applies and commits it after review.
- **Commits:** one per task on the phase branch; message `feat(e1): …`, `test(e1): …` or `docs(e1): …`; trailer = the
  `Co-Authored-By` line from your own session's attribution, then
  `Claude-Session: https://claude.ai/code/session_019nNyHrXgHzKVKBtdqy9Hez`.
- **Branches (D-133):** `e1/p1-core` (Tasks 1 to 4), `e1/p2-world` (Tasks 5 to 7), `e1/p3-sims` (Tasks 8 to 10), each
  from an up-to-date `main`. P1 and P2 are self-merged by the main session when CI is green and every task passed its
  reviewer (D-137). **P3 ends at a checkpoint:** the author plays the preview URL before the merge.
- Tests create the game with `Main.create()`, never `Main.new()`. Read state after `await get_tree().physics_frame`.
- Direct writes to `GameState` fields are allowed only in test setup, marked `# test-only setup` (existing convention).

## Review Focus

Inputs the spec implies but does not spell out, most likely first. Each has a test in the named task.

1. **A saved partial payment is larger than the next level's cost** (costs were lowered in a later build). Expected:
   the save loads and the pad still works. `pay_into_station` would otherwise never complete (it pays
   `cost - paid <= 0`). Task 4 clamps `paid` to `cost - 1` on load instead of rejecting the save. This replaces the
   spec's validation rule `paid < cost` (spec 5.5); Task 4 amends that spec line.
2. **`counter_steaks` is above the current capacity** (a save from a build with bigger tables). Expected: no crash,
   the pile shows what it has slots for, the hero cannot add more, travelers still buy. Task 6.
3. **The night starts while the hero is paying on a pad.** Expected: payment stops, the partial amount stays, the ring
   and label hide, and nothing is paid at night. Task 5.
4. **The hero holds less gold than one drain tick.** Expected: the pad takes exactly the gold held, never below zero.
   Task 3.
5. **The counter is upgraded while travelers are queued and one is being served.** Expected: no error; the queue cap
   rises at once; the traveler in service finishes on the new service time. Task 6.

---

## File structure

| File | Responsibility | Task |
|---|---|---|
| `balance/station_balance.gd` (new) | The numbers | 1 |
| `core/station_effects.gd` (new) | Level to value, cost curve, derived sizes | 1 |
| `core/map_layout.gd` | Pad positions, 9 queue slots | 2 |
| `autoload/GameState.gd`, `autoload/EventBus.gd` | Station state, payment, signals, snapshot | 3, 4 |
| `core/save_codec.gd` | Built-in migration 3 to 4, station validation | 4 |
| `world/build_spots/level_pips.gd` (new) | The star pip row shared by spots and pads | 5 |
| `world/stations/upgrade_pad.gd` (new) | The pad: zone, ring, label, pips, payment | 5 |
| `world/stations/counter.gd`, `freezer.gd`, `world/traveler_spawner.gd`, `components/carry_stack.gd` | Read upgraded values | 6 |
| `core/pulse.gd`, `world/stations/closeup_sign.gd`, `world/save/autosave.gd`, `world/audio/audio_director.gd`, `world/fx/reactions.gd`, `ui/guide/guide.gd` | React to stations | 7 |
| `actors/bots/upgrader_bot.gd` (new), `actors/bots/planner_bot.gd` | A bot that buys upgrades | 8 |
| `tests/sim/test_station_sims.gd` (new) | Criteria 6.1 to 6.3 | 8 |
| `tests/sim/sweep_runner.gd`, `tests/sim/make_save.gd`, `export/perf_night3.sh` | Upgrader sweep, level 5 perf fixture | 9 |

---

# Phase 1: `e1/p1-core`

### Task 1: StationBalance and StationEffects

Spec 4, 5.1, 5.2.

**Files:**
- Create: `balance/station_balance.gd` (main purpose)
- Modify: `balance/balance_data.gd` (main purpose)
- Create: `core/station_effects.gd`
- Test: `tests/unit/test_station_effects.gd`

**Interfaces:**
- Consumes: `HeroBalance.carry_capacity`, `CardBalance.carry_step`, `CardBalance.max_level`,
  `EconomyBalance.traveler_speed`, `MapLayout.SERVICE_POINT`, `MapLayout.TRAVELER_EXIT`.
- Produces: `Balance.data.stations: StationBalance` and
  ```gdscript
  StationEffects.IDS: Array[StringName]   # [&"counter", &"freezer"]
  StationEffects.level_cost(id: StringName, level: int, sb: StationBalance) -> int   # -1 at max level
  StationEffects.queue_max(level: int, sb: StationBalance) -> int
  StationEffects.traveler_interval(level: int, sb: StationBalance) -> float
  StationEffects.service_time(level: int, sb: StationBalance) -> float
  StationEffects.counter_capacity(level: int, sb: StationBalance) -> int
  StationEffects.carry_bonus(level: int, sb: StationBalance) -> int
  StationEffects.load_per_tick(level: int, sb: StationBalance) -> int
  StationEffects.max_carry(hb: HeroBalance, cb: CardBalance, sb: StationBalance) -> int
  StationEffects.traveler_pool_size(sb: StationBalance, eb: EconomyBalance) -> int
  ```
  (`traveler_pool_size` takes `eb` as well; the spec's one-argument signature could not read the traveler speed.)

`EconomyBalance` keeps its four fields until Task 6; this task only adds.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_station_effects.gd`:

```gdscript
extends GutTest

var sb: StationBalance

func before_each() -> void:
	Balance.reset()
	sb = Balance.data.stations

func test_every_table_has_max_level_plus_one_entries() -> void:
	for arr in [sb.queue_max, sb.traveler_interval, sb.service_time, sb.counter_capacity, sb.carry_bonus, sb.load_per_tick]:
		assert_eq(arr.size(), sb.max_level + 1)

func test_level_0_is_the_s5_game() -> void:
	assert_eq(StationEffects.queue_max(0, sb), 4)
	assert_eq(StationEffects.traveler_interval(0, sb), 2.5)
	assert_eq(StationEffects.service_time(0, sb), 1.0)
	assert_eq(StationEffects.counter_capacity(0, sb), 12)
	assert_eq(StationEffects.carry_bonus(0, sb), 0)
	assert_eq(StationEffects.load_per_tick(0, sb), 1)

func test_level_0_matches_the_economy_fields_while_they_exist() -> void:
	# Task 6 deletes the EconomyBalance fields and this test with them.
	var e := Balance.data.economy
	assert_eq(StationEffects.queue_max(0, sb), e.queue_max)
	assert_eq(StationEffects.traveler_interval(0, sb), e.traveler_interval)
	assert_eq(StationEffects.service_time(0, sb), e.service_time)
	assert_eq(StationEffects.counter_capacity(0, sb), e.counter_capacity)

func test_level_5_values() -> void:
	assert_eq(StationEffects.queue_max(5, sb), sb.queue_max[5])
	assert_eq(StationEffects.counter_capacity(5, sb), sb.counter_capacity[5])
	assert_eq(StationEffects.carry_bonus(5, sb), sb.carry_bonus[5])
	assert_eq(StationEffects.load_per_tick(5, sb), sb.load_per_tick[5])

func test_tables_never_get_worse_with_level() -> void:
	for l in range(1, sb.max_level + 1):
		assert_gte(sb.queue_max[l], sb.queue_max[l - 1])
		assert_lte(sb.traveler_interval[l], sb.traveler_interval[l - 1])
		assert_lte(sb.service_time[l], sb.service_time[l - 1])
		assert_gt(sb.counter_capacity[l], sb.counter_capacity[l - 1])
		assert_gte(sb.carry_bonus[l], sb.carry_bonus[l - 1])
		assert_gte(sb.load_per_tick[l], sb.load_per_tick[l - 1])
		assert_gt(sb.traveler_interval[l], 0.0)
		assert_gt(sb.service_time[l], 0.0)

func test_levels_out_of_range_clamp() -> void:
	assert_eq(StationEffects.queue_max(-1, sb), sb.queue_max[0])
	assert_eq(StationEffects.queue_max(99, sb), sb.queue_max[sb.max_level])

func test_cost_curve() -> void:
	assert_eq(StationEffects.level_cost(&"counter", 0, sb), 30)
	assert_eq(StationEffects.level_cost(&"counter", 1, sb), 60)
	assert_eq(StationEffects.level_cost(&"counter", 4, sb), 480)
	assert_eq(StationEffects.level_cost(&"freezer", 0, sb), 25)
	assert_eq(StationEffects.level_cost(&"freezer", 4, sb), 400)
	assert_eq(StationEffects.level_cost(&"counter", sb.max_level, sb), -1)
	assert_eq(StationEffects.level_cost(&"freezer", sb.max_level + 3, sb), -1)

func test_max_carry_and_pool_size() -> void:
	var bd := Balance.data
	assert_eq(StationEffects.max_carry(bd.hero, bd.cards, sb),
		bd.hero.carry_capacity + bd.cards.carry_step * bd.cards.max_level + sb.carry_bonus[sb.max_level])
	var walk := MapLayout.SERVICE_POINT.distance_to(MapLayout.TRAVELER_EXIT) / bd.economy.traveler_speed
	assert_eq(StationEffects.traveler_pool_size(sb, bd.economy),
		sb.queue_max[sb.max_level] + int(ceil(walk / sb.service_time[sb.max_level])) + 2)
	assert_gte(StationEffects.traveler_pool_size(sb, bd.economy), bd.economy.queue_max * 2, "never smaller than today's pool")
```

- [ ] **Step 2: Run it and see it fail**

Run: `./run_tests.sh unit 2>&1 | tail -30`
Expected: FAIL, parse error naming `StationBalance`.

- [ ] **Step 3: Write the balance resource**

`balance/station_balance.gd`:

```gdscript
class_name StationBalance
extends Resource
## Station upgrade tuning (E1 spec 4, D-223 to D-225, D-230). Index = level; index 0 is the S5 game (D-228).

@export var max_level := 5
@export var cost_mult := 2.0
@export var counter_cost := 30
@export var freezer_cost := 25
## Sim 6.1: each counter level must serve at least this much more than the level below (D-230).
@export var min_level_gain := 0.08
@export var queue_max: Array[int] = [4, 5, 6, 7, 8, 9]
@export var traveler_interval: Array[float] = [2.5, 2.1, 1.8, 1.5, 1.25, 1.0]
@export var service_time: Array[float] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]
@export var counter_capacity: Array[int] = [12, 18, 24, 30, 36, 42]
@export var carry_bonus: Array[int] = [0, 2, 4, 6, 8, 10]
@export var load_per_tick: Array[int] = [1, 1, 2, 2, 3, 3]
```

In `balance/balance_data.gd`, after the `guards` line add:

```gdscript
@export var stations: StationBalance = StationBalance.new()
```

- [ ] **Step 4: Write the helper**

`core/station_effects.gd`:

```gdscript
class_name StationEffects
extends RefCounted
## Station level -> value (E1 spec 5.2). Pure: no scene access, no GameState.

const IDS: Array[StringName] = [&"counter", &"freezer"]

static func _at(arr: Array, level: int) -> Variant:
	return arr[clampi(level, 0, arr.size() - 1)]

## Gold for the step from `level` to `level + 1`; -1 at max level.
static func level_cost(id: StringName, level: int, sb: StationBalance) -> int:
	assert(id in IDS, "unknown station %s" % id)
	if level >= sb.max_level:
		return -1
	var base := sb.counter_cost if id == &"counter" else sb.freezer_cost
	return int(round(base * pow(sb.cost_mult, level)))

static func queue_max(level: int, sb: StationBalance) -> int:
	return int(_at(sb.queue_max, level))

static func traveler_interval(level: int, sb: StationBalance) -> float:
	return float(_at(sb.traveler_interval, level))

static func service_time(level: int, sb: StationBalance) -> float:
	return float(_at(sb.service_time, level))

static func counter_capacity(level: int, sb: StationBalance) -> int:
	return int(_at(sb.counter_capacity, level))

static func carry_bonus(level: int, sb: StationBalance) -> int:
	return int(_at(sb.carry_bonus, level))

static func load_per_tick(level: int, sb: StationBalance) -> int:
	return int(_at(sb.load_per_tick, level))

## The largest carry the hero can ever have: every carry card plus a max-level freezer.
static func max_carry(hb: HeroBalance, cb: CardBalance, sb: StationBalance) -> int:
	return hb.carry_capacity + cb.carry_step * cb.max_level + carry_bonus(sb.max_level, sb)

## Travelers alive at once at max level: a full queue, plus the ones still walking out, plus a margin.
static func traveler_pool_size(sb: StationBalance, eb: EconomyBalance) -> int:
	var walk_out := MapLayout.SERVICE_POINT.distance_to(MapLayout.TRAVELER_EXIT) / eb.traveler_speed
	return queue_max(sb.max_level, sb) + int(ceil(walk_out / service_time(sb.max_level, sb))) + 2
```

- [ ] **Step 5: Run the tests**

Run: `./run_tests.sh unit 2>&1 | tail -15`
Expected: all pass, 0 errors.

- [ ] **Step 6: Commit**

```bash
git add balance/station_balance.gd balance/balance_data.gd core/station_effects.gd tests/unit/test_station_effects.gd
git commit -m "feat(e1): StationBalance and StationEffects"
```

---

### Task 2: Map layout: pads and queue slots

Spec 5.2.

**Files:**
- Modify: `core/map_layout.gd` (the `QUEUE_SLOTS` line and one new block after `STATION_RADIUS`)
- Test: `tests/unit/test_station_layout.gd` (new), `tests/unit/test_props_layout.gd` (one line)

**Interfaces:**
- Consumes: `Balance.data.stations.queue_max` (Task 1), `CameraMath`, `Geometry`, `PropsLayout.ITEMS`.
- Produces:
  ```gdscript
  MapLayout.STATION_PADS: Dictionary   # {&"counter": Vector2, &"freezer": Vector2}
  MapLayout.STATION_STAND: Dictionary  # {&"counter": COUNTER_DROP, &"freezer": FREEZER_ZONE}
  MapLayout.QUEUE_SLOTS                # 9 slots; the first 4 unchanged
  ```

The coordinates below were checked by hand against every test in this task. If a test still fails, move only the
failing point, by the smallest step that passes, and say so in the report. Never move a prop or one of the first 4
queue slots.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_station_layout.gd`:

```gdscript
extends GutTest
## E1 spec 5.2: the pads and the longer queue are fixed by these tests, not by eye.

func before_each() -> void:
	Balance.reset()

func _on_screen_from(p: Vector2, hero: Vector2) -> bool:
	var xf := CameraMath.camera_transform(CameraMath.focus_for(hero), Balance.ui)
	return CameraMath.on_screen(MapLayout.to3(p), xf, CameraMath.projection(Balance.ui))

func test_first_four_queue_slots_are_unchanged() -> void:
	assert_eq(MapLayout.QUEUE_SLOTS.slice(0, 4), [Vector2(0, 6.0), Vector2(-1.2, 7.0), Vector2(-2.4, 8.0), Vector2(-3.6, 9.0)])

func test_there_is_a_slot_for_every_queued_traveler() -> void:
	var most := 0
	for q in Balance.data.stations.queue_max:
		most = maxi(most, q)
	assert_gte(MapLayout.QUEUE_SLOTS.size(), most)

func test_queue_slots_are_in_bounds_and_north_of_the_road() -> void:
	var play := Rect2(MapLayout.BOUNDS_MIN, MapLayout.BOUNDS_MAX - MapLayout.BOUNDS_MIN)
	for s in MapLayout.QUEUE_SLOTS:
		assert_true(play.has_point(s), "%s in bounds" % s)
		assert_lt(s.y, MapLayout.ROAD_Z, "%s north of the road" % s)

func test_an_arriving_traveler_does_not_walk_through_the_queue() -> void:
	var slots: Array = MapLayout.QUEUE_SLOTS
	for k in range(1, slots.size()):
		for j in k:
			assert_gte(Geometry.dist_point_segment(slots[j], MapLayout.TRAVELER_ENTER, slots[k]), 1.0,
				"walking to slot %d passes slot %d" % [k, j])

func test_the_whole_queue_is_on_screen_from_the_counter() -> void:
	for s in MapLayout.QUEUE_SLOTS:
		assert_true(_on_screen_from(s, MapLayout.COUNTER_DROP), "%s on screen" % s)

func test_each_pad_is_on_screen_from_its_station() -> void:
	for id in StationEffects.IDS:
		assert_true(_on_screen_from(MapLayout.STATION_PADS[id], MapLayout.STATION_STAND[id]), String(id))

func test_pads_overlap_no_zone() -> void:
	var r := MapLayout.BUILD_RADIUS
	var zones := [[MapLayout.SIGN, MapLayout.STATION_RADIUS], [MapLayout.FREEZER_ZONE, MapLayout.STATION_RADIUS],
		[MapLayout.COUNTER_DROP, MapLayout.STATION_RADIUS], [MapLayout.GOLD_PILE, Balance.data.hero.magnet_radius],
		[MapLayout.HOME, 0.0], [MapLayout.NIGHT1_START, 0.0]]
	for id in MapLayout.SPOT_IDS:
		zones.append([MapLayout.spot_position(id), MapLayout.BUILD_RADIUS])
	for s in MapLayout.QUEUE_SLOTS:
		zones.append([s, 0.0])
	for id in StationEffects.IDS:
		var p: Vector2 = MapLayout.STATION_PADS[id]
		for z in zones:
			assert_gt(p.distance_to(z[0]), r + float(z[1]), "%s pad overlaps %s" % [id, z[0]])
		for lane in MapLayout.ZONE_RECTS:
			assert_gt(Geometry.dist_point_rect(p, MapLayout.ZONE_RECTS[lane]), r, "%s pad overlaps the %s lane zone" % [id, lane])

func test_pads_are_clear_of_the_bodies() -> void:
	var bodies := [
		Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2, MapLayout.DINER_HALF * 2),
		Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE),
	]
	for id in StationEffects.IDS:
		for b in bodies:
			assert_gt(Geometry.dist_point_rect(MapLayout.STATION_PADS[id], b), MapLayout.BUILD_RADIUS + MapLayout.HERO_RADIUS,
				"%s pad too close to a body" % id)

func test_pads_are_inside_the_bounds() -> void:
	var play := Rect2(MapLayout.BOUNDS_MIN, MapLayout.BOUNDS_MAX - MapLayout.BOUNDS_MIN).grow(-MapLayout.BUILD_RADIUS)
	for id in StationEffects.IDS:
		assert_true(play.has_point(MapLayout.STATION_PADS[id]), String(id))

func test_the_default_waypoint_graph_is_unchanged() -> void:
	# D-230: a new node would change nearest() and the planner's routes, and so the determinism baseline.
	var g := WaypointGraph.create_default()
	var names: Array = g.nodes.keys()
	names.sort()
	assert_eq(names, ["counter_drop", "e_mid", "fence_e", "fence_n", "fence_w", "freezer", "front_e", "gold_pile",
		"home", "ne", "nw", "se", "sign", "sw", "tower_ne", "tower_nw", "zone_east", "zone_north", "zone_west"])
	var links := 0
	for n in g.edges:
		links += (g.edges[n] as Array).size()
	assert_eq(links, 54, "27 undirected edges")
```

In `tests/unit/test_props_layout.gd`, inside `test_off_stations_roads_and_spots`, after
`points.append_array(MapLayout.QUEUE_SLOTS)` add:

```gdscript
	points.append_array(MapLayout.STATION_PADS.values())
```

- [ ] **Step 2: Run it and see it fail**

Run: `./run_tests.sh unit 2>&1 | grep -E "test_station_layout|Invalid|FAILED" | head`
Expected: FAIL, `STATION_PADS` not found in `MapLayout`.

- [ ] **Step 3: Change the layout**

In `core/map_layout.gd` replace the `QUEUE_SLOTS` line with:

```gdscript
## Slots 0-3: the S1 diagonal. Slots 4-8 (E1, D-230): a second row just north of the road, filling eastward, so an
## arriving traveler never walks through the queue and the whole line is on screen from the counter.
const QUEUE_SLOTS := [Vector2(0, 6.0), Vector2(-1.2, 7.0), Vector2(-2.4, 8.0), Vector2(-3.6, 9.0),
	Vector2(-3.0, 10.3), Vector2(-1.8, 10.3), Vector2(-0.6, 10.3), Vector2(0.6, 10.3), Vector2(1.8, 10.3)]
```

After the `BUILD_RADIUS` line add:

```gdscript
## E1 upgrade pads (radius BUILD_RADIUS) and where the hero stands to use each station (camera test).
const STATION_PADS := {&"counter": Vector2(2.6, 7.2), &"freezer": Vector2(7.9, 7.0)}
const STATION_STAND := {&"counter": COUNTER_DROP, &"freezer": FREEZER_ZONE}
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit 2>&1 | tail -15`
Expected: all pass. `test_travelers.gd` still passes: at level 0 only slots 0 to 3 are used.

- [ ] **Step 5: Commit**

```bash
git add core/map_layout.gd tests/unit/test_station_layout.gd tests/unit/test_props_layout.gd
git commit -m "feat(e1): upgrade pad positions and a 9-slot traveler queue"
```

---

### Task 3: Station state, payment and signals

Spec 5.3. The snapshot (`to_dict`, `from_dict`, schema) is Task 4.

**Files:**
- Modify: `autoload/GameState.gd` (main purpose), `autoload/EventBus.gd` (main purpose)
- Test: `tests/unit/test_game_state_stations.gd` (new)

**Interfaces:**
- Consumes: `StationEffects`, `Balance.data.stations` (Task 1).
- Produces:
  ```gdscript
  # EventBus
  signal station_changed(id: StringName, level: int, paid: int)
  signal station_upgraded(id: StringName, level: int)
  # GameState
  var stations := {}   # {&"counter": {"level": int, "paid": int}, &"freezer": {...}}
  func station_level(id: StringName) -> int             # 0 while stations is empty
  func station_next_cost(id: StringName) -> int         # -1 at max level or while stations is empty
  func station_remaining_cost(id: StringName) -> int    # -1 at max level or while stations is empty
  func pay_into_station(id: StringName, amount: int) -> int
  func debug_set_station_level(id: StringName, level: int) -> void
  func counter_capacity() -> int
  func carry_capacity() -> int                          # now includes the freezer bonus
  ```

- [ ] **Step 1: Write the failing test**

`tests/unit/test_game_state_stations.gd`:

```gdscript
extends GutTest

var sb: StationBalance
var _events: Array = []

func before_each() -> void:
	Balance.reset()
	sb = Balance.data.stations
	GameState.new_game(1234)
	_events = []
	EventBus.gold_changed.connect(_on_gold)
	EventBus.station_changed.connect(_on_changed)
	EventBus.station_upgraded.connect(_on_upgraded)

func after_each() -> void:
	EventBus.gold_changed.disconnect(_on_gold)
	EventBus.station_changed.disconnect(_on_changed)
	EventBus.station_upgraded.disconnect(_on_upgraded)

func _on_gold(_g: int, d: int) -> void:
	_events.append(["gold", d])

func _on_changed(id: StringName, level: int, paid: int) -> void:
	_events.append(["changed", id, level, paid])

func _on_upgraded(id: StringName, level: int) -> void:
	_events.append(["upgraded", id, level])

func test_new_game_has_both_stations_at_level_0() -> void:
	assert_eq(GameState.stations.size(), 2)
	for id in StationEffects.IDS:
		assert_eq(GameState.stations[id], {"level": 0, "paid": 0})
		assert_eq(GameState.station_level(id), 0)

func test_before_the_first_new_game_everything_reads_as_level_0() -> void:
	GameState.stations = {}  # test-only setup: the boot window (Main builds the world before new_game)
	for id in StationEffects.IDS:
		assert_eq(GameState.station_level(id), 0)
		assert_eq(GameState.station_next_cost(id), -1)
		assert_eq(GameState.station_remaining_cost(id), -1)
		assert_eq(GameState.pay_into_station(id, 10), 0)
	assert_eq(GameState.carry_capacity(), Balance.data.hero.carry_capacity)
	assert_eq(GameState.counter_capacity(), sb.counter_capacity[0])

func test_partial_payment() -> void:
	GameState.add_gold(100)
	_events = []
	assert_eq(GameState.pay_into_station(&"counter", 10), 10)
	assert_eq(GameState.gold, 90)
	assert_eq(GameState.stations[&"counter"], {"level": 0, "paid": 10})
	assert_eq(GameState.station_remaining_cost(&"counter"), 20)
	assert_eq(_events, [["gold", -10], ["changed", &"counter", 0, 10]])

func test_completing_a_level_emits_changed_then_upgraded() -> void:
	GameState.add_gold(100)
	GameState.pay_into_station(&"counter", 25)
	_events = []
	assert_eq(GameState.pay_into_station(&"counter", 50), 5, "never more than the level still costs")
	assert_eq(GameState.gold, 70)
	assert_eq(GameState.stations[&"counter"], {"level": 1, "paid": 0})
	assert_eq(_events, [["gold", -5], ["changed", &"counter", 1, 0], ["upgraded", &"counter", 1]])
	assert_eq(GameState.station_next_cost(&"counter"), 60)

func test_payment_is_capped_by_the_gold_held() -> void:
	# Review Focus 4: less gold than one drain tick.
	GameState.add_gold(1)
	assert_eq(GameState.pay_into_station(&"freezer", 2), 1)
	assert_eq(GameState.gold, 0)
	assert_eq(GameState.pay_into_station(&"freezer", 2), 0)
	assert_eq(GameState.stations[&"freezer"].paid, 1)

func test_zero_and_negative_amounts_do_nothing() -> void:
	GameState.add_gold(50)
	_events = []
	assert_eq(GameState.pay_into_station(&"counter", 0), 0)
	assert_eq(GameState.pay_into_station(&"counter", -5), 0)
	assert_eq(GameState.gold, 50)
	assert_eq(_events, [])

func test_max_level_takes_no_gold() -> void:
	GameState.debug_set_station_level(&"counter", sb.max_level)
	GameState.add_gold(999)
	_events = []
	assert_eq(GameState.station_next_cost(&"counter"), -1)
	assert_eq(GameState.station_remaining_cost(&"counter"), -1)
	assert_eq(GameState.pay_into_station(&"counter", 50), 0)
	assert_eq(GameState.gold, 999)
	assert_eq(_events, [])

func test_paying_the_whole_ladder_costs_the_sum_of_the_curve() -> void:
	var total := 0
	for l in sb.max_level:
		total += StationEffects.level_cost(&"freezer", l, sb)
	GameState.add_gold(total)
	var guard := 10000
	while GameState.station_level(&"freezer") < sb.max_level and guard > 0:
		GameState.pay_into_station(&"freezer", 7)
		guard -= 1
	assert_eq(GameState.station_level(&"freezer"), sb.max_level)
	assert_eq(GameState.gold, 0)

func test_freezer_level_adds_to_carry() -> void:
	var base := GameState.carry_capacity()
	GameState.debug_set_station_level(&"freezer", 3)
	assert_eq(GameState.carry_capacity(), base + sb.carry_bonus[3])
	GameState.debug_grant_card(&"carry_capacity")
	assert_eq(GameState.carry_capacity(), base + sb.carry_bonus[3] + Balance.data.cards.carry_step)

func test_counter_level_raises_what_the_counter_takes() -> void:
	GameState.carried_steaks = 40  # test-only setup
	assert_eq(GameState.move_carry_to_counter(40), sb.counter_capacity[0])
	GameState.debug_set_station_level(&"counter", 2)
	assert_eq(GameState.move_carry_to_counter(40), sb.counter_capacity[2] - sb.counter_capacity[0])
	assert_eq(GameState.counter_steaks, sb.counter_capacity[2])

func test_debug_set_clamps_and_emits() -> void:
	_events = []
	GameState.debug_set_station_level(&"counter", 99)
	assert_eq(GameState.stations[&"counter"], {"level": sb.max_level, "paid": 0})
	assert_eq(_events, [["changed", &"counter", sb.max_level, 0]])

func test_new_game_resets_stations() -> void:
	GameState.debug_set_station_level(&"counter", 4)
	GameState.new_game(5)
	assert_eq(GameState.station_level(&"counter"), 0)
```

- [ ] **Step 2: Run it and see it fail**

Run: `./run_tests.sh unit 2>&1 | grep -E "test_game_state_stations|Invalid|SCRIPT ERROR" | head`
Expected: FAIL, `station_changed` not found on EventBus.

- [ ] **Step 3: Add the signals**

In `autoload/EventBus.gd`, after the `build_completed` signal, in the file's own comment style:

```gdscript
## E1: a station's level or paid amount changed.
signal station_changed(id: StringName, level: int, paid: int)
## E1: a station finished a level (emitted after station_changed).
signal station_upgraded(id: StringName, level: int)
```

- [ ] **Step 4: Add the state**

In `autoload/GameState.gd`:

After `var night_fails := 0` add:

```gdscript
## E1: station upgrades (StringName -> {level, paid}). Empty until the first new_game.
var stations := {}
```

In `new_game`, after the `buildings` loop, and in `from_dict`, after the `buildings` loop (Task 4 replaces the
`from_dict` line with the real restore), add:

```gdscript
	stations = _fresh_stations()
```

Replace `carry_capacity()` with:

```gdscript
func carry_capacity() -> int:
	return CardEffects.carry_capacity(Balance.data.hero.carry_capacity, cards, Balance.data.cards) \
		+ StationEffects.carry_bonus(station_level(&"freezer"), Balance.data.stations)
```

In `move_carry_to_counter` replace `Balance.data.economy.counter_capacity` with `counter_capacity()`.

After the buildings section (before `damage_fence`'s section or at the end of the buildings block) add:

```gdscript
# --- stations (E1) ---------------------------------------------------------

static func _fresh_stations() -> Dictionary:
	var out := {}
	for id in StationEffects.IDS:
		out[id] = {"level": 0, "paid": 0}
	return out

## 0 before the first new_game (the world is built and ticks while `stations` is still empty).
func station_level(id: StringName) -> int:
	assert(id in StationEffects.IDS, "unknown station %s" % id)
	return int(stations[id].level) if stations.has(id) else 0

func station_next_cost(id: StringName) -> int:
	assert(id in StationEffects.IDS, "unknown station %s" % id)
	if not stations.has(id):
		return -1
	return StationEffects.level_cost(id, int(stations[id].level), Balance.data.stations)

func station_remaining_cost(id: StringName) -> int:
	var cost := station_next_cost(id)
	return -1 if cost < 0 else cost - int(stations[id].paid)

func counter_capacity() -> int:
	return StationEffects.counter_capacity(station_level(&"counter"), Balance.data.stations)

func pay_into_station(id: StringName, amount: int) -> int:
	var cost := station_next_cost(id)
	if cost < 0:
		return 0
	var s: Dictionary = stations[id]
	var pay := mini(amount, mini(gold, cost - int(s.paid)))
	if pay <= 0:
		return 0
	gold -= pay
	s.paid = int(s.paid) + pay
	EventBus.gold_changed.emit(gold, -pay)
	if int(s.paid) >= cost:
		s.level = int(s.level) + 1
		s.paid = 0
		EventBus.station_changed.emit(id, s.level, s.paid)
		EventBus.station_upgraded.emit(id, s.level)
	else:
		EventBus.station_changed.emit(id, s.level, s.paid)
	return pay

## Tests, sims and fixtures only.
func debug_set_station_level(id: StringName, level: int) -> void:
	assert(id in StationEffects.IDS, "unknown station %s" % id)
	stations[id] = {"level": clampi(level, 0, Balance.data.stations.max_level), "paid": 0}
	EventBus.station_changed.emit(id, int(stations[id].level), 0)
```

- [ ] **Step 5: Run the tests**

Run: `./run_tests.sh unit 2>&1 | tail -15`
Expected: all pass. `test_game_state.gd` still passes (level 0 everywhere).

- [ ] **Step 6: Prove level 0 is unchanged**

Run: `./run_tests.sh sim 2>&1 | tail -5 && tools/baseline_diff.sh`
Expected: sims pass; `baseline identical`.

- [ ] **Step 7: Commit**

```bash
git add autoload/GameState.gd autoload/EventBus.gd tests/unit/test_game_state_stations.gd
git commit -m "feat(e1): station state, payment and signals in GameState"
```

---

### Task 4: Save schema 4

Spec 5.5, Review Focus 1.

**Files:**
- Modify: `autoload/GameState.gd` (main purpose: `SCHEMA_VERSION`, `to_dict`, `from_dict`)
- Modify: `core/save_codec.gd`
- Modify: `tests/unit/test_save_codec.gd` (the test `test_older_version_migrates_through_the_hook` only)
- Modify: `docs/superpowers/specs/2026-10-05-e1-station-upgrades-design.md` (one bullet in 5.5)
- Test: `tests/unit/test_save_stations.gd` (new)

**Interfaces:**
- Consumes: Task 3's `stations`, `_fresh_stations()`.
- Produces: `GameState.SCHEMA_VERSION == 4`; `to_dict().stations` with `String` keys;
  `SaveCodec.fresh_stations() -> Dictionary` (String keys, level 0); `SaveCodec.decode` migrates 3 to 4 by itself.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_save_stations.gd`:

```gdscript
extends GutTest

var bd: BalanceData

func before_each() -> void:
	Balance.reset()
	bd = Balance.data
	GameState.new_game(20260930)

func after_each() -> void:
	SaveCodec.MIGRATIONS.clear()

func _decode(state: Dictionary) -> Dictionary:
	return SaveCodec.decode(SaveCodec.encode(state, "t", 1), GameState.SCHEMA_VERSION, bd)

func _v3() -> Dictionary:
	var s := GameState.to_dict()
	s.v = 3
	s.erase("stations")
	return s

func test_schema_is_4_and_the_snapshot_carries_stations_with_string_keys() -> void:
	assert_eq(GameState.SCHEMA_VERSION, 4)
	var d := GameState.to_dict()
	assert_eq(d.stations, {"counter": {"level": 0, "paid": 0}, "freezer": {"level": 0, "paid": 0}})
	for k in d.stations:
		assert_eq(typeof(k), TYPE_STRING)

func test_round_trip_with_upgraded_stations() -> void:
	GameState.add_gold(500)
	GameState.debug_set_station_level(&"counter", 3)
	GameState.pay_into_station(&"freezer", 10)
	var d := GameState.to_dict()
	var r := _decode(d)
	assert_true(r.ok, r.reason)
	GameState.new_game(1)
	GameState.from_dict(r.state)
	assert_eq(GameState.station_level(&"counter"), 3)
	assert_eq(GameState.stations[&"freezer"], {"level": 0, "paid": 10})
	assert_eq(typeof(GameState.stations[&"freezer"].paid), TYPE_INT, "JSON floats become ints again")
	assert_eq(GameState.to_dict(), d)

func test_a_v3_save_loads_with_both_stations_at_level_0() -> void:
	var r := _decode(_v3())
	assert_true(r.ok, r.reason)
	assert_eq(int(r.state.v), 4)
	assert_eq(r.state.stations, SaveCodec.fresh_stations())
	GameState.from_dict(r.state)
	assert_eq(GameState.station_level(&"counter"), 0)

func test_the_built_in_step_survives_clearing_the_test_hook() -> void:
	SaveCodec.MIGRATIONS.clear()
	assert_true(_decode(_v3()).ok)

func test_a_registered_step_overrides_the_built_in_one() -> void:
	SaveCodec.MIGRATIONS[3] = func(st: Dictionary) -> Dictionary:
		st.v = 4
		st.stations = {"counter": {"level": 2, "paid": 0}, "freezer": {"level": 0, "paid": 0}}
		return st
	var r := _decode(_v3())
	assert_true(r.ok, r.reason)
	assert_eq(int(r.state.stations.counter.level), 2)

func test_a_v2_save_has_no_step() -> void:
	var s := _v3()
	s.v = 2
	var r := _decode(s)
	assert_eq([r.ok, r.reason], [false, "version"])

func _bad(mutate: Callable) -> String:
	var s := GameState.to_dict()
	mutate.call(s)
	return _decode(s).reason

func test_validation() -> void:
	assert_eq(_bad(func(s): s.erase("stations")), "content")
	assert_eq(_bad(func(s): s.stations = []), "content")
	assert_eq(_bad(func(s): s.stations.erase("freezer")), "content")
	assert_eq(_bad(func(s): s.stations["oven"] = {"level": 0, "paid": 0}), "content")
	assert_eq(_bad(func(s): s.stations.counter = {"level": 0}), "content")
	assert_eq(_bad(func(s): s.stations.counter.level = "1"), "content")
	assert_eq(_bad(func(s): s.stations.counter.level = -1), "content")
	assert_eq(_bad(func(s): s.stations.counter.level = bd.stations.max_level + 1), "content")
	assert_eq(_bad(func(s): s.stations.counter.paid = -1), "content")
	assert_eq(_bad(func(s): s.stations.counter.level = bd.stations.max_level), "")

func test_a_paid_amount_above_the_cost_loads_and_the_pad_still_works() -> void:
	# Review Focus 1: costs were lowered after the save was written.
	var s := GameState.to_dict()
	s.stations.counter.paid = 9999
	s.gold = 5
	var r := _decode(s)
	assert_true(r.ok, r.reason)
	GameState.from_dict(r.state)
	var cost := GameState.station_next_cost(&"counter")
	assert_eq(int(GameState.stations[&"counter"].paid), cost - 1)
	assert_eq(GameState.pay_into_station(&"counter", 5), 1)
	assert_eq(GameState.station_level(&"counter"), 1)

func test_paid_at_max_level_is_dropped_on_load() -> void:
	var s := GameState.to_dict()
	s.stations.freezer = {"level": bd.stations.max_level, "paid": 7}
	var r := _decode(s)
	assert_true(r.ok, r.reason)
	GameState.from_dict(r.state)
	assert_eq(GameState.stations[&"freezer"], {"level": bd.stations.max_level, "paid": 0})

func test_the_v3_fixtures_still_load() -> void:
	for name in ["night3_start", "night3_closeup"]:
		var text := FileAccess.get_file_as_string("res://export/fixtures/%s.save.json" % name)
		var r := SaveCodec.decode(text, GameState.SCHEMA_VERSION, bd)
		assert_true(r.ok, "%s: %s" % [name, r.reason])
		assert_eq(r.state.stations, SaveCodec.fresh_stations())
```

- [ ] **Step 2: Run it and see it fail**

Run: `./run_tests.sh unit 2>&1 | grep -E "test_save_stations" | head`
Expected: FAIL (`SCHEMA_VERSION` is 3, `fresh_stations` missing).

- [ ] **Step 3: Snapshot in GameState**

In `autoload/GameState.gd`:

- `const SCHEMA_VERSION := 4`
- In `to_dict`, add to the returned dictionary: `"stations": _stations_out(),`
- In `from_dict`, replace the `stations = _fresh_stations()` line from Task 3 with:

```gdscript
	stations = _fresh_stations()
	for id in StationEffects.IDS:
		var st: Dictionary = d.stations[String(id)]
		var level := clampi(int(st.level), 0, Balance.data.stations.max_level)
		var cost := StationEffects.level_cost(id, level, Balance.data.stations)
		# A paid amount at or above the cost would never complete (pay_into_station pays cost - paid): clamp it.
		stations[id] = {"level": level, "paid": 0 if cost < 0 else clampi(int(st.paid), 0, cost - 1)}
```

- Next to `_guards_out` add:

```gdscript
func _stations_out() -> Dictionary:
	var out := {}
	for id in stations:
		out[String(id)] = {"level": int(stations[id].level), "paid": int(stations[id].paid)}
	return out
```

- [ ] **Step 4: Migration and validation in SaveCodec**

In `core/save_codec.gd`:

- Add `"stations"` to `STATE_KEYS`.
- Replace the comment above `MIGRATIONS` with:

```gdscript
## from_version (int) -> Callable(state: Dictionary) -> Dictionary. A test hook: an entry here overrides the
## built-in step of the same version (_built_in). Tests may clear it freely.
```

- Add:

```gdscript
static func fresh_stations() -> Dictionary:
	var out := {}
	for id in StationEffects.IDS:
		out[String(id)] = {"level": 0, "paid": 0}
	return out

## The shipped migrations. Returns null when `from_v` has no step.
static func _built_in(from_v: int, state: Dictionary) -> Variant:
	match from_v:
		3:  # E1: station upgrades
			state.stations = fresh_stations()
			state.v = 4
			return state
	return null
```

- In `decode`, replace the first four lines of the `while v < current_v:` body
  (`if not MIGRATIONS.has(v): … state = MIGRATIONS[v].call(state)`) with:

```gdscript
		state = MIGRATIONS[v].call(state) if MIGRATIONS.has(v) else _built_in(v, state)
```

  The existing check right after it (`typeof(state) != TYPE_DICTIONARY …`) already turns a `null` into
  `reason = "version"`.

- In `validate`, add `"stations"` to the `for k in ["buildings", "cards", "guards"]` type list, and before the
  `lane_plan` size check add:

```gdscript
	for id in s.stations:
		if typeof(id) != TYPE_STRING or not StringName(id) in StationEffects.IDS:
			return "station " + str(id)
	for id in StationEffects.IDS:
		if not s.stations.has(String(id)):
			return "missing station " + str(id)
		var st = s.stations[String(id)]
		if typeof(st) != TYPE_DICTIONARY or not st.has_all(["level", "paid"]):
			return "station fields " + str(id)
		for f in ["level", "paid"]:
			if not typeof(st[f]) in [TYPE_INT, TYPE_FLOAT]:
				return "station field type " + str(id)
		if int(st.level) < 0 or int(st.level) > bd.stations.max_level or float(st.paid) < 0.0:
			return "range station " + str(id)
```

- [ ] **Step 5: Fix the one existing test that assumed "no step for the previous version"**

In `tests/unit/test_save_codec.gd`, test `test_older_version_migrates_through_the_hook`: version 3 now has a built-in
step, so the test uses version 2, which has none. Replace every `GameState.SCHEMA_VERSION - 1` **inside this test
only** with `2`, and inside its lambda, next to `st.night_fails = 0`, add:

```gdscript
		st.stations = SaveCodec.fresh_stations()
```

Keep every assertion. The two other tests that register `MIGRATIONS[GameState.SCHEMA_VERSION - 1]` stay as they are:
a registered step overrides the built-in one.

- [ ] **Step 6: Amend the spec line**

In the spec, section 5.5, replace the bullet that starts "Validation: both ids present" with:

```markdown
- Validation: both ids present and no unknown id, `0 <= level <= max_level`, `paid >= 0`. On load, `paid` is clamped
  to `cost - 1` (0 at max level): a save written before a cost was lowered still loads and its pad still completes.
```

- [ ] **Step 7: Run everything**

Run: `./run_tests.sh all 2>&1 | tail -8 && tools/baseline_diff.sh`
Expected: unit and sim pass; `baseline identical`. If a unit test outside this task fails on `"stations"` (a test that
builds a state dictionary by hand), add `"stations": SaveCodec.fresh_stations()` to its fixture and list the file in
the report.

- [ ] **Step 8: Commit**

```bash
git add autoload/GameState.gd core/save_codec.gd tests/unit/test_save_stations.gd tests/unit/test_save_codec.gd docs/superpowers/specs/2026-10-05-e1-station-upgrades-design.md
git commit -m "feat(e1): save schema 4 with a built-in 3-to-4 migration"
```

**Phase 1 PR:** `e1/p1-core` into `main`. Body: the `./run_tests.sh all` tail and the `baseline identical` line.

---

# Phase 2: `e1/p2-world`

### Task 5: LevelPips and UpgradePad

Spec 3, 5.4, Review Focus 3.

**Files:**
- Create: `world/build_spots/level_pips.gd`, `world/stations/upgrade_pad.gd`
- Modify: `world/build_spots/build_spot.gd` (the pip loop in `setup`, lines 37-47)
- Wiring note: `world/world.gd` (hot)
- Test: `tests/unit/test_upgrade_pad.gd` (new)

**Interfaces:**
- Consumes: `GameState.pay_into_station`, `station_next_cost`, `station_remaining_cost`, `station_level`;
  `EventBus.station_changed`, `station_upgraded`; `MapLayout.STATION_PADS`; `Economy.drain_per_tick`.
- Produces:
  ```gdscript
  LevelPips.make(parent: Node3D, count: int, y: float) -> Array   # of MeshInstance3D named "Pip%d", added to parent
  LevelPips.show_level(pips: Array, level: int, y: float) -> void
  class_name UpgradePad   # setup(id: StringName, world: World), refresh(); fields station_id, zone, label, marker, _pips
  World.upgrade_pads: Dictionary   # {&"counter": UpgradePad, &"freezer": UpgradePad}  (wiring note)
  ```

- [ ] **Step 1: Write the failing test**

`tests/unit/test_upgrade_pad.gd`:

```gdscript
extends GutTest

var main: Main
var pad: UpgradePad

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(8)
	pad = main.world.upgrade_pads[&"counter"]

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _pay_ticks(n: int) -> int:
	var eco := Balance.data.economy
	return ceili((eco.stand_still_time + n * eco.transfer_tick) * Engine.physics_ticks_per_second) + 2

func test_both_pads_exist_at_their_layout_positions() -> void:
	for id in StationEffects.IDS:
		var p: UpgradePad = main.world.upgrade_pads[id]
		assert_eq(p.station_id, id)
		assert_eq(Vector2(p.global_position.x, p.global_position.z), MapLayout.STATION_PADS[id])
		assert_eq(p.zone.radius, MapLayout.BUILD_RADIUS)
		assert_eq(p._pips.size(), Balance.data.stations.max_level)

func test_hidden_at_night_shown_by_day() -> void:
	assert_false(pad.label.visible, "night 1")
	assert_false(pad.marker.visible)
	main.phase_controller.debug_skip_to_day()
	await _ticks(1)
	assert_true(pad.label.visible)
	assert_true(pad.marker.visible)
	assert_eq(pad.label.text, str(GameState.station_next_cost(&"counter")))

func test_standing_on_the_pad_buys_a_level() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.add_gold(30)
	await TestHelpers.walk_in(main.hero, MapLayout.STATION_PADS[&"counter"])
	await _ticks(_pay_ticks(30))
	assert_eq(GameState.station_level(&"counter"), 1)
	assert_eq(GameState.gold, 0)
	assert_true(pad._pips[0].visible)
	assert_false(pad._pips[1].visible)
	assert_eq(pad.label.text, str(GameState.station_remaining_cost(&"counter")))

func test_the_ring_shows_paid_over_cost() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.add_gold(15)
	await TestHelpers.walk_in(main.hero, MapLayout.STATION_PADS[&"counter"])
	await _ticks(_pay_ticks(30))
	assert_eq(int(GameState.stations[&"counter"].paid), 15, "all the gold held, level not complete")
	assert_true(pad.zone.ring.visible)
	assert_eq(pad.label.text, "15")

func test_max_level_reads_max_and_takes_nothing() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_station_level(&"counter", Balance.data.stations.max_level)
	GameState.add_gold(100)
	await TestHelpers.walk_in(main.hero, MapLayout.STATION_PADS[&"counter"])
	await _ticks(_pay_ticks(10))
	assert_eq(pad.label.text, tr("MAX"))
	assert_false(pad.marker.visible)
	assert_eq(GameState.gold, 100)

func test_night_stops_a_payment_and_keeps_the_partial() -> void:
	# Review Focus 3
	main.phase_controller.debug_skip_to_day()
	GameState.add_gold(30)
	await TestHelpers.walk_in(main.hero, MapLayout.STATION_PADS[&"counter"])
	await _ticks(_pay_ticks(3))
	var paid := int(GameState.stations[&"counter"].paid)
	assert_between(paid, 1, 29)
	EventBus.closeup_requested.emit()
	await _ticks(_pay_ticks(20))
	assert_eq(main.phase_controller.phase, Phase.NIGHT)
	assert_eq(int(GameState.stations[&"counter"].paid), paid, "nothing is paid at night")
	assert_false(pad.label.visible)
	assert_false(pad.zone.ring.visible)

func test_refresh_is_safe_before_the_first_new_game() -> void:
	GameState.stations = {}  # test-only setup: the boot window
	pad.refresh()
	assert_eq(pad.label.text, "")
	GameState.new_game(8)

func test_build_spots_keep_their_pips() -> void:
	var spot: BuildSpot = main.world.build_spots["tower_nw"]
	assert_eq(spot._pips.size(), Balance.data.build.max_level)
	assert_eq(spot._pips[0].name, "Pip0")
```

If `EventBus.closeup_requested` does not start the night from a unit test in this harness, use the way
`tests/unit/test_stations.gd` or `test_restore_world.gd` enters NIGHT from DAY and say which in the report.

- [ ] **Step 2: Run it and see it fail**

Run: `./run_tests.sh unit 2>&1 | grep -E "test_upgrade_pad|SCRIPT ERROR" | head`
Expected: FAIL, `UpgradePad` unknown.

- [ ] **Step 3: Extract the pip row**

`world/build_spots/level_pips.gd`:

```gdscript
class_name LevelPips
extends RefCounted
## The row of level stars above a build spot or an upgrade pad (Pillar 1: growth reads).

const SPACING := 0.3

static func make(parent: Node3D, count: int, y: float) -> Array:
	var pips: Array = []
	for i in count:
		var pip := MeshInstance3D.new()
		pip.name = "Pip%d" % i
		pip.mesh = LevelStar.mesh()
		pip.material_override = LevelStar.material()
		pip.rotation.x = deg_to_rad(Balance.ui.camera_pitch)  # the star faces the camera
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pip.position = Vector3((i - (count - 1) * 0.5) * SPACING, y, 0)
		parent.add_child(pip)
		pips.append(pip)
	return pips

static func show_level(pips: Array, level: int, y: float) -> void:
	for i in pips.size():
		pips[i].visible = i < level
		pips[i].position.y = y
```

In `world/build_spots/build_spot.gd` `setup`, replace the block from `var max_level: int = Balance.data.build.max_level`
through `_pips.append(pip)` with:

```gdscript
	_pips = LevelPips.make(self, Balance.data.build.max_level, _pip_y(1))
```

In `refresh`, replace the `for i in _pips.size():` loop (3 lines) with:

```gdscript
	LevelPips.show_level(_pips, level, _pip_y(level))
```

- [ ] **Step 4: Write the pad**

`world/stations/upgrade_pad.gd`:

```gdscript
class_name UpgradePad
extends Node3D
## Stand-still payment for one station's next level (E1 spec 3). All state comes from GameState.stations.

const MARKER_SCENE := preload("res://art/env/spot_marker.tscn")
const PIP_Y := 1.1
const LABEL_Y := 1.6

var station_id: StringName
var label: WorldLabel
var zone: StationZone
var marker: Node3D
var _pips: Array = []
var _fx: FlyFx
## Paid ticks since the level started; drives the dust only (visual).
var _paid_ticks := 0

func setup(id: StringName, world: World) -> void:
	station_id = id
	_fx = world.fly_fx
	name = "Pad_%s" % id
	position = MapLayout.to3(MapLayout.STATION_PADS[id])
	label = WorldLabel.make("", 40)
	label.position = Vector3(0, LABEL_Y, 0)
	add_child(label)
	marker = MARKER_SCENE.instantiate()
	add_child(marker)
	_pips = LevelPips.make(self, Balance.data.stations.max_level, PIP_Y)
	zone = StationZone.new()
	zone.radius = MapLayout.BUILD_RADIUS
	zone.drive_ring = false  # the ring shows paid / cost
	add_child(zone)
	zone.ticked.connect(_on_tick)
	EventBus.station_changed.connect(_on_station_changed)
	EventBus.phase_changed.connect(_on_phase_changed)  # after the zone's own connection (it syncs its phase first)
	EventBus.state_restored.connect(refresh)
	refresh()

func _on_tick() -> void:
	var cost := GameState.station_next_cost(station_id)
	if cost < 0:
		return
	var paid := GameState.pay_into_station(station_id, Economy.drain_per_tick(cost, Balance.data.build))
	if paid <= 0:
		return
	if GameState.station_remaining_cost(station_id) == GameState.station_next_cost(station_id):
		_paid_ticks = 0  # this tick completed a level
	else:
		_paid_ticks += 1
	if _paid_ticks > 0 and _paid_ticks % maxi(Balance.ui.build_dust_every, 1) == 0:
		EventBus.fx_requested.emit(&"dust", global_position)
	var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
	if _fx != null and hero != null:
		_fx.fly("coin", hero.global_position + Vector3(0, 1.2, 0), global_position + Vector3(0, 0.3, 0))

func _on_station_changed(id: StringName, _level: int, _paid: int) -> void:
	if id == station_id:
		refresh()

func _on_phase_changed(_phase: int, _day: int) -> void:
	refresh()

## Rebuilds everything from GameState. Safe before the first new_game (stations is empty then).
func refresh() -> void:
	var known := GameState.stations.has(station_id)
	var level := GameState.station_level(station_id)
	var cost := GameState.station_next_cost(station_id)
	var paid := int(GameState.stations[station_id].paid) if known else 0
	if paid == 0:
		_paid_ticks = 0
	var day := zone != null and zone.is_active()
	LevelPips.show_level(_pips, level, PIP_Y)
	if not known:
		label.text = ""
	elif cost < 0:
		label.text = tr("MAX")
	else:
		label.text = str(cost - paid)
	label.visible = day
	marker.visible = day and known and cost >= 0
	if zone != null:
		var progress := 0.0 if cost <= 0 else float(paid) / float(cost)
		zone.ring.visible = progress > 0.0 and day
		zone.ring.set_progress(progress)
```

- [ ] **Step 5: Wiring note for `world/world.gd`**

Apply locally, save as `/tmp/wiring_e1_t05.patch`, do not commit:

- Next to the `build_spots` member: `var upgrade_pads := {}`
- In `_build_stations()`, right after `counter.setup(self)`:

```gdscript
	for id in StationEffects.IDS:
		var pad := UpgradePad.new()
		add_child(pad)
		pad.setup(id, self)
		upgrade_pads[id] = pad
```

- [ ] **Step 6: Run everything**

Run: `./run_tests.sh all 2>&1 | tail -8 && tools/baseline_diff.sh`
Expected: pass; `baseline identical` (bots route around nothing new: pads have no collider, and no baseline bot stops
on one).

- [ ] **Step 7: Shots**

Run: `tools/shots.sh docs/review/media/e1/task05`
The main session checks the day shots at 100% and 40%: both pads readable, cost labels not overlapping the counter
label, the sign or the freezer stack.

- [ ] **Step 8: Commit**

```bash
git add world/build_spots/level_pips.gd world/build_spots/build_spot.gd world/stations/upgrade_pad.gd tests/unit/test_upgrade_pad.gd docs/review/media/e1/task05
git commit -m "feat(e1): upgrade pads for the counter and the freezer"
```

---

### Task 6: Stations use the upgraded values; remove the old economy fields

Spec 5.1, 5.4, Review Focus 2 and 5.

**Files:**
- Modify: `world/stations/counter.gd`, `world/stations/freezer.gd`, `world/traveler_spawner.gd`,
  `components/carry_stack.gd`, `actors/bots/planner_bot.gd` (line 18 only), `ui/guide/guide.gd` (line 120 only)
- Modify: `balance/economy_balance.gd` (main purpose: remove 4 fields)
- Wiring note: `world/world.gd:188` (hot)
- Modify tests that read the removed fields: `tests/unit/test_travelers.gd`, `test_reactions.gd`, `test_piles.gd`,
  `test_stations.gd`, `test_game_state.gd`, `test_guide.gd`, `test_restore_world.gd`, `test_station_effects.gd`
- Test: `tests/unit/test_station_world.gd` (new)

**Interfaces:**
- Consumes: `StationEffects.*`, `GameState.station_level`, `GameState.counter_capacity()`,
  `EventBus.station_upgraded`.
- Produces: nothing new for later tasks; `EconomyBalance` no longer has `queue_max`, `traveler_interval`,
  `service_time`, `counter_capacity`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_station_world.gd`:

```gdscript
extends GutTest

var main: Main
var sb: StationBalance
var _grew := 0

func before_each() -> void:
	Balance.reset()
	sb = Balance.data.stations
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(21)
	main.hero.teleport(Vector2(15, 8))  # away from every zone
	_grew = 0

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _secs(seconds: float) -> int:
	return int(ceil(seconds * Engine.physics_ticks_per_second * 1.1))

func test_the_counter_pile_has_a_slot_for_every_steak_at_max_level() -> void:
	var top := sb.counter_capacity[sb.max_level]
	GameState.debug_set_station_level(&"counter", sb.max_level)
	GameState.counter_steaks = top  # test-only setup
	EventBus.stocks_changed.emit()
	assert_eq(main.world.counter.stack_count(), top)

func test_counter_steaks_above_the_capacity_do_not_break_anything() -> void:
	# Review Focus 2: a save from a build with bigger tables.
	main.phase_controller.debug_skip_to_day()
	GameState.counter_steaks = 500  # test-only setup
	GameState.carried_steaks = 3  # test-only setup
	EventBus.stocks_changed.emit()
	assert_eq(main.world.counter.stack_count(), sb.counter_capacity[sb.max_level], "the pile shows what it has slots for")
	assert_eq(GameState.move_carry_to_counter(3), 0)
	await _ticks(_secs(20.0))
	assert_lt(GameState.counter_steaks, 500, "travelers still buy")

func test_the_freezer_loads_more_per_tick_at_level_2() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_station_level(&"freezer", 2)
	GameState.add_freezer(50)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	var eco := Balance.data.economy
	await _ticks(ceili((eco.stand_still_time + 2 * eco.transfer_tick) * Engine.physics_ticks_per_second) + 2)
	assert_gte(GameState.carried_steaks, 2 * sb.load_per_tick[2])
	await _ticks(_secs(3.0))
	assert_eq(GameState.carried_steaks, GameState.carry_capacity(), "fills to the upgraded capacity, never past it")
	assert_eq(GameState.carry_capacity(), Balance.data.hero.carry_capacity + sb.carry_bonus[2])

func test_the_queue_grows_with_the_counter_level() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_station_level(&"counter", 3)
	await _ticks(_secs((sb.queue_max[3] + 2) * (sb.traveler_interval[3] + Balance.data.economy.traveler_jitter)))
	assert_eq(main.world.traveler_spawner.queue.size(), sb.queue_max[3])

func test_upgrading_while_a_traveler_is_served() -> void:
	# Review Focus 5
	main.phase_controller.debug_skip_to_day()
	GameState.counter_steaks = 12  # test-only setup
	var sp := main.world.traveler_spawner
	await _ticks(_secs(sb.queue_max[0] * 3.0))
	assert_eq(sp.queue.size(), sb.queue_max[0], "full at level 0")
	GameState.debug_set_station_level(&"counter", 4)
	await _ticks(_secs(20.0))
	assert_gt(sp.queue.size(), sb.queue_max[0], "the cap rose at once")
	assert_lte(sp.queue.size(), sb.queue_max[4])
	assert_lt(GameState.counter_steaks, 12, "service went on")

func test_the_traveler_pool_never_grows_on_a_level_5_day() -> void:
	assert_eq(main.world.traveler_pool.size, StationEffects.traveler_pool_size(sb, Balance.data.economy))
	main.world.traveler_pool.grew.connect(func(_n): _grew += 1)
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_station_level(&"counter", sb.max_level)
	for i in _secs(60.0):
		GameState.counter_steaks = sb.counter_capacity[sb.max_level]  # test-only setup: always stocked
		await get_tree().physics_frame
	assert_eq(_grew, 0)

func test_the_carry_stack_has_a_slot_for_the_largest_carry() -> void:
	var bd := Balance.data
	var cap := StationEffects.max_carry(bd.hero, bd.cards, sb)
	assert_eq(main.hero.carry_stack._pile.multimesh.instance_count, cap)
	GameState.carried_steaks = cap  # test-only setup
	EventBus.stocks_changed.emit()
	assert_eq(main.hero.carry_stack.visible_count(), cap)

func test_an_upgrade_pops_the_visual_not_the_body() -> void:
	var body := main.world.get_node("CounterBody") as StaticBody3D
	GameState.debug_set_station_level(&"counter", 1)
	EventBus.station_upgraded.emit(&"counter", 1)
	assert_eq(body.scale, Vector3.ONE)
	assert_gt(main.world.counter.body_visual.scale.x, 1.0)
	await _ticks(_secs(Balance.ui.build_pop_time))
	assert_almost_eq(main.world.counter.body_visual.scale.x, 1.0, 0.001)
```

If `World` holds the counter body under another path than `get_node("CounterBody")`, use the path
`add_static_box` gives it (`world/world.gd:152-170`) and say so in the report.

- [ ] **Step 2: Run it and see it fail**

Run: `./run_tests.sh unit 2>&1 | grep -E "test_station_world" | head`
Expected: FAIL (pool size, pile slots, `body_visual`).

- [ ] **Step 3: Counter**

In `world/stations/counter.gd`:

- Add members: `var body_visual: Node3D` and `var _pop: Tween`.
- Replace the `world.add_static_box("CounterBody", …)` line with:

```gdscript
	var body := world.add_static_box("CounterBody", Vector3(MapLayout.COUNTER_SIZE.x, 1.0, MapLayout.COUNTER_SIZE.y), MapLayout.COUNTER, COUNTER_ART)
	body_visual = body.get_child(1) as Node3D  # add_static_box: child 0 is the shape, child 1 the visual root
```

- Replace the slot loop with (the first 12 slots are exactly today's):

```gdscript
	var sb := Balance.data.stations
	var slots := PackedVector3Array()
	for i in StationEffects.counter_capacity(sb.max_level, sb):
		var layer := floori(i / 12.0)  # 2 rows of 6 per layer; the pile grows upward
		var j := i % 12
		var col := j % 6
		var row := floori(j / 6.0)
		slots.append(MapLayout.to3(MapLayout.COUNTER - MapLayout.COUNTER_DROP + Vector2(-1.1 + col * 0.44, -0.2 + row * 0.4), 1.1 + layer * 0.18))
```

- At the end of `setup`, before `refresh()`: `EventBus.station_upgraded.connect(_on_station_upgraded)`
- Add:

```gdscript
## Visual only: the model pops; the StaticBody3D and its shape are never scaled.
func _on_station_upgraded(id: StringName, _level: int) -> void:
	if id != &"counter" or body_visual == null:
		return
	if _pop != null and _pop.is_valid():
		_pop.kill()
	body_visual.scale = Vector3.ONE * Balance.ui.build_pop_scale
	_pop = create_tween()
	_pop.tween_property(body_visual, "scale", Vector3.ONE, Balance.ui.build_pop_time)
```

- [ ] **Step 4: Freezer**

In `world/stations/freezer.gd`: the same `body_visual` capture on the `FreezerBody` line, the same `_pop` member, the
same handler with `id != &"freezer"`, and the same `connect`. In `_on_tick` replace
`GameState.move_freezer_to_carry(1)` with:

```gdscript
	GameState.move_freezer_to_carry(StationEffects.load_per_tick(GameState.station_level(&"freezer"), Balance.data.stations))
```

- [ ] **Step 5: Traveler spawner**

In `world/traveler_spawner.gd` (no change to the order of `_rng` calls):

```gdscript
func _next_interval() -> float:
	var e := Balance.data.economy
	var base := StationEffects.traveler_interval(GameState.station_level(&"counter"), Balance.data.stations)
	return base + _rng.randf_range(-e.traveler_jitter, e.traveler_jitter)
```

In `_physics_process`, after `var e := Balance.data.economy` add:

```gdscript
	var sb := Balance.data.stations
	var counter_level := GameState.station_level(&"counter")
```

and replace `e.queue_max` with `StationEffects.queue_max(counter_level, sb)` and `e.service_time` with
`StationEffects.service_time(counter_level, sb)`.

- [ ] **Step 6: Carry stack, planner bot, guide**

- `components/carry_stack.gd` `_ready`: replace the two lines that compute `cb` and `cap` with:

```gdscript
	var bd := Balance.data
	var cap := StationEffects.max_carry(bd.hero, bd.cards, bd.stations)
```

  and update the class comment's last line to "a slot per steak the hero can ever carry (cards and freezer, D-201)".
- `actors/bots/planner_bot.gd:18`: `var counter_cap := GameState.counter_capacity()`
- `ui/guide/guide.gd:120`: `"counter_capacity": gs.counter_capacity(),`

- [ ] **Step 7: Wiring note for `world/world.gd:188`**

Apply locally, save as `/tmp/wiring_e1_t06.patch`, do not commit:

```gdscript
	traveler_pool.setup(_make_traveler, StationEffects.traveler_pool_size(Balance.data.stations, Balance.data.economy))
```

- [ ] **Step 8: Remove the old fields**

In `balance/economy_balance.gd` delete the lines `counter_capacity`, `traveler_interval`, `queue_max`,
`service_time`. Then:

Run: `grep -rnE "economy\.(queue_max|traveler_interval|service_time|counter_capacity)|\be\.(queue_max|traveler_interval|service_time|counter_capacity)|eco\.(queue_max|traveler_interval|service_time|counter_capacity)" --include="*.gd" . | grep -v "^./addons"`

Every hit is a test. In each, keep the assertion and read the level-0 value instead:

| Old | New |
|---|---|
| `….queue_max` | `StationEffects.queue_max(0, Balance.data.stations)` |
| `….traveler_interval` | `StationEffects.traveler_interval(0, Balance.data.stations)` |
| `….service_time` | `StationEffects.service_time(0, Balance.data.stations)` |
| `….counter_capacity` | `StationEffects.counter_capacity(0, Balance.data.stations)` |

Two special cases:
- `tests/unit/test_station_effects.gd`: delete `test_level_0_matches_the_economy_fields_while_they_exist` and, in
  `test_max_carry_and_pool_size`, replace `bd.economy.queue_max * 2` with `8`.
- `tests/unit/test_piles.gd` `test_carry_stack_shows_the_max_capacity_exactly`: the cap is now

```gdscript
	var cap := StationEffects.max_carry(Balance.data.hero, Balance.data.cards, Balance.data.stations)
	assert_eq(cap, Balance.data.hero.carry_capacity + cb.carry_step * cb.max_level + Balance.data.stations.carry_bonus[Balance.data.stations.max_level])
```

  Keep the rest of that test.

Re-run the grep. Expected: no output.

- [ ] **Step 9: Run everything**

Run: `./run_tests.sh all 2>&1 | tail -8 && tools/baseline_diff.sh`
Expected: pass; `baseline identical`.

- [ ] **Step 10: Shots**

Run: `tools/shots.sh docs/review/media/e1/task06`
Plus one extra capture with a level 5 counter, 42 steaks on it, a full 9-traveler queue and a 26-steak carry (use
`GameState.debug_set_station_level` in the capture script the way `tests/sim/capture.gd` sets up its other scenes).
The main session checks: the pile does not hide the counter label, the queue's second row reads as a line, and the
carry stack stays on screen. If the stack leaves the screen: report it; do not cap it in this task (spec 8).

- [ ] **Step 11: Commit**

```bash
git add world/stations/counter.gd world/stations/freezer.gd world/traveler_spawner.gd components/carry_stack.gd actors/bots/planner_bot.gd ui/guide/guide.gd balance/economy_balance.gd tests/unit docs/review/media/e1/task06
git commit -m "feat(e1): stations, travelers and carry read the upgraded values"
```

---

### Task 7: The sign, the autosave, sound, sparkle and the guide

Spec 5.4.

**Files:**
- Modify: `core/pulse.gd`, `world/stations/closeup_sign.gd`, `world/save/autosave.gd`,
  `world/audio/audio_director.gd`, `world/fx/reactions.gd`, `ui/guide/guide.gd` (the `should_pulse` entry)
- Test: `tests/unit/test_station_reactions.gd` (new), `tests/unit/test_pulse.gd` (add tests)

**Interfaces:**
- Consumes: `EventBus.station_changed`, `station_upgraded`; `GameState.to_dict().stations`.
- Produces: `Pulse.should_pulse` counts stations when the state has a `stations` key.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_pulse.gd`:

```gdscript
func _with_stations(s: Dictionary) -> Dictionary:
	s["stations"] = {"counter": {"level": 0, "paid": 0}, "freezer": {"level": 0, "paid": 0}}
	return s

func test_a_state_without_stations_ignores_them() -> void:
	var s := _state()
	s.gold = 1
	assert_true(Pulse.should_pulse(s, Balance.data))

func test_an_affordable_station_blocks_the_pulse() -> void:
	var sb := Balance.data.stations
	var cheapest := mini(sb.counter_cost, sb.freezer_cost)
	var s := _with_stations(_state())
	s.gold = cheapest
	assert_false(Pulse.should_pulse(s, Balance.data))
	s.gold = cheapest - 1
	assert_true(Pulse.should_pulse(s, Balance.data))

func test_a_partly_paid_station_counts_what_is_left() -> void:
	var s := _with_stations(_state())
	s.gold = 1
	s.stations.counter.paid = Balance.data.stations.counter_cost - 1
	assert_false(Pulse.should_pulse(s, Balance.data))

func test_maxed_stations_are_ignored() -> void:
	var s := _with_stations(_state())
	for id in s.stations:
		s.stations[id].level = Balance.data.stations.max_level
	for id in MapLayout.SPOT_IDS:
		s.buildings[id].level = Balance.data.build.max_level
	s.gold = 100000
	assert_true(Pulse.should_pulse(s, Balance.data))
```

`tests/unit/test_station_reactions.gd`:

```gdscript
extends GutTest

var main: Main
var _fx: Array = []

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(8)
	main.phase_controller.debug_skip_to_day()
	_fx = []
	EventBus.fx_requested.connect(_on_fx)

func after_each() -> void:
	EventBus.fx_requested.disconnect(_on_fx)

func _on_fx(kind: StringName, pos: Vector3) -> void:
	_fx.append([kind, pos])

func _max_everything_but_the_counter() -> void:
	for id in MapLayout.SPOT_IDS:
		GameState.buildings[id].level = Balance.data.build.max_level  # test-only setup
	GameState.debug_set_station_level(&"freezer", Balance.data.stations.max_level)
	GameState.debug_set_station_level(&"counter", Balance.data.stations.max_level - 1)

func test_the_sign_pulses_after_the_last_station_level_is_bought() -> void:
	_max_everything_but_the_counter()
	var cost := GameState.station_next_cost(&"counter")
	GameState.add_gold(cost)
	assert_false(main.world.closeup_sign.pulsing, "something is affordable")
	GameState.pay_into_station(&"counter", cost)
	assert_eq(GameState.station_level(&"counter"), Balance.data.stations.max_level)
	assert_true(main.world.closeup_sign.pulsing, "nothing is left to buy")

func test_an_upgrade_sparkles_at_the_pad() -> void:
	GameState.add_gold(30)
	GameState.pay_into_station(&"counter", 30)
	var at := MapLayout.to3(MapLayout.STATION_PADS[&"counter"], 1.0)
	assert_true(_fx.has([&"sparkle", at]), "sparkle at the counter pad: %s" % [_fx])

func test_the_guide_snapshot_ignores_stations() -> void:
	var guide := Guide.new()
	main.add_child(guide)
	main.settings_store = SettingsStore.with_dir("user://test_station_guide")
	main.settings_store.wipe_for_tests()
	main.settings_store.load_settings()
	guide.setup(main)
	GameState.add_gold(Balance.data.stations.freezer_cost)  # covers a pad; the loop below leaves no spot to buy
	for id in MapLayout.SPOT_IDS:
		GameState.buildings[id].level = Balance.data.build.max_level  # test-only setup: no spot is buyable
	var snap: Dictionary = guide.snapshot()
	assert_true(bool(snap.should_pulse), "the tutorial's close rule does not wait for stations")
	assert_false(Pulse.should_pulse(GameState.to_dict(), Balance.data), "the sign itself does wait")
	assert_eq(int(snap.counter_capacity), GameState.counter_capacity())
```

For the guide test, follow how `tests/unit/test_guide.gd` builds its `Guide` (settings store first, then `setup`); if
it differs from the lines above, copy that file's helper and keep the three assertions.

Add to `tests/unit/test_autosave.gd`, next to `test_offer_pick_build_and_day_writes` and using that file's own
helpers (`_saved()` and its day setup):

```gdscript
func test_a_station_upgrade_writes_at_once() -> void:
	# the same setup as test_offer_pick_build_and_day_writes up to the DAY phase, then:
	GameState.add_gold(30)
	var before: int = autosave.writes
	GameState.pay_into_station(&"counter", 30)
	assert_gt(autosave.writes, before, "station_upgraded writes at once")
	assert_eq(int(_saved().stations.counter.level), 1)
```

(`autosave` here is whatever name that file gives its `Autosave` instance.)

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit 2>&1 | grep -E "test_pulse|test_station_reactions|test_autosave" | head -20`
Expected: the new tests FAIL.

- [ ] **Step 3: Pulse**

In `core/pulse.gd`, before the final `return true`:

```gdscript
	# E1: an affordable station upgrade is something left to do. No `stations` key = none (the guide passes that).
	var stations: Dictionary = state.get("stations", {})
	for id in stations:
		var st: Dictionary = stations[id]
		var cost := StationEffects.level_cost(StringName(id), int(st.level), bd.stations)
		if cost >= 0 and gold >= cost - int(st.paid):
			return false
```

- [ ] **Step 4: The listeners**

- `world/stations/closeup_sign.gd`, next to the `building_changed` connection:

```gdscript
	EventBus.station_changed.connect(_on_station_changed)
```

  and next to `_on_building_changed`:

```gdscript
## gold_changed fires before the level increments, so the pulse must be re-read after station_changed (E1).
func _on_station_changed(_id: StringName, _level: int, _paid: int) -> void:
	refresh_pulse()
```

- `world/save/autosave.gd` `_ready`, after the `build_completed` connection:

```gdscript
	EventBus.station_upgraded.connect(_on_build_completed)  # "after each build" covers station levels (E1)
	EventBus.station_changed.connect(_mark_dirty.unbind(3))
```

- `world/audio/audio_director.gd`, after the `build_completed` line:

```gdscript
	EventBus.station_upgraded.connect(func(_id, _lv): play(&"build_done"))
```

- `world/fx/reactions.gd`: connect next to `build_completed`, and disconnect wherever this file disconnects
  `_on_build_completed`:

```gdscript
	EventBus.station_upgraded.connect(_on_station_upgraded)
```

```gdscript
func _on_station_upgraded(id: StringName, _level: int) -> void:
	EventBus.fx_requested.emit(&"sparkle", MapLayout.to3(MapLayout.STATION_PADS[id], 1.0))
```

- `ui/guide/guide.gd` `snapshot()`: before the `return {`, add

```gdscript
	var spots_only := gs.to_dict()
	spots_only.erase("stations")  # the tutorial never waits for a station upgrade (E1 spec 5.4)
```

  and change the entry to `"should_pulse": Pulse.should_pulse(spots_only, Balance.data),`

- [ ] **Step 5: Run everything**

Run: `./run_tests.sh all 2>&1 | tail -8 && tools/baseline_diff.sh`
Expected: pass; `baseline identical`. The baseline bots do not read the sign's pulse, so the new pulse rule cannot
move them; if the diff is not identical, stop and report.

- [ ] **Step 6: Commit**

```bash
git add core/pulse.gd world/stations/closeup_sign.gd world/save/autosave.gd world/audio/audio_director.gd world/fx/reactions.gd ui/guide/guide.gd tests/unit/test_pulse.gd tests/unit/test_station_reactions.gd tests/unit/test_autosave.gd
git commit -m "feat(e1): sign pulse, autosave, sound and sparkle react to station upgrades"
```

**Phase 2 PR:** `e1/p2-world` into `main`. Body: test tails, `baseline identical`, the Task 5 and 6 shots.

---

# Phase 3: `e1/p3-sims`

### Task 8: UpgraderBot and the three sims

Spec 5.6, criteria 6.1 to 6.3.

**Files:**
- Create: `actors/bots/upgrader_bot.gd`
- Modify: `actors/bots/planner_bot.gd` (the last 2 lines of `day_think`, plus one new method)
- Test: `tests/sim/test_station_sims.gd` (new), `tests/unit/test_upgrader_bot.gd` (new)

**Interfaces:**
- Consumes: `GameState.station_remaining_cost`, `debug_set_station_level`; `SimHarness`; `ParkedBot`;
  `MapLayout.STATION_PADS`.
- Produces: `PlannerBot.idle_goal() -> String` (returns `"sign"`); `class_name UpgraderBot` with graph nodes
  `pad_counter`, `pad_freezer`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_upgrader_bot.gd`:

```gdscript
extends GutTest

func before_each() -> void:
	Balance.reset()
	GameState.new_game(3)

func test_its_graph_is_the_default_plus_two_pads() -> void:
	var bot := UpgraderBot.new()
	autofree(bot)
	var base := WaypointGraph.create_default()
	assert_eq(bot.graph.nodes.size(), base.nodes.size() + 2)
	for id in StationEffects.IDS:
		assert_eq(bot.graph.position_of("pad_%s" % id), MapLayout.STATION_PADS[id])
		assert_false(bot.graph.shortest("home", "pad_%s" % id).is_empty(), "reachable")
	assert_false(base.nodes.has("pad_counter"), "the shared default graph is untouched")

func test_idle_goal_is_the_cheapest_station_it_can_finish() -> void:
	var bot := UpgraderBot.new()
	autofree(bot)
	assert_eq(bot.idle_goal(), "sign", "no gold")
	GameState.add_gold(25)
	assert_eq(bot.idle_goal(), "pad_freezer")
	GameState.add_gold(5)
	assert_eq(bot.idle_goal(), "pad_freezer", "still the cheapest")
	GameState.debug_set_station_level(&"freezer", 1)  # next costs 50
	assert_eq(bot.idle_goal(), "pad_counter")
	GameState.debug_set_station_level(&"counter", 1)  # next costs 60
	assert_eq(bot.idle_goal(), "sign", "30 gold finishes nothing")

func test_ties_go_to_the_counter() -> void:
	var bot := UpgraderBot.new()
	autofree(bot)
	Balance.data.stations.freezer_cost = Balance.data.stations.counter_cost
	GameState.add_gold(100)
	assert_eq(bot.idle_goal(), "pad_counter")

func test_the_planner_still_idles_at_the_sign() -> void:
	var bot := PlannerBot.new()
	autofree(bot)
	GameState.add_gold(1000)
	assert_eq(bot.idle_goal(), "sign")
```

`tests/sim/test_station_sims.gd`:

```gdscript
extends GutTest
## E1 spec criteria 6.1 to 6.3 (D-230).

const SEED := 20260930
const WINDOW_S := 60.0
var h: SimHarness
var _served := 0

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)
	_served = 0
	EventBus.steak_sold.connect(_on_sold)

func after_each() -> void:
	EventBus.steak_sold.disconnect(_on_sold)
	h.finish()

func _on_sold(_count: int, _gold: int) -> void:
	_served += 1

## Travelers served in WINDOW_S of a day with the counter always stocked.
func _served_at(level: int) -> int:
	h.finish()
	await get_tree().process_frame
	Balance.reset()
	h = SimHarness.new(self)
	h.start(SEED, ParkedBot)
	h.main.hero.teleport(Vector2(15, 8))  # away from every zone
	h.main.phase_controller.debug_skip_to_day()
	GameState.debug_set_station_level(&"counter", level)
	_served = 0
	var cap := GameState.counter_capacity()
	for i in int(WINDOW_S * Engine.physics_ticks_per_second):
		GameState.counter_steaks = cap  # test-only setup: always stocked
		await h.tick()
	return _served

func test_6_1_every_counter_level_serves_more_than_the_one_below() -> void:
	var sb := Balance.data.stations
	var gain: float = sb.min_level_gain
	var max_level: int = sb.max_level
	var counts: Array = []
	for level in range(0, max_level + 1):
		counts.append(await _served_at(level))
	gut.p("served per level in %ds: %s" % [int(WINDOW_S), counts])
	assert_gt(counts[0], 0)
	for level in range(1, counts.size()):
		assert_gte(float(counts[level]), float(counts[level - 1]) * (1.0 + gain),
			"level %d serves %d, level %d serves %d" % [level, counts[level], level - 1, counts[level - 1]])

## Seconds DAY phase 1 takes for the PlannerBot with the counter preset to `level`.
func _day1_seconds(level: int) -> float:
	h.finish()
	await get_tree().process_frame
	Balance.reset()
	h = SimHarness.new(self)
	h.start(SEED, PlannerBot)
	var n1 := await h.run_night()
	assert_true(n1.cleared, "night 1 must clear")
	GameState.debug_set_station_level(&"counter", level)
	var d := await h.run_day()
	assert_true(d.closed, "day 1 must close up at level %d" % level)
	return d.seconds

func test_6_2_a_level_3_counter_shortens_the_day() -> void:
	var base := await _day1_seconds(0)
	var upgraded := await _day1_seconds(3)
	gut.p("day 1: %.1fs at level 0, %.1fs at level 3" % [base, upgraded])
	assert_lt(upgraded, base)

func test_6_3_the_upgrader_holds_nights_1_to_3() -> void:
	h.start(SEED, UpgraderBot)
	for night in range(1, 4):
		var n := await h.run_night()
		assert_true(n.cleared, "night %d: %s" % [night, n])
		if night < 3:
			var d := await h.run_day()
			assert_true(d.closed, "day %d closes up" % night)
	gut.p("upgrader stations after night 3: %s, stuck %d" % [GameState.stations, h.bot.stuck_count])
	assert_eq(h.bot.stuck_count, 0, "the pad routes are walkable")
```

If `run_night` returns before the DAY phase is fully entered and `debug_set_station_level` there is too early for the
spawner's first interval, set the level one `await h.tick()` later; both runs of 6.2 must do the same.

- [ ] **Step 2: Run them and see them fail**

Run: `./run_tests.sh unit 2>&1 | grep -E "test_upgrader_bot|SCRIPT ERROR" | head`
Expected: FAIL, `UpgraderBot` unknown.

- [ ] **Step 3: The planner's idle hook**

In `actors/bots/planner_bot.gd` `day_think`, replace the final `else:` block's last line

```gdscript
		go_to(spot if spot != "" else "sign")
```

with

```gdscript
		go_to(spot if spot != "" else idle_goal())
```

and add below `day_think`:

```gdscript
## Where to go when nothing is left to haul, sell or build. The planner closes up.
func idle_goal() -> String:
	return "sign"
```

- [ ] **Step 4: The bot**

`actors/bots/upgrader_bot.gd`:

```gdscript
class_name UpgraderBot
extends PlannerBot
## PlannerBot that spends what is left on station upgrades before closing up (E1 spec 5.6, D-230).
## Defense first: it only looks at the pads once the planner has no purchase for tonight.

func _init() -> void:
	# Its own graph: WaypointGraph.create_default() must stay as it is for the baseline bots.
	graph.add_node("pad_counter", MapLayout.STATION_PADS[&"counter"])
	graph.add_edge("pad_counter", "front_e")
	graph.add_edge("pad_counter", "home")
	graph.add_node("pad_freezer", MapLayout.STATION_PADS[&"freezer"])
	graph.add_edge("pad_freezer", "se")
	graph.add_edge("pad_freezer", "freezer")

func day_think(delta: float) -> void:
	# keep standing on a pad that is mid-payment (each tick drains gold, so idle_goal would flip)
	if goal.begins_with("pad_") and arrived():
		var id := StringName(goal.trim_prefix("pad_"))
		if int(GameState.stations[id].paid) > 0 and GameState.gold > 0 and GameState.station_remaining_cost(id) > 0:
			return
	super.day_think(delta)

## The cheapest station level the gold in hand can finish; ties go to the counter (IDS order).
func idle_goal() -> String:
	var best := ""
	var best_rem := 0
	for id in StationEffects.IDS:
		var rem := GameState.station_remaining_cost(id)
		if rem >= 0 and rem <= GameState.gold and (best == "" or rem < best_rem):
			best = "pad_%s" % id
			best_rem = rem
	return best if best != "" else "sign"
```

- [ ] **Step 5: Run the unit tests**

Run: `./run_tests.sh unit 2>&1 | tail -8`
Expected: all pass.

- [ ] **Step 6: Run the sims and record the numbers**

Run: `./run_tests.sh sim 2>&1 | grep -E "served per level|day 1:|upgrader stations|SIM SUITE|passed|failed"`

- 6.2 and 6.3 must pass.
- 6.1 may fail at this point: that is the dead-level guard working, and tuning is Task 10. **Do not change the
  tables and do not weaken the test.** Put the printed `served per level` line and the `SIM SUITE` seconds in the
  report. If 6.1 fails, mark the task DONE_WITH_CONCERNS and say which levels fail.
- If `SIM SUITE` is over 60 s: report the per-test timings and stop (D-132).

- [ ] **Step 7: Baseline**

Run: `tools/baseline_diff.sh`
Expected: `baseline identical` (the planner's `idle_goal()` returns `"sign"`, as before).

- [ ] **Step 8: Commit**

```bash
git add actors/bots/upgrader_bot.gd actors/bots/planner_bot.gd tests/unit/test_upgrader_bot.gd tests/sim/test_station_sims.gd
git commit -m "feat(e1): UpgraderBot and the station sims"
```

---

### Task 9: Upgrader sweep and the level 5 perf fixture

Spec 5.6.

**Files:**
- Modify: `tests/sim/sweep_runner.gd`, `tests/sim/make_save.gd`, `export/perf_night3.sh`
- Create: `export/fixtures/day3_counter5.save.json` (generated)
- Test: `tests/unit/test_perf_fixture.gd` (add one test)

**Interfaces:**
- Consumes: `UpgraderBot` (Task 8), `GameState.to_dict().stations` (Task 4).
- Produces: `sweep.gd -- --bot=upgrader` writes `tests/sim/out/sweep_upgrader.csv`;
  `make_save.gd -- --fixture=day3_counter5`; `DAY_FIXTURE=day3_counter5 export/perf_night3.sh …`.

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_perf_fixture.gd`:

```gdscript
func test_the_level_5_day_fixture_loads() -> void:
	var text := FileAccess.get_file_as_string("res://export/fixtures/day3_counter5.save.json")
	assert_ne(text, "", "generate it: make_save.gd -- --fixture=day3_counter5")
	var r := SaveCodec.decode(text, GameState.SCHEMA_VERSION, Balance.data)
	assert_true(r.ok, r.reason)
	assert_eq(String(r.state.resume_phase), "DAY")
	assert_eq(int(r.state.day), 3)
	assert_eq(int(r.state.stations.counter.level), Balance.data.stations.max_level)
```

Run: `./run_tests.sh unit 2>&1 | grep -E "test_perf_fixture" | head`
Expected: FAIL (the file does not exist).

- [ ] **Step 2: Sweep mode**

In `tests/sim/sweep_runner.gd` `_run`:

- `var args := {"seed": "20260930", "days": "14", "bot": "planner"}`
- After `Balance.reset()`: `var upgrader := String(args.bot) == "upgrader"`
- `h.start(int(args.seed), UpgraderBot if upgrader else PlannerBot)`
- The header row: append `+ (",stations" if upgrader else "")` to the header string.
- Each of the three `rows.append(...)` calls inside the day loop: append `+ _stations(upgrader)` to the string.
- The output file: `out_dir.path_join("sweep_upgrader.csv" if upgrader else "sweep.csv")`

Add:

```gdscript
## "" for the planner (its CSV must stay byte-identical to the S4 baseline); the station levels for the upgrader.
func _stations(upgrader: bool) -> String:
	if not upgrader:
		return ""
	var parts: Array = []
	for id in StationEffects.IDS:
		parts.append("%s:%d" % [id, GameState.station_level(id)])
	return "," + "|".join(parts)
```

Update the file's header comment: add "`--bot=upgrader` runs the UpgraderBot and writes `sweep_upgrader.csv` with a
`stations` column (E1)."

- [ ] **Step 3: Check both modes**

Run: `tools/baseline_diff.sh`
Expected: `baseline identical`.

Run: `"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd -- --bot=upgrader --days=6 2>&1 | tail -12`
Expected: 6 rows ending in a `counter:N|freezer:M` column, a `SWEEP` line, no `SCRIPT ERROR`, and
`tests/sim/out/sweep_upgrader.csv` exists. Paste the rows in the report.

- [ ] **Step 4: The fixture generator**

In `tests/sim/make_save.gd`:

- Add a member `var _fixture := ""` and, at the top of `_run`:

```gdscript
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fixture="):
			_fixture = a.trim_prefix("--fixture=")
```

- In `_on_snapshot`, right after `_done = true`:

```gdscript
	if _fixture == "day3_counter5":
		# E1 perf: day 3 with a level 5 counter (a 9-traveler queue). The night3_* fixtures stay at schema 3.
		var s5: Dictionary = state.duplicate(true)
		s5.resume_phase = "DAY"
		s5.stations["counter"] = {"level": root.get_node("Balance").data.stations.max_level, "paid": 0}
		_write("day3_counter5", s5)
		quit(0)
		return
```

- Move the body of the existing `for pair in …` loop's file writing into a helper and call it from both places:

```gdscript
func _write(fixture: String, s: Dictionary) -> void:
	var codec = load("res://core/save_codec.gd")
	var path := ProjectSettings.globalize_path("res://export/fixtures/%s.save.json" % fixture)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(codec.encode(s, "fixture", 0))
	f.close()
	print("wrote ", path)
```

- Update the header comment: "`-- --fixture=day3_counter5` writes only that fixture. Do not run it without the
  argument in E1: that would rewrite the night3 fixtures at schema 4, and they are kept at schema 3 as migration
  tests."

Run: `"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/make_save.gd -- --fixture=day3_counter5 2>&1 | tail -3`
Expected: `wrote …/export/fixtures/day3_counter5.save.json`.

Run: `git status --short export/fixtures`
Expected: only `day3_counter5.save.json` is new; the two `night3_*` files are unchanged.

- [ ] **Step 5: The perf script**

In `export/perf_night3.sh`:

- After the `TO=` line: `DAY_FIXTURE="${DAY_FIXTURE:-night3_closeup}"`
- In the day `openurl` line replace `f=night3_closeup` with `f=$DAY_FIXTURE`.
- Add to the header comment: `# DAY_FIXTURE (optional, default night3_closeup) picks the day fixture, e.g. DAY_FIXTURE=day3_counter5 (E1).`

Run: `bash -n export/perf_night3.sh && echo ok`
Expected: `ok`.

- [ ] **Step 6: Run the tests**

Run: `./run_tests.sh unit 2>&1 | tail -6`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add tests/sim/sweep_runner.gd tests/sim/make_save.gd export/perf_night3.sh export/fixtures/day3_counter5.save.json tests/unit/test_perf_fixture.gd
git commit -m "feat(e1): upgrader sweep mode and a level 5 day perf fixture"
```

---

### Task 10: Tuning, readings and docs (main session)

Spec 4, 7, 8. The main session does this task itself: it holds the balance decisions (D-103) and the hot files.

**Files:**
- Modify: `balance/station_balance.gd` (main purpose, only if 6.1 fails), `docs/REVIEW_QUEUE.md`,
  `docs/DECISIONS.md`, `CLAUDE.md`
- Create: `docs/review/media/e1/` readings

- [ ] **Step 1: Sim 6.1**

Run: `./run_tests.sh sim 2>&1 | grep -E "served per level|SIM SUITE|failed"`

If 6.1 passes, go to Step 2. If it fails, tune `queue_max`, `traveler_interval` and `service_time` for the failing
levels in `balance/station_balance.gd`. Rules:
- Level 0 never changes.
- Each table stays monotonic (Task 1's test).
- `queue_max` never exceeds `MapLayout.QUEUE_SLOTS.size()` (9). More slots is a layout change: stop and split.
- At most 3 rounds (D-103). After the third failing round, stop and bring the `served per level` lines to the author.
- Never lower `min_level_gain` and never touch the test to make it pass.

Log the final tables and the served counts as a decision in `docs/DECISIONS.md`.

- [ ] **Step 2: Full suites and the baseline**

Run: `./run_tests.sh all 2>&1 | tail -8 && tools/baseline_diff.sh`
Expected: pass, `SIM SUITE` under 60 s, `baseline identical`.

- [ ] **Step 3: The upgrader sweep**

For each seed in `20260930 11 777`:

Run: `"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd -- --bot=upgrader --seed=<seed> > docs/review/media/e1/sweep_upgrader_<seed>.txt 2>&1; cp tests/sim/out/sweep_upgrader.csv docs/review/media/e1/sweep_upgrader_<seed>.csv`

Compare `first_fail_day` and `hard_break_day` with `tests/sim/baseline/s4_sweep_<seed>.txt`, and `day_seconds` per
row. Write the comparison (3 lines per seed) into `docs/DECISIONS.md`. If the upgrader breaks more than 2 days earlier
than the planner on any seed, that is a balance conflict: bring it to the author with the numbers before merging.

- [ ] **Step 4: Day perf at level 5**

Build the web profile pack (`export/README.md`), then:

Run: `DAY_FIXTURE=day3_counter5 export/perf_night3.sh <web_profile_dir> docs/review/media/e1/perf_counter5`

Three runs; read the frozen `PERF phase=DAY` line; take the median (D-199). Record it next to the D-221 day-3 reading
(52.9 fps) in `docs/DECISIONS.md` and in known issue 1 of `docs/REVIEW_QUEUE.md`. A lower reading is reported, not
tuned away.

- [ ] **Step 5: Device check**

Push the branch, wait for the Pages preview, then:

Run: `export/device_check.sh https://khanhnguyendev.github.io/last-stand-tycoon/preview/e1-p3-sims/ docs/review/media/e1/device`

Read the screenshots: the pads, labels and pips are readable on the notch iPhone. Android is Playwright Pixel 7,
labelled **emulated** (D-141).

- [ ] **Step 6: Docs**

- `docs/REVIEW_QUEUE.md`, new section "E1 station upgrades":
  1. No per-level station art; a level shows as a pop and star pips (D-229).
  2. Station upgrades are a mid-game sink: with defense first, 8 to 38 gold is left in days 1 to 3. Too late?
  3. The freezer upgrade is comfort, not day speed (D-230).
  4. The 26-steak carry stack height (with the Task 6 shot).
  5. The queue's second row beside the road (with the Task 6 shot).
  6. Playtest question: "Did you notice you could upgrade the counter and the freezer? Did you want to?"
- `CLAUDE.md`, Commands section, after the Sweep line:
  `- Upgrader sweep (E1): the same command with `-- --bot=upgrader`; writes `tests/sim/out/sweep_upgrader.csv``
- `CLAUDE.md`, "Git workflow", first bullet: the branch pattern reads `s<N>/p<N>-<slug>` or `e<N>/p<N>-<slug>`.
- `docs/DECISIONS.md`: one decision entry for the task (tuned tables or "tables unchanged", sweep comparison, perf).

- [ ] **Step 7: Commit and open the checkpoint PR**

```bash
git add balance/station_balance.gd docs CLAUDE.md
git commit -m "docs(e1): tuning, upgrader sweep, level 5 perf reading, review queue"
```

Open the PR `e1/p3-sims` into `main`. **Checkpoint: do not merge.** Give the author the preview URL and these things to
try: buy counter level 1 on the first day, watch the queue, buy a freezer level, close the tab mid-payment and reopen.

---

## Self-review notes

- Spec coverage: criterion 1, 3 (Tasks 3, 5); 2 (Task 6, sim 6.1); 4 (every task's `baseline_diff`, Task 9);
  5 (Task 4); 6 (Task 8, tuned in Task 10); 7 (Global Constraints, Task 10). Spec 5.4's listeners: Task 7. Spec 5.6
  perf: Tasks 9 and 10. Spec 8 risks: Task 10's review-queue items.
- Two deliberate differences from the spec, both written into the tasks that own them: `traveler_pool_size` takes the
  economy balance as a second argument (Task 1); the `paid < cost` validation rule becomes a clamp on load (Task 4,
  which amends the spec line).
