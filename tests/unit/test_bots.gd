extends GutTest

var h: SimHarness

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)

func after_each() -> void:
	h.finish()

func test_bot_walks_route_and_stops_at_goal() -> void:
	h.start(11, BotBase)  # base bot: no think(), only steering
	h.bot.go_to("zone_north")
	var ok: bool = await h.run_until(func(): return h.bot.arrived(), 15.0)
	assert_true(ok)
	assert_lt(h.main.hero.xz().distance_to(MapLayout.lane_end("north")), 0.15)
	await h.run_until(func(): return false, 0.5)
	assert_gt(h.main.hero.still_time, 0.3)

func test_parked_bot_stays_home() -> void:
	h.start(11, ParkedBot)  # spawns at NIGHT1_START (D-126), walks home in about 6 s
	await h.run_until(func(): return false, 10.0)
	assert_lt(h.main.hero.xz().distance_to(MapLayout.HOME), 0.1)

func test_naive_bot_heads_for_main_lane_at_night_start() -> void:
	h.start(11, NaiveBot)
	await h.run_until(func(): return false, 1.2)
	assert_eq(h.bot.goal, "zone_north")  # night 1 wave 0 is always north

func test_route_reset_on_restore() -> void:
	h.start(11, NaiveBot)
	await h.run_until(func(): return false, 1.2)
	GameState.from_dict(GameState.to_dict())
	assert_eq(h.bot.goal, "")

func test_naive_bot_redecides_right_after_restore() -> void:
	h.start(11, NaiveBot)
	await h.run_until(func(): return false, 1.2)
	GameState.from_dict(GameState.to_dict())
	assert_eq(h.bot.goal, "")
	await h.run_until(func(): return false, 0.05)
	assert_eq(h.bot.goal, "zone_north")  # decision timer was reset, not left counting down

func test_route_reset_on_hero_placement() -> void:
	h.start(11, NaiveBot)
	await h.run_until(func(): return false, 1.2)
	EventBus.hero_place_requested.emit(MapLayout.HOME)
	assert_eq(h.bot.goal, "")

func test_stuck_hero_warns_and_reroutes() -> void:
	h.start(11, BotBase)
	h.bot.go_to("home")
	h.bot._route = [Vector2.ZERO]  # straight through the diner collider: the hero cannot get there
	await h.run_until(func(): return h.bot.stuck_count > 0, 6.0)
	assert_gt(h.bot.stuck_count, 0)
	assert_eq(h.bot.goal, "home")

## Both boars are spawned before the first wave, so they are the only live enemies.
func _lane_choice(lanes: Array) -> String:
	h.start(11, NaiveBot)
	var wd := h.main.world.wave_director
	await h.run_until(func(): return false, 1.2)
	for l in lanes:
		wd.debug_spawn(l)
	assert_lt(1.2 + 1.1, Balance.data.wave.first_wave_delay)  # still before wave 0 starts
	await h.run_until(func(): return false, 1.1)
	return h.bot.goal

func test_naive_bot_picks_most_enemies_then_lane_order() -> void:
	assert_eq(await _lane_choice(["east", "west"]), "zone_west")  # tie: west first (LANES order)

func test_naive_bot_picks_lane_with_more_enemies() -> void:
	assert_eq(await _lane_choice(["east", "west", "east"]), "zone_east")

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
	h.start(11, PlannerBot)
	for i in Balance.data.cards.max_level:
		GameState.debug_grant_card(&"carry_capacity")
	h.main.phase_controller.debug_skip_to_day()
	GameState.freezer_steaks = 40  # test-only setup write
	var ok: bool = await h.run_until(func(): return GameState.carried_steaks >= GameState.carry_capacity(), 60.0)
	assert_true(ok, "loaded to %d (base %d)" % [GameState.carry_capacity(), Balance.data.hero.carry_capacity])

func test_fast_hero_arrives_without_overshoot() -> void:
	h.start(11, BotBase)
	for i in Balance.data.cards.max_level:
		GameState.debug_grant_card(&"move_speed")
	h.main.phase_controller.debug_skip_to_day()
	h.bot.go_to("sign")
	var goal: Vector2 = h.bot.graph.position_of("sign")
	var overshoot := false
	var prev: Vector2 = h.main.hero.xz()
	for i in 60 * 30:
		await h.tick()
		var now: Vector2 = h.main.hero.xz()
		if h.bot._route.size() <= 1 and (goal - prev).dot(goal - now) < -1e-6:
			overshoot = true  # passed the goal on the final approach
		prev = now
		if h.bot.arrived():
			break
	assert_true(h.bot.arrived(), "arrives at move_speed L5")
	assert_false(overshoot, "the arrival step uses the effective speed")
	assert_eq(h.bot.stuck_count, 0)
