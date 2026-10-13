extends GutTest
## E5 spec 8.1: the tier bot pays the tier-up before stations, builds the yard towers once they exist, and routes to them.

func before_each() -> void:
	Balance.reset()

func after_each() -> void:
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

## Task 22 DELIBERATE CHANGE. Before (Task 21): at tier 2 with 5000 gold the sign is for sale but the bot "does not seek the tier-3 sign":
## idle_goal() equalled the upgrader's ("pad_freezer"), and the test asserted ne "tier_sign". After: it seeks the front-lot sign.
## Mutation: the old freeze (`GameState.tier < 2`) returns "pad_freezer" here.
func test_at_tier_2_with_5000_gold_the_bot_seeks_the_tier_3_sign() -> void:
	GameState.new_game(1)
	GameState.debug_set_tier(2, 1)
	GameState.add_gold(5000)
	assert_eq(GameState.tier_remaining_cost(), 1500, "the sign is for sale")
	var bot := TierBot.new()
	autofree(bot)
	assert_eq(bot.idle_goal(), "tier_sign_3")

## The rule: rem > 0 and rem <= gold in hand (idle_goal runs only after next_purchase found nothing). Mutations: no affordability check
## (seeks at 1499), `rem >= gold` (not at 1500).
func test_the_tier_3_sign_is_sought_at_exactly_the_cost_and_not_one_gold_below() -> void:
	GameState.new_game(1)
	GameState.debug_set_tier(2, 1)
	var bot := TierBot.new()
	autofree(bot)
	GameState.gold = 1499  # test-only setup
	assert_ne(bot.idle_goal(), "tier_sign_3", "one gold short")
	GameState.gold = 1500  # test-only setup
	assert_eq(bot.idle_goal(), "tier_sign_3")

## Mutation: ignoring `rem > 0` seeks a sign at the top tier (remaining -1) or when paid (0).
func test_at_tier_3_there_is_no_sign_to_seek() -> void:
	GameState.new_game(1)
	GameState.debug_set_tier(3, 1)
	GameState.add_gold(9000)
	assert_eq(GameState.tier_remaining_cost(), -1)
	var bot := TierBot.new()
	autofree(bot)
	assert_ne(bot.idle_goal(), "tier_sign_3")
	assert_ne(bot.idle_goal(), "tier_sign")

func _bot_world(tier: int, seed_value := 20260930, policy := "threat") -> TierBot:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	var bot := TierBot.new()
	bot.policy = policy
	main.add_child(bot)
	bot.setup(main)
	main.phase_controller.start_new_game(seed_value)
	GameState.debug_set_tier(tier, 1)
	main.phase_controller.debug_skip_to_day()
	return bot

## test-only setup: every spot of the tier at the top build level (a fence with its hit points). building_changed is emitted as every real
## purchase does, so the branch pads that appear refresh now (a pad that first refreshes on a payment tick would disarm itself).
func _max_all_spots() -> void:
	for id in MapLayout.spots_for_tier(GameState.tier):
		GameState.buildings[id].level = Balance.data.build.max_level
		GameState.buildings[id].hp = GameState.fence_max_hp(Balance.data.build.max_level) if MapLayout.spot_kind(id) == "fence" else 0.0
		EventBus.building_changed.emit(StringName(id), Balance.data.build.max_level, 0)

## The goal is the FRONT-LOT sign (MapLayout.tier_sign(3)), not the tier-2 sign's west position, and only once the tier-2 purchases are
## done. Mutations: goal "tier_sign" (west position); the sign before an affordable yard tower.
func test_it_walks_to_the_front_lot_sign_after_its_tier_2_purchases() -> void:
	var bot := await _bot_world(2)
	_max_all_spots()
	GameState.buildings["tower_w"].level = 0  # test-only setup: one tier-2 purchase still open
	GameState.add_gold(1700)
	bot.day_think(0.0)
	assert_eq(bot.goal, "tower_w", "the open tier-2 purchase comes before the sign")
	GameState.buildings["tower_w"].level = Balance.data.build.max_level
	bot.day_think(0.0)
	assert_eq(bot.goal, "tier_sign_3")
	assert_eq(bot.graph.position_of(bot.goal), MapLayout.tier_sign(3))
	assert_ne(bot.graph.position_of(bot.goal), MapLayout.TIER_SIGN, "not the tier-2 sign's west position")

## The bot really pays tier 3 by standing at the front-lot sign. Mutation: a tier-3 sign node unreachable or on a collider (stuck, no payment).
func test_it_pays_tier_3_at_the_front_lot_sign() -> void:
	var bot := await _bot_world(2)
	_max_all_spots()
	GameState.stations[&"counter"].level = Balance.data.stations.max_level  # test-only setup
	GameState.stations[&"freezer"].level = Balance.data.stations.max_level  # test-only setup
	GameState.add_gold(1500)
	var ok := false
	for i in 60 * 40:
		await get_tree().physics_frame
		if GameState.boss_pending:
			ok = true
			break
	assert_true(ok, "paid in full")
	assert_eq(GameState.gold, 0, "exactly the 1500 was spent")
	assert_eq(bot.tier_ups, 1)
	assert_eq(bot.stuck_count, 0)
	assert_eq(bot.skipped_goals, 0)

## Mutation: the tier-2 graph at tier 3 (no tower_sw or fence_sw node) skips them (skipped_goals > 0, never built).
func test_it_builds_the_south_west_tower_and_fence_at_tier_3() -> void:
	var bot := await _bot_world(3)
	for id in MapLayout.spots_for_tier(3):
		if not id in MapLayout.TIER_SPOTS[3]:
			GameState.buildings[id].level = Balance.data.build.max_level  # test-only setup: the rest is built
			GameState.buildings[id].hp = GameState.fence_max_hp(Balance.data.build.max_level) if MapLayout.spot_kind(id) == "fence" else 0.0
	GameState.add_gold(300)
	var ok := false
	for i in 60 * 60:
		await get_tree().physics_frame
		if int(GameState.buildings["tower_sw"].level) >= 1 and int(GameState.buildings["fence_sw"].level) >= 1:
			ok = true
			break
	assert_true(ok, "tower_sw and fence_sw are built (gold left %d)" % GameState.gold)
	assert_eq(bot.skipped_goals, 0)
	assert_eq(bot.stuck_count, 0)

## Mutation: no zone_sw node in the bot's tier-3 graph (the night post is dropped and counted).
func test_the_night_post_at_tier_3_can_be_the_south_west_zone() -> void:
	var bot := await _bot_world(3)
	bot._sync_graph()
	var wd: WaveDirector = bot.main.world.wave_director
	wd.debug_spawn("sw")
	bot._night(1.0)
	assert_eq(bot.goal, "zone_sw")
	assert_eq(bot.skipped_goals, 0)
	assert_eq(bot.graph.position_of("zone_sw"), MapLayout.lane_end("sw"))
	wd.debug_kill_all()

# --- branch policies (pure) --------------------------------------------------------------------------------

static func _wave(main_lane: String, brute_main := 0, side_lane := "", brute_side := 0) -> Dictionary:
	return {"main": main_lane, "main_count": 4, "side": side_lane, "side_count": 2 if side_lane != "" else 0,
		"hp_mult": 1.0, "brute_main": brute_main, "brute_side": brute_side}

## [policy, plan, spot, expected branch]. Mutations: all_a returning B (or the reverse); `mixed` returning one kind for both; threat
## reading a tower's first lane only (tower_nw with brutes on north), reading any lane's threat instead of brutes (the no-brute rows),
## or reading the side group (the fence_e row).
func test_each_policy_picks_the_documented_branch_for_a_literal_plan() -> void:
	var none := [_wave("north")]
	var sw := [_wave("sw", 2)]
	var north := [_wave("north", 3)]
	var side_e := [_wave("north", 0, "east", 2)]
	var table := [
		["all_a", none, "tower_sw", &"longbow"], ["all_a", none, "fence_sw", &"stone"], ["all_a", sw, "tower_e", &"longbow"],
		["all_b", sw, "tower_sw", &"volley"], ["all_b", sw, "fence_sw", &"spike"], ["all_b", none, "fence_n", &"spike"],
		["mixed", none, "tower_nw", &"longbow"], ["mixed", sw, "fence_w", &"spike"], ["mixed", north, "tower_ne", &"longbow"],
		["mixed", north, "fence_n", &"spike"],
		["volley_stone", none, "tower_sw", &"volley"], ["volley_stone", none, "fence_sw", &"stone"], ["volley_stone", sw, "tower_e", &"volley"],
		["volley_stone", north, "fence_n", &"stone"],
		["threat", none, "tower_sw", &"volley"], ["threat", none, "fence_sw", &"spike"], ["threat", none, "fence_n", &"spike"],
		["threat", sw, "tower_sw", &"longbow"], ["threat", sw, "fence_sw", &"stone"], ["threat", sw, "fence_w", &"spike"],
		["threat", sw, "tower_nw", &"volley"], ["threat", sw, "tower_w", &"volley"], ["threat", sw, "fence_n", &"spike"],
		["threat", north, "tower_nw", &"longbow"], ["threat", north, "tower_ne", &"longbow"], ["threat", north, "fence_n", &"stone"],
		["threat", north, "tower_w", &"volley"], ["threat", north, "tower_e", &"volley"], ["threat", north, "fence_e", &"spike"],
		["threat", side_e, "fence_e", &"stone"], ["threat", side_e, "tower_e", &"longbow"], ["threat", side_e, "fence_n", &"spike"],
	]
	for row in table:
		var got := TierBot.branch_choices(row[0], [row[2]], row[1])
		assert_eq(got[row[2]], row[3], "%s %s" % [row[0], row[2]])

## One call decides every spot; the answer depends on nothing but the arguments.
func test_branch_choices_covers_every_spot_given_and_is_pure() -> void:
	var plan := [_wave("sw", 1)]
	var ids := MapLayout.spots_for_tier(3)
	var a := TierBot.branch_choices("threat", ids, plan)
	assert_eq(a.keys().size(), ids.size())
	var before := plan.duplicate(true)
	var ids_before := ids.duplicate()
	TierBot.branch_choices("threat", ids, plan)
	assert_eq(plan, before, "the plan argument is not mutated")
	assert_eq(ids, ids_before, "the spot list is not mutated")
	assert_eq(a["tower_sw"], &"longbow")
	assert_eq(a["fence_sw"], &"stone")
	assert_eq(a["fence_w"], &"spike", "a tier-3 lane's brute does not leak onto the others")

## The bot in a real world buys exactly the policy's branch by standing on its pad: one tower and one fence (800 gold: tower_nw 500, then
## tower_ne cannot be finished with 300, so fence_w 300). Mutations: the wrong pad (all_b buying Longbow), paying both pads (a refund
## puts gold back, or branch_paid stays), a payment started it cannot finish (gold 0 with a partial pad).
func test_it_completes_one_tower_and_one_fence_branch_by_standing_on_the_pad() -> void:
	var bot := await _bot_world(3, 20260930, "all_b")
	_max_all_spots()
	GameState.gold = 800  # test-only setup
	var chosen := {}
	var on_chosen := func(spot: StringName, branch: StringName) -> void: chosen[String(spot)] = branch
	EventBus.branch_chosen.connect(on_chosen)
	var ok := false
	for i in 60 * 80:
		await get_tree().physics_frame
		if chosen.size() >= 2:
			ok = true
			break
	EventBus.branch_chosen.disconnect(on_chosen)
	assert_true(ok, "two branches were bought: %s, gold %d" % [chosen, GameState.gold])
	assert_eq(chosen, {"tower_nw": &"volley", "fence_w": &"spike"})
	assert_eq(GameState.gold, 0, "exactly 500 + 300 spent: nothing refunded, nothing wasted")
	for id in MapLayout.spots_for_tier(3):
		assert_eq(GameState.buildings[id].branch_paid, {}, "%s holds no partial payment" % id)
		if not id in ["tower_nw", "fence_w"]:
			assert_eq(GameState.branch_of(id), &"", id)
	assert_eq(bot.skipped_goals, 0)
	assert_eq(bot.stuck_count, 0)

# --- determinism ---------------------------------------------------------------------------------------------

## A short scripted run: tier 2 -> pays the front-lot sign (policy-free) -> or, at tier 3, the policy's first branches. Returns the hash of
## the goal sequence and of the final state.
var _last_goals: Array = []
var _last_paid := false

func _trace(tier: int, policy: String, gold: int, stop: Callable) -> int:
	var bot := await _bot_world(tier, 20260930, policy)
	_max_all_spots()
	GameState.stations[&"counter"].level = Balance.data.stations.max_level  # test-only setup
	GameState.stations[&"freezer"].level = Balance.data.stations.max_level  # test-only setup
	GameState.gold = gold  # test-only setup
	var goals: Array = []
	for i in 60 * 40:
		await get_tree().physics_frame
		if goals.is_empty() or goals[-1] != bot.goal:
			goals.append(bot.goal)
		if stop.call():
			break
	var branches := {}
	for id in MapLayout.spots_for_tier(GameState.tier):
		branches[id] = String(GameState.branch_of(id))
	_last_goals = goals
	_last_paid = GameState.boss_pending
	return hash([goals, GameState.gold, GameState.tier_paid, GameState.boss_pending, branches])

func test_two_runs_of_the_same_seed_and_policy_have_identical_traces() -> void:
	var t2_a := await _trace(2, "threat", 1500, func(): return GameState.boss_pending)
	var goals_a := _last_goals
	var paid_a := _last_paid
	var t2_b := await _trace(2, "threat", 1500, func(): return GameState.boss_pending)
	assert_true(paid_a and _last_paid, "both runs really paid the tier-3 sign (else the comparison is vacuous)")
	assert_eq(t2_a, t2_b, "tier 2 to the tier-3 payment; goal traces %s | %s" % [goals_a, _last_goals])
	var done := func(): return GameState.branch_of("tower_nw") != &"" and GameState.branch_of("fence_w") != &""
	var b_a := await _trace(3, "all_a", 800, done)
	var b_b := await _trace(3, "all_a", 800, done)
	var b_t := await _trace(3, "all_b", 800, done)
	assert_eq(b_a, b_b, "tier 3 branches under all_a")
	assert_ne(b_a, b_t, "the trace sees the policy (Longbow and Stone wall against Volley and Spike fence)")

## Wiring: the default policy (threat) reads GameState.lane_plan. Mutation: passing [] instead of GameState.lane_plan to branch_choices in
## _next_branch_pad (hand-checked: the Longbow and Stone rows then return Volley and Spike pads and fail).
func _one_branch_bot() -> TierBot:
	GameState.new_game(1)
	GameState.debug_set_tier(3, 1)
	for id in MapLayout.spots_for_tier(3):
		GameState.buildings[id].level = Balance.data.build.max_level  # test-only setup
		GameState.buildings[id].hp = GameState.fence_max_hp(Balance.data.build.max_level) if MapLayout.spot_kind(id) == "fence" else 0.0
	GameState.gold = 5000  # test-only setup
	var bot := TierBot.new()
	autofree(bot)
	assert_eq(bot.policy, "threat", "the default")
	return bot

func _only(bot: TierBot, keep: String) -> void:
	for id in MapLayout.spots_for_tier(3):  # test-only setup: only `keep` can still branch
		if id != keep:
			GameState.buildings[id].branch = "spike" if MapLayout.spot_kind(id) == "fence" else "volley"

func test_the_default_policy_reads_the_nights_plan_for_a_tower() -> void:
	var bot := _one_branch_bot()
	_only(bot, "tower_nw")
	GameState.lane_plan = [_wave("west", 2)]  # tower_nw covers west
	assert_eq(bot.next_purchase(), "pad_tower_nw_a", "Longbow")
	GameState.lane_plan = [_wave("sw", 2)]
	assert_eq(bot.next_purchase(), "pad_tower_nw_b", "Volley")

func test_the_default_policy_reads_the_nights_plan_for_a_fence() -> void:
	var bot := _one_branch_bot()
	_only(bot, "fence_w")
	GameState.lane_plan = [_wave("west", 2)]
	assert_eq(bot.next_purchase(), "pad_fence_w_a", "Stone wall")
	GameState.lane_plan = [_wave("sw", 2)]
	assert_eq(bot.next_purchase(), "pad_fence_w_b", "Spike fence")

## E6 Task 6 (spec 4.4, D-283, D-288). The lanes each tier-3 spot covers, written by hand (not read from MapLayout), in spots_for_tier order.
const SPOT_LANES := {"tower_nw": ["west", "north"], "tower_ne": ["north", "east"], "fence_w": ["west"], "fence_n": ["north"],
	"fence_e": ["east"], "tower_w": ["west"], "tower_e": ["east"], "tower_sw": ["sw"], "fence_sw": ["sw"]}

## The tiny oracle: a fence takes Stone wall when its lane is the siege lane, a tower takes Longbow when the siege lane is among its lanes.
func _oracle(spot: String, siege: String) -> StringName:
	var on_siege: bool = siege in SPOT_LANES[spot]
	if spot.begins_with("tower"):
		return &"longbow" if on_siege else &"volley"
	return &"stone" if on_siege else &"spike"

## Hand-written expected table for the character {siege: north, hare: west}: [spot, lanes, branch].
## Mutations: the character ignored (the plan read with the flag on: the no-brute plan makes every row Volley/Spike); "covers the siege lane"
## replaced by "covers only the siege lane" (tower_nw and tower_ne, which also cover west and east, turn Volley).
func test_threat_with_a_character_follows_the_documented_table_for_siege_north() -> void:
	var ch := {"siege": "north", "hare": "west"}
	var table := [
		["tower_nw", &"longbow"],  # west + north: covers the siege lane and the hare lane
		["tower_ne", &"longbow"],  # north + east
		["fence_w", &"spike"],     # west: hare lane, not siege
		["fence_n", &"stone"],     # north: the siege lane
		["fence_e", &"spike"],
		["tower_w", &"volley"],    # west only: the hare lane
		["tower_e", &"volley"],    # east only
		["tower_sw", &"volley"],   # sw only
		["fence_sw", &"spike"],
	]
	var ids := MapLayout.spots_for_tier(3)
	assert_eq(ids.size(), table.size(), "the table lists every tier-3 spot")
	var got := TierBot.branch_choices("threat", ids, [_wave("sw")], 3, ch)  # tonight's plan has no brute anywhere
	for row in table:
		assert_eq(got[row[0]], row[1], "siege north: " + row[0])

## All four possible siege lanes, every tier-3 spot, against the independent oracle (the hare lane is always another lane).
func test_threat_with_a_character_matches_the_oracle_for_every_siege_lane_and_spot() -> void:
	var lanes := ["west", "north", "east", "sw"]
	var tried := 0
	for siege in lanes:
		var hare: String = lanes[(lanes.find(siege) + 1) % 4]
		var got := TierBot.branch_choices("threat", MapLayout.spots_for_tier(3), [_wave("sw", 2)], 3, {"siege": siege, "hare": hare})
		for spot in SPOT_LANES:
			assert_eq(got[spot], _oracle(spot, siege), "siege %s hare %s %s" % [siege, hare, spot])
			tried += 1
	assert_eq(tried, 36)

## tower_nw covers west and north: with siege west and hare north (both its lanes) it still takes Longbow. Mutation: "covers only the siege lane".
func test_a_tower_covering_both_the_siege_and_the_hare_lane_takes_longbow() -> void:
	var got := TierBot.branch_choices("threat", ["tower_nw", "tower_ne"], [], 3, {"siege": "west", "hare": "north"})
	assert_eq(got["tower_nw"], &"longbow", "tower_nw covers siege west and hare north")
	assert_eq(got["tower_ne"], &"volley", "tower_ne covers north (hare) and east, not the siege lane")
	var got2 := TierBot.branch_choices("threat", ["tower_nw", "tower_ne"], [], 3, {"siege": "north", "hare": "east"})
	assert_eq(got2["tower_ne"], &"longbow", "tower_ne covers siege north and hare east")

## The same character gives the same choices under any night plan. Mutation: the plan still read with a character.
func test_the_character_choice_does_not_change_from_day_to_day() -> void:
	var ch := {"siege": "east", "hare": "sw"}
	var ids := MapLayout.spots_for_tier(3)
	var base := TierBot.branch_choices("threat", ids, [_wave("north")], 3, ch)  # no brute tonight
	for plan in [[_wave("west", 3)], [_wave("sw", 2, "north", 2)], [_wave("north", 0, "west", 4)]]:  # brutes on other lanes
		assert_eq(TierBot.branch_choices("threat", ids, plan, 3, ch), base)
	for spot in SPOT_LANES:
		assert_eq(base[spot], _oracle(spot, "east"), spot)

## Through the bot instance. Mutation: the bot passes {} instead of GameState.lane_character() (it then reads the plan: Volley here).
func test_with_the_flag_on_the_bot_buys_longbow_on_the_siege_lane_whatever_tonights_plan() -> void:
	Balance.data.tiers.retune_enabled = true
	var bot := _one_branch_bot()
	var siege := String(GameState.lane_character().get("siege", ""))
	assert_eq(siege, "east", "pinned: the siege lane of run seed 1")
	var tower := ""
	for id in ["tower_nw", "tower_ne", "tower_w", "tower_e", "tower_sw"]:
		if siege in SPOT_LANES[id]:
			tower = id
			break
	assert_ne(tower, "")
	_only(bot, tower)
	var other := "west" if siege != "west" else "north"
	GameState.lane_plan = [_wave(other, 3)]  # tonight's brutes are NOT on the siege lane
	assert_eq(bot.next_purchase(), "pad_%s_a" % tower, "Longbow")
	GameState.lane_plan = []  # no brute tonight at all
	assert_eq(bot.next_purchase(), "pad_%s_a" % tower, "Longbow the next day too")
	Balance.reset()

## Flag off, the same seed: the plan decides (no brute on the tower's lanes tonight gives Volley).
func test_with_the_flag_off_the_bot_still_reads_the_nights_plan() -> void:
	var bot := _one_branch_bot()
	assert_true(GameState.lane_character().is_empty())
	_only(bot, "tower_nw")
	GameState.lane_plan = [_wave("sw", 3)]
	assert_eq(bot.next_purchase(), "pad_tower_nw_b", "Volley")
	GameState.lane_plan = [_wave("west", 3)]
	assert_eq(bot.next_purchase(), "pad_tower_nw_a", "Longbow")

## `unbranched` (report-only) buys no branch and is not a skipped goal. Mutations: it buying any branch; an unbought branch counted as skipped;
## idle_goal changing (the concrete goal is pinned).
func test_unbranched_never_buys_a_branch_and_skips_nothing() -> void:
	assert_true("unbranched" in TierBot.REPORT_POLICIES)
	assert_false("unbranched" in TierBot.POLICIES, "fixtures and the CI sim loop over POLICIES")
	for flag in [false, true]:
		Balance.data.tiers.retune_enabled = flag
		var bot := _one_branch_bot()
		bot.policy = "unbranched"
		GameState.lane_plan = [_wave("west", 3), _wave("north", 2, "east", 2)]
		assert_eq(bot.next_purchase(), "", "everything max, 5000 gold, nothing else to build (flag %s)" % flag)
		assert_eq(bot.skipped_goals, 0)
		assert_eq(TierBot.branch_choices("unbranched", MapLayout.spots_for_tier(3), GameState.lane_plan), {})
		assert_eq(bot.idle_goal(), "pad_freezer", "tier 3, everything max, 5000 gold: the cheapest station level (the upgrader's idle goal)")
		Balance.reset()

## `unbranched` skips only the branch pads. Mutation: the policy short-circuits next_purchase (no yard tower) or idle_goal (no sign).
func test_unbranched_still_buys_a_level_0_yard_tower() -> void:
	var bot := _one_branch_bot()
	bot.policy = "unbranched"
	GameState.buildings["tower_w"].level = 0  # test-only setup: one yard tower still to build
	assert_eq(bot.next_purchase(), "tower_w")

func test_unbranched_still_seeks_the_tier_3_sign_at_tier_2() -> void:
	GameState.new_game(1)
	GameState.debug_set_tier(2, 1)
	GameState.add_gold(5000)
	var bot := TierBot.new()
	autofree(bot)
	bot.policy = "unbranched"
	assert_eq(bot.idle_goal(), "tier_sign_3")

## An unknown policy still fails loudly (the assert), so a typo never silently becomes a policy.
func test_an_unknown_policy_still_fails_loudly() -> void:
	var src := FileAccess.get_file_as_string("res://actors/bots/tier_bot.gd")
	assert_true(src.contains('assert(p_policy in POLICIES or p_policy in REPORT_POLICIES, "unknown policy "'))

## A pad that never arms: the bot gives up after PAD_WAIT_CAP_TICKS, counts one skip and picks another goal (no stall).
func test_a_pad_that_never_pays_is_skipped_once_after_the_cap() -> void:
	var bot := await _bot_world(3)
	_max_all_spots()
	GameState.gold = 5000  # test-only setup
	var pad := bot.next_purchase()
	assert_true(pad.begins_with("pad_"), pad)
	bot.goal = pad
	bot._route = []
	bot.hero.teleport(bot.graph.position_of(pad))  # standing on it, never walked in: the pad is not armed
	assert_true(bot.arrived())
	for i in TierBot.PAD_WAIT_CAP_TICKS:
		bot.day_think(0.0)
		assert_eq(bot.goal, pad, "still waiting")
	assert_eq(bot.skipped_goals, 0)
	bot.day_think(0.0)
	assert_eq(bot.skipped_goals, 1)
	assert_ne(bot.next_purchase(), pad, "not picked again today")

# --- E6 phase 4: the threat-matched bot buys for the marked lanes first (flag on) ------------------------------------

## Buys `n` branches in a row with plenty of gold: returns the pad goals in the order the bot targets them (each target is then marked bought).
func _targets(bot: TierBot, n: int) -> Array:
	var out: Array = []
	for i in n:
		var p := bot.next_purchase()
		if p == "":
			break
		out.append(p)
		var t := TierBot._pad_target(p)
		GameState.buildings[t[0]].branch = String(t[1])  # test-only setup: the branch is bought
	return out

## A run seed whose lane character has this siege lane (the character is derived from the seed, so the test searches for one).
func _seed_with_siege(siege: String) -> int:
	for sd in range(1, 400):
		if String(LaneCharacter.for_run(sd).get("siege", "")) == siege:
			return sd
	return -1

func _bot_for_seed(sd: int, gold: int) -> TierBot:
	var bot := _one_branch_bot()
	GameState.new_game(sd)
	GameState.debug_set_tier(3, 1)
	for id in MapLayout.spots_for_tier(3):
		GameState.buildings[id].level = Balance.data.build.max_level  # test-only setup
		GameState.buildings[id].hp = GameState.fence_max_hp(Balance.data.build.max_level) if MapLayout.spot_kind(id) == "fence" else 0.0
	GameState.gold = gold  # test-only setup
	GameState.lane_plan = [_wave("west", 2)]
	return bot

## A run seed whose lane character is exactly {siege, hare} (the character is derived from the seed, so the test searches for one).
func _seed_with_character(siege: String, hare: String) -> int:
	for sd in range(1, 1000):
		var c := LaneCharacter.for_run(sd)
		if String(c.siege) == siege and String(c.hare) == hare:
			return sd
	return -1

## Hand-written buying orders over spots_for_tier(3) = [tower_nw, tower_ne, fence_w, fence_n, fence_e, tower_w, tower_e, tower_sw, fence_sw]:
## towers on the siege lane, towers on the hare lane, the siege fence, the hare fence, the rest (list order inside a group). Literals, no oracle.
const ORDER_LITERALS := [
	[{"siege": "west", "hare": "north"}, ["tower_nw", "tower_w", "tower_ne", "fence_w", "fence_n", "fence_e", "tower_e", "tower_sw", "fence_sw"]],
	[{"siege": "north", "hare": "east"}, ["tower_nw", "tower_ne", "tower_e", "fence_n", "fence_e", "fence_w", "tower_w", "tower_sw", "fence_sw"]],
	[{"siege": "east", "hare": "sw"}, ["tower_ne", "tower_e", "tower_sw", "fence_e", "fence_sw", "tower_nw", "fence_w", "fence_n", "tower_w"]],
	[{"siege": "sw", "hare": "west"}, ["tower_sw", "tower_nw", "tower_w", "fence_sw", "fence_w", "tower_ne", "fence_n", "fence_e", "tower_e"]],
	[{"siege": "east", "hare": "west"}, ["tower_ne", "tower_e", "tower_nw", "tower_w", "fence_e", "fence_w", "fence_n", "tower_sw", "fence_sw"]],
]

func test_the_marked_lane_order_for_literal_characters() -> void:
	for c in ORDER_LITERALS:
		assert_eq(TierBot.marked_lane_order(MapLayout.spots_for_tier(3), c[0]), c[1], str(c[0]))
	assert_eq(TierBot.marked_lane_order(MapLayout.spots_for_tier(3), {}), MapLayout.spots_for_tier(3), "an empty character keeps the list order")

func _pad_for(spot: String, siege: String) -> String:
	return "pad_%s_%s" % [spot, "a" if _oracle(spot, siege) in [&"longbow", &"stone"] else "b"]

## With gold for exactly one tower branch (500), the first target is a tower covering the siege lane, for each siege lane. Mutation: the list
## order (siege east then buys tower_nw, which does not cover east; the 300-gold fence is not what is bought either).
func test_with_gold_for_one_branch_the_threat_bot_buys_a_tower_on_the_siege_lane() -> void:
	Balance.data.tiers.retune_enabled = true
	for siege in ["west", "north", "east", "sw"]:
		var sd := _seed_with_siege(siege)
		assert_ne(sd, -1, "a seed with siege " + siege)
		var bot := _bot_for_seed(sd, 500)
		var ch := GameState.lane_character()
		assert_eq(ch.siege, siege)
		assert_ne(ch.hare, siege)
		var first := bot.next_purchase()
		var spot: String = TierBot._pad_target(first)[0]
		assert_true(spot.begins_with("tower") and siege in SPOT_LANES[spot], "siege %s: first target %s" % [siege, first])
		assert_true(first.ends_with("_a"), "Longbow")

## With gold for everything, the threat bot's targets follow ORDER_LITERALS through the live bot. Mutations: groups 1 and 2 swapped, the hare fence
## before the siege fence, list order inside a group lost (node or hash order).
func test_the_threat_bot_buys_in_the_literal_order() -> void:
	Balance.data.tiers.retune_enabled = true
	for c in ORDER_LITERALS:
		var sd := _seed_with_character(c[0].siege, c[0].hare)
		assert_ne(sd, -1, str(c[0]))
		var bot := _bot_for_seed(sd, 5000)
		assert_eq(GameState.lane_character(), c[0])
		var want: Array = []
		for spot in c[1]:
			want.append(_pad_for(spot, c[0].siege))
		assert_eq(_targets(bot, 9), want, str(c[0]))

## Seed 1's character is {siege east, hare west}. Flag off (empty character): today's list order for every policy (captured before the order change).
const TODAY_FLAG_OFF := {
	"all_a": ["pad_tower_nw_a", "pad_tower_ne_a", "pad_fence_w_a"],
	"all_b": ["pad_tower_nw_b", "pad_tower_ne_b", "pad_fence_w_b"],
	"mixed": ["pad_tower_nw_a", "pad_tower_ne_a", "pad_fence_w_b"],
	"volley_stone": ["pad_tower_nw_b", "pad_tower_ne_b", "pad_fence_w_a"],
	"unbranched": [],
}
## Flag on: every policy that buys branches uses the marked-lane order of east / west (tower_ne, tower_e, tower_nw, tower_w, fence_e, fence_w, then
## fence_n, tower_sw, fence_sw); only the branch differs (a = Longbow / Stone wall, b = Volley / Spike fence). Literals.
const FLAG_ON_ORDER := ["tower_ne", "tower_e", "tower_nw", "tower_w", "fence_e", "fence_w", "fence_n", "tower_sw", "fence_sw"]
const FLAG_ON_BRANCH := {
	"all_a": "aaaaaaaaa",
	"all_b": "bbbbbbbbb",
	"mixed": "aaaabbbab",
	"volley_stone": "bbbbaaaba",
	"threat": "aabbabbbb",
}

func test_every_branch_policy_keeps_todays_order_with_an_empty_character() -> void:
	for pol in TODAY_FLAG_OFF:
		Balance.reset()
		var bot := _one_branch_bot()
		bot.policy = pol
		GameState.lane_plan = [_wave("west", 2)]
		assert_true(GameState.lane_character().is_empty())
		assert_eq(_targets(bot, 3), TODAY_FLAG_OFF[pol], "%s flag off" % pol)
	Balance.reset()
	var bot2 := _one_branch_bot()
	GameState.lane_plan = [_wave("west", 2)]
	assert_eq(_targets(bot2, 3), ["pad_tower_nw_a", "pad_tower_ne_b", "pad_fence_w_a"], "threat, empty character: the plan decides, list order")

## Flag on, seed 1 (east / west): the same order for every policy. Mutation: the order applied to `threat` only (the 4 other policies keep the list).
func test_every_branch_policy_buys_in_the_marked_lane_order_with_a_character() -> void:
	for pol in FLAG_ON_BRANCH:
		Balance.reset()
		Balance.data.tiers.retune_enabled = true
		var bot := _one_branch_bot()
		bot.policy = pol
		GameState.lane_plan = [_wave("west", 2)]
		assert_eq(GameState.lane_character(), {"siege": "east", "hare": "west"})
		var want: Array = []
		for i in 9:
			want.append("pad_%s_%s" % [FLAG_ON_ORDER[i], FLAG_ON_BRANCH[pol][i]])
		assert_eq(_targets(bot, 9), want, "%s flag on" % pol)
	Balance.reset()
	Balance.data.tiers.retune_enabled = true
	var bot3 := _one_branch_bot()
	bot3.policy = "unbranched"
	assert_eq(_targets(bot3, 3), [], "unbranched buys no branch")

# --- E6 phase 4: the hero holds a breached lane ---------------------------------------------------------------------------------------

const _LANES3: Array = ["west", "north", "east", "sw"]  # lanes_for_tier(3) order; north before sw
const _CHAR := {"siege": "north", "hare": "sw"}

func _counts(n: int, w: int, e: int, sw: int) -> Dictionary:
	return {"west": w, "north": n, "east": e, "sw": sw}

func _breach(n: int, w: int, e: int, sw: int) -> Dictionary:
	return {"west": w, "north": n, "east": e, "sw": sw}

func test_with_a_character_the_lane_with_enemies_at_the_diner_wins_over_the_bigger_lane() -> void:
	# seed 7, night 23, t = 93.0: north 10 (none past the fence), sw 8 (5 at the diner)
	assert_eq(NaiveBot.pick_lane(_LANES3, _counts(10, 0, 0, 8), _breach(0, 0, 0, 5), _CHAR), "sw")

func test_with_a_character_and_nothing_breached_the_choice_is_todays() -> void:
	assert_eq(NaiveBot.pick_lane(_LANES3, _counts(10, 0, 0, 8), _breach(0, 0, 0, 0), _CHAR), "north")
	assert_eq(NaiveBot.pick_lane(_LANES3, _counts(0, 0, 0, 0), _breach(0, 0, 0, 0), _CHAR), "", "zero everywhere: no lane (the caller falls back to the plan's main lane)")

func test_with_a_character_two_breached_lanes_the_one_with_more_at_the_diner_wins() -> void:
	assert_eq(NaiveBot.pick_lane(_LANES3, _counts(10, 0, 0, 8), _breach(2, 0, 0, 5), _CHAR), "sw")
	assert_eq(NaiveBot.pick_lane(_LANES3, _counts(10, 0, 0, 8), _breach(5, 0, 0, 2), _CHAR), "north")

func test_with_a_character_equal_breach_counts_fall_back_to_the_most_enemies_then_lane_order() -> void:
	assert_eq(NaiveBot.pick_lane(_LANES3, _counts(4, 0, 0, 9), _breach(3, 0, 0, 3), _CHAR), "sw", "tied breach: most enemies")
	assert_eq(NaiveBot.pick_lane(_LANES3, _counts(6, 0, 0, 6), _breach(3, 0, 0, 3), _CHAR), "north", "tied on both: lane order")

func test_with_an_empty_character_the_breach_is_ignored() -> void:
	assert_eq(NaiveBot.pick_lane(_LANES3, _counts(10, 0, 0, 8), _breach(0, 0, 0, 5), {}), "north")
	assert_eq(NaiveBot.pick_lane(_LANES3, _counts(10, 0, 0, 8), _breach(2, 0, 0, 5), {}), "north")
	assert_eq(NaiveBot.pick_lane(_LANES3, _counts(10, 0, 0, 8), _breach(0, 0, 0, 0), {}), "north")
	assert_eq(NaiveBot.pick_lane(_LANES3, _counts(1, 0, 0, 8), _breach(1, 0, 0, 0), {}), "sw")

func test_todays_choice_is_pinned_for_three_literals() -> void:
	# captured from the loop in NaiveBot._night before this change
	assert_eq(NaiveBot.most_enemies(["west", "north", "east"], {"west": 3, "north": 3, "east": 1}), "west")
	assert_eq(NaiveBot.most_enemies(["west", "north", "east"], {"west": 0, "north": 2, "east": 5}), "east")
	assert_eq(NaiveBot.most_enemies(["west", "north", "east", "sw"], {"west": 0, "north": 0, "east": 0, "sw": 0}), "")

## enemy_breached(lane, dist, reach, fence_standing, walks_past)
func test_a_fence_stopping_kind_is_breached_at_a_fallen_fences_stop_point_or_at_the_diner() -> void:
	var len := MapLayout.path_length("sw")
	var stop := len - MapLayout.FENCE_OFFSET_FROM_END - 1.2
	assert_true(TierBot.enemy_breached("sw", stop, 1.2, false, false), "held at the stop point of a fallen fence")
	assert_false(TierBot.enemy_breached("sw", stop - 0.1, 1.2, false, false), "short of the stop point")
	assert_false(TierBot.enemy_breached("sw", stop, 1.2, true, false), "a boar held at a standing fence is not breached")
	assert_false(TierBot.enemy_breached("sw", len - 1.0, 1.2, true, false), "near the diner but not at it")
	assert_true(TierBot.enemy_breached("sw", len, 1.2, true, false), "at the diner (the end of the path)")

func test_a_kind_that_walks_past_fences_is_breached_past_the_fence_line_whether_or_not_it_stands() -> void:
	var line := MapLayout.path_length("sw") - MapLayout.FENCE_OFFSET_FROM_END
	assert_true(TierBot.enemy_breached("sw", line + 0.1, 1.2, true, true), "a hare past a standing fence")
	assert_true(TierBot.enemy_breached("sw", line + 0.1, 1.2, false, true), "a hare past a fallen fence")
	assert_false(TierBot.enemy_breached("sw", line - 0.1, 1.2, true, true), "a hare short of the line")

class _StopProbe:
	var lane := ""
	var _kind: StringName
	func _init(p_lane: String, p_kind: StringName) -> void:
		lane = p_lane
		_kind = p_kind
	func path_length() -> float:
		return MapLayout.path_length(lane)
	func stats() -> MonsterStats:
		return Balance.data.monsters.stats(_kind)

## The bot's stop point is the game's while the fence stands (TargetProviders.fence_stop_dist), for every lane and kind.
func test_the_stop_point_agrees_with_the_games_for_every_lane_and_kind() -> void:
	GameState.new_game(1)
	GameState.debug_set_tier(3, 1)
	for lane in MapLayout.lanes_for_tier(3):
		var fence: String = MapLayout.lane_fence(lane)
		GameState.buildings[fence].level = Balance.data.build.max_level
		GameState.buildings[fence].hp = GameState.fence_max_hp(Balance.data.build.max_level)
		for kind in MonsterBalance.KINDS:
			var probe := _StopProbe.new(lane, kind)
			assert_eq(TierBot.fence_stop_point(lane, probe.stats().reach), TargetProviders.fence_stop_dist(probe), "%s %s" % [lane, kind])

# --- the live pick (TierBot._pick_lane in a tier-3 world) ----------------------------------------------------------------------------

func _spawn_at(wd: WaveDirector, lane: String, kind: StringName, dist: float) -> void:
	var b := wd.debug_spawn(lane, 0.0, 1.0, kind)
	b.dist = dist  # test-only setup

func _live_pick(bot: TierBot) -> String:
	var wd := bot.main.world.wave_director
	var lanes := MapLayout.lanes_for_tier(3)
	var counts := {}
	for l in lanes:
		counts[l] = 0
	for b in wd.alive_enemies():
		counts[String(b.lane)] += 1
	return bot._pick_lane(lanes, counts, wd)

## Lane A (west): its fence has fallen and 2 boars stand past its stop point. Lane B (north): its fence stands and 4 boars are far back.
## Flag on: west. Flag off (no character): north, the most enemies. Fails if `standing` is inverted or `counts` is passed as `breached`.
func test_the_live_pick_goes_to_the_lane_with_enemies_past_a_fallen_fence() -> void:
	Balance.data.tiers.retune_enabled = true
	var bot := await _bot_world(3)
	assert_false(GameState.lane_character().is_empty())
	var stop := MapLayout.path_length("west") - MapLayout.FENCE_OFFSET_FROM_END - 1.2
	GameState.buildings["fence_w"].level = 0  # test-only setup: fallen
	GameState.buildings["fence_n"].level = Balance.data.build.max_level
	GameState.buildings["fence_n"].hp = GameState.fence_max_hp(Balance.data.build.max_level)
	var wd := bot.main.world.wave_director
	for i in 2:
		_spawn_at(wd, "west", &"boar", stop + 0.5)
	for i in 4:
		_spawn_at(wd, "north", &"boar", 2.0)
	assert_eq(_live_pick(bot), "west")
	Balance.data.tiers.retune_enabled = false
	assert_true(GameState.lane_character().is_empty())
	assert_eq(_live_pick(bot), "north")

## A hare past the line of a STANDING fence counts as breached; a boar held at a standing fence does not.
func test_the_live_pick_counts_a_hare_past_a_standing_fence_but_not_a_held_boar() -> void:
	Balance.data.tiers.retune_enabled = true
	var bot := await _bot_world(3)
	var wd := bot.main.world.wave_director
	for f in ["fence_w", "fence_n"]:
		GameState.buildings[f].level = Balance.data.build.max_level
		GameState.buildings[f].hp = GameState.fence_max_hp(Balance.data.build.max_level)
	var line := MapLayout.path_length("west") - MapLayout.FENCE_OFFSET_FROM_END
	_spawn_at(wd, "west", &"hare", line + 0.5)
	for i in 3:
		_spawn_at(wd, "north", &"boar", MapLayout.path_length("north") - MapLayout.FENCE_OFFSET_FROM_END - 1.2)  # held at the standing fence
	assert_eq(_live_pick(bot), "west")
