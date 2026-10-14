extends GutTest
## E5 tier 3 Task 12 (spec 3.5, 6.4; D-264, D-272.1): Longbow and Volley in play, the two Spike state queries, Targeting.select_many.
## Literals: unbranched levels 8/7.0, 12/7.5, 18/8.0 at 0.5 s; Longbow 120 per 3.0 s at 9.98 m; Volley 3 x 10 per 0.5 s at 8.0 m.
## Spike scale (wave balance: hp_growth 0.15): hp_mult(12) = 1 + 0.15 x 11 = 2.65, hp_mult(15) = 1 + 0.15 x 14 = 3.1,
## so the scale at pressure 15 is 3.1 / 2.65 = 1.169811; thorns 6 x = 7.0189, pass 10 x = 11.6981.
## Since D-280 the tier-3 cap is 12, so the LIVE scale is 1.0 (hp_mult(12) / hp_mult(12)); the pressure-15 case is in-memory only
## (the cap is raised in the test), kept because it covers the formula.

const TOWER := "tower_nw"
const FENCE := "fence_n"

class FakeTarget:
	extends Node3D
	var alive := true
	var spawn_index := 1
	var generation := 1
	var hits := 0.0
	var kind: StringName = &"boar"
	func take_hit(a: float) -> void:
		hits += a

var main: Main
var spot: TowerSpot
var fired: Array = []
var _targets: Array = []

func before_each() -> void:
	Balance.reset()
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(71)
	await get_tree().process_frame
	GameState.debug_set_tier(3, 8)
	main.world.rebuild_for_tier()
	spot = main.world.build_spots[TOWER]
	fired = []
	_targets = []

func after_each() -> void:
	Balance.reset()
	GameState.new_game(1)

## Builds a spot to the top level through the real payment API.
func _build_max(id: String) -> void:
	GameState.gold = 100000
	var guard := 0
	while GameState.next_level_cost(id) >= 0 and guard < 10:
		GameState.pay_into_spot(id, 100000)
		guard += 1

func _branch(id: String, branch: StringName) -> void:
	_build_max(id)
	GameState.gold = 100000
	GameState.pay_into_branch(id, branch, 100000)

func _fake(x_off: float, idx: int) -> FakeTarget:
	var t := FakeTarget.new()
	t.spawn_index = idx
	add_child_autofree(t)
	t.global_position = Vector3(spot.global_position.x + x_off, 0.0, spot.global_position.z)
	_targets.append(t)
	return t

## The tower's attacker fed with the fake targets, stepped by hand (its own process is off).
func _arm() -> void:
	var a := spot.attacker
	a.process_mode = Node.PROCESS_MODE_DISABLED
	a.candidates = func():
		var out: Array = []
		for t in _targets:
			out.append({"position": t.global_position, "spawn_index": t.spawn_index, "ref": t})
		return out
	a.fired.connect(func(r): fired.append(r))

func _attack_once() -> void:
	spot.attacker._physics_process(1.0 / 60.0)

## Lets every projectile land (the pool's projectiles run their own physics).
func _settle() -> void:
	for i in 90:
		await get_tree().physics_frame

# --- unbranched levels -------------------------------------------------------

func test_unbranched_levels_keep_todays_literals() -> void:
	var want := [[8.0, 7.0], [12.0, 7.5], [18.0, 8.0]]
	for lv in 3:
		var st := TowerSpot.stats_for(lv + 1, &"")
		assert_eq(st.damage, want[lv][0], "level %d damage" % (lv + 1))
		assert_eq(st.attack_range, want[lv][1], "level %d range" % (lv + 1))
		assert_eq(st.interval, 0.5)
		assert_eq(st.count, 1)

func test_built_unbranched_tower_attacker_is_level_stats() -> void:
	_build_max(TOWER)
	var a := spot.attacker
	assert_eq([a.damage, a.attack_range, a.interval, a.count], [18.0, 8.0, 0.5, 1])

# --- Longbow -----------------------------------------------------------------

func test_longbow_attacker_equals_branch_balance() -> void:
	_branch(TOWER, &"longbow")
	var a := spot.attacker
	var lb := Balance.data.branches.longbow
	assert_eq(a.attack_range, lb.attack_range)
	assert_eq(a.damage, lb.damage)
	assert_eq(a.interval, lb.interval)
	assert_eq(a.count, 1)
	assert_eq([a.damage, a.attack_range, a.interval], [120.0, 9.98, 3.0], "the balance literals")

func test_longbow_hits_at_9_5_but_not_at_10_5() -> void:
	_branch(TOWER, &"longbow")
	_arm()
	var near := _fake(9.5, 1)
	_attack_once()
	await _settle()
	assert_eq(near.hits, 120.0)
	_targets.clear()
	var far := _fake(10.5, 2)
	spot.attacker._cooldown = 0.0
	spot.attacker._retarget = 0.0
	_attack_once()
	await _settle()
	assert_eq(far.hits, 0.0)

func test_unbranched_level_3_does_not_reach_9_5() -> void:
	_build_max(TOWER)
	_arm()
	var t := _fake(9.5, 1)
	_attack_once()
	await _settle()
	assert_eq(t.hits, 0.0)
	assert_eq(fired.size(), 0)

# --- Volley ------------------------------------------------------------------

func test_volley_attacker_equals_branch_balance() -> void:
	_branch(TOWER, &"volley")
	var a := spot.attacker
	assert_eq([a.damage, a.attack_range, a.interval, a.count], [10.0, 8.0, 0.5, 3])

func test_volley_five_in_range_fires_three_at_the_first_three() -> void:
	_branch(TOWER, &"volley")
	_arm()
	# Distances 6, 2, 4, 2 (spawn 9, tie with spawn 5), 7.5. Order: spawn 5 (2.0), spawn 9 (2.0), spawn 3 (4.0), 6.0, 7.5.
	var d6 := _fake(6.0, 1)
	var d2a := _fake(2.0, 9)
	var d4 := _fake(4.0, 3)
	var d2b := _fake(-2.0, 5)
	var d75 := _fake(7.5, 2)
	_attack_once()
	assert_eq(fired.size(), 3)
	assert_eq(fired, [d2b, d2a, d4], "nearest first, ties by lower spawn index")
	await _settle()
	assert_eq([d2b.hits, d2a.hits, d4.hits], [10.0, 10.0, 10.0])
	assert_eq([d6.hits, d75.hits], [0.0, 0.0])

func test_volley_fires_only_as_many_as_in_range() -> void:
	_branch(TOWER, &"volley")
	_arm()
	_fake(3.0, 1)
	_fake(5.0, 2)
	_fake(8.5, 3)  # out of range
	_attack_once()
	assert_eq(fired.size(), 2)

func test_volley_one_target_gets_one_projectile() -> void:
	_branch(TOWER, &"volley")
	_arm()
	var t := _fake(3.0, 1)
	_attack_once()
	assert_eq(fired, [t])
	await _settle()
	assert_eq(t.hits, 10.0, "never two projectiles at one target in one attack")

func test_volley_attacks_again_after_the_interval() -> void:
	_branch(TOWER, &"volley")
	_arm()
	_fake(3.0, 1)
	_fake(4.0, 2)
	for i in 31:  # t = 0 and the first tick at or after 0.5 s
		_attack_once()
	assert_eq(fired.size(), 4, "two attacks of two projectiles in 31 ticks")

func test_volley_fires_after_an_empty_scan() -> void:
	_branch(TOWER, &"volley")
	_arm()
	for i in 30:
		_attack_once()
	assert_eq(fired.size(), 0, "nothing in range")
	_fake(3.0, 1)
	var ticks := 0
	while fired.is_empty() and ticks < 40:
		_attack_once()
		ticks += 1
	assert_eq(fired.size(), 1)
	assert_lte(ticks, ceili(Balance.data.hero.retarget_interval * 60.0) + 1, "within retarget_interval and one tick")

func test_projectile_pool_covers_five_volley_towers() -> void:
	# Top tier 2 (4 towers; a two-tier build): ceil((4 x 6 + 5) x 1.2) = 35. With the tier-3 entry (5 towers; the shipped build): ceil((5 x 6 + 5) x 1.2) = 42.
	# in_flight(3, 8.0, 0.5, 16) = 3 x (floor(1.0) + 1) = 6.
	assert_eq(World.in_flight(3, 8.0, 0.5, 16.0), 6)
	assert_eq(World.pool_sizes(Balance.data).projectile, 42, "the shipped build")
	assert_gte(World.pool_sizes(Balance.data).projectile, 5 * 6 + 5)
	Balance.reset()
	assert_eq(World.pool_sizes(Balance.data).projectile, 42, "the shipped build: top tier 3")
	Balance.data.tiers.tier_costs = [0, 500]  # a two-tier build (the shipped one has three)
	assert_eq(World.pool_sizes(Balance.data).projectile, 35, "top tier 2")
	assert_eq(World.pool_sizes(Balance.data).steak, 293, "the two-tier steak pool (a pin: it must not change with the switch)")

# --- select_many -------------------------------------------------------------

func _c(x: float, z: float, idx: int) -> Dictionary:
	return {"position": Vector3(x, 0, z), "spawn_index": idx, "ref": null}

func test_select_many_first_equals_select() -> void:
	var sets := [
		[_c(3, 0, 5), _c(1, 1, 9), _c(0, 5, 1)],
		[_c(2, 0, 8), _c(-2, 0, 3)],
		[_c(-2, 0, 3), _c(2, 0, 8), _c(0, 2, 3 + 1), _c(0, -2, 0)],
		[_c(0, 4.0, 7), _c(-4.0, 0, 2), _c(5, 0, 1)],
		[_c(0, 9, 1)],
		[],
	]
	for cs in sets:
		var one := Targeting.select(Vector3.ZERO, 4.0, cs)
		var many := Targeting.select_many(Vector3.ZERO, 4.0, cs, 3)
		if one.is_empty():
			assert_eq(many.size(), 0)
		else:
			assert_eq(many[0], one)

func test_select_many_orders_and_caps() -> void:
	var cs := [_c(3, 0, 5), _c(1, 0, 9), _c(-1, 0, 2), _c(3.5, 0, 1), _c(9, 0, 7)]
	var got := Targeting.select_many(Vector3.ZERO, 4.0, cs, 3)
	var ids: Array = []
	for g in got:
		ids.append(g.spawn_index)
	assert_eq(ids, [2, 9, 5], "tie at 1.0 goes to spawn 2; the 4th in range and the one out of range are cut")
	assert_eq(Targeting.select_many(Vector3.ZERO, 4.0, cs, 10).size(), 4)

# --- save, load, new game ------------------------------------------------------

func test_branched_tower_survives_save_and_load_and_new_game_clears_it() -> void:
	_branch(TOWER, &"volley")
	var snap := GameState.to_dict()
	GameState.new_game(5)
	assert_false(spot.attacker.enabled, "no building after new_game: the tower is off")
	assert_eq(GameState.branch_of(TOWER), &"")
	GameState.from_dict(snap)
	var a := spot.attacker
	assert_eq([a.damage, a.attack_range, a.interval, a.count], [10.0, 8.0, 0.5, 3])
	# A tower rebuilt to level 3 after a new game has no branch stats.
	GameState.new_game(6)
	GameState.debug_set_tier(3, 8)
	_build_max(TOWER)
	assert_eq([a.damage, a.attack_range, a.count], [18.0, 8.0, 1])

# --- Spike queries -------------------------------------------------------------

## Three waves with different multipliers: only the FIRST sets the scale (a last-wave or max rule would read 1.5x or 2x).
func _first_wave_mult(m: float) -> void:
	GameState.lane_plan = [{"hp_mult": m}, {"hp_mult": m * 1.5}, {"hp_mult": m * 2.0}]

func _base_plan() -> void:
	_first_wave_mult(WaveMath.hp_mult(12, 0, Balance.data.wave))

func test_spike_values_at_the_base_plan() -> void:
	_branch(FENCE, &"spike")
	_base_plan()
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 6.0, 1e-6)
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 10.0, 1e-6)
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"baron"), 10.0, 1e-6)

func test_spike_values_grow_with_the_plan_pressure() -> void:
	_branch(FENCE, &"spike")
	_first_wave_mult(WaveMath.hp_mult(15, 0, Balance.data.wave))
	assert_almost_eq(Balance.data.wave.hp_growth, 0.15, 1e-9)
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 7.019, 0.001)
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 11.698, 0.001)

func test_spike_scale_reads_the_first_wave_of_a_real_plan() -> void:
	GameState.day = 20
	GameState.debug_set_tier(3, 17)
	_branch(FENCE, &"spike")
	assert_eq(GameState.lane_plan.size(), 3)
	# Pressure is capped at 12 (the ruling; it was 15), so the plan's first wave is the base plan's: thorns 6.0.
	assert_almost_eq(float(GameState.lane_plan[2].hp_mult), 3.445, 0.001)
	assert_almost_eq(float(GameState.lane_plan[0].hp_mult), 2.65, 0.001)
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 6.0, 0.001, "first wave, not the last (would be 6 x 3.445 / 2.65 = 7.80)")
	# With cap = base a real plan scales by 1.0, which cannot tell "first wave" from "last wave" or "plan ignored". Re-run the old case with
	# the cap raised in memory (15, the value before the ruling): the plan's waves differ again and the scale reads the first one.
	Balance.data.tiers.tier_cap[3] = 15
	GameState.debug_set_tier(3, 17)
	assert_almost_eq(float(GameState.lane_plan[2].hp_mult), 4.857, 0.001, "cap 15: the last wave")
	assert_almost_eq(float(GameState.lane_plan[0].hp_mult), 3.1, 0.001, "cap 15: the first wave")
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 7.019, 0.001, "cap 15: first wave, not the last (would be 10.99)")

func test_spike_scale_is_one_without_a_plan() -> void:
	_branch(FENCE, &"spike")
	GameState.lane_plan = []
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 6.0, 1e-6)

func test_pass_damage_only_for_hare_kinds() -> void:
	_branch(FENCE, &"spike")
	_base_plan()
	assert_eq(GameState.fence_pass_damage(FENCE, &"boar"), 0.0)
	assert_eq(GameState.fence_pass_damage(FENCE, &"brute"), 0.0)

func test_stone_unbranched_and_rubble_deal_nothing() -> void:
	_base_plan()
	_branch("fence_w", &"stone")
	assert_eq(GameState.fence_thorn_damage("fence_w"), 0.0)
	assert_eq(GameState.fence_pass_damage("fence_w", &"hare"), 0.0)
	_build_max(FENCE)  # unbranched level 3
	assert_eq(GameState.fence_thorn_damage(FENCE), 0.0)
	assert_eq(GameState.fence_pass_damage(FENCE, &"hare"), 0.0)
	_branch("fence_e", &"spike")
	assert_gt(GameState.fence_thorn_damage("fence_e"), 0.0)
	GameState.buildings["fence_e"].hp = 0.0  # rubble
	assert_eq(GameState.fence_thorn_damage("fence_e"), 0.0)
	assert_eq(GameState.fence_pass_damage("fence_e", &"hare"), 0.0)
	assert_eq(GameState.fence_thorn_damage("no_such_spot"), 0.0)

func test_queries_change_no_state() -> void:
	_branch(FENCE, &"spike")
	_base_plan()
	var before := GameState.to_dict()
	watch_signals(EventBus)
	GameState.fence_thorn_damage(FENCE)
	GameState.fence_pass_damage(FENCE, &"hare")
	assert_eq(GameState.to_dict(), before)
	assert_signal_not_emitted(EventBus, "building_changed")
	assert_signal_not_emitted(EventBus, "gold_changed")
	assert_signal_not_emitted(EventBus, "branch_chosen")

# --- E6 Task 7: the specialist values behind the retune flag (D-283, D-286) ---------------------------------

func _fake_kind(kind: StringName, idx: int) -> FakeTarget:
	var t := _fake(5.0, idx)
	t.kind = kind
	return t

## One Longbow shot at a lone target of `kind`; returns the damage it took.
func _longbow_shot_at(kind: StringName) -> float:
	_arm()
	var t := _fake_kind(kind, 1)
	_attack_once()
	await _settle()
	return t.hits

## Mutation: the multiplier is 1.0 for every kind (brute stays 120), or it is applied to every kind (boar gets 240).
func test_retune_on_longbow_does_double_to_a_brute_and_exactly_120_to_the_rest() -> void:
	Balance.data.tiers.retune_enabled = true
	_branch(TOWER, &"longbow")
	assert_eq(await _longbow_shot_at(&"brute"), 240.0, "120 x 2.0")
	for kind in [&"boar", &"hare", &"baron", &"boss"]:
		_targets.clear()
		spot.attacker._cooldown = 0.0
		spot.attacker._retarget = 0.0
		assert_eq(await _longbow_shot_at(kind), 120.0, "no bonus against %s" % kind)

## Mutation: the multiplier lives in the shared Attacker default or in stats_for, so an unbranched or Volley tower gets it.
func test_retune_on_unbranched_and_volley_do_their_old_damage_to_a_brute() -> void:
	Balance.data.tiers.retune_enabled = true
	_build_max(TOWER)
	assert_eq(await _longbow_shot_at(&"brute"), 18.0, "unbranched level 3: 18")
	var spot2: TowerSpot = main.world.build_spots["tower_ne"]
	_targets.clear()
	_branch("tower_ne", &"volley")
	var a := spot2.attacker
	a.process_mode = Node.PROCESS_MODE_DISABLED
	var t := FakeTarget.new()
	t.kind = &"brute"
	t.spawn_index = 1
	add_child_autofree(t)
	t.global_position = Vector3(spot2.global_position.x + 3.0, 0.0, spot2.global_position.z)
	a.candidates = func(): return [{"position": t.global_position, "spawn_index": 1, "ref": t}]
	a._physics_process(1.0 / 60.0)
	await _settle()
	assert_eq(t.hits, 10.0, "Volley: 10 per projectile, one target")
	assert_true(a.kind_mults.is_empty())

## Mutation: pass damage still 10 with the flag on, or the retune value ignores the night's scale.
func test_retune_on_spike_pass_damage_is_24_times_the_scale() -> void:
	Balance.data.tiers.retune_enabled = true
	_branch(FENCE, &"spike")
	_base_plan()
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 24.0, 1e-6)
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"baron"), 24.0, 1e-6)
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 6.0, 1e-6, "thorns unchanged")
	assert_eq(GameState.fence_pass_damage(FENCE, &"boar"), 0.0)
	# In memory: pressure 15 raises the scale to 3.1 / 2.65; 24 x 1.169811 = 28.0755.
	_first_wave_mult(WaveMath.hp_mult(15, 0, Balance.data.wave))
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 28.0755, 0.001)

## D-304: with the flag on the FIRST tier-3 night (day == tier_day) is at pressure 10, below Spike's base (pressure 12, spike_base_mult), so Spike
## scales by hp_mult(10) / hp_mult(12) = 2.35 / 2.65 = 0.886792: pass 24 x 0.886792 = 21.2830, thorns 6 x 0.886792 = 5.3208.
## Mutation: spike_base_mult follows base_pressure (2.35, scale 1.0 on the first night) or the scale is ignored.
func test_retune_on_first_tier_3_night_scales_spike_by_pressure_10_over_12() -> void:
	var tb := Balance.data.tiers
	var saved_day := GameState.day
	tb.retune_enabled = true
	GameState.day = 9
	GameState.debug_set_tier(3, 9)
	_branch(FENCE, &"spike")
	assert_eq(GameState.pressure(), 10, "first tier-3 night, flag on")
	assert_almost_eq(float(GameState.lane_plan[0].hp_mult), 2.35, 1e-6, "the plan's first wave is the pressure-10 multiplier")
	var base := BranchMath.spike_base_mult(Balance.data.wave, tb)
	assert_almost_eq(base, 2.65, 1e-9, "spike_base_mult stays the pressure-12 multiplier with the flag on")
	var scale := 2.35 / 2.65
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 24.0 * scale, 1e-6)
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 21.283, 0.001)
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"baron"), 21.283, 0.001)
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 6.0 * scale, 1e-6)
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 5.3208, 0.0001)
	# The same night with the flag off is at pressure 12, scale 1.0 (the old behaviour).
	tb.retune_enabled = false
	GameState.debug_set_tier(3, 9)
	assert_eq(GameState.pressure(), 12)
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 6.0, 1e-6)
	GameState.day = saved_day

## Flag-off pins: mutation = the retune value leaks into the default path.
func test_retune_off_pins_longbow_120_and_pass_damage_10() -> void:
	Balance.data.tiers.retune_enabled = false  # the off state, explicit since the flip (D-307)
	assert_false(TierEffects.retune_on(Balance.data.tiers))
	_branch(TOWER, &"longbow")
	assert_true(spot.attacker.kind_mults.is_empty())
	assert_eq(await _longbow_shot_at(&"brute"), 120.0)
	assert_eq(spot.attacker.interval, 3.0, "flag off: the Longbow fires every 3.0 s")
	_branch(FENCE, &"spike")
	_base_plan()
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 10.0, 1e-6)

## Mutation: the accessor ignores the flag, applies to every kind, or returns 0 for an unknown kind.
func test_longbow_kind_mult_accessor_off_on_unknown() -> void:
	var bb := Balance.data.branches
	assert_eq(BranchMath.longbow_kind_mult(&"brute", bb, false), 1.0)
	assert_eq(BranchMath.longbow_kind_mult(&"brute", bb, true), 2.0)
	assert_eq(BranchMath.longbow_kind_mult(&"boar", bb, true), 1.0)
	assert_eq(BranchMath.longbow_kind_mult(&"baron", bb, true), 1.0)
	assert_eq(BranchMath.longbow_kind_mult(&"boss", bb, true), 1.0)
	assert_eq(BranchMath.longbow_kind_mult(&"no_such_kind", bb, true), 1.0)
	assert_true(BranchMath.longbow_kind_mults(bb, false).is_empty())
	assert_eq(BranchMath.longbow_kind_mults(bb, true), {&"brute": 2.0})

## Mutation: spike_pass_base returns the retune value for any fence, or ignores the flag.
func test_spike_pass_base_accessor() -> void:
	var bb := Balance.data.branches
	assert_eq(BranchMath.spike_pass_base(bb.spike, bb, false), 10.0)
	assert_eq(BranchMath.spike_pass_base(bb.spike, bb, true), 24.0)
	assert_eq(BranchMath.spike_pass_base(bb.stone, bb, true), 0.0, "another fence keeps its own number")

# --- E6 tuning rounds 1 and 2 (D-297): Longbow interval 2.0 s behind the flag ---------------------------------------

## Mutation: the interval accessor returns the old value with the flag on (3.0), or the field is not read.
func test_retune_on_longbow_interval_is_2_0_through_apply_level() -> void:
	Balance.data.tiers.retune_enabled = true
	_branch(TOWER, &"longbow")
	assert_eq(spot.attacker.interval, 2.0)
	assert_eq([spot.attacker.damage, spot.attacker.attack_range], [120.0, 9.98], "damage and range unchanged")

## Mutation: the new interval leaks to the flag-off path (accessor ignores the flag).
func test_retune_off_longbow_interval_is_3_0_and_accessor_pins() -> void:
	Balance.data.tiers.retune_enabled = false  # the off state, explicit since the flip (D-307)
	var bb := Balance.data.branches
	_branch(TOWER, &"longbow")
	assert_eq(spot.attacker.interval, 3.0)
	assert_eq(BranchMath.tower_interval(bb.longbow, bb, false), 3.0)
	assert_eq(BranchMath.tower_interval(bb.longbow, bb, true), 2.0)
	assert_eq(BranchMath.tower_interval(bb.volley, bb, true), 0.5, "Volley keeps its interval with the flag on")
	var plain := TowerSpot.stats_for(3, &"")
	assert_eq(BranchMath.tower_interval(plain, bb, true), 0.5, "the unbranched tower keeps its interval with the flag on")

## Mutation: Volley or the unbranched tower pick up the Longbow's interval through the real path.
func test_retune_on_volley_and_unbranched_keep_their_interval() -> void:
	Balance.data.tiers.retune_enabled = true
	_build_max(TOWER)
	assert_eq(spot.attacker.interval, 0.5)
	_branch("tower_ne", &"volley")
	assert_eq((main.world.build_spots["tower_ne"] as TowerSpot).attacker.interval, 0.5)

## The interval is taken when the level is applied (like the kind multipliers): a Longbow built with the flag on has 2.0 s and
## keeps it when the flag later reads off; one built in the same world with the flag off from the start has 3.0 s.
func test_longbow_interval_is_a_snapshot_of_the_flag_at_build_time() -> void:
	Balance.data.tiers.retune_enabled = true
	_branch(TOWER, &"longbow")
	assert_eq(spot.attacker.interval, 2.0)
	Balance.data.tiers.retune_enabled = false
	assert_eq(spot.attacker.interval, 2.0, "not re-read after the toggle")
	_arm()
	var t := _fake(5.0, 1)
	_attack_once()
	assert_eq(spot.attacker._cooldown, 2.0, "a shot after the toggle still cools down 2.0 s")
	_branch("tower_ne", &"longbow")
	assert_eq((main.world.build_spots["tower_ne"] as TowerSpot).attacker.interval, 3.0, "flag off at build: the old interval")

## Mutation: the retune interval applies to any Longbow-looking stats object, not the balance's own.
func test_retune_on_a_fresh_longbow_stats_object_keeps_3_0() -> void:
	var bb := Balance.data.branches
	assert_eq(BranchMath.tower_interval(BranchBalance._longbow(), bb, true), 3.0)
