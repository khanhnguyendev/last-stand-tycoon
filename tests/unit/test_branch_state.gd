extends GutTest
## E5 tier 3 spec 3.6: branch state on buildings, pay-and-refund rules, the dawn reset, damage by kind, the fail snapshot.
## The build's top tier is 2, so each test appends the tier-3 cost entry (Balance.reset() in after_each drops it).

const TOWER := "tower_nw"
const FENCE := "fence_n"
const FENCE_B := "fence_w"

func before_each() -> void:
	Balance.reset()
	Balance.data.tiers.tier_costs.append(1500)
	GameState.new_game(20261007)
	GameState.day = 10
	GameState.debug_set_tier(3, 8)
	GameState.gold = 0

func after_each() -> void:
	Balance.reset()
	GameState.new_game(1)

## Test-only setup writes: a building standing at the top level.
func _max(id: String) -> void:
	var b: Dictionary = GameState.buildings[id]
	b.level = Balance.data.build.max_level
	if MapLayout.spot_kind(id) == "fence":
		b.hp = GameState.fence_max_hp(int(b.level))

## Gold in the purse plus gold sitting on branch pads: only branch purchases may change this, never a payment.
func _total() -> int:
	var t := GameState.gold
	for id in GameState.buildings:
		for k in GameState.buildings[id].branch_paid:
			t += int(GameState.buildings[id].branch_paid[k])
	return t

func _snapshot_of_state() -> Dictionary:
	return {"gold": GameState.gold, "buildings": GameState.buildings.duplicate(true)}

# --- shape and read API -----------------------------------------------------

func test_every_building_has_the_full_shape() -> void:
	for id in GameState.buildings:
		assert_eq(GameState.buildings[id].keys().size(), 5, id)
		assert_eq(GameState.buildings[id].branch, "", id)
		assert_eq(GameState.buildings[id].branch_paid, {}, id)
	assert_true(GameState.buildings.has("fence_sw"), "debug_set_tier added the tier-3 spots")
	assert_eq(GameState.buildings.fence_sw.keys().size(), 5, "debug_set_tier uses the one shape")

func test_costs_and_options_follow_the_spot_kind() -> void:
	assert_eq(GameState.branch_cost(TOWER), 500)
	assert_eq(GameState.branch_cost(FENCE), 300)
	assert_eq(GameState.branch_options(TOWER), [&"longbow", &"volley"] as Array[StringName])
	assert_eq(GameState.branch_options(FENCE), [&"stone", &"spike"] as Array[StringName])
	assert_eq(GameState.branch_of(TOWER), &"")

# --- payment ------------------------------------------------------------------

func test_full_payment_commits_and_a_partial_one_does_not() -> void:
	_max(TOWER)
	GameState.gold = 1000
	assert_eq(GameState.pay_into_branch(TOWER, &"longbow", 499), 499)
	assert_eq(GameState.branch_of(TOWER), &"", "cost - 1 does not commit")
	assert_eq(GameState.buildings[TOWER].branch_paid, {"longbow": 499})
	assert_eq(GameState.branch_remaining(TOWER, &"longbow"), 1)
	assert_eq(GameState.pay_into_branch(TOWER, &"longbow", 10), 1, "only the remaining 1 is taken")
	assert_eq(GameState.branch_of(TOWER), &"longbow")
	assert_eq(GameState.buildings[TOWER].branch_paid, {})
	assert_eq(GameState.gold, 500)

func test_payment_is_clamped_to_gold() -> void:
	_max(FENCE)
	GameState.gold = 40
	assert_eq(GameState.pay_into_branch(FENCE, &"stone", 300), 40)
	assert_eq(GameState.gold, 0)
	assert_eq(GameState.pay_into_branch(FENCE, &"stone", 300), 0, "no gold: nothing taken")
	assert_eq(GameState.buildings[FENCE].branch_paid, {"stone": 40})

func test_completing_one_pad_refunds_the_other_pads_partial_exactly() -> void:
	_max(FENCE)
	GameState.gold = 1000
	var totals: Array[int] = [_total()]
	GameState.pay_into_branch(FENCE, &"stone", 120)
	totals.append(_total())
	GameState.pay_into_branch(FENCE, &"spike", 77)
	totals.append(_total())
	assert_eq(GameState.gold, 1000 - 120 - 77)
	watch_signals(EventBus)
	var taken := GameState.pay_into_branch(FENCE, &"stone", 1000)
	totals.append(_total())
	assert_eq(taken, 180)
	assert_eq(GameState.gold, 1000 - 120 - 77 - 180 + 77, "the spike pad's 77 came back, exactly")
	assert_eq(GameState.buildings[FENCE].branch_paid, {})
	assert_eq(totals, [1000, 1000, 1000, 1000 - 300], "gold + paid is conserved by every payment; only the 300 price leaves")
	assert_signal_emit_count(EventBus, "branch_chosen", 1)
	assert_signal_emitted_with_parameters(EventBus, "branch_chosen", [StringName(FENCE), &"stone"])
	assert_signal_emit_count(EventBus, "branch_refunded", 1)
	assert_signal_emitted_with_parameters(EventBus, "branch_refunded", [StringName(FENCE), 77])

func test_no_refund_signal_when_the_other_pad_is_empty() -> void:
	_max(TOWER)
	GameState.gold = 500
	watch_signals(EventBus)
	GameState.pay_into_branch(TOWER, &"volley", 500)
	assert_signal_emit_count(EventBus, "branch_chosen", 1)
	assert_signal_not_emitted(EventBus, "branch_refunded")

func test_gold_changed_reports_the_payment_and_the_refund() -> void:
	_max(TOWER)
	GameState.gold = 1000
	GameState.pay_into_branch(TOWER, &"volley", 200)
	var seen := []
	var f := func(g: int, d: int): seen.append([g, d])
	EventBus.gold_changed.connect(f)
	GameState.pay_into_branch(TOWER, &"longbow", 500)
	EventBus.gold_changed.disconnect(f)
	assert_eq(seen, [[300, -500], [500, 200]])

func test_a_partial_payment_survives_dawn_and_the_save_round_trip() -> void:
	_max(TOWER)
	GameState.gold = 300
	GameState.pay_into_branch(TOWER, &"longbow", 123)
	GameState.heal_for_dawn()
	GameState.reset_destroyed_fences()
	GameState.advance_day()
	assert_eq(GameState.buildings[TOWER].branch_paid, {"longbow": 123})
	var d := GameState.to_dict()
	GameState.new_game(5)
	GameState.debug_set_tier(3, 1)
	GameState.from_dict(d)
	assert_eq(GameState.buildings[TOWER].branch_paid, {"longbow": 123})
	assert_eq(GameState.gold, 177)

# --- refusals -----------------------------------------------------------------

func _assert_refused(spot: String, branch: StringName, why: String) -> void:
	GameState.gold = 2000
	var before := _snapshot_of_state()
	clear_signal_watcher()
	watch_signals(EventBus)
	assert_eq(GameState.pay_into_branch(spot, branch, 2000), 0, why)
	assert_eq(GameState.gold, before.gold, why + ": gold")
	assert_eq(GameState.buildings, before.buildings, why + ": state")
	assert_signal_not_emitted(EventBus, "gold_changed")
	assert_signal_not_emitted(EventBus, "branch_chosen")

func test_refusals_change_nothing() -> void:
	_max(TOWER)
	_max(FENCE)
	_assert_refused(TOWER, &"stone", "a fence branch on a tower")
	_assert_refused(FENCE, &"longbow", "a tower branch on a fence")
	_assert_refused(TOWER, &"nonsense", "unknown branch")
	_assert_refused(TOWER, &"", "empty branch id")
	GameState.buildings[FENCE_B].level = 2
	GameState.buildings[FENCE_B].hp = 100.0
	_assert_refused(FENCE_B, &"stone", "below max level")
	GameState.buildings[FENCE].hp = 0.0
	_assert_refused(FENCE, &"stone", "a rubble fence")
	GameState.pay_into_branch(TOWER, &"longbow", 500)
	_assert_refused(TOWER, &"volley", "already branched, other branch")
	_assert_refused(TOWER, &"longbow", "already branched, same branch")

func test_below_tier_3_is_refused() -> void:
	_max(TOWER)
	GameState.debug_set_tier(2, 5)
	assert_false(GameState.can_branch(TOWER))
	_assert_refused(TOWER, &"longbow", "tier 2")

func test_can_branch_rules() -> void:
	assert_false(GameState.can_branch(TOWER), "level 0")
	_max(TOWER)
	assert_true(GameState.can_branch(TOWER))
	_max(FENCE)
	assert_true(GameState.can_branch(FENCE))
	GameState.buildings[FENCE].hp = 0.0
	assert_false(GameState.can_branch(FENCE), "rubble")
	assert_eq(GameState.branch_remaining(FENCE, &"stone"), -1)
	GameState.gold = 500
	GameState.pay_into_branch(TOWER, &"volley", 500)
	assert_false(GameState.can_branch(TOWER), "already branched")

# --- stone repairs, heal, damage by kind ------------------------------------------

func test_choosing_stone_repairs_to_the_new_maximum_and_spike_keeps_the_level_3_hp() -> void:
	_max(FENCE)
	_max(FENCE_B)
	GameState.damage_fence(FENCE, 200.0)
	GameState.damage_fence(FENCE_B, 200.0)
	GameState.gold = 600
	GameState.pay_into_branch(FENCE, &"stone", 300)
	GameState.pay_into_branch(FENCE_B, &"spike", 300)
	assert_eq(GameState.buildings[FENCE].hp, 640.0, "stone: full repair at the new maximum")
	assert_eq(GameState.buildings[FENCE_B].hp, 120.0, "spike: the damaged hp is untouched")

func test_a_surviving_branched_fence_heals_to_its_branch_maximum() -> void:
	_max(FENCE)
	_max(FENCE_B)
	GameState.gold = 600
	GameState.pay_into_branch(FENCE, &"stone", 300)
	GameState.pay_into_branch(FENCE_B, &"spike", 300)
	GameState.damage_fence(FENCE, 500.0)
	GameState.damage_fence(FENCE_B, 100.0)
	GameState.heal_for_dawn()
	assert_eq(GameState.buildings[FENCE].hp, 640.0, "stone heals to 640, not the level-3 320")
	assert_eq(GameState.buildings[FENCE_B].hp, 320.0)
	GameState.reset_destroyed_fences()
	assert_eq(GameState.branch_of(FENCE), &"stone", "a surviving fence keeps its branch")
	assert_eq(GameState.branch_of(FENCE_B), &"spike")

func test_stone_halves_brute_damage_and_nothing_else() -> void:
	_max(FENCE)
	GameState.gold = 300
	GameState.pay_into_branch(FENCE, &"stone", 300)
	GameState.damage_fence(FENCE, 100.0, &"brute")
	assert_eq(GameState.buildings[FENCE].hp, 640.0 - 50.0, "brute x 0.5")
	GameState.damage_fence(FENCE, 100.0, &"boar")
	assert_eq(GameState.buildings[FENCE].hp, 590.0 - 100.0, "a Boar's hit is not reduced")
	GameState.damage_fence(FENCE, 10.0)
	assert_eq(GameState.buildings[FENCE].hp, 480.0, "no kind: no reduction")

func test_spike_and_unbranched_take_full_brute_damage() -> void:
	_max(FENCE)
	_max(FENCE_B)
	GameState.gold = 300
	GameState.pay_into_branch(FENCE, &"spike", 300)
	GameState.damage_fence(FENCE, 100.0, &"brute")
	assert_eq(GameState.buildings[FENCE].hp, 220.0)
	GameState.damage_fence(FENCE_B, 100.0, &"brute")
	assert_eq(GameState.buildings[FENCE_B].hp, 220.0)

# --- dawn: a destroyed fence -----------------------------------------------------------

func test_a_destroyed_branched_fence_loses_level_and_branch_at_dawn() -> void:
	_max(FENCE)
	GameState.gold = 300
	GameState.pay_into_branch(FENCE, &"stone", 300)
	GameState.damage_fence(FENCE, 1e6)
	var g := GameState.gold
	GameState.reset_destroyed_fences()
	assert_eq(GameState.buildings[FENCE], {"level": 0, "paid": 0, "hp": 0.0, "branch": "", "branch_paid": {}})
	assert_eq(GameState.gold, g, "nothing was on its pads: no gold appears")

func test_a_destroyed_fence_refunds_its_pad_payments_at_dawn() -> void:
	_max(FENCE)
	_max(FENCE_B)
	GameState.gold = 1000
	GameState.pay_into_branch(FENCE, &"stone", 100)
	GameState.pay_into_branch(FENCE, &"spike", 55)
	GameState.pay_into_branch(FENCE_B, &"stone", 90)
	GameState.damage_fence(FENCE, 1e6)  # fence_w survives with its payment
	var before := _total()
	watch_signals(EventBus)
	GameState.reset_destroyed_fences()
	assert_eq(GameState.gold, 1000 - 100 - 55 - 90 + 155)
	assert_eq(GameState.buildings[FENCE].branch_paid, {})
	assert_eq(GameState.buildings[FENCE_B].branch_paid, {"stone": 90}, "the standing fence keeps its payment")
	assert_eq(_total(), before, "no gold appears or disappears")
	assert_signal_emit_count(EventBus, "branch_refunded", 1)
	assert_signal_emitted_with_parameters(EventBus, "branch_refunded", [StringName(FENCE), 155])

# --- the fail snapshot ------------------------------------------------------------------------
## PhaseController takes `snapshot = GameState.to_dict()` at close-up and restores it with `GameState.from_dict(snapshot)`
## on a failed night (world/phase_controller.gd). A Main-level test needs the tier-3 world (a later task), so this runs the
## same two calls on the state; test_save_v6 proves the same dictionary survives encode/decode.

func test_a_failed_night_restores_the_branch_and_the_pad_payments_of_the_day() -> void:
	_max(TOWER)
	_max(FENCE)
	GameState.gold = 1500
	GameState.pay_into_branch(TOWER, &"longbow", 500)
	GameState.pay_into_branch(FENCE, &"stone", 140)
	var snapshot := GameState.to_dict()  # close-up
	snapshot.resume_phase = "DAY"
	# the night: the fence is wrecked, gold is earned
	GameState.damage_fence(FENCE, 1e6)
	GameState.reset_destroyed_fences()
	GameState.add_gold(77)
	assert_eq(GameState.buildings[FENCE].branch_paid, {}, "the night's dawn changed the live state")
	GameState.from_dict(snapshot)  # the failed night
	assert_eq(GameState.branch_of(TOWER), &"longbow")
	assert_eq(GameState.buildings[TOWER].branch_paid, {})
	assert_eq(GameState.buildings[FENCE].branch_paid, {"stone": 140})
	assert_eq(GameState.buildings[FENCE].level, 3)
	assert_eq(GameState.gold, 1500 - 500 - 140)
