extends GutTest

var bd: BalanceData

func before_each() -> void:
	Balance.reset()
	bd = Balance.data
	GameState.new_game(20260930)

func after_each() -> void:
	SaveCodec.MIGRATIONS.clear()

func _decode(state: Dictionary) -> Dictionary:
	return SaveCodec.decode(SaveCodec.encode(state, "t", 1), GameState.SCHEMA_VERSION, bd)

func _v3() -> Dictionary:
	var s := GameState.to_dict()
	s.v = 3
	s.erase("stations")
	return s

func test_schema_is_4_and_the_snapshot_carries_stations_with_string_keys() -> void:
	assert_eq(GameState.SCHEMA_VERSION, 4)
	var d := GameState.to_dict()
	assert_eq(d.stations, {"counter": {"level": 0, "paid": 0}, "freezer": {"level": 0, "paid": 0}})
	for k in d.stations:
		assert_eq(typeof(k), TYPE_STRING)

func test_round_trip_with_upgraded_stations() -> void:
	GameState.add_gold(500)
	GameState.debug_set_station_level(&"counter", 3)
	GameState.pay_into_station(&"freezer", 10)
	var d := GameState.to_dict()
	var r := _decode(d)
	assert_true(r.ok, r.reason)
	GameState.new_game(1)
	GameState.from_dict(r.state)
	assert_eq(GameState.station_level(&"counter"), 3)
	assert_eq(GameState.stations[&"freezer"], {"level": 0, "paid": 10})
	assert_eq(typeof(GameState.stations[&"freezer"].paid), TYPE_INT, "JSON floats become ints again")
	assert_eq(GameState.to_dict(), d)

func test_a_v3_save_loads_with_both_stations_at_level_0() -> void:
	var r := _decode(_v3())
	assert_true(r.ok, r.reason)
	assert_eq(int(r.state.v), 4)
	assert_eq(r.state.stations, SaveCodec.fresh_stations())
	GameState.from_dict(r.state)
	assert_eq(GameState.station_level(&"counter"), 0)

func test_the_built_in_step_survives_clearing_the_test_hook() -> void:
	SaveCodec.MIGRATIONS.clear()
	assert_true(_decode(_v3()).ok)

func test_a_registered_step_overrides_the_built_in_one() -> void:
	SaveCodec.MIGRATIONS[3] = func(st: Dictionary) -> Dictionary:
		st.v = 4
		st.stations = {"counter": {"level": 2, "paid": 0}, "freezer": {"level": 0, "paid": 0}}
		return st
	var r := _decode(_v3())
	assert_true(r.ok, r.reason)
	assert_eq(int(r.state.stations.counter.level), 2)

func test_a_v2_save_has_no_step() -> void:
	var s := _v3()
	s.v = 2
	var r := _decode(s)
	assert_eq([r.ok, r.reason], [false, "version"])

func _bad(mutate: Callable) -> String:
	var s := GameState.to_dict()
	mutate.call(s)
	return _decode(s).reason

func test_validation() -> void:
	assert_eq(_bad(func(s): s.erase("stations")), "content")
	assert_eq(_bad(func(s): s.stations = []), "content")
	assert_eq(_bad(func(s): s.stations.erase("freezer")), "content")
	assert_eq(_bad(func(s): s.stations["oven"] = {"level": 0, "paid": 0}), "content")
	assert_eq(_bad(func(s): s.stations.counter = {"level": 0}), "content")
	assert_eq(_bad(func(s): s.stations.counter.level = "1"), "content")
	assert_eq(_bad(func(s): s.stations.counter.level = -1), "content")
	assert_eq(_bad(func(s): s.stations.counter.level = bd.stations.max_level + 1), "content")
	assert_eq(_bad(func(s): s.stations.counter.paid = -1), "content")
	assert_eq(_bad(func(s): s.stations.counter.level = bd.stations.max_level), "")

func test_a_paid_amount_above_the_cost_loads_and_the_pad_still_works() -> void:
	# Review Focus 1: costs were lowered after the save was written.
	var s := GameState.to_dict()
	s.stations.counter.paid = 9999
	s.gold = 5
	var r := _decode(s)
	assert_true(r.ok, r.reason)
	GameState.from_dict(r.state)
	var cost := GameState.station_next_cost(&"counter")
	assert_eq(int(GameState.stations[&"counter"].paid), cost - 1)
	assert_eq(GameState.pay_into_station(&"counter", 5), 1)
	assert_eq(GameState.station_level(&"counter"), 1)

func test_paid_at_max_level_is_dropped_on_load() -> void:
	var s := GameState.to_dict()
	s.stations.freezer = {"level": bd.stations.max_level, "paid": 7}
	var r := _decode(s)
	assert_true(r.ok, r.reason)
	GameState.from_dict(r.state)
	assert_eq(GameState.stations[&"freezer"], {"level": bd.stations.max_level, "paid": 0})

func test_the_v3_fixtures_still_load() -> void:
	for name in ["night3_start", "night3_closeup"]:
		var text := FileAccess.get_file_as_string("res://export/fixtures/%s.save.json" % name)
		var r := SaveCodec.decode(text, GameState.SCHEMA_VERSION, bd)
		assert_true(r.ok, "%s: %s" % [name, r.reason])
		assert_eq(r.state.stations, SaveCodec.fresh_stations())
