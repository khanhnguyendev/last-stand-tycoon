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

func test_new_game_clears_cards() -> void:
	GameState.debug_grant_card(&"tank")
	GameState.new_game(5)
	assert_eq([GameState.cards, GameState.card_offer, GameState.guards], [{}, [] as Array[StringName], {}])

func test_offer_and_pick() -> void:
	watch_signals(EventBus)
	GameState.set_card_offer([&"archer", &"tank", &"move_speed"] as Array[StringName])
	assert_signal_emitted_with_parameters(EventBus, "card_offered", [[&"archer", &"tank", &"move_speed"]])
	var lvl := GameState.pick_card(&"move_speed")
	assert_eq(lvl, 1)
	assert_eq(GameState.card_level(&"move_speed"), 1)
	assert_eq(GameState.card_offer, [] as Array[StringName])
	assert_signal_emitted_with_parameters(EventBus, "card_picked", [&"move_speed", 1])
	assert_false(GameState.guards.has(&"move_speed"))

func test_clear_offer_emits_nothing() -> void:
	GameState.set_card_offer([&"archer"] as Array[StringName])
	watch_signals(EventBus)
	GameState.clear_card_offer()
	assert_eq(GameState.card_offer, [] as Array[StringName])
	assert_signal_not_emitted(EventBus, "card_offered")

func test_debug_grant_card_drops_a_maxed_card_from_the_restored_offer() -> void:
	GameState.set_card_offer([&"tank", &"archer"] as Array[StringName])
	GameState.cards[&"tank"] = Balance.data.cards.max_level - 1  # test-only setup write
	GameState.debug_grant_card(&"tank")
	assert_eq(GameState.card_offer, [&"archer"] as Array[StringName])

func test_tank_gets_hp_archer_does_not() -> void:
	var t := Balance.data.guards.tank
	GameState.debug_grant_card(&"archer")
	assert_false(GameState.guards.has(&"archer"), "the roof archer has no HP (spec 5.2)")
	GameState.debug_grant_card(&"tank")
	assert_eq(GameState.guards[&"tank"].hp, t.max_hp)
	GameState.debug_grant_card(&"tank")
	assert_almost_eq(float(GameState.guards[&"tank"].hp), t.max_hp * (1.0 + t.hp_growth), 1e-3,
		"level-up sets HP to the new max")

func test_damage_knockout_once_then_noop_and_revive() -> void:
	var mx := Balance.data.guards.tank.max_hp
	GameState.debug_grant_card(&"tank")
	watch_signals(EventBus)
	var hit := mx * 0.25
	GameState.damage_guard(&"tank", hit)
	assert_signal_emitted_with_parameters(EventBus, "guard_damaged", [&"tank", mx - hit])
	GameState.damage_guard(&"tank", mx)
	assert_eq(GameState.guards[&"tank"].hp, 0.0)
	assert_signal_emit_count(EventBus, "guard_knocked_out", 1)
	GameState.damage_guard(&"tank", 5.0)
	assert_signal_emit_count(EventBus, "guard_damaged", 2)
	assert_signal_emit_count(EventBus, "guard_knocked_out", 1)
	GameState.damage_guard(&"archer", 5.0)  # no entry: no-op
	assert_signal_emit_count(EventBus, "guard_damaged", 2)
	assert_false(GameState.guards.has(&"archer"))
	GameState.revive_guard(&"tank")
	assert_eq(GameState.guards[&"tank"].hp, mx)
	assert_signal_emitted_with_parameters(EventBus, "guard_revived", [&"tank"])

func test_dawn_heals_guards_with_signal() -> void:
	GameState.debug_grant_card(&"tank")
	GameState.damage_guard(&"tank", 1000.0)
	GameState.damage_diner(1.0)
	watch_signals(EventBus)
	var seen := []
	EventBus.guard_healed.connect(func(_g, _h): seen.append(GameState.diner_hp), CONNECT_ONE_SHOT)
	GameState.heal_for_dawn()
	assert_eq(seen, [Balance.data.build.diner_max_hp], "the diner is healed first")
	var mx := Balance.data.guards.tank.max_hp
	assert_eq(GameState.guards[&"tank"].hp, mx)
	assert_signal_emitted_with_parameters(EventBus, "guard_healed", [&"tank", mx])

func test_card_offered_emits_a_copy() -> void:
	var got := []
	EventBus.card_offered.connect(func(o): got.append(o), CONNECT_ONE_SHOT)
	GameState.set_card_offer([&"archer", &"tank"] as Array[StringName])
	assert_eq(got.size(), 1)
	got[0].append(&"x")
	assert_eq(GameState.card_offer, [&"archer", &"tank"] as Array[StringName])

func test_debug_grant_keeps_an_open_offer() -> void:
	GameState.set_card_offer([&"archer", &"move_speed"] as Array[StringName])
	GameState.debug_grant_card(&"tank")
	assert_eq(GameState.card_level(&"tank"), 1)
	assert_eq(GameState.card_offer, [&"archer", &"move_speed"] as Array[StringName])

func test_card_effects_reach_economy() -> void:
	var cb := Balance.data.cards
	GameState.debug_grant_card(&"carry_capacity")
	GameState.debug_grant_card(&"gold_per_steak")
	var cap := Balance.data.hero.carry_capacity + cb.carry_step
	var price := Balance.data.economy.gold_per_steak + cb.gold_step
	assert_eq(GameState.carry_capacity(), cap)
	assert_eq(GameState.gold_per_steak(), price)
	GameState.freezer_steaks = cap + 10  # test-only setup write
	assert_eq(GameState.move_freezer_to_carry(cap + 10), cap)
	GameState.carried_steaks = 0  # test-only setup write
	GameState.counter_steaks = 2  # test-only setup write
	GameState.sell_from_counter(2)
	assert_eq(GameState.gold_pile, 2 * price)

func test_round_trip_v2_through_json() -> void:
	GameState.debug_grant_card(&"tank")
	GameState.debug_grant_card(&"hero_damage")
	GameState.damage_guard(&"tank", 1.0 / 3.0)
	GameState.set_card_offer([&"archer", &"move_speed"] as Array[StringName])
	var d := GameState.to_dict()
	assert_eq(int(d.v), GameState.SCHEMA_VERSION)
	assert_eq(d.cards, {"tank": 1, "hero_damage": 1})
	assert_eq(d.card_offer, ["archer", "move_speed"])
	assert_eq(d.guards, {"tank": {"hp": Balance.data.guards.tank.max_hp - 1.0 / 3.0}})
	var back = JSON.parse_string(JSON.stringify(d, "", true, true))  # D-146 full precision
	GameState.new_game(1)
	GameState.from_dict(back)
	assert_eq(GameState.to_dict(), d)
	assert_eq(GameState.card_level(&"tank"), 1)
	assert_eq(GameState.card_offer, [&"archer", &"move_speed"] as Array[StringName])

func test_night_fails_and_mercy_factor() -> void:
	var wb := Balance.data.wave
	assert_eq(GameState.night_fails, 0)
	assert_almost_eq(GameState.mercy_factor(), 1.0, 1e-6)
	for n in range(0, 7):
		GameState.set_night_fails(n)
		assert_almost_eq(GameState.mercy_factor(), maxf(1.0 - wb.mercy_step * n, wb.mercy_floor), 1e-6)
	GameState.set_night_fails(-3)
	assert_eq(GameState.night_fails, 0, "never negative")
	GameState.set_night_fails(2)
	GameState.clear_night_fails()
	assert_eq(GameState.night_fails, 0)
	GameState.set_night_fails(2)
	GameState.new_game(8)
	assert_eq(GameState.night_fails, 0, "a new game starts without mercy")

func test_round_trip_v3_carries_night_fails() -> void:
	GameState.set_night_fails(3)
	var d := GameState.to_dict()
	assert_eq(int(d.v), 3)
	assert_eq(int(d.night_fails), 3)
	var back = JSON.parse_string(JSON.stringify(d, "", true, true))
	GameState.new_game(1)
	GameState.from_dict(back)
	assert_eq(GameState.night_fails, 3)
	assert_eq(GameState.to_dict(), d)
