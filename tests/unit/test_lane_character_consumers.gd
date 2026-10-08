extends GutTest
## E6 task 4 (D-282, D-286, D-287): the night plan goes through the lane character at tier 3 with the flag on; with the flag off
## the plan and the spawn schedule are what they were. Consumers of extra groups are tested in test_wave_schedule / test_lane_planner.

## Captured from the code BEFORE task 4 (git 61593de), flag off: for each seed and day 17 to 24, tier 3 entered on day 17,
## [seed, day, md5(str(plan))[:8], [md5(str(WaveSchedule.build(wave, wb, tb, 3)))[:8] per wave], hash of the last wave's boss-marked schedule].
## Method: a throwaway GUT test ran new_game(seed); debug_set_tier(3, 17); day = d - 1; advance_day() and printed these.
const OFF_PINS := [
	[20260930, 17, "2df1d158", ["b9ee9dba", "162baeb1", "da77ef66"], "da77ef66"],
	[20260930, 18, "ec27e861", ["84b8805b", "01ecb89f", "a3da967f"], "a3da967f"],
	[20260930, 19, "cb53fd8c", ["efdae129", "f79b0441", "686a3e03"], "686a3e03"],
	[20260930, 20, "4ab5aa15", ["09401460", "86c41149", "1a391d24"], "1a391d24"],
	[20260930, 21, "32e56c2d", ["7ee0a79d", "df4e8126", "31f8f8f3"], "31f8f8f3"],
	[20260930, 22, "194934c9", ["09401460", "9b0c2df8", "31f8f8f3"], "31f8f8f3"],
	[20260930, 23, "312b326e", ["11662acd", "b19d74dc", "59dc095b"], "59dc095b"],
	[20260930, 24, "496df575", ["11662acd", "86c41149", "686a3e03"], "686a3e03"],
	[1, 17, "bad80daa", ["84b8805b", "1fe08b3b", "bbf77a68"], "bbf77a68"],
	[1, 18, "030e24ad", ["b9ee9dba", "b19d74dc", "69996018"], "69996018"],
	[1, 19, "b613285f", ["f94b8c42", "b97d69cd", "bbf77a68"], "bbf77a68"],
	[1, 20, "7dc46a60", ["f94b8c42", "125bf4ab", "bbf77a68"], "bbf77a68"],
	[1, 21, "4ba2896d", ["f51c080f", "01ecb89f", "7c6bfe48"], "7c6bfe48"],
	[1, 22, "2d8341a0", ["7fd255cf", "fd897955", "caa4464a"], "caa4464a"],
	[1, 23, "386c7834", ["efdae129", "125bf4ab", "686a3e03"], "686a3e03"],
	[1, 24, "47e9f9db", ["11662acd", "ec388a67", "1a391d24"], "1a391d24"],
	[2, 17, "4bb98452", ["9a062177", "0aa3def5", "da77ef66"], "da77ef66"],
	[2, 18, "90ba8860", ["04b2f783", "125bf4ab", "5f5f2f39"], "5f5f2f39"],
	[2, 19, "bb21f5cc", ["9c05150a", "9b0c2df8", "bbf77a68"], "bbf77a68"],
	[2, 20, "e46d56d0", ["c981af27", "647ba250", "59dc095b"], "59dc095b"],
	[2, 21, "b6c3bfca", ["11662acd", "145f17ac", "5f5f2f39"], "5f5f2f39"],
	[2, 22, "8aebb752", ["9c05150a", "145f17ac", "5f5f2f39"], "5f5f2f39"],
	[2, 23, "3ab20bd1", ["11662acd", "145f17ac", "caa4464a"], "caa4464a"],
	[2, 24, "a7540778", ["846fb800", "fd897955", "caa4464a"], "caa4464a"],
]

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

## Mutation: apply is called with the flag off (the plan, hence its hash, changes for any night with brutes or hares).
func test_flag_off_tier3_plan_and_schedule_are_what_they_were() -> void:
	var tb := Balance.data.tiers
	for pin in OFF_PINS:
		_tier3_day(pin[0], pin[1])
		var tag := "seed %d day %d" % [pin[0], pin[1]]
		assert_eq(_h(GameState.lane_plan), pin[2], "%s: plan" % tag)
		var sched: Array = GameState.lane_plan.map(func(w): return _h(WaveSchedule.build(w, Balance.data.wave, tb, 3)))
		assert_eq(sched, pin[3], "%s: schedules" % tag)
		for w in GameState.lane_plan:
			assert_false(w.has("extra"), "%s: no extra key with the flag off" % tag)
		var bp := LanePlanner.with_boss(GameState.lane_plan)
		assert_eq(_h(WaveSchedule.build(bp[bp.size() - 1], Balance.data.wave, tb, 3)), pin[4], "%s: boss-marked last wave" % tag)

## One plan spelled out (seed 20260930, day 17, wave 0), so a hash mismatch above can be read.
func test_flag_off_wave_literal() -> void:
	_tier3_day(20260930, 17)
	assert_eq(GameState.lane_plan[0], {"main": "sw", "side": "west", "main_count": 10, "side_count": 9, "hp_mult": 2.65, "fast_main": 4,
		"fast_side": 3, "boss": false, "brute_main": 0, "brute_side": 0})
	assert_eq(GameState.lane_plan.size(), 3)

## Tiers 1 and 2 with the flag ON are untouched: the character is {} and the plan is the planner's.
func test_lane_character_is_empty_below_tier_3_and_with_the_flag_off() -> void:
	Balance.data.tiers.retune_enabled = true
	GameState.new_game(20260930)
	assert_eq(GameState.lane_character(), {}, "tier 1")
	GameState.debug_set_tier(2, 9)
	assert_eq(GameState.lane_character(), {}, "tier 2")
	var tb := Balance.data.tiers
	assert_eq(GameState.lane_plan, LanePlanner.plan(20260930, GameState.day, Balance.data.wave, 2, 9, tb), "tier 2 plan with the flag on is the planner's")
	GameState.debug_set_tier(3, 17)
	assert_eq(GameState.lane_character(), LaneCharacter.for_run(20260930), "tier 3 with the flag on")
	Balance.data.tiers.retune_enabled = false
	assert_eq(GameState.lane_character(), {}, "tier 3 with the flag off")

## Mutation: the plan skips apply, or is built from another seed, day or tier_day. (apply is idempotent by design, so a second
## application cannot be detected here; the boss mark is added later by PhaseController, outside GameState.lane_plan.)
func test_flag_on_tier3_plan_is_the_planner_through_apply() -> void:
	Balance.data.tiers.retune_enabled = true
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
	Balance.data.tiers.retune_enabled = true
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
	Balance.data.tiers.retune_enabled = true
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
	assert_gt(_peak, 0, "enemies were alive")
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
