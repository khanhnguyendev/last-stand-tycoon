extends SceneTree
## Writes export/fixtures/night3_start.save.json (resume_phase NIGHT: resume_from enters night 3 at once) and
## night3_closeup.save.json (resume_phase DAY, day-peak reading) from a PlannerBot run (seed 20260930), using the
## close-up snapshot that precedes night 3. Run: "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/make_save.gd -- --fixture=day3_counter5|night3|tier|tier3|tier3_branch_day
## `tier` (E5 spec 8.1) runs a TierBot from seed 20260930 to the first boss-night close-up and writes boss_night_tier1,
## boss_only, tier2_night1, tier2_full and tier2_night. `tier3` (E5 tier 3, Task 23, schema 6) builds its eight states from the committed
## tier2_full fixture and real play: fixtures 1, 2 and 5 (the Baron close-up, the same without yard towers, the cap night) come from a TierBot
## run of about 155 s on seed 20260930; the others are constructed. The in-script "built twice" check proves the construction is pure; two runs
## giving identical md5 prove the whole thing deterministic. It writes
## tier3_baron_full, tier3_baron_no_yard, tier3_baron_alone, tier3_night1 and tier3_cap_<all_a|all_b|mixed|threat>. `tier3_branch_day` (checkpoint video, recording aid) reads the committed tier3_night1 through the real codec, gives tower_sw and fence_sw the
## state of tower_w and fence_w (level 3) and 1500 gold, so a tier-3 DAY has several max-level buildings and the gold to buy branches, and writes
## export/fixtures/tier3_branch_day.save.json (not committed: reproduce it with this option). `day3_counter5` writes only that fixture. `night3` rewrites the two night3 fixtures at the current schema and must
## not be used while they serve as schema-3 migration tests. No argument (or an unknown one) is a usage error.

var _done := false
var _fixture := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fixture="):
			_fixture = a.trim_prefix("--fixture=")
	if _fixture != "day3_counter5" and _fixture != "night3" and _fixture != "tier" and _fixture != "tier3" and _fixture != "tier3_branch_day":
		push_error("usage: -- --fixture=day3_counter5|night3|tier|tier3|tier3_branch_day")
		quit(2)
		return
	if _fixture == "tier":
		await _run_tier()
		return
	if _fixture == "tier3":
		quit(0 if await _run_tier3() else 1)
		return
	if _fixture == "tier3_branch_day":
		quit(0 if _run_branch_day() else 1)
		return
	root.get_node("Balance").reset()
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	var bot = load("res://actors/bots/planner_bot.gd").new()
	main.add_child(bot)
	bot.setup(main)
	root.get_node("EventBus").snapshot_taken.connect(_on_snapshot)
	main.phase_controller.start_new_game(20260930)
	for i in 60 * 60 * 30:
		if _done:
			return
		await physics_frame
	push_error("no night-3 close-up within 30 min of game time")
	quit(1)

func _on_snapshot(state: Dictionary) -> void:
	# Night N runs with GameState.day == N (new_game sets 1; advance_day at dawn), so the close-up before
	# night 3 carries day == 3.
	if _done or String(state.resume_phase) != "DAY" or int(state.day) != 3:
		return
	_done = true
	if _fixture == "day3_counter5":
		# E1 perf: day 3 with a level 5 counter (queue_max 9; stocked, so the queue fills once the 42 steaks are sold). The night3_* fixtures stay at schema 3.
		var s5: Dictionary = state.duplicate(true)
		s5.resume_phase = "DAY"
		var sb5 = root.get_node("Balance").data.stations
		s5.stations["counter"] = {"level": sb5.max_level, "paid": 0}
		s5.counter_steaks = sb5.counter_capacity[sb5.max_level]  # stocked: travelers are served, not only queued
		_write("day3_counter5", s5)
		quit(0)
		return
	for pair in [["night3_start", "NIGHT"], ["night3_closeup", "DAY"]]:
		var s: Dictionary = state.duplicate(true)
		s.resume_phase = pair[1]
		_write(pair[0], s)
	quit(0)

func _write(fixture: String, s: Dictionary) -> void:
	var codec = load("res://core/save_codec.gd")
	var path := ProjectSettings.globalize_path("res://export/fixtures/%s.save.json" % fixture)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(codec.encode(s, "fixture", 0))
	f.close()
	print("wrote ", path)

# --- E5 tier fixtures (spec 8.1) -----------------------------------------------------------------------------------

var _base: Dictionary = {}

func _on_tier_snapshot(state: Dictionary) -> void:
	if _base.is_empty() and String(state.resume_phase) == "DAY" and bool(state.boss_pending):
		_base = state.duplicate(true)

func _levels(ids: Array) -> String:
	var gs = root.get_node("GameState")
	var parts: Array = []
	for id in ids:
		if gs.buildings.has(id):
			parts.append("%s:%d" % [id, int(gs.buildings[id].level)])
	return "|".join(parts)

func _run_tier() -> void:
	var gs = root.get_node("GameState")
	root.get_node("Balance").reset()
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	var bot = load("res://actors/bots/tier_bot.gd").new()
	main.add_child(bot)
	bot.setup(main)
	root.get_node("EventBus").snapshot_taken.connect(_on_tier_snapshot)
	main.phase_controller.start_new_game(20260930)
	var last_day := -1
	for i in 60 * 3600 * 4:  # 4 hours of game time
		if not _base.is_empty():
			break
		await physics_frame
		if int(gs.day) != last_day:
			last_day = int(gs.day)
			var sts := []
			for sid in gs.stations:
				sts.append("%s:%d" % [sid, int(gs.stations[sid].level)])
			print("day=%d tier=%d gold=%d tier_paid=%d defense=%s stations=%s fails=%d" % [gs.day, gs.tier, gs.gold,
				gs.tier_paid, _levels(load("res://core/map_layout.gd").ALL_SPOT_IDS), "|".join(sts), gs.night_fails])
	if _base.is_empty():
		push_error("the TierBot never paid the tier in 4 hours of game time: day=%d tier_paid=%d gold=%d stuck=%d tier_ups=%d" % [
			gs.day, gs.tier_paid, gs.gold, bot.stuck_count, bot.tier_ups])
		quit(1)
		return
	print("base: close-up of day %d, tier_ups=%d, boss_nights_won=%d" % [int(_base.day), bot.tier_ups, bot.boss_nights_won])
	# stop the live game so the derivation below can use GameState without side effects
	main.get_parent().remove_child(main)
	main.free()
	root.get_node("EventBus").snapshot_taken.disconnect(_on_tier_snapshot)
	quit(0 if _write_tier_fixtures(_base) else 1)

func _plan(s: Dictionary) -> Array:
	var bd = root.get_node("Balance").data
	return load("res://core/lane_planner.gd").plan(int(s.run_seed), int(s.day), bd.wave, int(s.tier), int(s.tier_day), bd.tiers)

func _common(s: Dictionary) -> void:
	s.gold_pile = 0
	s.carried_steaks = 0
	s.card_offer = []

## Builds all five states, validates every one, and only then writes. False (nothing written) on any failure.
func _write_tier_fixtures(base: Dictionary) -> bool:
	var bd = root.get_node("Balance").data
	var gs = root.get_node("GameState")
	var tb = bd.tiers
	var boss := base.duplicate(true)
	boss.resume_phase = "NIGHT"
	boss.night_fails = 0
	_common(boss)
	var out: Array = [["boss_night_tier1", boss]]

	var only := boss.duplicate(true)
	for id in only.buildings:
		only.buildings[id] = {"level": 0, "paid": 0, "hp": 0.0, "branch": "", "branch_paid": {}}
	only.cards = {}
	only.guards = {}
	only.card_offer = []
	for w in only.lane_plan:
		w.main_count = 0
		w.side_count = 0
		w.fast_main = 0
		w.fast_side = 0
		w.side = ""
	only.lane_plan[only.lane_plan.size() - 1].boss = true
	only.boss_pending = true
	out.append(["boss_only", only])

	# tier 2 as the dawn after a won boss night leaves it. Done through a real GameState round trip:
	# from_dict, heal_for_dawn (diner, fences and guards to full HP), to_dict.
	var t2 := base.duplicate(true)
	t2.tier = 2
	t2.boss_pending = false
	t2.tier_paid = 0
	t2.day = int(base.day) + 1
	t2.tier_day = t2.day
	t2.night_fails = 0
	t2.resume_phase = "NIGHT"
	for id in load("res://core/map_layout.gd").TIER_SPOTS[2]:
		t2.buildings[id] = {"level": 0, "paid": 0, "hp": 0.0, "branch": "", "branch_paid": {}}
	t2.lane_plan = _plan(t2)
	gs.from_dict(t2)
	gs.heal_for_dawn()
	t2 = gs.to_dict()
	t2.resume_phase = "NIGHT"
	_common(t2)
	out.append(["tier2_night1", t2])

	var full := t2.duplicate(true)
	full.day = int(t2.tier_day) + int(tb.fast_ramp_days[2])
	if load("res://core/wave_math.gd").pressure(int(full.day), 2, int(full.tier_day), tb) != int(tb.tier_cap[2]):
		push_error("tier2_full is not at the pressure cap")
		return false
	var ml: int = bd.build.max_level
	for id in full.buildings:
		full.buildings[id] = {"level": ml, "paid": 0, "hp": gs.fence_max_hp(ml) if load("res://core/map_layout.gd").spot_kind(id) == "fence" else 0.0, "branch": "", "branch_paid": {}}
	full.lane_plan = _plan(full)
	out.append(["tier2_full", full])
	out.append(["tier2_night", full])
	var codec = load("res://core/save_codec.gd")
	for pair in out:
		var why: String = codec.validate(pair[1], bd)
		if why != "":
			push_error("fixture %s invalid: %s" % [pair[0], why])
			return false
	for pair in out:
		_write(pair[0], pair[1])
	return true

# --- E5 tier-3 fixtures (Task 23, spec 9.4) --------------------------------------------------------------------------
# Fixtures 1, 2 and 5 come from a TierBot real-play run (the Baron close-up, the same without yard towers, the four cap nights); 3 and 4
# are constructed from the committed tier2_full fixture (decoded and migrated to schema 6 through the real codec): the
# tier-1 boss night was won on day 12, tier 2 entered on day 13 (tier_day 13), pressure caps on day 16 (the fixture's day).
# Stations (counter 4, freezer 4), cards (archer 2, tank 5, hero_damage 3, gold_per_steak 1), the tank guard and gold 47 are
# the bot run's, kept as they are.

func _load_tier2_full() -> Dictionary:
	var text := FileAccess.get_file_as_string("res://export/fixtures/tier2_full.save.json")
	var gs = root.get_node("GameState")
	var r: Dictionary = load("res://core/save_codec.gd").decode(text, int(gs.SCHEMA_VERSION), root.get_node("Balance").data)
	if not bool(r.ok):
		push_error("tier2_full does not decode: " + String(r.reason))
		return {}
	return r.state

func _full_buildings(s: Dictionary, ids: Array, branches: Dictionary) -> void:
	var gs = root.get_node("GameState")
	var ml: int = root.get_node("Balance").data.build.max_level
	for id in ids:
		var br: String = String(branches.get(id, ""))
		var fence: bool = load("res://core/map_layout.gd").spot_kind(id) == "fence"
		s.buildings[id] = {"level": ml, "paid": 0, "hp": gs.fence_max_hp(ml, StringName(br)) if fence else 0.0, "branch": br, "branch_paid": {}}

## Every fixture as [stem, state, description], built from scratch each call.
func _build_tier3(real_baron: Dictionary, real_cap: Dictionary) -> Array:
	var bd = root.get_node("Balance").data
	var planner = load("res://core/lane_planner.gd")
	var layout = load("res://core/map_layout.gd")
	var base := _load_tier2_full()
	if base.is_empty():
		return []
	var out: Array = []
	# (0) not written: the constructed Baron night, full tier-2 build (the base of fixtures 3 and 4): tier 2, day 16 (the tier-2 cap), the sign paid, every tier-1 and yard spot at level 3
	var baron := base.duplicate(true)
	baron.resume_phase = "NIGHT"
	baron.night_fails = 0
	baron.boss_pending = true
	baron.tier_paid = 0
	_common(baron)
	_full_buildings(baron, layout.spots_for_tier(2), {})
	baron.diner_hp = float(bd.build.diner_max_hp)
	baron.lane_plan = planner.with_boss(_plan(baron))
	# (1) REAL PLAY: the close-up snapshot of the Baron night (tier 2, sign paid) of a TierBot run, resumed at NIGHT
	var real := real_baron.duplicate(true)
	real.resume_phase = "NIGHT"
	real.night_fails = 0
	_common(real)
	out.append(["tier3_baron_full", real, "real play (TierBot, seed 20260930, threat) at the close-up of the Baron night; resume NIGHT"])
	# (2) the same without the yard towers
	var noyard := real.duplicate(true)
	for id in layout.TIER_SPOTS[2]:
		noyard.buildings[id] = {"level": 0, "paid": 0, "hp": 0.0, "branch": "", "branch_paid": {}}
	out.append(["tier3_baron_no_yard", noyard, "(1) with tower_w and tower_e at level 0"])
	# (3) the Baron alone: no building, no card, no guard, no other enemy (the slice-1 boss_only recipe, at tier 2)
	var alone := baron.duplicate(true)  # constructed from tier2_full, not from the real run
	for id in alone.buildings:
		alone.buildings[id] = {"level": 0, "paid": 0, "hp": 0.0, "branch": "", "branch_paid": {}}
	alone.cards = {}
	alone.guards = {}
	for w in alone.lane_plan:
		w.main_count = 0
		w.side_count = 0
		w.fast_main = 0
		w.fast_side = 0
		w.side = ""
	out.append(["tier3_baron_alone", alone, "constructed: (0) with no building, card or guard; every wave empty, the Baron on the last"])
	# (4) the first tier-3 night: the dawn after the Baron night (day 17, tier_day 17); the two new spots unbuilt, the rest full
	var t3 := baron.duplicate(true)
	t3.tier = 3
	t3.boss_pending = false
	t3.day = int(baron.day) + 1
	t3.tier_day = t3.day
	for id in layout.TIER_SPOTS[3]:
		t3.buildings[id] = {"level": 0, "paid": 0, "hp": 0.0, "branch": "", "branch_paid": {}}
	t3.lane_plan = _plan(t3)
	# resume DAY: the bot plays the first tier-3 day (builds the two new spots) and then the night. Gold 47 + the Baron's 150 steaks sold
	# at 3 gold each = 497, which pays both new spots to level 3 (tower 40+80+160, fence 20+40+80 = 420) with a little left.
	t3.resume_phase = "DAY"
	t3.gold = int(baron.gold) + int(bd.monsters.stats(&"baron").steaks_per_kill) * int(bd.economy.gold_per_steak)
	out.append(["tier3_night1", t3, "constructed: (0) one dawn later, tier 3, resume DAY; gold 47 + 150 Baron steaks x 3; tower_sw and fence_sw unbuilt; no branches"])
	# (5) REAL PLAY: the close-up of a tier-3 cap night at least 5 nights after the cap was first reached, resumed at NIGHT; one copy per policy
	var tb = bd.tiers
	var spots: Array = layout.spots_for_tier(3)
	for policy in load("res://actors/bots/tier_bot.gd").POLICIES:
		var cap := real_cap.duplicate(true)
		cap.resume_phase = "NIGHT"
		cap.night_fails = 0
		_common(cap)
		if load("res://core/wave_math.gd").pressure(int(cap.day), 3, int(cap.tier_day), tb) != int(tb.tier_cap[3]):
			push_error("tier3_cap_%s is not at the pressure cap" % policy)
			return []
		var choice: Dictionary = load("res://actors/bots/tier_bot.gd").branch_choices(policy, spots, cap.lane_plan, 3)
		for id in spots:
			if int(cap.buildings[id].level) != int(bd.build.max_level):
				push_error("tier3_cap_%s: %s is not at max level in the real-play state (level %d)" % [policy, id, int(cap.buildings[id].level)])
				return []
		_full_buildings(cap, spots, choice)
		out.append(["tier3_cap_" + policy, cap, "real play (TierBot, seed 20260930) at the close-up of cap night day %d (pressure %d); branches set by TierBot.branch_choices(%s, tonight's plan)" % [int(cap.day), tb.tier_cap[3], policy]])
	return out

var _real_baron: Dictionary = {}
var _real_cap: Dictionary = {}
var _cap_first_day := -1

func _on_t3_snapshot(state: Dictionary) -> void:
	if String(state.resume_phase) != "DAY":
		return
	var bd = root.get_node("Balance").data
	if _real_baron.is_empty() and bool(state.boss_pending) and int(state.tier) == 2:
		_real_baron = state.duplicate(true)
	if int(state.tier) == 3 and not bool(state.boss_pending):
		var at_cap: bool = load("res://core/wave_math.gd").pressure(int(state.day), 3, int(state.tier_day), bd.tiers) == int(bd.tiers.tier_cap[3])
		if at_cap and _cap_first_day < 0:
			_cap_first_day = int(state.day)
		if at_cap and _real_cap.is_empty() and int(state.day) >= _cap_first_day + 5:
			_real_cap = state.duplicate(true)

## Plays the tier bot (seed 20260930, policy threat) until both real-play states are captured.
func _play_real() -> bool:
	var gs = root.get_node("GameState")
	root.get_node("Balance").reset()
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	var bot = load("res://actors/bots/tier_bot.gd").new()
	main.add_child(bot)
	bot.setup(main)
	root.get_node("EventBus").snapshot_taken.connect(_on_t3_snapshot)
	main.phase_controller.start_new_game(20260930)
	for i in 60 * 3600 * 4:
		if not _real_baron.is_empty() and not _real_cap.is_empty():
			break
		await physics_frame
	var ok := not _real_baron.is_empty() and not _real_cap.is_empty()
	if not ok:
		push_error("real play did not reach both states: baron %s cap %s (day %d tier %d)" % [not _real_baron.is_empty(), not _real_cap.is_empty(), gs.day, gs.tier])
	print("real play: Baron night close-up day %d; tier-3 cap night day %d (cap first reached day %d)" % [int(_real_baron.get("day", -1)), int(_real_cap.get("day", -1)), _cap_first_day])
	main.get_parent().remove_child(main)
	main.free()
	root.get_node("EventBus").snapshot_taken.disconnect(_on_t3_snapshot)
	return ok

func _run_tier3() -> bool:
	if not await _play_real():
		return false
	var bd = root.get_node("Balance").data
	var codec = load("res://core/save_codec.gd")
	var a := _build_tier3(_real_baron, _real_cap)
	var b := _build_tier3(_real_baron, _real_cap)
	if a.is_empty() or a.size() != b.size():
		push_error("tier3 fixtures were not built")
		return false
	for i in a.size():
		if codec.encode(a[i][1], "fixture", 0) != codec.encode(b[i][1], "fixture", 0):
			push_error("fixture %s is not deterministic (two builds differ)" % a[i][0])
			return false
		var why: String = codec.validate(a[i][1], bd)
		if why != "":
			push_error("fixture %s invalid: %s" % [a[i][0], why])
			return false
	for item in a:
		var s: Dictionary = item[1]
		var blds := []
		for id in load("res://core/map_layout.gd").ALL_SPOT_IDS:
			if s.buildings.has(id) and int(s.buildings[id].level) > 0:
				blds.append("%s:%d%s" % [id, int(s.buildings[id].level), ("/" + String(s.buildings[id].branch)) if String(s.buildings[id].branch) != "" else ""])
		print("FIXTURE %s v=%d day=%d tier=%d tier_day=%d gold=%d phase=%s boss=%s pressure=%d | %s | %s" % [item[0], int(s.v), int(s.day), int(s.tier),
			int(s.tier_day), int(s.gold), s.resume_phase, s.lane_plan[s.lane_plan.size() - 1].boss, load("res://core/wave_math.gd").pressure(int(s.day), int(s.tier), int(s.tier_day), bd.tiers),
			" ".join(blds), item[2]])
		_write(item[0], s)
	return true

## The video's branch-day state: tier3_night1 (decoded through the real codec) with the south-west pair built like the west pair, and 1500 gold.
func _run_branch_day() -> bool:
	var text := FileAccess.get_file_as_string("res://export/fixtures/tier3_night1.save.json")
	var bd = root.get_node("Balance").data
	var codec = load("res://core/save_codec.gd")
	var r: Dictionary = codec.decode(text, int(root.get_node("GameState").SCHEMA_VERSION), bd)
	if not bool(r.ok):
		push_error("tier3_night1 does not decode: " + String(r.reason))
		return false
	var s: Dictionary = r.state
	for pair in [["fence_sw", "fence_w"], ["tower_sw", "tower_w"]]:
		s.buildings[pair[0]] = (s.buildings[pair[1]] as Dictionary).duplicate(true)
	s.gold = 1500
	var why: String = codec.validate(s, bd)
	if why != "":
		push_error("fixture tier3_branch_day invalid: " + why)
		return false
	_write("tier3_branch_day", s)
	return true
