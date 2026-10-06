extends GutTest

var main: Main
var pad: UpgradePad

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(8)
	pad = main.world.upgrade_pads[&"counter"]

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _pay_ticks(n: int) -> int:
	var eco := Balance.data.economy
	return ceili((eco.stand_still_time + n * eco.transfer_tick) * Engine.physics_ticks_per_second) + 2

func test_both_pads_exist_at_their_layout_positions() -> void:
	for id in StationEffects.IDS:
		var p: UpgradePad = main.world.upgrade_pads[id]
		assert_eq(p.station_id, id)
		assert_eq(Vector2(p.global_position.x, p.global_position.z), MapLayout.STATION_PADS[id])
		assert_eq(p.zone.radius, MapLayout.BUILD_RADIUS)
		assert_eq(p._pips.size(), Balance.data.stations.max_level)

func test_hidden_at_night_shown_by_day() -> void:
	assert_false(pad.label.visible, "night 1")
	assert_false(pad.marker.visible)
	assert_false(pad.name_label.visible)
	main.phase_controller.debug_skip_to_day()
	await _ticks(1)
	assert_true(pad.label.visible)
	assert_true(pad.name_label.visible)
	assert_true(pad.marker.visible)
	assert_eq(pad.label.text, str(GameState.station_next_cost(&"counter")))

func test_standing_on_the_pad_buys_a_level() -> void:
	main.phase_controller.debug_skip_to_day()
	var cost := GameState.station_next_cost(&"counter")
	GameState.add_gold(cost)
	await TestHelpers.walk_in(main.hero, MapLayout.STATION_PADS[&"counter"])
	await _ticks(_pay_ticks(cost))
	assert_eq(GameState.station_level(&"counter"), 1)
	assert_eq(GameState.gold, 0)
	assert_true(pad._pips[0].visible)
	assert_false(pad._pips[1].visible)
	assert_eq(pad.label.text, str(GameState.station_remaining_cost(&"counter")))

func test_the_ring_shows_paid_over_cost() -> void:
	main.phase_controller.debug_skip_to_day()
	var cost := GameState.station_next_cost(&"counter")
	var held := cost / 2
	GameState.add_gold(held)
	await TestHelpers.walk_in(main.hero, MapLayout.STATION_PADS[&"counter"])
	await _ticks(_pay_ticks(cost))
	assert_eq(int(GameState.stations[&"counter"].paid), held, "all the gold held, level not complete")
	assert_true(pad.zone.ring.visible)
	assert_eq(pad.label.text, str(cost - held))

func test_max_level_reads_max_and_takes_nothing() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_station_level(&"counter", Balance.data.stations.max_level)
	GameState.add_gold(100)
	await TestHelpers.walk_in(main.hero, MapLayout.STATION_PADS[&"counter"])
	await _ticks(_pay_ticks(10))
	assert_eq(pad.label.text, tr("MAX"))
	assert_false(pad.marker.visible)
	assert_eq(GameState.gold, 100)

func test_night_stops_a_payment_and_keeps_the_partial() -> void:
	# Review Focus 3
	main.phase_controller.debug_skip_to_day()
	var cost := GameState.station_next_cost(&"counter")
	GameState.add_gold(cost)
	await TestHelpers.walk_in(main.hero, MapLayout.STATION_PADS[&"counter"])
	await _ticks(_pay_ticks(3))
	var paid := int(GameState.stations[&"counter"].paid)
	assert_between(paid, 1, cost - 1)
	EventBus.closeup_requested.emit()
	await _ticks(_pay_ticks(20))
	assert_eq(main.phase_controller.phase, Phase.NIGHT)
	assert_eq(int(GameState.stations[&"counter"].paid), paid, "nothing is paid at night")
	assert_false(pad.label.visible)
	assert_false(pad.zone.ring.visible)

func test_refresh_is_safe_before_the_first_new_game() -> void:
	GameState.stations = {}  # test-only setup: the boot window
	pad.refresh()
	assert_eq(pad.label.text, "")
	GameState.new_game(8)

func test_build_spots_keep_their_pips() -> void:
	var spot: BuildSpot = main.world.build_spots["tower_nw"]
	assert_eq(spot._pips.size(), Balance.data.build.max_level)
	assert_eq(spot._pips[0].name, "Pip0")

func test_each_pad_names_its_station() -> void:
	assert_eq(main.world.upgrade_pads[&"counter"].name_label.text, tr("Counter"))
	assert_eq(main.world.upgrade_pads[&"freezer"].name_label.text, tr("Freezer"))

func test_standing_on_the_pad_at_night_pays_nothing() -> void:
	var cost := GameState.station_next_cost(&"counter")
	GameState.add_gold(cost)
	await TestHelpers.walk_in(main.hero, MapLayout.STATION_PADS[&"counter"])
	await _ticks(_pay_ticks(10))
	assert_eq(int(GameState.stations[&"counter"].paid), 0)
	assert_eq(GameState.gold, cost)
