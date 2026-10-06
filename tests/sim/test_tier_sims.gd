extends GutTest
## E5 spec 8.1 sims 1 to 4 (D-242, D-244). Each starts from an injected fixture (tests/sim/make_save.gd --fixture=tier).
## Wall-clock prints are information only, never asserted.

const SEED := 20260930
var h: SimHarness
var _t0 := 0
var hares := 0
var boss_spawn_s := -1.0
var boss_hp := 0.0

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)
	_t0 = Time.get_ticks_msec()
	hares = 0

func after_each() -> void:
	if EventBus.enemy_killed.is_connected(_count_hare):
		EventBus.enemy_killed.disconnect(_count_hare)
	h.finish()
	gut.p("  wall time %.1f s" % ((Time.get_ticks_msec() - _t0) / 1000.0))

func _count_hare(_i: int, _lane: StringName, _p: Vector3, kind: StringName) -> void:
	if kind == &"hare":
		hares += 1

func _watch_boss_until_fell() -> bool:
	if boss_spawn_s < 0.0 and h.main.world.wave_director.boss_alive():
		boss_spawn_s = h.elapsed
		for b in h.main.world.wave_director.alive_enemies():
			if b.kind == &"boss":
				boss_hp = b.health.max_hp
	return h.failed

func test_1_the_tier_bot_wins_the_boss_night_within_the_allowed_retries() -> void:
	h.start_from("boss_night_tier1", TierBot)
	var max_r: int = Balance.data.sim.boss_night_max_retries
	var retries := 0
	var t0 := h.elapsed
	var n := await h.run_night()
	while n.failed and retries < max_r:
		retries += 1
		var restored := await h.run_until(func(): return not h.main.phase_controller.failing, Balance.ui.banner_time + 1.0)
		assert_true(restored, "the fail flow restores")
		assert_true(GameState.boss_pending, "the boss is still pending after a loss")
		assert_eq(GameState.tier, 1, "still tier 1 after a loss")
		if h.main.phase_controller.phase == Phase.DAY:
			var d := await h.run_day()
			assert_true(d.closed, "the bot closes up again")
		t0 = h.elapsed
		n = await h.run_night()
	var night_s := h.elapsed - t0
	gut.p("boss night won after %d retries (max %d); diner_frac %.3f; night seconds %.1f" % [retries, max_r, n.diner_frac, night_s])
	gut.p("  result %s; stuck_count %d; phase %s wave_index %d" % [n, h.bot.stuck_count, str(h.main.phase_controller.phase), h.main.world.wave_director.wave_index])
	assert_true(n.cleared, "the boss night is won within %d retries" % max_r)
	if n.cleared:
		await h.run_until(func(): return GameState.tier == 2, 30.0)
	assert_eq(GameState.tier, 2, "the dawn tiered up")
	assert_true(GameState.buildings.has("tower_w"))
	assert_eq(GameState.night_fails, 0, "the win clears the fail count")

func test_2_the_boss_alone_needs_at_least_boss_min_hold_s_to_fell_the_diner() -> void:
	h.start_from("boss_only", ParkedBot)
	boss_spawn_s = -1.0
	boss_hp = 0.0
	await h.run_until(_watch_boss_until_fell, 400.0)
	assert_true(h.failed, "with no defense the boss fells the diner")
	var hold := h.fell_s - h.first_boss_hit_s
	gut.p("boss alone: first hit at %.1f s, diner fell at %.1f s, hold %.1f s (min %.1f)" % [h.first_boss_hit_s, h.fell_s, hold, Balance.data.tiers.boss_min_hold_s])
	gut.p("  boss max HP %.0f; spawn at %.1f s, first hit %.1f s after spawn (lane walk); phase after %s" % [boss_hp, boss_spawn_s, h.first_boss_hit_s - boss_spawn_s, str(h.main.phase_controller.phase)])
	assert_gte(hold, Balance.data.tiers.boss_min_hold_s)

func test_3_the_tier_bot_holds_the_first_tier2_night() -> void:
	h.start_from("tier2_night1", TierBot)
	EventBus.enemy_killed.connect(_count_hare)
	var n := await h.run_night()
	gut.p("tier-2 night 1: %s; hares killed %d; stuck_count %d" % [n, hares, h.bot.stuck_count])
	assert_true(n.cleared, "no retry on the first tier-2 night (D-241)")

func test_4_a_full_tier2_build_clears_the_cap_with_0_retries_on_three_seeds() -> void:
	for sd in [20260930, 1, 2]:
		h.finish()
		await get_tree().process_frame
		Balance.reset()
		h = SimHarness.new(self)
		h.start_from("tier2_full", NaiveBot, sd)
		var t0 := h.elapsed
		var n := await h.run_night()
		gut.p("tier-2 cap, seed %d: %s; night seconds %.1f; stuck_count %d" % [sd, n, h.elapsed - t0, h.bot.stuck_count])
		assert_true(n.cleared, "seed %d holds the cap (D-244)" % sd)
