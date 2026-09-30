extends GutTest

var main: Main
var bot: PlannerBot

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	bot = PlannerBot.new()
	main.add_child(bot)
	bot.setup(main)
	main.phase_controller.start_new_game(51)
	GameState.advance_day()  # day-2 plan has side groups

func _side_lane() -> String:
	var side := {"west": 0.0, "north": 0.0, "east": 0.0}
	for w in GameState.lane_plan:
		side[w.side] += int(w.side_count) * float(w.hp_mult)
	var best := ""
	for l in LanePlanner.LANES:
		if best == "" or side[l] > side[best]:
			best = l
	return best

func test_first_buy_is_fence_on_top_side_lane() -> void:
	GameState.add_gold(100)
	assert_eq(bot.next_purchase(), MapLayout.LANE_FENCE[_side_lane()])

func test_then_adjacent_tower() -> void:
	GameState.add_gold(100)
	var fence: String = MapLayout.LANE_FENCE[_side_lane()]
	GameState.pay_into_spot(fence, 20)
	var t := bot.next_purchase()
	assert_true(t.begins_with("tower"))
	assert_true(_side_lane() in MapLayout.TOWER_LANES[t])

func test_nothing_if_unaffordable() -> void:
	GameState.add_gold(5)
	assert_eq(bot.next_purchase(), "")

func _plan(main_lane: String, main_n: int, side_lane: String, side_n: int) -> void:
	GameState.lane_plan = [{"main": main_lane, "side": side_lane, "main_count": main_n,
		"side_count": side_n, "hp_mult": 1.0}]

func _build(id: String) -> void:
	GameState.pay_into_spot(id, GameState.next_level_cost(id))

func test_unbuilt_tower_ne_competes() -> void:
	# east is the heaviest lane, west the side lane: steps 1-2 build fence_w and tower_nw
	_plan("east", 10, "west", 3)
	GameState.add_gold(1000)
	assert_eq(bot.next_purchase(), "fence_w")
	_build("fence_w")
	assert_eq(bot.next_purchase(), "tower_nw")
	_build("tower_nw")
	# step 3: tower_ne scores max(north 0, east 10) = fence_e's 10; tie -> SPOT_IDS order -> tower_ne
	assert_eq(bot.next_purchase(), "tower_ne")
	_build("tower_ne")
	assert_eq(bot.next_purchase(), "fence_e")

func test_upgrade_highest_threat_lane_first() -> void:
	_plan("east", 10, "west", 3)
	GameState.add_gold(1000)
	for id in ["fence_w", "tower_nw", "tower_ne", "fence_e"]:
		_build(id)
	# everything with threat is built: upgrade next to the east lane, cheapest affordable first
	var expect := ""
	var best := 0
	for id in ["tower_ne", "fence_e"]:
		var rem := GameState.remaining_cost(id)
		if expect == "" or rem < best:
			expect = id
			best = rem
	assert_eq(bot.next_purchase(), expect)
	# with only fence_e's price in hand the choice is still an east spot
	GameState.gold = GameState.remaining_cost("fence_e")
	assert_eq(bot.next_purchase(), "fence_e")

func test_hysteresis() -> void:
	GameState.add_gold(100)
	var spot := "fence_w" if bot.next_purchase() != "fence_w" else "fence_e"
	GameState.pay_into_spot(spot, 5)
	main.hero.teleport(bot.graph.position_of(spot))
	bot.go_to(spot)
	bot._route.clear()
	assert_true(bot.arrived())
	bot.day_think(0.0)
	assert_eq(bot.goal, spot, "kept while paying with gold left")
	for id in MapLayout.SPOT_IDS:  # spend down to 0
		if id != spot:
			GameState.pay_into_spot(id, GameState.gold)
	assert_eq(GameState.gold, 0)
	bot.day_think(0.0)
	assert_eq(bot.goal, "sign", "released once gold hits 0")
