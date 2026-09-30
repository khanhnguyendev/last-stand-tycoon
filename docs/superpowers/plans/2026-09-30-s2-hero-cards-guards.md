# S2 Hero Cards + Adventurer Guards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill the dawn `CARD_PICK` stub with IDEA.md's 7 hero cards and add the Archer and Tank guards, then re-tune the waves for a day-10 break with cards.

**Architecture:**
- Pure `core/` modules hold all the rules and are unit-tested:
  - `CardCatalog`: ids, kinds, text;
  - `CardEffects`: levels → stats;
  - `CardOffer`: the seeded offers.
- `GameState` stores card levels, the open offer and the Tank's HP (schema v2). `PhaseController` waits in DAWN/`CARD_PICK` for `EventBus.card_chosen`.
- The UI (`CardPickOverlay`) and the bots both only emit `card_chosen`.
- Guards are plain `Node3D` actors owned by a `GuardRoster`. The roster registers the `guard` target provider, and the Boar gains one `match` arm.

**Tech Stack:** Godot 4.7.2 (GDScript, Compatibility renderer, single-threaded web export), GUT 9.7.1, headless sims.

**Spec:** `docs/superpowers/specs/2026-09-30-s2-hero-cards-guards-design.md`. It builds on the S1 spec `docs/superpowers/specs/2026-09-30-s1-vertical-slice-design.md`. Decisions are D-161 to D-170 in `docs/DECISIONS.md`.

## Global Constraints

- `GODOT_TAG=4.7.2-stable`. Tests run with `./run_tests.sh unit|sim|all|--quick`, with `export GODOT=/Users/ryan/Applications/Godot-4.7.2-stable/Godot.app/Contents/MacOS/Godot`.
- Gameplay runs in `_physics_process` only. It never depends on frame delta.
- Randomness only through `Rng.stream(run_seed, day, name)`. `test_no_global_rand` bans global `randi`/`randf`/`randi_range` calls; calls on an `rng` object are fine.
- Only `GameState` methods mutate game data, and they emit the EventBus signals. Tweens are visual only.
- EventBus is for cross-system events only.
- Every number lives in `balance/`. Every user string goes through `tr()` (in nodes) or `TranslationServer.translate()` (in static functions).
- Ties are broken by a fixed id order (`CardCatalog.IDS`, `spawn_index`), never by node order.
- `PhaseController` uses only the D-128 whitelist on its exports. `test_phase_controller` enforces this.
- **D-139 hot files:** implementers never edit these unless the file is the task's main purpose:
  - `world/main.gd`, `world/world.gd`, `world/main.tscn`
  - `autoload/EventBus.gd`, `autoload/GameState.gd`
  - `balance/*`, `project.godot`, `run_tests.sh`, `CLAUDE.md`, `.github/workflows/*`
  They deliver a wiring note plus a patch instead, and the main session applies it. The task headers below say where a hot file *is* the task's main purpose.
- `./run_tests.sh` fails on GUT errors and any `SCRIPT ERROR`. Don't write tests that expect engine errors.
- Sims and tests read state after `await get_tree().physics_frame`. `physics_frame` fires before the nodes' `_physics_process` (D-118).
- The sim suite stays under 60 s (D-132). Never drop, skip or weaken a test.
- Commits end with:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_019nNyHrXgHzKVKBtdqy9Hez
  ```
- **Phases and branches (D-133).** One PR per phase, self-merged under D-137/D-159 once CI is green:

  | Phase | Branch | Tasks |
  |---|---|---|
  | 1 | `s2/p1-core` | 1–3 |
  | 2 | `s2/p2-flow` | 4–7 |
  | 3 | `s2/p3-pick-ui` | 8–9 |
  | 4 | `s2/p4-guards` | 10–12 |
  | 5 | `s2/p5-tuning` | 13–15 |

## Review Focus

These are inputs the spec implies but no task tests by default. Each one has its test added to the owning task.

1. **Landscape or short windows at the pick.** Three 220 px panels plus the heading don't fit 1280×720. Expected: panels shrink to fit inside the safe area, and never overlap or go off screen. Covered by Task 8, `test_layout_fits_landscape_and_two_cards`.
2. **Focus pause during the pick** (switching apps at dawn). Expected: owned fingers are dropped, and after resuming a normal tap still picks. Covered by Task 8, `test_pause_then_resume_still_picks`.
3. **Tank knocked out when dawn arrives.** Expected: at dawn the Tank is back on its post with full HP, with no respawn timer running into the day. Covered by Task 11, `test_dawn_restores_a_downed_tank`.
4. **A thumb still on the joystick when the night ends.** Expected: the stick ends, and the release over a panel picks nothing. Covered by Task 8, `test_held_stick_release_over_panel_does_not_pick`.
5. **Everything maxed.** Expected: no overlay, straight to DAY, and a later dawn still works. Covered by Task 5, `test_empty_offer_skips_to_day`.

---

## Phase 1: Pure core (`s2/p1-core`)

### Task 1: Card and guard balance resources

Main purpose: `balance/*`, so the implementer edits the balance files directly.

**Files:**
- Create: `balance/card_balance.gd`, `balance/guard_stats.gd`, `balance/guard_balance.gd`
- Modify: `balance/balance_data.gd`, `balance/target_priority.gd`, `balance/sim_thresholds.gd`, `balance/ui_tuning.gd`
- Test: `tests/unit/test_balance.gd`

**Interfaces:**
- Produces:
  - `Balance.data.cards: CardBalance` with `max_level:int=5`, `offer_size:int=3`, `damage_step:float=0.20`, `attack_speed_step:float=0.15`, `move_step:float=0.08`, `carry_step:int=2`, `gold_step:int=1`.
  - `Balance.data.guards: GuardBalance`, which has `archer: GuardStats`, `tank: GuardStats` and `func stats(id: StringName) -> GuardStats`.
  - `GuardStats` fields: `max_hp`, `hp_growth`, `damage`, `damage_growth`, `interval`, `attack_range`, `projectile_speed`, `body_radius`, `walk_speed`, `respawn_s` (floats), plus `targetable: bool` and `on_roof: bool`.
  - `Balance.data.wave.target_priority.kinds == [&"fence_on_lane", &"guard", &"diner"]`.
  - `Balance.data.sim.break_day_target:int=10`, `break_day_tolerance:int=1`.
  - `Balance.ui.card_input_guard_s:float=0.5`, `card_panel_size:Vector2=(560,220)`, `card_panel_gap:float=24.0`, `card_panel_min_h:float=120.0`.

- [ ] **Step 1: Write the failing test.** Add to `tests/unit/test_balance.gd`, and change the `target_priority` pin inside `test_spec_values_loaded` (line 14) to the three kinds:

```gdscript
	assert_eq(Array(d.wave.target_priority.kinds), [&"fence_on_lane", &"guard", &"diner"])
```

```gdscript
func test_s2_card_balance_defaults() -> void:
	var c := Balance.data.cards
	assert_eq([c.max_level, c.offer_size, c.carry_step, c.gold_step], [5, 3, 2, 1])
	assert_almost_eq(c.damage_step, 0.20, 1e-6)
	assert_almost_eq(c.attack_speed_step, 0.15, 1e-6)
	assert_almost_eq(c.move_step, 0.08, 1e-6)

func test_s2_guard_balance_defaults() -> void:
	var a := Balance.data.guards.archer
	var t := Balance.data.guards.tank
	assert_eq([a.targetable, a.on_roof, t.targetable, t.on_roof], [false, true, true, false])
	assert_eq([a.damage, a.damage_growth, a.interval, a.attack_range, a.projectile_speed, a.body_radius],
		[6.0, 0.30, 0.6, 9.0, 16.0, 0.4])
	assert_eq([t.max_hp, t.hp_growth, t.damage, t.damage_growth, t.interval, t.attack_range, t.projectile_speed,
		t.body_radius, t.walk_speed, t.respawn_s], [160.0, 0.35, 5.0, 0.25, 0.8, 2.5, 60.0, 0.45, 3.0, 3.0])
	assert_eq(Balance.data.guards.stats(&"archer"), a)
	assert_eq(Balance.data.guards.stats(&"tank"), t)

func test_s2_thresholds_and_ui() -> void:
	assert_eq([Balance.data.sim.break_day_target, Balance.data.sim.break_day_tolerance], [10, 1])
	assert_almost_eq(Balance.ui.card_input_guard_s, 0.5, 1e-6)
	assert_eq(Balance.ui.card_panel_size, Vector2(560, 220))
	assert_almost_eq(Balance.ui.card_panel_gap, 24.0, 1e-6)
	assert_almost_eq(Balance.ui.card_panel_min_h, 120.0, 1e-6)

func test_s2_reset_deep_copies_guard_stats() -> void:
	Balance.data.guards.tank.max_hp = 1.0
	Balance.reset()
	assert_eq(Balance.data.guards.tank.max_hp, 160.0, "D-157: sub-resources built by initializers survive reset")
```

- [ ] **Step 2: Run it and see it fail.** Run `./run_tests.sh unit`. Expected: FAIL. The parse errors name `cards`, `guards` and `break_day_target`.

- [ ] **Step 3: Implement.**

`balance/card_balance.gd`:
```gdscript
class_name CardBalance
extends Resource
## Hero-card tuning (S2 spec 8, D-167). Upgrade steps are per level; max level per card is max_level.

@export var max_level := 5
@export var offer_size := 3
@export var damage_step := 0.20
@export var attack_speed_step := 0.15
@export var move_step := 0.08
@export var carry_step := 2
@export var gold_step := 1
```

`balance/guard_stats.gd`:
```gdscript
class_name GuardStats
extends Resource
## One adventurer's level-1 stats and per-level growth (S2 spec 8). Stat at level L = base x (1 + growth x (L - 1)).

@export var max_hp := 0.0
@export var hp_growth := 0.0
@export var damage := 0.0
@export var damage_growth := 0.0
@export var interval := 1.0
@export var attack_range := 0.0
@export var projectile_speed := 16.0
@export var body_radius := 0.4
@export var walk_speed := 0.0
@export var respawn_s := 0.0
## Ground guards are enemy targets (D-164); the roof Archer is not.
@export var targetable := false
@export var on_roof := false
```

`balance/guard_balance.gd`:
```gdscript
class_name GuardBalance
extends Resource
## Archer and Tank stats (S2 spec 8, D-163). Built by initializers: exports keep .tres as text (D-157).

@export var archer: GuardStats = GuardBalance._archer()
@export var tank: GuardStats = GuardBalance._tank()

func stats(id: StringName) -> GuardStats:
	assert(id == &"archer" or id == &"tank", "no guard stats for %s" % id)
	return archer if id == &"archer" else tank

static func _archer() -> GuardStats:
	var s := GuardStats.new()
	s.damage = 6.0
	s.damage_growth = 0.30
	s.interval = 0.6
	s.attack_range = 9.0
	s.projectile_speed = 16.0
	s.body_radius = 0.4
	s.targetable = false
	s.on_roof = true
	return s

static func _tank() -> GuardStats:
	var s := GuardStats.new()
	s.max_hp = 160.0
	s.hp_growth = 0.35
	s.damage = 5.0
	s.damage_growth = 0.25
	s.interval = 0.8
	s.attack_range = 2.5
	s.projectile_speed = 60.0  # melee: the same Attacker, a near-instant projectile
	s.body_radius = 0.45
	s.walk_speed = 3.0
	s.respawn_s = 3.0
	s.targetable = true
	s.on_roof = false
	return s
```

`balance/balance_data.gd`: append the following two lines after `sim`.
```gdscript
@export var cards: CardBalance = CardBalance.new()
@export var guards: GuardBalance = GuardBalance.new()
```

`balance/target_priority.gd`: the kinds line becomes:
```gdscript
## Ordered target kinds an enemy checks each tick (D-004, D-049, D-164).
@export var kinds: Array[StringName] = [&"fence_on_lane", &"guard", &"diner"]
```

`balance/sim_thresholds.gd`: append:
```gdscript
## S2 sweep target (D-170): the PlannerBot breaks at break_day_target +- break_day_tolerance. Reported, not asserted.
@export var break_day_target := 10
@export var break_day_tolerance := 1
```

`balance/ui_tuning.gd`: append:
```gdscript
## S2 card pick overlay (D-162): early taps are ignored for card_input_guard_s; panel size, gap, and the
## smallest height panels may shrink to on short (landscape) windows.
@export var card_input_guard_s := 0.5
@export var card_panel_size := Vector2(560, 220)
@export var card_panel_gap := 24.0
@export var card_panel_min_h := 120.0
```

- [ ] **Step 4: Run and see it pass.** Run `./run_tests.sh all`. Expected: exit 0.
  - The `guard` kind has no provider yet, so `find_target` skips it and every S1 test passes unchanged.
  - If `tests/unit/test_boar.gd:91` or any other test pins a two-kind list, update only that pin to the three kinds.

- [ ] **Step 5: Commit.**
```bash
git add balance tests/unit/test_balance.gd
git commit -m "feat(balance): S2 card, guard, threshold and UI tuning resources (Task S2-1)"
```

### Task 2: `CardCatalog` and `CardEffects`

**Files:**
- Create: `core/card_catalog.gd`, `core/card_effects.gd`
- Test: `tests/unit/test_card_catalog.gd`, `tests/unit/test_card_effects.gd`

**Interfaces:**
- Consumes: `CardBalance`, `GuardBalance`, `GuardStats` (Task 1).
- Produces:
  - `CardCatalog.IDS`, `CardCatalog.UPGRADES`, `CardCatalog.ADVENTURERS` (`Array[StringName]`).
  - `CardCatalog.kind(id) -> StringName` (`&"upgrade"` / `&"adventurer"`) and `CardCatalog.max_level(cb) -> int`.
  - Text: `CardCatalog.display_name(id) -> String`, `effect_text(id, cb) -> String`, `level_text(current_level) -> String`, `pick_banner(id, new_level) -> String`.
  - `CardCatalog.GLYPHS: Dictionary`.
  - `CardEffects.level_of(levels, id) -> int`.
  - `CardEffects.hero_damage(base, levels, cb) -> float`, `hero_attack_interval(...) -> float`, `hero_move_speed(...) -> float`.
  - `CardEffects.carry_capacity(base:int, levels, cb) -> int`, `gold_per_steak(base:int, levels, cb) -> int`.
  - `CardEffects.guard_stats(id, level, gb) -> Dictionary` with the keys `max_hp`, `damage`, `interval`, `range`, `projectile_speed`, `body_radius`, `walk_speed`, `respawn_s`, `targetable`, `on_roof`.
  - Levels are a `Dictionary` of StringName → int; a missing id means level 0.

- [ ] **Step 1: Write the failing tests.**

`tests/unit/test_card_catalog.gd`:
```gdscript
extends GutTest

func before_each() -> void:
	Balance.reset()

func test_ids_kinds_and_order() -> void:
	assert_eq(CardCatalog.IDS, [&"hero_damage", &"attack_speed", &"move_speed", &"carry_capacity",
		&"gold_per_steak", &"archer", &"tank"] as Array[StringName])
	assert_eq(CardCatalog.UPGRADES.size() + CardCatalog.ADVENTURERS.size(), CardCatalog.IDS.size())
	for id in CardCatalog.UPGRADES:
		assert_eq(CardCatalog.kind(id), &"upgrade")
	for id in CardCatalog.ADVENTURERS:
		assert_eq(CardCatalog.kind(id), &"adventurer")
	assert_eq(CardCatalog.max_level(Balance.data.cards), 5)

func test_every_card_has_text_and_glyph() -> void:
	var cb := Balance.data.cards
	for id in CardCatalog.IDS:
		assert_ne(CardCatalog.display_name(id), "", "name for %s" % id)
		assert_ne(CardCatalog.effect_text(id, cb), "", "effect for %s" % id)
		assert_eq(String(CardCatalog.GLYPHS[id]).length(), 2, "glyph for %s" % id)
	assert_eq(CardCatalog.effect_text(&"hero_damage", cb), "+20% hero damage")
	assert_eq(CardCatalog.effect_text(&"carry_capacity", cb), "+2 carry")
	assert_eq(CardCatalog.effect_text(&"gold_per_steak", cb), "+1 gold per steak")

func test_level_and_banner_text() -> void:
	assert_eq(CardCatalog.level_text(0), "NEW")
	assert_eq(CardCatalog.level_text(2), "Lv 2 → 3")
	assert_eq(CardCatalog.pick_banner(&"archer", 1), "The Archer joins!")
	assert_eq(CardCatalog.pick_banner(&"tank", 3), "Tank Lv 3")
	assert_eq(CardCatalog.pick_banner(&"move_speed", 2), "Running Shoes Lv 2")
```

`tests/unit/test_card_effects.gd`:
```gdscript
extends GutTest

var cb: CardBalance

func before_each() -> void:
	Balance.reset()
	cb = Balance.data.cards

func test_level_zero_is_base() -> void:
	var none := {}
	assert_eq(CardEffects.hero_damage(10.0, none, cb), 10.0)
	assert_eq(CardEffects.hero_attack_interval(0.5, none, cb), 0.5)
	assert_eq(CardEffects.hero_move_speed(5.0, none, cb), 5.0)
	assert_eq(CardEffects.carry_capacity(6, none, cb), 6)
	assert_eq(CardEffects.gold_per_steak(3, none, cb), 3)

func test_upgrades_at_every_level() -> void:
	for l in range(0, 6):
		var lv := {&"hero_damage": l, &"attack_speed": l, &"move_speed": l, &"carry_capacity": l, &"gold_per_steak": l}
		assert_almost_eq(CardEffects.hero_damage(10.0, lv, cb), 10.0 * (1.0 + 0.20 * l), 1e-5)
		assert_almost_eq(CardEffects.hero_attack_interval(0.5, lv, cb), 0.5 / (1.0 + 0.15 * l), 1e-5)
		assert_almost_eq(CardEffects.hero_move_speed(5.0, lv, cb), 5.0 * (1.0 + 0.08 * l), 1e-5)
		assert_eq(CardEffects.carry_capacity(6, lv, cb), 6 + 2 * l)
		assert_eq(CardEffects.gold_per_steak(3, lv, cb), 3 + l)

func test_guard_stats_scale_per_level() -> void:
	var gb := Balance.data.guards
	var t1 := CardEffects.guard_stats(&"tank", 1, gb)
	var t3 := CardEffects.guard_stats(&"tank", 3, gb)
	assert_almost_eq(t1.max_hp, 160.0, 1e-5)
	assert_almost_eq(t3.max_hp, 160.0 * (1.0 + 0.35 * 2), 1e-4)
	assert_almost_eq(t3.damage, 5.0 * (1.0 + 0.25 * 2), 1e-5)
	assert_eq([t3.interval, t3.range, t3.targetable, t3.on_roof], [0.8, 2.5, true, false])
	var a5 := CardEffects.guard_stats(&"archer", 5, gb)
	assert_almost_eq(a5.damage, 6.0 * (1.0 + 0.30 * 4), 1e-5)
	assert_eq([a5.range, a5.targetable, a5.on_roof], [9.0, false, true])
```

- [ ] **Step 2: Run them and see them fail.** Run `./run_tests.sh unit`. Expected: FAIL; `CardCatalog`/`CardEffects` are not declared.

- [ ] **Step 3: Implement.**

`core/card_catalog.gd`:
```gdscript
class_name CardCatalog
extends RefCounted
## The 7 hero-card types (S2 spec 4.1, D-166). IDS order is the tie-break order everywhere.

const IDS: Array[StringName] = [&"hero_damage", &"attack_speed", &"move_speed", &"carry_capacity",
	&"gold_per_steak", &"archer", &"tank"]
const UPGRADES: Array[StringName] = [&"hero_damage", &"attack_speed", &"move_speed", &"carry_capacity", &"gold_per_steak"]
const ADVENTURERS: Array[StringName] = [&"archer", &"tank"]
const NAMES := {
	&"hero_damage": "Sharp Cleaver", &"attack_speed": "Quick Hands", &"move_speed": "Running Shoes",
	&"carry_capacity": "Big Backpack", &"gold_per_steak": "Fancy Menu", &"archer": "Archer", &"tank": "Tank",
}
const GLYPHS := {
	&"hero_damage": "DM", &"attack_speed": "AS", &"move_speed": "MV", &"carry_capacity": "CA",
	&"gold_per_steak": "GO", &"archer": "AR", &"tank": "TK",
}

static func kind(id: StringName) -> StringName:
	assert(id in IDS, "unknown card %s" % id)
	return &"adventurer" if id in ADVENTURERS else &"upgrade"

static func max_level(cb: CardBalance) -> int:
	return cb.max_level

static func display_name(id: StringName) -> String:
	return TranslationServer.translate(NAMES[id])

static func effect_text(id: StringName, cb: CardBalance) -> String:
	match id:
		&"hero_damage":
			return TranslationServer.translate("+%d%% hero damage") % roundi(cb.damage_step * 100.0)
		&"attack_speed":
			return TranslationServer.translate("+%d%% attack speed") % roundi(cb.attack_speed_step * 100.0)
		&"move_speed":
			return TranslationServer.translate("+%d%% move speed") % roundi(cb.move_step * 100.0)
		&"carry_capacity":
			return TranslationServer.translate("+%d carry") % cb.carry_step
		&"gold_per_steak":
			return TranslationServer.translate("+%d gold per steak") % cb.gold_step
		&"archer":
			return TranslationServer.translate("Shoots from the roof")
	return TranslationServer.translate("Holds the west lane")

## The level line on a card: NEW for an unowned card, otherwise "Lv n → n+1".
static func level_text(current_level: int) -> String:
	if current_level <= 0:
		return TranslationServer.translate("NEW")
	return TranslationServer.translate("Lv %d → %d") % [current_level, current_level + 1]

static func pick_banner(id: StringName, new_level: int) -> String:
	if kind(id) == &"adventurer" and new_level == 1:
		return TranslationServer.translate("The %s joins!") % display_name(id)
	return TranslationServer.translate("%s Lv %d") % [display_name(id), new_level]
```

`core/card_effects.gd`:
```gdscript
class_name CardEffects
extends RefCounted
## Card levels -> the stats in effect (S2 spec 4.2, D-167). Pure: base values, levels and balance in; value out.

static func level_of(levels: Dictionary, id: StringName) -> int:
	return int(levels.get(id, 0))

static func hero_damage(base: float, levels: Dictionary, cb: CardBalance) -> float:
	return base * (1.0 + cb.damage_step * level_of(levels, &"hero_damage"))

static func hero_attack_interval(base: float, levels: Dictionary, cb: CardBalance) -> float:
	return base / (1.0 + cb.attack_speed_step * level_of(levels, &"attack_speed"))

static func hero_move_speed(base: float, levels: Dictionary, cb: CardBalance) -> float:
	return base * (1.0 + cb.move_step * level_of(levels, &"move_speed"))

static func carry_capacity(base: int, levels: Dictionary, cb: CardBalance) -> int:
	return base + cb.carry_step * level_of(levels, &"carry_capacity")

static func gold_per_steak(base: int, levels: Dictionary, cb: CardBalance) -> int:
	return base + cb.gold_step * level_of(levels, &"gold_per_steak")

## A guard's stats at level >= 1: base x (1 + growth x (level - 1)).
static func guard_stats(id: StringName, level: int, gb: GuardBalance) -> Dictionary:
	assert(level >= 1, "guard_stats needs level >= 1")
	var s := gb.stats(id)
	var k := float(level - 1)
	return {
		"max_hp": s.max_hp * (1.0 + s.hp_growth * k),
		"damage": s.damage * (1.0 + s.damage_growth * k),
		"interval": s.interval,
		"range": s.attack_range,
		"projectile_speed": s.projectile_speed,
		"body_radius": s.body_radius,
		"walk_speed": s.walk_speed,
		"respawn_s": s.respawn_s,
		"targetable": s.targetable,
		"on_roof": s.on_roof,
	}
```

- [ ] **Step 4: Run and see them pass.** Run `./run_tests.sh unit`. Expected: exit 0.

- [ ] **Step 5: Commit.**
```bash
git add core/card_catalog.gd core/card_effects.gd tests/unit/test_card_catalog.gd tests/unit/test_card_effects.gd
git commit -m "feat(core): card catalog and card effects (Task S2-2)"
```

### Task 3: `CardOffer`

**Files:**
- Create: `core/card_offer.gd`
- Test: `tests/unit/test_card_offer.gd`

**Interfaces:**
- Consumes: `CardCatalog.IDS`/`UPGRADES`, `CardEffects.level_of`, `CardBalance`, `Rng.stream`.
- Produces: `CardOffer.make(run_seed: int, day: int, levels: Dictionary, cb: CardBalance) -> Array[StringName]`. `day` is the post-`advance_day` day, so the first dawn uses 2.

- [ ] **Step 1: Write the failing test.** The golden values below come from the pinned engine (Godot 4.7.2, seed 20260930, the exact draw of spec §4.3). A mismatch means the draw changed: fix the code, never the pins.

`tests/unit/test_card_offer.gd`:
```gdscript
extends GutTest

const SEED := 20260930
var cb: CardBalance

func before_each() -> void:
	Balance.reset()
	cb = Balance.data.cards

func _all(level: int) -> Dictionary:
	var d := {}
	for id in CardCatalog.IDS:
		d[id] = level
	return d

func test_golden_offers() -> void:
	assert_eq(CardOffer.make(SEED, 2, {}, cb), [&"archer", &"tank", &"carry_capacity"] as Array[StringName])
	assert_eq(CardOffer.make(SEED, 3, {&"tank": 1}, cb),
		[&"archer", &"hero_damage", &"carry_capacity"] as Array[StringName])
	assert_eq(CardOffer.make(SEED, 4, {&"tank": 1, &"archer": 1}, cb),
		[&"carry_capacity", &"attack_speed", &"hero_damage"] as Array[StringName])

func test_first_offer_is_archer_tank_and_one_upgrade_for_any_seed() -> void:
	for s in [1, 7, 99, 20260930, 123456]:
		var o := CardOffer.make(s, 2, {}, cb)
		assert_eq(o.size(), 3)
		assert_eq([o[0], o[1]], [&"archer", &"tank"])
		assert_true(o[2] in CardCatalog.UPGRADES, "third is an upgrade: %s" % o[2])

func test_zero_level_entries_still_mean_first_offer() -> void:
	var o := CardOffer.make(SEED, 2, {&"tank": 0}, cb)
	assert_eq([o[0], o[1]], [&"archer", &"tank"])

func test_later_offers_are_distinct_and_eligible() -> void:
	var levels := {&"tank": 1, &"hero_damage": 5, &"archer": 5}
	for day in range(3, 30):
		var o := CardOffer.make(SEED, day, levels, cb)
		assert_eq(o.size(), 3)
		var seen := {}
		for id in o:
			assert_false(seen.has(id), "distinct on day %d" % day)
			seen[id] = true
			assert_ne(id, &"hero_damage", "maxed card offered")
			assert_ne(id, &"archer", "maxed card offered")

func test_fewer_eligible_means_fewer_cards() -> void:
	var levels := _all(5)
	levels[&"tank"] = 2
	levels[&"archer"] = 4
	assert_eq(CardOffer.make(SEED, 9, levels, cb), [&"archer", &"tank"] as Array[StringName])

func test_all_maxed_is_empty() -> void:
	assert_eq(CardOffer.make(SEED, 9, _all(5), cb), [] as Array[StringName])

func test_deterministic_per_seed_and_day() -> void:
	var lv := {&"tank": 2, &"move_speed": 1}
	assert_eq(CardOffer.make(SEED, 6, lv, cb), CardOffer.make(SEED, 6, lv, cb))
	var differ := false
	for day in range(3, 13):
		if CardOffer.make(SEED, day, lv, cb) != CardOffer.make(SEED, day + 1, lv, cb):
			differ = true
	assert_true(differ, "offers vary by day")
```

- [ ] **Step 2: Run it and see it fail.** Run `./run_tests.sh unit`. Expected: FAIL; `CardOffer` is not declared.

- [ ] **Step 3: Implement.** `core/card_offer.gd`:
```gdscript
class_name CardOffer
extends RefCounted
## Dawn card offers (S2 spec 4.3, D-166). The draw is pinned (golden test) so every build gives the same offers.

static func make(run_seed: int, day: int, levels: Dictionary, cb: CardBalance) -> Array[StringName]:
	var rng := Rng.stream(run_seed, day, &"cards")
	var out: Array[StringName] = []
	if not _any_picked(levels):
		out.append(&"archer")
		out.append(&"tank")
		out.append(CardCatalog.UPGRADES[rng.randi_range(0, CardCatalog.UPGRADES.size() - 1)])
		return out
	var pool: Array[StringName] = []
	for id in CardCatalog.IDS:
		if CardEffects.level_of(levels, id) < cb.max_level:
			pool.append(id)
	for i in mini(cb.offer_size, pool.size()):
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out

## "No card picked yet": no id at level >= 1 (a zero entry does not count).
static func _any_picked(levels: Dictionary) -> bool:
	for id in levels:
		if int(levels[id]) >= 1:
			return true
	return false
```

- [ ] **Step 4: Run and see it pass.** Run `./run_tests.sh all`. Expected: exit 0.

- [ ] **Step 5: Commit, then open the Phase 1 PR.**
```bash
git add core/card_offer.gd tests/unit/test_card_offer.gd
git commit -m "feat(core): seeded dawn card offers with golden pins (Task S2-3)"
```

---

## Phase 2: State and flow (`s2/p2-flow`)

### Task 4: EventBus signals and GameState v2

Main purpose: `autoload/EventBus.gd` and `autoload/GameState.gd`.

**Files:**
- Modify: `autoload/EventBus.gd`, `autoload/GameState.gd`
- Test: `tests/unit/test_game_state.gd`

**Interfaces:**
- Consumes: `CardEffects`, `CardCatalog`, `Balance.data.cards`/`guards` (Tasks 1–2).
- Produces:
  - **EventBus signals:** `card_offered(offer: Array)`, `card_chosen(card_id: StringName)`, `card_picked(card_id: StringName, level: int)`, `guard_damaged(guard_id: StringName, hp_left: float)`, `guard_knocked_out(guard_id: StringName)`, `guard_revived(guard_id: StringName)`, `guard_healed(guard_id: StringName, hp: float)`.
  - **GameState fields:** `cards: Dictionary` (StringName → int), `card_offer: Array[StringName]`, `guards: Dictionary` (StringName → `{"hp": float}`).
  - **GameState methods:**
    - reads: `card_level(id) -> int`, `carry_capacity() -> int`, `gold_per_steak() -> int`, `guard_max_hp(id) -> float`
    - offer: `set_card_offer(offer: Array[StringName])`, `clear_card_offer()`, `pick_card(id) -> int`, `debug_grant_card(id) -> int`
    - guards: `damage_guard(id, amount)`, `revive_guard(id)`
  - `SCHEMA_VERSION = 2`. `to_dict()` writes String keys and ids.

- [ ] **Step 1: Write the failing tests.** Append to `tests/unit/test_game_state.gd`. Its `before_each` already calls `Balance.reset()` and `GameState.new_game(...)`; if not, add both.

```gdscript
func test_new_game_clears_cards() -> void:
	GameState.debug_grant_card(&"tank")
	GameState.new_game(5)
	assert_eq([GameState.cards, GameState.card_offer, GameState.guards], [{}, [] as Array[StringName], {}])

func test_offer_and_pick() -> void:
	watch_signals(EventBus)
	GameState.set_card_offer([&"archer", &"tank", &"move_speed"] as Array[StringName])
	assert_signal_emitted_with_parameters(EventBus, "card_offered", [[&"archer", &"tank", &"move_speed"]])
	var lvl := GameState.pick_card(&"move_speed")
	assert_eq(lvl, 1)
	assert_eq(GameState.card_level(&"move_speed"), 1)
	assert_eq(GameState.card_offer, [] as Array[StringName])
	assert_signal_emitted_with_parameters(EventBus, "card_picked", [&"move_speed", 1])
	assert_false(GameState.guards.has(&"move_speed"))

func test_clear_offer_emits_nothing() -> void:
	GameState.set_card_offer([&"archer"] as Array[StringName])
	watch_signals(EventBus)
	GameState.clear_card_offer()
	assert_eq(GameState.card_offer, [] as Array[StringName])
	assert_signal_not_emitted(EventBus, "card_offered")

func test_tank_gets_hp_archer_does_not() -> void:
	GameState.debug_grant_card(&"archer")
	assert_false(GameState.guards.has(&"archer"), "the roof archer has no HP (spec 5.2)")
	GameState.debug_grant_card(&"tank")
	assert_eq(GameState.guards[&"tank"].hp, 160.0)
	GameState.debug_grant_card(&"tank")
	assert_almost_eq(float(GameState.guards[&"tank"].hp), 160.0 * 1.35, 1e-3, "level-up sets HP to the new max")

func test_damage_knockout_once_then_noop_and_revive() -> void:
	GameState.debug_grant_card(&"tank")
	watch_signals(EventBus)
	GameState.damage_guard(&"tank", 100.0)
	assert_signal_emitted_with_parameters(EventBus, "guard_damaged", [&"tank", 60.0])
	GameState.damage_guard(&"tank", 100.0)
	assert_eq(GameState.guards[&"tank"].hp, 0.0)
	assert_signal_emit_count(EventBus, "guard_knocked_out", 1)
	GameState.damage_guard(&"tank", 5.0)
	assert_signal_emit_count(EventBus, "guard_damaged", 2)
	assert_signal_emit_count(EventBus, "guard_knocked_out", 1)
	GameState.damage_guard(&"archer", 5.0)  # no entry: no-op
	GameState.revive_guard(&"tank")
	assert_eq(GameState.guards[&"tank"].hp, 160.0)
	assert_signal_emitted_with_parameters(EventBus, "guard_revived", [&"tank"])

func test_dawn_heals_guards_with_signal() -> void:
	GameState.debug_grant_card(&"tank")
	GameState.damage_guard(&"tank", 1000.0)
	watch_signals(EventBus)
	GameState.heal_for_dawn()
	assert_eq(GameState.guards[&"tank"].hp, 160.0)
	assert_signal_emitted_with_parameters(EventBus, "guard_healed", [&"tank", 160.0])

func test_card_effects_reach_economy() -> void:
	GameState.debug_grant_card(&"carry_capacity")
	GameState.debug_grant_card(&"gold_per_steak")
	assert_eq(GameState.carry_capacity(), Balance.data.hero.carry_capacity + 2)
	assert_eq(GameState.gold_per_steak(), Balance.data.economy.gold_per_steak + 1)
	GameState.freezer_steaks = 20  # test-only setup write
	assert_eq(GameState.move_freezer_to_carry(20), Balance.data.hero.carry_capacity + 2)
	GameState.carried_steaks = 0  # test-only setup write
	GameState.counter_steaks = 2  # test-only setup write
	GameState.sell_from_counter(2)
	assert_eq(GameState.gold_pile, 2 * (Balance.data.economy.gold_per_steak + 1))

func test_round_trip_v2_through_json() -> void:
	GameState.debug_grant_card(&"tank")
	GameState.debug_grant_card(&"hero_damage")
	GameState.damage_guard(&"tank", 30.0)
	GameState.set_card_offer([&"archer", &"move_speed"] as Array[StringName])
	var d := GameState.to_dict()
	assert_eq(int(d.v), 2)
	assert_eq(d.cards, {"tank": 1, "hero_damage": 1})
	assert_eq(d.card_offer, ["archer", "move_speed"])
	assert_eq(d.guards, {"tank": {"hp": 130.0}})
	var back = JSON.parse_string(JSON.stringify(d, "", true, true))  # D-146 full precision
	GameState.new_game(1)
	GameState.from_dict(back)
	assert_eq(GameState.to_dict(), d)
	assert_eq(GameState.card_level(&"tank"), 1)
	assert_eq(GameState.card_offer, [&"archer", &"move_speed"] as Array[StringName])
```

If the existing `test_game_state.gd` pins `to_dict()` keys or `"v": 1`, update those pins to schema 2 with the three new keys.

- [ ] **Step 2: Run them and see them fail.** Run `./run_tests.sh unit`. Expected: FAIL; the methods are unknown.

- [ ] **Step 3: Implement.**

`autoload/EventBus.gd`: append:
```gdscript
## PhaseController (via GameState) -> overlay, HUD, bots. The dawn offer, in display order.
signal card_offered(offer: Array)
## Overlay / bots -> PhaseController. A pick request; ignored unless it matches the open offer.
signal card_chosen(card_id: StringName)
## GameState -> Hero, guards, HUD. level is the card's new level.
signal card_picked(card_id: StringName, level: int)
## GameState -> guards. hp_left after the hit.
signal guard_damaged(guard_id: StringName, hp_left: float)
## GameState -> guards, sims. Once per knockout.
signal guard_knocked_out(guard_id: StringName)
## GameState -> guards. Back at full HP after the respawn timer.
signal guard_revived(guard_id: StringName)
## GameState -> guards. Dawn healed the guard to hp (spec 5.2: after phase_changed(DAWN)).
signal guard_healed(guard_id: StringName, hp: float)
```

`autoload/GameState.gd` changes:
- `const SCHEMA_VERSION := 2`
- Add after `lane_plan`:
```gdscript
## S2: card levels (StringName -> int; missing = 0), the open dawn offer, and targetable guards' HP.
var cards := {}
var card_offer: Array[StringName] = []
var guards := {}
```
- In `new_game()`, before `lane_plan = ...`:
```gdscript
	cards = {}
	card_offer = []
	guards = {}
```
- In `to_dict()`, add these entries to the returned dictionary:
```gdscript
		"cards": _string_keys(cards), "card_offer": card_offer.map(func(id): return String(id)),
		"guards": _guards_out(),
```
- In `from_dict()`, before `EventBus.state_restored.emit()`:
```gdscript
	cards = {}
	for k in d.cards:
		cards[StringName(k)] = int(d.cards[k])
	card_offer = []
	for id in d.card_offer:
		card_offer.append(StringName(id))
	guards = {}
	for k in d.guards:
		guards[StringName(k)] = {"hp": float(d.guards[k].hp)}
```
- In `pick_steak()` and `move_freezer_to_carry()`, replace `Balance.data.hero.carry_capacity` with `carry_capacity()`. In `sell_from_counter()`, replace `Balance.data.economy.gold_per_steak` with `gold_per_steak()`.
- Append to `heal_for_dawn()`:
```gdscript
	for id in guards:
		guards[id].hp = guard_max_hp(id)
		EventBus.guard_healed.emit(id, float(guards[id].hp))
```
- New section at the end:
```gdscript
# --- cards and guards (S2) ------------------------------------------------

func card_level(id: StringName) -> int:
	return int(cards.get(id, 0))

func carry_capacity() -> int:
	return CardEffects.carry_capacity(Balance.data.hero.carry_capacity, cards, Balance.data.cards)

func gold_per_steak() -> int:
	return CardEffects.gold_per_steak(Balance.data.economy.gold_per_steak, cards, Balance.data.cards)

func guard_max_hp(id: StringName) -> float:
	return float(CardEffects.guard_stats(id, maxi(card_level(id), 1), Balance.data.guards).max_hp)

func set_card_offer(offer: Array[StringName]) -> void:
	card_offer = offer.duplicate()
	EventBus.card_offered.emit(Array(card_offer))

## Debug skip only (spec 5.1): no signal, so no overlay shows.
func clear_card_offer() -> void:
	card_offer = []

func pick_card(id: StringName) -> int:
	assert(id in card_offer, "pick_card: %s is not offered" % id)
	var level := card_level(id) + 1
	assert(level <= Balance.data.cards.max_level, "pick_card: %s is maxed" % id)
	cards[id] = level
	card_offer = []
	if CardCatalog.kind(id) == &"adventurer" and Balance.data.guards.stats(id).targetable:
		guards[id] = {"hp": guard_max_hp(id)}
	EventBus.card_picked.emit(id, level)
	return level

## Debug and test helper: offer exactly this card, then pick it.
func debug_grant_card(id: StringName) -> int:
	card_offer = [id]
	return pick_card(id)

func damage_guard(id: StringName, amount: float) -> void:
	if not guards.has(id) or float(guards[id].hp) <= 0.0:
		return
	var hp := maxf(float(guards[id].hp) - amount, 0.0)
	guards[id].hp = hp
	EventBus.guard_damaged.emit(id, hp)
	if hp <= 0.0:
		EventBus.guard_knocked_out.emit(id)

func revive_guard(id: StringName) -> void:
	if not guards.has(id):
		return
	guards[id].hp = guard_max_hp(id)
	EventBus.guard_revived.emit(id)

static func _string_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = d[k]
	return out

func _guards_out() -> Dictionary:
	var out := {}
	for k in guards:
		out[String(k)] = {"hp": float(guards[k].hp)}
	return out
```

- [ ] **Step 4: Run and see them pass.** Run `./run_tests.sh all`. Expected: exit 0. The S1 sims are unchanged, because dawn still auto-continues until Task 5.

- [ ] **Step 5: Commit.**
```bash
git add autoload/EventBus.gd autoload/GameState.gd tests/unit/test_game_state.gd
git commit -m "feat(state): GameState v2 with cards, offer and guard HP; S2 EventBus signals (Task S2-4)"
```

### Task 5: The dawn pick in PhaseController, with a default bot pick

**Files:**
- Modify: `world/phase_controller.gd`, `actors/bots/bot_base.gd`
- Test: `tests/unit/test_phase_controller.gd`

**Interfaces:**
- Consumes: `CardOffer.make`, `CardCatalog.pick_banner`, `GameState.set_card_offer`/`clear_card_offer`/`pick_card`, `EventBus.card_chosen`.
- Produces:
  - DAWN waits in `dawn_substate == "CARD_PICK"` until a valid `card_chosen`.
  - `debug_skip_to_day()` skips the pick without granting a card, both from NIGHT and during `CARD_PICK`.
  - `BotBase.choose_card(offer: Array) -> StringName`, which is leftmost by default. Bots pick one physics tick after `card_offered`.

- [ ] **Step 1: Adapt and extend the tests** in `tests/unit/test_phase_controller.gd`.

Add a helper:
```gdscript
func _pick_first() -> void:
	EventBus.card_chosen.emit(GameState.card_offer[0])
```

In `test_close_up_collects_and_snapshots_day` and `test_fail_after_close_up_returns_to_day`, insert `_pick_first()` right after `EventBus.wave_cleared.emit(2)`.

Replace the tail of `test_dawn_steps_in_order` (from `assert_eq(pc.phase, Phase.DAY)`) with:
```gdscript
	assert_eq(pc.phase, Phase.DAWN)
	assert_eq(pc.dawn_substate, "CARD_PICK")
	assert_eq(GameState.card_offer.size(), 3)
	assert_eq([GameState.card_offer[0], GameState.card_offer[1]], [&"archer", &"tank"])
	assert_signal_emitted(EventBus, "card_offered")
	assert_eq(GameState.freezer_steaks, 3)
	assert_eq(GameState.carried_steaks, 2)
	assert_eq(GameState.diner_hp, Balance.data.build.diner_max_hp)
	assert_eq(GameState.buildings.fence_w, {"level": 0, "paid": 0, "hp": 0.0})
	assert_eq(GameState.buildings.fence_n.hp, GameState.fence_max_hp(1))
	assert_eq(GameState.day, 2)
	assert_ne(GameState.lane_plan[0].side, "")
	assert_eq(main.world.steak_pool.active().size(), 0)
	_pick_first()
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.card_level(&"archer"), 1)
	assert_eq(get_signal_parameters(EventBus, "phase_changed", 0), [Phase.DAWN, 1])
	assert_eq(get_signal_parameters(EventBus, "phase_changed", 1), [Phase.DAY, 2])
	assert_eq(pc.dawn_substate, "")
```

Add these tests:
```gdscript
func test_invalid_stale_and_night_choices_are_ignored() -> void:
	EventBus.card_chosen.emit(&"tank")  # at night
	assert_eq(GameState.card_level(&"tank"), 0)
	EventBus.wave_cleared.emit(2)
	EventBus.card_chosen.emit(&"gold_per_steak" if GameState.card_offer[2] != &"gold_per_steak" else &"move_speed")
	assert_eq(pc.phase, Phase.DAWN, "a card not in the offer is ignored")
	EventBus.card_chosen.emit(&"tank")
	assert_eq(pc.phase, Phase.DAY)
	EventBus.card_chosen.emit(&"archer")  # stale: the offer is closed
	assert_eq(GameState.card_level(&"archer"), 0)
	assert_eq(GameState.card_level(&"tank"), 1)

func test_pick_shows_banner() -> void:
	EventBus.wave_cleared.emit(2)
	watch_signals(EventBus)
	EventBus.card_chosen.emit(&"archer")
	assert_signal_emitted_with_parameters(EventBus, "banner_requested", ["The Archer joins!"])

func test_empty_offer_skips_to_day() -> void:
	for id in CardCatalog.IDS:
		GameState.cards[id] = Balance.data.cards.max_level  # test-only setup write
	watch_signals(EventBus)
	EventBus.wave_cleared.emit(2)
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(pc.dawn_substate, "")
	assert_signal_not_emitted(EventBus, "card_offered")
	pc.close_up()
	EventBus.wave_cleared.emit(2)
	assert_eq(pc.phase, Phase.DAY, "a later dawn still works")
	assert_eq(GameState.day, 3)

func test_debug_skip_grants_no_card_from_night_and_from_pick() -> void:
	pc.debug_skip_to_day()
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.cards, {})
	assert_eq(GameState.card_offer, [] as Array[StringName])
	pc.close_up()
	EventBus.wave_cleared.emit(2)
	assert_eq(pc.dawn_substate, "CARD_PICK")
	pc.debug_skip_to_day()
	assert_eq([pc.phase, pc.dawn_substate, GameState.cards], [Phase.DAY, "", {}])

func test_new_game_during_pick_resets_substate() -> void:
	EventBus.wave_cleared.emit(2)
	pc.start_new_game(3)
	assert_eq(pc.dawn_substate, "")
	assert_eq(pc.phase, Phase.NIGHT)
	EventBus.card_chosen.emit(&"archer")
	assert_eq(GameState.card_level(&"archer"), 0)
```

- [ ] **Step 2: Run them and see them fail.** Run `./run_tests.sh unit`. Expected: FAIL (dawn still auto-continues).

- [ ] **Step 3: Implement.**

`world/phase_controller.gd`:
- In `_ready()`, add `EventBus.card_chosen.connect(_on_card_chosen)`.
- In `start_new_game()`, add `dawn_substate = ""` after `_fail_id += 1`.
- In `_restore_snapshot()`, add `dawn_substate = ""` after `_recall_all()`.
- In `_run_dawn()`, remove the line `dawn_substate = "CARD_PICK"          # 5`, so that `_card_pick()` sets the sub-state.
- Replace `_card_pick()` and `debug_skip_to_day()`:
```gdscript
## Spec 5.4 step 5 (S2 spec 5.1): offer the dawn cards and wait for EventBus.card_chosen.
func _card_pick() -> void:
	var offer := CardOffer.make(GameState.run_seed, GameState.day, GameState.cards, Balance.data.cards)
	if offer.is_empty():
		dawn_substate = ""
		_enter_day()
		return
	dawn_substate = "CARD_PICK"
	GameState.set_card_offer(offer)

func _on_card_chosen(id: StringName) -> void:
	if phase != Phase.DAWN or dawn_substate != "CARD_PICK" or not GameState.card_offer.has(id):
		return
	var level := GameState.pick_card(id)
	dawn_substate = ""
	EventBus.banner_requested.emit(CardCatalog.pick_banner(id, level))
	_enter_day()

## Debug helpers (ui/debug hotkeys, tests). Same narrow interface.
## Skips the card pick without granting a card (S2 spec 5.1), from NIGHT or during CARD_PICK.
func debug_skip_to_day() -> void:
	if phase == Phase.NIGHT and not failing:
		_run_dawn()
	if phase == Phase.DAWN and dawn_substate == "CARD_PICK":
		GameState.clear_card_offer()
		dawn_substate = ""
		_enter_day()
```

`actors/bots/bot_base.gd`:
- Add `var _pending_offer: Array = []`.
- In `setup()`, add `EventBus.card_offered.connect(_on_card_offered)`.
- In `reset_route()`, add `_pending_offer = []`.
- At the top of `_physics_process`, after the `main == null` check:
```gdscript
	if not _pending_offer.is_empty():
		var pick := choose_card(_pending_offer)
		_pending_offer = []
		EventBus.card_chosen.emit(pick)
```
- Then add:
```gdscript
func _on_card_offered(offer: Array) -> void:
	_pending_offer = offer.duplicate()

## Which card to take from a dawn offer (D-168). Base: leftmost.
func choose_card(offer: Array) -> StringName:
	return offer[0]
```

- [ ] **Step 4: Run and see them pass.** Run `./run_tests.sh all`. Expected: exit 0.
  - The sims now pass through a real pick. Every bot takes the leftmost card, which is the Archer on dawn 1, and it has no effect yet.
  - The sim numbers must equal the pre-task numbers (`night2 naive/planner` lines). Paste both into the report.

- [ ] **Step 5: Commit.**
```bash
git add world/phase_controller.gd actors/bots/bot_base.gd tests/unit/test_phase_controller.gd
git commit -m "feat(flow): dawn waits for a card pick; debug skip grants none; bots pick leftmost (Task S2-5)"
```

### Task 6: Hero card effects and input blocking

**Files:**
- Modify: `actors/hero/hero.gd`, `actors/hero/hero_input.gd`, `ui/joystick/joystick.gd`
- Test: `tests/unit/test_hero.gd`, `tests/unit/test_joystick.gd`

**Interfaces:**
- Consumes: `CardEffects.hero_*`, `GameState.cards`, `EventBus.card_picked`/`state_restored`/`phase_changed`.
- Produces:
  - `Hero.move_speed() -> float`, which is the effective speed.
  - `Hero._apply_card_stats()` reconfigures the attacker (damage and interval).
  - `HeroInput.blocked: bool`, which is true in DAWN.
  - The joystick ends and ignores new presses while blocked.

- [ ] **Step 1: Write the failing tests.**

Append to `tests/unit/test_hero.gd`. Use the file's existing `main`/`hero` setup. If it builds a bare `Hero`, add a `Main.create()` fixture exactly like `test_phase_controller.gd`'s `before_each`, and call `pc.start_new_game(99)`.
```gdscript
func test_move_speed_card_applies() -> void:
	var base := Balance.data.hero.move_speed
	assert_almost_eq(main.hero.move_speed(), base, 1e-5)
	GameState.debug_grant_card(&"move_speed")
	assert_almost_eq(main.hero.move_speed(), base * 1.08, 1e-5)
	main.hero.teleport(Vector2(10, 0))
	main.hero.input.set_move(Vector2(1, 0))
	for i in 60:
		await get_tree().physics_frame
	main.hero.input.set_move(Vector2.ZERO)
	assert_almost_eq(main.hero.xz().x, 10.0 + base * 1.08, 0.25)

func test_attack_cards_reconfigure_attacker_and_restore_resets() -> void:
	var hb := Balance.data.hero
	GameState.debug_grant_card(&"hero_damage")
	GameState.debug_grant_card(&"attack_speed")
	assert_almost_eq(main.hero.attacker.damage, hb.attack_damage * 1.2, 1e-5)
	assert_almost_eq(main.hero.attacker.interval, hb.attack_interval / 1.15, 1e-5)
	GameState.new_game(4)  # cards cleared, state_restored
	assert_almost_eq(main.hero.attacker.damage, hb.attack_damage, 1e-5)
	assert_almost_eq(main.hero.attacker.interval, hb.attack_interval, 1e-5)

func test_input_blocked_in_dawn_only() -> void:
	main.hero.input.player_control = true
	EventBus.wave_cleared.emit(2)  # -> DAWN / CARD_PICK
	assert_true(main.hero.input.blocked)
	main.hero.input.set_move(Vector2.RIGHT)
	assert_eq(main.hero.input.get_move(), Vector2.ZERO)
	Input.action_press(&"move_right")
	assert_eq(main.hero.input.get_move(), Vector2.ZERO, "WASD is blocked too")
	Input.action_release(&"move_right")
	EventBus.card_chosen.emit(GameState.card_offer[0])
	assert_false(main.hero.input.blocked)
	main.hero.input.set_move(Vector2.RIGHT)
	assert_eq(main.hero.input.get_move(), Vector2.RIGHT)
```

Append to `tests/unit/test_joystick.gd`, reusing its existing fixture and touch helpers:
```gdscript
func test_blocked_input_ends_stick_and_ignores_new_press() -> void:
	_touch(0, Vector2(200, 700), true)
	assert_true(joystick.is_active())
	input.blocked = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(joystick.is_active(), "blocked ends the stick")
	_touch(1, Vector2(300, 700), true)
	assert_false(joystick.is_active(), "no new stick while blocked")
	input.blocked = false
	_touch(1, Vector2(300, 700), false)
	_touch(2, Vector2(300, 700), true)
	assert_true(joystick.is_active())
```
If the file names its fixtures differently, use its names. `_touch(index, pos, pressed)` sends an `InputEventScreenTouch` to `joystick.handle()`; add it if it doesn't exist.

- [ ] **Step 2: Run them and see them fail.** Run `./run_tests.sh unit`. Expected: FAIL (`move_speed()` and `blocked` are unknown).

- [ ] **Step 3: Implement.**

`actors/hero/hero_input.gd`:
- Add `var blocked := false` with the comment `## True during DAWN (S2 card pick): get_move() returns zero for WASD, joystick and bots.`
- Make `get_move()` start with:
```gdscript
	if blocked:
		return Vector2.ZERO
```

`actors/hero/hero.gd`:
- In `_ready()`, append:
```gdscript
	EventBus.card_picked.connect(func(_id: StringName, _level: int): _apply_card_stats())
	EventBus.state_restored.connect(_apply_card_stats)
	EventBus.phase_changed.connect(_on_phase_changed)
```
- In `setup()`, replace the `attacker.configure(...)` call and the `var hb := ...` line above it with `_apply_card_stats()`, keeping the three lines that follow.
- In `_physics_process`, the velocity uses `move_speed()`:
  `velocity = Vector3(mv.x, 0.0, mv.y) * move_speed()`.
- Add:
```gdscript
## Effective move speed with cards (S2 spec 4.2).
func move_speed() -> float:
	return CardEffects.hero_move_speed(Balance.data.hero.move_speed, GameState.cards, Balance.data.cards)

## Attack stats with cards; S1 configured these once in setup().
func _apply_card_stats() -> void:
	var hb := Balance.data.hero
	var cb := Balance.data.cards
	attacker.configure(CardEffects.hero_damage(hb.attack_damage, GameState.cards, cb), hb.attack_range,
		CardEffects.hero_attack_interval(hb.attack_interval, GameState.cards, cb), hb.retarget_interval,
		hb.moving_attack_speed_mult, hb.projectile_speed)

func _on_phase_changed(phase: int, _day: int) -> void:
	input.blocked = phase == Phase.DAWN
```

`ui/joystick/joystick.gd`:
- In `_physics_process`, add at the top:
```gdscript
	if _input_api != null and _input_api.blocked:
		if is_active():
			_end()
		return
```
- In `handle()`, add a guard in both press branches:
  - `if (not is_active() or event.index == active_index) and _allowed(event.position) and not _blocked():`
  - `if (not is_active() or active_index == -1) and _allowed(event.position) and not _blocked():`
- Add:
```gdscript
func _blocked() -> bool:
	return _input_api != null and _input_api.blocked
```

- [ ] **Step 4: Run and see them pass.** Run `./run_tests.sh all`. Expected: exit 0.

- [ ] **Step 5: Commit.**
```bash
git add actors/hero ui/joystick tests/unit/test_hero.gd tests/unit/test_joystick.gd
git commit -m "feat(hero): card stats for move/damage/attack speed; input blocked during the dawn pick (Task S2-6)"
```

### Task 7: Bot card policies and effective stat reads

**Files:**
- Modify: `actors/bots/bot_base.gd`, `actors/bots/naive_bot.gd`, `actors/bots/planner_bot.gd`, `tests/unit/helpers.gd`, `tests/sim/test_day_sims.gd`
- Test: `tests/unit/test_bots.gd`

**Interfaces:**
- Consumes: `BotBase.choose_card` (Task 5), `Hero.move_speed()` (Task 6), `GameState.carry_capacity()` (Task 4).
- Produces:
  - `NaiveBot.choose_card`: `&"archer"` if it is offered, otherwise the leftmost card.
  - `PlannerBot.choose_card`: the first card in `PlannerBot.CARD_PREFERENCE` order that is offered.

- [ ] **Step 1: Write the failing tests.** Append to `tests/unit/test_bots.gd`, using its existing `Main` fixture. Add a `Main.create()` fixture like `test_phase_controller.gd` if there is none.
```gdscript
func test_card_policies() -> void:
	var naive := NaiveBot.new()
	var planner := PlannerBot.new()
	var parked := ParkedBot.new()
	assert_eq(naive.choose_card([&"tank", &"move_speed", &"archer"]), &"archer")
	assert_eq(naive.choose_card([&"move_speed", &"tank"]), &"move_speed")
	assert_eq(planner.choose_card([&"archer", &"tank", &"carry_capacity"]), &"tank")
	assert_eq(planner.choose_card([&"move_speed", &"carry_capacity", &"gold_per_steak"]), &"gold_per_steak")
	assert_eq(planner.choose_card([&"move_speed"]), &"move_speed")
	assert_eq(parked.choose_card([&"carry_capacity", &"archer"]), &"carry_capacity")
	for b in [naive, planner, parked]:
		b.free()

func test_planner_fills_to_effective_carry_capacity() -> void:
	for i in 5:
		GameState.debug_grant_card(&"carry_capacity")
	var bot := PlannerBot.new()
	main.add_child(bot)
	bot.setup(main)
	main.phase_controller.debug_skip_to_day()
	GameState.freezer_steaks = 40  # test-only setup write
	var ok := false
	for i in 60 * 60:
		await get_tree().physics_frame
		if GameState.carried_steaks >= GameState.carry_capacity():
			ok = true
			break
	assert_true(ok, "loaded to %d (base %d)" % [GameState.carry_capacity(), Balance.data.hero.carry_capacity])
	bot.queue_free()

func test_fast_hero_still_arrives() -> void:
	for i in 5:
		GameState.debug_grant_card(&"move_speed")
	var bot := BotBase.new()
	main.add_child(bot)
	bot.setup(main)
	main.phase_controller.debug_skip_to_day()
	bot.go_to("sign")
	var ok := false
	for i in 60 * 30:
		await get_tree().physics_frame
		if bot.arrived():
			ok = true
			break
	assert_true(ok, "arrives at move_speed L5 without overshooting forever")
	assert_eq(bot.stuck_count, 0)
	bot.queue_free()
```

- [ ] **Step 2: Run them and see them fail.** Run `./run_tests.sh unit`. Expected: FAIL (the policies aren't there, and the planner stops at 6).

- [ ] **Step 3: Implement.**
- `actors/bots/bot_base.gd`, in `_steer()`: `var step := hero.move_speed() / float(Engine.physics_ticks_per_second)`.
- `tests/unit/helpers.gd`: `var step := hero.move_speed() / float(Engine.physics_ticks_per_second)`.
- `actors/bots/planner_bot.gd`: `var cap := GameState.carry_capacity()`. Also add:
```gdscript
## Card preference (D-168): the Tank first (its post is on a lane with one tower), then the Archer, then upgrades.
const CARD_PREFERENCE: Array[StringName] = [&"tank", &"archer", &"hero_damage", &"attack_speed",
	&"gold_per_steak", &"carry_capacity", &"move_speed"]

func choose_card(offer: Array) -> StringName:
	for id in CARD_PREFERENCE:
		if id in offer:
			return id
	return offer[0]
```
- `actors/bots/naive_bot.gd`:
```gdscript
## D-168: the Archer when offered (the strongest unaided pick, so the night-2 check is the worst case).
func choose_card(offer: Array) -> StringName:
	return &"archer" if &"archer" in offer else offer[0]
```
- `tests/sim/test_day_sims.gd`:
  - In `test_night2_naive_unaided_is_hard_and_deterministic`, add `assert_eq(int(r1.closeup.cards.get("archer", 0)), 1, "naive took the Archer")` and append `r1.closeup.cards` / `r2.closeup.cards` to the two compared arrays.
  - In `test_night2_planner_is_comfortable`, add `assert_eq(int(r.closeup.cards.get("tank", 0)), 1, "planner took the Tank")`.

- [ ] **Step 4: Run and see them pass.** Run `./run_tests.sh all`. Expected: exit 0. Guards don't exist yet, so the Archer and Tank picks don't change the night-2 numbers. Paste the sim lines into the report.

- [ ] **Step 5: Commit, then open the Phase 2 PR.**
```bash
git add actors/bots tests/unit/helpers.gd tests/unit/test_bots.gd tests/sim/test_day_sims.gd
git commit -m "feat(bots): card policies; bots use effective carry and move speed (Task S2-7)"
```

---

## Phase 3: Pick UI (`s2/p3-pick-ui`)

### Task 8: `CardPickOverlay`

**Files:**
- Create: `ui/card_pick/card_pick_overlay.gd`
- Modify: `tests/unit/test_glyphs.gd`
- Wiring note (D-139): in `world/main.gd` `_ready()`, add these lines right after `joystick.setup(hero.input)` and before the debug-overlay block:
  ```gdscript
  	# S2 (D-162): after InputLayer so its _input runs before the joystick's.
  	card_overlay = CardPickOverlay.new()
  	add_child(card_overlay)
  ```
  plus `var card_overlay: CardPickOverlay` next to `var hud: Hud`.
- Test: `tests/unit/test_card_pick_overlay.gd`

**Interfaces:**
- Consumes: `EventBus.card_offered`/`card_picked`/`state_restored`/`phase_changed`, `CardCatalog` text, `SafeArea.insets(vp)`, `Balance.ui.card_*`.
- Produces:
  - `CardPickOverlay` (node name `"CardPickOverlay"`, layer 15), with `offer: Array[StringName]`.
  - `panel_rects() -> Array[Rect2]`, `accepting() -> bool` and `static func layout(vp: Vector2, insets: Dictionary, n: int, ui: UiTuning) -> Array[Rect2]`.
  - It emits only `EventBus.card_chosen`.

- [ ] **Step 1: Write the failing tests.** `tests/unit/test_card_pick_overlay.gd`:
```gdscript
extends GutTest

var main: Main
var pc: PhaseController
var ov: CardPickOverlay

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	pc = main.phase_controller
	main.hero.input.player_control = false
	pc.start_new_game(99)
	ov = main.get_node("CardPickOverlay")

func _dawn() -> void:
	EventBus.wave_cleared.emit(2)

func _wait_guard() -> void:
	for i in int(ceil(Balance.ui.card_input_guard_s * Engine.physics_ticks_per_second)) + 2:
		await get_tree().physics_frame

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	main.get_viewport().push_input(e, true)

func _mouse(pos: Vector2, pressed: bool, device := 0) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.pressed = pressed
	e.device = device
	main.get_viewport().push_input(e, true)

func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	main.get_viewport().push_input(e, true)

func test_hidden_until_offer_then_panels_match() -> void:
	assert_false(ov.visible)
	_dawn()
	assert_true(ov.visible)
	assert_eq(ov.offer, GameState.card_offer)
	assert_eq(ov.panel_rects().size(), 3)

func test_tap_release_on_same_panel_picks() -> void:
	_dawn()
	await _wait_guard()
	var want: StringName = GameState.card_offer[1]
	var c := ov.panel_rects()[1].get_center()
	_touch(0, c, true)
	_touch(0, c, false)
	assert_eq(GameState.card_level(want), 1)
	assert_eq(pc.phase, Phase.DAY)
	assert_false(ov.visible)

func test_press_one_release_other_does_nothing() -> void:
	_dawn()
	await _wait_guard()
	_touch(0, ov.panel_rects()[0].get_center(), true)
	_touch(0, ov.panel_rects()[2].get_center(), false)
	assert_eq(pc.phase, Phase.DAWN)
	assert_eq(GameState.cards, {})

func test_input_guard_ignores_early_taps() -> void:
	_dawn()
	var c := ov.panel_rects()[0].get_center()
	_touch(0, c, true)
	_touch(0, c, false)
	assert_eq(pc.phase, Phase.DAWN, "tap inside the guard time is ignored")
	await _wait_guard()
	_touch(1, c, true)
	_touch(1, c, false)
	assert_eq(pc.phase, Phase.DAY)

func test_keys_pick_after_guard() -> void:
	_dawn()
	var want: StringName = GameState.card_offer[2]
	_key(KEY_3)
	assert_eq(pc.phase, Phase.DAWN)
	await _wait_guard()
	_key(KEY_3)
	assert_eq(GameState.card_level(want), 1)

func test_mouse_click_picks_and_emulated_mouse_is_ignored() -> void:
	_dawn()
	await _wait_guard()
	var c := ov.panel_rects()[0].get_center()
	_mouse(c, true, InputEvent.DEVICE_ID_EMULATION)
	_mouse(c, false, InputEvent.DEVICE_ID_EMULATION)
	assert_eq(pc.phase, Phase.DAWN)
	_mouse(c, true)
	_mouse(c, false)
	assert_eq(pc.phase, Phase.DAY)

func test_held_stick_release_over_panel_does_not_pick() -> void:
	_touch(0, Vector2(200, 700), true)
	await get_tree().physics_frame
	assert_true(main.joystick.is_active())
	_dawn()
	await _wait_guard()
	assert_false(main.joystick.is_active(), "the dawn block ended the stick")
	_touch(0, ov.panel_rects()[1].get_center(), false)
	assert_eq(pc.phase, Phase.DAWN)

func test_after_debug_skip_overlay_hides_and_press_reaches_joystick() -> void:
	_dawn()
	var c := ov.panel_rects()[0].get_center()
	pc.debug_skip_to_day()
	assert_false(ov.visible)
	_touch(0, c, true)
	assert_true(main.joystick.is_active())
	_touch(0, c, false)

func test_pause_then_resume_still_picks() -> void:
	_dawn()
	await _wait_guard()
	var c := ov.panel_rects()[0].get_center()
	_touch(0, c, true)
	ov.notification(Node.NOTIFICATION_PAUSED)
	_touch(0, c, false)
	assert_eq(pc.phase, Phase.DAWN, "the paused press no longer owns the finger")
	_touch(1, c, true)
	_touch(1, c, false)
	assert_eq(pc.phase, Phase.DAY)

func test_layout_fits_landscape_and_two_cards() -> void:
	var ui := Balance.ui
	var none := {"top": 0, "bottom": 0, "left": 0, "right": 0}
	for vp in [Vector2(720, 1280), Vector2(1280, 720), Vector2(720, 1560)]:
		for n in [1, 2, 3]:
			var rects := CardPickOverlay.layout(vp, none, n, ui)
			assert_eq(rects.size(), n)
			for i in n:
				assert_true(Rect2(Vector2.ZERO, vp).encloses(rects[i]), "%s n=%d panel %d on screen" % [vp, n, i])
				assert_gte(rects[i].size.y, ui.card_panel_min_h)
				if i > 0:
					assert_false(rects[i].intersects(rects[i - 1]), "no overlap")
	var notch := {"top": 90, "bottom": 60, "left": 0, "right": 0}
	var r := CardPickOverlay.layout(Vector2(720, 1280), notch, 3, ui)
	assert_gte(r[0].position.y, 90.0)
	assert_lte(r[2].end.y, 1280.0 - 60.0)
```

In `tests/unit/test_glyphs.gd`, change the sample to `const SAMPLE := "Quán ăn mở cửa — Đêm thứ 3 → 4"`.

- [ ] **Step 2: Run them and see them fail.** Run `./run_tests.sh unit`. Expected: FAIL; `CardPickOverlay` is not declared.
  - If `test_glyphs` fails on "→" once the rest passes, Nunito lacks U+2192. In that case, change `CardCatalog.level_text` to `"Lv %d > %d"`, revert the sample, update the Task 2 test pin, and report it.

- [ ] **Step 3: Implement.** `ui/card_pick/card_pick_overlay.gd`:
```gdscript
class_name CardPickOverlay
extends CanvasLayer
## Dawn card pick (S2 spec 5.4, D-162). Tap a card (press and release on the same panel) or press 1/2/3.
## Main adds it after InputLayer, so its _input runs before the joystick's; it consumes only presses it owns
## (the fade-button ownership pattern), ignores emulated mouse events and every press in the first
## card_input_guard_s, and hides outside DAWN.

var offer: Array[StringName] = []
var _root: Control
var _heading: Label
var _panels: Array[Control] = []
var _rects: Array[Rect2] = []
var _owned := {}
var _guard_left := 0.0

const HEADING_H := 70.0
const ADVENTURER_BAND := Color("f2c230")
const UPGRADE_BAND := Color("3cc6b8")

func _init() -> void:
	name = "CardPickOverlay"
	layer = 15

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_heading = _label(44, _root)
	_heading.text = tr("Pick a card")
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visible = false
	EventBus.card_offered.connect(show_offer)
	EventBus.card_picked.connect(_on_card_picked)
	EventBus.state_restored.connect(hide_overlay)
	EventBus.phase_changed.connect(_on_phase_changed)
	get_viewport().size_changed.connect(_relayout)

func show_offer(o: Array) -> void:
	if o.is_empty():
		return
	offer.assign(o)
	for p in _panels:
		p.queue_free()
	_panels.clear()
	for id in offer:
		_panels.append(_make_panel(id))
	_relayout()
	_owned.clear()
	_guard_left = Balance.ui.card_input_guard_s
	visible = true

func hide_overlay() -> void:
	visible = false
	_owned.clear()

func panel_rects() -> Array[Rect2]:
	return _rects

func accepting() -> bool:
	return visible and _guard_left <= 0.0

## Panel rects for n cards in a column centred in the safe area. Panels shrink (not below card_panel_min_h)
## so the heading, gaps and panels always fit; width is clamped to the safe width minus side margins.
static func layout(vp: Vector2, insets: Dictionary, n: int, ui: UiTuning) -> Array[Rect2]:
	var top := float(insets.top)
	var bottom := vp.y - float(insets.bottom)
	var left := float(insets.left)
	var right := vp.x - float(insets.right)
	var gap := ui.card_panel_gap
	var avail_h := bottom - top - HEADING_H - gap * float(n + 1)
	var h := clampf(avail_h / float(n), ui.card_panel_min_h, ui.card_panel_size.y)
	var w := minf(ui.card_panel_size.x, right - left - 2.0 * (ui.edge_ignore_px + gap))
	var total := HEADING_H + gap + h * float(n) + gap * float(n - 1)
	var y := top + maxf((bottom - top - total) * 0.5, 0.0) + HEADING_H + gap
	var x := left + (right - left - w) * 0.5
	var out: Array[Rect2] = []
	for i in n:
		out.append(Rect2(Vector2(x, y + float(i) * (h + gap)), Vector2(w, h)))
	return out

func _relayout() -> void:
	if offer.is_empty():
		return
	var vp := get_viewport().get_visible_rect().size
	_rects = CardPickOverlay.layout(vp, SafeArea.insets(vp), offer.size(), Balance.ui)
	for i in _panels.size():
		_panels[i].position = _rects[i].position
		_panels[i].size = _rects[i].size
	_heading.size = Vector2(vp.x, HEADING_H)
	_heading.position = Vector2(0, _rects[0].position.y - HEADING_H - Balance.ui.card_panel_gap)

func _make_panel(id: StringName) -> Control:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	style.set_corner_radius_all(20)
	style.border_color = ADVENTURER_BAND if CardCatalog.kind(id) == &"adventurer" else UPGRADE_BAND
	style.border_width_left = 16
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 36
	box.offset_top = 16
	box.offset_right = -20
	box.offset_bottom = -16
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	_label(40, box).text = CardCatalog.display_name(id)
	_label(28, box).text = CardCatalog.effect_text(id, Balance.data.cards)
	_label(26, box).text = CardCatalog.level_text(GameState.card_level(id))
	return panel

func _label(size: int, parent: Control) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _physics_process(delta: float) -> void:
	if visible and _guard_left > 0.0:
		_guard_left = maxf(_guard_left - delta, 0.0)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and accepting():
			var i := [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
			if i >= 0 and i < offer.size():
				get_viewport().set_input_as_handled()
				_choose(i)
		return
	var idx := -1
	var pressed := false
	if event is InputEventScreenTouch:
		idx = event.index
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
	else:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if pressed:
		_owned.erase(idx)
		var p := _panel_at(event.position)
		if p >= 0 and accepting():
			_owned[idx] = p
			get_viewport().set_input_as_handled()
	elif _owned.has(idx):
		var p: int = _owned[idx]
		_owned.erase(idx)
		get_viewport().set_input_as_handled()
		if _panel_at(event.position) == p and accepting():
			_choose(p)

func _panel_at(pos: Vector2) -> int:
	for i in _rects.size():
		if _rects[i].has_point(pos):
			return i
	return -1

func _choose(i: int) -> void:
	EventBus.card_chosen.emit(offer[i])

func _on_card_picked(_id: StringName, _level: int) -> void:
	hide_overlay()

func _on_phase_changed(phase: int, _day: int) -> void:
	if phase != Phase.DAWN:
		hide_overlay()

## D-147: a paused tree drops touch releases, so forget every owned finger.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_owned.clear()
```
Before running, apply the `world/main.gd` wiring above in your worktree; the main session re-applies it from your note.

- [ ] **Step 4: Run and see them pass.** Run `./run_tests.sh all`. Expected: exit 0.

- [ ] **Step 5: Commit** (without `world/main.gd`; its lines go in the wiring note, as `git diff world/main.gd > /tmp/lst-s2t8-wiring.patch`).
```bash
git add ui/card_pick tests/unit/test_card_pick_overlay.gd tests/unit/test_glyphs.gd
git commit -m "feat(ui): dawn card pick overlay with finger ownership and input guard (Task S2-8)"
```

### Task 9: HUD card strip, day label, debug URL scenes, and the simulator self-review

**Files:**
- Create: `ui/hud/card_strip.gd`, `ui/debug/debug_scenes.gd`
- Modify: `ui/hud/hud.gd`, `ui/debug/debug_overlay.gd`
- Test: `tests/unit/test_hud.gd`, `tests/unit/test_debug_scenes.gd`

**Interfaces:**
- Consumes: `CardCatalog.IDS`/`GLYPHS`, `GameState.card_level`, `GameState.debug_grant_card`, `EventBus.card_offered`.
- Produces:
  - `CardStrip` (a Label, `refresh()`).
  - `Hud.card_strip`.
  - `DebugScenes.parse(query: String) -> Dictionary` and `DebugScenes.apply(main, q: Dictionary)`. The script is loaded, not a `class_name`, because it lives in `ui/debug`. The URL `?cards=archer:1,tank:2&scene=cardpick` grants the cards, then jumps to the dawn pick. This is the reusable simulator-review hook for S2–S5.

- [ ] **Step 1: Write the failing tests.**

Append to `tests/unit/test_hud.gd`, using its fixture (`main`, `hud`):
```gdscript
func test_card_strip_lists_owned_cards_in_catalog_order() -> void:
	assert_eq(main.hud.card_strip.text, "")
	GameState.debug_grant_card(&"tank")
	GameState.debug_grant_card(&"hero_damage")
	GameState.debug_grant_card(&"tank")
	assert_eq(main.hud.card_strip.text, "DM1  TK2")
	GameState.new_game(2)
	assert_eq(main.hud.card_strip.text, "")

func test_day_label_shows_new_day_on_offer() -> void:
	EventBus.wave_cleared.emit(2)
	assert_eq(main.hud.day_label.text, "Day 2")
```

`tests/unit/test_debug_scenes.gd`:
```gdscript
extends GutTest

var DS = load("res://ui/debug/debug_scenes.gd")
var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(99)

func test_parse() -> void:
	assert_eq(DS.parse("?cards=archer:1,tank:2&scene=cardpick"),
		{"cards": {&"archer": 1, &"tank": 2}, "scene": "cardpick"})
	assert_eq(DS.parse(""), {"cards": {}, "scene": ""})
	assert_eq(DS.parse("?cards=bogus:3,tank:x"), {"cards": {}, "scene": ""}, "unknown ids and bad levels are dropped")

func test_apply_grants_cards_and_opens_pick() -> void:
	DS.apply(main, DS.parse("?cards=tank:2,move_speed:1&scene=cardpick"))
	assert_eq(GameState.card_level(&"tank"), 2)
	assert_eq(GameState.card_level(&"move_speed"), 1)
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK")
```

- [ ] **Step 2: Run them and see them fail.** Run `./run_tests.sh unit`. Expected: FAIL.

- [ ] **Step 3: Implement.**

`ui/hud/card_strip.gd`:
```gdscript
class_name CardStrip
extends Label
## Owned hero cards under the gold label (S2 spec 5.5): "DM1  TK2" in CardCatalog.IDS order. Listener only.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 28)
	add_theme_constant_override("outline_size", 6)
	add_theme_color_override("font_outline_color", Color.BLACK)
	EventBus.card_picked.connect(func(_id: StringName, _level: int): refresh())
	EventBus.state_restored.connect(refresh)
	refresh()

func refresh() -> void:
	var parts: Array[String] = []
	for id in CardCatalog.IDS:
		var l := GameState.card_level(id)
		if l > 0:
			parts.append("%s%d" % [CardCatalog.GLYPHS[id], l])
	text = "  ".join(parts)
```

`ui/hud/hud.gd`:
- Add `var card_strip: CardStrip`.
- In `_ready()`, after `gold_label` is created:
```gdscript
	card_strip = CardStrip.new()
	card_strip.position = Vector2(24, 84)
	root.add_child(card_strip)
```
- Also connect `EventBus.card_offered.connect(_on_card_offered)`, and add:
```gdscript
## phase_changed(DAWN) carries the old day; the offer comes after advance_day (S2 spec 5.1).
func _on_card_offered(_offer: Array) -> void:
	day_label.text = tr("Day %d") % GameState.day
```
- In `_arrow_rect()`, include the strip:
  `var hud_bottom := maxf(maxf(_top_column.get_global_rect().end.y, gold_label.get_global_rect().end.y), card_strip.get_global_rect().end.y)`.

`ui/debug/debug_scenes.gd`:
```gdscript
extends RefCounted
## Debug-build URL scenes for simulator self-reviews (D-159). Loaded, never preloaded from release code.
## ?cards=archer:1,tank:2 grants cards; &scene=cardpick jumps to the dawn pick.

static func parse(query: String) -> Dictionary:
	var out := {"cards": {}, "scene": ""}
	for pair in query.trim_prefix("?").split("&", false):
		var kv := pair.split("=", true, 1)
		if kv.size() != 2:
			continue
		if kv[0] == "scene":
			out.scene = kv[1]
		elif kv[0] == "cards":
			for item in kv[1].split(",", false):
				var il := item.split(":", true, 1)
				if il.size() == 2 and StringName(il[0]) in CardCatalog.IDS and il[1].is_valid_int():
					out.cards[StringName(il[0])] = int(il[1])
	return out

static func apply(main, q: Dictionary) -> void:
	for id in CardCatalog.IDS:
		for i in int(q.cards.get(id, 0)):
			GameState.debug_grant_card(id)
	if q.scene == "cardpick" and main.phase_controller.phase == Phase.NIGHT:
		EventBus.wave_cleared.emit(GameState.lane_plan.size() - 1)
```

`ui/debug/debug_overlay.gd`:
- Add `var _scene_query := {}`.
- At the end of `setup()`:
```gdscript
	if OS.has_feature("web"):
		_scene_query = load("res://ui/debug/debug_scenes.gd").parse(str(JavaScriptBridge.eval("window.location.search", true)))
		EventBus.phase_changed.connect(_on_first_phase, CONNECT_ONE_SHOT)
```
- New methods:
```gdscript
## The URL scene waits for the game's first NIGHT (Main starts it deferred) and then runs deferred, so it never
## re-enters PhaseController while _enter_night is still emitting phase_changed.
func _on_first_phase(_phase: int, _day: int) -> void:
	_apply_scene.call_deferred()

func _apply_scene() -> void:
	load("res://ui/debug/debug_scenes.gd").apply(_main, _scene_query)
```

- [ ] **Step 4: Run and see them pass.** Run `./run_tests.sh all`. Expected: exit 0.

- [ ] **Step 5: Simulator self-review (D-159).** The main session pushes the phase branch. Then:
  - `WAIT_S=25 export/device_check.sh "https://khanhnguyendev.github.io/last-stand-tycoon/preview/s2-p3-pick-ui/debug/?scene=cardpick" <scratch>/pick_ios`
  - the same with `?cards=tank:2,hero_damage:1&scene=cardpick`
  - `node export/pw_check.mjs "<same url>" <scratch>/pick_android.png android`

  Read each screenshot and check:
  - all panels are inside the safe area, with nothing under the notch or home indicator;
  - the text is readable and unclipped, "→" renders, and the level lines read "NEW" / "Lv 2 → 3";
  - the strip reads "DM1  TK2" under the gold;
  - the heading doesn't collide with the top HUD.

  Report each item as pass or fail, with the screenshot paths.

- [ ] **Step 6: Commit, then open the Phase 3 PR.**
```bash
git add ui/hud ui/debug tests/unit/test_hud.gd tests/unit/test_debug_scenes.gd
git commit -m "feat(ui): HUD card strip, day label on offer, debug URL scenes for simulator reviews (Task S2-9)"
```

---

## Phase 4: Guards (`s2/p4-guards`)

### Task 10: Guard posts and geometry guarantees

**Files:**
- Modify: `core/map_layout.gd`, `world/visuals.gd` (adds the colors `archer` 2f9e44 and `tank` 5c4b8a to `COLORS`)
- Test: `tests/unit/test_geometry.gd`

**Interfaces:**
- Produces:
  - `MapLayout.GUARD_POST_ARCHER := Vector2(2.5, -2.5)`, `MapLayout.DINER_DOOR := Vector2(-3.0, 4.6)`, `MapLayout.TANK_POST_BACK := 3.0`.
  - `MapLayout.guard_post(id: StringName) -> Vector2` and `MapLayout.tank_return_path() -> Array`, which is `[DINER_DOOR, Vector2(-5.0, 4.6), guard_post(&"tank")]`.
  - `Visuals.COLORS.archer` and `Visuals.COLORS.tank`.

- [ ] **Step 1: Write the failing tests.** Append to `tests/unit/test_geometry.gd`:
```gdscript
func _offsets() -> Array:
	var s := Balance.data.enemy.lateral_spread
	return [-s, -s * 0.5, 0.0, s * 0.5, s]

func test_tank_post_on_west_lane() -> void:
	var p := MapLayout.guard_post(&"tank")
	assert_almost_eq(p.x, -6.599, 0.01)
	assert_almost_eq(p.y, -2.654, 0.01)

func test_every_west_boar_comes_within_reach_of_the_tank() -> void:
	var post := MapLayout.guard_post(&"tank")
	var r := Balance.data.enemy.reach + Balance.data.guards.tank.body_radius
	var fade := Balance.data.enemy.offset_fade_distance
	var length := MapLayout.path_length("west")
	for off in _offsets():
		var best := INF
		var d := 0.0
		while d <= length:
			best = minf(best, EnemyPath.position_at("west", d, off, fade).distance_to(post))
			d += 0.05
		assert_lte(best, r, "offset %.2f closest %.3f" % [off, best])

func test_tank_is_behind_the_fence_stop_and_hits_fence_held_boars() -> void:
	var post := MapLayout.guard_post(&"tank")
	var t := Balance.data.guards.tank
	var reach := Balance.data.enemy.reach
	var stop := MapLayout.path_length("west") - MapLayout.FENCE_OFFSET_FROM_END - reach
	for off in _offsets():
		var q := EnemyPath.position_at("west", stop, off, Balance.data.enemy.offset_fade_distance)
		var dd := q.distance_to(post)
		assert_gt(dd, reach + t.body_radius, "a boar at the fence does not target the tank (offset %.2f)" % off)
		assert_lte(dd, t.attack_range, "the tank reaches a fence-held boar (offset %.2f, %.3f m)" % [off, dd])

func test_tank_range_covers_its_attackers() -> void:
	var t := Balance.data.guards.tank
	assert_gte(t.attack_range, Balance.data.enemy.reach + t.body_radius)

func test_archer_covers_lane_ends_and_north_east_fence_stops() -> void:
	var a := MapLayout.guard_post(&"archer")
	var rng := Balance.data.guards.archer.attack_range
	var fade := Balance.data.enemy.offset_fade_distance
	for lane in ["west", "north", "east"]:
		for off in _offsets():
			var e := EnemyPath.position_at(lane, MapLayout.path_length(lane), off, fade)
			assert_lte(e.distance_to(a), rng, "%s end offset %.2f" % [lane, off])
	for lane in ["north", "east"]:
		var stop := MapLayout.path_length(lane) - MapLayout.FENCE_OFFSET_FROM_END - Balance.data.enemy.reach
		for off in _offsets():
			assert_lte(EnemyPath.position_at(lane, stop, off, fade).distance_to(a), rng, "%s fence stop" % lane)

func test_tank_return_path_is_clear() -> void:
	var path := MapLayout.tank_return_path()
	assert_eq(path[0], MapLayout.DINER_DOOR)
	assert_eq(path[path.size() - 1], MapLayout.guard_post(&"tank"))
	var r := Balance.data.guards.tank.body_radius
	var box := Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2.0, MapLayout.DINER_HALF * 2.0)
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var n := int(ceil(a.distance_to(b) / 0.05))
		for k in n + 1:
			var p := a.lerp(b, float(k) / float(n))
			assert_gte(Geometry.dist_point_rect(p, box), r - 1e-4, "segment %d clears the diner" % i)
			for t in MapLayout.TOWER_SPOTS.values():
				assert_gte(p.distance_to(t), MapLayout.TOWER_VISUAL_RADIUS + r, "segment %d clears a tower" % i)
```

- [ ] **Step 2: Run them and see them fail.** Run `./run_tests.sh unit`. Expected: FAIL; `guard_post` is unknown.

- [ ] **Step 3: Implement.** Add to `core/map_layout.gd`, after `BUILD_RADIUS`:
```gdscript
## S2 guard posts (D-163): the Archer on the diner roof; the Tank on the west lane's center line,
## TANK_POST_BACK m before the lane end. A knocked-out guard respawns at DINER_DOOR (D-165).
const GUARD_POST_ARCHER := Vector2(2.5, -2.5)
const DINER_DOOR := Vector2(-3.0, 4.6)
const TANK_POST_BACK := 3.0

static func guard_post(id: StringName) -> Vector2:
	if id == &"archer":
		return GUARD_POST_ARCHER
	return Geometry.point_back_from_end(LANE_PATHS["west"], TANK_POST_BACK)

## Door -> south-west corner (outside the diner) -> Tank post; test_geometry proves it clears the diner and towers.
static func tank_return_path() -> Array:
	return [DINER_DOOR, Vector2(-5.0, 4.6), guard_post(&"tank")]
```
Add `"archer": Color("2f9e44"), "tank": Color("5c4b8a"),` to `Visuals.COLORS` in `world/visuals.gd`.

- [ ] **Step 4: Run and see them pass.** Run `./run_tests.sh unit`. Expected: exit 0.

- [ ] **Step 5: Commit.**
```bash
git add core/map_layout.gd world/visuals.gd tests/unit/test_geometry.gd
git commit -m "feat(map): guard posts, diner door and the Tank return path with geometry guarantees (Task S2-10)"
```

### Task 11: Guards, roster, the guard target and the Boar arm

**Files:**
- Create: `actors/guards/guard.gd`, `world/guard_roster.gd`
- Modify: `actors/enemy/boar.gd`, `world/target_providers.gd` (the comment on line 4)
- Wiring note (D-139) for `world/world.gd`:
  - Add `var guard_roster: GuardRoster` to the fields.
  - At the end of `_ready()`:
    ```gdscript
    	guard_roster = GuardRoster.new()
    	guard_roster.name = "GuardRoster"
    	add_child(guard_roster)
    	guard_roster.setup(self)
    ```
  - In `_occluder_targets()`, before `return out`:
    ```gdscript
    	if guard_roster != null:
    		out.append_array(guard_roster.occluder_points())
    ```
- Test: `tests/unit/test_guards.gd`, `tests/unit/test_boar.gd`

**Interfaces:**
- Consumes: `MapLayout.guard_post`/`tank_return_path`/`DINER_DOOR`, `CardEffects.guard_stats`, `GameState.guards`/`card_level`/`revive_guard`/`damage_guard`, `WaveDirector.providers`/`enemy_candidates`, `World.projectile_pool`.
- Produces:
  - `GuardRoster.guards: Dictionary` (id → Guard), `guard_target(enemy) -> Dictionary`, `occluder_points() -> Array`.
  - `Guard.State {POSTED, DOWN, RETURNING}`, `Guard.state`, `Guard.stats`, `Guard.attacker`, `Guard.xz()`, `Guard.is_targetable()`.
  - Target dictionaries of the form `{"kind": &"guard", "guard_id": StringName}`.

- [ ] **Step 1: Write the failing tests.** `tests/unit/test_guards.gd`:
```gdscript
extends GutTest

var main: Main
var pc: PhaseController
var roster: GuardRoster

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	pc = main.phase_controller
	main.hero.input.player_control = false
	pc.start_new_game(99)
	main.world.wave_director.stop()  # test setup: no scheduled waves; boars come from debug_spawn
	main.hero.teleport(Vector2(15, 8))  # hero out of every fight
	roster = main.world.guard_roster

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_hire_spawns_guards_at_posts() -> void:
	GameState.debug_grant_card(&"archer")
	var a: Guard = roster.guards[&"archer"]
	assert_eq(a.xz(), MapLayout.guard_post(&"archer"))
	assert_almost_eq(a.global_position.y, MapLayout.DINER_HEIGHT, 1e-4)
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	assert_eq(t.state, Guard.State.RETURNING, "a new Tank walks in from the door")
	await _ticks(60 * 8)
	assert_eq(t.state, Guard.State.POSTED)
	assert_eq(t.xz(), MapLayout.guard_post(&"tank"))

func test_upgrade_card_spawns_no_guard() -> void:
	GameState.debug_grant_card(&"move_speed")
	assert_eq(roster.guards.size(), 0)

func test_archer_is_never_targeted() -> void:
	GameState.debug_grant_card(&"archer")
	for lane in ["west", "north", "east"]:
		var b: Boar = main.world.wave_director.debug_spawn(lane)
		b.dist = b.path_length()
		b._update_position()
		assert_eq(roster.guard_target(b), {}, lane)

func test_archer_kills_a_north_boar() -> void:
	GameState.debug_grant_card(&"archer")
	var b: Boar = main.world.wave_director.debug_spawn("north")
	var killed := false
	for i in 60 * 20:
		await get_tree().physics_frame
		if not b.alive:
			killed = true
			break
	assert_true(killed, "the roof archer kills a north boar")

func test_tank_stops_a_west_boar_and_takes_damage() -> void:
	GameState.debug_grant_card(&"tank")
	await _ticks(60 * 8)
	var b: Boar = main.world.wave_director.debug_spawn("west")
	var engaged := false
	for i in 60 * 25:
		await get_tree().physics_frame
		if not b.alive:
			break
		if b.current_target.get("kind", &"") == &"guard":
			engaged = true
	assert_true(engaged, "the boar targeted the tank")
	assert_lt(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"), "the tank took hits")
	assert_lt(b.dist, b.path_length() - 1.0, "the boar never reached the diner")

func test_knockout_respawn_at_door_then_return() -> void:
	GameState.debug_grant_card(&"tank")
	await _ticks(60 * 8)
	var t: Guard = roster.guards[&"tank"]
	GameState.damage_guard(&"tank", 1e6)
	assert_eq(t.state, Guard.State.DOWN)
	assert_false(t.is_targetable())
	var b: Boar = main.world.wave_director.debug_spawn("west")
	b.dist = MapLayout.path_length("west") - MapLayout.TANK_POST_BACK - 1.0
	b._update_position()
	assert_eq(roster.guard_target(b), {}, "a downed tank is not a target")
	await _ticks(int(ceil(Balance.data.guards.tank.respawn_s * 60.0)) + 2)
	assert_eq(t.state, Guard.State.RETURNING)
	assert_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"))
	assert_lt(t.xz().distance_to(MapLayout.DINER_DOOR), 0.2, "respawns at the door")
	await _ticks(60 * 8)
	assert_eq(t.state, Guard.State.POSTED)

func test_dawn_restores_a_downed_tank() -> void:
	GameState.debug_grant_card(&"tank")
	GameState.damage_guard(&"tank", 1e6)
	EventBus.wave_cleared.emit(2)  # dawn
	var t: Guard = roster.guards[&"tank"]
	assert_eq(t.state, Guard.State.POSTED)
	assert_eq(t.xz(), MapLayout.guard_post(&"tank"))
	assert_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"))
	await _ticks(int(ceil(Balance.data.guards.tank.respawn_s * 60.0)) + 2)
	assert_eq(t.state, Guard.State.POSTED, "no respawn timer carried into the day")

func test_level_up_reconfigures() -> void:
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	assert_almost_eq(t.attacker.damage, 5.0, 1e-5)
	GameState.debug_grant_card(&"tank")
	assert_almost_eq(t.attacker.damage, 5.0 * 1.25, 1e-5)
	assert_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"))
	assert_eq(roster.guards.size(), 1, "a duplicate levels up; no second tank")

func test_occluder_points_include_visible_guards() -> void:
	GameState.debug_grant_card(&"archer")
	assert_eq(roster.occluder_points().size(), 1)
```

Append to `tests/unit/test_boar.gd`, using its fixture (it has `main` or a `WaveDirector`; adapt the names to the fixture):
```gdscript
func test_priority_fence_then_guard_then_diner() -> void:
	assert_eq(Array(Balance.data.wave.target_priority.kinds), [&"fence_on_lane", &"guard", &"diner"])
	GameState.debug_grant_card(&"tank")
	main.world.guard_roster.guards[&"tank"].place_at_post()  # skip the walk in from the door
	GameState.add_gold(GameState.next_level_cost("fence_w"))
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	var b: Boar = main.world.wave_director.debug_spawn("west")
	b.dist = TargetProviders.fence_stop_dist(b)
	b._update_position()
	assert_eq(main.world.wave_director.providers.find_target(b).kind, &"fence_on_lane")
	GameState.damage_fence("fence_w", 1e6)
	b.dist = b.path_length() - MapLayout.TANK_POST_BACK - 1.0
	b._update_position()
	assert_eq(main.world.wave_director.providers.find_target(b).kind, &"guard")
	GameState.damage_guard(&"tank", 1e6)
	b.dist = b.path_length()
	b._update_position()
	assert_eq(main.world.wave_director.providers.find_target(b).kind, &"diner")
```

- [ ] **Step 2: Run them and see them fail.** Run `./run_tests.sh unit`. Expected: FAIL; `GuardRoster` is not declared.

- [ ] **Step 3: Implement.**

`actors/guards/guard.gd`:
```gdscript
class_name Guard
extends Node3D
## An adventurer guard at its fixed post (S2 spec 6, D-163 to D-165). HP lives in GameState.guards (Tank only).
## No physics body: the hero walks through guards (as towers, D-125).

enum State { POSTED, DOWN, RETURNING }

## Height above the feet the camera aims at when checking occlusion (D-151).
const AIM_HEIGHT := 1.0
const BAR_WIDTH := 1.0

var id: StringName
var state := State.POSTED
var stats: Dictionary = {}
var attacker: Attacker
var visual: Node3D
var _bar: MeshInstance3D
var _respawn_left := 0.0
var _path: Array = []

func setup(p_id: StringName, world: World) -> void:
	id = p_id
	name = "Guard_%s" % p_id
	visual = Visuals.visual_root()
	var body := Visuals.capsule(0.4, 1.4, Visuals.COLORS[String(p_id)])
	body.position.y = 0.7
	visual.add_child(body)
	add_child(visual)
	_bar = Visuals.box(Vector3(BAR_WIDTH, 0.08, 0.08), Visuals.COLORS.diner_hp)
	_bar.position.y = 1.8
	_bar.visible = false
	add_child(_bar)
	attacker = Attacker.new()
	attacker.position.y = 1.0
	attacker.candidates = world.wave_director.enemy_candidates
	attacker.projectile_pool = world.projectile_pool
	add_child(attacker)
	EventBus.card_picked.connect(_on_card_picked)
	EventBus.guard_damaged.connect(_on_guard_hp)
	EventBus.guard_healed.connect(_on_guard_hp)
	EventBus.guard_revived.connect(_on_guard_revived)
	EventBus.guard_knocked_out.connect(_on_knocked_out)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.state_restored.connect(_on_state_restored)
	apply_stats()
	place_at_post()

func apply_stats() -> void:
	stats = CardEffects.guard_stats(id, maxi(GameState.card_level(id), 1), Balance.data.guards)
	attacker.configure(stats.damage, stats.range, stats.interval, Balance.data.hero.retarget_interval, 1.0,
		stats.projectile_speed)
	_refresh_bar()

func xz() -> Vector2:
	return Vector2(global_position.x, global_position.z)

func is_targetable() -> bool:
	return bool(stats.targetable) and state != State.DOWN and GameState.guards.has(id) \
		and float(GameState.guards[id].hp) > 0.0

func place_at_post() -> void:
	state = State.POSTED
	_respawn_left = 0.0
	_path = []
	visual.visible = true
	attacker.enabled = true
	position = MapLayout.to3(MapLayout.guard_post(id), MapLayout.DINER_HEIGHT if bool(stats.on_roof) else 0.0)
	_refresh_bar()

## Appear at the diner door and walk the fixed path to the post (hire and respawn, D-165).
func arrive_from_door() -> void:
	_path = MapLayout.tank_return_path()
	position = MapLayout.to3(_path.pop_front())
	state = State.RETURNING
	visual.visible = true
	attacker.enabled = true
	_refresh_bar()

func _physics_process(delta: float) -> void:
	match state:
		State.DOWN:
			_respawn_left -= delta
			if _respawn_left <= 1e-6:
				GameState.revive_guard(id)
				arrive_from_door()
		State.RETURNING:
			_walk(delta)

func _walk(delta: float) -> void:
	var step := float(stats.walk_speed) * delta
	while step > 0.0 and not _path.is_empty():
		var target: Vector2 = _path[0]
		var d := target - xz()
		if d.length() <= step:
			position = MapLayout.to3(target)
			step -= d.length()
			_path.pop_front()
		else:
			position = MapLayout.to3(xz() + d.normalized() * step)
			step = 0.0
	if _path.is_empty():
		state = State.POSTED

func _on_knocked_out(g: StringName) -> void:
	if g != id:
		return
	state = State.DOWN
	_respawn_left = float(stats.respawn_s)
	attacker.enabled = false
	visual.visible = false
	_bar.visible = false

func _on_card_picked(c: StringName, _level: int) -> void:
	if c == id:
		apply_stats()

func _on_guard_hp(g: StringName, _hp: float) -> void:
	if g == id:
		_refresh_bar()

func _on_guard_revived(g: StringName) -> void:
	if g == id:
		_refresh_bar()

func _on_phase_changed(phase: int, _day: int) -> void:
	if phase == Phase.DAWN:
		place_at_post()

func _on_state_restored() -> void:
	apply_stats()
	place_at_post()

func _refresh_bar() -> void:
	if not GameState.guards.has(id) or state == State.DOWN:
		_bar.visible = false
		return
	var mx := GameState.guard_max_hp(id)
	var hp := float(GameState.guards[id].hp)
	_bar.visible = mx > 0.0 and hp < mx - 1e-6
	_bar.scale.x = clampf(hp / mx, 0.0, 1.0) if mx > 0.0 else 0.0
```

`world/guard_roster.gd`:
```gdscript
class_name GuardRoster
extends Node3D
## Spawns guards from GameState card levels and registers the &"guard" target kind (S2 spec 6.3, 7, D-164).

var guards := {}
var _world: World

func setup(world: World) -> void:
	_world = world
	world.wave_director.providers.register(&"guard", guard_target)
	EventBus.card_picked.connect(_on_card_picked)
	EventBus.state_restored.connect(sync)
	sync()

## Match guards to GameState (restore, new game).
func sync() -> void:
	for id in CardCatalog.ADVENTURERS:
		var lvl := GameState.card_level(id)
		if lvl >= 1 and not guards.has(id):
			_spawn(id)
		elif lvl < 1 and guards.has(id):
			var g: Guard = guards[id]
			guards.erase(id)
			remove_child(g)
			g.queue_free()

func _on_card_picked(id: StringName, _level: int) -> void:
	if CardCatalog.kind(id) != &"adventurer" or guards.has(id):
		return
	var g := _spawn(id)
	if not bool(g.stats.on_roof):
		g.arrive_from_door()

func _spawn(id: StringName) -> Guard:
	var g := Guard.new()
	add_child(g)
	g.setup(id, _world)
	guards[id] = g
	return g

## First targetable guard (CardCatalog.IDS order) within the enemy's reach + the guard's body radius (xz).
func guard_target(enemy) -> Dictionary:
	var reach := Balance.data.enemy.reach
	var p := Vector2(enemy.global_position.x, enemy.global_position.z)
	for id in CardCatalog.IDS:
		if not guards.has(id):
			continue
		var g: Guard = guards[id]
		if g.is_targetable() and p.distance_to(g.xz()) <= reach + float(g.stats.body_radius) + 1e-4:
			return {"kind": &"guard", "guard_id": id}
	return {}

## Aim points of visible guards, so the diner fades when it hides one (D-151).
func occluder_points() -> Array:
	var out: Array = []
	for id in guards:
		var g: Guard = guards[id]
		if g.visual.visible:
			out.append(g.global_position + Vector3(0, Guard.AIM_HEIGHT, 0))
	return out
```

`actors/enemy/boar.gd`: add this arm to the `match current_target.kind:` block:
```gdscript
			&"guard":
				GameState.damage_guard(current_target.guard_id, eb.damage)
```

`world/target_providers.gd` line 4 becomes `## S2 registers &"guard" here (GuardRoster); Boar gained one match arm for it (S2 spec 7).`

Apply the `world/world.gd` wiring above in your worktree to run the tests. The main session re-applies it from your note (`git diff world/world.gd > /tmp/lst-s2t11-wiring.patch`).

- [ ] **Step 4: Run and see them pass.** Run `./run_tests.sh all`. Expected: exit 0 for unit.
  - **If a sim threshold fails**, it will most likely be night 2 NaiveBot, now with a working Archer, going above 0.30. Apply D-169 in order: lower `GuardBalance._archer()` `damage` in 1.0 steps, down to a floor of 3.0. Re-run the sims after each step, and report every step's numbers.
  - If the threshold still fails at the floor, relax nothing and stop: escalate to the main session with the numbers.
  - Night 2 PlannerBot (with the Tank) must stay ≥ 0.60.

- [ ] **Step 5: Commit** (without `world/world.gd`, which goes in the wiring note).
```bash
git add actors/guards world/guard_roster.gd actors/enemy/boar.gd world/target_providers.gd balance/guard_balance.gd tests/unit/test_guards.gd tests/unit/test_boar.gd
git commit -m "feat(guards): Archer and Tank at their posts, guard targeting, knockout and respawn (Task S2-11)"
```

### Task 12: Restore contract with cards and guards

**Files:**
- Test: `tests/unit/test_restore_world.gd`
- Modify: only what the tests show missing. By design everything is covered by the `state_restored` handlers in Tasks 6, 8, 9 and 11.

**Interfaces:**
- Consumes: everything above.
- Produces: the S1 restore contract (S1 spec §4.2), extended to guards, the overlay, hero input and hero stats.

- [ ] **Step 1: Write the tests.** Append to `tests/unit/test_restore_world.gd`, using its fixture (`main`, `pc`) and its fail-tick helper. If it has none, copy `_fail_ticks()` from `test_phase_controller.gd`.
```gdscript
func test_restore_brings_back_cards_and_guards() -> void:
	EventBus.wave_cleared.emit(2)
	EventBus.card_chosen.emit(&"tank")
	GameState.debug_grant_card(&"hero_damage")
	pc.close_up()  # snapshot: tank 1, hero_damage 1
	await get_tree().physics_frame
	GameState.damage_guard(&"tank", 1e6)  # knocked out at night
	GameState.damage_diner(1e6)
	await _ticks(_fail_ticks())
	assert_eq(pc.phase, Phase.DAY)
	var t: Guard = main.world.guard_roster.guards[&"tank"]
	assert_eq(t.state, Guard.State.POSTED)
	assert_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"))
	assert_almost_eq(main.hero.attacker.damage, Balance.data.hero.attack_damage * 1.2, 1e-5)
	assert_false(main.hero.input.blocked)
	assert_false(main.card_overlay.visible)

func test_new_game_removes_guards() -> void:
	GameState.debug_grant_card(&"archer")
	GameState.debug_grant_card(&"tank")
	pc.start_new_game(5)
	await get_tree().process_frame
	assert_eq(main.world.guard_roster.guards.size(), 0)
	assert_eq(main.hud.card_strip.text, "")
```

- [ ] **Step 2: Run them.** Run `./run_tests.sh all`.
  - If they pass, the contract holds; say so in the report.
  - If one fails, fix only the handler it names, in the owning file, and re-run.

- [ ] **Step 3: Simulator self-review (D-159).** Once the phase branch is pushed:
  - run `WAIT_S=30 export/device_check.sh "<preview>/debug/?cards=archer:1,tank:1" <scratch>/guards_ios`;
  - check that the Archer is visible on the roof, the Tank at the west-lane post, the HP bar hidden at full HP, and the diner fade still readable.

  Report pass or fail, with the paths.

- [ ] **Step 4: Commit, then open the Phase 4 PR.**
```bash
git add tests/unit/test_restore_world.gd
git commit -m "test(restore): cards, guards, hero stats and overlay survive a fail restore (Task S2-12)"
```

---

## Phase 5: Tuning and results (`s2/p5-tuning`)

### Task 13: Sweep columns for cards and guards

**Files:**
- Modify: `tests/sim/sweep_runner.gd`

**Interfaces:**
- Produces:
  - Sweep CSV columns: `...,unspent_gold_at_closeup,cards,guard_knockouts,picked`, over 14 days by default.
  - The final line is `SWEEP broke_at_day=N target=10±1`.

- [ ] **Step 1: Implement.**
  - Default `"days": "14"`.
  - Connect `EventBus.card_picked` to count `_picked = "%s" % id` (the day's pick), and `EventBus.guard_knocked_out` to `_knockouts += 1`. Reset both before each night.
  - Extend the header and both row formats:
    - the failure row gets the 3 new fields, with `cards` from `_cards()`, `guard_knockouts` from `_knockouts` and `picked` empty;
    - the full row appends `,%s,%d,%s` % `[_cards(), _knockouts, _picked]`.
  - Add:
```gdscript
func _cards() -> String:
	var parts: Array = []
	for id in CardCatalog.IDS:
		if GameState.card_level(id) > 0:
			parts.append("%s:%d" % [id, GameState.card_level(id)])
	return "|".join(parts)
```
  - Replace the last print with `print("SWEEP broke_at_day=%d target=%d±%d" % [broke_at, Balance.data.sim.break_day_target, Balance.data.sim.break_day_tolerance])`.
  - Disconnect both new signals next to `_on_sold`.

- [ ] **Step 2: Run it.** Run `"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/sweep.gd`. Paste the CSV and the SWEEP line into the report. This is the S2 baseline, before any tuning.

- [ ] **Step 3: Commit.**
```bash
git add tests/sim/sweep_runner.gd
git commit -m "chore(sweep): card, knockout and pick columns; 14 days; break-day target line (Task S2-13)"
```

### Task 14: S2 tuning pass (D-169)

Main purpose: `balance/*`.

**Files:**
- Modify: `balance/*.gd` defaults only
- Modify: the pinned-reference tests that pin a changed value (`test_balance`, `test_wave_math`, `test_economy`, `test_card_effects`, `test_geometry` for Archer range)

**Rules:** Change only Balance defaults: no code or geometry. Targets, in precedence order:
1. Night 1 NaiveBot ≥ 0.50.
2. Night 2 PlannerBot (Tank) ≥ 0.60.
3. The sweep breaks at day 10 ± 1, with unspent gold at close-up under 40 through day 5.
4. Night 2 NaiveBot (Archer) ≤ 0.30. It may relax to ≤ 0.45, and any relaxation is logged.

Knobs:
- For target 4: Archer L1 `damage`, then `attack_range` (floor 8.65, per the §6.1 geometry test).
- For target 3: `count_growth` / `hp_growth`, then Tank stats, then card steps, then `side_share_*`.

Each round is one knob change, then `./run_tests.sh sim` and the sweep. **Stop and escalate** with the CSV after 3 rounds without progress, or on any conflict: 1 vs 2; 3 vs 1 or 2; or 4 (even at ≤ 0.45) vs 3.

- [ ] **Step 1: Baseline.** Use the sweep from Task 13, plus `./run_tests.sh sim`.
- [ ] **Step 2: Iterate** by the rules above. Record every round: knob, old → new, the four targets, and the unspent gold on days 1–5.
- [ ] **Step 3: Update the pins** for any changed value in the same commit.
- [ ] **Step 4: Run** `./run_tests.sh all`. Expected: exit 0.
- [ ] **Step 5: Commit.**
```bash
git add balance tests
git commit -m "chore(balance): S2 tuning pass for a day-10 break with cards (Task S2-14)"
```
The main session logs the result as the next D-id ("S2 tuning pass"). It lists every change with old → new values, the final sims, the break day and any relaxation. It also updates REVIEW_QUEUE if a player-facing value moved.

### Task 15: S2 results and review media

**Files:**
- Modify: `tests/sim/capture.gd` (a `--cards=archer:1,tank:1` argument, granted after `start_new_game` through `root.get_node("GameState").debug_grant_card(StringName(id))` in a loop)
- Create: `docs/screenshots/s2/lane_west.png`, `lane_north.png`, `lane_east.png`, `card_pick.png`, `guards_day.png`
- The main session edits `docs/superpowers/specs/2026-09-30-s2-hero-cards-guards-design.md`, adding §15 Results: sims, the sweep, the break day, test counts and screenshot paths.

- [ ] **Step 1: Implement the `--cards` argument** in `capture.gd`:
  - parse it like `--lane` into `id:level` pairs;
  - after `start_new_game(...)`, call `debug_grant_card` `level` times for each id;
  - `--scene=cardpick` emits `root.get_node("EventBus").wave_cleared.emit(lane_plan.size() - 1)`.
- [ ] **Step 2: Render the shots** (with rendering, not headless):
```bash
for lane in west north east; do "$GODOT" --path . --resolution 720x1280 -s res://tests/sim/capture.gd -- --out=docs/screenshots/s2/lane_$lane.png --lane=$lane --cards=archer:1,tank:1; done
"$GODOT" --path . --resolution 720x1280 -s res://tests/sim/capture.gd -- --out=docs/screenshots/s2/card_pick.png --scene=cardpick --seconds=1
"$GODOT" --path . --resolution 720x1280 -s res://tests/sim/capture.gd -- --out=docs/screenshots/s2/guards_day.png --cards=archer:2,tank:2 --seconds=3
```
- [ ] **Step 3: Read every PNG** and report:
  - the Archer is on the roof in all lane shots;
  - the Tank is on the west lane in `lane_west.png`;
  - the card panels are readable;
  - nothing is hidden by the diner (the D-151 fade applies).
- [ ] **Step 4: Run** `./run_tests.sh all`, and report the unit and sim counts and the SIM SUITE time.
- [ ] **Step 5: Commit, then open the Phase 5 PR.**
```bash
git add tests/sim/capture.gd docs/screenshots/s2
git commit -m "docs(s2): lane, card pick and guard screenshots; capture --cards/--scene (Task S2-15)"
```
