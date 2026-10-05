extends GutTest

var main: Main
var _fx: Array = []

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(8)
	main.phase_controller.debug_skip_to_day()
	_fx = []
	EventBus.fx_requested.connect(_on_fx)

func after_each() -> void:
	EventBus.fx_requested.disconnect(_on_fx)

func _on_fx(kind: StringName, pos: Vector3) -> void:
	_fx.append([kind, pos])

func _max_everything_but_the_counter() -> void:
	for id in MapLayout.SPOT_IDS:
		GameState.buildings[id].level = Balance.data.build.max_level  # test-only setup
	GameState.debug_set_station_level(&"freezer", Balance.data.stations.max_level)
	GameState.debug_set_station_level(&"counter", Balance.data.stations.max_level - 1)

func test_the_sign_pulses_after_the_last_station_level_is_bought() -> void:
	_max_everything_but_the_counter()
	var cost := GameState.station_next_cost(&"counter")
	GameState.add_gold(cost)
	assert_false(main.world.closeup_sign.pulsing, "something is affordable")
	GameState.pay_into_station(&"counter", cost)
	assert_eq(GameState.station_level(&"counter"), Balance.data.stations.max_level)
	assert_true(main.world.closeup_sign.pulsing, "nothing is left to buy")

func test_an_upgrade_sparkles_at_the_pad() -> void:
	GameState.add_gold(30)
	GameState.pay_into_station(&"counter", 30)
	var at := MapLayout.to3(MapLayout.STATION_PADS[&"counter"], 1.0)
	assert_true(_fx.has([&"sparkle", at]), "sparkle at the counter pad: %s" % [_fx])

func test_the_guide_snapshot_ignores_stations() -> void:
	main.settings_store = SettingsStore.with_dir("user://test_station_guide")
	main.settings_store.wipe_for_tests()
	main.settings_store.load_settings()
	var guide := Guide.new()
	main.add_child(guide)
	guide.setup(main)
	GameState.add_gold(Balance.data.stations.freezer_cost)  # covers a pad; the loop below leaves no spot to buy
	for id in MapLayout.SPOT_IDS:
		GameState.buildings[id].level = Balance.data.build.max_level  # test-only setup: no spot is buyable
	var snap: Dictionary = guide.snapshot()
	assert_true(bool(snap.should_pulse), "the tutorial's close rule does not wait for stations")
	assert_false(Pulse.should_pulse(GameState.to_dict(), Balance.data), "the sign itself does wait")
	assert_eq(int(snap.counter_capacity), GameState.counter_capacity())
