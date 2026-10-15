extends GutTest
## E8 phase 2 Task 8 (spec 4.5, B9, B10): the tier bot reaches tier 4 and the bench plays tier-4 mixes. Tier 4 is opened in memory (Tier4Support): it is unreachable in
## play until Task 9.

func before_each() -> void:
	Balance.reset()
	Tier4Support.open_tier4()

func after_each() -> void:
	Balance.reset()

## test-only setup: the tier-3 build finished: every spot of tier 3 at the top level, towers and fences branched, both stations at the top level.
func _finish_tier3_ladder(branched := true) -> void:
	for id in MapLayout.spots_for_tier(3):
		GameState.buildings[id].level = Balance.data.build.max_level
		if MapLayout.spot_kind(id) == "fence":
			GameState.buildings[id].hp = GameState.fence_max_hp(Balance.data.build.max_level)
		if branched:
			GameState.buildings[id].branch = &"longbow" if MapLayout.spot_kind(id) == "tower" else &"stone"
	for sid in StationEffects.IDS:
		GameState.stations[sid].level = Balance.data.stations.max_level

func _tier3_bot(gold := 20000) -> TierBot:
	GameState.new_game(1)
	GameState.debug_set_tier(3, 1)
	GameState.add_gold(gold)
	var bot := TierBot.new()
	autofree(bot)
	return bot

# --- the sign of the next tier -------------------------------------------------------------------------------------------------

func test_next_sign_name_follows_the_tier() -> void:
	GameState.new_game(1)
	var bot := TierBot.new()
	autofree(bot)
	var want := {1: "tier_sign", 2: "tier_sign_3", 3: "tier_sign_4"}
	for t in want:
		GameState.debug_set_tier(t, 1)
		assert_eq(bot.next_sign_name(), want[t], "tier %d sells tier %d" % [t, t + 1])

# --- tier 4 only after the ladder ------------------------------------------------------------------------------------------------

## Mutation: dropping `_ladder_done_for_tier_4()` from idle_goal makes the first assert fail.
func test_it_buys_tier_4_only_after_the_tier_3_ladder() -> void:
	var bot := _tier3_bot()
	assert_gt(GameState.tier_remaining_cost(), 0, "setup: tier 4 is for sale")
	assert_lte(GameState.tier_remaining_cost(), GameState.gold, "setup: the gold covers it")
	assert_ne(bot.idle_goal(), "tier_sign_4", "nothing built: the ladder is open")
	_finish_tier3_ladder()
	assert_eq(bot.idle_goal(), "tier_sign_4", "the ladder complete: it seeks the tier-4 sign")
	assert_eq(bot.graph.position_of("tier_sign_4"), MapLayout.tier_sign(4))

func test_every_open_rung_of_the_ladder_holds_the_bot_back() -> void:
	var bot := _tier3_bot()
	var top: int = Balance.data.build.max_level
	for id in MapLayout.spots_for_tier(3):
		_finish_tier3_ladder()
		GameState.buildings[id].level = top - 1
		assert_ne(bot.idle_goal(), "tier_sign_4", "%s below the top level" % id)
		_finish_tier3_ladder()
		GameState.buildings[id].branch = &""
		assert_ne(bot.idle_goal(), "tier_sign_4", "%s unbranched" % id)
	_finish_tier3_ladder()
	GameState.stations[&"counter"].level = Balance.data.stations.max_level - 1
	assert_ne(bot.idle_goal(), "tier_sign_4", "a station below the top")

func test_the_unbranched_policy_needs_no_branch_for_its_ladder() -> void:
	var bot := _tier3_bot()
	bot.policy = "unbranched"
	_finish_tier3_ladder(false)
	assert_eq(bot.idle_goal(), "tier_sign_4")
	bot.policy = "threat"
	assert_ne(bot.idle_goal(), "tier_sign_4", "every other policy still needs its branches")

func test_the_gold_in_hand_must_finish_the_payment() -> void:
	var bot := _tier3_bot(0)
	_finish_tier3_ladder()
	var cost := GameState.tier_remaining_cost()
	GameState.gold = cost - 1  # test-only setup
	assert_ne(bot.idle_goal(), "tier_sign_4")
	GameState.gold = cost  # test-only setup
	assert_eq(bot.idle_goal(), "tier_sign_4")

# --- the cap and the build -------------------------------------------------------------------------------------------------------

## Mutation: reading the cap as `>= 3` (or not at all) makes the capped bot seek the sign.
func test_with_max_tier_3_the_bot_never_buys_tier_4() -> void:
	var bot := _tier3_bot()
	_finish_tier3_ladder()
	assert_eq(bot.idle_goal(), "tier_sign_4", "control: uncapped")
	bot.max_tier = 3
	assert_ne(bot.idle_goal(), "tier_sign_4", "capped at 3")
	bot.max_tier = 4
	assert_eq(bot.idle_goal(), "tier_sign_4", "capped at 4: it pays tier 4")

func test_a_build_without_tier_4_never_sends_the_bot_to_its_sign() -> void:
	Balance.reset()  # tier 4 is not for sale: top tier 3
	GameState.new_game(1)
	GameState.debug_set_tier(3, 1)
	GameState.add_gold(20000)
	var bot := TierBot.new()
	autofree(bot)
	_finish_tier3_ladder()
	assert_eq(GameState.tier_remaining_cost(), -1)
	assert_ne(bot.idle_goal(), "tier_sign_4")
	assert_ne(bot.idle_goal(), "tier_sign_3")

## Mid-payment at the tier-4 sign the bot keeps standing there (day_think reads next_sign_name), and a bot capped at 3 does not. Mutation: the hold names only the
## tier-2 and tier-3 signs: the uncapped assert fails.
func test_the_hold_on_the_tier_4_sign_mid_payment_respects_the_cap() -> void:
	var bot := await _bot_world("threat", 3)
	_finish_tier3_ladder()
	GameState.tier_paid = 100  # test-only setup: a part-payment
	GameState.add_gold(5000)
	await get_tree().physics_frame  # the bot's think() puts the tier-4 sign node in its graph
	var at := bot.graph.position_of("tier_sign_4")
	bot.hero.global_position = Vector3(at.x, bot.hero.global_position.y, at.y)  # test-only setup: the hero on the node
	bot.reset_route()
	bot.goal = "tier_sign_4"
	assert_true(bot.arrived(), "setup: standing on the sign")
	assert_gt(GameState.tier_remaining_cost(), 0)
	bot.day_think(0.0)
	assert_eq(bot.goal, "tier_sign_4", "control: uncapped, it keeps standing on the sign")
	bot.max_tier = 3
	bot.day_think(0.0)
	assert_ne(bot.goal, "tier_sign_4", "capped at 3: no hold")

## At tier 4 the bot buys the two new towers, then the branch of its policy on each, under every policy.
func test_every_policy_picks_the_branch_pads_of_the_new_towers() -> void:
	for policy in TierBot.POLICIES:
		GameState.new_game(1)
		GameState.debug_set_tier(4, 1)
		GameState.add_gold(20000)
		var bot := TierBot.new()
		autofree(bot)
		bot.policy = policy
		_finish_tier3_ladder()
		for id in MapLayout.TIER_SPOTS[4]:
			GameState.buildings[id].level = Balance.data.build.max_level
		var character := GameState.lane_character()
		assert_false(character.is_empty(), "setup: a tier-4 run has a lane character")
		var choices := TierBot.branch_choices(policy, MapLayout.spots_for_tier(4), GameState.lane_plan, 4, character)
		var wanted: Array = []
		for id in MapLayout.TIER_SPOTS[4]:
			wanted.append(TierBot.pad_goal(id, choices[id]))
		var seen := {}
		for i in 2:
			var p := bot.next_purchase()
			assert_true(p in wanted, "%s: the pick %s is a new tower's pad" % [policy, p])
			assert_true(bot.graph.nodes.has(p), "%s: %s is in the tier-4 graph" % [policy, p])
			seen[p] = true
			var target := TierBot._pad_target(p)
			GameState.buildings[target[0]].branch = target[1]  # test-only setup: the pad's branch is bought
		assert_eq(seen.size(), 2, "%s: both new towers get a pad" % policy)
		assert_eq(bot.next_purchase(), "", "%s: nothing is left to buy" % policy)

## Threat-matched reads the new towers' lanes through MapLayout.tower_lanes: a tower on the siege lane takes the Longbow, any other the Volley.
func test_threat_matched_branches_the_new_towers_by_their_lanes() -> void:
	for siege_seed in range(1, 40):
		var character := LaneCharacter.for_run(siege_seed)
		var out := TierBot.branch_choices("threat", MapLayout.TIER_SPOTS[4], [], 4, character)
		for id in MapLayout.TIER_SPOTS[4]:
			var want: StringName = &"longbow" if character.siege in MapLayout.tower_lanes(id) else &"volley"
			assert_eq(out[id], want, "seed %d %s" % [siege_seed, id])

func _bot_world(policy: String, tier := 4) -> TierBot:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	var bot := TierBot.new()
	bot.policy = policy
	main.add_child(bot)
	bot.setup(main)
	main.phase_controller.start_new_game(20260930)
	GameState.debug_set_tier(tier, 1)
	main.phase_controller.debug_skip_to_day()
	return bot

## The bot really walks to both back-lot towers and branches them, for every policy (a world run: the pads are reachable and arm).
func test_in_the_world_every_policy_branches_both_new_towers() -> void:
	for policy in TierBot.POLICIES:
		var bot := await _bot_world(policy)
		for id in GameState.buildings:
			if not id in MapLayout.TIER_SPOTS[4]:
				GameState.buildings[id].level = Balance.data.build.max_level  # test-only setup: the rest is built
				GameState.buildings[id].hp = GameState.fence_max_hp(Balance.data.build.max_level) if MapLayout.spot_kind(id) == "fence" else 0.0
				GameState.buildings[id].branch = &"longbow" if MapLayout.spot_kind(id) == "tower" else &"stone"
		for id in MapLayout.TIER_SPOTS[4]:
			GameState.buildings[id].level = Balance.data.build.max_level
			EventBus.building_changed.emit(StringName(id), Balance.data.build.max_level, 0)
		for sid in StationEffects.IDS:
			GameState.stations[sid].level = Balance.data.stations.max_level
		GameState.add_gold(20000)
		var choices := TierBot.branch_choices(policy, MapLayout.TIER_SPOTS[4], GameState.lane_plan, 4, GameState.lane_character())
		var ok := false
		for i in 60 * 60:
			await get_tree().physics_frame
			if GameState.branch_of("tower_n2") != &"" and GameState.branch_of("tower_e2") != &"":
				ok = true
				break
		assert_true(ok, "%s: both new towers are branched" % policy)
		for id in MapLayout.TIER_SPOTS[4]:
			assert_eq(GameState.branch_of(id), choices[id], "%s %s" % [policy, id])
		assert_eq(bot.stuck_count, 0, policy)
		assert_eq(bot.skipped_goals, 0, policy)
		var world := bot.get_parent()  # one world at a time: the next policy's bot must not share GameState with this one
		world.get_parent().remove_child(world)
		world.free()

# --- the bench's tier-4 mix ------------------------------------------------------------------------------------------------------

## Hand-computed (pressure 15, the cap; run seed 71, lane character siege sw / hare north, tier day 20, day 23):
##  raw wave totals 4 x 5.9 = 23.6 -> 24, 6 x 5.9 = 35.4 -> 35 -> 30, 8 x 5.9 = 47.2 -> 47 -> 30; hp_mult 3.1 x (1, 35/30, 47/30) = 3.1, 3.61667, 4.85667.
##  side share min(0.2 + 0.05 x 13, 0.45) = 0.45: side 11 / 14 / 14, main 13 / 16 / 16; the side group splits (odd unit to side): 6+5 / 7+7 / 7+7.
##  hares at 0.35: wave 3 main round(5.6) = 6, side round(4.9) = 5 -> side 3, side2 2; H = 11, T = round(0.7 x 11) = 8.
##  the planner's wave 3: main sw (siege) 16, side north (hare) 7, side2 east (neutral) 7. Step b: the hare lane (side) takes min(8, 7) = 7 hares, the other 4 fill main (4 of 16).
##  So wave 3: siege = 12 boars + 4 hares + 1 brute (the main lane's brute), hare = 0 boars + 7 hares, neutral = 7 boars + 0 hares.
func test_the_tier_4_mix_at_the_cap_is_the_real_planners_split_for_one_pinned_wave() -> void:
	var plan := BranchBench.tier4_plan(15)
	assert_eq(LaneCharacter.for_run(BranchBench.SEED), {"siege": "sw", "hare": "north"})
	var w: Dictionary = plan[2]
	assert_eq([w.main, w.side, w.side2], ["sw", "north", "east"], "the lanes of wave 3")
	assert_eq([w.main_count, w.side_count, w.side2_count], [16, 7, 7])
	assert_eq([w.fast_main, w.fast_side, w.fast_side2], [4, 7, 0], "step b: 7 hares on the hare lane, the other 4 on main")
	assert_eq([w.brute_main, w.brute_side, w.brute_side2], [1, 0, 0])
	assert_almost_eq(float(w.hp_mult), 3.1 * 47.0 / 30.0, 1e-9)
	var want := {&"siege": [12, 4, 1], &"hare": [0, 7, 0], &"neutral": [7, 0, 0]}
	for lane in want:
		var m: Dictionary = BranchBench.mix(lane, 15, -1, false, 4)[2]
		assert_eq([m.boars, m.hares, m.brutes], want[lane], "%s wave 3: boars, hares, brutes" % lane)
		assert_almost_eq(float(m.hp_mult), 4.8566667, 1e-6, "%s wave 3 hp_mult" % lane)
	var first: Dictionary = BranchBench.mix(&"siege", 15, -1, false, 4)[0]
	assert_eq([first.boars, first.hares, first.brutes], [10, 3, 1], "wave 1: main 13 with 3 hares")
	assert_almost_eq(float(first.hp_mult), 3.1, 1e-9)

func test_a_tier_4_mix_holds_exactly_one_group_of_the_planner_per_lane_type() -> void:
	for p in [12, 13, 14, 15]:
		var plan := BranchBench.tier4_plan(p)
		for lane in BranchBench.LANES:
			var m := BranchBench.mix(lane, p, -1, false, 4)
			assert_eq(m.size(), plan.size())
		var total := [0, 0, 0]
		for w in plan.size():
			for g in ["main", "side", "side2"]:
				total[0] += int(plan[w][g + "_count"])
				total[1] += int(plan[w]["fast_" + g])
				total[2] += int(plan[w]["brute_" + g])
			var sum := [0, 0, 0]
			for lane in BranchBench.LANES:
				var mw: Dictionary = BranchBench.mix(lane, p, -1, false, 4)[w]
				sum[0] += int(mw.boars) + int(mw.hares)
				sum[1] += int(mw.hares)
				sum[2] += int(mw.brutes)
			var wave_total := [0, 0, 0]
			for g in ["main", "side", "side2"]:
				wave_total[0] += int(plan[w][g + "_count"])
				wave_total[1] += int(plan[w]["fast_" + g])
				wave_total[2] += int(plan[w]["brute_" + g])
			assert_eq(sum, wave_total, "p%d wave %d: the three lane types hold the whole wave" % [p, w + 1])

func test_the_tier_3_mix_is_unchanged_by_the_tier_argument() -> void:
	for lane in BranchBench.LANES:
		assert_eq(BranchBench.mix(lane, 12), BranchBench.mix(lane, 12, -1, false, 3))
	assert_eq(BranchBench.mix(&"siege", 12)[2].brutes, 1)
