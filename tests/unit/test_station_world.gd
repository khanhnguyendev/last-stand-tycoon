extends GutTest

var main: Main
var sb: StationBalance
var _grew := 0

func before_each() -> void:
	Balance.reset()
	sb = Balance.data.stations
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(21)
	main.hero.teleport(Vector2(15, 8))  # away from every zone
	_grew = 0

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _secs(seconds: float) -> int:
	return int(ceil(seconds * Engine.physics_ticks_per_second * 1.1))

func test_the_counter_pile_has_a_slot_for_every_steak_at_max_level() -> void:
	var top := sb.counter_capacity[sb.max_level]
	GameState.debug_set_station_level(&"counter", sb.max_level)
	GameState.counter_steaks = top  # test-only setup
	EventBus.stocks_changed.emit()
	assert_eq(main.world.counter.stack_count(), top)

func test_counter_steaks_above_the_capacity_do_not_break_anything() -> void:
	# Review Focus 2: a save from a build with bigger tables.
	main.phase_controller.debug_skip_to_day()
	GameState.counter_steaks = 500  # test-only setup
	GameState.carried_steaks = 3  # test-only setup
	EventBus.stocks_changed.emit()
	assert_eq(main.world.counter.stack_count(), sb.counter_capacity[sb.max_level], "the pile shows what it has slots for")
	assert_eq(GameState.move_carry_to_counter(3), 0)
	await _ticks(_secs(20.0))
	assert_lt(GameState.counter_steaks, 500, "travelers still buy")

func test_the_freezer_loads_more_per_tick_at_level_2() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_station_level(&"freezer", 2)
	GameState.add_freezer(50)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	var eco := Balance.data.economy
	await _ticks(ceili((eco.stand_still_time + 2 * eco.transfer_tick) * Engine.physics_ticks_per_second) + 2)
	assert_gte(GameState.carried_steaks, 2 * sb.load_per_tick[2])
	await _ticks(_secs(3.0))
	assert_eq(GameState.carried_steaks, GameState.carry_capacity(), "fills to the upgraded capacity, never past it")
	assert_eq(GameState.carry_capacity(), Balance.data.hero.carry_capacity + sb.carry_bonus[2])

func test_the_queue_grows_with_the_counter_level() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_station_level(&"counter", 3)
	await _ticks(_secs((sb.queue_max[3] + 2) * (sb.traveler_interval[3] + Balance.data.economy.traveler_jitter)))
	assert_eq(main.world.traveler_spawner.queue.size(), sb.queue_max[3])

func test_upgrading_while_a_traveler_is_served() -> void:
	# Review Focus 5
	main.phase_controller.debug_skip_to_day()
	var sp := main.world.traveler_spawner
	await _ticks(_secs(sb.queue_max[0] * 3.0 + 10.0))  # empty counter: nobody is served, the queue fills and stays full
	assert_eq(sp.queue.size(), sb.queue_max[0], "full at level 0")
	assert_true((sp.queue[0] as Traveler).at_target(), "precondition: the front traveler is at the counter")
	GameState.counter_steaks = 12  # test-only setup
	await _ticks(5)
	assert_gt((sp.queue[0] as Traveler).service_timer, 0.0, "precondition: a traveler is mid-service")
	GameState.debug_set_station_level(&"counter", 4)
	await _ticks(_secs(20.0))
	assert_gt(sp.queue.size(), sb.queue_max[0], "the cap rose at once")
	assert_lte(sp.queue.size(), sb.queue_max[4])
	assert_lt(GameState.counter_steaks, 12, "service went on")

func test_the_traveler_pool_never_grows_on_a_level_5_day() -> void:
	assert_eq(main.world.traveler_pool.size, StationEffects.traveler_pool_size(sb, Balance.data.economy))
	main.world.traveler_pool.grew.connect(func(_n): _grew += 1)
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_station_level(&"counter", sb.max_level)
	for i in _secs(60.0):
		GameState.counter_steaks = sb.counter_capacity[sb.max_level]  # test-only setup: always stocked
		await get_tree().physics_frame
	assert_eq(_grew, 0)

func test_the_carry_stack_has_a_slot_for_the_largest_carry() -> void:
	var bd := Balance.data
	var cap := StationEffects.max_carry(bd.hero, bd.cards, sb)
	assert_eq(main.hero.carry_stack._pile.multimesh.instance_count, cap)
	GameState.carried_steaks = cap  # test-only setup
	EventBus.stocks_changed.emit()
	assert_eq(main.hero.carry_stack.visible_count(), cap)

func test_an_upgrade_pops_the_visual_not_the_body() -> void:
	var body := main.world.get_node("CounterBody") as StaticBody3D
	GameState.debug_set_station_level(&"counter", 1)
	EventBus.station_upgraded.emit(&"counter", 1)
	assert_eq(body.scale, Vector3.ONE)
	assert_gt(main.world.counter.body_visual.scale.x, 1.0)
	await _ticks(_secs(Balance.ui.build_pop_time))
	assert_almost_eq(main.world.counter.body_visual.scale.x, 1.0, 0.001)

func test_a_restore_mid_pop_kills_the_pop_and_resets_the_scale() -> void:
	var vis: Node3D = main.world.counter.body_visual
	EventBus.station_upgraded.emit(&"counter", 1)
	assert_gt(vis.scale.x, 1.0)
	EventBus.state_restored.emit()
	assert_eq(vis.scale, Vector3.ONE)
	await _ticks(_secs(Balance.ui.build_pop_time))
	assert_eq(vis.scale, Vector3.ONE)

func test_a_restore_mid_pop_kills_the_freezer_pop_and_resets_the_scale() -> void:
	var vis: Node3D = main.world.freezer.body_visual
	EventBus.station_upgraded.emit(&"freezer", 1)
	assert_gt(vis.scale.x, 1.0)
	EventBus.state_restored.emit()
	assert_eq(vis.scale, Vector3.ONE)
	await _ticks(_secs(Balance.ui.build_pop_time))
	assert_eq(vis.scale, Vector3.ONE)
