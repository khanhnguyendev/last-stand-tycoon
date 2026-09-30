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
