extends GutTest
## E5 tier 3 Task 21 (D-270.1): the switch. `tier_costs` is [0, 500, 1500] as shipped, and tier 3 is reachable through the real
## game: the tier-1 sign, the King's night, the tier-2 sign that sells the front lot, the Baron's night, the tier-3 dawn.
## NOTHING here appends a cost entry or calls debug_set_tier: the shipped build is the subject.

const FIXTURE := "res://tests/fixtures/v5/tier2_full.save.json"  # a real save written BEFORE the switch: tier 2, nothing paid

var main: Main
var sfx: Array = []
var banners: Array = []

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	await get_tree().physics_frame
	main.phase_controller.start_new_game(20260930)
	sfx.clear()
	banners.clear()
	EventBus.sfx_requested.connect(_on_sfx)
	EventBus.banner_requested.connect(_on_banner)

func after_each() -> void:
	EventBus.sfx_requested.disconnect(_on_sfx)
	EventBus.banner_requested.disconnect(_on_banner)
	Balance.reset()
	GameState.new_game(1)

func _on_sfx(id) -> void:
	sfx.append(id)

func _on_banner(t) -> void:
	banners.append(t)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Tier 1 -> 2 through the controller: pay the tier-1 sign, win the King's night, end the reveal, skip the card pick. Ends in the tier-2 day.
func _to_tier_2_day() -> void:
	main.phase_controller.debug_skip_to_day()
	var cost := GameState.tier_next_cost()
	assert_eq(cost, 500, "the tier-1 sign sells tier 2 for 500")
	GameState.add_gold(cost)
	assert_eq(GameState.pay_into_tier(cost), cost)
	main.phase_controller.debug_skip_to_night()
	main.phase_controller.debug_skip_to_day()  # the won boss night's dawn
	main.phase_controller.finish_reveal_now()
	main.phase_controller.debug_skip_to_day()  # skips the tier-2 card pick
	await get_tree().physics_frame

## Stand on the front-lot sign with the gold and let the zone take it (the real stand-still payment).
func _pay_tier_3_by_standing(extra := 0) -> void:
	GameState.add_gold(1500 + extra)
	await TestHelpers.walk_in(main.hero, MapLayout.tier_sign(3))
	var ticks := 0
	while not GameState.boss_pending and ticks < 60 * 20:
		await get_tree().physics_frame
		ticks += 1
	main.hero.teleport(Vector2(15, 8))

## Pays the tier-3 sign and wins the Baron's night: ends at the tier-3 dawn, the reveal about to run.
func _to_tier_3_dawn() -> void:
	await _to_tier_2_day()
	await _pay_tier_3_by_standing()
	main.phase_controller.debug_skip_to_night()
	main.phase_controller.debug_skip_to_day()

# --- the shipped ladder --------------------------------------------------------------------------

## Mutation: tier_costs left at [0, 500] (the switch not thrown) fails every value here.
func test_the_shipped_build_has_three_tiers_and_the_third_costs_1500() -> void:
	var tb := Balance.data.tiers
	assert_eq(Array(tb.tier_costs), [0, 500, 1500])
	assert_eq(TierEffects.top_tier(tb), 3)
	assert_eq(TierEffects.tier_cost(2, tb), 1500)
	assert_eq(TierEffects.tier_cost(3, tb), -1, "nothing is sold beyond tier 3")

# --- the tier-2 sign sells the front lot ---------------------------------------------------------

## Mutation: a sign text that ignores the tier ("Open the yards" at both) fails the text; a sign that stays in the west yard fails the position;
## a build that stops at two tiers fails state() (hidden).
func test_at_tier_2_the_sign_stands_on_the_front_lot_and_sells_it_for_1500() -> void:
	await _to_tier_2_day()
	var sign := main.world.tier_sign
	assert_eq(GameState.tier, 2)
	assert_eq(GameState.tier_next_cost(), 1500)
	assert_eq(sign.state(), &"selling")
	assert_true(sign.visible)
	assert_true(sign.label.visible, "by day")
	assert_true(sign.marker.visible)
	assert_eq(sign.label.text, tr("Buy the lot") + "\n1500")
	assert_ne(sign.label.text, tr("Open the yards") + "\n1500")
	assert_true(sign.position.is_equal_approx(MapLayout.to3(MapLayout.tier_sign(3))), "on the front lot, not in the west yard")
	assert_false(sign.position.is_equal_approx(MapLayout.to3(MapLayout.tier_sign(2))))

## Mutation: the text keyed on a position or on "any sign" instead of the tier fails the tier-1 half.
func test_at_tier_1_the_sign_is_unchanged() -> void:
	main.phase_controller.debug_skip_to_day()
	await get_tree().physics_frame
	var sign := main.world.tier_sign
	assert_eq(GameState.tier, 1)
	assert_eq(sign.label.text, tr("Open the yards") + "\n500")
	assert_true(sign.position.is_equal_approx(MapLayout.to3(MapLayout.tier_sign(2))))

## Mutation: a remaining cost that shows the full price after a payment fails the second line.
func test_a_partial_payment_shows_the_remaining_cost_on_the_front_lot_sign() -> void:
	await _to_tier_2_day()
	GameState.add_gold(600)
	assert_eq(GameState.pay_into_tier(600), 600)
	assert_eq(main.world.tier_sign.label.text, tr("Buy the lot") + "\n900")
	assert_eq(GameState.tier_paid, 600)

## Mutation: a cost other than 1500 (or a sign that never takes the payment) fails: the gold ends at exactly 0 and the boss is pending.
func test_standing_on_the_sign_with_1500_pays_it_in_full_and_a_boss_is_pending() -> void:
	await _to_tier_2_day()
	await _pay_tier_3_by_standing()
	assert_true(GameState.boss_pending)
	assert_eq(GameState.gold, 0)
	assert_eq(main.world.tier_sign.state(), &"boss")
	assert_eq(main.world.tier_sign.label.text, tr("Boss tonight"))

func test_1499_gold_does_not_buy_it() -> void:
	await _to_tier_2_day()
	GameState.add_gold(1499)
	await TestHelpers.walk_in(main.hero, MapLayout.tier_sign(3))
	await _frames(60 * 6)
	assert_false(GameState.boss_pending)
	assert_eq(GameState.tier_paid + GameState.gold, 1499, "nothing vanished")
	assert_eq(GameState.tier_paid, 1499, "it all went in, one short")

# --- the Baron's night and the tier-3 dawn -------------------------------------------------------

## Mutation: boss_kind_for(2) empty (no boss at tier 2) fails the Baron on the wave; a build with no third tier skips the tier-up.
func test_the_baron_night_is_announced_and_leads_the_wave() -> void:
	await _to_tier_2_day()
	await _pay_tier_3_by_standing()
	banners.clear()
	main.phase_controller.debug_skip_to_night()
	assert_true(GameState.is_boss_night())
	assert_true(banners.has(tr("Baron von Hop comes")), str(banners))
	var kinds := WaveSchedule.build(GameState.lane_plan.back(), Balance.data.wave, Balance.data.tiers, GameState.tier).map(func(e): return e.kind)
	assert_eq(kinds[0], &"baron")

## Mutation: the tier staying 2 (the cost entry missing) fails the first line; a reveal with a missing or extra step fails the count of five;
## a world not rebuilt for tier 3 fails each world check.
func test_a_won_baron_night_tiers_up_and_the_world_has_everything_of_tier_3() -> void:
	await _to_tier_3_dawn()
	assert_eq([GameState.tier, GameState.boss_pending, GameState.tier_paid], [3, false, 0])
	var reveal := main.world.tier_reveal
	assert_true(reveal.running(), "the reveal starts at the dawn")
	assert_eq(reveal.steps_left(), 5, "five steps")
	var base := sfx.count(&"build_done")
	await _frames(int(ceil(Balance.data.tiers.tier_reveal_time * 60.0)) + 10)
	assert_false(reveal.running(), "it ran out")
	assert_eq(sfx.count(&"build_done") - base, 5, "five step sounds")
	var w := main.world
	assert_true(w.telegraph_markers.has("sw"), "the SW lane's flag")
	assert_true((w.telegraph_markers["sw"] as TelegraphMarker).is_inside_tree())
	assert_true(w.build_spots.has("tower_sw"))
	assert_true(w.build_spots.has("fence_sw"))
	assert_true(GameState.buildings.has("tower_sw") and GameState.buildings.has("fence_sw"))
	assert_true(w.yard_ids().has("front"), "the front lot")
	assert_eq((w.diner_body.get_node("Visual").get_node("DinerArt") as Node).scene_file_path, "res://art/env/diner_t3.tscn")
	# The night plan the dawn built is the tier-3 plan (mutation: a plan left from tier 2, or one made with tier 2's lanes, differs).
	assert_eq(GameState.lane_plan, LanePlanner.plan(GameState.run_seed, GameState.day, Balance.data.wave, 3, GameState.tier_day, Balance.data.tiers))

## Mutation: a queue still on the west slots at tier 3 fails; so does an exit left in the west.
func test_after_the_reveal_the_queue_stands_east_and_the_served_leave_east() -> void:
	await _to_tier_3_dawn()
	main.phase_controller.finish_reveal_now()
	main.phase_controller.debug_skip_to_day()  # the card pick
	await get_tree().physics_frame
	assert_eq(main.phase_controller.phase, Phase.DAY)
	var sp := main.world.traveler_spawner
	GameState.counter_steaks = 0
	main.hero.teleport(Vector2(15, 8))
	var guard := 0
	while sp.queue.size() < 2 and guard < 60 * 40:
		await get_tree().physics_frame
		guard += 1
	assert_gte(sp.queue.size(), 2)
	guard = 0
	while not (sp.queue[0] as Traveler).at_target() and guard < 60 * 20:
		await get_tree().physics_frame
		guard += 1
	# Slot 0 is (0, 6.0) in BOTH layouts, so it cannot tell them apart; the second slot can: east (1.1, 6.9), west (-1.2, 7.0).
	guard = 0
	while not (sp.queue[1] as Traveler).at_target() and guard < 60 * 20:
		await get_tree().physics_frame
		guard += 1
	var second := (sp.queue[1] as Traveler).xz()
	assert_lt(second.distance_to(Vector2(1.1, 6.9)), 0.06, "the second traveler stands at the east slot (1.1, 6.9), not the west (-1.2, 7.0): %s" % second)
	assert_gt(second.x, 0.0, "east of the counter")
	var front: Traveler = sp.queue[0]
	GameState.counter_steaks = 20
	guard = 0
	while not front.leaving and guard < 60 * 10:
		await get_tree().physics_frame
		guard += 1
	assert_true(front.leaving)
	assert_eq(front._target, MapLayout.traveler_exit(3), "it walks to the east exit")
	assert_gt(front._target.x, 0.0, "east")

## Mutation: lanes_for_tier(3) without "sw" (or a planner that never draws it) fails: some tier-3 plan of 40 days has an sw wave.
func test_a_night_plan_at_tier_3_can_contain_the_south_west_lane() -> void:
	var seen := {}
	for d in range(9, 49):
		for wave in LanePlanner.plan(20260930, d, Balance.data.wave, 3, 9, Balance.data.tiers):
			seen[wave.main] = true
			seen[wave.side] = true
	assert_true(seen.has("sw"), "lanes seen: %s" % [seen.keys()])
	var at_tier_2 := {}
	for d in range(9, 49):
		for wave in LanePlanner.plan(20260930, d, Balance.data.wave, 2, 9, Balance.data.tiers):
			at_tier_2[wave.main] = true
			at_tier_2[wave.side] = true
	assert_false(at_tier_2.has("sw"), "tier 2 never uses it")

## Mutation: pads keyed on something other than the tier and the level fail: none at tier 2, both at a max-level tier-3 building,
## none where the building is below max.
func test_branch_pads_show_at_the_first_tier_3_day_for_max_level_buildings() -> void:
	await _to_tier_2_day()
	assert_eq(main.world.branch_pads.size(), 0, "no pad node at tier 2")
	await _pay_tier_3_by_standing()
	GameState.gold = 100000
	var id := "tower_nw"
	while GameState.next_level_cost(id) >= 0:
		assert_gt(GameState.pay_into_spot(id, 100000), 0)
	GameState.gold = 0
	main.phase_controller.debug_skip_to_night()
	main.phase_controller.debug_skip_to_day()
	main.phase_controller.finish_reveal_now()
	main.phase_controller.debug_skip_to_day()  # the card pick
	await get_tree().physics_frame
	assert_eq(GameState.tier, 3)
	assert_eq(main.phase_controller.phase, Phase.DAY)
	assert_eq(main.world.branch_pads.size(), 9, "a pair for each tier-3 spot")
	for p in main.world.branch_pads[id]:
		assert_true(p.is_shown(), "the max-level tower offers both branches")
	for p in main.world.branch_pads["tower_ne"]:
		assert_false(p.is_shown(), "an unbuilt tower does not")

# --- the top of the ladder -----------------------------------------------------------------------

## Mutation: a fourth sign (a cost entry beyond 1500, or has_tier_sign(4)) fails the hidden state; pay_into_tier taking gold at the top fails the gold.
func test_at_tier_3_no_sign_is_shown_and_paying_does_nothing() -> void:
	await _to_tier_3_dawn()
	main.phase_controller.finish_reveal_now()
	main.phase_controller.debug_skip_to_day()
	await get_tree().physics_frame
	var sign := main.world.tier_sign
	assert_eq(GameState.tier, 3)
	assert_eq(GameState.tier_next_cost(), -1)
	assert_eq(GameState.tier_remaining_cost(), -1)
	assert_eq(sign.state(), &"hidden")
	assert_false(sign.visible)
	assert_eq(sign.label.text, "")
	GameState.add_gold(5000)
	assert_eq(GameState.pay_into_tier(1500), 0)
	assert_eq([GameState.gold, GameState.tier_paid, GameState.boss_pending], [5000, 0, false])
	assert_eq(GameState.tier, 3)

# --- saves ---------------------------------------------------------------------------------------

func _load_state(d: Dictionary) -> void:
	var r := SaveCodec.decode(SaveCodec.encode(d, "t", 0), GameState.SCHEMA_VERSION, Balance.data)
	assert_true(r.ok, r.reason)
	GameState.from_dict(r.state)
	EventBus.state_restored.emit()

## Mutation: a load that zeroes the payment while the sign sells (the old "no next tier" branch) or caps it wrongly fails.
func test_a_schema_6_save_at_tier_2_keeps_its_partial_tier_3_payment() -> void:
	await _to_tier_2_day()
	GameState.add_gold(700)
	assert_eq(GameState.pay_into_tier(700), 700)
	var saved := GameState.to_dict()
	assert_eq([int(saved.v), int(saved.tier), int(saved.tier_paid)], [7, 2, 700])
	GameState.new_game(1)
	_load_state(saved)
	assert_eq([GameState.tier, GameState.tier_paid, GameState.boss_pending], [2, 700, false])
	assert_eq(GameState.tier_remaining_cost(), 800)
	assert_eq(main.world.tier_sign.label.text, tr("Buy the lot") + "\n800")
	assert_eq(main.world.tier_sign.state(), &"selling")

## Mutation: a load that trusts the saved tier (4 on a three-tier build: the world and the sign index past the ladder) fails the first line;
## one that keeps a payment at the full price (the sign could never complete it) fails the second.
func test_a_save_claiming_tier_4_loads_at_3_and_a_full_payment_loads_one_short() -> void:
	await _to_tier_3_dawn()
	var saved := GameState.to_dict()
	assert_eq(int(saved.tier), 3)
	saved.tier = 4
	GameState.new_game(1)
	_load_state(saved)
	assert_eq(GameState.tier, 3, "clamped to the top of the ladder")
	assert_eq(GameState.tier_paid, 0)
	assert_eq(GameState.tier_next_cost(), -1)
	GameState.new_game(1)
	main.phase_controller.start_new_game(20260930)
	await _to_tier_2_day()
	var s2 := GameState.to_dict()
	assert_eq(int(s2.tier), 2)
	s2.tier_paid = 1500
	GameState.new_game(1)
	_load_state(s2)
	assert_eq([GameState.tier, GameState.tier_paid], [2, 1499], "a payment at the price loads one short")
	assert_eq(GameState.tier_remaining_cost(), 1)

## Mutation: a save at tier 2 that cannot show the sign (its payment field coerced to the top) fails: it loads unpaid and the sign says 1500.
func test_a_save_made_before_the_switch_loads_and_shows_the_sign_at_1500() -> void:
	var env = SaveCodec._parse(FileAccess.get_file_as_string(FIXTURE))
	var old = SaveCodec._parse(env.state_json)
	assert_eq([int(old.v), int(old.tier), int(old.tier_paid), bool(old.boss_pending)], [5, 2, 0, false], "the fixture is a schema-5 tier-2 save")
	var r := SaveCodec.decode(FileAccess.get_file_as_string(FIXTURE), GameState.SCHEMA_VERSION, Balance.data)
	assert_true(r.ok, r.reason)
	GameState.from_dict(r.state)
	EventBus.state_restored.emit()
	assert_eq([GameState.tier, GameState.tier_paid, GameState.boss_pending], [2, 0, false])
	assert_eq(GameState.tier_next_cost(), 1500)
	assert_eq(GameState.tier_remaining_cost(), 1500)
	assert_eq(main.world.tier_sign.state(), &"selling")
	assert_eq(main.world.tier_sign.label.text, tr("Buy the lot") + "\n1500")

# --- source scan: the switch is data, not code ---------------------------------------------------

const PROD_DIRS := ["res://autoload", "res://core", "res://components", "res://actors", "res://world", "res://ui", "res://art", "res://balance"]

func _collect(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		_collect(dir_path.path_join(d), out)

## Production .gd files (everything but ui/debug, tests and tools), as path -> lines with the comments cut off.
func _prod_lines() -> Dictionary:
	var files: Array = []
	for d in PROD_DIRS:
		_collect(d, files)
	var out := {}
	for path in files:
		if (path as String).begins_with("res://ui/debug/"):
			continue
		var lines: Array = []
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var cut: String = line
			var hash_at := cut.find("#")
			if hash_at >= 0:
				cut = cut.substr(0, hash_at)
			lines.append(cut.strip_edges())
		out[path] = lines
	return out

## Mutation: a production caller of debug_set_tier (e.g. a "start at tier 3" shortcut outside ui/debug) fails; so does a write to tier_costs.
func test_no_production_code_forces_the_tier_or_writes_the_costs() -> void:
	var prod := _prod_lines()
	assert_true(prod.has("res://autoload/GameState.gd"), "the scan reached autoload/")
	assert_true(prod.has("res://world/world.gd"), "and world/")
	var write_re := RegEx.new()
	write_re.compile("tier_costs\\s*(\\.append|\\.push_back|\\.insert|\\.resize|\\.pop_back|\\.remove_at|\\.assign|\\.clear|\\[[^\\]]*\\]\\s*=|=[^=]|\\+=)")
	var offenders: Array = []
	for path in prod:
		for line in prod[path]:
			if line.contains("debug_set_tier") and not line.begins_with("func debug_set_tier("):
				offenders.append("%s: %s" % [path, line])
			if write_re.search(line) != null and not (path == "res://balance/tier_balance.gd" and line.begins_with("@export var tier_costs")):
				offenders.append("%s: %s" % [path, line])
	assert_eq(offenders, [], "debug_set_tier is called, or tier_costs is written, outside ui/debug, tests and tools")

## Every read of tier_costs in production, one legitimate use each. A new read (a special case for "tier 3 missing") fails this list.
## Mutation: `if tier_costs.size() < 3` anywhere, or any other reader, adds a line and fails.
func test_the_only_reads_of_tier_costs_are_the_two_bounds_in_tier_effects() -> void:
	var prod := _prod_lines()
	var reads: Array = []
	for path in prod:
		for line in prod[path]:
			if line.contains("tier_costs") and not line.begins_with("@export var tier_costs"):
				reads.append("%s: %s" % [path, line])
	reads.sort()
	assert_eq(reads, [
		# top_tier(): the highest tier is the number of entries (the one definition of "top"; every other check goes through it)
		"res://core/tier_effects.gd: return tb.tier_costs.size()",
		# tier_cost(): the cost of buying tier + 1, bounded by top_tier() just above
		"res://core/tier_effects.gd: return tb.tier_costs[tier]",
	])

## No production comparison of top_tier() against a literal tier: "the top is 3" is the data's business. Each use below is a legitimate bound.
## Mutation: `if top_tier(tb) < 3` / `== 2` anywhere fails.
func test_nothing_compares_the_top_tier_against_a_literal() -> void:
	var prod := _prod_lines()
	var re := RegEx.new()
	re.compile("top_tier\\([^)]*\\)\\s*(==|!=|<=|>=|<|>)\\s*\\d|\\d\\s*(==|!=|<=|>=|<|>)\\s*(TierEffects\\.)?top_tier\\(|tier_costs\\.size\\(\\)\\s*(==|!=|<=|>=|<|>)")
	var hits: Array = []
	var uses := 0
	for path in prod:
		for line in prod[path]:
			if line.contains("top_tier("):
				uses += 1
			if re.search(line) != null:
				hits.append("%s: %s" % [path, line])
	# Two tolerated guards, kept deliberately: they are correct for any ladder length (Main builds the branch-pad hint and the warm-up draws the
	# pad visuals only when the build has a tier 3 at all). A third one fails this. The scan is literal: it misses an alias such as
	# `var top := TierEffects.top_tier(tb)` followed by `if top < 3`.
	hits.sort()
	assert_eq(hits, ["res://world/main.gd: if TierEffects.top_tier(Balance.data.tiers) >= 3 and not settings_store.branch_hint_done:",
		"res://world/warmup.gd: if TierEffects.top_tier(Balance.data.tiers) < 3:"])
	assert_gt(uses, 5, "the scan saw the real uses (clamps, loops, pool sizes)")
