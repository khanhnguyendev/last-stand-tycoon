extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	GameState.new_game(3)
	main.hero.input.player_control = false

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_hero_kills_boar_in_range() -> void:
	var wd := main.world.wave_director
	var b := wd.debug_spawn("north")
	main.hero.teleport(Vector2(0, -21))
	watch_signals(EventBus)
	await _ticks(120)
	assert_false(b.alive)
	assert_signal_emitted(EventBus, "enemy_killed")
	# the hero's magnet may already hold some of the drops
	assert_eq(GameState.carried_steaks + main.world.steak_pool.active().size(), Balance.data.economy.steaks_per_kill)

func test_projectile_never_hits_recycled_boar() -> void:
	# Review Focus 2 (plan form)
	var wd := main.world.wave_director
	var b1 := wd.debug_spawn("north", 0.0, 100.0)
	b1.dist = 0.0
	var proj: Projectile = main.world.projectile_pool.acquire()
	proj.launch(Vector3(0, 1, 30), b1, b1.spawn_index, 10.0, 1.0, main.world.projectile_pool)
	b1.take_hit(1e9)
	await _ticks(20)  # death tween (0.15 s) releases b1
	var b2 := wd.debug_spawn("north", 0.0, 1.0)
	assert_same(b2, b1, "pool reused the same node")
	var hp_before := b2.health.hp
	await _ticks(5)
	assert_eq(b2.health.hp, hp_before)
	assert_false(main.world.projectile_pool.active().has(proj))

func test_projectile_in_flight_never_hits_reused_boar_same_index() -> void:
	# Review Focus 2, hard form: the Boar is recycled with the SAME spawn_index (a new night) before
	# the projectile ticks again, and the projectile is close enough to hit it at once.
	var wd := main.world.wave_director
	var pool := main.world.projectile_pool
	var b1 := wd.debug_spawn("north", 0.0, 100.0)
	var idx := b1.spawn_index
	var gen := b1.generation
	var proj: Projectile = pool.acquire()
	proj.launch(b1.global_position + Vector3(0, 0.5, 0), b1, idx, 10.0, 1000.0, pool)
	b1.take_hit(1e9)
	main.world.enemy_pool.release(b1)  # the pool reclaims it immediately
	var b2: Boar = main.world.enemy_pool.acquire()
	assert_same(b2, b1)
	b2.spawn("north", idx, 0.0, 1.0, wd)  # same spawn_index, new generation
	assert_ne(b2.generation, gen)
	var hp_before := b2.health.hp
	assert_true(pool.active().has(proj), "projectile survived the reuse")
	await _ticks(3)
	assert_eq(b2.health.hp, hp_before, "recycled Boar untouched")
	assert_false(pool.active().has(proj), "projectile despawned")

func test_is_moving_false_on_tick_after_teleport() -> void:
	main.hero.input.set_move(Vector2(1, 0))
	await _ticks(3)
	assert_true(main.hero.is_moving())
	main.hero.teleport(Vector2(10, 8))
	assert_false(main.hero.is_moving(), "teleport zeroes velocity")
	await _ticks(1)
	assert_false(main.hero.is_moving(), "no movement, so no moving-attack multiplier")

func test_attacker_uses_is_moving_from_hero() -> void:
	assert_eq(main.hero.attacker.is_moving, main.hero.is_moving)
