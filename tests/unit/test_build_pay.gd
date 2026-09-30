extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(31)
	main.phase_controller.debug_skip_to_day()

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _stand(spot_id: String) -> void:
	await TestHelpers.walk_in(main.hero, MapLayout.spot_position(spot_id))

## Frames to finish `cost` by standing: still time + ticks at the drain rate, +10 % margin.
func _frames_to_pay(cost: int) -> int:
	var e := Balance.data.economy
	var ticks := ceili(float(cost) / Economy.drain_per_tick(cost, Balance.data.build))
	return int(ceil((e.stand_still_time + ticks * e.transfer_tick) * 60.0 * 1.1))

func test_fence_builds_and_keeps_paying() -> void:
	var cost := GameState.next_level_cost("fence_n")
	var extra := 5
	GameState.add_gold(cost + extra)
	await _stand("fence_n")
	await _ticks(_frames_to_pay(cost))
	assert_eq(GameState.buildings.fence_n.level, 1)
	await _ticks(30)
	assert_eq(GameState.gold, 0)
	assert_eq(GameState.buildings.fence_n.paid, extra, "keeps paying toward the next level")

func test_partial_payment_persists_after_leaving() -> void:
	var have := 10
	assert_lt(have, GameState.next_level_cost("tower_nw"), "precondition: cannot finish a level")
	GameState.add_gold(have)
	await _stand("tower_nw")
	await _ticks(60)
	assert_eq(GameState.gold, 0)
	assert_eq(GameState.buildings.tower_nw.paid, have)
	main.hero.teleport(MapLayout.HOME)
	await _ticks(10)
	assert_eq(GameState.buildings.tower_nw.paid, have)
	assert_eq(main.world.build_spots.tower_nw.label.text, str(GameState.next_level_cost("tower_nw") - have))
	# The bots' stand point for this spot must also pay.
	GameState.add_gold(3)
	await TestHelpers.walk_in(main.hero, WaypointGraph.create_default().position_of("tower_nw"))
	await _ticks(60)
	assert_gt(GameState.buildings.tower_nw.paid, have, "bot stand point pays")

func test_partial_payment_survives_dawn() -> void:
	# Spec 8.6: partial payment persists across nights (rubble fences are the exception and reset).
	GameState.add_gold(10)
	GameState.pay_into_spot("tower_nw", 10)
	main.phase_controller.debug_skip_to_night()
	main.phase_controller.debug_skip_to_day()
	assert_eq(GameState.buildings.tower_nw.paid, 10)

func test_pays_only_what_gold_allows() -> void:
	# Review Focus 5: gold below the drain never goes negative.
	assert_gt(Economy.drain_per_tick(GameState.next_level_cost("tower_ne"), Balance.data.build), 1, "precondition: drain >= 2")
	GameState.add_gold(1)
	await _stand("tower_ne")
	await _ticks(40)
	assert_eq(GameState.gold, 0)
	assert_eq(GameState.buildings.tower_ne.paid, 1)

func test_max_level_spot_takes_nothing() -> void:
	# Review Focus 5
	var total := 0
	for l in Balance.data.build.max_level:
		total += Economy.level_cost("fence_w", l, Balance.data.build)
	GameState.add_gold(total)
	for i in Balance.data.build.max_level:
		GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	assert_eq(GameState.gold, 0, "precondition: exactly paid off")
	GameState.add_gold(50)
	var left := GameState.gold
	assert_eq(main.world.build_spots.fence_w.label.text, "MAX")
	await _stand("fence_w")
	await _ticks(60)
	var z: StationZone = main.world.build_spots.fence_w.zone
	assert_true(z.standing, "precondition: hero is standing")
	assert_false(z.ring.visible)
	assert_eq(GameState.gold, left)

func test_ring_shows_paid_over_cost() -> void:
	var cost := GameState.next_level_cost("tower_nw")
	var have := 10
	assert_lt(have, cost, "precondition")
	GameState.add_gold(have)
	GameState.pay_into_spot("tower_nw", have)
	var z: StationZone = main.world.build_spots.tower_nw.zone
	assert_true(z.ring.visible)
	var v: Variant = (z.ring.material_override as ShaderMaterial).get_shader_parameter("progress")
	assert_almost_eq(float(v), float(have) / float(cost), 1e-4)

func test_dawn_inside_zone_needs_reentry() -> void:
	# D-121: hero inside a build-spot zone when dawn activates it -> no payment until exit and re-entry.
	main.phase_controller.close_up()  # back to NIGHT
	GameState.add_gold(40)
	await _stand("fence_e")
	main.phase_controller.debug_skip_to_day()
	await _ticks(60)
	assert_eq(GameState.gold, 40)
	await _stand("fence_e")
	await _ticks(60)
	assert_lt(GameState.gold, 40)

func test_no_payment_at_night() -> void:
	main.phase_controller.close_up()
	GameState.add_gold(40)
	await _stand("fence_e")
	await _ticks(60)
	var d := (main.hero.xz() - MapLayout.spot_position("fence_e")).length()
	assert_lte(d, MapLayout.BUILD_RADIUS, "precondition: hero is inside the zone")
	assert_false(main.world.build_spots.fence_e.zone.standing)
	assert_eq(GameState.gold, 40)
