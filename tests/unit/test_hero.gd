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

func test_move_speed_card_applies() -> void:
	var base := Balance.data.hero.move_speed
	var fast := base * (1.0 + Balance.data.cards.move_step)
	assert_almost_eq(hero.move_speed(), base, 1e-5)
	GameState.debug_grant_card(&"move_speed")
	assert_almost_eq(hero.move_speed(), fast, 1e-5)
	hero.teleport(Vector2(10, 8))
	hero.input.set_move(Vector2(1, 0))
	await _ticks(60)
	hero.input.set_move(Vector2.ZERO)
	assert_almost_eq(hero.xz().x, 10.0 + fast, 0.25)

func test_attack_cards_reconfigure_attacker_and_restore_resets() -> void:
	var hb := Balance.data.hero
	var cb := Balance.data.cards
	GameState.debug_grant_card(&"hero_damage")
	GameState.debug_grant_card(&"attack_speed")
	assert_almost_eq(hero.attacker.damage, hb.attack_damage * (1.0 + cb.damage_step), 1e-5)
	assert_almost_eq(hero.attacker.interval, hb.attack_interval / (1.0 + cb.attack_speed_step), 1e-5)
	GameState.new_game(4)  # cards cleared, state_restored
	assert_almost_eq(hero.attacker.damage, hb.attack_damage, 1e-5)
	assert_almost_eq(hero.attacker.interval, hb.attack_interval, 1e-5)

func test_input_blocked_in_dawn_only() -> void:
	main.phase_controller.start_new_game(1)
	assert_false(main.hero.input.blocked, "night is not blocked")
	main.hero.input.player_control = true
	EventBus.wave_cleared.emit(2)  # -> DAWN / CARD_PICK
	assert_true(main.hero.input.blocked)
	main.hero.input.set_move(Vector2.RIGHT)
	assert_eq(main.hero.input.get_move(), Vector2.ZERO)
	Input.action_press(&"move_right")
	assert_eq(main.hero.input.get_move(), Vector2.ZERO, "WASD is blocked too")
	Input.action_release(&"move_right")
	main.phase_controller.start_new_game(2)
	assert_false(main.hero.input.blocked, "a new game during the pick unblocks")
	EventBus.wave_cleared.emit(2)
	EventBus.card_chosen.emit(GameState.card_offer[0])
	assert_false(main.hero.input.blocked)
	main.hero.input.set_move(Vector2.RIGHT)
	assert_eq(main.hero.input.get_move(), Vector2.RIGHT)
