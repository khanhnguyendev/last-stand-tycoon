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
	assert_eq(bot.idle_goal(), "sign", "no gold")
	GameState.add_gold(25)
	assert_eq(bot.idle_goal(), "pad_freezer")
	GameState.add_gold(5)
	assert_eq(bot.idle_goal(), "pad_freezer", "still the cheapest")
	GameState.debug_set_station_level(&"freezer", 1)  # next costs 50
	assert_eq(bot.idle_goal(), "pad_counter")
	GameState.debug_set_station_level(&"counter", 1)  # next costs 60
	assert_eq(bot.idle_goal(), "sign", "30 gold finishes nothing")

func test_ties_go_to_the_counter() -> void:
	var bot := UpgraderBot.new()
	autofree(bot)
	Balance.data.stations.freezer_cost = Balance.data.stations.counter_cost
	GameState.add_gold(100)
	assert_eq(bot.idle_goal(), "pad_counter")

func test_the_planner_still_idles_at_the_sign() -> void:
	var bot := PlannerBot.new()
	autofree(bot)
	GameState.add_gold(1000)
	assert_eq(bot.idle_goal(), "sign")
