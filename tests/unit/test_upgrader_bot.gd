extends GutTest

func before_each() -> void:
	Balance.reset()
	GameState.new_game(3)

func test_its_graph_is_the_default_plus_two_pads() -> void:
	var bot := UpgraderBot.new()
	autofree(bot)
	var base := WaypointGraph.create_default()
	assert_eq(bot.graph.nodes.size(), base.nodes.size() + 2)
	for id in StationEffects.IDS:
		assert_eq(bot.graph.position_of("pad_%s" % id), MapLayout.STATION_PADS[id])
		assert_false(bot.graph.shortest("home", "pad_%s" % id).is_empty(), "reachable")
	assert_false(base.nodes.has("pad_counter"), "the shared default graph is untouched")

func test_idle_goal_is_the_cheapest_station_it_can_finish() -> void:
	var bot := UpgraderBot.new()
	autofree(bot)
	var sb := Balance.data.stations
	var freezer_cost := StationEffects.level_cost(&"freezer", 0, sb)
	var counter_cost := StationEffects.level_cost(&"counter", 0, sb)
	assert_lt(freezer_cost, counter_cost, "this sequence assumes the freezer is the cheaper first level")
	assert_lt(counter_cost, StationEffects.level_cost(&"freezer", 1, sb), "level 2 costs more than level 1")
	assert_lt(counter_cost, StationEffects.level_cost(&"counter", 1, sb), "level 2 costs more than level 1")
	assert_eq(bot.idle_goal(), "sign", "no gold")
	GameState.add_gold(freezer_cost)
	assert_eq(bot.idle_goal(), "pad_freezer")
	GameState.add_gold(counter_cost - freezer_cost)
	assert_eq(bot.idle_goal(), "pad_freezer", "still the cheapest")
	GameState.debug_set_station_level(&"freezer", 1)
	assert_eq(bot.idle_goal(), "pad_counter")
	GameState.debug_set_station_level(&"counter", 1)
	assert_eq(bot.idle_goal(), "sign", "the gold held finishes nothing")

func test_ties_go_to_the_counter() -> void:
	var bot := UpgraderBot.new()
	autofree(bot)
	Balance.data.stations.freezer_cost = Balance.data.stations.counter_cost
	GameState.add_gold(Balance.data.stations.counter_cost + 1)
	assert_eq(bot.idle_goal(), "pad_counter")

func test_the_planner_still_idles_at_the_sign() -> void:
	var bot := PlannerBot.new()
	autofree(bot)
	GameState.add_gold(1000)
	assert_eq(bot.idle_goal(), "sign")
