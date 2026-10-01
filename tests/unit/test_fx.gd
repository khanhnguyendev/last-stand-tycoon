extends GutTest
## Task 30 feel budget. World.fly_fx / fx_pool come from the D-139 wiring (applied).

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(91)

func _local_fx() -> FlyFx:
	var pool := NodePool.new()
	add_child_autofree(pool)
	pool.setup(func(): return FlyFx.make_item(), 4)
	var fx := FlyFx.new()
	add_child_autofree(fx)
	fx.setup(pool)
	return fx

func _wired_fx() -> FlyFx:
	return main.world.fly_fx

func test_fly_is_visual_only_and_releases() -> void:
	var fx := _local_fx()
	var before := GameState.to_dict()
	fx.fly("coin", Vector3(0, 1, 0), Vector3(3, 1, 0))
	assert_eq(fx.in_flight(), 1)
	for i in ceili(Balance.ui.transfer_arc_time * 60.0) + 10:
		await get_tree().process_frame
	assert_eq(fx.in_flight(), 0)
	assert_eq(GameState.to_dict(), before)

func test_fly_arc_peaks_at_apex() -> void:
	var fx := _local_fx()
	fx.fly("steak", Vector3(0, 1, 0), Vector3(4, 1, 0))
	var item: Node3D = fx._pool.active()[0]
	var top := 0.0
	for i in ceili(Balance.ui.transfer_arc_time * 60.0) + 2:
		await get_tree().process_frame
		if fx.in_flight() > 0:
			top = maxf(top, item.position.y - 1.0)
	assert_gt(top, Balance.ui.transfer_arc_apex * 0.5)
	assert_lte(top, Balance.ui.transfer_arc_apex + 1e-3)

func test_recall_mid_flight_kills_tween() -> void:
	var fx := _local_fx()
	fx.fly("coin", Vector3.ZERO, Vector3(5, 0, 0))
	var item: Node3D = fx._pool.active()[0]
	fx._pool.recall_all()
	assert_eq(fx.in_flight(), 0)
	item.position = Vector3(9, 9, 9)
	await get_tree().process_frame
	assert_eq(item.position, Vector3(9, 9, 9), "a recalled item is not moved by a stale tween")

func test_wired_world_has_fly_fx() -> void:
	assert_not_null(_wired_fx(), "wired: World creates FlyFx over fx_pool")
	assert_not_null(main.world.fx_pool)
	assert_not_null(main.world.find_child("FxPool", false, false), "wired: FxPool node")

func test_wired_fly_is_visual_only_and_releases() -> void:
	var fx := _wired_fx()
	var before := GameState.to_dict()
	fx.fly("coin", Vector3(0, 1, 0), Vector3(3, 1, 0))
	assert_eq(fx.in_flight(), 1)
	for i in 30:
		await get_tree().process_frame
	assert_eq(fx.in_flight(), 0)
	assert_eq(GameState.to_dict(), before)

func test_freezer_transfer_spawns_fly() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.add_freezer(3)
	await TestHelpers.walk_in(main.hero, MapLayout.FREEZER_ZONE)
	var peak := 0
	var fx := _wired_fx()
	for i in 25:
		await get_tree().physics_frame
		peak = maxi(peak, fx.in_flight())
	assert_gt(GameState.carried_steaks, 0, "FX hooks never break the transfer")
	assert_gt(peak, 0, "a steak arc flew")

func test_counter_transfer_spawns_fly() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.carried_steaks = 2
	await TestHelpers.walk_in(main.hero, MapLayout.COUNTER_DROP)
	var peak := 0
	var fx := _wired_fx()
	for i in 25:
		await get_tree().physics_frame
		peak = maxi(peak, fx.in_flight())
	assert_gt(GameState.counter_steaks, 0, "FX hooks never break the transfer")
	assert_gt(peak, 0, "a steak arc flew")

func test_build_pop_overshoots() -> void:
	var s: BuildSpot = main.world.build_spots.fence_w
	GameState.add_gold(GameState.next_level_cost("fence_w"))
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	await get_tree().process_frame
	assert_gt(s.visual.scale.x, 1.0)
	assert_lte(s.visual.scale.x, Balance.ui.build_pop_scale + 1e-3)
	for i in ceili(Balance.ui.build_pop_time * 60.0) + 12:
		await get_tree().process_frame
	assert_almost_eq(s.visual.scale.x, 1.0, 0.01)

func _boar_material(b: Boar) -> Material:
	return (b.visual.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).material_override

func test_hit_flash() -> void:
	main.phase_controller.debug_skip_to_day()
	var b := main.world.wave_director.debug_spawn("north", 0.0, 10.0)
	b.take_hit(1.0)
	assert_true(b.flash_active())
	assert_true(b.visual.flash_active)
	assert_eq(_boar_material(b), BoarVisual.flash_material())
	for i in ceili(Balance.ui.hit_flash_time * 60.0) + 4:
		await get_tree().physics_frame
	assert_false(b.flash_active())
	assert_false(b.visual.flash_active, "visual flash ended with the countdown")
	assert_ne(_boar_material(b), BoarVisual.flash_material(), "boar colour restored")

func test_flash_reset_on_release_and_spawn() -> void:
	var b := main.world.wave_director.debug_spawn("north", 0.0, 10.0)
	b.take_hit(1.0)
	assert_true(b.visual.flash_active, "flashing right after take_hit")
	main.world.enemy_pool.release(b)
	assert_false(b.flash_active())
	assert_false(b.visual.flash_active)
	assert_ne(_boar_material(b), BoarVisual.flash_material())
	b.spawn("north", 7, 0.0, 10.0, main.world.wave_director)
	assert_false(b.visual.flash_active)
	assert_ne(_boar_material(b), BoarVisual.flash_material())

func test_night_hides_partial_payment_ring() -> void:
	var s: BuildSpot = main.world.build_spots.fence_n
	main.phase_controller.debug_skip_to_day()
	assert_eq(main.phase_controller.phase, Phase.DAY)
	GameState.add_gold(5)
	GameState.pay_into_spot("fence_n", 2)
	assert_true(s.zone.ring.visible, "day: partial payment shows the ring")
	main.phase_controller.debug_skip_to_night()
	assert_eq(main.phase_controller.phase, Phase.NIGHT)
	assert_false(s.zone.ring.visible, "night: ring hidden")
	main.phase_controller.debug_skip_to_day()
	assert_true(s.zone.ring.visible, "day again: ring back")

func test_night_hides_build_cost_labels() -> void:
	var s: BuildSpot = main.world.build_spots.fence_n
	main.phase_controller.debug_skip_to_day()
	assert_true(s.label.visible, "day: cost label shown")
	main.phase_controller.debug_skip_to_night()
	assert_false(s.label.visible, "night: cost label hidden")
	main.phase_controller.debug_skip_to_day()
	assert_true(s.label.visible, "day again: label back")

func test_build_pop_tween_killed_on_refresh() -> void:
	var s: BuildSpot = main.world.build_spots.fence_w
	GameState.add_gold(GameState.next_level_cost("fence_w"))
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	assert_true(s._pop != null and s._pop.is_valid())
	s.refresh()
	assert_false(s._pop != null and s._pop.is_valid(), "refresh kills a running pop")
	assert_almost_eq(s.visual.scale.x, 1.0, 1e-4)
	for i in 20:
		await get_tree().process_frame
	assert_almost_eq(s.visual.scale.x, 1.0, 1e-4, "no stale pop tween fights the refreshed scale")
