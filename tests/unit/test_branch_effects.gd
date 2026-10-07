extends GutTest
## E5 tier 3 Task 12 (spec 3.5, 6.4; D-264, D-272.1): Longbow and Volley in play, the two Spike state queries, Targeting.select_many.
## Literals: unbranched levels 8/7.0, 12/7.5, 18/8.0 at 0.5 s; Longbow 120 per 3.0 s at 9.98 m; Volley 3 x 10 per 0.5 s at 8.0 m.
## Spike scale (wave balance: hp_growth 0.15): hp_mult(12) = 1 + 0.15 x 11 = 2.65, hp_mult(15) = 1 + 0.15 x 14 = 3.1,
## so the scale at pressure 15 is 3.1 / 2.65 = 1.169811; thorns 6 x = 7.0189, pass 10 x = 11.6981.

const TOWER := "tower_nw"
const FENCE := "fence_n"

class FakeTarget:
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

func _first_wave_mult(m: float) -> void:
	GameState.lane_plan = [{"hp_mult": m}]

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
