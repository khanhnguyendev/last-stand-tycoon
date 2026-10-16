extends GutTest
## E8 phase 2 Task 9 (B12): the tier-4 sims. Every state starts from a fixture written by `tests/sim/make_save.gd -- --fixture=tier4`
## (TierBot real play, threat policy, max_tier 4, tuning seeds 1, 4 and 7; the seed-1 run also records the Wrecker night and the first tier-4 night;
## the Wrecker alone is the one constructed night, built from the real Wrecker-night capture).
## 1. The Wrecker alone needs at least boss_min_hold_s to fell the diner from its first hit; a branch build wins the Wrecker night within boss_night_max_retries.
## 2. The first tier-4 night is held with 0 retries.
## 3. A full tier-4 branch build holds the tier-4 cap with 0 retries on seeds 1, 4 and 7.
## Wall-clock prints are information only, never asserted. Reads only signals and GameState (D-113). The bands are judged by the report scripts, not by one run (B12);
## an assertion that fails here is reported, not tuned (Task 11 tunes).

var h: SimHarness
var _t0 := 0
var bosses_killed := 0
var growth: Array = []
var last_wave_start_s := -1.0

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)
	_t0 = Time.get_ticks_msec()
	bosses_killed = 0
	growth = []
	last_wave_start_s = -1.0

func after_each() -> void:
	for pair in [[EventBus.enemy_killed, _count_kill], [EventBus.wave_started, _on_wave_started]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	h.finish()
	Balance.reset()
	gut.p("  wall time %.1f s" % ((Time.get_ticks_msec() - _t0) / 1000.0))

func _count_kill(_i: int, _lane: StringName, _p: Vector3, kind: StringName) -> void:
	if TierEffects.is_boss_kind(kind, Balance.data.tiers):
		bosses_killed += 1

func _on_wave_started(wave_index: int, _main: StringName, _side: StringName) -> void:
	if wave_index == GameState.lane_plan.size() - 1:
		last_wave_start_s = h.elapsed

func _watch_pools() -> void:
	var w: World = h.main.world
	for p in [w.enemy_pool, w.steak_pool, w.projectile_pool]:
		var pool: NodePool = p
		pool.grew.connect(func(n: int): growth.append("%s -> %d" % [pool.name, n]))

func _start(stem: String, bot_script: GDScript, phase := "") -> void:
	h.start_from(stem, bot_script, 0, phase)
	if h.bot is TierBot:
		(h.bot as TierBot).max_tier = 4
	_watch_pools()

## Stale-fixture guard (as in test_tier3_sims.gd): the plan STORED in the fixture file must equal what the planner makes today for its run, day and tier,
## through the lane character, with the boss as GameState adds it. Mutation: change a wave count or the hare share and this fails for every fixture.
func _assert_fresh_plan(stem: String, boss_night: bool) -> void:
	var stored: Dictionary = SaveCodec.decode(FileAccess.get_file_as_string("res://export/fixtures/%s.save.json" % stem), GameState.SCHEMA_VERSION, Balance.data).state
	var character := LaneCharacter.for_run(int(stored.run_seed))
	var fresh := LanePlanner.plan(int(stored.run_seed), int(stored.day), Balance.data.wave, int(stored.tier), int(stored.tier_day), Balance.data.tiers)
	fresh = LaneCharacter.apply(fresh, character, Balance.data.tiers)
	if boss_night:
		fresh = LanePlanner.with_boss(fresh, character)
	assert_eq(_canon(stored.lane_plan), _canon(fresh), "stale fixture %s: re-run make_save.gd -- --fixture=tier4" % stem)
	assert_eq(_canon(GameState.lane_plan), _canon(fresh), "%s: the game started from the fixture plays the planner's plan" % stem)

func _canon(plan: Array) -> Array:
	return plan.map(func(w): return JSON.stringify(_norm(w), "", true))

func _norm(v: Variant) -> Variant:
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _norm(v[k])
		return d
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float and is_equal_approx(v, roundf(v)):
		return int(roundf(v))
	return v

func _spot_levels(ids: Array) -> Array:
	return ids.map(func(id): return int(GameState.buildings[id].level) if GameState.buildings.has(id) else -1)

# ---- sim 1a: the Wrecker alone ---------------------------------------------------------------------------------------

## Sim 2's rule at tier 3 (spec 4.6): with no defence the Wrecker needs at least boss_min_hold_s from its first hit to fell the diner.
func test_1a_the_wrecker_alone_needs_at_least_boss_min_hold_s_to_fell_the_diner() -> void:
	h.start_from("tier4_wrecker_only", ParkedBot, 0, "DAY")
	# A tier-3 load re-derives the plan (D-286.4), so the fixture's no-defence state is kept and the waves are emptied here, in memory (test-only setup):
	# every wave loses its monsters; the Wrecker stays on the last (the boss rides the wave, not its counts).
	var emptied: Array = GameState.lane_plan.duplicate(true)
	for w in emptied:
		for k in w.keys():
			if String(k).ends_with("_count") or String(k).begins_with("fast_") or String(k).begins_with("brute_"):
				w[k] = 0
		w.extra = []
		w.side = ""
	GameState.lane_plan = emptied
	h.main.phase_controller.close_up()
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.enemy_killed.connect(_count_kill)
	assert_eq(GameState.tier, 3)
	assert_true(GameState.is_boss_night(), "the fixture is a boss night")
	assert_eq(TierEffects.boss_kind_for(GameState.tier, Balance.data.tiers), &"wrecker")
	assert_eq(_spot_levels(MapLayout.spots_for_tier(3)), [0, 0, 0, 0, 0, 0, 0, 0, 0], "no building (precondition)")
	var boss_hp: float = Balance.data.monsters.stats(&"wrecker").hp * float(GameState.lane_plan[-1].hp_mult)
	var n := await h.run_night(400.0)
	assert_true(n.failed, "with no defense the Wrecker fells the diner")
	assert_gte(h.first_boss_hit_s, 0.0, "the Wrecker hit the diner")
	assert_eq(h.kills, 0, "the Wrecker was never killed")
	assert_gte(last_wave_start_s, 0.0, "the last wave started")
	var hold := h.fell_s - h.first_boss_hit_s
	gut.p("Wrecker alone (HP %.0f): last wave at %.1f s, first hit at %.1f s (%.1f s later), diner fell at %.1f s, hold %.1f s (min %.1f)" % [boss_hp, last_wave_start_s, h.first_boss_hit_s, h.first_boss_hit_s - last_wave_start_s, h.fell_s, hold, Balance.data.tiers.boss_min_hold_s])
	assert_gte(hold, Balance.data.tiers.boss_min_hold_s)

# ---- sim 1b: the Wrecker night is won ------------------------------------------------------------------------------------

func test_1b_a_branch_build_wins_the_wrecker_night_within_the_allowed_retries() -> void:
	# "DAY": the real restore point of a boss night is the close-up snapshot, so a lost night returns to the day.
	_start("tier4_wrecker_full", TierBot, "DAY")
	EventBus.enemy_killed.connect(_count_kill)
	assert_eq(GameState.tier, 3)
	assert_true(GameState.boss_pending, "the boss is pending before the night")
	_assert_fresh_plan("tier4_wrecker_full", true)
	var max_r: int = Balance.data.sim.boss_night_max_retries
	var retries := 0
	var d0 := await h.run_day()
	assert_true(d0.closed, "the bot closes up")
	assert_true(GameState.is_boss_night(), "tonight is the boss night")
	var mercy := GameState.mercy_factor()
	var t0 := h.elapsed
	bosses_killed = 0
	var n := await h.run_night()
	while n.failed and retries < max_r:
		retries += 1
		var restored := await h.run_until(func(): return not h.main.phase_controller.failing, Balance.ui.banner_time + 1.0)
		assert_true(restored, "the fail flow restores")
		assert_eq(h.main.phase_controller.phase, Phase.DAY, "a lost boss night returns to the day")
		assert_true(GameState.boss_pending, "the boss is still pending after a loss")
		assert_eq(GameState.tier, 3, "still tier 3 after a loss")
		assert_eq(GameState.night_fails, retries, "the loss counts")
		var d := await h.run_day()
		assert_true(d.closed, "the bot closes up again")
		mercy = GameState.mercy_factor()
		t0 = h.elapsed
		bosses_killed = 0
		n = await h.run_night()
	var night_s := h.elapsed - t0
	gut.p("Wrecker night won after %d retries (max %d); diner_frac %.3f; night seconds %.1f; mercy on the winning attempt %.2f" % [retries, max_r, n.diner_frac, night_s, mercy])
	assert_true(n.cleared, "the Wrecker night is won within %d retries" % max_r)
	assert_eq(bosses_killed, 1, "the Wrecker died exactly once on the winning attempt")
	assert_eq(h.bot.stuck_count, 0, "the bot never got stuck")
	assert_eq(GameState.tier, 4, "the dawn tiered up")
	assert_true(GameState.buildings.has("tower_n2"), "the back lot")
	assert_eq(GameState.night_fails, 0, "the win clears the fail count")

# ---- sim 2: the first tier-4 night ---------------------------------------------------------------------------------------

func test_2_the_first_tier_4_night_is_held_with_0_retries() -> void:
	_start("tier4_night1", TierBot)
	assert_eq(GameState.tier, 4)
	assert_false(GameState.is_boss_night())
	assert_eq(GameState.day, GameState.tier_day, "the first tier-4 night")
	_assert_fresh_plan("tier4_night1", false)
	assert_eq(GameState.night_fails, 0, "a first attempt")
	var n := await h.run_night()
	gut.p("first tier-4 night: %s; diner HP left %.1f; pressure %d" % [n, GameState.diner_hp, GameState.pressure()])
	assert_false(n.failed, "no loss, so no retry")
	assert_true(n.cleared, "the first tier-4 night is held on the first attempt")
	assert_eq(GameState.night_fails, 0)
	assert_eq(h.bot.stuck_count, 0, "the bot never got stuck")

# ---- sim 3: the tier-4 cap -------------------------------------------------------------------------------------------------

func test_3_a_full_tier_4_branch_build_holds_the_cap_with_0_retries_on_seeds_1_4_and_7() -> void:
	var lines: Array = []
	for sd in [1, 4, 7]:
		h.finish()
		await get_tree().process_frame
		Balance.reset()
		h = SimHarness.new(self)
		growth = []
		_start("tier4_cap_s%d" % sd, TierBot)
		assert_eq(GameState.tier, 4)
		assert_eq(GameState.run_seed, sd)
		_assert_fresh_plan("tier4_cap_s%d" % sd, false)
		assert_eq(GameState.pressure(), Balance.data.tiers.tier_cap[4], "seed %d: at the tier-4 cap" % sd)
		var branched := 0
		for id in MapLayout.spots_for_tier(4):
			assert_eq(int(GameState.buildings[id].level), 3, "seed %d: %s is at max level" % [sd, id])
			if String(GameState.buildings[id].branch) != "":
				branched += 1
		assert_eq(branched, MapLayout.spots_for_tier(4).size(), "seed %d: every branchable building carries a branch (precondition)" % sd)
		var hp_before := GameState.diner_hp
		var n := await h.run_night()
		lines.append("seed %d: %s dawn HP %.1f of %.0f (from %.1f)" % [sd, n, GameState.diner_hp, Balance.data.build.diner_max_hp, hp_before])
		assert_false(n.failed, "seed %d: no loss" % sd)
		assert_true(n.cleared, "seed %d holds the tier-4 cap with 0 retries" % sd)
		assert_eq(GameState.night_fails, 0, "seed %d: 0 retries" % sd)
		assert_eq(h.bot.stuck_count, 0, "seed %d: never stuck" % sd)
	gut.p("tier-4 cap: " + " | ".join(lines))
