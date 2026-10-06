extends GutTest
## E5 spec 8.1 sims 1 to 4 (D-242, D-244). Each starts from an injected fixture (tests/sim/make_save.gd --fixture=tier).
## Wall-clock prints are information only, never asserted. Reads only signals and GameState (D-113).

var h: SimHarness
var _t0 := 0
var hares := 0
var bosses_killed := 0
var last_wave_start_s := -1.0

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)
	_t0 = Time.get_ticks_msec()
	hares = 0
	bosses_killed = 0
	last_wave_start_s = -1.0

func after_each() -> void:
	for pair in [[EventBus.enemy_killed, _count_kill], [EventBus.wave_started, _on_wave_started]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	h.finish()
	gut.p("  wall time %.1f s" % ((Time.get_ticks_msec() - _t0) / 1000.0))

func _count_kill(_i: int, _lane: StringName, _p: Vector3, kind: StringName) -> void:
	if kind == &"hare":
		hares += 1
	elif kind == &"boss":
		bosses_killed += 1

func _on_wave_started(wave_index: int, _main: StringName, _side: StringName) -> void:
	if wave_index == GameState.lane_plan.size() - 1:
		last_wave_start_s = h.elapsed

func test_1_the_tier_bot_wins_the_boss_night_within_the_allowed_retries() -> void:
	# "DAY": the real restore point of a boss night is the close-up snapshot, so a lost night returns to the day.
	h.start_from("boss_night_tier1", TierBot, 0, "DAY")
	EventBus.enemy_killed.connect(_count_kill)
	var max_r: int = Balance.data.sim.boss_night_max_retries
	var retries := 0
	var d0 := await h.run_day()
	assert_true(d0.closed, "the bot closes up")
	assert_true(GameState.is_boss_night(), "tonight is the boss night")
	assert_true(GameState.boss_pending, "the boss is pending before the night")
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
		assert_eq(GameState.tier, 1, "still tier 1 after a loss")
		assert_eq(GameState.night_fails, retries, "the loss counts")
		assert_true(GameState.is_boss_night(), "still the boss night")
		var d := await h.run_day()
		assert_true(d.closed, "the bot closes up again")
		mercy = GameState.mercy_factor()
		t0 = h.elapsed
		bosses_killed = 0
		n = await h.run_night()
	var night_s := h.elapsed - t0
	gut.p("boss night won after %d retries (max %d); diner_frac %.3f; night seconds %.1f; mercy on the winning attempt %.2f" % [retries, max_r, n.diner_frac, night_s, mercy])
	assert_true(n.cleared, "the boss night is won within %d retries" % max_r)
	assert_eq(bosses_killed, 1, "the boss died exactly once on the winning attempt")
	assert_eq(h.bot.stuck_count, 0, "the bot never got stuck")
	assert_eq(GameState.tier, 2, "the dawn tiered up")
	assert_true(GameState.buildings.has("tower_w"))
	assert_eq(GameState.night_fails, 0, "the win clears the fail count")

func test_2_the_boss_alone_needs_at_least_boss_min_hold_s_to_fell_the_diner() -> void:
	h.start_from("boss_only", ParkedBot)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.enemy_killed.connect(_count_kill)
	assert_true(GameState.is_boss_night(), "the fixture is a boss night")
	var boss_hp: float = Balance.data.monsters.stats(&"boss").hp * float(GameState.lane_plan[-1].hp_mult)
	var n := await h.run_night(400.0)
	assert_true(n.failed, "with no defense the boss fells the diner")
	assert_gte(h.first_boss_hit_s, 0.0, "the boss hit the diner")
	assert_eq(h.kills, 0, "the boss was never killed")
	assert_gte(last_wave_start_s, 0.0, "the last wave started")
	var hold := h.fell_s - h.first_boss_hit_s
	gut.p("boss alone (HP %.0f): last wave at %.1f s, first hit at %.1f s (%.1f s later), diner fell at %.1f s, hold %.1f s (min %.1f)" % [boss_hp, last_wave_start_s, h.first_boss_hit_s, h.first_boss_hit_s - last_wave_start_s, h.fell_s, hold, Balance.data.tiers.boss_min_hold_s])
	assert_gte(hold, Balance.data.tiers.boss_min_hold_s)

func test_3_the_tier_bot_holds_the_first_tier2_night() -> void:
	h.start_from("tier2_night1", TierBot)
	EventBus.enemy_killed.connect(_count_kill)
	var n := await h.run_night()
	gut.p("tier-2 night 1: %s; hares killed %d" % [n, hares])
	assert_true(n.cleared, "no retry on the first tier-2 night (D-241)")
	assert_gt(hares, 0, "hares were in the night")
	assert_eq(h.bot.stuck_count, 0, "the bot never got stuck")

func test_4_a_full_tier2_build_clears_the_cap_with_0_retries_on_three_seeds() -> void:
	var lines: Array = []
	for sd in [20260930, 1, 2]:
		h.finish()
		await get_tree().process_frame
		Balance.reset()
		h = SimHarness.new(self)
		h.start_from("tier2_full", NaiveBot, sd)
		assert_eq(GameState.tier, 2)
		assert_eq(GameState.pressure(), Balance.data.tiers.tier_cap[GameState.tier], "seed %d is at the tier-2 cap" % sd)
		assert_eq(GameState.run_seed, sd)
		var t0 := h.elapsed
		var n := await h.run_night()
		lines.append("seed %d: %s; night seconds %.1f" % [sd, n, h.elapsed - t0])
		assert_true(n.cleared, "seed %d holds the cap (D-244)" % sd)
		assert_eq(h.bot.stuck_count, 0, "seed %d: the bot never got stuck" % sd)
	gut.p("tier-2 cap: " + " | ".join(lines))
