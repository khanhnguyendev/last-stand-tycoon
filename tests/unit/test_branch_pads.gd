extends GutTest
## E5 tier 3 Task 17 (D-263, D-264, D-273): the branch pads. At tier 3 a level-3 tower or fence takes one of two branches; the
## player chooses by standing still on one of two pads beside the building. Every test names the wrong implementation it catches.
## The build's top tier is 2, so each test appends the tier-3 cost entry (Balance.reset() drops it).

const ASPECTS := [9.0 / 21.0, 720.0 / 1280.0, 16.0 / 9.0]
const ASPECT_NAMES := ["9:21", "9:16", "16:9"]
const HINT_DIR := "user://test_branch_hint"
## D-294.8: at least this many base px (720 x 1280; the views are in base px at every aspect, like the size floors) between a pad's items and every other label.
const MIN_GAP_PX := 8.0
## The seven buildings that stand at the tier-3 dawn (tower_sw and fence_sw are bought afterwards).
const SEVEN := ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e", "tower_w", "tower_e"]

var main: Main
var pc: PhaseController
var pile_sparkles := 0
var _fx_log: Array = []
var _boxes: Array = []
## The smallest gap (px) found per pad, stage and place of the hero by `_on_findings`: printed by the stood-pad tests.
var _stage_gaps := {}

func before_each() -> void:
	BranchPad.reset_focus()
	Balance.reset()
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)  # test-only: the build knows tier 3
	pile_sparkles = 0
	_fx_log = []
	_boxes = []
	_stage_gaps = {}

func after_each() -> void:
	if EventBus.fx_requested.is_connected(_on_fx):
		EventBus.fx_requested.disconnect(_on_fx)
	SettingsStore.with_dir(HINT_DIR).wipe_for_tests()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HINT_DIR))
	BranchPad.reset_focus()
	Balance.reset()
	GameState.new_game(1)

func _on_fx(kind: StringName, pos: Vector3) -> void:
	_fx_log.append([kind, pos])

## A running game at tier 3, day, the hero under test control. `tier3 := false` stays at tier 2.
func _start(tier3 := true) -> void:
	main = Main.create()
	add_child_autofree(main)
	pc = main.phase_controller
	main.hero.input.player_control = false
	pc.start_new_game(20261007)
	pc.debug_skip_to_day()
	await get_tree().physics_frame
	if tier3:
		GameState.debug_set_tier(3, GameState.day)
	else:
		GameState.debug_set_tier(2, GameState.day)
	GameState.gold = 0
	await get_tree().physics_frame

## Builds `id` to the top level through the real API (gold in, pay_into_spot to level 3), leaving the purse at 0.
func _max(id: String) -> void:
	GameState.gold = 100000
	while GameState.next_level_cost(id) >= 0:
		assert_gt(GameState.pay_into_spot(id, 100000), 0)
	GameState.gold = 0

func _pads(id: String) -> Array:
	return main.world.branch_pads[id]

func _pad_pos(id: String, i: int) -> Vector2:
	return MapLayout.branch_pad(id, i)

func _cost(id: String) -> int:
	return GameState.branch_cost(id)

## Teleports just outside the pad and walks in at move speed (the way a player enters), then stands.
func _stand_on(id: String, i: int) -> void:
	await TestHelpers.walk_in(main.hero, _pad_pos(id, i))

## Stand-still frames until `cond` or `max_frames`.
func _wait_until(cond: Callable, max_frames := 60 * 15) -> void:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1

# --- existence and the option mapping --------------------------------------------------------------------------------------

func test_pads_exist_only_at_tier_3_on_level_3_buildings_without_a_branch() -> void:
	await _start(false)
	assert_eq(main.world.branch_pads.size(), 0, "no pad node exists below tier 3")
	GameState.debug_set_tier(3, GameState.day)
	await get_tree().physics_frame
	assert_eq(main.world.branch_pads.size(), 9, "tier 3: a pair for each of the nine spots")
	for id in main.world.branch_pads:
		assert_eq(_pads(id).size(), 2)
		for p in _pads(id):
			assert_false(p.is_shown(), "%s: an unbuilt spot has no pad on the map" % id)
			assert_false(p.body.visible)
	_max("tower_nw")
	for p in _pads("tower_nw"):
		assert_true(p.is_shown(), "a level-3 tower with no branch shows both pads")
		assert_true(p.body.visible)
	assert_false(_pads("tower_ne")[0].is_shown(), "the other tower is unbuilt: its pads stay away")
	var mid := "fence_n"
	GameState.gold = 100000
	GameState.pay_into_spot(mid, 100000)  # level 1 only
	GameState.gold = 0
	assert_false(_pads(mid)[0].is_shown(), "level 1 or 2 shows no branch pad")
	_max("fence_w")
	assert_true(_pads("fence_w")[1].is_shown())
	GameState.damage_fence("fence_w", 1e6)  # rubble: it loses its level at dawn
	assert_false(_pads("fence_w")[0].is_shown(), "a fence in rubble offers no branch")
	GameState.gold = _cost("tower_nw")
	assert_gt(GameState.pay_into_branch("tower_nw", &"volley", _cost("tower_nw")), 0)
	for p in _pads("tower_nw"):
		assert_false(p.is_shown(), "both pads are gone once a branch is chosen")

func test_pad_index_maps_to_the_branch_option_index_and_the_committed_position() -> void:
	await _start()
	for id in MapLayout.spots_for_tier(3):
		var opts := GameState.branch_options(id)
		for i in 2:
			assert_eq(_pads(id)[i].branch_id, opts[i], "%s pad %d" % [id, i])
			assert_true(_pads(id)[i].global_position.is_equal_approx(MapLayout.to3(_pad_pos(id, i))), "%s pad %d stands at its MapLayout position" % [id, i])
	assert_eq(GameState.branch_options("tower_sw"), [&"longbow", &"volley"], "pinned: tower pads A/B")
	assert_eq(GameState.branch_options("fence_n"), [&"stone", &"spike"], "pinned: fence pads A/B")

func test_the_spots_own_cost_label_gives_way_to_the_pads_and_comes_back_after_the_branch() -> void:
	await _start()
	_max("tower_ne")
	var sp: BuildSpot = main.world.build_spots["tower_ne"]
	assert_false(sp.label.visible, "no MAX label stacks on the pads' labels at a branchable spot")
	assert_false(sp.marker.visible, "the build marker is for an unbuilt spot only")
	assert_eq(sp._pips[2].visible, true, "the three level pips stay")
	GameState.gold = _cost("tower_ne")
	GameState.pay_into_branch("tower_ne", &"longbow", _cost("tower_ne"))
	assert_true(sp.label.visible, "after the branch the spot shows its own MAX again")
	assert_eq(sp.label.text, tr("MAX"))

# --- payment ---------------------------------------------------------------------------------------------------------------

func test_standing_still_drains_gold_into_that_pad_only() -> void:
	await _start()
	_max("tower_sw")
	GameState.gold = 120
	await _stand_on("tower_sw", 1)  # the second option: Volley
	await _wait_until(func(): return GameState.gold == 0)
	assert_eq(GameState.gold, 0, "the offer was taken")
	var b: Dictionary = GameState.buildings["tower_sw"]
	assert_eq(b.branch_paid, {"volley": 120}, "only the pad stood on was paid (a wrong pad index or both pads would show another key)")
	assert_eq(_pads("tower_sw")[1].paid(), 120)
	assert_true(_pads("tower_sw")[1].zone.ring.visible)
	assert_almost_eq(_pads("tower_sw")[1].zone.ring.progress, 120.0 / float(_cost("tower_sw")), 1e-6)
	assert_false(_pads("tower_sw")[0].zone.ring.visible, "the other pad shows no progress")
	assert_eq(_pads("tower_sw")[0].cost_label.text, str(_cost("tower_sw")))
	assert_eq(_pads("tower_sw")[1].cost_label.text, str(_cost("tower_sw") - 120))
	assert_eq(GameState.branch_of("tower_sw"), &"", "a partial payment commits nothing")

func test_a_hero_walking_across_both_pads_at_move_speed_commits_nothing() -> void:
	await _start()
	for id in ["tower_sw", "fence_w", "tower_nw"]:
		_max(id)
	GameState.gold = 5000
	for id in ["tower_sw", "fence_w", "tower_nw"]:
		var a := _pad_pos(id, 0)
		var b := _pad_pos(id, 1)
		var dir := (b - a).normalized()
		var start := a - dir * 2.5
		var finish := b + dir * 2.5
		main.hero.teleport(start)
		await get_tree().physics_frame
		var inside_a := false
		var inside_b := false
		for i in 600:
			var d := finish - main.hero.xz()
			if d.length() < 0.2:
				break
			main.hero.input.set_move(d.normalized())
			await get_tree().physics_frame
			inside_a = inside_a or main.hero.xz().distance_to(a) < MapLayout.BRANCH_PAD_RADIUS
			inside_b = inside_b or main.hero.xz().distance_to(b) < MapLayout.BRANCH_PAD_RADIUS
		main.hero.input.set_move(Vector2.ZERO)
		assert_true(inside_a and inside_b, "%s: the hero really crossed both pads" % id)
		assert_eq(GameState.gold, 5000, "%s: nothing committed by walking through" % id)
		assert_eq(GameState.buildings[id].branch_paid, {}, id)

func test_a_hero_already_standing_where_a_pad_appears_must_leave_and_come_back() -> void:
	await _start()
	await _stand_on("tower_nw", 0)  # walked in and standing still on the spot where the pad will be: the zone is armed
	for i in 90:
		await get_tree().physics_frame
	assert_gte(main.hero.still_time, Balance.data.economy.stand_still_time, "past the stand-still threshold")
	_max("tower_nw")  # the pad appears under the hero
	GameState.gold = 5000
	for i in 120:
		await get_tree().physics_frame
	assert_eq(GameState.gold, 5000, "D-121: the pad appeared under the hero: nothing is taken until they leave and re-enter")
	assert_true(_pads("tower_nw")[0].is_shown())
	await _stand_on("tower_nw", 0)  # walk_in leaves and comes back in
	await _wait_until(func(): return GameState.gold < 5000, 120)
	assert_lt(GameState.gold, 5000, "after leaving and re-entering it pays")

func test_pads_take_nothing_at_night_and_hide() -> void:
	await _start()
	_max("fence_n")
	GameState.gold = 1000
	await _stand_on("fence_n", 0)
	pc.debug_skip_to_night()
	await get_tree().physics_frame
	for p in _pads("fence_n"):
		assert_false(p.is_shown(), "pads are DAY only")
		assert_false(p.body.visible)
		assert_false(p.zone.ring.visible)
	var held := GameState.gold
	for i in 120:
		await get_tree().physics_frame
	assert_eq(GameState.gold, held, "no gold at night")
	_pads("fence_n")[0]._on_tick()  # a tick that slipped through at night (a Stone wall is never a cheap mid-night repair)
	assert_eq(GameState.gold, held, "the pad itself refuses a night payment")
	assert_eq(GameState.buildings["fence_n"].branch_paid, {})

# --- completion and the refund -----------------------------------------------------------------------------------------------

func test_completion_hides_both_pads_at_once_and_flies_the_other_pads_gold_back() -> void:
	await _start()
	_max("tower_e")
	var cost := _cost("tower_e")
	var half := cost / 2
	GameState.gold = half
	assert_eq(GameState.pay_into_branch("tower_e", &"volley", half), half)  # a partial payment on pad B
	GameState.gold = cost + 77
	_fx_log.clear()
	EventBus.fx_requested.connect(_on_fx)
	await _stand_on("tower_e", 0)  # complete pad A (Longbow) by standing
	await _wait_until(func(): return GameState.branch_of("tower_e") != &"")
	assert_eq(GameState.branch_of("tower_e"), &"longbow")
	for p in _pads("tower_e"):
		assert_false(p.is_shown(), "BOTH pads disappear when one completes")
		assert_false(p.body.visible)
	assert_eq(GameState.gold, 77 + half, "the other pad's partial payment is back in gold")
	var b: BranchPad = _pads("tower_e")[1]
	assert_eq(b.last_refund, half, "the effect names the exact amount")
	assert_eq(b.refund_label.text, "+%d" % half, "the exact amount is on the label")
	assert_eq(b.refund_coins, mini(BranchPad.REFUND_COINS, half))
	assert_eq(_pads("tower_e")[0].last_refund, 0, "the pad that was chosen refunds nothing")
	assert_gt(main.world.fly_fx.in_flight(), 0, "coins are in the air")
	await _wait_until(func(): return main.world.fly_fx.in_flight() == 0, 120)
	assert_eq(main.world.fly_fx.in_flight(), 0, "and they land")

func test_the_refund_coins_start_at_the_other_pad_and_end_at_the_hero() -> void:
	await _start()
	_max("tower_e")
	var cost := _cost("tower_e")
	GameState.gold = 100
	GameState.pay_into_branch("tower_e", &"volley", 100)
	GameState.gold = cost
	main.hero.teleport(MapLayout.HOME)
	await get_tree().physics_frame
	GameState.pay_into_branch("tower_e", &"longbow", cost)  # completes: refund 100 from the Volley pad
	var items: Array = main.world.fx_pool.active()
	assert_eq(items.size(), 1, "the first coin leaves at once, the rest follow")
	var it: Node3D = items[0]
	var from_pad: Vector3 = _pads("tower_e")[1].global_position
	assert_almost_eq(it.position.x, from_pad.x, 1e-3, "the coin starts at the OTHER pad (the Volley pad), not the chosen one")
	assert_almost_eq(it.position.z, from_pad.z, 1e-3)
	await _wait_until(func(): return main.world.fly_fx.in_flight() == 0, 120)
	assert_eq(main.world.fly_fx.in_flight(), 0)

func test_a_refund_does_not_sparkle_at_the_gold_pile_but_a_pile_collection_does() -> void:
	await _start()
	_max("tower_e")
	var cost := _cost("tower_e")
	GameState.gold = 100
	GameState.pay_into_branch("tower_e", &"volley", 100)
	GameState.gold = cost
	EventBus.fx_requested.connect(_on_fx)
	_fx_log.clear()
	GameState.pay_into_branch("tower_e", &"longbow", cost)
	for i in 5:
		await get_tree().physics_frame
	var pile := MapLayout.to3(MapLayout.GOLD_PILE, 0.6)
	for e in _fx_log:
		assert_false(e[0] == &"sparkle" and (e[1] as Vector3).is_equal_approx(pile), "a refund is coins flying to the hero, not gold at the pile")
	_fx_log.clear()
	GameState.gold_pile = 12
	GameState.collect_pile()
	await get_tree().physics_frame
	var n := 0
	for e in _fx_log:
		if e[0] == &"sparkle" and (e[1] as Vector3).is_equal_approx(pile):
			n += 1
	assert_eq(n, 1, "a real pile collection still sparkles at the pile")

func test_reactions_tell_a_refund_from_other_gains() -> void:
	var r := Reactions.new()
	add_child_autofree(r)
	EventBus.fx_requested.connect(_on_fx)
	var pile := MapLayout.to3(MapLayout.GOLD_PILE, 0.6)
	var sparkles := func() -> int:
		var n := 0
		for e in _fx_log:
			if e[0] == &"sparkle" and (e[1] as Vector3).is_equal_approx(pile):
				n += 1
		return n
	EventBus.gold_changed.emit(50, 7)  # a plain gain: at once
	assert_eq(sparkles.call(), 1, "a gain with no payment before it sparkles at once")
	_fx_log.clear()
	EventBus.gold_changed.emit(40, -10)  # a payment ...
	EventBus.gold_changed.emit(90, 50)  # ... and the refund of 50 right behind it in the same tick
	EventBus.branch_refunded.emit(&"tower_e", 50)
	await get_tree().process_frame
	assert_eq(sparkles.call(), 0, "a gain right after a payment that branch_refunded names is dropped")
	EventBus.gold_changed.emit(40, -10)
	EventBus.gold_changed.emit(90, 33)  # a sale in the same tick as a payment: no refund names it
	await get_tree().process_frame
	assert_eq(sparkles.call(), 1, "a gain nothing claims still sparkles, one idle later")
	_fx_log.clear()
	EventBus.phase_changed.emit(Phase.DAWN, 3)
	EventBus.gold_changed.emit(140, 50)  # a destroyed fence's dawn refund
	await get_tree().process_frame
	assert_eq(sparkles.call(), 0, "no pile is collected at dawn: a gain then is the fence refund")
	EventBus.phase_changed.emit(Phase.DAY, 3)
	EventBus.gold_changed.emit(150, 10)
	assert_eq(sparkles.call(), 1, "by day a plain collection sparkles again")


## Two physics frames: the hero's move, then the pads' stage update (physics_frame fires before the nodes' _physics_process, D-118).
func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

## Every text label of every pad that is visible in the tree now, by kind: {cost, name, effect, warn} -> Array of pads.
func _visible_text() -> Dictionary:
	var out := {"cost": [], "name": [], "effect": [], "warn": []}
	for id in main.world.branch_pads:
		for p: BranchPad in main.world.branch_pads[id]:
			if not p.body.visible:
				continue
			for k in [["cost", p.cost_label], ["name", p.name_label], ["effect", p.effect_label], ["warn", p.warn_label]]:
				if k[1] != null and (k[1] as Label3D).visible and (k[1] as Label3D).text != "":
					out[k[0]].append(p)
	return out

## Pads whose glyph is visible now.
func _visible_icons() -> Array:
	var out: Array = []
	for id in main.world.branch_pads:
		for p: BranchPad in main.world.branch_pads[id]:
			if p.body.visible and p.icon.visible:
				out.append(p)
	return out

func _all_max() -> void:
	for id in MapLayout.spots_for_tier(3):
		_max(id)

func test_two_gains_after_one_spend_both_wait_and_one_refund_claims_only_its_own() -> void:
	var r := Reactions.new()
	add_child_autofree(r)
	EventBus.fx_requested.connect(_on_fx)
	var pile := MapLayout.to3(MapLayout.GOLD_PILE, 0.6)
	var sparkles := func() -> int:
		var n := 0
		for e in _fx_log:
			if e[0] == &"sparkle" and (e[1] as Vector3).is_equal_approx(pile):
				n += 1
		return n
	EventBus.gold_changed.emit(40, -10)
	EventBus.gold_changed.emit(90, 50)  # the refund
	EventBus.gold_changed.emit(120, 30)  # a sale in the same tick
	EventBus.branch_refunded.emit(&"tower_e", 50)
	await get_tree().process_frame
	assert_eq(sparkles.call(), 1, "the refund is dropped, the sale still sparkles (a single slot would have lost one of the two)")
	_fx_log.clear()
	EventBus.gold_changed.emit(40, -10)
	EventBus.gold_changed.emit(60, 20)
	EventBus.gold_changed.emit(90, 30)
	await get_tree().process_frame
	assert_eq(sparkles.call(), 2, "two unclaimed gains in one frame both sparkle")

func test_reactions_freed_in_the_frame_of_a_spend_flush_nothing_and_raise_nothing() -> void:
	var r := Reactions.new()
	add_child(r)
	EventBus.fx_requested.connect(_on_fx)
	EventBus.gold_changed.emit(40, -10)
	EventBus.gold_changed.emit(90, 50)
	r.free()  # the deferred flush must be dropped with the node
	await get_tree().process_frame
	await get_tree().process_frame
	var n := 0
	for e in _fx_log:
		if e[0] == &"sparkle":
			n += 1
	assert_eq(n, 0, "a freed Reactions flushed no sparkle (and raised no script error: the runner fails on one)")

func test_tiers_1_and_2_never_refresh_a_spot_when_the_world_syncs_its_pads() -> void:
	await _start(false)
	var sp: BuildSpot = main.world.build_spots["tower_nw"]
	sp.label.text = "UNTOUCHED"
	main.world._sync_branch_pads()
	assert_eq(sp.label.text, "UNTOUCHED", "at tier 2 the sync does not refresh a spot")
	assert_eq(main.world.branch_pads.size(), 0)
	GameState.debug_set_tier(3, GameState.day)
	await get_tree().physics_frame
	assert_ne(sp.label.text, "UNTOUCHED", "at tier 3 it does")

# --- the preview (D-263.3) ------------------------------------------------------------------------------------------------

func test_standing_inside_a_pad_shows_the_preview_before_any_gold_moves_and_leaving_hides_it() -> void:
	await _start()
	_max("tower_w")
	GameState.gold = 400
	var pad: BranchPad = _pads("tower_w")[0]
	assert_false(pad.preview_shown())
	await _walk_onto("tower_w", 0)  # E6: the pad is ON once he walked in (armed); a hero placed on it is UNARMED and shows no preview
	assert_true(main.hero.still_time < Balance.data.economy.stand_still_time, "not past the arming threshold yet")
	assert_eq(pad.stage, BranchPad.ON)
	assert_true(pad.preview_shown(), "the preview shows the moment the hero is inside")
	assert_false(pad.effect_label.visible, "its second line is the card's now, not the world's")
	assert_eq(GameState.gold, 400, "and nothing is paid yet")
	assert_false(_pads("tower_w")[1].preview_shown(), "the other pad shows none")
	main.hero.teleport(_pad_pos("tower_w", 0) + Vector2(3.0, 0.0))
	await _settle()
	assert_false(pad.preview_shown(), "it hides when the hero leaves")
	assert_false(pad.effect_label.visible)
	pc.debug_skip_to_night()
	main.hero.teleport(_pad_pos("tower_w", 0))
	await _settle()
	assert_false(pad.preview_shown(), "no preview at night")

func test_the_longbow_preview_draws_a_ring_at_its_range_beside_the_ring_at_todays() -> void:
	Balance.reset()
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)
	Balance.data.branches.longbow.attack_range = 7.3  # a number the pad must read, not remember
	await _start()
	_max("tower_sw")
	var pad: BranchPad = _pads("tower_sw")[0]
	assert_eq(pad.branch_id, &"longbow")
	assert_eq(pad.preview_rings.size(), 2, "the gain is the gap between two rings")
	var radii: Array = pad.preview_rings.map(func(r): return BranchPad.ring_radius(r))
	assert_almost_eq(float(radii[0]), Balance.data.build.tower_range[2], 0.01, "the ring at the level-3 range today")
	assert_almost_eq(float(radii[1]), 7.3, 0.01, "the ring at the Longbow's range, from Balance.data.branches")
	assert_true(pad.preview.global_position.is_equal_approx(MapLayout.to3(MapLayout.spot_position("tower_sw"))), "centred on the tower, not on the pad")
	assert_eq(pad.name_label.text, tr("Longbow"))
	assert_eq(pad.effect_label.text, tr("far, heavy, slow"))
	assert_eq(_pads("tower_sw")[1].preview_rings.size(), 0, "the Volley pad draws no ring")

func test_the_volley_stone_and_spike_previews() -> void:
	Balance.reset()
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)
	Balance.data.branches.volley.count = 4  # the hint and the line read the count
	Balance.data.branches.stone.hp = 480.0  # 480 / 320 = 1.5
	await _start()
	var v: BranchPad = _pads("tower_sw")[1]
	assert_eq(v.name_label.text, tr("Volley"))
	assert_eq(v.effect_label.text, tr("%d targets") % 4, "the line is built from the balance count")
	assert_eq(v.hint_label.text, "x4", "the multiplier is the Volley's count from Balance")
	assert_eq(v.hint_icons[0].mesh, BranchIcons.mesh(&"volley"))
	var s: BranchPad = _pads("fence_sw")[0]
	assert_eq(s.name_label.text, tr("Stone wall"))
	assert_eq(s.effect_label.text, tr("holds brutes"))
	assert_eq(s.hint_label.text, "x1.5", "the HP gain is Stone hp over the level-3 hp, from Balance")
	assert_eq(s.hint_icons[0].mesh, BranchIcons.mesh(&"stone"), "a shield glyph")
	var k: BranchPad = _pads("fence_sw")[1]
	assert_eq(k.name_label.text, tr("Spike fence"))
	assert_eq(k.effect_label.text, tr("hurts attackers"))
	assert_eq(k.hint_icons[0].mesh, BranchIcons.mesh(&"spike"), "a spike glyph")
	assert_null(k.hint_label, "spikes carry no number")
	assert_eq(BranchPad._mult_text(2.0), "x2", "a whole gain has no decimal")

func test_fence_pads_carry_the_broken_fence_line_and_tower_pads_do_not() -> void:
	await _start()
	for id in MapLayout.spots_for_tier(3):
		for p in _pads(id):
			if MapLayout.spot_kind(id) == "fence":
				assert_not_null(p.warn_label, id)
				assert_eq(p.warn_label.text, tr("lost if broken"), id)
				assert_eq(p.warn_icon.mesh, BranchIcons.mesh(&"broken"), id)
			else:
				assert_null(p.warn_label, id + ": a tower is not lost when it is hit")
				assert_null(p.warn_icon)

func test_the_branch_glyphs_are_distinct_and_fully_triangulated() -> void:
	var seen := {}
	for kind in BranchIcons.KINDS:
		var m := BranchIcons.mesh(kind)
		assert_eq(m.surface_get_array_len(0), BranchIcons.expected_vertices(kind), "%s: every layer triangulated" % kind)
		for l in BranchIcons.layers(kind):
			assert_eq(Geometry2D.triangulate_polygon(l[0]).size(), 3 * (l[0].size() - 2), "%s: a layer is a simple polygon" % kind)
			assert_false(String(l[1]).begins_with("gold"), "%s: gold is the hero-and-reward colour" % kind)
			assert_false(String(l[1]).contains("white"), "%s: no white" % kind)
		var box := m.get_aabb()
		assert_lte(box.size.x, 1.3, kind + " fits its square")
		assert_lte(box.size.y, 1.3, kind + " fits its square")
		var sig := str(m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
		assert_false(seen.has(sig), "%s differs from every other glyph" % kind)
		seen[sig] = true
	assert_true(BranchIcons.material().billboard_keep_scale)
	await _start()
	for id in MapLayout.spots_for_tier(3):
		var a: BranchPad = _pads(id)[0]
		var b: BranchPad = _pads(id)[1]
		assert_ne(a.icon.mesh, b.icon.mesh, "%s: the two options have different icons" % id)
		assert_eq(a.icon.mesh, BranchIcons.mesh(a.branch_id))

# --- stages: progressive disclosure -----------------------------------------------------------------------------------------

func test_far_pads_show_a_depth_tested_glyph_and_no_text_anywhere() -> void:
	await _start()
	for id in SEVEN:  # the tier-3 dawn: the seven old buildings stand at level 3, the two new spots are not built yet
		_max(id)
	main.hero.teleport(MapLayout.HOME)
	await _settle()
	assert_eq(BranchPad.focus_spot(), "", "nothing within near_m of HOME")
	var text := _visible_text()
	for k in text:
		assert_eq(text[k].size(), 0, "far stage: no %s label anywhere" % k)
	assert_eq(_visible_icons().size(), 14, "every pad of the seven shows its glyph")
	for p in _visible_icons():
		assert_eq(p.stage, BranchPad.FAR)
		assert_eq(p.icon.material_override, BranchIcons.far_front_material(BranchPad.LABEL_PRIORITY), "the far glyph draws with the pad labels' priority (before the hero)")
		assert_false(p.icon.material_override.no_depth_test, "but it is depth-tested, so a building hides it")
		assert_true(p.marker.visible and p.body.visible, "the ring is there")
		assert_almost_eq(p.icon.scale.x, Balance.ui.branch_pad_far_icon_m, 1e-6)

func test_on_stage_shows_the_glyph_and_the_preview_on_exactly_the_stood_pad_and_leaving_reverts() -> void:
	await _start()
	for id in SEVEN:
		_max(id)
	await _walk_onto("fence_n", 1)
	var text := _visible_text()
	var pad: BranchPad = _pads("fence_n")[1]
	assert_eq(text.name.size() + text.effect.size() + text.warn.size(), 0, "no name, preview line or warning in the world: they are the card's")
	assert_eq(text.cost.size(), 0, "and no cost: the card owns it while the pad is armed")
	assert_eq(pad.stage, BranchPad.ON)
	assert_true(pad.icon.visible and pad.preview_shown(), "the glyph and the preview shape show on exactly the stood pad")
	var sib: BranchPad = _pads("fence_n")[0]
	assert_eq(sib.stage, BranchPad.SIBLING_QUIET)
	assert_false(sib.icon.visible, "the sibling shows no glyph")
	assert_false(sib.cost_label.visible, "and no cost")
	assert_true(sib.body.visible and sib.marker.visible, "but its ground ring")
	var visible_glyphs := 0
	for q in _pads("fence_n"):
		if q.icon.visible:
			visible_glyphs += 1
	assert_eq(visible_glyphs, 1, "at that spot exactly one pad shows a glyph")
	var quiet := 0
	for id in main.world.branch_pads:
		for p in main.world.branch_pads[id]:
			if p.stage == BranchPad.FAR_QUIET:
				quiet += 1
				assert_false(p.icon.visible, "a far glyph hides while the hero stands on any pad")
	assert_eq(quiet, 12)
	main.hero.teleport(MapLayout.HOME)
	await _settle()
	text = _visible_text()
	for k in text:
		assert_eq(text[k].size(), 0, "leaving reverts: no %s" % k)
	assert_eq(_visible_icons().size(), 14)
	assert_false(pad.preview_shown())
	assert_eq(sib.stage, BranchPad.FAR, "leaving the pad brings the sibling's glyph back")
	assert_true(sib.icon.visible)
	main.hero.teleport(_pad_pos("fence_n", 0) + Vector2(0.0, -3.0))  # 3 m north of the pad, out in the lane
	await _settle()
	assert_eq(sib.stage, BranchPad.NEAR, "and, near the pad, its cost")
	assert_true(sib.cost_label.visible and sib.icon.visible)

func test_the_siblings_payment_ring_stays_visible_while_it_is_quiet() -> void:
	await _start()
	_max("tower_w")
	GameState.gold = 120
	GameState.pay_into_branch("tower_w", &"volley", 120)  # a partial payment on pad B
	var b: BranchPad = _pads("tower_w")[1]
	main.hero.teleport(_pad_pos("tower_w", 0))  # stand on pad A
	await _settle()
	assert_eq(b.stage, BranchPad.SIBLING_QUIET)
	assert_false(b.icon.visible)
	assert_true(b.body.visible and b.marker.visible, "the sibling's ground ring")
	assert_true(b.zone.ring.visible, "the sibling's payment-progress ring")
	assert_almost_eq(b.zone.ring.progress, 120.0 / float(_cost("tower_w")), 1e-6)

func test_no_stale_focus_survives_night_a_new_game_or_a_load() -> void:
	await _start()
	_max("tower_w")
	main.hero.teleport(_pad_pos("tower_w", 0))
	await _settle()
	assert_eq(BranchPad.focus_spot(), "tower_w")
	assert_not_null(BranchPad.pad_hero_stands_on())
	pc.debug_skip_to_night()
	assert_eq(BranchPad.focus_spot(), "", "night: nothing focused, at once")
	assert_null(BranchPad.pad_hero_stands_on())
	pc.debug_skip_to_day()
	await _settle()
	assert_eq(BranchPad.focus_spot(), "tower_w")
	var d := GameState.to_dict()
	GameState.new_game(3)
	assert_eq(BranchPad.focus_spot(), "", "a new game")
	assert_null(BranchPad.pad_hero_stands_on())
	GameState.from_dict(d)
	await _settle()
	assert_eq(BranchPad.focus_spot(), "tower_w", "a load recomputes it")

func test_far_glyphs_meet_their_floor_from_home() -> void:
	await _start()
	for id in SEVEN:
		_max(id)
	main.hero.teleport(MapLayout.HOME)
	await _settle()
	# Mutation: a far glyph size under branch_pad_far_icon_min_px fails at any aspect. Pads off screen at an aspect are skipped (9:21 sees fewer).
	for a in ASPECTS.size():
		var v := View.new(MapLayout.HOME, ASPECTS[a])
		var worst := INF
		var seen := 0
		var sizes: Array = []
		for id in SEVEN:
			for p: BranchPad in _pads(id):
				assert_eq(p.stage, BranchPad.FAR)
				if not v.screen().has_point(v.pt(p.icon.global_position)):
					continue
				var h := _node_rect(p.icon, v).size.y / 1.14
				sizes.append("%s %.0f" % [p.name.trim_prefix("BranchPad_"), h])
				worst = minf(worst, h)
				seen += 1
		assert_gt(seen, 6, "most pads are on screen from HOME at %s" % ASPECT_NAMES[a])
		gut.p("far glyph heights from HOME at %s (base px): %s; worst %.1f, floor %.0f" % [ASPECT_NAMES[a], sizes, worst, Balance.ui.branch_pad_far_icon_min_px])
		assert_gte(worst, Balance.ui.branch_pad_far_icon_min_px, "far glyph floor at %s" % ASPECT_NAMES[a])

func test_at_night_nothing_of_any_pad_shows() -> void:
	await _start()
	_all_max()
	main.hero.teleport(_pad_pos("fence_n", 1))
	await _settle()
	pc.debug_skip_to_night()
	await _settle()
	assert_eq(_visible_icons().size(), 0)
	var text := _visible_text()
	for k in text:
		assert_eq(text[k].size(), 0)
	for id in main.world.branch_pads:
		for p in main.world.branch_pads[id]:
			assert_false(p.body.visible)
			assert_false(p.preview.visible)
			assert_false(p.is_physics_processing(), "a hidden pad costs nothing")
	pc.debug_skip_to_day()
	await _settle()
	for id in main.world.branch_pads:
		for p in main.world.branch_pads[id]:
			assert_true(p.is_physics_processing(), "a shown pad processes")

func test_the_focus_spot_keeps_with_hysteresis_and_is_computed_once_per_frame() -> void:
	await _start()
	_all_max()
	var base := _pad_pos("tower_nw", 1)  # (-3.0, -5.1)
	assert_eq([Balance.ui.branch_pad_near_m, Balance.ui.branch_pad_leave_m], [3.5, 3.8], "the band the distances below are chosen for")
	# The diner's wall pushes a hero standing straight south of the pad to x = -4.4, a frame after he is placed; so the points are chosen on the free side of
	# that wall, `d` metres from the pad exactly: 1.45 m west of its x and sqrt(d^2 - 1.45^2) south of it.
	var at := func(d: float) -> Vector2: return base + Vector2(-1.45, sqrt(d * d - 1.45 * 1.45))
	main.hero.teleport(at.call(3.0))
	await _settle()
	assert_almost_eq(main.hero.xz().distance_to(base), 3.0, 0.01, "setup: the hero stands where it was put")
	assert_eq(BranchPad.focus_spot(), "tower_nw", "3.0 m: inside near_m")
	main.hero.teleport(at.call(3.65))
	await _settle()
	assert_almost_eq(main.hero.xz().distance_to(base), 3.65, 0.01, "setup")
	assert_eq(BranchPad.focus_spot(), "tower_nw", "3.65 m: beyond near_m 3.5, inside leave_m 3.8: kept")
	main.hero.teleport(at.call(4.0))
	await _settle()
	assert_eq(BranchPad.focus_spot(), "", "4.0 m: beyond leave_m: dropped")
	main.hero.teleport(at.call(3.65))
	await _settle()
	assert_eq(BranchPad.focus_spot(), "", "3.65 m from a dropped focus: beyond near_m, not re-chosen")
	# one computation per physics frame: a second call in the same frame sees the cached answer
	main.hero.teleport(base + Vector2(0.0, 3.0))
	await get_tree().physics_frame
	BranchPad.update_focus(get_tree())
	var first := BranchPad.focus_spot()
	main.hero.teleport(MapLayout.HOME)
	BranchPad.update_focus(get_tree())
	assert_eq(BranchPad.focus_spot(), first, "the same physics frame: cached")
	await get_tree().physics_frame
	BranchPad.update_focus(get_tree())
	assert_ne(BranchPad.focus_spot(), first, "the next frame: recomputed")

func test_the_focus_spot_is_the_nearest_branchable_one_and_ties_follow_the_spot_order() -> void:
	await _start()
	_max("tower_ne")
	_max("tower_nw")
	# a point on the x = 0 axis is equally far from the mirrored pads (-3.0, -5.5) and (3.0, -5.5)
	main.hero.teleport(Vector2(0.0, -5.5))
	await _settle()
	assert_eq(BranchPad.focus_spot(), "tower_nw", "a tie goes to the first spot in spots_for_tier order")
	main.hero.teleport(Vector2(0.5, -5.5))
	await _settle()
	assert_eq(BranchPad.focus_spot(), "tower_nw", "kept by hysteresis")
	BranchPad.reset_focus()
	main.hero.teleport(Vector2(1.0, -5.5))
	await _settle()
	assert_eq(BranchPad.focus_spot(), "tower_ne", "nearest wins")

# --- readability at phone size (in base pixels) ------------------------------------------------------------------------

class View:
	var xf: Transform3D
	var proj: Projection
	var aspect: float
	func _init(focus: Vector2, p_aspect: float) -> void:
		xf = CameraMath.camera_transform(CameraMath.focus_for(focus), Balance.ui)
		proj = CameraMath.projection(Balance.ui, p_aspect)
		aspect = p_aspect
	## The base view (project.godot: canvas_items, expand): 720 wide below 9:16 (height 720 / aspect), else 1280 high (width 1280 * aspect).
	func half_h() -> float:
		return 0.5 * maxf(1280.0, 720.0 / aspect)
	func half_w() -> float:
		return 0.5 * (720.0 if aspect < 720.0 / 1280.0 else 1280.0 * aspect)
	func pt(w: Vector3) -> Vector2:
		var n := CameraMath.to_ndc(w, xf, proj)
		return Vector2(n.x * half_w(), -n.y * half_h())
	func quad(c: Vector3, sz: Vector2) -> Rect2:
		return bounds([c + xf.basis.x * sz.x * 0.5 + xf.basis.y * sz.y * 0.5, c - xf.basis.x * sz.x * 0.5 + xf.basis.y * sz.y * 0.5,
			c + xf.basis.x * sz.x * 0.5 - xf.basis.y * sz.y * 0.5, c - xf.basis.x * sz.x * 0.5 - xf.basis.y * sz.y * 0.5])
	func box(b: AABB) -> Rect2:
		var pts: Array = []
		for k in 8:
			pts.append(b.position + Vector3(b.size.x * (k & 1), b.size.y * ((k >> 1) & 1), b.size.z * ((k >> 2) & 1)))
		return bounds(pts)
	func bounds(pts: Array) -> Rect2:
		var r := Rect2(pt(pts[0]), Vector2.ZERO)
		for q in pts:
			r = r.expand(pt(q))
		return r
	func screen() -> Rect2:
		return Rect2(-half_w(), -half_h(), half_w() * 2.0, half_h() * 2.0)
	## Base px per metre of camera-up at `w`.
	func px_per_m(w: Vector3) -> float:
		return quad(w, Vector2(0.0, 1.0)).size.y

## The rect of a shown glyph or label, from the REAL node: its global position and the box it draws now.
func _node_rect(n: Node3D, v: View) -> Rect2:
	if n is Label3D:
		var l := n as Label3D
		var b := BranchPad.text_box(l)
		var c := l.global_position
		if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT:
			c += v.xf.basis.x * b.x * 0.5
		return v.quad(c, b)
	return v.quad(n.global_position, BranchPad.glyph_box(n as MeshInstance3D))

## [[name, node, rect]] of everything a pad shows now (glyph, cost, name, effect, warning glyph and text).
func _pad_items(p: BranchPad, v: View) -> Array:
	var out: Array = []
	if not p.body.visible:
		return out
	for pair in [["icon", p.icon], ["cost", p.cost_label], ["name", p.name_label], ["effect", p.effect_label], ["warn_icon", p.warn_icon], ["warn", p.warn_label]]:
		var n: Node3D = pair[1]
		if n == null or not n.visible or (n is Label3D and (n as Label3D).text == ""):
			continue
		out.append(["%s/%s" % [p.name, pair[0]], n, _node_rect(n, v)])
	return out

## The rect of the preview's glyph (and its multiplier) over the building, when the preview shows one.
func _preview_rect(p: BranchPad, v: View) -> Variant:
	if not p.preview.visible or p.hint_icons.is_empty():
		return null
	var r := _node_rect(p.hint_icons[0], v)
	if p.hint_label != null:
		r = r.merge(_node_rect(p.hint_label, v))
	return r

func _px_h(p: Vector3, len_m: float, v: View) -> float:
	return v.quad(p, Vector2(0.0, len_m)).size.y

func _font_w(text: String, size: int) -> float:
	return (load(WorldLabel.BOLD_PATH) as Font).get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x * 0.01

## Cost-label and level-pip rects of every spot at every level (unbuilt and built heights), minus `skip`'s own cost label.
func _spot_rects(v: View, skip: String) -> Array:
	var out: Array = []
	for id in main.world.build_spots:
		var sp: BuildSpot = main.world.build_spots[id]
		for lvl in range(0, Balance.data.build.max_level + 1):
			if id != skip:
				out.append([id + " label L%d" % lvl, v.quad(sp.global_position + Vector3(0, sp._label_y(lvl), 0), Vector2(1.2, 0.6))])
			if lvl >= 1:
				out.append([id + " pips L%d" % lvl, v.quad(sp.global_position + Vector3(0, sp._pip_y(lvl), 0), Vector2(1.1, 0.4))])
	return out

func _sign_rect(v: View) -> Rect2:
	var w := _font_w(tr("Close up"), 36) + 0.08
	return v.quad(MapLayout.to3(MapLayout.SIGN, 1.95), Vector2(w, 0.36 * 1.3))

## The tier sign's label, when it shows (at the top tier the sign is hidden: then there is nothing to clear).
func _tier_sign_rect(v: View) -> Variant:
	var ts: TierSign = main.world.tier_sign
	if ts == null or not ts.label.visible:
		return null
	return _node_rect(ts.label, v)

## The HUD's top bar in base px: the day label, moons and diner bar column (16 + 54 + 6 + the bar) over the full width.
func _hud_rect(v: View) -> Rect2:
	return Rect2(-v.half_w(), -v.half_h(), v.half_w() * 2.0, 16.0 + 54.0 + 6.0 + Hud.BAR_SIZE.y)

func _hero_rect(at: Vector2, v: View) -> Rect2:
	return v.box(AABB(Vector3(at.x - 0.4, 0.0, at.y - 0.05), Vector3(0.8, 1.8, 0.1)))

## The quads (world centre, size in m) of everything a telegraph marker's row shows now (the geometry test_telegraph.gd measures).
func _row_quads(mk: TelegraphMarker) -> Array:
	var out: Array = []
	var xf := CameraMath.camera_transform(Vector2.ZERO, Balance.ui)  # billboards face the camera: one basis for every focus
	for kind in mk.items:
		var it: Dictionary = mk.items[kind]
		if not (it.icon as Node3D).visible:
			continue
		var ic := it.icon as MeshInstance3D
		var bb := ic.mesh.get_aabb()
		out.append([ic.global_position + xf.basis.x * (bb.get_center().x * ic.scale.x) + xf.basis.y * (bb.get_center().y * ic.scale.y), Vector2(bb.size.x, bb.size.y) * ic.scale.x])
		if it.num != null:
			var l := it.num as Label3D
			var lb := l.get_aabb()
			out.append([l.global_position + xf.basis.x * lb.get_center().x, Vector2(lb.size.x, 0.75 * float(l.font_size) * l.pixel_size)])
	return out

## [[lane, quads]] of every row of every plan, computed once (setting a plan refreshes every marker).
func _all_rows(plans: Array) -> Array:
	var out: Array = []
	for pl in plans:
		_set_plan(pl)
		for lane in main.world.telegraph_markers:
			var mk: TelegraphMarker = main.world.telegraph_markers[lane]
			if not mk.shown().is_empty():
				out.append([lane, _row_quads(mk)])
	return out

func _row_rect(quads: Array, v: View) -> Rect2:
	var rect := Rect2()
	var first := true
	for q in quads:
		var r := v.quad(q[0], q[1])
		rect = r if first else rect.merge(r)
		first = false
	return rect

func _wave(m: String, mc: int, fm: int, s: String, sc: int, fs: int, bm := 0, bs := 0) -> Dictionary:
	return {"main": m, "side": s, "main_count": mc, "side_count": sc, "hp_mult": 1.0,
		"fast_main": fm, "fast_side": fs, "boss": false, "brute_main": bm, "brute_side": bs}

## Every lane carries Boar, hare and brute and the boss is on `boss_lane`: the widest rows.
func _plan_boss_on(boss_lane: String) -> Array:
	var w1 := _wave("west", 6, 2, "east", 5, 1, 1, 1)
	var w2 := _wave("north", 6, 2, "sw", 5, 1, 1, 1)
	var w3 := _wave(boss_lane, 6, 2, "north" if boss_lane != "north" else "west", 5, 1, 1, 1)
	w3.boss = true
	return [w1, w2, w3]

func _set_plan(plan: Array) -> void:
	GameState.lane_plan = plan
	for m in main.world.telegraph_markers.values():
		m.refresh()

func _gap(a: Rect2, b: Rect2) -> float:
	return maxf(maxf(b.position.x - a.end.x, a.position.x - b.end.x), maxf(b.position.y - a.end.y, a.position.y - b.end.y))

## Nearest distance (screen metres at the pad) from the pad's centre to a rect.
func _attach_m(r: Rect2, centre: Vector2, ppm: float) -> float:
	var q := Vector2(clampf(centre.x, r.position.x, r.end.x), clampf(centre.y, r.position.y, r.end.y))
	return centre.distance_to(q) / ppm

## How far (screen metres) the ON stack may stand from the pad's centre (nearest edge): one line above the head (1.05), a second
## above it (1.9) and the warning under the glyph row below the pad (2.0). The sibling's NEAR block must stay within 1.5.
const ATTACH_ON_M := 3.2
const ATTACH_NEAR_M := 1.5
## The margin the worst-point scan keeps between the spot's nearest pad and the next spot's (m). Mutation: 0.5 (the old one) moves fence_e's point.
const WORST_MARGIN_M := 0.02
const HULL_MARGIN_PX := 6.5

func test_the_ui_floors_are_the_plans() -> void:
	assert_eq(Balance.ui.branch_pad_icon_min_px, 28.0)
	assert_eq(Balance.ui.branch_pad_label_min_px, 28.0)
	assert_eq(Balance.ui.branch_pad_warn_min_px, 20.0)
	assert_eq(Balance.ui.branch_pad_near_m, 3.5)
	assert_eq(Balance.ui.branch_pad_leave_m, 3.8, "E6 round 5: the keep band is 0.3 m wider than the near distance")
	assert_true(Balance.ui.branch_pad_label_font in [48, 40] and Balance.ui.branch_pad_cost_font in [48, 40] and Balance.ui.branch_pad_warn_font in [48, 40], "the project's own font sizes")

func test_sizes_meet_the_floors_for_the_stood_pad() -> void:
	await _start()
	_all_max()
	var worst := {"icon": INF, "label": INF, "cost": INF, "warn": INF}
	for aspect in ASPECTS:
		for id in MapLayout.spots_for_tier(3):
			for i in 2:
				main.hero.teleport(_pad_pos(id, i))
				await _settle()
				var v := View.new(_pad_pos(id, i), aspect)
				var p: BranchPad = _pads(id)[i]
				for it in _pad_items(p, v):
					var n: Node3D = it[1]
					if n == p.icon:
						worst.icon = minf(worst.icon, (it[2] as Rect2).size.y / 1.14)
					elif n == p.name_label or n == p.effect_label:
						worst.label = minf(worst.label, _px_h(n.global_position, float(p.name_label.font_size) * p.name_label.pixel_size, v))
					elif n == p.cost_label:
						worst.cost = minf(worst.cost, _px_h(n.global_position, float(p.cost_label.font_size) * p.cost_label.pixel_size, v))
					elif n == p.warn_label:
						worst.warn = minf(worst.warn, _px_h(n.global_position, float(p.warn_label.font_size) * p.warn_label.pixel_size, v))
	gut.p("measured worst (base px): %s" % [worst])
	var ui := Balance.ui
	assert_gte(worst.icon, ui.branch_pad_icon_min_px, "the stood pad's glyph")
	assert_gte(worst.label, ui.branch_pad_label_min_px, "name and preview line em")
	assert_gte(worst.cost, ui.branch_pad_label_min_px, "the stood pad's cost em")
	assert_gte(worst.warn, ui.branch_pad_warn_min_px, "the warning line em")

## The nearest distance from `at` to any pad of `id` (or, with `others`, to any pad of another spot).
func _pad_dist(at: Vector2, id: String, others := false) -> float:
	var best := INF
	var table := MapLayout.BRANCH_PADS
	for oid in table:
		if (oid == id) == others:
			continue
		for pp in table[oid]:
			best = minf(best, at.distance_to(pp))
	return best

## The distance (m, on the ground) from `at` to the nearest solid the hero collides with: every BoxShape3D of a layer-1 StaticBody3D in the
## world, read from the real colliders (the diner, the counter and the freezer: three boxes; the fences and towers have no collider). Negative
## inside one. The boxes are read once per game (`_boxes`).
func _solid_dist(at: Vector2) -> float:
	if _boxes.is_empty():
		for body in _static_bodies(main.world):
			for c in body.get_children():
				if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
					_boxes.append([(c as CollisionShape3D).global_transform.affine_inverse(), ((c as CollisionShape3D).shape as BoxShape3D).size * 0.5, (c as CollisionShape3D).global_position.y])
		assert_eq(_boxes.size(), 3, "the world has three solids: the diner, the counter and the freezer")
	var best := INF
	for b in _boxes:
		var l: Vector3 = (b[0] as Transform3D) * Vector3(at.x, b[2], at.y)
		var half: Vector3 = b[1]
		var out := Vector2(maxf(absf(l.x) - half.x, 0.0), maxf(absf(l.z) - half.z, 0.0))
		best = minf(best, out.length() if out.length() > 0.0 else maxf(absf(l.x) - half.x, absf(l.z) - half.z))
	return best

func _static_bodies(n: Node) -> Array:
	var out: Array = []
	if n is StaticBody3D and (n as StaticBody3D).collision_layer & 1 != 0:
		out.append(n)
	for c in n.get_children():
		out.append_array(_static_bodies(c))
	return out

## Whether `at` is a fair NEAR view of `id`: reachable, the spot's own nearest pad within `limit` and the nearest of the map by 0.5 m.
func _near_ok(id: String, at: Vector2, limit: float) -> bool:
	var own := _pad_dist(at, id)
	return own <= limit and own > MapLayout.BRANCH_PAD_RADIUS and _pad_dist(at, id, true) > own + 0.5 and _solid_dist(at) > MapLayout.HERO_RADIUS + 0.05 \
			and at.x > -16.0 and at.x < 16.0 and at.y > -19.0 and at.y < 14.0

## "home": `dist` metres from the pad nearest HOME, on the line towards HOME, turned (15 degree steps, smallest turn first) until the point is a
## fair NEAR view. "worst": the worst ground for size, found by a scan: the camera pitch makes a pad smaller the further NORTH of the hero it is, so
## the point maximises min(z, the camera's focus clamp) - z of the spot's northern pad, over every 0.05 m grid point a hero can stand on (off
## every solid by his radius + 0.05, off every pad, the spot's nearest pad within (0.9, near_m - 0.05] m, every other spot's nearest pad further
## than the own one by 0.02 m: the game has no larger margin, it focuses the strictly nearest spot). Vector2(INF, INF) when none exists.
func _near_hero_at(id: String, dist: float, approach: String) -> Vector2:
	var pads: Array = MapLayout.BRANCH_PADS[id]
	if approach == "worst":
		var limit: float = Balance.ui.branch_pad_near_m - 0.05
		var north_z := minf((pads[0] as Vector2).y, (pads[1] as Vector2).y)
		var lo := Vector2(minf((pads[0] as Vector2).x, (pads[1] as Vector2).x), north_z) - Vector2.ONE * limit
		var hi := Vector2(maxf((pads[0] as Vector2).x, (pads[1] as Vector2).x), maxf((pads[0] as Vector2).y, (pads[1] as Vector2).y)) + Vector2.ONE * limit
		var best := Vector2(INF, INF)
		var best_score := -INF
		for xi in range(int(lo.x / 0.05), int(hi.x / 0.05) + 1):
			for zi in range(int(lo.y / 0.05), int(hi.y / 0.05) + 1):
				var at := Vector2(xi * 0.05, zi * 0.05)
				var own := _pad_dist(at, id)
				if own <= 0.9 or own > limit:
					continue
				var score := minf(at.y, CameraMath.FOCUS_MAX.y) - north_z
				if score <= best_score or _pad_dist(at, id, true) <= own + WORST_MARGIN_M or _solid_dist(at) <= MapLayout.HERO_RADIUS + 0.05:
					continue
				if at.x < -16.0 or at.x > 16.0 or at.y < -19.0 or at.y > 14.0:
					continue
				best = at
				best_score = score
		return best
	var nearest: Vector2 = pads[0] if (pads[0] as Vector2).distance_to(MapLayout.HOME) <= (pads[1] as Vector2).distance_to(MapLayout.HOME) else pads[1]
	var toward := (MapLayout.HOME - nearest).normalized()
	for k in range(0, 13):
		for sgn in ([1.0] if k == 0 else [1.0, -1.0]):
			var at := nearest + toward.rotated(deg_to_rad(15.0 * k) * sgn) * dist
			if _near_ok(id, at, dist + 0.01):
				return at
	return Vector2(INF, INF)

func test_the_clutter_cap_at_twenty_positions_over_the_map() -> void:
	await _start()
	_all_max()
	var worst := {"cost": 0, "name": 0, "effect": 0, "warn": 0}
	var n := 0
	for x in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		for z in [-10.0, -3.0, 4.0, 11.0]:
			main.hero.teleport(Vector2(x, z))
			await _settle()
			var t := _visible_text()
			for k in worst:
				worst[k] = maxi(worst[k], t[k].size())
			assert_lte(t.cost.size(), 2, "(%s, %s): at most 2 cost labels" % [x, z])
			assert_lte(t.name.size(), 1, "(%s, %s): at most 1 name" % [x, z])
			assert_lte(t.effect.size(), 1)
			assert_lte(t.warn.size(), 1)
			n += 1
	assert_eq(n, 20)
	gut.p("clutter over 20 positions: most visible %s" % [worst])

## The projected disc (radius `r` m on the ground) of a pad: the rect its ring covers.
func _disc_rect(c: Vector3, r: float, v: View) -> Rect2:
	var pts: Array = []
	for k in 12:
		pts.append(c + Vector3(cos(TAU * k / 12.0), 0.0, sin(TAU * k / 12.0)) * r)
	return v.bounds(pts)

## The rules for one view (the hero on pad `i` of `id`, at `aspect`): returns the findings as [{key, val, text}]: key
## "spot:pad|item|obstacle", val the overlap (w, h) in px rounded up, or (distance in screen-m rounded up to 0.01, 0) for an
## attachment finding. Every rect is built from the real nodes; `gap_out[0]` gets the smallest gap.
func _view_violations(id: String, i: int, aspect: float, rows: Array, gap_out: Array) -> Array:
	var bad: Array = []
	var p: BranchPad = _pads(id)[i]
	var sib: BranchPad = _pads(id)[1 - i]
	var v := View.new(_pad_pos(id, i), aspect)
	var centre := v.pt(p.global_position)
	var ppm := v.px_per_m(p.global_position)
	var mine := _pad_items(p, v)
	var tag := "%.2f %s pad %d" % [aspect, id, i]
	var pk := "%s:%d" % [id, i]
	var add := func(item: String, obstacle: String, val: Vector2, text: String) -> void:
		bad.append({"key": "%s|%s|%s" % [pk, item, obstacle], "val": val, "text": "%s: %s" % [tag, text]})
	if p.stage != BranchPad.ON or mine.size() < 4:
		add.call("stack", "not shown", Vector2.ZERO, "the stack does not show")
		return bad
	# on this pad only the stood option speaks: the sibling shows its rings and nothing else
	if sib.stage != BranchPad.SIBLING_QUIET or not _pad_items(sib, v).is_empty():
		add.call("sibling", "not quiet", Vector2.ZERO, "the sibling is not quiet")
	for e in mine:  # on screen
		var item := String(e[0]).get_slice("/", 1)
		if not v.screen().encloses(e[2]):
			add.call(item, "the screen edge", Vector2.ZERO, "%s %s is not fully on screen" % [e[0], e[2]])
	if not v.screen().has_point(v.pt(sib.global_position)):
		add.call("sibling", "the screen edge", Vector2.ZERO, "the sibling pad is off screen")
	var pr = _preview_rect(p, v)
	if pr != null and not v.screen().encloses(pr):
		add.call("preview", "the screen edge", Vector2.ZERO, "the preview glyph %s is not on screen" % pr)
	for e in mine:  # attachment
		var d := _attach_m(e[2], centre, ppm)
		if d > ATTACH_ON_M:
			add.call(String(e[0]).get_slice("/", 1), "attachment", Vector2(ceilf(d * 100.0) / 100.0, 0.0), "%s stands %.2f screen-m from its pad (limit %.1f)" % [e[0], d, ATTACH_ON_M])
	var others: Array = []  # [what, rect]
	others.append(["the hero", _hero_rect(_pad_pos(id, i), v)])
	for oid in main.world.branch_pads:
		for q: BranchPad in main.world.branch_pads[oid]:
			if q != p and q.body.visible and q.icon.visible:
				others.append(["another pad's glyph " + String(q.name), _node_rect(q.icon, v)])
	if pr != null:
		others.append(["the preview glyph", pr])
	var sp: BuildSpot = main.world.build_spots[id]
	var pips_rect := v.quad(sp.global_position + Vector3(0, sp._pip_y(Balance.data.build.max_level), 0), Vector2(1.1, 0.4))
	var sib_disc := _disc_rect(sib.global_position, MapLayout.BRANCH_PAD_RADIUS, v)
	others.append(["the building's pips", pips_rect])
	assert_false(sp.label.visible, id + ": the building's own MAX label is hidden while its pads show, so nothing of it can collide")
	others.append(["the close-up sign's label", _sign_rect(v)])
	var tsr = _tier_sign_rect(v)
	if tsr != null:
		others.append(["the tier sign's label", tsr])
	others.append(["the HUD's top bar", _hud_rect(v)])
	for l in get_tree().get_nodes_in_group(&"world_labels"):  # the stations' own world labels (Counter, Freezer, ...); not the pads', the tier sign's,
		var lab := l as Label3D  # the close-up sign's or the telegraph rows' (those have their own rects above)
		if lab == null or lab.text == "" or not lab.is_visible_in_tree() or (main.world.tier_sign != null and lab == main.world.tier_sign.label):
			continue
		var skip := lab.get_parent().name == "CloseUpSign"
		var anc: Node = lab.get_parent()
		while anc != null and not skip:
			skip = anc is TelegraphMarker
			anc = anc.get_parent()
		if skip:
			continue
		var mine_own := false
		for oid in main.world.branch_pads:
			for q: BranchPad in main.world.branch_pads[oid]:
				mine_own = mine_own or q.is_ancestor_of(lab)
		if not mine_own:
			var idx := 0  # a stable name: the label's index among its parent's labels (engine names like @Label3D@724 change between runs)
			for lsib in lab.get_parent().get_children():
				if lsib == lab:
					break
				idx += int(lsib is Label3D)
			others.append(["the %s label #%d" % [lab.get_parent().name, idx], _node_rect(lab, v)])
	for row in rows:
		others.append(["the %s telegraph row" % row[0], _row_rect(row[1], v)])
	for e in mine:
		var item := String(e[0]).get_slice("/", 1)
		for o in others:
			if (e[2] as Rect2).intersects(o[1]):
				var ov := (e[2] as Rect2).intersection(o[1])
				add.call(item, o[0], Vector2(ceilf(ov.size.x), ceilf(ov.size.y)), "%s %s overlaps %s %s by %.0f x %.0f px" % [e[0], e[2], o[0], o[1], ov.size.x, ov.size.y])
			gap_out[0] = minf(gap_out[0], _gap(e[2], o[1]))
	if pr != null:  # the preview (glyph and its text) clears the SAME obstacles as the stack (everything in `others` but itself), and the sibling's ring
		var preview_obstacles: Array = others.filter(func(o): return o[0] != "the preview glyph")
		preview_obstacles.append(["the sibling's ring", sib_disc])
		for o in preview_obstacles:
			if (pr as Rect2).intersects(o[1]):
				var ov := (pr as Rect2).intersection(o[1])
				add.call("preview", o[0], Vector2(ceilf(ov.size.x), ceilf(ov.size.y)), "the preview %s overlaps %s %s by %.0f x %.0f px" % [pr, o[0], o[1], ov.size.x, ov.size.y])
	for k in mine.size():
		for l in range(k + 1, mine.size()):
			if (mine[k][2] as Rect2).intersects(mine[l][2]):
				add.call(String(mine[k][0]).get_slice("/", 1), "inside the stack: " + String(mine[l][0]).get_slice("/", 1), Vector2.ONE, "%s overlaps %s inside one stack" % [mine[k][0], mine[l][0]])
	return bad

## Folds the findings of many views into {key: max val}.
func _fold(findings: Array, into: Dictionary) -> void:
	for f in findings:
		var cur: Vector2 = into.get(f.key, Vector2.ZERO)
		into[f.key] = Vector2(maxf(cur.x, f.val.x), maxf(cur.y, f.val.y))

# --- E6 (spec 5.3, D-284.4, D-284.5, D-289.1, D-292.3): the world side of the retuned pads ---------------------------------
# On a pad the world shows the ring, the glyph and the preview shape; the name, the effect and the warning are the HUD card's. The near stage
# shows ring, glyph and cost. ZERO overlaps: no pinned list, no exemption. Every rect is built from the real nodes (the same helpers as above).

## A running game at tier 3 (the same as _start; kept for the tests below).
func _start_on(tier3 := true) -> void:
	await _start(tier3)

## Walks in from outside (the zone arms, so the card shows), then lets the stage settle.
func _walk_onto(id: String, i: int) -> void:
	await _stand_on(id, i)
	await _settle()
	await get_tree().process_frame

## One real LaneCharacterMarker per lane and kind (siege, hare), placed by the production code at the lane's real row anchor:
## [[name, marker]]. Which two lanes show a badge depends on the seed; here every lane can (the worst case for any seed).
func _badge_nodes() -> Array:
	var out: Array = []
	for lane in MapLayout.lanes_for_tier(3):
		var mk: TelegraphMarker = main.world.telegraph_markers[lane]
		# the north badge mirrors to the east side when the run's other badge is on the west lane: both variants stand in the list
		for other in (["west", "east"] if lane == "north" else ["west" if lane != "west" else "north"]):
			for kind in ["siege", "hare"]:
				var b := LaneCharacterMarker.new()
				main.world.add_child(b)
				b.setup(lane)
				b.refresh({"siege": lane, "hare": other} if kind == "siege" else {"siege": other, "hare": lane}, mk.row_anchor())
				out.append(["the %s lane's %s badge (other on %s)" % [lane, kind, other], b])
	return out

func _badge_rect(b: LaneCharacterMarker, v: View) -> Rect2:
	var bb := b.icon.mesh.get_aabb()
	var c := b.icon.global_position + v.xf.basis.x * (bb.get_center().x * b.icon.scale.x) + v.xf.basis.y * (bb.get_center().y * b.icon.scale.y)
	return v.quad(c, Vector2(bb.size.x, bb.size.y) * b.icon.scale.x)

## The card's rect (View coordinates: the origin is the screen centre) for a bottom safe inset. While the REAL card control shows (`main.hud.branch_card`)
## its size and its distance from the bottom of the base view come from the control's own global rect; hidden, from the card's constants.
func _card_rect_v(v: View, inset: float) -> Rect2:
	var size := BranchCard.CARD_SIZE
	var gap := BranchCard.BOTTOM_GAP
	var card: Control = main.hud.branch_card
	if card.visible:
		var r := card.get_global_rect()
		size = r.size
		gap = card.get_viewport().get_visible_rect().size.y - r.end.y
	var bottom := v.half_h() - inset - gap
	return Rect2(-size.x * 0.5, bottom - size.y, size.x, size.y)

## Every obstacle a pad's world item must clear, as [[what, rect]]: the hero's body at `hero_at`, the pips of all nine buildings at level 3
## (and any building MAX label that shows), the close-up sign's label, the stations' own labels (Counter, Freezer, ...), tonight's count rows
## (`rows`), the tier sign's label, the HUD's top bar, every lane-character badge (`badges`), the glyphs and costs of the pads that are not
## in `skip` and show now, and (`card`) the branch card at a 0 and a 34 px bottom inset.
func _world_obstacles(v: View, hero_at: Vector2, rows: Array, badges: Array, skip: Array, card: bool) -> Array:
	var out: Array = []
	out.append(["the hero", _hero_rect(hero_at, v)])
	for id in main.world.build_spots:
		var sp: BuildSpot = main.world.build_spots[id]
		if _visible_pips(id) > 0:  # round 7: a spot's own pips hide while its pad shows a cost; hidden pips are no obstacle (read from the real nodes)
			out.append(["the pips of " + id, v.quad(sp.global_position + Vector3(0, sp._pip_y(Balance.data.build.max_level), 0), Vector2(1.1, 0.4))])
		if sp.label.visible:
			out.append(["the MAX label of " + id, _node_rect(sp.label, v)])
	out.append(["the close-up sign's label", _sign_rect(v)])
	var tsr = _tier_sign_rect(v)
	if tsr != null:
		out.append(["the tier sign's label", tsr])
	out.append(["the HUD's top bar", _hud_rect(v)])
	for l in get_tree().get_nodes_in_group(&"world_labels"):  # the stations' labels; not the pads', the tier sign's, the sign's or the rows' (own rects)
		var lab := l as Label3D
		if lab == null or lab.text == "" or not lab.is_visible_in_tree() or (main.world.tier_sign != null and lab == main.world.tier_sign.label):
			continue
		var skip_it := lab.get_parent().name == "CloseUpSign"
		var anc: Node = lab.get_parent()
		while anc != null and not skip_it:
			skip_it = anc is TelegraphMarker or anc is BranchPad
			anc = anc.get_parent()
		if skip_it:
			continue
		var idx := 0
		for lsib in lab.get_parent().get_children():
			if lsib == lab:
				break
			idx += int(lsib is Label3D)
		out.append(["the %s label #%d" % [lab.get_parent().name, idx], _node_rect(lab, v)])
	for row in rows:
		out.append(["the %s count row" % row[0], _row_rect(row[1], v)])
	for b in badges:
		out.append([b[0], _badge_rect(b[1], v)])
	for oid in main.world.branch_pads:
		for q: BranchPad in main.world.branch_pads[oid]:
			if skip.has(q) or not q.body.visible:
				continue
			if q.icon.visible:
				out.append(["the glyph of " + String(q.name), _node_rect(q.icon, v)])
			if q.cost_label.visible and q.cost_label.text != "":
				out.append(["the cost of " + String(q.name), _node_rect(q.cost_label, v)])
	if card:
		for inset in [0.0, 34.0]:
			out.append(["the branch card (inset %.0f)" % inset, _card_rect_v(v, inset)])
	return out

func _fmt_overlap(a: Rect2, b: Rect2) -> String:
	var ov := a.intersection(b)
	return "%.0f x %.0f px" % [ov.size.x, ov.size.y]

## The ON findings of the hero standing on pad `i` of `id` at `hero_at` (the pad's centre when INF) at `aspect`: [text], empty when clean.
## `armed`: the hero walked in (stage ON: the glyph and the preview shape); else he was placed there (stage UNARMED: the glyph alone, no preview).
## Either way the world shows the glyph and NOTHING else of the pad: no cost, no name, no preview line, no warning.
func _on_findings(id: String, i: int, aspect: float, rows: Array, badges: Array, hero_at := Vector2.INF, armed := true) -> Array:
	var bad: Array = []
	var p: BranchPad = _pads(id)[i]
	var sib: BranchPad = _pads(id)[1 - i]
	if not hero_at.is_finite():
		hero_at = _pad_pos(id, i)
	var v := View.new(hero_at, aspect)
	var tag := "%s %s pad %d hero at %s" % [ASPECT_NAMES[ASPECTS.find(aspect)], id, i, hero_at]
	var want_stage := BranchPad.ON if armed else BranchPad.UNARMED
	if p.stage != want_stage:
		bad.append("%s: the stage is %d, not %d" % [tag, p.stage, want_stage])
		return bad
	if p.cost_label.visible:
		bad.append("%s: the cost shows" % tag)
	if sib.stage != BranchPad.SIBLING_QUIET or not _pad_items(sib, v).is_empty():
		bad.append("%s: the sibling is not quiet" % tag)
	var mine := _pad_items(p, v)
	if mine.map(func(it): return it[1]) != [p.icon]:
		bad.append("%s: the world shows %s, not the glyph alone" % [tag, mine.map(func(it): return it[0])])
	var items: Array = []  # [what, rect]
	for it in mine:
		items.append([String(it[0]).get_slice("/", 1), it[2]])
	var pr = _preview_rect(p, v)
	if not armed:
		if p.preview.visible:
			bad.append("%s: a preview shows on an unarmed pad" % tag)
	elif pr != null:
		items.append(["preview", pr])
	elif p.branch_id != &"longbow":
		bad.append("%s: the preview shape does not show" % tag)
	var obstacles := _on_obstacles(v, hero_at, rows, badges, [p, sib])
	for it in items:
		var r: Rect2 = it[1]
		if not v.screen().encloses(r):
			bad.append("%s: the %s %s is not fully on screen" % [tag, it[0], r])
		for o in obstacles:
			var cls := _obstacle_class(String(o[0]))
			var g := _gap(r, o[1])
			var key := "%s %s pad %d (%s)" % ["ON" if armed else "UNARMED", id, i, "edge" if hero_at.distance_to(_pad_pos(id, i)) > 0.01 else "centre"]
			if cls != "HUD bar" and cls != "card" and cls != "hero":
				_stage_gaps[key] = minf(float(_stage_gaps.get(key, INF)), g)
			var need := 0.0 if cls == "HUD bar" or cls == "card" or cls == "hero" else MIN_GAP_PX  # the HUD bar, the card and the hero (the glyph follows him) keep the zero-overlap rule
			if g < need or (need == 0.0 and r.intersects(o[1])):
				bad.append("%s: the %s %s is %.0f px from %s %s (under %.0f)" % [tag, it[0], r, g, o[0], o[1], need])
	if items.size() == 2 and (items[0][1] as Rect2).intersects(items[1][1]):
		bad.append("%s: the glyph overlaps the preview by %s" % [tag, _fmt_overlap(items[0][1], items[1][1])])
	if not mine.is_empty():
		var h := (mine[0][2] as Rect2).size.y / 1.14
		if h < Balance.ui.branch_pad_icon_min_px:
			bad.append("%s: the glyph is %.1f px, under the %.0f px floor" % [tag, h, Balance.ui.branch_pad_icon_min_px])
	return bad

## What a pad item on an ARMED pad must clear: everything of `_world_obstacles` and the branch card (the card shows exactly then).
func _on_obstacles(v: View, hero_at: Vector2, rows: Array, badges: Array, skip: Array) -> Array:
	return _world_obstacles(v, hero_at, rows, badges, skip, true)

## [[what, rect]] of the obstacles `r` intersects.
func _hits(r: Rect2, obstacles: Array) -> Array:
	var out: Array = []
	for o in obstacles:
		if r.intersects(o[1]):
			out.append(o)
	return out

## The comparison runs for real: a fake item inside the card's rect hits the card at both insets, one just above it hits nothing, and the
## list an ARMED pad is checked against really holds the card (mutation: the card left out of that list; no real pad view comes near it).
func test_flag_on_the_card_is_in_the_armed_pads_obstacle_list_and_a_rect_on_it_is_a_hit() -> void:
	await _start_on()
	_all_max()
	var v := View.new(_pad_pos("fence_n", 1), ASPECTS[1])
	var armed := _on_obstacles(v, _pad_pos("fence_n", 1), [], [], [])
	var names := armed.map(func(o): return String(o[0]))
	assert_true("the branch card (inset 0)" in names and "the branch card (inset 34)" in names, "the armed pad's list holds the card at both insets")
	var card := _card_rect_v(v, 0.0)
	var inside := Rect2(card.position + Vector2(10, 10), Vector2(20, 20))
	var hits := _hits(inside, armed).map(func(o): return String(o[0]))
	assert_true("the branch card (inset 0)" in hits, "a rect on the card hits it")
	assert_eq(_hits(Rect2(card.position - Vector2(0, 300), Vector2(20, 20)), armed).filter(func(o): return String(o[0]).begins_with("the branch card")), [], "a rect well above it does not")
	var unarmed_free := _world_obstacles(v, _pad_pos("fence_n", 1), [], [], [], false).map(func(o): return String(o[0]))
	assert_false("the branch card (inset 0)" in unarmed_free, "the near stage has no card")

func _dump_gaps(title: String) -> void:
	var lines: Array = []
	var worst := INF
	for k in _stage_gaps:
		lines.append("%s: smallest gap %.0f px" % [k, _stage_gaps[k]])
		worst = minf(worst, float(_stage_gaps[k]))
	lines.sort()
	gut.p("%s: smallest of all %.0f px" % [title, worst])
	_dump(title, lines)

func _dump(title: String, lines: Array) -> void:
	gut.p("%s: %d findings" % [title, lines.size()])
	for l in lines:
		gut.p("  " + String(l))

## The hero walks onto each of the 18 pads (armed: the card shows) and stands at its centre and at four edge points (N, E, S, W at 0.8 of the pad's
## radius; a point inside a solid, or on another pad, is skipped, and at least three per pad must be measured): the world shows the glyph (which
## FOLLOWS the hero) and the preview shape, and nothing of them meets the hero, the pips, the labels, the count rows, the badges, the HUD bar, the
## card or another pad's items. Mutation: the glyph anchored to the pad's centre again fails the north edge point (it lands on his head).
func test_flag_on_the_stood_pad_shows_zero_overlaps_at_the_centre_and_four_edge_points_in_every_view() -> void:
	await _start_on()
	_all_max()
	var rows := _all_rows([_plan_boss_on("west"), _plan_boss_on("north"), _plan_boss_on("east"), _plan_boss_on("sw")])
	var badges := _badge_nodes()
	var findings: Array = []
	var views := 0
	var edge_min := 99
	for id in MapLayout.spots_for_tier(3):
		for i in 2:
			await _walk_onto(id, i)
			assert_true(main.hud.branch_card.visible, "%s pad %d: the card shows (armed), so the world may leave the words to it" % [id, i])
			var c := _pad_pos(id, i)
			for a in ASPECTS.size():
				findings.append_array(_on_findings(id, i, ASPECTS[a], rows, badges))
				views += 1
			var edges := 0
			for dir in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
				var pt: Vector2 = c + dir * (0.8 * MapLayout.BRANCH_PAD_RADIUS)
				if _solid_dist(pt) <= MapLayout.HERO_RADIUS or pt.distance_to(_pad_pos(id, 1 - i)) <= MapLayout.BRANCH_PAD_RADIUS:
					continue
				var other_pad := false
				for oid in MapLayout.spots_for_tier(3):
					for k in 2:
						other_pad = other_pad or ((oid != id or k != i) and pt.distance_to(_pad_pos(oid, k)) <= MapLayout.BRANCH_PAD_RADIUS)
				if other_pad:
					continue
				main.hero.global_position = MapLayout.to3(pt)  # not teleport: that would disarm the pad
				await _settle()
				assert_true(main.hud.branch_card.visible, "%s pad %d edge %s: still armed" % [id, i, dir])
				edges += 1
				for a in ASPECTS.size():
					findings.append_array(_on_findings(id, i, ASPECTS[a], rows, badges, pt))
					views += 1
			assert_gte(edges, 3, "%s pad %d: at least three edge points were measured" % [id, i])
			edge_min = mini(edge_min, edges)
	gut.p("ON: %d views (centre and edge points), at least %d edge points per pad" % [views, edge_min])
	_dump_gaps("ON gaps")
	_dump("ON, centre and edge points", findings)
	assert_eq(findings, [], "an empty expected set: no pinned view, no exemption")

## A point the hero can stand on, about `r` m from `c`, on the ray from `c` along the first free direction (of 16); the direction is returned in the second slot.
func _free_point(c: Vector2, r: float) -> Array:
	for k in 16:
		var dir := Vector2.from_angle(TAU * float(k) / 16.0)
		var ok := true
		for rr in [r, Balance.ui.branch_pad_leave_m - 0.05, Balance.ui.branch_pad_leave_m + 0.1]:
			ok = ok and _reachable(c + dir * rr)
		if ok:
			return [c + dir * r, dir]
	return []

## A direction from pad `i` of `id` along which the hero stands on a free point at 1 to 6 m from it and is, at every one of them, farther than the keep distance from the spot's OTHER pad (so this pad alone decides the stars).
func _lone_ray(id: String, i: int) -> Vector2:
	var c := _pad_pos(id, i)
	for k in 16:
		var dir := Vector2.from_angle(TAU * float(k) / 16.0)
		var ok := true
		for rr in [0.0, 1.0, 2.0, 3.0, 3.4, 4.5, 6.0]:
			ok = ok and (rr == 0.0 or _reachable(c + dir * rr))
			ok = ok and (c + dir * rr).distance_to(_pad_pos(id, 1 - i)) > Balance.ui.branch_pad_leave_m + 0.3
		if ok:
			return dir
	return Vector2.ZERO

## The pips of a spot as the real nodes show them now: how many of its stars are visible.
func _visible_pips(id: String) -> int:
	var n := 0
	for pip in (main.world.build_spots[id] as BuildSpot)._pips:
		n += int((pip as LevelPip).visible)
	return n

## Author's decision (task 14 round 7): a building's level pips HIDE while one of its own pads shows a cost (NEAR or ON) and come back with the cost.
## Catches: pips that never hide; pips of ANOTHER spot hidden; pips that stay hidden after the hero leaves (at the leave distance) or after the purchase.
func test_flag_on_a_spots_level_pips_hide_while_its_own_pad_shows_a_cost_and_return_with_it() -> void:
	await _start_on()
	_all_max()
	var c := _pad_pos("tower_nw", 0)
	_near_step(Vector2(15.0, 8.0))
	for id in MapLayout.spots_for_tier(3):
		assert_eq(_visible_pips(id), 3, "%s: FAR from every pad the three stars show" % id)
	var fp := _free_point(c, 1.6)
	assert_false(fp.is_empty(), "setup: a free ray from the pad")
	var near_at: Vector2 = fp[0]
	_near_step(near_at)
	assert_eq(_pads("tower_nw")[0].stage, BranchPad.NEAR, "setup: the pad shows its cost")
	assert_eq(_visible_pips("tower_nw"), 0, "the pad of the SAME spot is NEAR: its stars are hidden")
	assert_eq(_visible_pips("tower_ne"), 3, "another spot's stars are not touched")
	assert_eq(_visible_pips("fence_w"), 3, "another spot's stars are not touched")
	# the keep band: still shown at the leave distance, back once the hero is past it
	var dir: Vector2 = fp[1]
	_near_step(c + dir * (Balance.ui.branch_pad_leave_m - 0.05))
	assert_eq(_pads("tower_nw")[0].stage, BranchPad.NEAR, "setup: inside the keep band the cost stays")
	assert_eq(_visible_pips("tower_nw"), 0, "hidden while the cost is shown")
	_near_step(c + dir * (Balance.ui.branch_pad_leave_m + 0.1))
	assert_ne(_pads("tower_nw")[0].stage, BranchPad.NEAR, "setup: past the leave distance the cost hides")
	assert_eq(_visible_pips("tower_nw"), 3, "the stars are back with the cost hidden")
	# a purchase: the pad disappears while NEAR
	_near_step(near_at)
	assert_eq(_visible_pips("tower_nw"), 0, "setup: hidden again")
	GameState.gold = _cost("tower_nw")
	assert_gt(GameState.pay_into_branch("tower_nw", &"volley", _cost("tower_nw")), 0)
	assert_false(_pads("tower_nw")[0].is_shown(), "setup: the pads are gone")
	assert_eq(_visible_pips("tower_nw"), 3, "after the purchase the pad is gone and the stars are back")

## Real physics ticks: the hero walks from FAR onto tower_nw's pad a and back out. From the first tick any own pad is not FAR until every own pad is FAR again the
## stars are hidden on EVERY tick (the walk-in passes NEAR -> UNARMED -> ON; a rule that covers only NEAR or ON flashes the stars for one tick), and they never toggle in between.
## Catches: UNARMED not covering (one-tick flash); stars returning while the hero stands on the pad.
func test_flag_on_the_pips_stay_hidden_on_every_tick_of_a_walk_in_and_out() -> void:
	await _start_on()
	_all_max()
	var id := "fence_sw"  # its two pads are 5.3 m apart: the sibling is out of reach, so one pad alone decides the stars
	var pad_a: BranchPad = _pads(id)[0]
	var c := _pad_pos(id, 0)
	var dir := _lone_ray(id, 0)
	assert_ne(dir, Vector2.ZERO, "setup: a free ray from the pad")
	main.hero.teleport(c + dir * 6.0)
	await _settle()
	assert_eq(_visible_pips(id), 3, "setup: far away the stars show")
	var step: float = main.hero.move_speed() / 60.0
	var log: Array = []  # [tick, stages of both pads, stars shown]
	var seen_stages := {}
	var in_use_once := false
	# in: walk to the pad's centre; out: walk back to 6 m
	for leg in 2:
		var target := c if leg == 0 else c + dir * 6.0
		for t in 900:
			var d: Vector2 = target - main.hero.xz()
			if d.length() < 0.05:
				break
			main.hero.input.set_move((d / step).limit_length(1.0))
			await get_tree().physics_frame  # one tick: what is read is the state the last tick left (pads, then zones, have run)
			var stages: Array = _pads(id).map(func(q): return q.stage)
			seen_stages[stages[0]] = true
			var used: bool = stages.any(func(st): return st != BranchPad.FAR)
			in_use_once = in_use_once or used
			log.append([used, _visible_pips(id), stages])
	main.hero.input.set_move(Vector2.ZERO)
	assert_true(in_use_once, "setup: the walk made a pad leave FAR")
	assert_true(seen_stages.has(BranchPad.NEAR) and seen_stages.has(BranchPad.ON), "setup: it passed NEAR and ON (stages %s)" % [seen_stages.keys()])
	for k in log.size():
		var used: bool = log[k][0]
		assert_eq(log[k][1], 0 if used else 3, "tick %d: stages %s: the stars %s" % [k, log[k][2], "hidden while a pad is in use" if used else "show with every own pad FAR"])
	var toggles := 0
	for k in range(1, log.size()):
		toggles += int(log[k][1] != log[k - 1][1])
	assert_eq(toggles, 2, "one hide on the way in and one show on the way out; no toggle in between")

## The walk-in tick itself (the pad ran, its zone did not): UNARMED, and the stars are already hidden.
func test_flag_on_the_pips_are_hidden_in_the_unarmed_walk_in_tick() -> void:
	await _start_on()
	_all_max()
	var c := _pad_pos("fence_sw", 0)
	var p: BranchPad = _pads("fence_sw")[0]
	main.hero.teleport(c + _lone_ray("fence_sw", 0) * 3.0)
	await _settle()
	main.hero.global_position = MapLayout.to3(c + Vector2(0, 0.0))
	BranchPad._cache_frame = -1
	p._physics_process(0.0)
	assert_eq(p.stage, BranchPad.UNARMED, "setup: the walk-in tick")
	assert_eq(_visible_pips("fence_sw"), 0, "UNARMED hides the stars too")

## The pads leave the map without a stage change of their own: night (pads are not shown at night), a tier drop (the world frees them), a new game, a load. The stars must be
## right afterwards: visible with no pad shown, hidden again after a load that puts the hero NEAR a pad (one tick).
func test_flag_on_the_pips_follow_night_a_tier_drop_a_new_game_and_a_load_while_the_hero_is_near_a_pad() -> void:
	await _start_on()
	_all_max()
	var c := _pad_pos("tower_nw", 0)
	var near_at: Vector2 = _free_point(c, 1.6)[0]
	main.hero.teleport(near_at)
	await _settle()
	assert_eq(_pads("tower_nw")[0].stage, BranchPad.NEAR, "setup: NEAR")
	assert_eq(_visible_pips("tower_nw"), 0, "setup: hidden")
	# night starts while he stands there: no pad is shown at night, the stars show all night
	pc.debug_skip_to_night()
	assert_eq(_visible_pips("tower_nw"), 3, "night: the stars are back at once")
	await _settle()
	assert_eq(_visible_pips("tower_nw"), 3, "night: and stay all night")
	pc.debug_skip_to_day()
	await _settle()
	assert_eq(_visible_pips("tower_nw"), 0, "dawn: he is still there, the pad is in use again")
	# a load with the hero near: the pads are made again, the stars follow within one tick
	var d := GameState.to_dict()
	GameState.new_game(3)
	await get_tree().physics_frame
	assert_eq(main.world.branch_pads.size(), 0, "a new game: tier 1, no pads")
	for id in main.world.build_spots:
		assert_false((main.world.build_spots[id] as BuildSpot)._pips_covered, "%s: nothing covers its stars after a new game" % id)
	GameState.from_dict(d)
	main.hero.teleport(near_at)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(_pads("tower_nw")[0].stage, BranchPad.NEAR, "setup: the reloaded pad is NEAR")
	assert_eq(_visible_pips("tower_nw"), 0, "a load with the hero NEAR: hidden after one tick")
	assert_eq(_visible_pips("tower_ne"), 3, "another spot's stars show")
	# a tier drop while NEAR frees the pads
	GameState.debug_set_tier(2, GameState.day)
	await get_tree().physics_frame
	assert_eq(main.world.branch_pads.size(), 0, "setup: a tier drop frees the pads")
	assert_eq(_visible_pips("tower_nw"), 3, "the pads are freed while NEAR: the stars are back")

## FAR stage: the stars show, so a FAR glyph must keep MIN_GAP_PX from the pips of every building (the same 1.1 x 0.4 m star row the other scans use), over every
## pad, three aspects, the camera on the pad (the gap is a fixed offset in the world, so only the scale of the view changes it).
func test_flag_on_a_far_glyph_keeps_eight_px_from_every_buildings_stars() -> void:
	await _start_on()
	_all_max()
	main.hero.teleport(Vector2(15.0, 8.0))
	await _settle()
	var findings: Array = []
	var smallest := INF
	var seen := 0
	for id in MapLayout.spots_for_tier(3):
		for i in 2:
			var p: BranchPad = _pads(id)[i]
			assert_eq(p.stage, BranchPad.FAR, "setup: %s pad %d is FAR" % [id, i])
			for a in ASPECTS.size():
				var v := View.new(_pad_pos(id, i), ASPECTS[a])
				var g := _node_rect(p.icon, v)
				for oid in main.world.build_spots:
					var sp: BuildSpot = main.world.build_spots[oid]
					if _visible_pips(oid) == 0 or sp.global_position.distance_to(p.global_position) > 12.0:
						continue
					seen += 1
					var gap := _gap(g, v.quad(sp.global_position + Vector3(0, sp._pip_y(Balance.data.build.max_level), 0), Vector2(1.1, 0.4)))
					smallest = minf(smallest, gap)
					if gap < MIN_GAP_PX:
						findings.append("%s %s pad %d: the FAR glyph is %.1f px from the stars of %s" % [ASPECT_NAMES[a], id, i, gap, oid])
	gut.p("FAR glyph vs stars: %d pairs, smallest gap %.1f px" % [seen, smallest])
	_dump("FAR glyph vs stars", findings)
	assert_gt(seen, 18, "setup: the pairs were measured")
	assert_eq(findings, [], "every FAR glyph keeps 8 px from every visible star row")

## ON hides them too (the hero stands on the pad); leaving brings them back. Catches a rule that covers NEAR only.
func test_flag_on_a_spots_level_pips_stay_hidden_while_the_hero_stands_on_its_pad() -> void:
	await _start_on()
	_all_max()
	await _walk_onto("tower_ne", 0)
	assert_eq(_pads("tower_ne")[0].stage, BranchPad.ON, "setup: on the pad")
	assert_eq(_visible_pips("tower_ne"), 0, "ON: hidden")
	assert_eq(_visible_pips("tower_nw"), 3, "another spot's stars show")
	_near_step(Vector2(15.0, 8.0))
	assert_eq(_visible_pips("tower_ne"), 3, "back once he is away")

## Near stage, per pad. EVERY pad is measured over EVERY reachable view in which it shows its cost: the hero on a 0.5 m grid within
## branch_pad_near_m of the pad (arriving from far away), and the keep band out to branch_pad_leave_m (the hero first inside the reach, then walked
## outward in 0.25 m steps along the line from the pad, so the hysteresis keeps the cost shown). Reachable = off every solid by his radius + 0.05, on
## no pad, inside the map. At each such point, at 9:21, 9:16 and 16:9, the pad that shows its cost is a block (glyph over cost) that is fully on
## screen, keeps the 28 px floors and intersects NONE of: the hero, the pips (and MAX labels) of all nine buildings, the close-up sign's label, the
## station labels, tonight's count rows (four plans), the tier sign's label, the HUD's top bar, every lane badge, the other pads' glyphs and costs, and
## the sibling's block. Empty expected set: no pinned view, no exemption. The obstacles are the real nodes' rects, cached once (they do not depend on
## where the hero stands); the cache is compared with `_world_obstacles` (the stood-pad tests' list) at the first view of every pad.
## Mutations: a pad moved back / an offset removed (tower_ne b), the old three-point sampling (it never saw tower_ne b's pips), a wider block.
func test_flag_on_the_near_stage_shows_zero_overlaps_for_every_pad_over_its_reachable_views() -> void:
	var t0 := Time.get_ticks_msec()
	await _start_on()
	_all_max()
	var rows := _all_rows([_plan_boss_on("west"), _plan_boss_on("north"), _plan_boss_on("east"), _plan_boss_on("sw")])
	var badges := _badge_nodes()
	var statics := _static_obstacles(rows, badges)
	var res := _near_scan(MapLayout.spots_for_tier(3), range(ASPECTS.size()), statics, rows, badges, true)
	_dump("NEAR per pad (points measured, smallest gap in px to each obstacle class; negative = overlap)", res.report)
	var lines: Array = []
	for k in res.findings:
		lines.append("%s  [%d times, worst shortfall %.0f px, hero at %s]" % [k, res.findings[k][0], res.findings[k][1], res.findings[k][3]])
	lines.sort()
	_dump("NEAR scan findings", lines)
	gut.p("NEAR scan: %d..%d points per pad, %d ms; smallest tether: %.1f px wide (gold line), %.1f px long; smallest gap to any obstacle or block: %.1f px" % [res.min_pts, res.max_pts, Time.get_ticks_msec() - t0, _tether_min[0], _tether_min[1], res.min_gap])
	for id in MapLayout.spots_for_tier(3):
		for i in 2:
			assert_true(res.seen_near.has("%s:%d" % [id, i]), "%s pad %d was measured in the near stage at least once" % [id, i])
		if res.both_possible.has(id):
			assert_true(res.both_seen.has(id), "%s: both pads can be in reach, so a both-in-reach view was measured" % id)
	assert_eq(lines, [], "an empty expected set: no pinned view, no exemption (the hero is drawn in front: test_flag_on_the_hero_and_his_pile_write_depth_after_the_pad_labels_and_rings, tools/check_hero_front.gd)")

## The scan behind the test above (also used by tools/probes): {findings, report, seen_near, both_possible, both_seen, min_pts, max_pts}. `aspect_ids`:
## indices into ASPECTS. `oracle`: compare the cached obstacle list with `_world_obstacles` at the first view of every pad.
func _near_scan(spots: Array, aspect_ids: Array, statics: Array, rows: Array, badges: Array, oracle: bool, step_spots := []) -> Dictionary:
	var all_pads: Array = []
	for id in MapLayout.spots_for_tier(3):
		all_pads.append_array(_pads(id))
	var res := {"findings": {}, "report": [], "seen_near": {}, "both_possible": {}, "both_seen": {}, "min_pts": 100000, "max_pts": 0, "min_gap": INF}
	var findings: Dictionary = res.findings
	var near_m: float = Balance.ui.branch_pad_near_m
	var leave_m: float = Balance.ui.branch_pad_leave_m
	for id in spots:
		for i in 2:
			var p: BranchPad = _pads(id)[i]
			var sib: BranchPad = _pads(id)[1 - i]
			var c := _pad_pos(id, i)
			var gaps := {}  # class -> smallest gap (px) of an item to it
			var pts := 0
			var views := 0
			var checked_oracle := not oracle
			for xi in range(-9, 10):
				for zi in range(-9, 10):
					var at := c + Vector2(xi, zi) * 0.5
					var d := at.distance_to(c)
					if d > leave_m or not _reachable(at):
						continue
					if d <= near_m and at.distance_to(_pad_pos(id, 1 - i)) <= near_m:
						res.both_possible[id] = true
					# arrive: from far away inside the reach, or (the keep band) from inside it, walking out along the line from the pad
					_near_step(Vector2(15.0, 8.0), step_spots)
					if d > near_m:
						var dir := (at - c).normalized()
						var r := 3.0
						while r < d - 0.001:
							_near_step(c + dir * r, step_spots)
							r += 0.25
					_near_step(at, step_spots)
					if BranchPad.focus_spot() == id and d <= near_m and p.stage != BranchPad.NEAR:
						_add_finding(findings, "%s pad %d at %s: %.2f m away in the focus spot, stage %d, not NEAR" % [id, i, at, d, p.stage], Vector2.ZERO)
					if p.stage != BranchPad.NEAR or not p.cost_label.visible:
						continue
					res.seen_near["%s:%d" % [id, i]] = true
					pts += 1
					var sib_near := sib.stage == BranchPad.NEAR and sib.cost_label.visible
					if sib_near:
						res.both_seen[id] = true
					for a in aspect_ids:
						var v := View.new(at, ASPECTS[a])
						var tag := "%s %s pad %d" % [ASPECT_NAMES[a], id, i]
						var items := _pad_items(p, v)
						if items.map(func(it): return it[1]) != [p.icon, p.cost_label]:
							_add_finding(findings, "%s: shows %s, not a glyph and a cost" % [tag, items.map(func(it): return it[0])], Vector2.ZERO)
							continue
						views += 1
						var obstacles := _near_obstacles(statics, v, at, c, p, all_pads, NEAR_CULL_M)
						var block: Rect2 = (items[0][2] as Rect2).merge(items[1][2])
						if not checked_oracle:
							checked_oracle = true
							_assert_cache_matches(obstacles, statics, v, at, c, p, rows, badges, all_pads, block)
						for it in items:
							if not v.screen().encloses(it[2]):
								var s := v.screen()
								var br: Rect2 = it[2]
								_add_finding(findings, "%s: the %s is not fully on screen" % [tag, String(it[0]).get_slice("/", 1)], Vector2(maxf(maxf(s.position.x - br.position.x, br.end.x - s.end.x), 0.0), 0.0))
						if (items[0][2] as Rect2).size.y / 1.14 < Balance.ui.branch_pad_icon_min_px:
							_add_finding(findings, "%s: the glyph is under its floor" % tag, Vector2.ZERO)
						if _px_h(p.cost_label.global_position, float(p.cost_label.font_size) * p.cost_label.pixel_size, v) < Balance.ui.branch_pad_label_min_px:
							_add_finding(findings, "%s: the cost is under its floor" % tag, Vector2.ZERO)
						for it in items:
							for o in obstacles:
								var cls := _obstacle_class(String(o[0]))
								if cls == "hero":
									continue  # D-294.8: the hero is drawn in front of every pad label (the render check and the priorities below), not a rect rule
								var g := _gap(it[2], o[1])
								gaps[cls] = minf(float(gaps.get(cls, INF)), g)
								res.min_gap = minf(res.min_gap, g)
								if g < MIN_GAP_PX:
									_add_finding(findings, "%s: the %s is under %.0f px from %s" % [tag, String(it[0]).get_slice("/", 1), MIN_GAP_PX, o[0]], Vector2(MIN_GAP_PX - g, MIN_GAP_PX - g), at)
						if _own_overlap_m(p) > 0.06:  # a cost never sits on its own glyph (boxes in metres on the screen; the layout's boxes are a little larger than the ink)
							_add_finding(findings, "%s: the cost overlaps its own glyph" % tag, Vector2.ONE, at)
						_check_tether(p, v, at, obstacles, findings, tag)
						if sib_near:
							var sitems := _pad_items(sib, v)
							var bg := INF
							for it in items:
								for sit in sitems:
									bg = minf(bg, _gap(it[2], sit[2]))
							gaps["sibling block"] = minf(float(gaps.get("sibling block", INF)), bg)
							res.min_gap = minf(res.min_gap, bg)
							if bg < MIN_GAP_PX:
								_add_finding(findings, "%s: the two blocks are under %.0f px apart" % [tag, MIN_GAP_PX], Vector2(MIN_GAP_PX - bg, MIN_GAP_PX - bg), at)
			res.min_pts = mini(res.min_pts, pts)
			res.max_pts = maxi(res.max_pts, pts)
			var gl: Array = []
			for k in gaps:
				gl.append("%s %.0f" % [k, float(gaps[k])])
			gl.sort()
			res.report.append("%s pad %d: %d points, %d views; smallest gap px: %s" % [id, i, pts, views, ", ".join(gl)])
	return res

## How far (metres on the screen, camera plane) the cost's layout box reaches into the glyph's layout box; 0 when they do not overlap.
func _own_overlap_m(p: BranchPad) -> float:
	var xf := CameraMath.camera_transform(Vector2.ZERO, Balance.ui)
	var rel := p.cost_label.global_position - p.icon.global_position
	var d := Vector2(rel.dot(xf.basis.x), rel.dot(xf.basis.y))
	var half := (BranchPad.glyph_box(p.icon) + p._cost_box()) * 0.5
	return maxf(0.0, minf(half.x - absf(d.x), half.y - absf(d.y)))

## D-294.8: the glyph stays INSIDE its ring (all four corners of its box inside the ring's ellipse on the screen), and a cost reads as its pad's: a cost whose nearest edge is within
## 0.5 m (screen metres) of its pad's centre needs nothing; one beyond it shows the TETHER, a light line with an ink edge from the cost's box to the RING's edge: its ring end lies
## within 0.15 m of the ring's edge, its cost end touches the cost's label rect, it is at least TETHER_MIN_W_PX wide and TETHER_MIN_LEN_PX long at 720x1280, and it keeps MIN_GAP_PX from
## every obstacle but the hero (drawn in front), its own ring and its own cost.
const TETHER_MIN_W_PX := 7.5  # 3 px at the 40% scale
const TETHER_MIN_LEN_PX := 20.0
## The smallest tether measured in the last scan: [width px, length px] (reported by the near-stage test).
var _tether_min := [INF, INF]
func _check_tether(p: BranchPad, v: View, at: Vector2, obstacles: Array, findings: Dictionary, tag: String) -> void:
	var ppm := v.px_per_m(p.global_position)
	var centre := v.pt(p.global_position)
	var ring := PackedVector2Array()
	for k in 48:
		var ang := TAU * float(k) / 48.0
		ring.append(v.pt(p.global_position + Vector3(cos(ang), 0.0, sin(ang)) * MapLayout.BRANCH_PAD_RADIUS))
	var gr := _node_rect(p.icon, v)
	for corner in [gr.position, Vector2(gr.end.x, gr.position.y), gr.end, Vector2(gr.position.x, gr.end.y)]:
		if not Geometry2D.is_point_in_polygon(corner, ring):
			_add_finding(findings, "%s: the glyph is not inside its ring" % tag, Vector2.ONE, at)

			break
	var cr := _node_rect(p.cost_label, v)
	# the distance rule is measured in the world, in metres ON THE SCREEN (the camera's plane), so it does not depend on where the pad stands in the view:
	# the cost's nearest edge from the pad's centre, from the real label's position and the box its layout uses ("000")
	var xf := CameraMath.camera_transform(Vector2.ZERO, Balance.ui)
	var rel := p.cost_label.global_position - p.global_position
	var cpos := Vector2(rel.dot(xf.basis.x), rel.dot(xf.basis.y))
	var cbox: Vector2 = p._cost_box()
	var dist := Vector2(maxf(absf(cpos.x) - cbox.x * 0.5, 0.0), maxf(absf(cpos.y) - cbox.y * 0.5, 0.0)).length()
	var shown: bool = p.tether != null and p.tether.visible and p.tether_ink.visible and p.tether_ends.size() == 2
	if dist > BranchPad.TETHER_FROM_M + 0.01 and not shown:
		_add_finding(findings, "%s: the cost's nearest edge stands %.2f m from its pad and shows no tether" % [tag, dist], Vector2.ONE, at)
	if not shown:
		return
	var tip := v.pt(p.global_position + p.tether_ends[0])
	var tail := v.pt(p.global_position + p.tether_ends[1])
	var len_px := tip.distance_to(tail)
	_tether_min[1] = minf(_tether_min[1], len_px)
	if len_px < TETHER_MIN_LEN_PX:
		_add_finding(findings, "%s: the tether is %.0f px long (under %.0f)" % [tag, len_px, TETHER_MIN_LEN_PX], Vector2.ONE, at)
	# the width is the GOLD line's (the light part the eye reads), not the ink strip's, which is wider by its two edges
	var gold_v: PackedVector3Array = p.tether.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var width_px := v.pt(p.global_position + gold_v[0]).distance_to(v.pt(p.global_position + gold_v[1]))
	_tether_min[0] = minf(_tether_min[0], width_px)
	if width_px < TETHER_MIN_W_PX:
		_add_finding(findings, "%s: the tether is %.1f px wide (under %.1f)" % [tag, width_px, TETHER_MIN_W_PX], Vector2.ONE, at)
	var tq := Vector2(clampf(tail.x, cr.position.x, cr.end.x), clampf(tail.y, cr.position.y, cr.end.y))
	if tail.distance_to(tq) > 0.15 * ppm:
		_add_finding(findings, "%s: the tether's cost end is %.0f px from the cost" % [tag, tail.distance_to(tq)], Vector2.ONE, at)
	var ring_gap := INF
	for k in ring.size():
		var a0 := ring[k]
		var a1 := ring[(k + 1) % ring.size()]
		ring_gap = minf(ring_gap, tip.distance_to(Geometry2D.get_closest_point_to_segment(tip, a0, a1)))
	if ring_gap > 0.15 * ppm:
		_add_finding(findings, "%s: the tether's ring end is %.0f px from the ring's edge (over 0.15 m)" % [tag, ring_gap], Vector2.ONE, at)
	if tip.distance_to(centre) >= tail.distance_to(centre):
		_add_finding(findings, "%s: the tether points away from the pad" % tag, Vector2.ONE, at)
	for k in 13:
		var q := tip.lerp(tail, float(k) / 12.0)
		for o in obstacles:
			if _obstacle_class(String(o[0])) != "hero" and (o[1] as Rect2).grow(MIN_GAP_PX + width_px * 0.5).has_point(q):
				_add_finding(findings, "%s: the tether is within %.0f px of %s" % [tag, MIN_GAP_PX, o[0]], Vector2.ONE, at)

## A point the hero can stand on: off every solid by his radius + 0.05, on no pad, inside the map.
func _reachable(at: Vector2) -> bool:
	return at.x > -16.0 and at.x < 16.0 and at.y > -19.0 and at.y < 14.0 and _solid_dist(at) > MapLayout.HERO_RADIUS + 0.05 \
			and _min_pad_dist(at) > MapLayout.BRANCH_PAD_RADIUS

func _min_pad_dist(at: Vector2) -> float:
	var best := INF
	var table := MapLayout.BRANCH_PADS
	for oid in table:
		for pp in table[oid]:
			best = minf(best, at.distance_to(pp))
	return best

## The hero is put at `at` and every pad runs its frame (the shared focus is recomputed): no physics frames, so a scan of thousands of points stays fast.
func _near_step(at: Vector2, only_spots := []) -> void:
	main.hero.global_position = MapLayout.to3(at)
	BranchPad._cache_frame = -1
	for id in (only_spots if not only_spots.is_empty() else MapLayout.spots_for_tier(3)):
		for q: BranchPad in _pads(id):
			q._physics_process(0.0)

func _add_finding(findings: Dictionary, text: String, size: Vector2, hero := Vector2.INF) -> void:
	if not findings.has(text):
		findings[text] = [0, 0.0, 0.0, hero]
	findings[text][0] += 1
	if size.x * size.y >= maxf(findings[text][1] * findings[text][2], 0.0):
		findings[text][3] = hero  # the hero point of the worst overlap
	findings[text][1] = maxf(findings[text][1], size.x)
	findings[text][2] = maxf(findings[text][2], size.y)

static func _obstacle_class(what: String) -> String:
	if what == "the hero":
		return "hero"
	if what.begins_with("the pips of"):
		return "pips"
	if what.begins_with("the MAX label"):
		return "MAX labels"
	if what.contains("close-up"):
		return "close-up sign"
	if what.contains("tier sign"):
		return "tier sign"
	if what.contains("HUD"):
		return "HUD bar"
	if what.ends_with("count row"):
		return "count rows"
	if what.contains("badge"):
		return "lane badges"
	if what.begins_with("the glyph of") or what.begins_with("the cost of"):
		return "other pads"
	if what.begins_with("the branch card"):
		return "card"
	return "station labels"

## The obstacles that do not move with the hero, as [{name, at (a world point), quads: [[centre, size m]], screen (the HUD bar)}]. The quads come from
## the real nodes (the billboards face the camera, whose basis is the same for every focus).
func _static_obstacles(rows: Array, badges: Array) -> Array:
	var basis := CameraMath.camera_transform(Vector2.ZERO, Balance.ui).basis
	var out: Array = []
	for id in main.world.build_spots:
		var sp: BuildSpot = main.world.build_spots[id]
		var pips := sp.global_position + Vector3(0, sp._pip_y(Balance.data.build.max_level), 0)
		out.append({"name": "the pips of " + id, "at": pips, "quads": [[pips, Vector2(1.1, 0.4)]], "spot": id})
		if sp.label.visible:
			out.append({"name": "the MAX label of " + id, "at": sp.label.global_position, "quads": [_label_quad(sp.label, basis)]})
	var sw := _font_w(tr("Close up"), 36) + 0.08
	out.append({"name": "the close-up sign's label", "at": MapLayout.to3(MapLayout.SIGN, 1.95), "quads": [[MapLayout.to3(MapLayout.SIGN, 1.95), Vector2(sw, 0.36 * 1.3)]]})
	var ts: TierSign = main.world.tier_sign
	if ts != null and ts.label.visible:
		out.append({"name": "the tier sign's label", "at": ts.label.global_position, "quads": [_label_quad(ts.label, basis)]})
	out.append({"name": "the HUD's top bar", "at": Vector3.INF, "quads": []})
	for l in get_tree().get_nodes_in_group(&"world_labels"):
		var lab := l as Label3D
		if lab == null or lab.text == "" or not lab.is_visible_in_tree() or (ts != null and lab == ts.label):
			continue
		var skip_it := lab.get_parent().name == "CloseUpSign"
		var anc: Node = lab.get_parent()
		while anc != null and not skip_it:
			skip_it = anc is TelegraphMarker or anc is BranchPad
			anc = anc.get_parent()
		if skip_it:
			continue
		var idx := 0
		for lsib in lab.get_parent().get_children():
			if lsib == lab:
				break
			idx += int(lsib is Label3D)
		out.append({"name": "the %s label #%d" % [lab.get_parent().name, idx], "at": lab.global_position, "quads": [_label_quad(lab, basis)]})
	for row in rows:
		out.append({"name": "the %s count row" % row[0], "at": (row[1][0] as Array)[0], "quads": row[1]})
	for b in badges:
		var ic: MeshInstance3D = (b[1] as LaneCharacterMarker).icon
		var bb := ic.mesh.get_aabb()
		var cc := ic.global_position + basis.x * (bb.get_center().x * ic.scale.x) + basis.y * (bb.get_center().y * ic.scale.y)
		out.append({"name": b[0], "at": cc, "quads": [[cc, Vector2(bb.size.x, bb.size.y) * ic.scale.x]]})
	return out

func _label_quad(l: Label3D, basis: Basis) -> Array:
	var b := BranchPad.text_box(l)
	var c := l.global_position
	if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT:
		c += basis.x * b.x * 0.5
	return [c, b]

## [[what, rect]] for one view of a pad at `c` with the hero at `at`: the cached obstacles within reach of the pad (a block is under 2 m wide, so
## anything over NEAR_CULL_M metres away cannot touch it), the hero, and the other pads' glyphs and costs as they show now.
const NEAR_CULL_M := 12.0
func _near_obstacles(statics: Array, v: View, at: Vector2, c: Vector2, p: BranchPad, all_pads: Array, cull: float) -> Array:
	var out: Array = [["the hero", _hero_rect(at, v)]]
	for o in statics:
		if o.name == "the HUD's top bar":
			out.append([o.name, _hud_rect(v)])
			continue
		if o.has("spot") and _visible_pips(o.spot) == 0:
			continue  # round 7: the real pips of that spot are hidden in this view (its pad shows a cost): no obstacle
		var ap: Vector3 = o.at
		if Vector2(ap.x - c.x, ap.z - c.y).length() > cull:
			continue
		var r := Rect2()
		var first := true
		for q in o.quads:
			var qr := v.quad(q[0], q[1])
			r = qr if first else r.merge(qr)
			first = false
		out.append([o.name, r])
	for q: BranchPad in all_pads:
		if q == p or not q.body.visible:
			continue
		if q.icon.visible:
			out.append(["the glyph of " + String(q.name), _node_rect(q.icon, v)])
		if q.cost_label.visible and q.cost_label.text != "":
			out.append(["the cost of " + String(q.name), _node_rect(q.cost_label, v)])
	return out

## The cached list gives the same obstacles and rects as `_world_obstacles` (the other tests' list) for this view, exactly (the pad's own items and the
## other pads aside: both lists hold the other pads'), and everything the culling dropped is far from the block.
func _assert_cache_matches(culled: Array, statics: Array, v: View, at: Vector2, c: Vector2, p: BranchPad, rows: Array, badges: Array, all_pads: Array, block: Rect2) -> void:
	var full := _near_obstacles(statics, v, at, c, p, all_pads, 1.0e9)
	var want: Array = []
	for o in _world_obstacles(v, at, rows, badges, [p], false):
		want.append("%s %s" % [o[0], o[1]])
	var got: Array = []
	for o in full:
		got.append("%s %s" % [o[0], o[1]])
	want.sort()
	got.sort()
	assert_eq(got, want, "the cached obstacles are the full list's")
	for o in full:
		if not culled.any(func(k): return k[0] == o[0] and k[1] == o[1]):
			assert_gt(_gap(block, o[1]), 50.0, "%s was culled and is far from the block" % o[0])

## The lane-character badges against the pads: from the 18 pad views (the stood glyph and preview, and every glyph that shows) and from each
## lane's attack zone (the pads' glyphs and costs as they show there). The north badge met fence_n's glyph in 36 own-zone views.
func test_flag_on_no_lane_badge_overlaps_a_pad_item_from_the_pad_views_or_the_zones() -> void:
	await _start_on()
	_all_max()
	var badges := _badge_nodes()
	var findings: Array = []
	for id in MapLayout.spots_for_tier(3):
		for i in 2:
			await _walk_onto(id, i)
			var p: BranchPad = _pads(id)[i]
			for a in ASPECTS.size():
				var v := View.new(_pad_pos(id, i), ASPECTS[a])
				var items := _pad_items(p, v)
				var pr = _preview_rect(p, v)
				if pr != null:
					items.append(["preview", null, pr])
				for it in items:
					for b in badges:
						var br := _badge_rect(b[1], v)
						if _gap(it[2], br) < MIN_GAP_PX:
							findings.append("%s %s pad %d: %s is %.0f px from %s (under %.0f)" % [ASPECT_NAMES[a], id, i, it[0], _gap(it[2], br), b[0], MIN_GAP_PX])
	for lane in MapLayout.lanes_for_tier(3):
		var zone := MapLayout.zone_rect(lane).get_center()
		main.hero.teleport(Vector2(15.0, 8.0))
		await _settle()
		main.hero.teleport(zone)
		await _settle()
		for a in ASPECTS.size():
			var v := View.new(zone, ASPECTS[a])
			for oid in main.world.branch_pads:
				for q: BranchPad in main.world.branch_pads[oid]:
					for it in _pad_items(q, v):
						for b in badges:
							var br := _badge_rect(b[1], v)
							if _gap(it[2], br) < MIN_GAP_PX:
								findings.append("%s zone %s: %s is %.0f px from %s (under %.0f)" % [ASPECT_NAMES[a], lane, it[0], _gap(it[2], br), b[0], MIN_GAP_PX])
	_dump("badges vs pads", findings)
	assert_eq(findings, [], "an empty expected set")

## D-294.8: the hero is drawn in front of every pad label. Structure (what guarantees it in the render; tools/check_hero_front.gd renders it). The order is by
## render priority in the transparent pass: pad ring and disc RING_PRIORITY (-7), pad label OUTLINES (and the tether's ink edge) -6, pad label fills, glyphs and the
## tether's light line LABEL_PRIORITY (-5), the hero and his carried pile -2 and WRITING DEPTH (DEPTH_DRAW_ALWAYS: not a depth pre-pass, which some mobile GPUs skip in the Compatibility renderer, so everything drawn after him
## would paint over him), everything else 0 and up. The hero owns his materials (HeroVisual.draw_after_labels); no pad touches them.
func _hero_surfaces() -> Array:
	var out: Array = []
	for mi in main.hero.visual.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			out.append(m.get_active_material(s))
	return out

## Every material a pad draws: [what, material] for each Label3D (its render_priority is its own), each mesh with a material override, and the zone's payment ring.
func _pad_draws(p: BranchPad) -> Array:
	var out: Array = []
	for n in p.find_children("*", "", true, false):
		if n is Label3D:
			out.append([String(p.get_path_to(n)), (n as Label3D).render_priority, false])
			out.append([String(p.get_path_to(n)) + " outline", (n as Label3D).outline_render_priority, false])
		elif n is MeshInstance3D and (n as MeshInstance3D).material_override != null:
			var mo := (n as MeshInstance3D).material_override
			out.append([String(p.get_path_to(n)) + (" ring" if n is ProgressRing else ""), (mo as Material).render_priority, mo is BaseMaterial3D and (mo as BaseMaterial3D).no_depth_test])
	return out

func test_flag_on_the_hero_and_his_pile_write_depth_after_the_pad_labels_and_rings() -> void:
	await _start_on()
	_all_max()
	await _settle()
	var surfaces := _hero_surfaces()
	assert_gt(surfaces.size(), 0, "the hero has surfaces")
	for m in surfaces:
		var b := m as BaseMaterial3D
		assert_eq(b.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "the hero is in the transparent pass, where the labels are")
		assert_eq(b.depth_draw_mode, BaseMaterial3D.DEPTH_DRAW_ALWAYS, "and writes depth (a depth pre-pass is skipped by some mobile GPUs)")
		assert_eq(b.render_priority, -2)
	var pile: MultiMeshInstance3D = main.hero.carry_stack.get_child(0)
	var pm := pile.material_override as BaseMaterial3D
	assert_not_null(pm, "the carried pile has its own material")
	assert_eq(pm.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_eq(pm.depth_draw_mode, BaseMaterial3D.DEPTH_DRAW_ALWAYS)
	assert_eq(pm.render_priority, -2)
	assert_eq(PileMesh.steak_mesh().surface_get_material(0).render_priority, 0, "the shared steak mesh (every other pile) is untouched")
	assert_eq(BranchPad.RING_PRIORITY, -7)
	assert_eq(BranchPad.OUTLINE_PRIORITY, -6)
	assert_eq(BranchPad.LABEL_PRIORITY, -5)
	assert_eq(Hero.DRAW_AFTER_LABELS_PRIORITY, -2)
	var labels := 0
	var outlines := 0
	var depthless := 0
	var rings := 0
	for id in MapLayout.spots_for_tier(3):
		for p: BranchPad in _pads(id):
			for d in _pad_draws(p):
				assert_lt(int(d[1]), Hero.DRAW_AFTER_LABELS_PRIORITY, "%s %s: a pad node never draws at or after the hero (nothing under a pad is at or above -2)" % [p.name, d[0]])
				if String(d[0]).ends_with(" outline") or String(d[0]).ends_with("TetherInk"):
					outlines += 1
					assert_eq(int(d[1]), BranchPad.OUTLINE_PRIORITY, "%s %s: a label outline (and the tether's ink edge) draws below the label fills" % [p.name, d[0]])
					continue
				var is_ring := String(d[0]).ends_with(" ring") or String(d[0]).ends_with("Marker") or String(d[0]).contains("Range")
				if is_ring:
					rings += 1
					assert_eq(int(d[1]), BranchPad.RING_PRIORITY, "%s %s: ring and disc" % [p.name, d[0]])
				else:
					labels += 1
					assert_eq(int(d[1]), BranchPad.LABEL_PRIORITY, "%s %s: labels, glyphs, tether" % [p.name, d[0]])
					depthless += 1 if d[2] else 0
			assert_eq(((p.zone.ring.material_override) as ShaderMaterial).render_priority, BranchPad.RING_PRIORITY, "%s: the payment ring" % p.name)
			assert_eq(p.marker.material_override.render_priority, BranchPad.RING_PRIORITY)
			assert_eq(p.refund_label.render_priority, BranchPad.LABEL_PRIORITY)
	assert_gte(labels, 18 * 6)
	var pad_labels := 0
	for id in MapLayout.spots_for_tier(3):
		for p: BranchPad in _pads(id):
			pad_labels += p.find_children("*", "Label3D", true, false).size()
	assert_gt(pad_labels, 18 * 4)
	var tether_inks := 0
	for id in MapLayout.spots_for_tier(3):
		for p: BranchPad in _pads(id):
			tether_inks += 1 if p.tether_ink != null else 0
	assert_eq(outlines, pad_labels + tether_inks, "every pad Label3D has its outline priority asserted (and every tether its ink edge)")
	assert_gte(rings, 18)
	assert_gt(depthless, 0, "some glyphs have no depth test")
	main.hero.teleport(_near_hero_at("tower_e", 3.0, "home"))  # a NEAR glyph has no depth test: its material carries the priority
	await _settle()
	var near_glyphs := 0
	for p: BranchPad in _pads("tower_e"):
		if p.stage == BranchPad.NEAR:
			near_glyphs += 1
			assert_true((p.icon.material_override as BaseMaterial3D).no_depth_test)
			assert_eq((p.icon.material_override as BaseMaterial3D).render_priority, BranchPad.LABEL_PRIORITY, "a NEAR glyph draws before the hero")
	assert_gt(near_glyphs, 0)
	for l in get_tree().get_nodes_in_group(&"world_labels"):
		var anc: Node = l
		var pad_label := false
		while anc != null:
			pad_label = pad_label or anc is BranchPad
			anc = anc.get_parent()
		if not pad_label:
			assert_eq((l as Label3D).render_priority, 0, "a station label stays at priority 0, over the hero as today")

## Every pad whose cost stands beyond 0.5 m (its nearest edge from the pad's centre, measured on the real label) has a tether (a light line at LABEL_PRIORITY over its
## ink edge at OUTLINE_PRIORITY, no depth test); every other pad, shifted or not, has none. Round 6 moved eight of the ten shifted costs to within 0.5 m (a row beside the
## glyph; round 7: with the own pips hidden tower_nw a joined them); the one pad that keeps a tether, tower_e a, is pinned: no placement within 0.5 m clears the Freezer label
## and its own glyph (the search is in the report). Mutation: a tether on a pad whose
## cost stands within 0.5 m, or none on one beyond it.
func test_flag_on_the_tether_threshold_is_half_a_metre_and_its_gold_line_is_wide_enough() -> void:
	assert_eq(BranchPad.TETHER_FROM_M, 0.5, "pinned: a cost nearer than this to its pad's centre needs no tether (the distance rule of the search)")
	assert_almost_eq(BranchPad.TETHER_WIDTH_M - 2.0 * BranchPad.TETHER_INK_M, 0.17, 1e-6, "the gold line is 0.17 m: 7.5 px at 720x1280 where the view is the tightest (46.7 px per m)")

func test_flag_on_a_cost_beyond_half_a_metre_has_a_tether_drawn_with_the_labels_and_no_other_pad_has_one() -> void:
	await _start_on()
	_all_max()
	var with_tether: Array = []
	var shifted := 0
	var xf := CameraMath.camera_transform(Vector2.ZERO, Balance.ui)
	for id in MapLayout.spots_for_tier(3):
		for i in 2:
			var p: BranchPad = _pads(id)[i]
			var seen := false
			for k in 24:  # a reachable point 2 m from the pad, in whatever direction shows its cost
				var at := _pad_pos(id, i) + Vector2(2.0, 0.0).rotated(TAU * float(k) / 24.0)
				if not _reachable(at):
					continue
				_near_step(Vector2(15.0, 8.0))
				_near_step(at)
				if p.stage == BranchPad.NEAR and p.cost_label.visible:
					seen = true
					break
			assert_true(seen, "%s pad %d: shows its cost from a reachable point" % [id, i])
			var key := "%s:%d" % [id, i]
			shifted += 1 if BranchPad.COST_SHIFT_RETUNE.has(key) else 0
			var rel := p.cost_label.global_position - p.global_position
			var cpos := Vector2(rel.dot(xf.basis.x), rel.dot(xf.basis.y))
			var cbox: Vector2 = p._cost_box()
			var dist := Vector2(maxf(absf(cpos.x) - cbox.x * 0.5, 0.0), maxf(absf(cpos.y) - cbox.y * 0.5, 0.0)).length()
			var has: bool = p.tether_ends.size() == 2
			assert_eq(has, dist > BranchPad.TETHER_FROM_M, "%s: the cost's nearest edge is %.2f m from the pad: a tether iff beyond %.1f m" % [key, dist, BranchPad.TETHER_FROM_M])
			assert_true(p.tether.visible == has and p.tether_ink.visible == has)
			if has:
				with_tether.append(key)
				assert_eq((p.tether.material_override as BaseMaterial3D).render_priority, BranchPad.LABEL_PRIORITY)
				assert_eq((p.tether_ink.material_override as BaseMaterial3D).render_priority, BranchPad.OUTLINE_PRIORITY)
				assert_true((p.tether.material_override as BaseMaterial3D).no_depth_test)
				assert_true((p.tether_ink.material_override as BaseMaterial3D).no_depth_test)
				assert_ne(p.tether.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR][0], p.tether_ink.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR][0], "a light line over a dark edge")
				assert_gte(p.tether_len, 0.25, "%s: a tether is at least 0.25 m long on the screen" % key)
			else:
				assert_null(p.tether.mesh)
				assert_null(p.tether_ink.mesh)
	assert_eq(shifted, BranchPad.COST_SHIFT_RETUNE.size(), "every shifted pad was measured in its near stage")
	with_tether.sort()
	assert_eq(with_tether, ["tower_e:0"], "the one tethered pad: every other shifted cost stands within 0.5 m")
	gut.p("tethers: %s of %d shifted costs" % [with_tether, BranchPad.COST_SHIFT_RETUNE.size()])

## The hero standing on a pad that is NOT armed (placed there, or the pad appeared under him): the card stays hidden; the world shows the ring and the
## glyph at the ON place, NO cost and NO preview (it cannot be paid yet). The same empty expected set as the ON stage, 18 pads x 3 aspects. A pad
## processes before its own zone, so a walk-in shows one tick of UNARMED: no cost node is visible then either. Mutation: the cost shown while unarmed.
func test_flag_on_an_unarmed_pad_shows_ring_and_glyph_only_with_the_same_zero_overlaps_as_the_on_stage() -> void:
	await _start_on()
	_all_max()
	var rows := _all_rows([_plan_boss_on("west"), _plan_boss_on("north"), _plan_boss_on("east"), _plan_boss_on("sw")])
	var badges := _badge_nodes()
	var findings: Array = []
	var views := 0
	for id in MapLayout.spots_for_tier(3):
		for i in 2:
			main.hero.teleport(Vector2(15.0, 8.0))
			await _settle()
			main.hero.teleport(_pad_pos(id, i))  # placed, not walked in
			await _settle()
			await get_tree().process_frame
			var p: BranchPad = _pads(id)[i]
			assert_eq(BranchPad.pad_hero_stands_on(), p)
			assert_false(p.zone.armed, "%s pad %d: setup, the pad is not armed" % [id, i])
			assert_false(main.hud.branch_card.visible, "%s pad %d: so the card is hidden" % [id, i])
			assert_eq(p.stage, BranchPad.UNARMED, "%s pad %d" % [id, i])
			assert_true(p.marker.visible and p.icon.visible, "ring and glyph")
			assert_false(p.cost_label.visible, "%s pad %d: an unarmed pad shows no cost" % [id, i])
			assert_false(p.preview.visible, "no preview while unarmed")
			assert_false(p.name_label.visible or p.effect_label.visible or (p.warn_label != null and p.warn_label.visible), "no name, effect or warning")
			assert_eq((_pads(id)[1 - i] as BranchPad).stage, BranchPad.SIBLING_QUIET)
			for a in ASPECTS.size():
				findings.append_array(_on_findings(id, i, ASPECTS[a], rows, badges, Vector2.INF, false))
				views += 1
	assert_eq(views, 54)
	_dump("UNARMED, 54 views", findings)
	_dump_gaps("UNARMED gaps")
	assert_eq(findings, [], "an empty expected set: the same as the ON stage")
	# the walk-in tick: the pad has run, its zone has not (so it is not armed yet): the stage is UNARMED, with no cost node visible
	for id in ["tower_e", "fence_sw"]:
		var p: BranchPad = _pads(id)[0]
		main.hero.teleport(_pad_pos(id, 0) + Vector2(0, 2.0))
		await _settle()
		main.hero.global_position = MapLayout.to3(_pad_pos(id, 0) + Vector2(0, 0.5))
		BranchPad._cache_frame = -1
		p._physics_process(0.0)
		assert_eq(p.stage, BranchPad.UNARMED, "%s: the walk-in tick, before the zone arms" % id)
		assert_false(p.cost_label.visible, "%s: no cost node in the walk-in tick" % id)
		for pad_id in MapLayout.spots_for_tier(3):
			for q: BranchPad in _pads(pad_id):
				assert_false(q.stage == BranchPad.UNARMED and q.cost_label.visible, "an unarmed pad never shows a cost")
		await _settle()
		assert_eq(p.stage, BranchPad.ON, "%s: the next ticks arm it" % id)
	# leaving and walking back in arms the pad: the card shows
	await _walk_onto("tower_e", 0)
	assert_true(main.hud.branch_card.visible)
	assert_eq((_pads("tower_e")[0] as BranchPad).stage, BranchPad.ON)
	assert_false((_pads("tower_e")[0] as BranchPad).cost_label.visible, "the card shows the cost now")

## The world shows no word of the card on any stage: far, near, armed and unarmed (mutation: a name label left visible on the stood pad).
func test_flag_on_the_world_keeps_no_name_effect_or_warning_label_and_the_card_owns_the_cost_while_armed() -> void:
	await _start_on()
	_all_max()
	for id in ["tower_nw", "tower_e", "fence_n", "fence_sw"]:
		for i in 2:
			var stood: BranchPad = _pads(id)[i]
			var other: BranchPad = _pads(id)[1 - i]
			await _walk_onto(id, i)
			var text := _visible_text()
			assert_eq(text.name.size() + text.effect.size() + text.warn.size(), 0, "%s pad %d armed: no name, effect or warning in the world" % [id, i])
			assert_eq(text.cost.size(), 0, "%s pad %d armed: the card owns the cost" % [id, i])
			if stood.warn_icon != null:
				assert_false(stood.warn_icon.visible, "the fence warning glyph is the card's too")
			assert_true(stood.icon.visible and stood.preview_shown(), "the glyph and the preview shape stay")
			assert_true(stood.marker.visible and other.marker.visible, "both rings stay")
			assert_false(other.icon.visible or other.cost_label.visible, "the sibling is quiet")
			assert_true(main.hud.branch_card.visible)
			main.hero.teleport(_near_hero_at(id, 3.0, "home"))
			await _settle()
			assert_eq(BranchPad.focus_spot(), id)
			text = _visible_text()
			assert_eq(text.name.size() + text.effect.size() + text.warn.size(), 0, "%s near: no name, effect or warning" % id)
			var at := main.hero.xz()
			var in_reach := 0
			for q: BranchPad in [stood, other]:
				var reach := at.distance_to(Vector2(q.global_position.x, q.global_position.z)) <= Balance.ui.branch_pad_near_m
				in_reach += int(reach)
				assert_eq(q.stage, BranchPad.NEAR if reach else BranchPad.FAR, "%s near: a pad shows its cost only within reach" % id)
			assert_eq(text.cost.size(), in_reach, "%s near: ring, glyph and cost on the pads in reach" % id)
			assert_false(main.hud.branch_card.visible)
	main.hero.teleport(Vector2(15.0, 8.0))
	await _settle()
	var far := _visible_text()
	for k in far:
		assert_eq(far[k].size(), 0, "far: no %s" % k)

## Per-pad reach with its hysteresis: a pad shows its cost within branch_pad_near_m of the hero, keeps it out to
## branch_pad_leave_m once shown, and a pad entered from far in that band does not start showing it. The old spot-wide rule (mutation) would
## show both pads of the focus spot here.
func test_flag_on_a_pad_shows_its_cost_only_within_reach_with_a_hysteresis_band() -> void:
	await _start_on()
	_all_max()
	var a: BranchPad = _pads("fence_sw")[0]
	var b: BranchPad = _pads("fence_sw")[1]
	var pa := _pad_pos("fence_sw", 0)
	main.hero.teleport(Vector2(15.0, 8.0))
	await _settle()
	main.hero.teleport(pa + Vector2(-3.0, 0.0))  # 3.0 m: in reach of a, 5.4 m+ from b
	await _settle()
	assert_eq(BranchPad.focus_spot(), "fence_sw")
	assert_eq(a.stage, BranchPad.NEAR)
	assert_eq(b.stage, BranchPad.FAR, "the far pad of the focus spot shows ring and glyph only")
	assert_false(b.cost_label.visible)
	assert_true(b.icon.visible)
	var lv: float = Balance.ui.branch_pad_leave_m  # round 5: the keep band is shorter (3.8 m)
	assert_gte(lv, Balance.ui.branch_pad_near_m + 0.3, "the band stays at least 0.3 m wide")
	main.hero.teleport(pa + Vector2(-(lv - 0.2), 0.0))  # inside the leave band, a keeps its cost
	await _settle()
	assert_eq(a.stage, BranchPad.NEAR, "kept while within the leave distance")
	main.hero.teleport(pa + Vector2(-(lv + 0.4), 0.0))  # beyond it
	await _settle()
	assert_eq(a.stage, BranchPad.FAR, "dropped beyond branch_pad_leave_m")
	main.hero.teleport(Vector2(15.0, 8.0))
	await _settle()
	main.hero.teleport(pa + Vector2(-(lv - 0.2), 0.0))  # entered from far, straight into the band
	await _settle()
	assert_ne(a.stage, BranchPad.NEAR, "a pad first met in the band does not show its cost")

## The stage never changes what a tick pays: far, near, unarmed, armed (ON) and the quiet sibling, on a tower pad and a fence pad, and by really standing.
func test_flag_on_the_stage_never_changes_what_a_tick_pays() -> void:
	await _start_on()
	_max("tower_w")
	_max("fence_n")
	var tower_drain := Economy.drain_per_tick(_cost("tower_w"), Balance.data.build)
	var fence_drain := Economy.drain_per_tick(_cost("fence_n"), Balance.data.build)
	assert_eq(tower_drain, 25, "a tower pad: ceil(500 / drain_divisor 20)")
	assert_eq(fence_drain, 15, "a fence pad: ceil(300 / 20)")
	for case in [["tower_w", tower_drain], ["fence_n", fence_drain]]:
		var id: String = case[0]
		var drain: int = case[1]
		for st in [BranchPad.FAR, BranchPad.NEAR, BranchPad.UNARMED, BranchPad.ON, BranchPad.SIBLING_QUIET]:
			var pad: BranchPad = _pads(id)[0]
			GameState.buildings[id].branch_paid = {}
			GameState.gold = 100000
			match st:
				BranchPad.FAR:
					main.hero.teleport(MapLayout.HOME)
				BranchPad.NEAR:
					main.hero.teleport(_pad_pos(id, 0) + Vector2(1.0, 3.0))  # near pad 0 (3.2 m), not on it
				BranchPad.UNARMED:
					main.hero.teleport(_pad_pos(id, 0))
				BranchPad.SIBLING_QUIET:
					main.hero.teleport(_pad_pos(id, 1))  # the hero stands on pad 1: pad 0 is the quiet sibling, and still pays
				_:
					main.hero.teleport(MapLayout.HOME)
					await _settle()
					await _walk_onto(id, 0)
			await _settle()
			assert_eq(pad.stage, st, "%s is in stage %d" % [id, st])
			pad._on_tick()
			assert_eq(pad.paid(), drain, "%s stage %d: after tick 1" % [id, st])
			pad._on_tick()
			pad._on_tick()
			assert_eq(pad.paid(), 3 * drain, "%s stage %d: after tick 3" % [id, st])
	# and by really standing: the same amounts
	GameState.buildings["tower_w"].branch_paid = {}
	GameState.gold = 100000
	var spad: BranchPad = _pads("tower_w")[0]
	var ticks := [0]
	spad.zone.ticked.connect(func(): ticks[0] += 1)
	await _stand_on("tower_w", 0)
	await _wait_until(func(): return ticks[0] >= 3, 600)
	assert_gte(ticks[0], 3, "setup: the zone ticked")
	assert_eq(spad.paid(), ticks[0] * tower_drain, "standing: paid = ticks x drain")

## The world-space box of a spot's level-3 model: every mesh under its visual, transformed to the world.
func _model_corners(sp: BuildSpot) -> Array:
	var pts: Array = []
	for mi in sp.visual.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var box := m.get_aabb()
		for k in 8:
			pts.append(m.global_transform * (box.position + Vector3(box.size.x * (k & 1), box.size.y * ((k >> 1) & 1), box.size.z * ((k >> 2) & 1))))
	return pts

func test_the_pad_centre_clears_the_level_3_model_by_the_margin_from_the_pad() -> void:
	await _start()
	_all_max()
	_check_hull_margins()

## The rule of the test above, for the pad table in force now.
func _check_hull_margins() -> void:
	var worst := INF
	var worst_ring := 0
	for aspect in ASPECTS:
		for id in MapLayout.spots_for_tier(3):
			var sp: BuildSpot = main.world.build_spots[id]
			var corners := _model_corners(sp)
			assert_gt(corners.size(), 0, id + " has a model")
			for i in 2:
				var v := View.new(_pad_pos(id, i), aspect)
				var hull := Geometry2D.convex_hull(PackedVector2Array(corners.map(func(c): return v.pt(c))))
				var c3 := MapLayout.to3(_pad_pos(id, i))
				var inside := Geometry2D.is_point_in_polygon(v.pt(c3), hull)
				var margin := _dist_to_hull(v.pt(c3), hull) * (-1.0 if inside else 1.0)
				worst = minf(worst, margin)
				assert_gte(margin, HULL_MARGIN_PX, "%.2f %s pad %d: the pad centre %s clears the level-3 model's projected box by %.1f px: re-run the pad search (tools/probe_t3_layout.gd)" % [aspect, id, i, _pad_pos(id, i), margin])
				var hidden := 0
				for k in 8:
					var s3 := c3 + Vector3(cos(TAU * k / 8.0), 0.0, sin(TAU * k / 8.0)) * MapLayout.BRANCH_PAD_RADIUS * 0.5
					if Geometry2D.is_point_in_polygon(v.pt(s3), hull):
						hidden += 1
				worst_ring = maxi(worst_ring, hidden)
				assert_lte(hidden, 3, "%.2f %s pad %d: %d of 8 marker points are behind the model" % [aspect, id, i, hidden])
	gut.p("smallest margin between a pad centre and the projected level-3 model box: %.1f base px; most hidden marker points %d of 8" % [worst, worst_ring])

func test_flag_on_the_pad_centre_clears_the_level_3_model_by_the_margin_from_the_pad() -> void:
	await _start_on()
	_all_max()
	_check_hull_margins()

func _dist_to_hull(p: Vector2, hull: PackedVector2Array) -> float:
	var best := INF
	for i in hull.size():
		var q := Geometry2D.get_closest_point_to_segment(p, hull[i], hull[(i + 1) % hull.size()])
		best = minf(best, p.distance_to(q))
	return best

func test_warmup_run_places_the_pad_visuals_only_when_the_build_has_tier_3() -> void:
	await _start()
	var expected := Warmup.branch_pad_visuals().size()
	assert_eq(expected, 2 + BranchIcons.KINDS.size() * 2, "two rings and every glyph with both materials")
	var w := Warmup.new()
	main.add_child(w)
	w.run(main)  # to its first process_frame: the temporary nodes are in the tree
	var far_glyphs := 0
	var rings := 0
	for c in w.get_children():
		if c is MeshInstance3D and c.material_override == BranchIcons.far_material() and c.mesh in BranchIcons.KINDS.map(func(k): return BranchIcons.mesh(k)):
			far_glyphs += 1
		if c is MeshInstance3D and c.material_override == BranchIcons.ground_material():
			rings += 1
	assert_eq(far_glyphs, BranchIcons.KINDS.size(), "every glyph is drawn with the far material")
	assert_eq(rings, 2)
	await w.finished
	var with_pads := w.built_count
	w.queue_free()
	Balance.data.tiers.tier_costs.resize(2)
	var w2 := Warmup.new()
	main.add_child(w2)
	await w2.run(main)
	assert_eq(with_pads - w2.built_count, expected, "a build without tier 3 places none of them")

func test_the_warm_up_draws_the_pad_visuals_before_the_first_one_shows() -> void:
	var nodes := Warmup.branch_pad_visuals()
	var meshes: Array = nodes.map(func(n): return (n as MeshInstance3D).mesh)
	var mats: Array = nodes.map(func(n): return (n as MeshInstance3D).material_override)
	assert_true(BranchIcons.ring_mesh(&"ice_blue", 0.82, 0.22) in meshes, "the pad's ground ring mesh")
	assert_true(BranchIcons.ground_material() in mats, "and its alpha material")
	for kind in BranchIcons.KINDS:
		assert_true(BranchIcons.mesh(kind) in meshes, "the %s glyph" % kind)
	assert_true(BranchIcons.material() in mats, "the near and stood glyph material")
	assert_true(BranchIcons.far_material() in mats, "the far glyph's depth-tested material")
	Balance.data.tiers.tier_costs.resize(2)
	assert_eq(Warmup.branch_pad_visuals().size(), 0, "no tier 3 in the build: nothing to draw")
	for n in nodes:
		n.free()

# --- save, load, nights ------------------------------------------------------------------------------------------------------

func test_partial_payments_survive_close_up_a_night_and_a_reload_and_the_ring_shows_them() -> void:
	await _start()
	_max("fence_e")
	var cost := _cost("fence_e")
	GameState.gold = 90
	GameState.pay_into_branch("fence_e", &"spike", 90)
	var pad: BranchPad = _pads("fence_e")[1]
	var frac := 90.0 / float(cost)
	assert_true(pad.zone.ring.visible)
	assert_almost_eq(pad.zone.ring.progress, frac, 1e-6)
	assert_eq(pad.cost_label.text, str(cost - 90))
	pc.close_up()
	await get_tree().physics_frame
	assert_false(pad.zone.ring.visible, "no glowing ring on the lanes during combat")
	assert_eq(GameState.buildings["fence_e"].branch_paid, {"spike": 90}, "the payment waits through the night")
	pc.debug_skip_to_day()
	await get_tree().physics_frame
	assert_true(pad.zone.ring.visible, "dawn: the ring is back")
	assert_almost_eq(pad.zone.ring.progress, frac, 1e-6)
	assert_eq(pad.cost_label.text, str(cost - 90))
	var d := GameState.to_dict()
	GameState.new_game(3)
	await get_tree().physics_frame
	assert_eq(main.world.branch_pads.size(), 0, "a fresh game is tier 1: no pads at all")
	GameState.from_dict(d)
	await get_tree().physics_frame
	pad = _pads("fence_e")[1]  # the pads follow the tier: a fresh game dropped them, the reload made them again
	assert_true(pad.zone.ring.visible, "the reload redraws the ring")
	assert_almost_eq(pad.zone.ring.progress, frac, 1e-6)
	assert_eq(pad.cost_label.text, str(cost - 90))
	assert_eq(_pads("fence_e")[0].cost_label.text, str(cost), "the other pad is still empty")

func test_a_failed_night_restores_the_branch_and_the_partial_payment_through_the_real_controller() -> void:
	await _start()
	_max("tower_nw")
	_max("tower_ne")
	_max("fence_w")
	GameState.gold = _cost("tower_nw")
	GameState.pay_into_branch("tower_nw", &"longbow", _cost("tower_nw"))  # a branch bought in the DAY
	GameState.gold = 77
	GameState.pay_into_branch("tower_ne", &"volley", 77)  # a partial payment made in the DAY
	GameState.gold = 40
	pc.close_up()  # the restore point
	assert_eq(pc.phase, Phase.NIGHT)
	# during the night the pads are away and the state is what it was
	for p in _pads("tower_ne"):
		assert_false(p.is_shown())
	GameState.damage_fence("fence_w", 1e6)  # the night goes badly
	GameState.damage_diner(1e6)
	assert_true(pc.failing)
	var ticks := int(ceil(Balance.ui.banner_time * Engine.physics_ticks_per_second)) + 3
	for i in ticks:
		await get_tree().physics_frame
	assert_false(pc.failing)
	assert_eq(pc.phase, Phase.DAY, "the restore returns to the day it took the snapshot in")
	assert_eq(GameState.branch_of("tower_nw"), &"longbow", "the bought branch survived the failed night")
	assert_eq(GameState.buildings["tower_ne"].branch_paid, {"volley": 77}, "the partial payment survived")
	assert_gt(float(GameState.buildings["fence_w"].hp), 0.0, "the fence the night broke stands again")
	assert_eq(GameState.gold, 40)
	for p in _pads("tower_nw"):
		assert_false(p.is_shown(), "the chosen spot shows no pads")
	var pad: BranchPad = _pads("tower_ne")[1]
	assert_true(pad.is_shown())
	assert_true(pad.zone.ring.visible, "the pad shows the restored payment")
	assert_almost_eq(pad.zone.ring.progress, 77.0 / float(_cost("tower_ne")), 1e-6)
	assert_eq(pad.cost_label.text, str(_cost("tower_ne") - 77))
	assert_true(_pads("fence_w")[0].is_shown(), "the restored fence offers its branches again")

func test_a_fence_destroyed_at_night_loses_its_pads_at_dawn_and_the_gold_flies_back_then_both_pads_return_empty() -> void:
	await _start()
	_max("fence_n")
	GameState.gold = 120
	GameState.pay_into_branch("fence_n", &"stone", 120)
	GameState.gold = 55
	GameState.pay_into_branch("fence_n", &"spike", 55)
	var gold_before := GameState.gold
	pc.close_up()
	GameState.damage_fence("fence_n", 1e6)
	EventBus.fx_requested.connect(_on_fx)
	_fx_log.clear()
	watch_signals(EventBus)
	pc.debug_skip_to_day()
	assert_signal_emitted_with_parameters(EventBus, "branch_refunded", [&"fence_n", 175])
	assert_eq(GameState.gold, gold_before + 175, "no gold is lost")
	assert_eq(int(GameState.buildings["fence_n"].level), 0, "the fence reset to level 0")
	for p in _pads("fence_n"):
		assert_false(p.is_shown(), "at dawn its pads are gone")
	var stone: BranchPad = _pads("fence_n")[0]
	var spike: BranchPad = _pads("fence_n")[1]
	assert_eq(stone.last_refund, 120, "each pad flies what it held")
	assert_eq(spike.last_refund, 55)
	assert_eq(stone.refund_label.text, "+120")
	assert_gt(main.world.fly_fx.in_flight(), 0, "the coins fly to the hero")
	await get_tree().physics_frame
	var pile := MapLayout.to3(MapLayout.GOLD_PILE, 0.6)
	for e in _fx_log:
		assert_false(e[0] == &"sparkle" and (e[1] as Vector3).is_equal_approx(pile), "the dawn refund does not sparkle at the pile")
	_max("fence_n")
	for p in _pads("fence_n"):
		assert_true(p.is_shown(), "rebuilt to level 3 the pads return")
		assert_false(p.zone.ring.visible, "empty")
		assert_eq(p.cost_label.text, str(_cost("fence_n")))
		assert_eq(p.paid(), 0)

# --- the onboarding pointer --------------------------------------------------------------------------------------------------

func _hint(store: SettingsStore) -> BranchPadHint:
	var h := BranchPadHint.new()
	main.add_child(h)
	h.setup(main.world, store)
	return h

func _store() -> SettingsStore:
	var s := SettingsStore.with_dir(HINT_DIR)
	s.load_settings()
	return s

func test_the_pointer_points_at_the_nearest_shown_pad_once_ever_and_not_after_a_reload() -> void:
	await _start()
	var store := _store()
	assert_false(store.branch_hint_done)
	var h := _hint(store)
	main.hero.teleport(MapLayout.HOME)
	for i in 10:
		await get_tree().physics_frame
	assert_eq(h.shown_count, 0, "no pad is on the map yet: nothing to point at")
	assert_false(h.pointer.visible)
	_max("tower_nw")  # the first spot of the list
	_max("tower_e")
	main.hero.teleport(MapLayout.HOME)
	for i in 3:
		await get_tree().physics_frame
	assert_eq(h.shown_count, 1, "the first time a pad is visible and on screen the pointer shows")
	assert_true(h.pointer.visible)
	var hero_xz := main.hero.xz()
	var nearest: BranchPad = null
	var best := INF
	for id in ["tower_nw", "tower_e"]:
		for p in _pads(id):
			var d := hero_xz.distance_to(Vector2(p.global_position.x, p.global_position.z))
			if d < best:
				best = d
				nearest = p
	assert_eq(h.target, nearest, "the shown pad NEAREST the hero")
	assert_true(absf(h.pointer.global_position.y - Balance.ui.guide_pointer_h) <= Balance.ui.guide_bounce_m + 1e-3, "at the Guide's pointer height")
	assert_true(store.branch_hint_done, "the flag is set once the pointer is shown on screen")
	var disk := SettingsStore.with_dir(HINT_DIR)
	disk.load_settings()
	assert_true(disk.branch_hint_done, "and written")
	await _stand_on("tower_e", 1)  # the hero steps on a pad: the preview takes over
	assert_false(h.pointer.visible, "the pointer goes when the hero reaches a pad")
	main.hero.teleport(MapLayout.HOME)
	_max("fence_n")
	for i in 10:
		await get_tree().physics_frame
	assert_eq(h.shown_count, 1, "never a second time in the same game")
	assert_false(h.is_physics_processing(), "a finished hint stops processing")
	h.queue_free()
	var again := _store()
	assert_true(again.branch_hint_done, "remembered")
	var h2 := _hint(again)
	assert_false(h2.is_physics_processing(), "a reload with the flag set never even processes")
	for i in 10:
		await get_tree().physics_frame
	assert_eq(h2.shown_count, 0, "not after a reload")
	assert_false(h2.pointer.visible)

func test_the_pointer_waits_until_a_pad_is_on_screen_and_only_then_saves_the_flag() -> void:
	await _start()
	var store := _store()
	var h := _hint(store)
	_max("tower_e")
	main.hero.teleport(Vector2(-16.0, -18.0))  # the far north-west corner: the east tower's pads are off screen
	for i in 10:
		await get_tree().physics_frame
	assert_eq(h.shown_count, 0, "the pad is not on screen from where the hero stands")
	assert_false(store.branch_hint_done, "so nothing is saved")
	assert_true(h.is_physics_processing(), "and it keeps waiting")
	main.hero.teleport(MapLayout.HOME)
	for i in 5:
		await get_tree().physics_frame
	assert_eq(h.shown_count, 1)
	assert_true(store.branch_hint_done)

func test_the_pointer_never_fires_at_tier_2() -> void:
	await _start(false)
	var store := _store()
	var h := _hint(store)
	for id in MapLayout.spots_for_tier(2):
		_max(id)
	for i in 20:
		await get_tree().physics_frame
	assert_eq(h.shown_count, 0, "tier 2 has no branch pads")
	assert_false(h.pointer.visible)
	assert_false(store.branch_hint_done, "and the flag stays unset")

func test_the_settings_store_keeps_the_hint_flag_beside_guide_done() -> void:
	var s := SettingsStore.with_dir(HINT_DIR)
	s.wipe_for_tests()
	s.load_settings()
	assert_false(s.branch_hint_done)
	s.guide_done = true
	s.branch_hint_done = true
	assert_true(s.save_settings())
	var t := SettingsStore.with_dir(HINT_DIR)
	t.load_settings()
	assert_true(t.branch_hint_done and t.guide_done)
	t.branch_hint_done = false
	t.save_settings()
	var u := SettingsStore.with_dir(HINT_DIR)
	u.load_settings()
	assert_true(u.guide_done)
	assert_false(u.branch_hint_done, "independent of guide_done")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HINT_DIR))
	var f := FileAccess.open(HINT_DIR.path_join("settings.json"), FileAccess.WRITE)
	f.store_string('{"v":1,"muted":false,"guide_done":true,"branch_hint_done":"yes"}')
	f.close()
	var w := SettingsStore.with_dir(HINT_DIR)
	w.load_settings()
	assert_false(w.branch_hint_done, "a wrong type means the default")
	assert_true(w.guide_done)

func test_a_corrupt_settings_file_means_the_hint_is_not_shown_yet() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HINT_DIR))
	var f := FileAccess.open(HINT_DIR.path_join("settings.json"), FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var s := SettingsStore.with_dir(HINT_DIR)
	s.branch_hint_done = true  # a stale value in memory must not survive the load
	s.load_settings()
	assert_false(s.branch_hint_done, "corrupt: the pointer has not been shown yet")
	assert_false(s.guide_done)
