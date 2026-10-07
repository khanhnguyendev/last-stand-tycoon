extends GutTest

func before_each() -> void:
	Balance.reset()

func _state() -> Dictionary:
	var b := {}
	for id in MapLayout.SPOT_IDS:
		b[id] = {"level": 0, "paid": 0, "hp": 0.0}
	return {"gold": 0, "gold_pile": 0, "freezer_steaks": 0, "carried_steaks": 0, "counter_steaks": 0, "buildings": b}

func test_pulses_when_nothing_to_do() -> void:
	assert_true(Pulse.should_pulse(_state(), Balance.data))

func test_each_stock_blocks_pulse() -> void:
	for key in ["freezer_steaks", "carried_steaks", "counter_steaks", "gold_pile"]:
		var s := _state()
		s[key] = 1
		assert_false(Pulse.should_pulse(s, Balance.data), key)

func test_affordable_build_blocks_pulse() -> void:
	var bb: BuildBalance = Balance.data.build
	var cheapest := mini(bb.tower_cost, bb.fence_cost)
	var s := _state()
	s.gold = cheapest
	assert_false(Pulse.should_pulse(s, Balance.data))
	s.gold = cheapest - 1
	assert_true(Pulse.should_pulse(s, Balance.data))

func test_partial_paid_counts() -> void:
	var bb: BuildBalance = Balance.data.build
	var s := _state()
	s.gold = 1
	assert_true(Pulse.should_pulse(s, Balance.data), "precondition")
	s.buildings.fence_w.paid = Economy.level_cost("fence_w", 0, bb) - 1  # 1 gold remaining
	assert_false(Pulse.should_pulse(s, Balance.data))

func test_max_level_spots_ignored() -> void:
	var bb: BuildBalance = Balance.data.build
	var s := _state()
	s.gold = 10000
	for id in MapLayout.SPOT_IDS:
		s.buildings[id].level = bb.max_level
	assert_true(Pulse.should_pulse(s, Balance.data))

func test_one_upgradable_spot_among_maxed_decides_pulse() -> void:
	var bb: BuildBalance = Balance.data.build
	var s := _state()
	for id in MapLayout.SPOT_IDS:
		s.buildings[id].level = bb.max_level
	s.buildings.tower_ne.level = 1
	var cost := Economy.level_cost("tower_ne", 1, bb)
	s.gold = cost
	assert_false(Pulse.should_pulse(s, Balance.data))
	s.gold = cost - 1
	assert_true(Pulse.should_pulse(s, Balance.data))

func _with_stations(s: Dictionary) -> Dictionary:
	s["stations"] = {"counter": {"level": 0, "paid": 0}, "freezer": {"level": 0, "paid": 0}}
	return s

func test_a_state_without_stations_ignores_them() -> void:
	var s := _state()
	s.gold = 1
	assert_true(Pulse.should_pulse(s, Balance.data))

func test_an_affordable_station_blocks_the_pulse() -> void:
	var sb := Balance.data.stations
	var cheapest := mini(sb.counter_cost, sb.freezer_cost)
	var s := _with_stations(_state())
	for id in MapLayout.SPOT_IDS:
		s.buildings[id].level = Balance.data.build.max_level  # no spot is buyable: only the stations decide
	s.gold = cheapest
	assert_false(Pulse.should_pulse(s, Balance.data))
	s.gold = cheapest - 1
	assert_true(Pulse.should_pulse(s, Balance.data))

func test_a_partly_paid_station_counts_what_is_left() -> void:
	var s := _with_stations(_state())
	for id in MapLayout.SPOT_IDS:
		s.buildings[id].level = Balance.data.build.max_level
	s.gold = 1
	s.stations.counter.paid = Balance.data.stations.counter_cost - 1
	assert_false(Pulse.should_pulse(s, Balance.data))

func test_maxed_stations_are_ignored() -> void:
	var s := _with_stations(_state())
	for id in s.stations:
		s.stations[id].level = Balance.data.stations.max_level
	for id in MapLayout.SPOT_IDS:
		s.buildings[id].level = Balance.data.build.max_level
	s.gold = 100000
	assert_true(Pulse.should_pulse(s, Balance.data))

func test_affordable_tier_up_stops_the_pulse() -> void:
	Balance.reset()
	GameState.new_game(1)
	for id in GameState.buildings:  # test-only setup: max every spot
		GameState.buildings[id].level = Balance.data.build.max_level
	GameState.stations[&"counter"].level = Balance.data.stations.max_level
	GameState.stations[&"freezer"].level = Balance.data.stations.max_level
	GameState.gold = 499  # test-only setup
	assert_true(Pulse.should_pulse(GameState.to_dict(), Balance.data))
	GameState.gold = 500  # test-only setup
	assert_false(Pulse.should_pulse(GameState.to_dict(), Balance.data), "500 gold buys the tier")
	GameState.boss_pending = true  # test-only setup
	assert_true(Pulse.should_pulse(GameState.to_dict(), Balance.data), "paid: nothing left to buy")
	var no_tier := GameState.to_dict()
	for k in ["tier", "tier_day", "tier_paid", "boss_pending"]:
		no_tier.erase(k)
	GameState.boss_pending = false  # test-only setup
	assert_true(Pulse.should_pulse(no_tier, Balance.data), "a state without tier keys ignores the tier (the guide's view)")

## Task 21: the close-up sign's pulse waits while the tier sign is affordable. At tier 2 that is now the tier-3 sign (1500).
## Mutation: a tier cost read from the wrong index / a build with no third entry pulses at 1500 gold.
func test_an_affordable_tier_3_sign_blocks_the_pulse_at_tier_2_and_nothing_else_does() -> void:
	var s := _state()
	for id in MapLayout.SPOT_IDS:
		s.buildings[id].level = Balance.data.build.max_level  # nothing else to buy
	s.tier = 2
	s.tier_paid = 0
	s.boss_pending = false
	s.gold = 1499
	assert_true(Pulse.should_pulse(s, Balance.data), "one gold short of the front lot")
	s.gold = 1500
	assert_false(Pulse.should_pulse(s, Balance.data), "affordable: something is left to do")
	s.gold = 1000
	s.tier_paid = 500
	assert_false(Pulse.should_pulse(s, Balance.data), "a partial payment counts")
	s.tier_paid = 499
	assert_true(Pulse.should_pulse(s, Balance.data))
	s.gold = 5000
	s.tier_paid = 0
	s.boss_pending = true
	assert_true(Pulse.should_pulse(s, Balance.data), "paid in full: nothing to buy")
	s.boss_pending = false
	s.tier = 3
	assert_true(Pulse.should_pulse(s, Balance.data), "tier 3 has no sign")
