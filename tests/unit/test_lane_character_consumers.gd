extends GutTest
## E6 task 4 (D-282, D-286, D-287): the night plan goes through the lane character at tier 3. Consumers of extra groups are tested in test_wave_schedule / test_lane_planner.


func before_each() -> void:
	Balance.reset()

func after_each() -> void:
	Balance.reset()

func _h(v) -> String:
	return str(v).md5_text().substr(0, 8)

func _tier3_day(seed: int, d: int) -> void:
	GameState.new_game(seed)
	GameState.debug_set_tier(3, 17)
	GameState.day = d - 1
	GameState.advance_day()

## Tiers 1 and 2 are untouched: the character is {} and the plan is the planner's.
func test_lane_character_is_empty_below_tier_3() -> void:
	GameState.new_game(20260930)
	assert_eq(GameState.lane_character(), {}, "tier 1")
	GameState.debug_set_tier(2, 9)
	assert_eq(GameState.lane_character(), {}, "tier 2")
	var tb := Balance.data.tiers
	assert_eq(GameState.lane_plan, LanePlanner.plan(20260930, GameState.day, Balance.data.wave, 2, 9, tb), "tier 2 plan is the planner's")
	GameState.debug_set_tier(3, 17)
	assert_eq(GameState.lane_character(), LaneCharacter.for_run(20260930), "tier 3")

## Mutation: the plan skips apply, or is built from another seed, day or tier_day. (apply is idempotent by design, so a second
## application cannot be detected here; the boss mark is added later by PhaseController, outside GameState.lane_plan.)
func test_flag_on_tier3_plan_is_the_planner_through_apply() -> void:
	var tb := Balance.data.tiers
	var found_extra := false
	for s in [20260930, 1, 2, 3]:
		for d in range(17, 25):
			_tier3_day(s, d)
			var want := LaneCharacter.apply(LanePlanner.plan(s, d, Balance.data.wave, 3, 17, tb), LaneCharacter.for_run(s), tb)
			assert_eq(GameState.lane_plan, want, "seed %d day %d" % [s, d])
			for w in GameState.lane_plan:
				found_extra = found_extra or w.has("extra")
	assert_true(found_extra, "the scan met at least one extra group")

## Tier-up at dawn, load-free: complete_tier_up builds tier 3's first plan through the same function.
func test_tier_up_to_tier_3_goes_through_the_character() -> void:
	var tb := Balance.data.tiers
	GameState.new_game(20260930)
	GameState.debug_set_tier(2, 9)
	GameState.boss_pending = true
	GameState.day = 14
	GameState.complete_tier_up()
	assert_eq(GameState.tier, 3)
	var raw := LanePlanner.plan(20260930, GameState.day, Balance.data.wave, 3, GameState.tier_day, tb)
	var want := LaneCharacter.apply(raw, LaneCharacter.for_run(20260930), tb)
	assert_ne(want, raw, "setup: the character changes this night, so the plan below cannot be the planner's own")
	assert_eq(GameState.lane_plan, want)

# --- a real night -----------------------------------------------------------------------------------------------------

var _seen := {}
var _log: Array = []
var _tick := 0
var _wave_start := {}
var _growth: Array = []
var _cleared := false
var _peak := 0
var _wd: WaveDirector

func _on_spawned_out(_w: int) -> void:
	_record()  # the last spawn happens in this very tick: look before the wave dies
	_wd.debug_kill_all()

func _record() -> void:
	for b in _wd.alive_enemies():
		if not _seen.has(b.spawn_index):  # pooled nodes are reused: the night's spawn_index is the identity
			_seen[b.spawn_index] = true
			_log.append({"w": _wd.wave_index, "lane": b.lane, "kind": b.kind, "tick": _tick})
	_peak = maxi(_peak, _wd.alive_count())

func _on_wave_started(w: int, _m: StringName, _s: StringName) -> void:
	_wave_start[w] = _tick

func _on_wave_cleared(w: int) -> void:
	_cleared = w == 2

## First (seed, day) with an extra group in some wave AND a wave whose brutes the unapplied plan did not put on the siege lane.
func _scan_night() -> Dictionary:
	var tb := Balance.data.tiers
	for s in [20260930, 1, 2, 3, 4, 5, 6, 7, 8]:
		var c := LaneCharacter.for_run(s)
		for d in range(17, 41):
			var raw := LanePlanner.plan(s, d, Balance.data.wave, 3, 17, tb)
			var applied := LaneCharacter.apply(raw, c, tb)
			var has_extra := false
			var diverted := false
			for i in raw.size():
				has_extra = has_extra or applied[i].has("extra")
				var b := int(raw[i].brute_main) + int(raw[i].brute_side)
				if b > 0 and String(raw[i].main) != c.siege and String(raw[i].side) != c.siege:
					diverted = true
			if has_extra and diverted:
				return {"seed": s, "day": d}
	return {}

## Mutations: an extra group is not scheduled (its hares never spawn on the hare lane); it spawns with the main group (delay 0);
## brutes keep their unapplied lane; the enemy, steak or projectile pool is too small for a third parallel group.
func test_a_real_night_spawns_brutes_on_the_siege_lane_extra_groups_with_the_side_delay_and_grows_no_pool() -> void:
	var scan := _scan_night()
	assert_false(scan.is_empty(), "the scan found a night with an extra group and a diverted brute wave")
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	GameState.new_game(scan.seed)
	GameState.debug_set_tier(3, 17)
	GameState.day = scan.day - 1
	GameState.advance_day()
	var plan: Array = GameState.lane_plan
	var c := GameState.lane_character()
	var w: World = main.world
	for p in [w.enemy_pool, w.steak_pool, w.projectile_pool]:
		var pool: NodePool = p
		pool.grew.connect(func(n: int): _growth.append("%s -> %d" % [pool.name, n]))
	var wd := w.wave_director
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	_wd = wd
	EventBus.wave_spawned_out.connect(_on_spawned_out)  # the whole wave stands alive at once, then dies together
	wd.start_night(plan)
	var wb := Balance.data.wave
	var guard := 0
	while not _cleared and guard < 14000:
		await get_tree().physics_frame
		_tick += 1
		guard += 1
		_record()
	EventBus.wave_spawned_out.disconnect(_on_spawned_out)
	EventBus.wave_started.disconnect(_on_wave_started)
	EventBus.wave_cleared.disconnect(_on_wave_cleared)
	assert_true(_cleared, "the night ran to the last wave's clear")
	var raw_plan := LanePlanner.plan(scan.seed, scan.day, Balance.data.wave, 3, 17, Balance.data.tiers)
	var saw_extra := false
	var saw_diverted := false
	for i in plan.size():
		var got: Array = _log.filter(func(e): return e.w == i)
		# lanes and kinds against the PLAN's own fields (not against WaveSchedule.build, which the director also calls)
		var want_counts := {}
		var add := func(lane: String, kind: String, n: int) -> void:
			if n > 0:
				want_counts["%s/%s" % [lane, kind]] = int(want_counts.get("%s/%s" % [lane, kind], 0)) + n
		var pw: Dictionary = plan[i]
		add.call(String(pw.main), "boar", int(pw.main_count) - int(pw.fast_main))
		add.call(String(pw.main), "hare", int(pw.fast_main))
		add.call(String(pw.main), "brute", int(pw.brute_main))
		add.call(String(pw.side), "boar", int(pw.side_count) - int(pw.fast_side))
		add.call(String(pw.side), "hare", int(pw.fast_side))
		add.call(String(pw.side), "brute", int(pw.brute_side))
		for ex in pw.get("extra", []):
			add.call(String(ex.lane), "boar", int(ex.count) - int(ex.fast))
			add.call(String(ex.lane), "hare", int(ex.fast))
		var got_counts := {}
		for e in got:
			var k := "%s/%s" % [e.lane, e.kind]
			got_counts[k] = int(got_counts.get(k, 0)) + 1
			if e.kind == &"brute":
				assert_eq(String(e.lane), String(c.siege), "wave %d: a brute off the siege lane" % i)
		assert_eq(got_counts, want_counts, "wave %d: lanes and kinds as planned" % i)
		for ex in pw.get("extra", []):
			saw_extra = true
			assert_false(String(ex.lane) in [String(pw.main), String(pw.side)], "wave %d: the extra group has its own lane" % i)
			var on_lane: Array = got.filter(func(e): return e.lane == String(ex.lane))
			assert_eq(on_lane.size(), int(ex.count), "wave %d: the extra group's size" % i)
			assert_eq(on_lane.filter(func(e): return e.kind == &"hare").size(), int(ex.fast), "wave %d: the extra group's hares" % i)
			assert_false(on_lane.is_empty(), "wave %d: the extra group spawned (so its first tick exists)" % i)
			var first_tick: int = on_lane.map(func(e): return e.tick).min()
			var start_s := float(first_tick - int(_wave_start[i])) / 60.0
			assert_almost_eq(start_s, wb.side_group_delay, 0.1, "wave %d: the extra group starts at the side delay (nothing earlier)" % i)
		# a wave whose drawn side lane was replaced by the siege lane: compare the unapplied and the applied plan
		var brutes := int(pw.brute_main) + int(pw.brute_side)
		if brutes > 0 and String(raw_plan[i].side) != String(pw.side) and String(pw.side) == String(c.siege):
			saw_diverted = true
	assert_true(saw_extra, "the night had an extra group")
	assert_true(saw_diverted, "the night had a wave whose side lane was replaced by the siege lane")
	assert_eq(_growth, [], "no pool grew during the night")
	var pool_size: int = World.pool_sizes(Balance.data).enemy
	var biggest := 0
	for wv in plan:
		biggest = maxi(biggest, _total(wv))
	# Counted from the PLAN, not from WaveSchedule.build: the whole biggest wave, its third group included, stood alive at once
	# (the test kills a wave only after it has fully spawned). Mutation: a wave_spawned_out that fires before the extra group ends.
	assert_eq(_peak, biggest, "the whole biggest wave stood alive at once")
	assert_lte(_peak, pool_size, "the enemy pool covers the most alive at once (a third group spawns in parallel, not on top)")

## The pools are sized from a night's TOTALS and one wave at a time (waves never overlap), and apply keeps every wave's
## total: so pool_sizes needs no change. Mutation: an apply that adds or drops enemies.
func test_apply_keeps_every_waves_total_and_the_enemy_pool_covers_the_biggest_wave() -> void:
	var tb := Balance.data.tiers
	var cap: int = World.pool_sizes(Balance.data).enemy
	for s in [20260930, 1, 2, 3, 4, 5]:
		var c := LaneCharacter.for_run(s)
		for d in range(17, 41):
			var raw := LanePlanner.plan(s, d, Balance.data.wave, 3, 17, tb)
			var applied := LaneCharacter.apply(raw, c, tb)
			for i in raw.size():
				assert_eq(_total(applied[i]), _total(raw[i]), "seed %d day %d wave %d" % [s, d, i])
				assert_lte(_total(applied[i]), cap, "pool covers wave %d" % i)

func _total(w: Dictionary) -> int:
	var n := int(w.main_count) + int(w.side_count) + int(w.brute_main) + int(w.brute_side)
	for e in w.get("extra", []):
		n += int(e.count)
	return n
