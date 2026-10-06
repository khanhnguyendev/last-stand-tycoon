extends GutTest
## E5 spec 8.1: the tier bot pays the tier-up before stations, builds the yard towers once they exist, and routes to them.

func before_each() -> void:
	Balance.reset()

func _max_tier1_defense() -> void:
	for id in MapLayout.SPOT_IDS:  # test-only setup
		GameState.buildings[id].level = Balance.data.build.max_level

func test_graph_has_the_tier_nodes_and_the_default_is_untouched() -> void:
	var bot := TierBot.new()
	autofree(bot)
	for n in ["tier_sign", "tower_w", "tower_e"]:
		assert_true(bot.graph.nodes.has(n), n)
	assert_eq(WaypointGraph.create_default().nodes.size(), 19)

func test_every_node_routes_to_the_targets() -> void:
	var bot := TierBot.new()
	autofree(bot)
	for target in ["tier_sign", "tower_w", "tower_e", "pad_counter", "pad_freezer", "sign"]:
		assert_true(bot.graph.nodes.has(target), target)
		for n in bot.graph.nodes.keys():
			if n != target:
				assert_false(bot.graph.shortest(n, target).is_empty(), "%s -> %s" % [n, target])

func test_idle_goal_prefers_the_tier_up_when_affordable() -> void:
	GameState.new_game(1)
	var bot := TierBot.new()
	autofree(bot)
	var upgrader := UpgraderBot.new()
	autofree(upgrader)
	var cost := GameState.tier_next_cost()
	GameState.add_gold(cost)
	assert_eq(bot.idle_goal(), "tier_sign")
	GameState.gold = cost - 1  # test-only setup
	assert_eq(bot.idle_goal(), upgrader.idle_goal(), "below the cost it behaves as the upgrader")
	GameState.add_gold(1)
	GameState.pay_into_tier(cost)
	assert_ne(bot.idle_goal(), "tier_sign", "paid: nothing more to do at the sign")

func test_next_purchase_includes_the_yard_towers_at_tier_2() -> void:
	GameState.new_game(1)
	GameState.debug_set_tier(2, 1)
	var planner := PlannerBot.new()
	autofree(planner)
	var bot := TierBot.new()
	autofree(bot)
	GameState.add_gold(40)
	assert_eq(bot.next_purchase(), planner.next_purchase(), "an affordable tier-1 spot comes first, as the planner")
	_max_tier1_defense()
	var p := bot.next_purchase()
	assert_true(p in ["tower_w", "tower_e"], p)

func test_at_tier_1_it_buys_exactly_like_the_planner() -> void:
	GameState.new_game(1)
	var planner := PlannerBot.new()
	autofree(planner)
	var bot := TierBot.new()
	autofree(bot)
	GameState.day = 2  # test-only setup
	GameState.add_gold(1000)
	assert_eq(bot.next_purchase(), planner.next_purchase(), "fresh day 2")
	var spot := bot.next_purchase()
	GameState.buildings[spot].level = 1  # test-only setup: a fence (or whatever came first) built
	assert_eq(bot.next_purchase(), planner.next_purchase(), "one built")
	_max_tier1_defense()
	assert_eq(bot.next_purchase(), planner.next_purchase(), "everything maxed")
	assert_eq(bot.next_purchase(), "")

func test_keeps_standing_on_the_sign_mid_payment() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	var bot := TierBot.new()
	main.add_child(bot)
	bot.setup(main)
	main.phase_controller.start_new_game(20260930)
	main.phase_controller.debug_skip_to_day()
	_max_tier1_defense()
	GameState.stations[&"counter"].level = Balance.data.stations.max_level  # test-only setup
	GameState.stations[&"freezer"].level = Balance.data.stations.max_level  # test-only setup
	GameState.add_gold(GameState.tier_next_cost())
	var ok := false
	for i in 60 * 40:
		await get_tree().physics_frame
		if GameState.boss_pending:
			ok = true
			break
	assert_true(ok, "the bot walked to the sign and paid in full")
	assert_eq(bot.tier_ups, 1)
	assert_eq(bot.stuck_count, 0)

func test_builds_a_yard_tower_at_tier_2() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	var bot := TierBot.new()
	main.add_child(bot)
	bot.setup(main)
	main.phase_controller.start_new_game(20260930)
	GameState.debug_set_tier(2, 1)
	main.phase_controller.debug_skip_to_day()
	_max_tier1_defense()
	GameState.add_gold(40)
	var ok := false
	for i in 60 * 40:
		await get_tree().physics_frame
		if int(GameState.buildings["tower_w"].level) >= 1 or int(GameState.buildings["tower_e"].level) >= 1:
			ok = true
			break
	assert_true(ok, "a yard tower is built")
	assert_eq(bot.stuck_count, 0)
