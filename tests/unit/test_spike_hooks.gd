extends GutTest
## E5 tier 3 (spec 6.4, D-264, D-272.1): what a Spike fence does to monsters. Thorns: a monster whose hit lands on the fence
## takes `fence_thorn_damage` after its own hit. Pass damage: a monster with no fence entry in its priority list takes
## `fence_pass_damage` ONCE when it crosses the fence's line; its path and timing do not change.
## Literals at spike scale 1.0 (the first wave at the tier-3 base multiplier): thorns 6.0, pass 10.0 (hare and baron only).
## A Boar's hit is 5.0 every 1.0 s; a brute's is 8.0 x 4 on a fence. The fence line is path length - 4.0 (FENCE_OFFSET_FROM_END).

const DT := 1.0 / 60.0
const FENCE := "fence_n"
const BIG := 1000.0  ## hp multiplier that keeps a monster alive through any test

var main: Main
var wd: WaveDirector

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
	# Scale exactly 1.0: the plan's first wave carries the tier-3 base multiplier (spike_scale = now / base).
	GameState.lane_plan[0].hp_mult = BranchMath.spike_base_mult(Balance.data.wave, Balance.data.tiers)
	wd = main.world.wave_director

func after_each() -> void:
	Balance.reset()
	GameState.new_game(1)

func _build_max(id: String) -> void:
	GameState.gold = 100000
	var guard := 0
	while GameState.next_level_cost(id) >= 0 and guard < 10:
		GameState.pay_into_spot(id, 100000)
		guard += 1

func _branch(branch: StringName) -> void:
	_build_max(FENCE)
	GameState.gold = 100000
	if branch != &"":
		GameState.pay_into_branch(FENCE, branch, 100000)

## A pooled monster stepped by hand (its own process is off).
func _mon(kind: StringName, hp_mult := BIG, lane := "north") -> Boar:
	var b := wd.debug_spawn(lane, 0.0, hp_mult, kind)
	b.set_physics_process(false)
	return b

func _step(b: Boar, ticks: int) -> void:
	for i in ticks:
		b._physics_process(DT)

func _lost(b: Boar) -> float:
	return b.health.max_hp - b.health.hp

## Where the fence line is on a lane's path.
func _line(b: Boar) -> float:
	return b.path_length() - MapLayout.FENCE_OFFSET_FROM_END

func _at_stop(b: Boar) -> void:
	b.dist = TargetProviders.fence_stop_dist(b)
	b._update_position()

func _walk_until(b: Boar, dist: float) -> void:
	var guard := 0
	while b.dist < dist and b.alive and guard < 4000:
		b._physics_process(DT)
		guard += 1

# --- thorns ---

func test_a_spike_fence_hurts_a_boar_the_literal_thorn_amount_per_hit() -> void:
	_branch(&"spike")
	assert_almost_eq(GameState.fence_thorn_damage(FENCE), 6.0, 1e-4, "scale 1.0: the literal derived from BranchBalance")
	var b := _mon(&"boar")
	_at_stop(b)
	_step(b, 59)
	assert_almost_eq(_lost(b), 0.0, 1e-6, "no hit yet: no thorns, and no pass damage on the way")
	_step(b, 1)
	assert_almost_eq(_lost(b), 6.0, 1e-4, "one hit, one thorn (a per-tick or doubled thorn fails)")
	_step(b, 120)
	assert_almost_eq(_lost(b), 18.0, 1e-4, "three hits, three thorns")

func test_a_brute_takes_thorns_per_hit_not_per_damage_dealt() -> void:
	_branch(&"spike")
	var b := _mon(&"brute")
	_at_stop(b)
	_step(b, 60)
	assert_almost_eq(_lost(b), 6.0, 1e-4, "its x4 fence damage does not multiply the thorns")

func test_stone_and_plain_fences_do_not_thorn() -> void:
	for branch in [&"stone", &""]:
		GameState.buildings[FENCE] = GameState._new_building()  # a fresh, unbuilt fence
		_branch(branch)
		var b := _mon(&"boar")
		_at_stop(b)
		_step(b, 120)
		assert_almost_eq(_lost(b), 0.0, 1e-6, "no thorns at a '%s' fence" % branch)
		assert_lt(float(GameState.buildings[FENCE].hp), float(GameState.fence_max_hp(3, branch)), "the boar did hit the fence")

func test_the_hit_that_destroys_the_fence_still_thorns() -> void:
	_branch(&"spike")
	GameState.buildings[FENCE].hp = 3.0  # test-only: the next hit (5.0) breaks it
	var b := _mon(&"boar")
	_at_stop(b)
	_step(b, 60)
	assert_eq(float(GameState.buildings[FENCE].hp), 0.0, "the fence fell")
	assert_almost_eq(_lost(b), 6.0, 1e-4, "it took the hit that broke it: the thorn was read before the fence fell")
	_step(b, 60)
	assert_almost_eq(_lost(b), 6.0, 1e-4, "rubble does not thorn the next hit")

func test_a_monster_killed_by_thorns_counts_one_kill_and_drops_its_steaks() -> void:
	_branch(&"spike")
	var b := _mon(&"boar", 0.05)  # 1.5 hp: its first thorn kills it
	_at_stop(b)
	var steaks0: int = main.world.steak_pool.active().size()
	var killed: Array = []
	var cb := func(i, l, p, k): killed.append([i, k])
	EventBus.enemy_killed.connect(cb)
	_step(b, 60)
	var fence_hp := float(GameState.buildings[FENCE].hp)
	_step(b, 120)  # dead: more ticks change nothing
	EventBus.enemy_killed.disconnect(cb)
	assert_false(b.alive)
	assert_eq(float(GameState.buildings[FENCE].hp), fence_hp, "a dead monster no longer hits the fence (mutation: a corpse that keeps attacking)")
	assert_eq(killed, [[b.spawn_index, &"boar"]], "one kill, from the thorn")
	assert_eq(main.world.steak_pool.active().size() - steaks0, Balance.data.economy.steaks_per_kill, "it dropped its steaks")
	assert_eq(wd.alive_count(), 0)

# --- pass damage ---

func test_pass_damage_queries_follow_the_kind() -> void:
	_branch(&"spike")
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"hare"), 10.0, 1e-4)
	assert_almost_eq(GameState.fence_pass_damage(FENCE, &"baron"), 10.0, 1e-4)
	assert_eq(GameState.fence_pass_damage(FENCE, &"boar"), 0.0)
	assert_eq(GameState.fence_pass_damage(FENCE, &"brute"), 0.0)
	assert_eq(GameState.fence_pass_damage(FENCE, &"boss"), 0.0)

func test_a_hare_loses_the_literal_pass_damage_exactly_once() -> void:
	_branch(&"spike")
	var h := _mon(&"hare")
	var line := _line(h)
	_walk_until(h, line - 0.5)
	assert_almost_eq(_lost(h), 0.0, 1e-6, "before the line: nothing")
	_walk_until(h, line + 0.01)
	assert_almost_eq(_lost(h), 10.0, 1e-4, "crossing the line: the pass amount")
	_walk_until(h, h.path_length())
	_step(h, 240)  # standing at the diner, hitting it for 4 seconds
	assert_true(h.at_path_end())
	assert_almost_eq(_lost(h), 10.0, 1e-4, "still one hit in total (a per-tick or per-frame-past-the-line hit fails)")

func test_the_baron_takes_pass_damage_once_too() -> void:
	_branch(&"spike")
	var b := _mon(&"baron")
	_walk_until(b, b.path_length())
	_step(b, 60)
	assert_almost_eq(_lost(b), 10.0, 1e-4)

func test_no_pass_damage_at_stone_plain_or_rubble() -> void:
	for branch in [&"stone", &"", &"rubble"]:
		GameState.buildings[FENCE] = GameState._new_building()
		_branch(&"spike" if branch == &"rubble" else branch)
		if branch == &"rubble":
			GameState.damage_fence(FENCE, 1e9)
		var h := _mon(&"hare")
		_walk_until(h, h.path_length())
		assert_almost_eq(_lost(h), 0.0, 1e-6, "no pass damage at '%s'" % branch)

func test_a_boar_and_a_brute_stop_at_a_spike_fence_and_take_no_pass_damage() -> void:
	_branch(&"spike")
	for kind in [&"boar", &"brute"]:
		var b := _mon(kind)
		var stop := TargetProviders.fence_stop_dist(b)
		_walk_until(b, stop)
		_step(b, 30)  # standing at the fence, half an attack interval: no hit yet
		assert_almost_eq(b.dist, stop, 0.05, "%s stopped at the fence" % kind)
		assert_lt(b.dist, _line(b), "short of the line: it never crossed")
		assert_almost_eq(_lost(b), 0.0, 1e-6, "no pass damage for %s" % kind)

func test_a_fence_built_after_the_crossing_does_not_hurt_that_hare() -> void:
	_build_max(FENCE)
	GameState.damage_fence(FENCE, 1e9)  # rubble: not standing as the hare crosses
	var h := _mon(&"hare")
	_walk_until(h, _line(h) + 0.5)
	GameState.buildings[FENCE].hp = Balance.data.build.fence_hp[Balance.data.build.max_level - 1]  # test-only: stands again (plain)
	GameState.buildings[FENCE].branch = "spike"
	_walk_until(h, h.path_length())
	assert_almost_eq(_lost(h), 0.0, 1e-6, "the crossing already happened")

func test_a_monster_killed_by_pass_damage_counts_one_kill_and_drops_its_steaks() -> void:
	_branch(&"spike")
	var h := _mon(&"hare", 0.1)  # 1.5 hp
	var steaks0: int = main.world.steak_pool.active().size()
	var killed: Array = []
	var cb := func(i, l, p, k): killed.append([i, k])
	EventBus.enemy_killed.connect(cb)
	_walk_until(h, h.path_length())
	_step(h, 60)
	EventBus.enemy_killed.disconnect(cb)
	assert_false(h.alive)
	assert_eq(killed, [[h.spawn_index, &"hare"]])
	assert_lt(h.dist, h.path_length(), "it died at the line, not at the diner")
	assert_almost_eq(h.dist, _line(h), 0.1)
	assert_eq(main.world.steak_pool.active().size() - steaks0, Balance.data.economy.steaks_per_kill)

func test_a_recycled_monster_can_take_pass_damage_in_its_next_life() -> void:
	_branch(&"spike")
	var h := _mon(&"hare")
	_walk_until(h, h.path_length())
	assert_almost_eq(_lost(h), 10.0, 1e-4)
	h.spawn("north", 9, 0.0, BIG, wd, &"hare")  # the pool hands the same node out again
	assert_almost_eq(_lost(h), 0.0, 1e-6, "fresh hp")
	_walk_until(h, h.path_length())
	assert_almost_eq(_lost(h), 10.0, 1e-4, "its second life crossed the line again")

func test_the_spike_fence_does_not_change_a_hares_path_or_arrival_tick() -> void:
	_branch(&"spike")
	var with_spike := _arrival(_mon(&"hare"))
	GameState.damage_fence(FENCE, 1e9)  # rubble: the no-fence run
	var without := _arrival(_mon(&"hare"))
	assert_gt(with_spike.ticks, 0)
	assert_eq(with_spike.ticks, without.ticks, "same arrival tick")
	assert_eq(with_spike.path, without.path, "same distance at every tick")

func _arrival(h: Boar) -> Dictionary:
	var path: Array = []
	var ticks := 0
	while not h.at_path_end() and ticks < 4000:
		h._physics_process(DT)
		path.append(h.dist)
		ticks += 1
	return {"ticks": ticks, "path": path}
