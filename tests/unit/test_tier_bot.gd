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
