extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(8)

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _day() -> void:
	main.phase_controller.debug_skip_to_day()

## Physics ticks that are enough for the still requirement plus n transfer ticks.
func _wait_for(n_transfers: int) -> int:
	var eco := Balance.data.economy
	return ceili((eco.stand_still_time + n_transfers * eco.transfer_tick) * Engine.physics_ticks_per_second) + 2

func _ring_progress(z: StationZone) -> float:
	var v: Variant = (z.ring.material_override as ShaderMaterial).get_shader_parameter("progress")
	return 0.0 if v == null else float(v)

func test_freezer_fills_carry_to_capacity() -> void:
	_day()
	GameState.add_freezer(10)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	await _ticks(30)
	# 30 ticks minus the still requirement, one steak per transfer tick (derived from Balance, +-1 for tick sampling)
	var eco := Balance.data.economy
	var expect := (30.0 / Engine.physics_ticks_per_second - eco.stand_still_time) / eco.transfer_tick
	assert_gt(expect, 1.0)
	assert_between(GameState.carried_steaks, maxi(int(floor(expect)) - 1, 1), int(floor(expect)) + 1)
	await _ticks(_wait_for(Balance.data.hero.carry_capacity))
	assert_eq(GameState.carried_steaks, Balance.data.hero.carry_capacity)
	assert_eq(GameState.freezer_steaks, 10 - Balance.data.hero.carry_capacity)

func test_freezer_inactive_at_night() -> void:
	GameState.add_freezer(10)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	await _ticks(_wait_for(3))
	assert_eq(GameState.carried_steaks, 0)

func test_teleport_into_zone_does_not_arm() -> void:
	# D-121
	_day()
	GameState.add_freezer(10)
	main.hero.teleport(MapLayout.FREEZER_ZONE)
	await _ticks(_wait_for(3))
	assert_false(main.world.freezer.zone.armed)
	assert_eq(GameState.carried_steaks, 0)

func test_inside_when_zone_activates_needs_reentry() -> void:
	# D-121: hero inside at NIGHT, zone activates at dawn -> nothing until it leaves and re-enters.
	GameState.add_freezer(10)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	_day()
	await _ticks(_wait_for(3))
	assert_eq(GameState.carried_steaks, 0)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	await _ticks(_wait_for(3))
	assert_gt(GameState.carried_steaks, 0)

func test_moving_hero_does_not_transfer() -> void:
	_day()
	GameState.add_freezer(10)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE + Vector2(-0.8, 0))
	# drift at twice the stand-still speed threshold, so still_time keeps resetting
	main.hero.input.set_move(Vector2(1, 0) * (2.0 * Balance.data.economy.stand_still_speed / Balance.data.hero.move_speed))
	await _ticks(_wait_for(3))
	assert_eq(GameState.carried_steaks, 0)

func test_counter_fills_up_to_capacity() -> void:
	_day()
	var cap := Balance.data.economy.counter_capacity
	GameState.carried_steaks = 3  # test-only setup
	GameState.counter_steaks = cap - 1
	await TestHelpers.walk_in(main.hero, MapLayout.COUNTER_DROP)
	await _ticks(_wait_for(3))
	assert_eq(GameState.counter_steaks, cap)
	assert_eq(GameState.carried_steaks, 2)

func test_leaving_ends_stand() -> void:
	_day()
	var z: StationZone = main.world.freezer.zone
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	await _ticks(20)
	assert_true(z.standing)
	main.hero.teleport(Vector2(15, 8))
	await _ticks(2)
	assert_false(z.standing)

func test_labels_follow_state() -> void:
	_day()
	GameState.add_freezer(15)
	assert_eq(main.world.freezer.label.text, "15")
	assert_eq(main.world.freezer.stack_count(), 10)
	GameState.from_dict(main.phase_controller.snapshot)
	assert_eq(main.world.freezer.label.text, "0")

func test_phase_change_disarms_armed_hero() -> void:
	_day()
	GameState.add_freezer(10)
	var z: StationZone = main.world.freezer.zone
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	await _ticks(_wait_for(1))
	assert_true(z.armed, "precondition: armed and transferring")
	main.phase_controller.debug_skip_to_night()
	main.phase_controller.debug_skip_to_day()
	assert_eq(main.phase_controller.phase, Phase.DAY)
	var before := GameState.carried_steaks
	await _ticks(_wait_for(3))
	assert_eq(GameState.carried_steaks, before, "a hero standing inside across a phase change must re-enter")
	assert_false(z.armed)

func test_state_restored_disarms() -> void:
	_day()
	GameState.add_freezer(10)
	var z: StationZone = main.world.freezer.zone
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	await _ticks(_wait_for(1))
	assert_true(z.armed, "precondition: armed")
	var before := GameState.carried_steaks
	GameState.from_dict(GameState.to_dict())  # emits state_restored, stocks unchanged
	assert_false(z.armed)
	await _ticks(_wait_for(3))
	assert_eq(GameState.carried_steaks, before)

func test_ring_shows_stand_still_charge() -> void:
	_day()
	GameState.add_freezer(10)
	var z: StationZone = main.world.freezer.zone
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	var n := 0
	while not z.ring.visible and n < _wait_for(1):
		await _ticks(1)
		n += 1
	assert_true(z.ring.visible, "ring appears once the hero is armed and still")
	var p := _ring_progress(z)
	assert_gt(p, 0.0)
	assert_lt(p, 1.0)
	await _ticks(_wait_for(1))
	assert_eq(_ring_progress(z), 1.0)
	main.hero.teleport(Vector2(15, 8))
	await _ticks(2)
	assert_false(z.ring.visible)

func test_freezer_body_blocks_hero() -> void:
	_day()
	main.hero.teleport(MapLayout.FREEZER_ZONE)
	main.hero.input.set_move(Vector2(0, -1))
	await _ticks(60)
	assert_gte(main.hero.xz().y, MapLayout.FREEZER.y + MapLayout.FREEZER_SIZE.y / 2.0 + MapLayout.HERO_RADIUS - 0.05)

func test_counter_body_blocks_hero() -> void:
	_day()
	main.hero.teleport(Vector2(0, 7))
	main.hero.input.set_move(Vector2(0, -1))
	await _ticks(60)
	assert_gte(main.hero.xz().y, MapLayout.COUNTER.y + MapLayout.COUNTER_SIZE.y / 2.0 + MapLayout.HERO_RADIUS - 0.05)
