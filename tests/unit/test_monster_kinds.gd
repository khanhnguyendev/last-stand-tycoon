extends GutTest
## E5 spec 4.3, 7.1: one scene per monster; the kind picks the stats and the target list (D-148 for the hare).

class FakeDirector:
	extends RefCounted
	var providers := TargetProviders.new()
	var died: Array = []
	func _init() -> void:
		providers.register(&"fence_on_lane", func(e): return TargetProviders.fence_on_lane(e))
		providers.register(&"diner", func(e): return TargetProviders.diner(e))
	func on_enemy_died(b) -> void:
		died.append([b.spawn_index, b.kind])

const DT := 1.0 / 60.0
var dir: FakeDirector

func before_each() -> void:
	Balance.reset()
	GameState.new_game(7)
	dir = FakeDirector.new()

func _monster(kind: StringName, lane := "north", index := 0) -> Boar:
	var b := Boar.new()
	b.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(b)
	b.spawn(lane, index, 0.0, 1.0, dir, kind)
	return b

func _step(b: Boar, seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		b._physics_process(DT)

func _build_fence_n() -> void:
	GameState.add_gold(GameState.next_level_cost("fence_n"))
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n"))

func test_default_kind_is_boar_and_stats_follow_the_kind() -> void:
	var b := Boar.new()
	add_child_autofree(b)
	assert_eq(b.kind, &"boar")
	var h := _monster(&"hare")
	assert_eq(h.stats().speed, 3.6)
	assert_almost_eq(h.health.max_hp, 15.0, 1e-6)
	var boss := _monster(&"boss")
	assert_almost_eq(boss.health.max_hp, 800.0, 1e-6)

func test_spawn_takes_the_merged_multiplier_once() -> void:
	GameState.set_night_fails(1)
	var h := Boar.new()
	h.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(h)
	h.spawn("north", 0, 0.0, 1.9, dir, &"hare")
	assert_almost_eq(h.health.max_hp, 15.0 * 1.9, 1e-6, "spawn() takes the already-merged multiplier, as WaveDirector passes it")

func test_hare_walks_past_a_standing_fence_and_a_boar_stops() -> void:
	_build_fence_n()
	var hare := _monster(&"hare", "north", 0)
	var boar := _monster(&"boar", "north", 1)
	var walk := MapLayout.path_length("north") / Balance.data.monsters.stats(&"hare").speed
	_step(hare, walk + 0.2)
	_step(boar, MapLayout.path_length("north") / Balance.data.enemy.speed + 0.2)
	assert_true(hare.at_path_end(), "the hare reached the diner")
	var stop := boar.path_length() - MapLayout.FENCE_OFFSET_FROM_END - Balance.data.enemy.reach
	assert_almost_eq(boar.dist, stop, 0.05, "the boar stopped at the fence")
	var hp0 := GameState.diner_hp
	var fence0 := float(GameState.buildings.fence_n.hp)
	_step(hare, 1.0)
	_step(boar, 1.0)
	assert_almost_eq(hp0 - GameState.diner_hp, 4.0, 1e-4, "the hare hits the diner for its own damage")
	assert_lt(float(GameState.buildings.fence_n.hp), fence0, "the boar hits the fence")

func test_hare_keeps_the_diner_when_the_fence_falls() -> void:
	_build_fence_n()
	var hare := _monster(&"hare")
	_step(hare, MapLayout.path_length("north") / 3.6 + 0.2)
	assert_eq(hare.current_target.kind, &"diner")
	GameState.damage_fence("fence_n", 1e9)
	_step(hare, 0.1)
	assert_eq(hare.current_target.kind, &"diner", "Review Focus 5: no retarget")

func test_boss_breaks_a_fence_by_raw_damage() -> void:
	_build_fence_n()
	var boss := _monster(&"boss")
	var stop := boss.path_length() - MapLayout.FENCE_OFFSET_FROM_END - 1.6
	_step(boss, stop / 1.2 + 0.2)
	assert_almost_eq(boss.dist, stop, 0.05, "the boss stops at its own reach")
	var fence0 := float(GameState.buildings.fence_n.hp)
	_step(boss, 1.0)
	assert_almost_eq(fence0 - float(GameState.buildings.fence_n.hp), 15.0, 1e-4)

func test_mercy_scales_a_hares_hit() -> void:
	GameState.set_night_fails(1)
	var hare := _monster(&"hare")
	_step(hare, MapLayout.path_length("north") / 3.6 + 0.2)
	var hp0 := GameState.diner_hp
	_step(hare, Balance.data.monsters.stats(&"hare").attack_interval + 0.1)
	assert_almost_eq(hp0 - GameState.diner_hp, 4.0 * GameState.mercy_factor(), 1e-4)

func test_a_pooled_node_respawned_as_another_kind_takes_that_kinds_stats() -> void:
	var b := _monster(&"boss")
	b.spawn("north", 1, 0.0, 1.0, dir)
	assert_eq(b.kind, &"boar")
	assert_almost_eq(b.health.max_hp, 30.0, 1e-6)
	assert_eq(b.stats().reach, 1.2)
	b.spawn("north", 2, 0.0, 1.0, dir, &"hare")
	assert_eq(b.stats().speed, 3.6)
