extends GutTest

class FakeDirector:
	extends RefCounted
	var providers := TargetProviders.new()
	var died: Array = []
	func _init() -> void:
		providers.register(&"fence_on_lane", func(e): return TargetProviders.fence_on_lane(e))
		providers.register(&"diner", func(e): return TargetProviders.diner(e))
	func on_enemy_died(b) -> void:
		died.append(b.spawn_index)

const DT := 1.0 / 60.0
var dir: FakeDirector

func before_each() -> void:
	Balance.reset()
	GameState.new_game(7)
	dir = FakeDirector.new()

func _boar(lane: String, offset := 0.0) -> Boar:
	var b := Boar.new()
	b.process_mode = Node.PROCESS_MODE_DISABLED  # tests step it by hand
	add_child_autofree(b)
	b.spawn(lane, 0, offset, 1.0, dir)
	return b

func _step(b: Boar, seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		b._physics_process(DT)

func _walk_time(lane: String) -> float:
	return MapLayout.path_length(lane) / Balance.data.enemy.speed

func test_walks_to_zone_and_hits_diner() -> void:
	var eb := Balance.data.enemy
	var max_hp := Balance.data.build.diner_max_hp
	var b := _boar("north", 0.7)
	_step(b, _walk_time("north") + 0.1)
	assert_true(b.at_path_end())
	assert_true(Geometry.rect_contains(MapLayout.ZONE_RECTS.north, Vector2(b.position.x, b.position.z)))
	assert_eq(GameState.diner_hp, max_hp)
	_step(b, eb.attack_interval - 0.05)
	assert_eq(GameState.diner_hp, max_hp - eb.damage)

func test_standing_fence_blocks_and_takes_damage() -> void:
	GameState.add_gold(GameState.next_level_cost("fence_n"))
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n"))
	var b := _boar("north")
	_step(b, _walk_time("north") + 3.0 * Balance.data.enemy.attack_interval)
	var fence_dist := b.path_length() - MapLayout.FENCE_OFFSET_FROM_END
	assert_almost_eq(b.dist, fence_dist - Balance.data.enemy.reach, 0.05)
	assert_lt(GameState.buildings.fence_n.hp, GameState.fence_max_hp(1))
	assert_eq(GameState.diner_hp, Balance.data.build.diner_max_hp)

func test_rubble_does_not_block() -> void:
	GameState.add_gold(GameState.next_level_cost("fence_n"))
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n"))
	GameState.damage_fence("fence_n", 1000.0)
	var b := _boar("north")
	_step(b, _walk_time("north") + 0.1)
	assert_true(b.at_path_end())

func test_priority_is_data_driven() -> void:
	GameState.add_gold(GameState.next_level_cost("fence_n"))
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n"))
	Balance.data.wave.target_priority.kinds.assign([&"diner"])
	var b := _boar("north")
	_step(b, _walk_time("north") + 0.1)
	assert_true(b.at_path_end(), "fence ignored when not in priority list")

func test_death_reports_once() -> void:
	var b := _boar("west")
	b.take_hit(10.0)
	b.take_hit(25.0)
	b.take_hit(25.0)
	assert_false(b.alive)
	assert_eq(dir.died, [0])

func test_hp_mult_applies() -> void:
	var b := Boar.new()
	b.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(b)
	b.spawn("east", 3, 0.0, 1.15, dir)
	assert_almost_eq(b.health.max_hp, Balance.data.enemy.hp * 1.15, 0.0001)
	assert_eq(b.candidate().spawn_index, 3)

func test_listed_but_unregistered_fence_kind_does_not_stall() -> void:
	GameState.add_gold(GameState.next_level_cost("fence_n"))
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n"))
	assert_true(Balance.data.wave.target_priority.kinds.has(&"fence_on_lane"))
	dir.providers = TargetProviders.new()
	dir.providers.register(&"diner", func(e): return TargetProviders.diner(e))
	var b := _boar("north")
	_step(b, _walk_time("north") + 0.1)
	assert_true(b.at_path_end(), "no fence provider registered: the boar walks")

func test_reuse_resets_state() -> void:
	var pool := NodePool.new()
	add_child_autofree(pool)
	pool.setup(func(): return Boar.new(), 1)
	var b: Boar = pool.acquire()
	b.process_mode = Node.PROCESS_MODE_DISABLED  # tests step it by hand
	b.spawn("west", 5, 0.4, 1.0, dir)
	var gen := b.generation
	_step(b, 2.0)
	assert_gt(b.dist, 0.0)
	b.take_hit(1e9)
	assert_false(b.alive)
	b.play_death(pool)
	b.visual.scale = Vector3(0.01, 0.01, 0.01)  # what the death tween leaves behind
	pool.release(b)
	var b2: Boar = pool.acquire()
	assert_same(b2, b)
	b2.process_mode = Node.PROCESS_MODE_DISABLED
	b2.spawn("east", 6, 0.0, 1.0, dir)
	assert_eq(b2.dist, 0.0)
	assert_true(b2.alive)
	assert_eq(b2.health.hp, b2.health.max_hp)
	assert_eq(b2.visual.scale, Vector3.ONE)
	assert_true(b2.current_target.is_empty())
	assert_eq(b2.generation, gen + 1)
	assert_eq(dir.died, [5], "exactly one death, for the first life")

func test_pool_sizes_from_balance() -> void:
	# PINNED REFERENCE: spec 11 at the default Balance (D-124: steaks from the CAPPED day-10 counts
	# 17 + 25 + 30). If Task 35 changes a wave or economy value, update this row and spec 11 together.
	# E5: the boss is one more spawn; steaks = the top tier's capped night (75 kills x 2) + the boss drop (100), x 1.2
	assert_eq(World.pool_sizes(Balance.data), {"enemy": 41, "steak": 300, "projectile": 24, "fx": 32})

func test_guard_arm_damages_the_guard_and_stops_the_boar() -> void:
	GameState.debug_grant_card(&"tank")
	var stop := 10.0
	dir.providers.register(&"guard", func(e): return {"kind": &"guard", "guard_id": &"tank"} if e.dist >= stop else {})
	Balance.data.wave.target_priority.kinds.assign([&"fence_on_lane", &"guard", &"diner"])
	var b := _boar("north")
	_step(b, stop / Balance.data.enemy.speed + 0.1)
	var held := b.dist
	assert_gte(held, stop)
	_step(b, Balance.data.enemy.attack_interval)
	assert_almost_eq(b.dist, held, 1e-4, "a boar with a guard target stops advancing")
	assert_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank") - Balance.data.enemy.damage)

func test_mercy_scales_fence_arm_damage() -> void:
	GameState.set_night_fails(2)
	GameState.add_gold(GameState.next_level_cost("fence_n"))
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n"))
	var b := _boar("north")
	var stop := b.path_length() - MapLayout.FENCE_OFFSET_FROM_END - Balance.data.enemy.reach
	_step(b, stop / Balance.data.enemy.speed + 0.1)
	var hp0 := float(GameState.buildings.fence_n.hp)
	_step(b, Balance.data.enemy.attack_interval)
	assert_almost_eq(hp0 - float(GameState.buildings.fence_n.hp), Balance.data.enemy.damage * GameState.mercy_factor(), 1e-4)
	assert_lt(GameState.mercy_factor(), 1.0)

func test_mercy_scales_guard_arm_damage() -> void:
	GameState.set_night_fails(2)
	GameState.debug_grant_card(&"tank")
	var stop := 10.0
	dir.providers.register(&"guard", func(e): return {"kind": &"guard", "guard_id": &"tank"} if e.dist >= stop else {})
	Balance.data.wave.target_priority.kinds.assign([&"fence_on_lane", &"guard", &"diner"])
	var b := _boar("north")
	_step(b, stop / Balance.data.enemy.speed + 0.1)
	_step(b, Balance.data.enemy.attack_interval)
	var per_hit := Balance.data.enemy.damage * GameState.mercy_factor()
	assert_almost_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank") - per_hit, 1e-4)
