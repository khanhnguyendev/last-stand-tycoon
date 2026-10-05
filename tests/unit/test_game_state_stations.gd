extends GutTest

var sb: StationBalance
var _events: Array = []

func before_each() -> void:
	Balance.reset()
	sb = Balance.data.stations
	GameState.new_game(1234)
	_events = []
	EventBus.gold_changed.connect(_on_gold)
	EventBus.station_changed.connect(_on_changed)
	EventBus.station_upgraded.connect(_on_upgraded)

func after_each() -> void:
	EventBus.gold_changed.disconnect(_on_gold)
	EventBus.station_changed.disconnect(_on_changed)
	EventBus.station_upgraded.disconnect(_on_upgraded)

func _on_gold(_g: int, d: int) -> void:
	_events.append(["gold", d])

func _on_changed(id: StringName, level: int, paid: int) -> void:
	_events.append(["changed", id, level, paid])

func _on_upgraded(id: StringName, level: int) -> void:
	_events.append(["upgraded", id, level])

func test_new_game_has_both_stations_at_level_0() -> void:
	assert_eq(GameState.stations.size(), 2)
	for id in StationEffects.IDS:
		assert_eq(GameState.stations[id], {"level": 0, "paid": 0})
		assert_eq(GameState.station_level(id), 0)

func test_before_the_first_new_game_everything_reads_as_level_0() -> void:
	GameState.stations = {}  # test-only setup: the boot window (Main builds the world before new_game)
	for id in StationEffects.IDS:
		assert_eq(GameState.station_level(id), 0)
		assert_eq(GameState.station_next_cost(id), -1)
		assert_eq(GameState.station_remaining_cost(id), -1)
		assert_eq(GameState.pay_into_station(id, 10), 0)
	assert_eq(GameState.carry_capacity(), Balance.data.hero.carry_capacity)
	assert_eq(GameState.counter_capacity(), sb.counter_capacity[0])
	GameState.new_game(1234)  # leave a whole state behind

func test_partial_payment() -> void:
	GameState.add_gold(100)
	_events = []
	assert_eq(GameState.pay_into_station(&"counter", 10), 10)
	assert_eq(GameState.gold, 90)
	assert_eq(GameState.stations[&"counter"], {"level": 0, "paid": 10})
	assert_eq(GameState.station_remaining_cost(&"counter"), 20)
	assert_eq(_events, [["gold", -10], ["changed", &"counter", 0, 10]])

func test_completing_a_level_emits_changed_then_upgraded() -> void:
	GameState.add_gold(100)
	GameState.pay_into_station(&"counter", 25)
	_events = []
	assert_eq(GameState.pay_into_station(&"counter", 50), 5, "never more than the level still costs")
	assert_eq(GameState.gold, 70)
	assert_eq(GameState.stations[&"counter"], {"level": 1, "paid": 0})
	assert_eq(_events, [["gold", -5], ["changed", &"counter", 1, 0], ["upgraded", &"counter", 1]])
	assert_eq(GameState.station_next_cost(&"counter"), 60)

func test_payment_is_capped_by_the_gold_held() -> void:
	# Review Focus 4: less gold than one drain tick.
	GameState.add_gold(1)
	assert_eq(GameState.pay_into_station(&"freezer", 2), 1)
	assert_eq(GameState.gold, 0)
	assert_eq(GameState.pay_into_station(&"freezer", 2), 0)
	assert_eq(GameState.stations[&"freezer"].paid, 1)

func test_zero_and_negative_amounts_do_nothing() -> void:
	GameState.add_gold(50)
	_events = []
	assert_eq(GameState.pay_into_station(&"counter", 0), 0)
	assert_eq(GameState.pay_into_station(&"counter", -5), 0)
	assert_eq(GameState.gold, 50)
	assert_eq(_events, [])

func test_max_level_takes_no_gold() -> void:
	GameState.debug_set_station_level(&"counter", sb.max_level)
	GameState.add_gold(999)
	_events = []
	assert_eq(GameState.station_next_cost(&"counter"), -1)
	assert_eq(GameState.station_remaining_cost(&"counter"), -1)
	assert_eq(GameState.pay_into_station(&"counter", 50), 0)
	assert_eq(GameState.gold, 999)
	assert_eq(_events, [])

func test_paying_the_whole_ladder_costs_the_sum_of_the_curve() -> void:
	var total := 0
	for l in sb.max_level:
		total += StationEffects.level_cost(&"freezer", l, sb)
	GameState.add_gold(total)
	var guard := 10000
	while GameState.station_level(&"freezer") < sb.max_level and guard > 0:
		GameState.pay_into_station(&"freezer", 7)
		guard -= 1
	assert_eq(GameState.station_level(&"freezer"), sb.max_level)
	assert_eq(GameState.gold, 0)

func test_freezer_level_adds_to_carry() -> void:
	var base := GameState.carry_capacity()
	GameState.debug_set_station_level(&"freezer", 3)
	assert_eq(GameState.carry_capacity(), base + sb.carry_bonus[3])
	GameState.debug_grant_card(&"carry_capacity")
	assert_eq(GameState.carry_capacity(), base + sb.carry_bonus[3] + Balance.data.cards.carry_step)

func test_counter_level_raises_what_the_counter_takes() -> void:
	GameState.carried_steaks = 40  # test-only setup
	assert_eq(GameState.move_carry_to_counter(40), sb.counter_capacity[0])
	GameState.debug_set_station_level(&"counter", 2)
	assert_eq(GameState.move_carry_to_counter(40), sb.counter_capacity[2] - sb.counter_capacity[0])
	assert_eq(GameState.counter_steaks, sb.counter_capacity[2])

func test_debug_set_clamps_and_emits() -> void:
	_events = []
	GameState.debug_set_station_level(&"counter", 99)
	assert_eq(GameState.stations[&"counter"], {"level": sb.max_level, "paid": 0})
	assert_eq(_events, [["changed", &"counter", sb.max_level, 0]])

func test_new_game_resets_stations() -> void:
	GameState.debug_set_station_level(&"counter", 4)
	GameState.new_game(5)
	assert_eq(GameState.station_level(&"counter"), 0)
