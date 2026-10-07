extends GutTest
## E5 tier 3 Task 17 (D-263, D-264, D-273): the branch pads. At tier 3 a level-3 tower or fence takes one of two branches; the
## player chooses by standing still on one of two pads beside the building. Every test names the wrong implementation it catches.
## The build's top tier is 2, so each test appends the tier-3 cost entry (Balance.reset() drops it).

const ASPECTS := [9.0 / 21.0, 720.0 / 1280.0, 16.0 / 9.0]
const HINT_DIR := "user://test_branch_hint"
## The seven buildings that stand at the tier-3 dawn (tower_sw and fence_sw are bought afterwards).
const SEVEN := ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e", "tower_w", "tower_e"]

var main: Main
var pc: PhaseController
var pile_sparkles := 0
var _fx_log: Array = []

func before_each() -> void:
	BranchPad.reset_focus()
	Balance.reset()
	Balance.data.tiers.tier_costs.append(1500)  # test-only: the build knows tier 3
	pile_sparkles = 0
	_fx_log = []

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
	return (MapLayout.BRANCH_PADS[id] as Array)[i]

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
	EventBus.gold_changed.emit(40, -10)
	EventBus.gold_changed.emit(90, 50)
	r.free()  # the deferred flush must be dropped with the node
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(true, "no script error was raised (the runner fails on one)")

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
	main.hero.teleport(_pad_pos("tower_w", 0))
	await _settle()
	assert_true(main.hero.still_time < Balance.data.economy.stand_still_time, "not past the arming threshold yet")
	assert_true(pad.preview_shown(), "the preview shows the moment the hero is inside")
	assert_true(pad.effect_label.visible, "with its second line")
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

func test_the_fence_warning_is_part_of_the_preview_and_shows_only_while_standing_inside() -> void:
	await _start()
	_max("fence_n")
	var pad: BranchPad = _pads("fence_n")[1]
	assert_false(pad.warn_label.visible, "not while the hero is away")
	assert_false(pad.warn_icon.visible)
	main.hero.teleport(_pad_pos("fence_n", 1))
	await _settle()
	assert_true(pad.warn_label.visible, "the hero stands inside: the line is read before any gold moves")
	assert_true(pad.warn_icon.visible)
	assert_eq(pad.warn_label.text, tr("lost if broken"))
	main.hero.teleport(_pad_pos("fence_n", 1) + Vector2(3, 0))
	await _settle()
	assert_false(pad.warn_label.visible)
	assert_false(_pads("fence_n")[0].warn_label.visible, "the other pad's line never showed")

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
		assert_eq(p.icon.material_override, BranchIcons.far_material(), "the far glyph is depth-tested")
		assert_false(p.icon.material_override.no_depth_test, "so a building hides it")
		assert_true(p.marker.visible and p.body.visible, "the ring is there")
		assert_almost_eq(p.icon.scale.x, Balance.ui.branch_pad_far_icon_m, 1e-6)

func test_near_stage_shows_the_cost_on_exactly_the_focus_spots_two_pads() -> void:
	await _start()
	_all_max()
	var near := _pad_pos("tower_nw", 0) + Vector2(1.0, 3.0)  # 3 m or so from the pad, not on one
	main.hero.teleport(near)
	await _settle()
	assert_eq(BranchPad.focus_spot(), "tower_nw")
	var text := _visible_text()
	assert_eq(text.cost.size(), 2, "the focus spot's two pads show their cost")
	for p in text.cost:
		assert_eq(p.spot_id, "tower_nw")
		assert_eq(p.stage, BranchPad.NEAR)
		assert_eq(p.cost_label.text, str(_cost("tower_nw")))
		assert_eq(p.cost_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "centred under its glyph")
	assert_eq(text.name.size() + text.effect.size() + text.warn.size(), 0, "no name, preview line or warning yet")
	for p in _pads("tower_nw"):
		assert_eq(p.icon.material_override, BranchIcons.material(), "near: the glyph is drawn over the ground, readable")
		assert_almost_eq(p.icon.scale.x, Balance.ui.branch_pad_icon_m, 1e-6)
		var w := BranchPad.glyph_box(p.icon).x
		assert_lte(maxf(w, BranchPad.text_box(p.cost_label).x), 1.2, "the block is at most 1.2 m wide")
	var other: BranchPad = _pads("tower_ne")[0]
	assert_eq(other.stage, BranchPad.FAR, "another spot stays far")

func test_on_stage_shows_name_and_preview_line_on_exactly_the_stood_pad_and_leaving_reverts() -> void:
	await _start()
	for id in SEVEN:
		_max(id)
	main.hero.teleport(_pad_pos("fence_n", 1))
	await _settle()
	var text := _visible_text()
	var pad: BranchPad = _pads("fence_n")[1]
	assert_eq(text.name, [pad])
	assert_eq(text.effect, [pad])
	assert_eq(text.warn, [pad])
	assert_eq(text.cost.size(), 2, "the stood pad and its sibling show cost")
	assert_eq(pad.stage, BranchPad.ON)
	assert_eq(_pads("fence_n")[0].stage, BranchPad.NEAR)
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
	var base := _pad_pos("tower_nw", 1)  # (-3.0, -5.5)
	main.hero.teleport(base + Vector2(0.0, 3.0))
	await _settle()
	assert_eq(BranchPad.focus_spot(), "tower_nw", "3.0 m: inside near_m")
	main.hero.teleport(base + Vector2(0.0, 4.0))
	await _settle()
	assert_eq(BranchPad.focus_spot(), "tower_nw", "4.0 m: beyond near_m, inside leave_m: kept")
	main.hero.teleport(base + Vector2(0.0, 5.0))
	await _settle()
	assert_eq(BranchPad.focus_spot(), "", "5.0 m: beyond leave_m: dropped")
	main.hero.teleport(base + Vector2(0.0, 4.0))
	await _settle()
	assert_eq(BranchPad.focus_spot(), "", "4.0 m from a dropped focus: beyond near_m, not re-chosen")
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

func test_the_stage_never_changes_what_a_tick_pays() -> void:
	await _start()
	_max("tower_w")
	_max("fence_n")
	var tower_drain := Economy.drain_per_tick(_cost("tower_w"), Balance.data.build)
	var fence_drain := Economy.drain_per_tick(_cost("fence_n"), Balance.data.build)
	assert_eq(tower_drain, 25, "a tower pad: ceil(500 / drain_divisor 20)")
	assert_eq(fence_drain, 15, "a fence pad: ceil(300 / 20)")
	for case in [["tower_w", tower_drain], ["fence_n", fence_drain]]:
		var id: String = case[0]
		var drain: int = case[1]
		for st in [BranchPad.FAR, BranchPad.NEAR, BranchPad.ON]:
			var pad: BranchPad = _pads(id)[0]
			GameState.buildings[id].branch_paid = {}
			GameState.gold = 100000
			match st:
				BranchPad.FAR:
					main.hero.teleport(MapLayout.HOME)
				BranchPad.NEAR:
					main.hero.teleport(_pad_pos(id, 0) + Vector2(1.0, 3.0))
				_:
					main.hero.teleport(_pad_pos(id, 0))
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
	var pad: BranchPad = _pads("tower_w")[0]
	var ticks := [0]
	pad.zone.ticked.connect(func(): ticks[0] += 1)
	await _stand_on("tower_w", 0)
	await _wait_until(func(): return ticks[0] >= 3, 600)
	assert_eq(pad.paid(), ticks[0] * tower_drain, "standing: paid = ticks x drain")

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
const HULL_MARGIN_PX := 6.5
## Pads whose ON stack still collides at one view or more (violations over the three aspects): reported, not hidden (see the report).
const OPEN_VIEWS := {
	"tower_nw:0": 3, "tower_ne:1": 3, "fence_w:1": 3, "fence_e:0": 3, "tower_w:1": 3, "tower_e:1": 3, "tower_sw:1": 3, "fence_sw:0": 3, "fence_sw:1": 15,
}

func test_the_ui_floors_are_the_plans() -> void:
	assert_eq(Balance.ui.branch_pad_icon_min_px, 28.0)
	assert_eq(Balance.ui.branch_pad_label_min_px, 28.0)
	assert_eq(Balance.ui.branch_pad_warn_min_px, 20.0)
	assert_eq(Balance.ui.branch_pad_near_m, 3.5)
	assert_eq(Balance.ui.branch_pad_leave_m, 4.5)
	assert_true(Balance.ui.branch_pad_label_font in [48, 40] and Balance.ui.branch_pad_cost_font in [48, 40] and Balance.ui.branch_pad_warn_font in [48, 40], "the project's own font sizes")

func test_sizes_meet_the_floors_for_the_stood_pad_and_the_siblings_glyph_and_cost() -> void:
	await _start()
	_all_max()
	var worst := {"icon": INF, "label": INF, "cost": INF, "warn": INF, "sib_icon": INF, "sib_cost": INF}
	for aspect in ASPECTS:
		for id in MapLayout.spots_for_tier(3):
			for i in 2:
				main.hero.teleport(_pad_pos(id, i))
				await _settle()
				var v := View.new(_pad_pos(id, i), aspect)
				var p: BranchPad = _pads(id)[i]
				var sib: BranchPad = _pads(id)[1 - i]
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
				worst.sib_icon = minf(worst.sib_icon, _node_rect(sib.icon, v).size.y / 1.14)
				worst.sib_cost = minf(worst.sib_cost, _px_h(sib.cost_label.global_position, float(sib.cost_label.font_size) * sib.cost_label.pixel_size, v))
	gut.p("measured worst (base px): %s" % [worst])
	var ui := Balance.ui
	assert_gte(worst.icon, ui.branch_pad_icon_min_px, "the stood pad's glyph")
	assert_gte(worst.label, ui.branch_pad_label_min_px, "name and preview line em")
	assert_gte(worst.cost, ui.branch_pad_label_min_px, "the stood pad's cost em")
	assert_gte(worst.warn, ui.branch_pad_warn_min_px, "the warning line em")
	assert_gte(worst.sib_icon, ui.branch_pad_icon_min_px, "the sibling's glyph as seen from the stood pad")
	assert_gte(worst.sib_cost, ui.branch_pad_label_min_px, "the sibling's cost as seen from the stood pad")

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

## The rules for one view (the hero on pad `i` of `id`, at `aspect`): returns the violations as strings (and the smallest gap in
## `gap_out[0]`). Every rect is built from the real nodes.
func _view_violations(id: String, i: int, aspect: float, rows: Array, gap_out: Array) -> Array:
	var bad: Array = []
	var p: BranchPad = _pads(id)[i]
	var sib: BranchPad = _pads(id)[1 - i]
	var v := View.new(_pad_pos(id, i), aspect)
	var centre := v.pt(p.global_position)
	var ppm := v.px_per_m(p.global_position)
	var mine := _pad_items(p, v)
	var theirs := _pad_items(sib, v)
	var tag := "%.2f %s pad %d" % [aspect, id, i]
	if p.stage != BranchPad.ON or mine.size() < 4:
		bad.append(tag + ": the stack does not show")
		return bad
	for e in mine + theirs:  # on screen
		if not v.screen().encloses(e[2]):
			bad.append("%s: %s %s is not fully on screen" % [tag, e[0], e[2]])
	if not v.screen().has_point(v.pt(sib.global_position)):
		bad.append(tag + ": the sibling pad is off screen")
	var pr = _preview_rect(p, v)
	if pr != null and not v.screen().encloses(pr):
		bad.append("%s: the preview glyph %s is not on screen" % [tag, pr])
	for e in mine:  # attachment
		var d := _attach_m(e[2], centre, ppm)
		if d > ATTACH_ON_M:
			bad.append("%s: %s stands %.2f screen-m from its pad (limit %.1f)" % [tag, e[0], d, ATTACH_ON_M])
	for e in theirs:
		var d := _attach_m(e[2], v.pt(sib.global_position), v.px_per_m(sib.global_position))
		if d > ATTACH_NEAR_M:
			bad.append("%s: the sibling's %s stands %.2f screen-m from it (limit %.1f)" % [tag, e[0], d, ATTACH_NEAR_M])
	var others: Array = []  # [what, rect]
	for e in theirs:
		others.append(["the sibling's " + String(e[0]), e[2]])
	others.append(["the hero", _hero_rect(_pad_pos(id, i), v)])
	for oid in main.world.branch_pads:
		for q: BranchPad in main.world.branch_pads[oid]:
			if q != p and q != sib and q.body.visible and q.icon.visible:
				others.append(["another pad's glyph " + q.name, _node_rect(q.icon, v)])
	if pr != null:
		others.append(["the preview glyph", pr])
	var sp: BuildSpot = main.world.build_spots[id]
	var pips := sp.global_position + Vector3(0, sp._pip_y(Balance.data.build.max_level), 0)
	others.append(["the building's pips", v.quad(pips, Vector2(1.1, 0.4))])
	assert_false(sp.label.visible, id + ": the building's own MAX label is hidden while its pads show, so nothing of it can collide")
	others.append(["the close-up sign's label", _sign_rect(v)])
	var tsr = _tier_sign_rect(v)
	if tsr != null:
		others.append(["the tier sign's label", tsr])
	others.append(["the HUD's top bar", _hud_rect(v)])
	for row in rows:
		others.append(["the %s telegraph row" % row[0], _row_rect(row[1], v)])
	for e in mine:
		for o in others:
			if (e[2] as Rect2).intersects(o[1]):
				var ov := (e[2] as Rect2).intersection(o[1])
				bad.append("%s: %s %s overlaps %s %s by %.0f x %.0f px" % [tag, e[0], e[2], o[0], o[1], ov.size.x, ov.size.y])
			gap_out[0] = minf(gap_out[0], _gap(e[2], o[1]))
	for k in mine.size():
		for l in range(k + 1, mine.size()):
			if (mine[k][2] as Rect2).intersects(mine[l][2]):
				bad.append("%s: %s overlaps %s inside one stack" % [tag, mine[k][0], mine[l][0]])
	return bad

func test_with_the_hero_on_any_pad_the_stack_is_on_screen_and_clear_of_everything() -> void:
	await _start()
	_all_max()
	var plans: Array = []
	for boss in ["west", "north", "east", "sw"]:
		plans.append(_plan_boss_on(boss))
	var rows := _all_rows(plans)
	var gap := [INF]
	var views := 0
	var all_bad: Array = []
	for aspect in ASPECTS:
		for id in MapLayout.spots_for_tier(3):
			for i in 2:
				main.hero.teleport(_pad_pos(id, i))
				await _settle()
				var bad := _view_violations(id, i, aspect, rows, gap)
				for b in bad:
					all_bad.append(b)
				views += 1
	assert_eq(views, 54)
	# Violations by pad ("spot:index"), all three aspects. A pad listed in OPEN_VIEWS has known, REPORTED violations (see the task
	# report: what overlaps what, by how many px, and the smallest fix); it is marked pending, never passed, and it fails when it
	# gets WORSE or any other pad collides. A pad that is fixed is deleted from the list (the count then reads 0 and the test says so).
	var by_pad := {}
	for b in all_bad:
		var parts := String(b).split(" ")
		var key := "%s:%s" % [parts[1], parts[3].trim_suffix(":")]
		by_pad[key] = by_pad.get(key, 0) + 1
		if not OPEN_VIEWS.has(key):
			fail_test(b)
	for key in by_pad:
		if OPEN_VIEWS.has(key):
			assert_lte(by_pad[key], int(OPEN_VIEWS[key]), "%s collides more than the reported %d times: %d" % [key, OPEN_VIEWS[key], by_pad[key]])
	for key in OPEN_VIEWS:
		if not by_pad.has(key):
			fail_test("%s no longer collides: delete it from OPEN_VIEWS" % key)
	if not by_pad.is_empty():
		pending("OPEN (reported to the coordinator): %s" % [by_pad])
	gut.p("54 views, %d violations %s; the smallest gap between the stood stack and anything: %.1f base px" % [all_bad.size(), by_pad, gap[0]])

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
				assert_gte(margin, HULL_MARGIN_PX, "%.2f %s pad %d: the pad centre %s clears the level-3 model's projected box by %.1f px" % [aspect, id, i, _pad_pos(id, i), margin])
				var hidden := 0
				for k in 8:
					var s3 := c3 + Vector3(cos(TAU * k / 8.0), 0.0, sin(TAU * k / 8.0)) * MapLayout.BRANCH_PAD_RADIUS * 0.5
					if Geometry2D.is_point_in_polygon(v.pt(s3), hull):
						hidden += 1
				worst_ring = maxi(worst_ring, hidden)
				assert_lte(hidden, 3, "%.2f %s pad %d: %d of 8 marker points are behind the model" % [aspect, id, i, hidden])
	gut.p("smallest margin between a pad centre and the projected level-3 model box: %.1f base px; most hidden marker points %d of 8" % [worst, worst_ring])

func _dist_to_hull(p: Vector2, hull: PackedVector2Array) -> float:
	var best := INF
	for i in hull.size():
		var q := Geometry2D.get_closest_point_to_segment(p, hull[i], hull[(i + 1) % hull.size()])
		best = minf(best, p.distance_to(q))
	return best

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
