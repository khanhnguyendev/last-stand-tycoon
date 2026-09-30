# S3 Save/Load + Failure & Mercy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist the run in the browser (with a backup) and resume without a menu. Make a lost night cost exactly the same whether the player fails or quits. Make each failed retry of the same night gentler (mercy).

**Architecture:**
- `core/save_codec.gd` is pure. It encodes and decodes a checksummed envelope around `GameState.to_dict()`.
- `world/save/save_store.gd` owns the primary/backup rotation over one of two backends: `localStorage` through a JS try/catch on web, or files everywhere else.
- `world/save/autosave.gd` listens to EventBus only and writes at the spec §5.2 triggers.
- `PhaseController` gets one `_fail_restore()` path that also carries mercy, and a `resume_from()` used at boot.
- `Main` boots through a deferred `_boot()` that reads the store.

**Tech Stack:** Godot 4.7.2 (GDScript, single-threaded web export), GUT 9.7.1, `JavaScriptBridge`, Playwright (user cache) for the web smoke.

**Spec:** `docs/superpowers/specs/2026-09-30-s3-save-failure-mercy-design.md`. It builds on the S1 and S2 specs. Decisions D-171..D-178 are in `docs/DECISIONS.md`.

## Global Constraints

- `GODOT_TAG=4.7.2-stable`. Run `export GODOT=/Users/ryan/Applications/Godot-4.7.2-stable/Godot.app/Contents/MacOS/Godot`, then `./run_tests.sh unit|sim|all`.
- Gameplay code runs in `_physics_process`. Only `GameState` methods mutate game data. EventBus is for cross-system events only.
- Every number lives in `balance/`. Only `tests/unit/test_balance.gd` pins balance literals; every other test derives its values from `Balance`.
- `PhaseController` keeps the D-128 whitelist (`test_phase_controller` enforces it).
- JSON of `GameState.to_dict()` is always written as `JSON.stringify(d, "", true, true)` (D-146).
- **D-139 hot files:** `world/main.gd`, `world/world.gd`, `world/main.tscn`, `autoload/*`, `balance/*`, `project.godot`, `run_tests.sh` and `.github/*`.
  - A task may edit these only when the task header names them as its main purpose.
  - Otherwise the task delivers a wiring note plus a patch file, and the main session applies them.
- The unit and sim suites never write a real save: `Main.create()` leaves `Autosave.store` null. Tests use a store in a temp directory.
- `./run_tests.sh` fails on any GUT error or `SCRIPT ERROR`. Never drop, skip or weaken a test (D-132).
- Commits end with:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_019nNyHrXgHzKVKBtdqy9Hez
  ```
- **Phases:** one PR per phase, self-merged under D-137/D-159. Before merging, run `gh pr update-branch` if the branch is behind main.

  | Phase | Branch | Tasks | Note |
  |---|---|---|---|
  | 1 | `s3/p1-codec` | 1–3 | no gameplay change |
  | 2 | `s3/p2-mercy` | 4–5 | mercy and banners ship alone safely |
  | 3 | `s3/p3-autosave` | 6–7 | autosave and boot resume ship together |
  | 4 | `s3/p4-results` | 8–9 | |

## Review Focus

1. **Two tabs, or a preview build and main on the same origin.** Expected: keys are per path, so saves stay separate. Covered in Task 3 by `test_keys_are_prefixed_by_path`.
2. **A save written by a newer build.** Expected: it is never overwritten, the game starts fresh, and autosave stays off. Covered in Task 3 by `test_newer_save_is_never_overwritten` and in Task 7 by `test_newer_save_starts_fresh_and_keeps_it`.
3. **Quit during a night-1 retry, then reload.** Expected: mercy is kept, still 1, not reset or doubled. Covered in Task 7 by `test_quit_during_night1_retry_keeps_mercy`.
4. **Page hidden during DAY with unsaved changes.** Expected: an immediate flush. Covered in Task 6 by `test_hidden_flushes_when_dirty`.
5. **A CARD_PICK save whose offer has become invalid.** Expected: the decode rejects it and the game falls back instead of soft-locking. Covered in Task 2 by `test_content_rejects_card_pick_with_empty_or_maxed_offer`.

---

## Phase 1: Codec and store (`s3/p1-codec`)

### Task 1: GameState v3, `snapshot_taken`, and the S3 tuning fields

Main purpose: `autoload/GameState.gd`, `autoload/EventBus.gd`, `balance/wave_balance.gd` and `balance/ui_tuning.gd`.

**Files:**
- Modify: `autoload/GameState.gd`, `autoload/EventBus.gd`, `balance/wave_balance.gd`, `balance/ui_tuning.gd`
- Test: `tests/unit/test_game_state.gd`, `tests/unit/test_balance.gd`

**Interfaces:**
- Produces:
  - `GameState.SCHEMA_VERSION == 3` and `GameState.night_fails: int`.
  - `set_night_fails(n)`, `clear_night_fails()` and `mercy_factor() -> float`.
  - `EventBus.snapshot_taken(snapshot: Dictionary)`.
  - `WaveBalance.mercy_step = 0.15`, `WaveBalance.mercy_floor = 0.40`.
  - `UiTuning.banner_min_s = 0.6`, `UiTuning.autosave_interval_s = 3.0`.

- [ ] **Step 1: Write the failing tests.**
  - In `tests/unit/test_game_state.gd`, change the `assert_eq(int(d.v), 2)` pin in `test_round_trip_v2_through_json` to `GameState.SCHEMA_VERSION`.
  - Append to `tests/unit/test_game_state.gd`:
```gdscript
func test_night_fails_and_mercy_factor() -> void:
	var wb := Balance.data.wave
	assert_eq(GameState.night_fails, 0)
	assert_almost_eq(GameState.mercy_factor(), 1.0, 1e-6)
	for n in range(0, 7):
		GameState.set_night_fails(n)
		assert_almost_eq(GameState.mercy_factor(), maxf(1.0 - wb.mercy_step * n, wb.mercy_floor), 1e-6)
	GameState.set_night_fails(-3)
	assert_eq(GameState.night_fails, 0, "never negative")
	GameState.set_night_fails(2)
	GameState.clear_night_fails()
	assert_eq(GameState.night_fails, 0)
	GameState.set_night_fails(2)
	GameState.new_game(8)
	assert_eq(GameState.night_fails, 0, "a new game starts without mercy")

func test_round_trip_v3_carries_night_fails() -> void:
	GameState.set_night_fails(3)
	var d := GameState.to_dict()
	assert_eq(int(d.v), 3)
	assert_eq(int(d.night_fails), 3)
	var back = JSON.parse_string(JSON.stringify(d, "", true, true))
	GameState.new_game(1)
	GameState.from_dict(back)
	assert_eq(GameState.night_fails, 3)
	assert_eq(GameState.to_dict(), d)
```
  - Append to `tests/unit/test_balance.gd`:
```gdscript
func test_s3_tuning_defaults() -> void:
	assert_almost_eq(Balance.data.wave.mercy_step, 0.15, 1e-6)
	assert_almost_eq(Balance.data.wave.mercy_floor, 0.40, 1e-6)
	assert_almost_eq(Balance.ui.banner_min_s, 0.6, 1e-6)
	assert_almost_eq(Balance.ui.autosave_interval_s, 3.0, 1e-6)
```

- [ ] **Step 2: Run the unit tests.** Run `./run_tests.sh unit` and expect a FAIL.

- [ ] **Step 3: Implement.**
  - `autoload/EventBus.gd`: append
```gdscript
## PhaseController -> Autosave. A new restore point was taken (new game, close-up, night-1 retry). Never mutate it.
signal snapshot_taken(snapshot: Dictionary)
```
  - `balance/wave_balance.gd`: append
```gdscript
## Mercy (S3, D-175): enemy HP and damage x max(1 - mercy_step x night_fails, mercy_floor).
@export var mercy_step := 0.15
@export var mercy_floor := 0.40
```
  - `balance/ui_tuning.gd`: append
```gdscript
## S3: a new banner shortens the one on screen to at most banner_min_s (D-175); autosave throttle (D-173).
@export var banner_min_s := 0.6
@export var autosave_interval_s := 3.0
```
  - `autoload/GameState.gd`:
    - Set `const SCHEMA_VERSION := 3`.
    - Add the field `var night_fails := 0` with the comment `## Consecutive failures of the current night (S3 mercy, D-175).`
    - In `new_game()`, add `night_fails = 0`.
    - In `to_dict()`, add `"night_fails": night_fails,`.
    - In `from_dict()`, add `night_fails = int(d.night_fails)`.
    - Add the methods:
```gdscript
# --- failure and mercy (S3) ------------------------------------------------

func set_night_fails(n: int) -> void:
	night_fails = maxi(n, 0)

func clear_night_fails() -> void:
	night_fails = 0

## Enemy HP and damage multiplier (D-175).
func mercy_factor() -> float:
	var wb := Balance.data.wave
	return maxf(1.0 - wb.mercy_step * night_fails, wb.mercy_floor)
```

- [ ] **Step 4: Run the full suite.** Run `./run_tests.sh all` and expect exit 0. If a test pins `"v": 2` or `SCHEMA_VERSION == 2`, update that pin to 3 and nothing else.

- [ ] **Step 5: Commit.**
```bash
git add autoload balance tests/unit/test_game_state.gd tests/unit/test_balance.gd
git commit -m "feat(state): GameState v3 night_fails and mercy factor; snapshot_taken; S3 tuning fields (Task S3-1)"
```

### Task 2: `SaveCodec`

**Files:**
- Create: `core/save_codec.gd`
- Test: `tests/unit/test_save_codec.gd`

**Interfaces:**
- Consumes: `Rng.fnv1a32`, `CardCatalog`, `MapLayout.SPOT_IDS` and `BalanceData`.
- Produces:
  - `SaveCodec.FORMAT := 1`.
  - `SaveCodec.encode(state: Dictionary, build: String, now_unix: int) -> String`.
  - `SaveCodec.decode(text: String, current_v: int, bd: BalanceData) -> Dictionary`. It returns `{ok: bool, reason: String, state: Dictionary, newer: bool}`, and `reason` is one of `json`, `format`, `check`, `version` or `content`.
  - `SaveCodec.validate(state: Dictionary, bd: BalanceData) -> String`. An empty string means the state is valid.
  - `static var MIGRATIONS: Dictionary`, which maps a from-version int to `Callable(state) -> Dictionary`. It is empty at ship.

- [ ] **Step 1: Write the failing tests.** Create `tests/unit/test_save_codec.gd`:
```gdscript
extends GutTest

var bd: BalanceData

func before_each() -> void:
	Balance.reset()
	bd = Balance.data
	GameState.new_game(20260930)

func after_each() -> void:
	SaveCodec.MIGRATIONS.clear()

func _state(resume := "DAY") -> Dictionary:
	GameState.new_game(20260930)  # fresh each call: repeated grants would pass max_level
	GameState.debug_grant_card(&"tank")
	GameState.damage_diner(1.0 / 3.0)
	GameState.set_night_fails(2)
	var d := GameState.to_dict()
	d.resume_phase = resume
	return d

func test_round_trip_is_exact_after_from_dict() -> void:
	var s := _state()
	var r := SaveCodec.decode(SaveCodec.encode(s, "abc", 1234), GameState.SCHEMA_VERSION, bd)
	assert_true(r.ok, r.reason)
	GameState.new_game(1)
	GameState.from_dict(r.state)
	assert_eq(GameState.to_dict(), s)

func test_tampered_state_fails_the_check() -> void:
	var env = JSON.parse_string(SaveCodec.encode(_state(), "abc", 1))
	env.state_json = String(env.state_json).replace("\"gold\":0", "\"gold\":999")
	var r := SaveCodec.decode(JSON.stringify(env), GameState.SCHEMA_VERSION, bd)
	assert_false(r.ok)
	assert_eq(r.reason, "check")

func test_bad_json_and_formats() -> void:
	assert_eq(SaveCodec.decode("not json", 3, bd).reason, "json")
	assert_eq(SaveCodec.decode('{"format": {}, "state_json": "", "check": 1}', 3, bd).reason, "json")
	assert_eq(SaveCodec.decode("{}", 3, bd).reason, "json")
	var env = JSON.parse_string(SaveCodec.encode(_state(), "abc", 1))
	env.format = 2
	var r := SaveCodec.decode(JSON.stringify(env), GameState.SCHEMA_VERSION, bd)
	assert_eq([r.ok, r.reason, r.newer], [false, "format", true])

func test_newer_version_is_flagged() -> void:
	var s := _state()
	s.v = GameState.SCHEMA_VERSION + 1
	var r := SaveCodec.decode(SaveCodec.encode(s, "abc", 1), GameState.SCHEMA_VERSION, bd)
	assert_eq([r.ok, r.reason, r.newer], [false, "version", true])

func test_older_version_migrates_through_the_hook() -> void:
	var s := _state()
	s.v = GameState.SCHEMA_VERSION - 1
	s.erase("night_fails")
	var text := SaveCodec.encode(s, "abc", 1)
	assert_eq(SaveCodec.decode(text, GameState.SCHEMA_VERSION, bd).reason, "version", "no step registered")
	SaveCodec.MIGRATIONS[GameState.SCHEMA_VERSION - 1] = func(st: Dictionary) -> Dictionary:
		st.v = GameState.SCHEMA_VERSION
		st.night_fails = 0
		return st
	var r := SaveCodec.decode(text, GameState.SCHEMA_VERSION, bd)
	assert_true(r.ok, r.reason)
	assert_eq(int(r.state.night_fails), 0)

func _content(mutate: Callable, resume := "DAY") -> String:
	var s := _state(resume)
	mutate.call(s)
	return SaveCodec.decode(SaveCodec.encode(s, "abc", 1), GameState.SCHEMA_VERSION, bd).reason

func test_content_rejects_bad_ids_levels_and_phase() -> void:
	assert_eq(_content(func(s): s.cards["bogus"] = 1), "content")
	assert_eq(_content(func(s): s.cards["tank"] = bd.cards.max_level + 1), "content")
	assert_eq(_content(func(s): s.resume_phase = "LUNCH"), "content")
	assert_eq(_content(func(s): s.erase("gold")), "content")
	assert_eq(_content(func(s): s.buildings["tower_x"] = {"level": 0, "paid": 0, "hp": 0.0}), "content")
	assert_eq(_content(func(s): s.lane_plan.pop_back()), "content")
	assert_eq(_content(func(s): s.guards["hero_damage"] = {"hp": 1.0}), "content")
	assert_eq(_content(func(s): s.card_offer = ["bogus"]), "content")
	assert_eq(_content(func(s): s.buildings.erase("fence_n")), "content")
	assert_eq(_content(func(s): s.lane_plan[0].erase("hp_mult")), "content")
	assert_eq(_content(func(s): s.cards = []), "content")

func test_content_rejects_card_pick_with_empty_or_maxed_offer() -> void:
	assert_eq(_content(func(s): s.card_offer = [], "CARD_PICK"), "content")
	assert_eq(_content(func(s):
		s.card_offer = ["tank"]
		s.cards["tank"] = bd.cards.max_level, "CARD_PICK"), "content")
	assert_eq(_content(func(s): s.card_offer = ["archer", "move_speed"], "CARD_PICK"), "")
```
  Note: the last assert expects `reason == ""` because the decode is `ok`. `decode` returns `reason = ""` on success.

- [ ] **Step 2: Run the unit tests.** Run `./run_tests.sh unit` and expect a FAIL (`SaveCodec` is not declared).

- [ ] **Step 3: Implement** `core/save_codec.gd`:
```gdscript
class_name SaveCodec
extends RefCounted
## The save envelope (S3 spec 4, D-172): a checksum over the raw state JSON, a migration hook, content validation.

const FORMAT := 1
const RESUME_PHASES := ["NIGHT", "DAY", "CARD_PICK"]
const STATE_KEYS := ["v", "resume_phase", "run_seed", "day", "gold", "gold_pile", "freezer_steaks",
	"counter_steaks", "carried_steaks", "diner_hp", "buildings", "lane_plan", "cards", "card_offer", "guards",
	"night_fails"]
## from_version (int) -> Callable(state: Dictionary) -> Dictionary. Empty at ship (no older disk saves exist).
static var MIGRATIONS := {}

static func encode(state: Dictionary, build: String, now_unix: int) -> String:
	var sj := JSON.stringify(state, "", true, true)
	return JSON.stringify({"format": FORMAT, "saved_at_unix": now_unix, "build": build, "state_json": sj,
		"check": Rng.fnv1a32(sj)})

static func decode(text: String, current_v: int, bd: BalanceData) -> Dictionary:
	var out := {"ok": false, "reason": "", "state": {}, "newer": false}
	var env = _parse(text)
	if typeof(env) != TYPE_DICTIONARY or not env.has_all(["format", "state_json", "check"]) \
			or not typeof(env.format) in [TYPE_INT, TYPE_FLOAT] or not typeof(env.check) in [TYPE_INT, TYPE_FLOAT]:
		out.reason = "json"
		return out
	if int(env.format) != FORMAT:
		out.reason = "format"
		out.newer = int(env.format) > FORMAT
		return out
	if typeof(env.state_json) != TYPE_STRING or Rng.fnv1a32(env.state_json) != int(env.check):
		out.reason = "check"
		return out
	var state = _parse(env.state_json)
	if typeof(state) != TYPE_DICTIONARY or not state.has("v"):
		out.reason = "json"
		return out
	var v := int(state.v)
	if v > current_v:
		out.reason = "version"
		out.newer = true
		return out
	while v < current_v:
		if not MIGRATIONS.has(v):
			out.reason = "version"
			return out
		state = MIGRATIONS[v].call(state)
		v = int(state.v)
	if validate(state, bd) != "":
		out.reason = "content"
		return out
	out.ok = true
	out.state = state
	return out

## JSON.new().parse(): unlike JSON.parse_string, a bad text returns an error code without an engine error
## (GUT fails tests on engine errors).
static func _parse(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data

## "" when the state can be loaded without a crash or a soft-lock; otherwise what is wrong.
static func validate(s: Dictionary, bd: BalanceData) -> String:
	for k in STATE_KEYS:
		if not s.has(k):
			return "missing %s" % k
	if not String(s.resume_phase) in RESUME_PHASES:
		return "resume_phase"
	for k in ["buildings", "cards", "guards"]:
		if typeof(s[k]) != TYPE_DICTIONARY:
			return "type %s" % k
	for k in ["lane_plan", "card_offer"]:
		if typeof(s[k]) != TYPE_ARRAY:
			return "type %s" % k
	for id in s.buildings:
		if not String(id) in MapLayout.SPOT_IDS:
			return "building %s" % id
		if typeof(s.buildings[id]) != TYPE_DICTIONARY or not s.buildings[id].has_all(["level", "paid", "hp"]):
			return "building fields %s" % id
	for id in MapLayout.SPOT_IDS:
		if not s.buildings.has(id):
			return "missing building %s" % id
	if s.lane_plan.size() != bd.wave.base_counts.size():
		return "lane_plan"
	for w in s.lane_plan:
		if typeof(w) != TYPE_DICTIONARY or not w.has_all(["main", "side", "main_count", "side_count", "hp_mult"]):
			return "lane_plan fields"
	var max_level := bd.cards.max_level
	for id in s.cards:
		if not StringName(id) in CardCatalog.IDS:
			return "card %s" % id
		var l := int(s.cards[id])
		if l < 0 or l > max_level:
			return "level %s" % id
	for id in s.card_offer:
		if not StringName(id) in CardCatalog.IDS:
			return "offer %s" % id
	for id in s.guards:
		if not StringName(id) in CardCatalog.ADVENTURERS:
			return "guard %s" % id
	if String(s.resume_phase) == "CARD_PICK":
		if s.card_offer.is_empty():
			return "empty offer"
		for id in s.card_offer:
			if int(s.cards.get(String(id), 0)) >= max_level:
				return "maxed offer"
	return ""
```

- [ ] **Step 4: Run the full suite.** Run `./run_tests.sh all` and expect exit 0.

- [ ] **Step 5: Commit.**
```bash
git add core/save_codec.gd tests/unit/test_save_codec.gd
git commit -m "feat(core): save codec with checksum over the state text, migration hook and content validation (Task S3-2)"
```

### Task 3: `SaveStore`

**Files:**
- Create: `world/save/save_store.gd`
- Test: `tests/unit/test_save_store.gd`

**Interfaces:**
- Consumes: `SaveCodec`, `GameState.SCHEMA_VERSION` and `Balance.data`.
- Produces:
  - `SaveStore.for_platform() -> SaveStore` and `SaveStore.with_dir(dir: String) -> SaveStore` (tests).
  - `read() -> {ok, state, source, newer}`, `write(text) -> bool` and `wipe()`.
  - `writable: bool`.
  - `static normalize_path(p) -> String`.
  - `static js_call(op: String, key: String, value := "") -> String`.
  - `key_prefix: String`, which is `lst:<path>:` on web and `""` for files.

- [ ] **Step 1: Write the failing tests.** Create `tests/unit/test_save_store.gd`:
```gdscript
extends GutTest

var dir := ""

func before_each() -> void:
	Balance.reset()
	GameState.new_game(5)
	dir = "user://test_saves/%d" % Time.get_ticks_usec()

func after_each() -> void:
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_saves"))  # only succeeds when empty

func _text(gold: int) -> String:
	GameState.gold = gold  # test-only setup write
	var s := GameState.to_dict()
	s.resume_phase = "DAY"
	return SaveCodec.encode(s, "t", 1)

func test_write_then_read() -> void:
	var st := SaveStore.with_dir(dir)
	assert_true(st.write(_text(7)))
	var r := SaveStore.with_dir(dir).read()
	assert_eq([r.ok, r.source, int(r.state.gold)], [true, "primary", 7])

func test_backup_rotation_and_corrupt_primary() -> void:
	var st := SaveStore.with_dir(dir)
	st.write(_text(1))
	st.write(_text(2))  # backup now holds gold 1
	var f := FileAccess.open(dir.path_join("save.json"), FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	var st2 := SaveStore.with_dir(dir)
	var r := st2.read()
	assert_eq([r.ok, r.source, int(r.state.gold)], [true, "backup", 1])
	assert_true(FileAccess.file_exists(dir.path_join("save_corrupt.json")), "the corrupt primary is kept aside")

func test_both_corrupt_is_none() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for n in ["save.json", "save_bak.json"]:
		var f := FileAccess.open(dir.path_join(n), FileAccess.WRITE)
		f.store_string("nope")
		f.close()
	var r := SaveStore.with_dir(dir).read()
	assert_eq([r.ok, r.source], [false, "none"])

func test_newer_save_is_never_overwritten() -> void:
	var s := GameState.to_dict()
	s.resume_phase = "DAY"
	s.v = GameState.SCHEMA_VERSION + 1
	var newer := SaveCodec.encode(s, "future", 1)
	SaveStore.with_dir(dir).write(newer)
	var st := SaveStore.with_dir(dir)
	var r := st.read()
	assert_eq([r.ok, r.newer, st.writable], [false, true, false])
	assert_false(st.write(_text(3)))
	assert_eq(FileAccess.get_file_as_string(dir.path_join("save.json")), newer, "untouched")

func test_wipe_clears_everything_and_resets() -> void:
	var st := SaveStore.with_dir(dir)
	st.write(_text(1))
	st.write(_text(2))
	st.wipe()
	assert_false(st.read().ok)
	st.write(_text(4))
	assert_false(FileAccess.file_exists(dir.path_join("save_bak.json")), "a wiped run never reaches the backup")

func test_keys_are_prefixed_by_path() -> void:
	assert_eq(SaveStore.normalize_path("/last-stand-tycoon/preview/x/debug/index.html"), "/last-stand-tycoon/preview/x/debug/")
	assert_eq(SaveStore.normalize_path("/last-stand-tycoon/"), "/last-stand-tycoon/")
	var a := SaveStore.key_prefix_for("/a/")
	var b := SaveStore.key_prefix_for("/a/debug/")
	assert_ne(a, b)
	assert_eq(a, "lst:/a/:")

func test_js_call_escapes_keys_and_values() -> void:
	var js := SaveStore.js_call("set", "lst:/a/:save", "line1\n\"q\" \\ đêm")
	assert_false(js.contains("\n"), "no raw newline in the JS source")
	assert_true(js.contains(JSON.stringify("lst:/a/:save")))
	assert_true(js.contains(JSON.stringify("line1\n\"q\" \\ đêm")))
	assert_true(js.begins_with("(function(){try{"))
	assert_true(SaveStore.js_call("get", "k").contains("localStorage.getItem("))
	assert_true(SaveStore.js_call("remove", "k").contains("localStorage.removeItem("))
```

- [ ] **Step 2: Run the unit tests.** Run `./run_tests.sh unit` and expect a FAIL.

- [ ] **Step 3: Implement** `world/save/save_store.gd`:
```gdscript
class_name SaveStore
extends RefCounted
## One local save plus a backup (S3 spec 5.1, D-171, D-172). Web: localStorage under a per-path key prefix,
## every call wrapped in a JS try/catch (JavaScriptBridge.eval swallows exceptions). Elsewhere: files.

const NAMES := ["save", "save_bak", "save_corrupt"]

var writable := true
var key_prefix := ""
var _dir := ""
var _web := false
var _last_good_text := ""
var _warned := false

static func for_platform() -> SaveStore:
	var s := SaveStore.new()
	if OS.has_feature("web"):
		s._web = true
		s.key_prefix = key_prefix_for(normalize_path(str(JavaScriptBridge.eval("window.location.pathname", true))))
	else:
		s._dir = "user://save"
	return s

static func with_dir(dir: String) -> SaveStore:
	var s := SaveStore.new()
	s._dir = dir
	return s

static func normalize_path(p: String) -> String:
	return p.trim_suffix("index.html")

static func key_prefix_for(path: String) -> String:
	return "lst:%s:" % path

## JS source for one localStorage call; key and value go through JSON.stringify (escaping).
static func js_call(op: String, key: String, value := "") -> String:
	var k := JSON.stringify(key)
	match op:
		"get":
			return "(function(){try{var v=localStorage.getItem(%s);return JSON.stringify({ok:1,value:(v===null?'':v)})}catch(e){return JSON.stringify({ok:0,value:''})}})()" % k
		"set":
			return "(function(){try{localStorage.setItem(%s,%s);return 1}catch(e){return 0}})()" % [k, JSON.stringify(value)]
	return "(function(){try{localStorage.removeItem(%s);return 1}catch(e){return 0}})()" % k

func read() -> Dictionary:
	for name in ["save", "save_bak"]:
		var text := _read_key(name)
		if text == "":
			continue
		var r := SaveCodec.decode(text, GameState.SCHEMA_VERSION, Balance.data)
		if r.ok:
			_last_good_text = text
			return {"ok": true, "state": r.state, "source": "primary" if name == "save" else "backup", "newer": false}
		if r.newer:
			writable = false
			_warn("a newer build's save was found; autosave is off for this session")
			return {"ok": false, "state": {}, "source": name, "newer": true}
		if name == "save":
			_write_key("save_corrupt", text)
	return {"ok": false, "state": {}, "source": "none", "newer": false}

func write(text: String) -> bool:
	if not writable:
		return false
	if _last_good_text != "":
		_write_key("save_bak", _last_good_text)
	var ok := _write_key("save", text)
	if ok:
		_last_good_text = text
	else:
		_warn("save write failed (storage unavailable or full)")
	return ok

func wipe() -> void:
	for name in NAMES:
		_remove_key(name)
	_last_good_text = ""
	writable = true

func _warn(msg: String) -> void:
	if not _warned:
		_warned = true
		push_warning("SaveStore: " + msg)

## Named _read_key/_write_key/_remove_key: _get/_set would override Object's property virtuals.
func _read_key(name: String) -> String:
	if _web:
		var res = JSON.parse_string(str(JavaScriptBridge.eval(js_call("get", key_prefix + name), true)))
		return String(res.value) if typeof(res) == TYPE_DICTIONARY and int(res.ok) == 1 else ""
	var path := _dir.path_join(name + ".json")
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

func _write_key(name: String, text: String) -> bool:
	if _web:
		return int(JavaScriptBridge.eval(js_call("set", key_prefix + name, text), true)) == 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var tmp := _dir.path_join(name + ".json.tmp")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	var final := _dir.path_join(name + ".json")
	# rename_absolute replaces an existing file (macOS/Linux; desktop is tests only): never a moment without a primary.
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(final)) == OK

func _remove_key(name: String) -> void:
	if _web:
		JavaScriptBridge.eval(js_call("remove", key_prefix + name), true)
		return
	var path := _dir.path_join(name + ".json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
```

- [ ] **Step 4: Run the full suite.** Run `./run_tests.sh all` and expect exit 0.

- [ ] **Step 5: Commit, then open the Phase 1 PR.**
```bash
git add world/save tests/unit/test_save_store.gd
git commit -m "feat(save): SaveStore with per-path localStorage keys, JS try/catch, file backend and backup rotation (Task S3-3)"
```

---

## Phase 2: Mercy and banners (`s3/p2-mercy`)

### Task 4: One fail-restore path, mercy on Boars, `snapshot_taken`

**Files:**
- Modify: `world/phase_controller.gd`, `world/wave_director.gd`, `actors/enemy/boar.gd`
- Modify (tests that change, spec §6): `tests/sim/test_night_sims.gd`, `tests/unit/test_phase_controller.gd` and `tests/unit/test_restore_world.gd`
- Test: `tests/unit/test_mercy.gd`

**Interfaces:**
- Consumes: `GameState.night_fails`, `set_night_fails`, `clear_night_fails` and `mercy_factor` (Task 1), and `EventBus.snapshot_taken`.
- Produces:
  - `PhaseController._fail_restore()`.
  - `snapshot_taken` is emitted by `start_new_game`, by `close_up` and by each night-1 retry.
  - Dawn clears mercy.
  - Boar HP on the plan path is scaled by `mercy_factor()`.
  - All Boar attack arms deal `enemy.damage * mercy_factor()`.

- [ ] **Step 1: Write the failing tests.** Create `tests/unit/test_mercy.gd`:
```gdscript
extends GutTest

var main: Main
var pc: PhaseController

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	pc = main.phase_controller
	pc.start_new_game(61)
	main.hero.teleport(Vector2(15, 8))  # the hero must not kill the test boars

func _fail_ticks() -> int:
	return int(ceil(Balance.ui.banner_time * Engine.physics_ticks_per_second)) + 3

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_night1_fail_adds_mercy_and_snapshots_it() -> void:
	watch_signals(EventBus)
	GameState.damage_diner(1e6)
	await _ticks(_fail_ticks())
	assert_eq(pc.phase, Phase.NIGHT)
	assert_eq(GameState.night_fails, 1)
	assert_eq(int(pc.snapshot.night_fails), 1)
	assert_signal_emit_count(EventBus, "snapshot_taken", 1, "the night-1 retry re-emits its restore point")
	assert_signal_emitted_with_parameters(EventBus, "banner_requested", ["The monsters look tired tonight."])
	GameState.damage_diner(1e6)
	await _ticks(_fail_ticks())
	assert_eq(GameState.night_fails, 2)

func test_day_fail_carries_mercy_and_dawn_clears_it() -> void:
	EventBus.wave_cleared.emit(2)
	EventBus.card_chosen.emit(GameState.card_offer[0])
	pc.close_up()
	GameState.damage_diner(1e6)
	await _ticks(_fail_ticks())
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.night_fails, 1)
	pc.close_up()
	EventBus.wave_cleared.emit(2)
	assert_eq(GameState.night_fails, 0, "a cleared night resets mercy")

func test_mercy_scales_boar_hp_and_damage() -> void:
	GameState.set_night_fails(1)
	var f := GameState.mercy_factor()
	var wd := main.world.wave_director
	wd.stop()
	var plan_boar: Boar = wd._spawn("north", 0.0)  # plan path (hp_mult <= 0)
	assert_almost_eq(plan_boar.health.max_hp, Balance.data.enemy.hp * float(GameState.lane_plan[0].hp_mult) * f, 1e-4)
	var debug_boar: Boar = wd.debug_spawn("north", 0.0, 1.0)
	assert_almost_eq(debug_boar.health.max_hp, Balance.data.enemy.hp, 1e-4, "debug_spawn stays exact")
	debug_boar.dist = debug_boar.path_length()
	debug_boar._update_position()
	var hp0 := GameState.diner_hp
	await _ticks(int(ceil(Balance.data.enemy.attack_interval * 60.0)) + 2)
	assert_almost_eq(hp0 - GameState.diner_hp, Balance.data.enemy.damage * f, 1e-4, "diner arm scaled")
```
  If `Health` names its max field differently, read `components/health.gd` and use its field.
  - Update the tests that change (spec §6). In each of these, set `snap.night_fails = 1` before the `assert_eq(now, snap)` comparison, and keep every other field exact:
    - `tests/sim/test_night_sims.gd` `test_night1_fail_restarts_night`
    - `tests/unit/test_phase_controller.gd` `test_fail_night1_restarts_night`
    - `tests/unit/test_restore_world.gd` `test_fail_flow_restore_rebuilds_world`
  - Add Boar arm tests to `tests/unit/test_boar.gd`, using its `FakeDirector` fixture. For the fence arm and the guard arm, first call `GameState.set_night_fails(2)`, then assert the damage per hit equals `Balance.data.enemy.damage * GameState.mercy_factor()`.

- [ ] **Step 2: Run the unit and sim tests.** Run `./run_tests.sh unit` and `./run_tests.sh sim` and expect FAILs.

- [ ] **Step 3: Implement.**
  - `world/phase_controller.gd`:
    - In `start_new_game()`, right after `snapshot.resume_phase = "NIGHT"`, add `EventBus.snapshot_taken.emit(snapshot)`.
    - In `close_up()`, right after `snapshot.resume_phase = "DAY"`, add `EventBus.snapshot_taken.emit(snapshot)`.
    - In `_run_dawn()`, add `GameState.clear_night_fails()` just before `GameState.advance_day()`.
    - Replace `_on_fail_timer`:
```gdscript
func _on_fail_timer(fail_id: int) -> void:
	if fail_id != _fail_id:
		return  # start_new_game() ran meanwhile
	_fail_restore()

## The one failure path (S3 spec 6, D-175): the restore point carries the new mercy count, a night-1 retry
## re-emits it (the save gets it), then the S1 restore contract, then the flavor line.
func _fail_restore() -> void:
	var fails := int(snapshot.get("night_fails", 0)) + 1
	snapshot.night_fails = fails
	if String(snapshot.resume_phase) == "NIGHT":
		EventBus.snapshot_taken.emit(snapshot)
	_restore_snapshot()
	EventBus.banner_requested.emit(tr("The monsters look tired tonight."))
```
  - `world/wave_director.gd` `_spawn`: `var mult := hp_mult if hp_mult > 0.0 else float(_plan[maxi(wave_index, 0)].hp_mult) * GameState.mercy_factor()`
  - `actors/enemy/boar.gd`: in the attack block, add `var dmg := eb.damage * GameState.mercy_factor()` and use `dmg` in all three arms (`fence_on_lane`, `guard`, `diner`).

- [ ] **Step 4: Run the full suite.** Run `./run_tests.sh all` and expect exit 0. Paste the night-2 sim lines.

- [ ] **Step 5: Commit.**
```bash
git add world/phase_controller.gd world/wave_director.gd actors/enemy/boar.gd tests
git commit -m "feat(fail): one fail-restore path with mercy; snapshot_taken; mercy scales Boar HP and damage (Task S3-4)"
```

### Task 5: HUD banner queue

**Files:**
- Modify: `ui/hud/hud.gd`
- Test: `tests/unit/test_hud.gd`

**Interfaces:**
- Consumes: `Balance.ui.banner_time` and `Balance.ui.banner_min_s`.
- Produces: banners queue. A new banner shortens the current one to `min(remaining, banner_min_s)`; the next banner then plays for the full `banner_time`. The queue survives `state_restored`.

- [ ] **Step 1: Write the failing tests.** In `tests/unit/test_hud.gd`:
  - `before_each` runs `start_new_game(81)`, which emits "The monsters return". With the queue, that banner would still be showing when each test starts. So drain it at the end of `before_each` (test-only setup write):
    ```gdscript
    	hud._banner_queue.clear()
    	hud._banner_left = 0.0
    	hud._show_next_banner()
    ```
  - Replace `test_second_banner_resets_the_fade` with the spec §6 version, and add the queue tests:
```gdscript
func test_second_banner_shortens_the_first_then_plays_in_full() -> void:
	EventBus.banner_requested.emit("One")
	var shown := int(Balance.ui.banner_time * 60 * 0.9)
	for i in shown:
		await get_tree().process_frame
	EventBus.banner_requested.emit("Two")
	var r := minf(Balance.ui.banner_time - shown / 60.0, Balance.ui.banner_min_s)
	for i in int(ceil(r * 60.0)) + 2:
		await get_tree().process_frame
	assert_eq(hud.banner.text, "Two")
	assert_almost_eq(hud.banner_panel.modulate.a, 1.0, 1e-3)
	for i in int(Balance.ui.banner_time * 60 * 0.7):
		await get_tree().process_frame
	assert_true(hud.banner_panel.visible)
	assert_almost_eq(hud.banner_panel.modulate.a, 1.0, 1e-3)

func test_queued_banners_play_in_order() -> void:
	EventBus.banner_requested.emit("A")
	EventBus.banner_requested.emit("B")
	EventBus.banner_requested.emit("C")
	assert_eq(hud.banner.text, "A")
	var seen := ["A"]
	for i in int((Balance.ui.banner_min_s * 2.0 + Balance.ui.banner_time) * 60.0) + 30:
		await get_tree().process_frame
		if hud.banner.visible and seen[-1] != hud.banner.text:
			seen.append(hud.banner.text)
	assert_eq(seen, ["A", "B", "C"])

func test_queue_survives_state_restored() -> void:
	EventBus.banner_requested.emit("The monsters return")
	EventBus.banner_requested.emit("The monsters look tired tonight.")
	GameState.new_game(3)  # emits state_restored
	for i in int(ceil(Balance.ui.banner_min_s * 60.0)) + 3:
		await get_tree().process_frame
	assert_eq(hud.banner.text, "The monsters look tired tonight.")
```

- [ ] **Step 2: Run the unit tests.** Run `./run_tests.sh unit` and expect a FAIL.

- [ ] **Step 3: Implement.** In `ui/hud/hud.gd`:
  - Remove `_banner_tween` and its use.
  - Add the fields:
```gdscript
var _banner_queue: Array[String] = []
## Seconds left of the banner on screen; 0 when none is showing.
var _banner_left := 0.0
```
  - Replace `_on_banner`:
```gdscript
## S3 (D-175): a new banner shortens the current one to banner_min_s, then plays in full.
func _on_banner(text: String) -> void:
	_banner_queue.append(text)
	if _banner_left <= 0.0:
		_show_next_banner()
	else:
		_banner_left = minf(_banner_left, Balance.ui.banner_min_s)

func _show_next_banner() -> void:
	if _banner_queue.is_empty():
		_banner_left = 0.0
		banner.visible = false
		banner_panel.visible = false
		return
	banner.text = _banner_queue.pop_front()
	banner.visible = true
	banner_panel.visible = true
	banner_panel.modulate.a = 1.0
	_banner_left = Balance.ui.banner_time

func _tick_banner(delta: float) -> void:
	if _banner_left <= 0.0:
		return
	_banner_left -= delta
	banner_panel.modulate.a = clampf(_banner_left / (Balance.ui.banner_time * 0.25), 0.0, 1.0)
	if _banner_left <= 0.0:
		_show_next_banner()
```
  - Call `_tick_banner(delta)` at the top of `_process(delta)`. Rename its `_delta` parameter to `delta`.

- [ ] **Step 4: Run the full suite.** Run `./run_tests.sh all` and expect exit 0. The existing banner tests (`test_banner_shows_then_hides` and the backing and wrapping tests) must pass. The drained `before_each` is their only change.

- [ ] **Step 5: Commit, then open the Phase 2 PR.**
```bash
git add ui/hud/hud.gd tests/unit/test_hud.gd
git commit -m "feat(hud): banner queue; a new banner shortens the current one to banner_min_s (Task S3-5)"
```

---

## Phase 3: Autosave and resume (`s3/p3-autosave`)

Tasks 6 and 7 ship together. Autosave without a boot resume would write saves that nothing reads, which is harmless but pointless. A resume without Autosave would never find a save.

### Task 6: `Autosave`

**Files:**
- Create: `world/save/autosave.gd`
- Wiring note (D-139): in `world/main.gd`, add `var autosave: Autosave` next to `var hud: Hud`. Right after the FocusPause block in `_ready()`, add:
  ```gdscript
  	autosave = Autosave.new()
  	autosave.name = "Autosave"
  	add_child(autosave)
  ```
  The patch file is named in Step 5. Do not commit `main.gd`.
- Test: `tests/unit/test_autosave.gd`

**Interfaces:**
- Consumes: `SaveStore`, `SaveCodec.encode`, the EventBus signals and `GameState.to_dict()`.
- Produces:
  - `Autosave.store: SaveStore`; `null` means Autosave does nothing.
  - `flush()` and `writes: int` (a counter for tests).
  - Behaviour is the spec §5.2 table plus the state machine.

- [ ] **Step 1: Write the failing tests.** Create `tests/unit/test_autosave.gd`:
```gdscript
extends GutTest

var main: Main
var pc: PhaseController
var store: SaveStore
var dir := ""

func before_each() -> void:
	Balance.reset()
	dir = "user://test_saves/as_%d" % Time.get_ticks_usec()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	pc = main.phase_controller
	store = SaveStore.with_dir(dir)
	main.autosave.store = store

func after_each() -> void:
	store.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_saves"))

func _saved() -> Dictionary:
	return SaveStore.with_dir(dir).read().state

func _fail_ticks() -> int:
	return int(ceil(Balance.ui.banner_time * Engine.physics_ticks_per_second)) + 3

func test_new_game_writes_its_night_snapshot() -> void:
	pc.start_new_game(9)
	assert_eq(String(_saved().resume_phase), "NIGHT")
	assert_eq(int(_saved().day), 1)

func test_no_writes_at_night() -> void:
	pc.start_new_game(9)
	var w := main.autosave.writes
	GameState.add_gold(5)
	for i in int(Balance.ui.autosave_interval_s * 60.0) + 10:
		await get_tree().physics_frame
	assert_eq(main.autosave.writes, w)

func test_offer_pick_build_and_day_writes() -> void:
	pc.start_new_game(9)
	EventBus.wave_cleared.emit(2)
	assert_eq(String(_saved().resume_phase), "CARD_PICK")
	EventBus.card_chosen.emit(GameState.card_offer[0])
	assert_eq(String(_saved().resume_phase), "DAY")
	assert_eq(int(_saved().day), 2)
	GameState.add_gold(GameState.next_level_cost("fence_w"))
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	assert_eq(int(_saved().buildings.fence_w.level), 1, "build_completed writes at once")

func test_close_up_writes_the_restore_point() -> void:
	pc.start_new_game(9)
	pc.debug_skip_to_day()
	GameState.add_gold(12)
	pc.close_up()
	var s := _saved()
	assert_eq(String(s.resume_phase), "DAY")
	assert_eq(int(s.gold), 12)

func test_throttled_day_writes() -> void:
	pc.start_new_game(9)
	pc.debug_skip_to_day()
	var w := main.autosave.writes
	for i in 10:
		GameState.add_gold(1)
	assert_eq(main.autosave.writes, w, "no write before the interval")
	for i in int(Balance.ui.autosave_interval_s * 60.0) + 5:
		await get_tree().physics_frame
	assert_eq(main.autosave.writes, w + 1, "one write for many changes")
	assert_eq(int(_saved().gold), GameState.gold)

func test_hidden_flushes_when_dirty() -> void:
	pc.start_new_game(9)
	pc.debug_skip_to_day()
	GameState.add_gold(3)
	main.autosave.flush()
	assert_eq(int(_saved().gold), GameState.gold)

func test_night1_retry_writes_during_the_fail_flow() -> void:
	pc.start_new_game(9)
	GameState.damage_diner(1e6)
	for i in _fail_ticks():
		await get_tree().physics_frame
	var s := _saved()
	assert_eq([String(s.resume_phase), int(s.night_fails)], ["NIGHT", 1])

func test_day_fail_restore_writes_the_new_mercy() -> void:
	pc.start_new_game(9)
	pc.debug_skip_to_day()
	pc.close_up()
	GameState.damage_diner(1e6)
	for i in _fail_ticks():
		await get_tree().physics_frame
	var s := _saved()
	assert_eq([String(s.resume_phase), int(s.night_fails)], ["DAY", 1])

func test_main_create_has_no_store() -> void:
	var m := Main.create()
	add_child_autofree(m)
	assert_null(m.autosave.store)
```

- [ ] **Step 2: Run the unit tests.** Apply the `main.gd` wiring locally, then run `./run_tests.sh unit` and expect a FAIL.

- [ ] **Step 3: Implement** `world/save/autosave.gd`:
```gdscript
class_name Autosave
extends Node
## Writes the save at the S3 spec 5.2 triggers. Listens to EventBus only; tracks the phase itself. No store = no-op
## (Main.create() in tests), so suites never write a real save.

var store: SaveStore = null
var writes := 0
var phase := Phase.NIGHT
var failing := false
var _dirty := false
var _since_dirty := 0.0
var _js_cbs: Array = []

func _ready() -> void:
	EventBus.snapshot_taken.connect(_on_snapshot)
	EventBus.card_offered.connect(_on_offer)
	EventBus.phase_changed.connect(_on_phase)
	EventBus.night_failed.connect(_on_night_failed)
	EventBus.build_completed.connect(_on_build_completed)
	EventBus.stocks_changed.connect(_mark_dirty)
	EventBus.gold_changed.connect(_mark_dirty.unbind(2))
	EventBus.building_changed.connect(_mark_dirty.unbind(3))
	if OS.has_feature("web"):
		var doc := JavaScriptBridge.get_interface("document")
		var win := JavaScriptBridge.get_interface("window")
		var on_hide := JavaScriptBridge.create_callback(_on_page_hidden)
		_js_cbs.append(on_hide)
		doc.addEventListener("visibilitychange", on_hide)
		win.addEventListener("pagehide", on_hide)

func flush() -> void:
	if _dirty and phase == Phase.DAY and not failing:
		_write_live("DAY")

func _on_page_hidden(_args: Array) -> void:
	flush()

## snapshot_taken always writes: new game, close-up, night-1 retry (spec 5.2 state machine).
func _on_snapshot(snap: Dictionary) -> void:
	_write_state(snap.duplicate(true))

func _on_offer(_offer: Array) -> void:
	if phase == Phase.DAWN and not failing:
		_write_live("CARD_PICK")

func _on_phase(p: int, _day: int) -> void:
	phase = p
	failing = false
	if p == Phase.DAY:
		_write_live("DAY")

func _on_night_failed(_day: int) -> void:
	failing = true

func _on_build_completed(_spot: StringName, _level: int) -> void:
	if phase == Phase.DAY and not failing:
		_write_live("DAY")

func _mark_dirty() -> void:
	if phase == Phase.DAY and not failing and not _dirty:
		_dirty = true
		_since_dirty = 0.0

func _physics_process(delta: float) -> void:
	if not _dirty:
		return
	_since_dirty += delta
	if _since_dirty >= Balance.ui.autosave_interval_s - 1e-6:
		flush()

func _write_live(resume_phase: String) -> void:
	var d := GameState.to_dict()
	d.resume_phase = resume_phase
	_write_state(d)

func _write_state(d: Dictionary) -> void:
	if store == null:
		return
	if store.write(SaveCodec.encode(d, _build_id(), int(Time.get_unix_time_from_system()))):
		writes += 1
	_dirty = false

static func _build_id() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.LST_BUILD || ''", true))
	return "dev"
```

- [ ] **Step 4: Run the full suite.** Run `./run_tests.sh all` with the wiring applied and expect exit 0.

- [ ] **Step 5: Commit** without `world/main.gd`. Save the wiring as `/Users/ryan/ws/1.GAME/lst-wt/lst-s3t6-wiring.patch`.
- [ ] **Step 6 (main session):** apply the patch on the task branch, run `./run_tests.sh all`, and amend it into the task commit before the reviewer pass and before the next task (otherwise the branch is red).
```bash
git add world/save/autosave.gd tests/unit/test_autosave.gd
git commit -m "feat(save): Autosave at night start, dawn, pick, build and throttled day changes (Task S3-6)"
```

### Task 7: Boot resume and debug restart

**Files:**
- Modify: `world/phase_controller.gd` (`resume_from`), `ui/debug/debug_overlay.gd` (R key, URL fresh start)
- Wiring note (D-139): in `world/main.gd`:
  - Add the fields `var save_store: SaveStore` and `var debug_fresh_start := false`.
  - Replace the final `if auto_start:` block with:
    ```gdscript
    	if auto_start:
    		save_store = SaveStore.for_platform()
    		autosave.store = save_store
    		_boot.call_deferred()
    ```
  - Add:
    ```gdscript
    ## S3 (D-176, D-177): resume the saved run, or start fresh. Deferred so every listener has connected.
    func _boot() -> void:
    	if debug_fresh_start:
    		save_store.wipe()
    		phase_controller.start_new_game()
    		return
    	var r := save_store.read()
    	if r.ok:
    		phase_controller.resume_from(r.state)
    	else:
    		phase_controller.start_new_game()
    ```
  - The patch file is named in Step 5.
- Test: `tests/unit/test_resume.gd`

**Interfaces:**
- Consumes: Tasks 1–6.
- Produces:
  - `PhaseController.resume_from(state: Dictionary)` and `Main._boot()`.
  - The debug `R` key wipes the save and starts a new game.
  - Any `scene`, `cards` or `reset` URL key sets `main.debug_fresh_start = true` during the overlay's setup.

- [ ] **Step 1: Write the failing tests.** Create `tests/unit/test_resume.gd`:
```gdscript
extends GutTest

var main: Main
var pc: PhaseController
var dir := ""

func before_each() -> void:
	Balance.reset()
	dir = "user://test_saves/rs_%d" % Time.get_ticks_usec()

func after_each() -> void:
	SaveStore.with_dir(dir).wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_saves"))

## A fresh Main that boots from the store in `dir`, as the real boot does.
func _boot() -> void:
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	pc = main.phase_controller
	main.save_store = SaveStore.with_dir(dir)
	main.autosave.store = main.save_store
	main._boot()

## Play a first session with autosave on, then drop it (a "quit"). Always `await _session(...)`.
func _session(play: Callable) -> void:
	_boot()
	await play.call()
	remove_child(main)
	main.free()

func _fail_ticks() -> int:
	return int(ceil(Balance.ui.banner_time * Engine.physics_ticks_per_second)) + 3

func test_no_save_starts_a_new_game() -> void:
	_boot()
	assert_eq([pc.phase, GameState.day], [Phase.NIGHT, 1])

func test_day_resumes_at_home_with_same_state() -> void:
	await _session(func():
		pc.debug_skip_to_day()
		GameState.add_gold(GameState.next_level_cost("fence_w") + 17)
		GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w")))
	var gold := -1
	var s := SaveStore.with_dir(dir).read().state
	gold = int(s.gold)
	_boot()
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.gold, gold)
	assert_eq(int(GameState.buildings.fence_w.level), 1)
	assert_eq(main.hero.xz(), MapLayout.HOME)

func test_card_pick_resumes_with_same_offer_and_overlay() -> void:
	var offer: Array = []
	await _session(func():
		EventBus.wave_cleared.emit(2)
		offer.append_array(GameState.card_offer))  # lambdas capture locals by value; mutate, don't reassign
	_boot()
	assert_eq([pc.phase, pc.dawn_substate], [Phase.DAWN, "CARD_PICK"])
	assert_eq(Array(GameState.card_offer), offer)
	assert_true(main.card_overlay.visible)
	assert_true(main.hero.input.blocked)

func test_night_save_resumes_night1_start() -> void:
	await _session(func(): pass)  # the new-game save
	_boot()
	assert_eq([pc.phase, GameState.day], [Phase.NIGHT, 1])
	assert_eq(main.hero.xz(), MapLayout.NIGHT1_START)

func test_quit_mid_night_resumes_the_day_without_mercy() -> void:
	await _session(func():
		pc.debug_skip_to_day()
		pc.close_up())  # now at night 2; quit mid-night
	_boot()
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.night_fails, 0, "a quit adds no mercy (D-174)")

func test_quit_during_night1_retry_keeps_mercy() -> void:
	await _session(func():
		GameState.damage_diner(1e6)
		for i in _fail_ticks():
			await get_tree().physics_frame)
	await get_tree().process_frame
	_boot()
	assert_eq([pc.phase, GameState.night_fails], [Phase.NIGHT, 1])
	GameState.damage_diner(1e6)
	for i in _fail_ticks():
		await get_tree().physics_frame
	assert_eq(GameState.night_fails, 2)

func test_corrupt_primary_uses_backup_and_both_corrupt_starts_fresh() -> void:
	await _session(func():
		pc.debug_skip_to_day()
		GameState.add_gold(5)
		main.autosave.flush())
	var f := FileAccess.open(dir.path_join("save.json"), FileAccess.WRITE)
	f.store_string("{bad")
	f.close()
	_boot()
	assert_eq(pc.phase, Phase.DAY, "resumed from the backup")
	remove_child(main)
	main.free()
	for n in ["save.json", "save_bak.json"]:
		var g := FileAccess.open(dir.path_join(n), FileAccess.WRITE)
		g.store_string("{bad")
		g.close()
	_boot()
	assert_eq([pc.phase, GameState.day], [Phase.NIGHT, 1])

func test_newer_save_starts_fresh_and_keeps_it() -> void:
	GameState.new_game(3)
	var s := GameState.to_dict()
	s.resume_phase = "DAY"
	s.v = GameState.SCHEMA_VERSION + 1
	var newer := SaveCodec.encode(s, "future", 1)
	SaveStore.with_dir(dir).write(newer)
	_boot()
	assert_eq([pc.phase, GameState.day], [Phase.NIGHT, 1])
	pc.debug_skip_to_day()
	assert_eq(FileAccess.get_file_as_string(dir.path_join("save.json")), newer, "never overwritten")

func test_debug_fresh_start_wipes() -> void:
	await _session(func():
		pc.debug_skip_to_day()
		GameState.add_gold(1)
		main.autosave.flush())  # two writes: a backup exists
	assert_true(FileAccess.file_exists(dir.path_join("save_bak.json")))
	main = Main.create()
	add_child_autofree(main)
	main.save_store = SaveStore.with_dir(dir)
	main.autosave.store = main.save_store
	main.debug_fresh_start = true
	main._boot()
	assert_eq([main.phase_controller.phase, GameState.day], [Phase.NIGHT, 1])
	assert_false(FileAccess.file_exists(dir.path_join("save_bak.json")), "wiped: no backup of the old run")

func test_debug_r_key_wipes_and_restarts() -> void:
	if not OS.is_debug_build():
		pass_test("debug build only")
		return
	await _session(func():
		pc.debug_skip_to_day()
		GameState.add_gold(1)
		main.autosave.flush())
	_boot()
	assert_eq(pc.phase, Phase.DAY)
	main.get_node("DebugOverlay").handle_key(KEY_R)
	assert_eq([pc.phase, GameState.day], [Phase.NIGHT, 1])
	assert_false(FileAccess.file_exists(dir.path_join("save_bak.json")))
```
  `_session` awaits the lambda, so every caller must `await _session(...)`. Lambdas capture locals by value: mutate captured arrays (`append_array`), never reassign them.

- [ ] **Step 2: Run the unit tests.** Apply the wiring, then run `./run_tests.sh unit` and expect a FAIL.

- [ ] **Step 3: Implement.**
  - `world/phase_controller.gd`:
```gdscript
## Boot resume (S3 spec 5.3, D-176). DAY/NIGHT reuse the S1 restore contract; CARD_PICK re-opens the saved offer.
func resume_from(state: Dictionary) -> void:
	_fail_id += 1  # cancel any stale fail timer
	snapshot = state.duplicate(true)
	if String(state.resume_phase) != "CARD_PICK":
		_restore_snapshot()
		return
	wave_director.stop()
	traveler_spawner.stop()
	failing = false
	_recall_all()
	GameState.from_dict(state)
	dawn_substate = "CARD_PICK"
	phase = Phase.DAWN
	EventBus.hero_place_requested.emit(MapLayout.HOME)
	EventBus.phase_changed.emit(phase, GameState.day)
	GameState.set_card_offer(GameState.card_offer)
```
  - `ui/debug/debug_overlay.gd`:
    - In `setup()`, right after the query is parsed (the web branch), add a raw-key check that also runs when the query holds only unknown ids:
```gdscript
		var raw := str(JavaScriptBridge.eval("window.location.search", true))
		for key in ["scene=", "cards=", "reset="]:
			if raw.contains(key):
				main.debug_fresh_start = true
```
    - In `handle_key`, add
```gdscript
		KEY_R:
			if _main.save_store != null:
				_main.save_store.wipe()
			_main.phase_controller.start_new_game()
```

- [ ] **Step 4: Run the full suite.** Run `./run_tests.sh all` with the wiring applied and expect exit 0.

- [ ] **Step 5: Commit** without `world/main.gd`. Save the wiring as `/Users/ryan/ws/1.GAME/lst-wt/lst-s3t7-wiring.patch`.
- [ ] **Step 6 (main session):** apply the patch, run `./run_tests.sh all`, and amend it into the task commit before the reviewer pass. `debug_overlay.gd` uses `main.debug_fresh_start` and `save_store`, so every Main-based test is red until the patch is applied. Then open the Phase 3 PR.
```bash
git add world/phase_controller.gd ui/debug/debug_overlay.gd tests/unit/test_resume.gd
git commit -m "feat(save): boot resume (DAY, CARD_PICK, NIGHT), debug R and URL fresh start (Task S3-7)"
```

---

## Phase 4: Sims and results (`s3/p4-results`)

### Task 8: Sweep with mercy, and a mercy sim

**Files:**
- Modify: `tests/sim/sweep_runner.gd`, `tests/sim/test_night_sims.gd`

**Interfaces:**
- Produces:
  - The sweep retries up to 4 times, with mercy applied.
  - Two run-level values, printed on the final SWEEP line (not CSV columns): `first_fail_day` and `hard_break_day`.
  - A sim that checks mercy HP on a ParkedBot retry.

- [ ] **Step 1: Update the sweep.** In `tests/sim/sweep_runner.gd`:
  - Change the retry limit to `retries < 4`.
  - Replace the stale comment that begins "Retries are deterministic" with: "Retries run with mercy (S3, D-175): each retry of the same night is weaker, so a failed night can clear on a later retry."
  - Track `first_fail_day`: the first day where the first attempt failed.
  - Keep playing when a retry clears.
  - Set `hard_break_day` to the first day still failed after 4 retries, then stop.
  - The final line is `print("SWEEP first_fail_day=%d hard_break_day=%d target=%d±%d" % [...])`.
  - Keep the per-day rows. The `failed_retries` column already exists.
- [ ] **Step 2: Add the mercy sim.** Append to `tests/sim/test_night_sims.gd`:
```gdscript
func test_parked_retry_has_mercy_hp() -> void:
	h.start(SEED, ParkedBot)
	var r := await h.run_night()
	assert_true(r.failed)
	assert_true(await h.run_until(func(): return not h.main.phase_controller.failing, 5.0))
	assert_eq(GameState.night_fails, 1)
	await h.run_until(func(): return h.main.world.wave_director.alive_enemies().size() > 0, 15.0)
	var b: Boar = h.main.world.wave_director.alive_enemies()[0]
	assert_almost_eq(b.health.max_hp, Balance.data.enemy.hp * float(GameState.lane_plan[0].hp_mult) * GameState.mercy_factor(), 1e-4)
	assert_lt(b.health.max_hp, Balance.data.enemy.hp * float(GameState.lane_plan[0].hp_mult), "fewer hits per kill on the retry")
```
- [ ] **Step 3: Run the checks.** Run `./run_tests.sh all` and expect exit 0, with SIM SUITE under 60 s. Also run the sweep and paste the CSV and the SWEEP line.
- [ ] **Step 4: Commit.**
```bash
git add tests/sim
git commit -m "chore(sweep): retries with mercy; first_fail_day and hard_break_day; mercy sim (Task S3-8)"
```

### Task 9: Web smoke and results

**Files:**
- Create: `export/pw_resume.mjs`
- The main session writes the S3 spec results section and the REVIEW_QUEUE playtest questions.

- [ ] **Step 1: Write `export/pw_resume.mjs`.** It is modelled on `export/pw_check.mjs`, with the same Playwright loading from `LST_PW_DIR` and the same SwiftShader flags. Usage: `node export/pw_resume.mjs <debug_url_base> <out_dir> [android|desktop]`. All steps run in **one** browser context:
  1. Go to `<base>?cards=tank:1&scene=cardpick`. Wait until `window.LST_BUILD` is set, plus 12 s. Screenshot `1_pick.png`.
  2. Go to `<base>`, with no query. Wait 12 s. Screenshot `2_resumed_pick.png`. The overlay should still show the same offer, and the strip should read "TK1".
  3. Press `1`, wait 5 s, reload, and wait 12 s. Screenshot `3_resumed_day.png`: DAY at HOME, and the strip shows the picked card.
  4. Print `localStorage` keys that start with `lst:`, together with their lengths.
  5. Exit 1 on a page error.
- [ ] **Step 1b: Reset.** From S3 on, a plain URL resumes an old run from `localStorage`. Update `export/device_check.sh` and `export/pw_check.mjs` usage notes: debug URLs get `?reset=1` for a fresh start. Release URLs can't be reset; use a fresh browser profile.
- [ ] **Step 2: Run it** (main session) against the Phase 4 preview's `/debug/`. Also check the iOS Simulator: open step 1's URL and wait, then open step 2's URL. `simctl openurl` reuses Safari's origin storage. Take a screenshot, and read every PNG.
- [ ] **Step 3: Record the results** (main session):
  - Add an S3 spec "Results" section with the smoke-check results, the sweep line, and the unit and sim counts.
  - Append the spec §10 playtest questions to `docs/REVIEW_QUEUE.md` under "Final review playtest questions (S3)".
- [ ] **Step 4: Commit, then open the Phase 4 PR.**
```bash
git add export/pw_resume.mjs docs
git commit -m "test(web): resume smoke across reloads; S3 results (Task S3-9)"
```
