extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(41)

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_standing_on_sign_starts_night_after_hold() -> void:
	main.phase_controller.debug_skip_to_day()
	await TestHelpers.walk_in(main.hero, MapLayout.SIGN)
	var e := Balance.data.economy
	var still := int(ceil(e.stand_still_time * 60.0))
	var hold := int(ceil(ceil(e.closeup_hold / e.transfer_tick) * e.transfer_tick * 60.0))
	await _ticks(still + int(hold * 0.85))
	assert_eq(main.phase_controller.phase, Phase.DAY)
	await _ticks(int(hold * 0.3) + 2)
	assert_eq(main.phase_controller.phase, Phase.NIGHT)
	assert_eq(main.phase_controller.snapshot.resume_phase, "DAY")

func test_hold_resets_when_leaving() -> void:
	main.phase_controller.debug_skip_to_day()
	var sign_node: CloseUpSign = main.world.closeup_sign
	var e := Balance.data.economy
	var still := int(ceil(e.stand_still_time * 60.0))
	var hold := int(ceil(ceil(e.closeup_hold / e.transfer_tick) * e.transfer_tick * 60.0))
	await TestHelpers.walk_in(main.hero, MapLayout.SIGN)
	await _ticks(still + int(hold * 0.5))
	assert_gt(sign_node.hold, 0.0, "partway through the hold")
	main.hero.input.set_move(Vector2(1, 0))
	await _ticks(30)
	main.hero.input.set_move(Vector2.ZERO)
	assert_eq(sign_node.hold, 0.0)
	assert_false(sign_node.zone.ring.visible)
	await TestHelpers.walk_in(main.hero, MapLayout.SIGN)
	# Short of a full hold from zero: a leftover half hold would already have closed up.
	await _ticks(still + hold - 50 + 5)
	assert_eq(main.phase_controller.phase, Phase.DAY, "a full hold from zero is needed")
	await _ticks(60)
	assert_eq(main.phase_controller.phase, Phase.NIGHT)

func test_restore_to_day_does_not_close_up() -> void:
	# D-121, D-122: the hero lands at HOME after a fail; with no input the day must not end.
	main.phase_controller.debug_skip_to_day()
	GameState.add_gold(7)
	main.phase_controller.close_up()
	GameState.damage_diner(1e9)
	await _ticks(int(Balance.ui.banner_time * 60) + 5)
	assert_eq(main.phase_controller.phase, Phase.DAY)
	assert_eq(main.hero.xz(), MapLayout.HOME)
	main.hero.teleport(MapLayout.SIGN)  # a teleport into the zone must not arm it (D-121)
	await _ticks(60 * 5)
	assert_eq(main.phase_controller.phase, Phase.DAY)
	assert_eq(GameState.gold, 7)

func test_pulse_follows_predicate() -> void:
	main.phase_controller.debug_skip_to_day()
	var s: CloseUpSign = main.world.closeup_sign
	assert_true(s.pulsing)
	for i in 5:
		await get_tree().process_frame
	assert_gt(s._visual.scale.x, 1.0, "the sign is breathing")
	GameState.add_freezer(1)
	assert_false(s.pulsing)
	await get_tree().process_frame
	assert_eq(s._visual.scale, Vector3.ONE)

func test_telegraph_scales_and_visibility() -> void:
	var m: Dictionary = main.world.telegraph_markers
	for lane in m:
		assert_false(m[lane].visible, "hidden at night")
	var day1: Array = GameState.lane_plan
	main.phase_controller.debug_skip_to_day()
	assert_ne(day1, GameState.lane_plan, "a new day has a new plan")
	var threat := LanePlanner.threat_by_lane(GameState.lane_plan, Balance.data.enemy.hp)
	var mx: float = threat.values().max()
	for lane in m:
		var expect := LanePlanner.marker_scale(threat[lane], mx, Balance.ui.telegraph_scale_min, Balance.ui.telegraph_scale_max)
		assert_almost_eq(m[lane].target_scale, expect, 0.0001)
		assert_eq(m[lane].visible, expect > 0.0)

func test_telegraph_shows_the_boss_lane_the_day_the_tier_is_paid() -> void:
	# A seed whose day-1 plan does not already end on its heaviest lane, so the boss visibly changes the flags.
	var m: Dictionary = main.world.telegraph_markers
	var boss_lane := ""
	for seed in range(1, 40):
		main.phase_controller.start_new_game(seed)
		main.phase_controller.debug_skip_to_day()
		boss_lane = String(LanePlanner.with_boss(GameState.lane_plan).back().main)
		if m[boss_lane].target_scale < Balance.ui.telegraph_scale_max - 0.001:
			break
	var before: float = m[boss_lane].target_scale
	assert_lt(before, Balance.ui.telegraph_scale_max - 0.001, "test setup found a seed")
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	for lane in m:
		assert_true(m[boss_lane].target_scale >= m[lane].target_scale, "the boss lane is the largest")
	assert_gt(m[boss_lane].target_scale, before, "and it grew")
