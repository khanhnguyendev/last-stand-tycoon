extends GutTest
## E5 spec 6.1: tier state, the sign payment, the tier-up.

var _events: Array = []

func before_each() -> void:
	Balance.reset()
	_events.clear()
	GameState.new_game(20260930)
	EventBus.tier_changed.connect(_on_changed)
	EventBus.tier_paid_up.connect(_on_paid_up)
	EventBus.tier_reached.connect(_on_reached)
	EventBus.gold_changed.connect(_on_gold)

func after_each() -> void:
	EventBus.tier_changed.disconnect(_on_changed)
	EventBus.tier_paid_up.disconnect(_on_paid_up)
	EventBus.tier_reached.disconnect(_on_reached)
	EventBus.gold_changed.disconnect(_on_gold)

func _on_changed(t: int, p: int, b: bool) -> void: _events.append(["changed", t, p, b])
func _on_paid_up(n: int) -> void: _events.append(["paid_up", n])
func _on_reached(t: int) -> void: _events.append(["reached", t])
func _on_gold(g: int, d: int) -> void: _events.append(["gold", g, d])

func test_new_game_is_tier_1() -> void:
	assert_eq([GameState.tier, GameState.tier_day, GameState.tier_paid, GameState.boss_pending], [1, 1, 0, false])
	assert_eq(GameState.buildings.keys(), MapLayout.spots_for_tier(1))
	assert_eq(GameState.tier_next_cost(), 500)
	assert_eq(GameState.tier_remaining_cost(), 500)
	assert_eq(GameState.pressure(), 1)
	assert_false(GameState.is_boss_night())

func test_partial_payment_is_capped_by_gold() -> void:
	GameState.add_gold(40)
	_events.clear()
	assert_eq(GameState.pay_into_tier(100), 40)
	assert_eq([GameState.gold, GameState.tier_paid, GameState.boss_pending], [0, 40, false])
	assert_eq(GameState.tier_remaining_cost(), 460)
	assert_eq(_events, [["gold", 0, -40], ["changed", 1, 40, false]])

func test_completing_the_payment_flags_the_boss_night_once() -> void:
	GameState.add_gold(600)
	GameState.pay_into_tier(450)
	_events.clear()
	assert_eq(GameState.pay_into_tier(100), 50, "only the remaining 50 is taken")
	assert_eq([GameState.gold, GameState.tier_paid, GameState.boss_pending, GameState.tier], [100, 0, true, 1])
	assert_eq(_events, [["gold", 100, -50], ["changed", 1, 0, true], ["paid_up", 2]])
	_events.clear()
	assert_eq(GameState.pay_into_tier(100), 0, "nothing more is taken while the boss is pending")
	assert_eq(_events, [])
	assert_eq(GameState.tier_remaining_cost(), 0, "paid in full: remaining 0 until the tier-up")

func test_advance_day_plans_the_boss_night_when_pending() -> void:
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	GameState.advance_day()
	assert_true(GameState.is_boss_night())
	assert_eq(GameState.lane_plan.map(func(w): return w.boss), [false, false, true])
	assert_eq(GameState.pressure(), 2, "the boss night runs at the tier's own pressure (day 2 of tier 1 here)")

func test_complete_tier_up_adds_the_spots_and_replans() -> void:
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	for i in 8:
		GameState.advance_day()  # day 9, pressure capped at 7
	assert_eq(GameState.pressure(), 7)
	_events.clear()
	GameState.complete_tier_up()
	assert_eq([GameState.tier, GameState.tier_day, GameState.boss_pending, GameState.tier_paid], [2, 9, false, 0])
	assert_eq(GameState.buildings.keys(), MapLayout.spots_for_tier(2))
	assert_eq(GameState.buildings["tower_w"], {"level": 0, "paid": 0, "hp": 0.0})
	assert_eq(GameState.pressure(), 8, "tier 2 starts at its base")
	assert_eq(_events, [["changed", 2, 0, false], ["reached", 2]], "tier_changed, then tier_reached")
	assert_eq(GameState.tier_next_cost(), -1, "tier 2 is the top of this build")
	assert_eq(GameState.tier_remaining_cost(), -1)
	assert_false(GameState.is_boss_night(), "the next plan has no boss")
	assert_eq(GameState.pay_into_tier(100), 0, "nothing to buy at the top")

func test_complete_tier_up_emits_building_changed_for_each_new_spot() -> void:
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	watch_signals(EventBus)
	GameState.complete_tier_up()
	assert_signal_emitted_with_parameters(EventBus, "building_changed", [&"tower_w", 0, 0], 0)
	assert_signal_emit_count(EventBus, "building_changed", 2)

func test_snapshot_round_trip_carries_the_tier() -> void:
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	GameState.complete_tier_up()
	GameState.add_gold(70)
	var d := GameState.to_dict()
	assert_eq(int(d.v), 5)
	assert_eq([d.tier, d.tier_day, d.tier_paid, d.boss_pending], [2, 1, 0, false])
	assert_true(d.buildings.has("tower_e"))
	GameState.new_game(5)
	GameState.from_dict(d)
	assert_eq([GameState.tier, GameState.tier_day, GameState.tier_paid, GameState.boss_pending, GameState.gold], [2, 1, 0, false, 70])
	assert_eq(GameState.buildings.keys(), MapLayout.spots_for_tier(2))
	assert_eq(GameState.to_dict(), d)

func test_from_dict_clamps_a_tier_above_the_top() -> void:
	var d := GameState.to_dict()
	d.tier = 4   # a later build's save
	d.tier_day = 1
	GameState.from_dict(d)
	assert_eq(GameState.tier, TierEffects.top_tier(Balance.data.tiers))
	assert_eq(GameState.tier_next_cost(), -1)

func test_debug_set_tier() -> void:
	GameState.debug_set_tier(2, 9)
	assert_eq([GameState.tier, GameState.tier_day, GameState.boss_pending], [2, 9, false])
	assert_eq(GameState.buildings.keys(), MapLayout.spots_for_tier(2))
	assert_eq(GameState.pressure(), WaveMath.pressure(GameState.day, 2, 9, Balance.data.tiers))
	GameState.debug_set_tier(1, 5)
	assert_eq(GameState.tier_day, 1, "tier 1 always starts on day 1")

func test_pay_before_the_first_new_game_window_does_nothing() -> void:
	# GameState.buildings is emptied here to mimic the warm-up window: no new_game yet.
	GameState.buildings = {}  # test-only setup
	GameState.gold = 900      # test-only setup
	assert_eq(GameState.pay_into_tier(10), 0)
	assert_eq(GameState.gold, 900)
