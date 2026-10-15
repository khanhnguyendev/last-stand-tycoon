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

## A target with no `kind` property at all.
class FakeNoKind:
	extends Node3D
	var alive := true
	var spawn_index := 1
	var generation := 1
	var hits := 0.0
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
	assert_eq([a.damage, a.attack_range, a.interval], [120.0, 9.98, 2.0], "the balance literals (E6: the Longbow fires every 2.0 s)")

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
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 24.0, 1e-6)
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"baron"), 24.0, 1e-6)

func test_spike_values_grow_with_the_plan_pressure() -> void:
	_branch(FENCE, &"spike")
	_first_wave_mult(WaveMath.hp_mult(15, 0, Balance.data.wave))
	assert_almost_eq(Balance.data.wave.hp_growth, 0.15, 1e-9)
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 7.019, 0.001)
	# scale = hp_mult(15) / hp_mult(12) = 3.1 / 2.65 = 1.169811; 24 x 1.169811 = 28.0755 (it was 10 x 1.169811 = 11.698 before the retune)
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 28.0755, 0.001)

func test_spike_scale_reads_the_first_wave_of_a_real_plan() -> void:
	GameState.day = 20
	GameState.debug_set_tier(3, 17)
	_branch(FENCE, &"spike")
	assert_eq(GameState.lane_plan.size(), 3)
	# Day 20 of a tier entered on day 17 is the tier's fourth night: pressure 10 + 3 = 13, capped at 12, so the plan's first wave is the base plan's: thorns 6.0.
	assert_eq(GameState.pressure(), 12)
	assert_almost_eq(float(GameState.lane_plan[2].hp_mult), 3.445, 0.001)
	assert_almost_eq(float(GameState.lane_plan[0].hp_mult), 2.65, 0.001)
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 6.0, 0.001, "first wave, not the last (would be 6 x 3.445 / 2.65 = 7.80)")
	# At the cap the scale is 1.0, which cannot tell "first wave" from "last wave" or "plan ignored". Re-run it with the cap raised in memory to 15
	# (Spike's quoted base stays at pressure 12, hp_mult(12) = 2.65, whatever the cap): the night is at pressure 10 + 3 = 13, the plan's waves differ again and the scale reads the first one.
	Balance.data.tiers.tier_cap[3] = 15
	GameState.debug_set_tier(3, 17)
	assert_eq(GameState.pressure(), 13, "cap 15, tier base 10, the fourth night")
	var first := float(GameState.lane_plan[0].hp_mult)
	var last := float(GameState.lane_plan[2].hp_mult)
	assert_almost_eq(first, 1.0 + 0.15 * 12.0, 0.001, "cap 15: the first wave at pressure 13 (1 + 0.15 x 12 = 2.8)")
	assert_gt(last, first, "cap 15: the last wave is bigger")
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 6.0 * 2.8 / 2.65, 0.001, "cap 15: first wave, 6 x 2.8 / 2.65 = 6.340")
	assert_false(is_equal_approx(GameState.fence_thorn_damage(FENCE), 6.0 * last / 2.65), "not the last wave's multiplier")

func test_spike_base_mult_ignores_a_tier_cap_override() -> void:
	var before := BranchMath.spike_base_mult(Balance.data.wave, Balance.data.branches)
	Balance.data.tiers.tier_cap[3] = 15
	assert_eq(BranchMath.spike_base_mult(Balance.data.wave, Balance.data.branches), before, "the quote does not move with tier_cap")
	assert_almost_eq(before, 2.65, 1e-9, "pressure 12")

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

# --- E6 Task 7: the specialist values (D-283, D-286) ---------------------------------

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
func test_longbow_does_double_to_a_brute_36_to_a_hare_and_exactly_120_to_the_rest() -> void:
	_branch(TOWER, &"longbow")
	assert_eq(await _longbow_shot_at(&"brute"), 240.0, "120 x 2.0")
	for kind in [&"boar", &"boss"]:
		_targets.clear()
		spot.attacker._cooldown = 0.0
		spot.attacker._retarget = 0.0
		assert_eq(await _longbow_shot_at(kind), 120.0, "no bonus against %s" % kind)
	for kind in [&"hare", &"baron"]:
		_targets.clear()
		spot.attacker._cooldown = 0.0
		spot.attacker._retarget = 0.0
		assert_almost_eq(await _longbow_shot_at(kind), 36.0, 1e-4, "E8: 120 x 0.3 against %s (the Baron is a hare)" % kind)

## Mutation: the multiplier lives in the shared Attacker default or in stats_for, so an unbranched or Volley tower gets it.
func test_unbranched_does_its_old_damage_to_a_brute_and_volley_three_tenths_of_its_own() -> void:
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
	assert_almost_eq(t.hits, 3.0, 1e-4, "E8: Volley 10 x 0.3 against a brute, one target")
	assert_eq(a.kind_mults, {&"brute": 0.3}, "the Volley carries its own table")

## Mutation: pass damage still 10, or the value ignores the night's scale.
func test_spike_pass_damage_is_24_times_the_scale() -> void:
	_branch(FENCE, &"spike")
	_base_plan()
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 24.0, 1e-6)
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"baron"), 24.0, 1e-6)
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 6.0, 1e-6, "thorns unchanged")
	assert_eq(GameState.fence_pass_damage(FENCE, &"boar"), 0.0)
	# In memory: pressure 15 raises the scale to 3.1 / 2.65; 24 x 1.169811 = 28.0755.
	_first_wave_mult(WaveMath.hp_mult(15, 0, Balance.data.wave))
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 28.0755, 0.001)

## D-304: the FIRST tier-3 night (day == tier_day) is at pressure 10, below Spike's base (pressure 12, the tier's cap, spike_base_mult), so Spike
## scales by hp_mult(10) / hp_mult(12) = 2.35 / 2.65 = 0.886792: pass 24 x 0.886792 = 21.2830, thorns 6 x 0.886792 = 5.3208.
## Mutation: spike_base_mult follows tier_base (2.35, scale 1.0 on the first night) or the scale is ignored.
func test_first_tier_3_night_scales_spike_by_pressure_10_over_12() -> void:
	var saved_day := GameState.day
	GameState.day = 9
	GameState.debug_set_tier(3, 9)
	_branch(FENCE, &"spike")
	assert_eq(GameState.pressure(), 10, "first tier-3 night")
	assert_almost_eq(float(GameState.lane_plan[0].hp_mult), 2.35, 1e-6, "the plan's first wave is the pressure-10 multiplier")
	var base := BranchMath.spike_base_mult(Balance.data.wave, Balance.data.branches)
	assert_almost_eq(base, 2.65, 1e-9, "spike_base_mult is the pressure-12 multiplier (the cap), not the first night's")
	var scale := 2.35 / 2.65
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 24.0 * scale, 1e-6)
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 21.283, 0.001)
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"baron"), 21.283, 0.001)
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 6.0 * scale, 1e-6)
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 5.3208, 0.0001)
	GameState.day = saved_day

## Mutation: the Longbow table has an entry for any other kind or lacks the brute / hare entry; the Volley table has anything but its brute entry; the unbranched tower carries a table.
func test_longbow_kind_mults_table() -> void:
	var bb := Balance.data.branches
	assert_eq(bb.longbow.kind_mults, {&"brute": 2.0, &"hare": 0.3})
	for kind in [&"boar", &"boss", &"no_such_kind"]:
		assert_eq(float(bb.longbow.kind_mults.get(kind, 1.0)), 1.0, "no multiplier for %s" % kind)
	assert_eq(bb.volley.kind_mults, {&"brute": 0.3})
	for kind in [&"boar", &"hare", &"baron", &"boss", &"no_such_kind"]:
		assert_eq(float(bb.volley.kind_mults.get(kind, 1.0)), 1.0, "Volley: no multiplier for %s" % kind)
	assert_true(TowerSpot.stats_for(3, &"").kind_mults.is_empty())

## Mutation: pass damage is another number, or another fence has one.
func test_spike_pass_damage_stat() -> void:
	var bb := Balance.data.branches
	assert_eq(bb.spike.pass_damage, 24.0)
	assert_eq(BranchMath.pass_damage(bb.spike, &"hare", 1.0), 24.0)
	assert_eq(BranchMath.pass_damage(bb.spike, &"boar", 1.0), 0.0)
	assert_eq(BranchMath.pass_damage(bb.stone, &"hare", 1.0), 0.0, "another fence has none")

# --- E6 tuning rounds 1 and 2 (D-297): Longbow interval 2.0 s ---------------------------------------------------------

## Mutation: the Longbow's stats carry the old value (3.0), or the attacker does not read them.
func test_longbow_interval_is_2_0_through_apply_level() -> void:
	_branch(TOWER, &"longbow")
	assert_eq(spot.attacker.interval, 2.0)
	assert_eq([spot.attacker.damage, spot.attacker.attack_range], [120.0, 9.98], "damage and range unchanged")

## Mutation: Volley or the unbranched tower pick up the Longbow's interval.
func test_the_other_towers_keep_their_interval_in_the_stats() -> void:
	var bb := Balance.data.branches
	assert_eq(bb.longbow.interval, 2.0)
	assert_eq(bb.volley.interval, 0.5, "Volley keeps its interval")
	assert_eq(TowerSpot.stats_for(3, &"").interval, 0.5, "the unbranched tower keeps its interval")

## Mutation: Volley or the unbranched tower pick up the Longbow's interval through the real path.
func test_volley_and_unbranched_keep_their_interval() -> void:
	_build_max(TOWER)
	assert_eq(spot.attacker.interval, 0.5)
	_branch("tower_ne", &"volley")
	assert_eq((main.world.build_spots["tower_ne"] as TowerSpot).attacker.interval, 0.5)

# --- E8 Task 1: kind classes (D-314.10) -----------------------------------------------

## Mutation: the attacker looks the table up by the raw kind (the Baron then takes 120).
func test_a_longbow_hare_multiplier_applies_to_a_hare_and_to_a_baron() -> void:
	Balance.data.branches.longbow.kind_mults[&"hare"] = 0.5
	_branch(TOWER, &"longbow")
	assert_eq(await _longbow_shot_at(&"hare"), 60.0, "120 x 0.5")
	_targets.clear()
	spot.attacker._cooldown = 0.0
	spot.attacker._retarget = 0.0
	assert_eq(await _longbow_shot_at(&"baron"), 60.0, "the Baron is a hare")

## Mutation: damage_fence looks the table up by the raw kind (the Baron then does the plain hit).
func test_a_spike_hare_multiplier_applies_to_a_baron_hit_on_the_fence() -> void:
	Balance.data.branches.spike.damage_taken_mult_by_kind[&"hare"] = 2.0
	_branch(FENCE, &"spike")
	var before := float(GameState.buildings[FENCE].hp)
	GameState.damage_fence(FENCE, 10.0, &"baron")
	assert_almost_eq(before - float(GameState.buildings[FENCE].hp), 20.0, 1e-6, "10 x 2.0")
	GameState.damage_fence(FENCE, 10.0, &"hare")
	assert_almost_eq(before - float(GameState.buildings[FENCE].hp), 40.0, 1e-6, "a hare takes the same")
	GameState.damage_fence(FENCE, 10.0, &"boar")
	assert_almost_eq(before - float(GameState.buildings[FENCE].hp), 50.0, 1e-6, "another kind is unchanged")

## Mutation: the tier bot's clear-time estimate reads the raw kind (the Baron then keeps 120).
func test_tier_bot_tower_dps_uses_the_baron_class() -> void:
	var st := TowerBranchStats.new()
	st.damage = 120.0
	st.interval = 2.0
	st.count = 1
	st.kind_mults = {&"hare": 0.5}
	assert_almost_eq(TierBot.tower_dps(st, [1000.0], [&"baron"]), 30.0, 1e-6, "120 x 0.5 per 2.0 s")
	assert_almost_eq(TierBot.tower_dps(st, [1000.0], [&"hare"]), 30.0, 1e-6)
	assert_almost_eq(TierBot.tower_dps(st, [1000.0], [&"boar"]), 60.0, 1e-6)

## Mutation: BranchMath.pass_damage compares the raw kind (the Baron then takes 0) or skips the class (a boar takes 24).
func test_pass_damage_looks_the_kind_up_by_class() -> void:
	var f := FenceBranchStats.new()
	f.pass_damage = 24.0
	f.pass_kinds = [&"hare"]
	assert_almost_eq(BranchMath.pass_damage(f, &"baron", 1.0), 24.0, 1e-6, "the Baron is a hare")
	assert_almost_eq(BranchMath.pass_damage(f, &"hare", 1.0), 24.0, 1e-6)
	assert_eq(BranchMath.pass_damage(f, &"boar", 1.0), 0.0)

## Mutation: fence_hold_seconds reads the raw kind (the Baron then holds as long as a boar).
func test_fence_hold_seconds_looks_the_kind_up_by_class() -> void:
	var f := FenceBranchStats.new()
	f.damage_taken_mult_by_kind = {&"hare": 2.0}
	var m := MonsterStats.new()
	m.damage = 10.0
	m.attack_interval = 1.0
	m.fence_damage_mult = 1.0
	var plain := BranchMath.fence_hold_seconds(320.0, m, f, &"boar")
	assert_almost_eq(BranchMath.fence_hold_seconds(320.0, m, f, &"baron"), plain / 2.0, 1e-6, "the Baron takes the hare's x2.0")
	assert_almost_eq(BranchMath.fence_hold_seconds(320.0, m, f, &"hare"), plain / 2.0, 1e-6)

## Mutation: Attacker._damage_against reads target.kind without the null guard (a target with no kind errors or loses its damage).
func test_a_target_without_a_kind_takes_full_damage_from_a_branched_tower() -> void:
	_branch(TOWER, &"longbow")
	_arm()
	assert_false(spot.attacker.kind_mults.is_empty(), "precondition: the Longbow carries a table")
	var t := FakeNoKind.new()
	add_child_autofree(t)
	t.global_position = Vector3(spot.global_position.x + 5.0, 0.0, spot.global_position.z)
	_targets.append(t)
	_attack_once()
	await _settle()
	assert_eq(t.hits, 120.0, "no kind means no multiplier: full damage")
