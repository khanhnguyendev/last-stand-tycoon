extends GutTest

func before_each() -> void:
	Balance.reset()
	GameState.new_game(1234)

func _max_hp() -> float:
	return Balance.data.build.diner_max_hp

func _cap() -> int:
	return Balance.data.hero.carry_capacity

func test_new_game_defaults() -> void:
	assert_eq(GameState.day, 1)
	assert_eq(GameState.gold, 0)
	assert_eq(GameState.diner_hp, _max_hp())
	assert_eq(GameState.lane_plan.size(), 3)
	assert_eq(GameState.lane_plan[0].main, "north")
	for id in MapLayout.SPOT_IDS:
		assert_eq(GameState.buildings[id], {"level": 0, "paid": 0, "hp": 0.0})

func test_round_trip_identity() -> void:
	GameState.add_gold(55)
	GameState.add_freezer(7)
	var d := GameState.to_dict()
	GameState.new_game(999)
	GameState.from_dict(d)
	assert_eq(GameState.to_dict(), d)

func test_round_trip_through_json_keeps_ints() -> void:
	# Review Focus 1: S3 will serialize; JSON turns ints into floats.
	# Full precision (4th arg of stringify) is required: the default drops float digits.
	GameState.add_gold(1000)
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	GameState.advance_day()
	GameState.damage_diner(1.0 / 3.0)
	var d := GameState.to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d, "", true, true))
	GameState.new_game(1)
	GameState.from_dict(parsed)
	assert_eq(GameState.to_dict(), d)
	assert_eq(GameState.diner_hp, d.diner_hp, "float survives JSON exactly")
	assert_eq(typeof(GameState.gold), TYPE_INT)
	assert_eq(typeof(GameState.buildings.fence_w.level), TYPE_INT)
	assert_eq(typeof(GameState.lane_plan[0].main_count), TYPE_INT)

func test_from_dict_emits_state_restored() -> void:
	watch_signals(EventBus)
	GameState.from_dict(GameState.to_dict())
	assert_signal_emitted(EventBus, "state_restored")

func test_new_game_emits_state_restored() -> void:
	watch_signals(EventBus)
	GameState.new_game(7)
	assert_signal_emitted(EventBus, "state_restored")

func test_carry_capacity_and_transfers() -> void:
	GameState.add_freezer(_cap() + 4)
	assert_eq(GameState.move_freezer_to_carry(_cap() + 4), _cap())
	assert_eq(GameState.carried_steaks, _cap())
	assert_false(GameState.pick_steak())
	assert_eq(GameState.move_carry_to_counter(_cap()), _cap())
	assert_eq(GameState.counter_steaks, _cap())
	assert_eq(GameState.freezer_steaks, 4)

func test_counter_capacity() -> void:
	var cap := Balance.data.economy.counter_capacity
	GameState.counter_steaks = cap - 1  # test-only setup write
	GameState.carried_steaks = 3
	assert_eq(GameState.move_carry_to_counter(3), 1)
	assert_eq(GameState.counter_steaks, cap)

func test_sell_is_atomic_and_partial() -> void:
	var price := Balance.data.economy.gold_per_steak
	GameState.counter_steaks = 1
	watch_signals(EventBus)
	assert_eq(GameState.sell_from_counter(2), 1)
	assert_eq(GameState.counter_steaks, 0)
	assert_eq(GameState.gold_pile, price)
	assert_signal_emitted_with_parameters(EventBus, "steak_sold", [1, price])
	assert_eq(GameState.sell_from_counter(2), 0)

func test_collect_pile() -> void:
	GameState.gold_pile = 9
	assert_eq(GameState.collect_pile(), 9)
	assert_eq(GameState.gold, 9)
	assert_eq(GameState.gold_pile, 0)

func test_pay_builds_and_levels() -> void:
	var cost := GameState.next_level_cost("fence_n")
	GameState.add_gold(cost * 5)
	watch_signals(EventBus)
	assert_eq(GameState.pay_into_spot("fence_n", cost - 1), cost - 1)
	assert_eq(GameState.buildings.fence_n.paid, cost - 1)
	assert_eq(GameState.pay_into_spot("fence_n", cost), 1, "pays only what is left")
	assert_eq(GameState.buildings.fence_n, {"level": 1, "paid": 0, "hp": GameState.fence_max_hp(1)})
	assert_signal_emitted_with_parameters(EventBus, "build_completed", [&"fence_n", 1])
	assert_eq(GameState.gold, cost * 4)
	assert_eq(GameState.next_level_cost("fence_n"), Economy.level_cost("fence_n", 1, Balance.data.build))

func test_diner_fell_once() -> void:
	watch_signals(EventBus)
	GameState.damage_diner(_max_hp() - 1.0)
	GameState.damage_diner(5.0)
	GameState.damage_diner(5.0)
	assert_eq(GameState.diner_hp, 0.0)
	assert_signal_emit_count(EventBus, "diner_fell", 1)

func test_fence_damage_rubble_and_dawn() -> void:
	GameState.add_gold(GameState.next_level_cost("fence_w") * 2)
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	GameState.pay_into_spot("fence_e", GameState.next_level_cost("fence_e"))
	GameState.damage_fence("fence_w", 1e6)
	GameState.damage_fence("fence_e", 1.0)
	assert_eq(GameState.buildings.fence_w.hp, 0.0)
	GameState.damage_diner(_max_hp() / 3.0)
	GameState.heal_for_dawn()
	GameState.reset_destroyed_fences()
	assert_eq(GameState.buildings.fence_w, {"level": 0, "paid": 0, "hp": 0.0})
	assert_eq(GameState.buildings.fence_e.hp, GameState.fence_max_hp(1))
	assert_eq(GameState.diner_hp, _max_hp())

func test_advance_day_makes_new_plan() -> void:
	GameState.advance_day()
	assert_eq(GameState.day, 2)
	assert_ne(GameState.lane_plan[0].side, "")
