extends GutTest

var main: Main
var hero: Hero

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	GameState.new_game(1)
	hero = main.hero
	hero.input.player_control = false

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_moves_at_speed() -> void:
	hero.teleport(Vector2(10, 8))
	hero.input.set_move(Vector2(1, 0))
	await _ticks(60)
	assert_almost_eq(hero.xz().x, 10.0 + Balance.data.hero.move_speed, 0.2)

func test_blocked_by_diner() -> void:
	hero.teleport(Vector2(-3, 7))
	hero.input.set_move(Vector2(0, -1))
	await _ticks(90)
	assert_true(hero.xz().y >= MapLayout.DINER_HALF + MapLayout.HERO_RADIUS - 0.05, "z=%f" % hero.xz().y)

func test_still_time_counts() -> void:
	hero.teleport(Vector2(10, 8))
	hero.input.set_move(Vector2.ZERO)
	await _ticks(30)
	assert_almost_eq(hero.still_time, 0.5, 0.05)
	hero.input.set_move(Vector2(1, 0))
	await _ticks(2)
	assert_eq(hero.still_time, 0.0)
	assert_true(hero.is_moving())

func test_magnet_picks_steaks_up_to_capacity() -> void:
	hero.teleport(Vector2(10, 8))
	for i in 7:
		var s: Steak = main.world.steak_pool.acquire()
		s.place(Vector3(10.5, 0, 8))
	await _ticks(2)
	assert_eq(GameState.carried_steaks, 6)
	assert_eq(main.world.steak_pool.active().size(), 1)
	assert_eq(hero.carry_stack.visible_count(), 6)

func test_magnet_collects_gold_pile() -> void:
	GameState.gold_pile = 9  # test-only setup write
	hero.teleport(MapLayout.GOLD_PILE + Vector2(-1.0, 0))
	await _ticks(2)
	assert_eq(GameState.gold, 9)
	assert_eq(GameState.gold_pile, 0)

func test_starts_at_home() -> void:
	var m := Main.create()
	add_child_autofree(m)
	assert_eq(m.hero.xz(), MapLayout.HOME)
