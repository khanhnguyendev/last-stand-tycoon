extends GutTest
## S5 Task 5 (spec 5.2): every reaction shows up as a fx request or a visual change, and none touches gameplay state.

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(71)
	main.hero.teleport(Vector2(15, 8))  # away from every station zone
	# The previous test's Main is queue_freed; let it go so its Reactions do not answer too.
	await get_tree().process_frame
	watch_signals(EventBus)

func _fx_count(kind: StringName) -> int:
	var n := 0
	for i in get_signal_emit_count(EventBus, "fx_requested"):
		if get_signal_parameters(EventBus, "fx_requested", i)[0] == kind:
			n += 1
	return n

func _fx_pos(kind: StringName) -> Vector3:
	for i in get_signal_emit_count(EventBus, "fx_requested"):
		var p: Array = get_signal_parameters(EventBus, "fx_requested", i)
		if p[0] == kind:
			return p[1]
	return Vector3.INF

func test_enemy_killed_poof() -> void:
	EventBus.enemy_killed.emit(0, &"north", Vector3(1, 0, 1))
	assert_eq(_fx_count(&"poof"), 1)
	assert_eq(_fx_pos(&"poof"), Vector3(1, 0, 1))

func test_boar_hit_burst() -> void:
	main.phase_controller.debug_skip_to_night()
	var boar := main.world.wave_director.debug_spawn("north")
	boar.take_hit(1.0)
	assert_eq(_fx_count(&"hit"), 1)

func test_sale_coin_and_gold_sparkle() -> void:
	EventBus.steak_sold.emit(1, 3)
	assert_eq(_fx_count(&"coin"), 1)
	assert_eq(_fx_pos(&"coin"), MapLayout.to3(MapLayout.COUNTER, 1.2))
	EventBus.gold_changed.emit(5, 3)
	assert_eq(_fx_count(&"sparkle"), 1)
	assert_eq(_fx_pos(&"sparkle"), MapLayout.to3(MapLayout.GOLD_PILE, 0.6))
	EventBus.gold_changed.emit(2, -3)
	assert_eq(_fx_count(&"sparkle"), 1, "a spend is no sparkle")

func test_build_completed_and_dawn_sparkle() -> void:
	EventBus.build_completed.emit(&"tower_nw", 1)
	assert_eq(_fx_count(&"sparkle"), 1)
	assert_eq(_fx_pos(&"sparkle"), MapLayout.to3(MapLayout.spot_position("tower_nw"), 1.0))
	EventBus.phase_changed.emit(Phase.DAWN, 1)
	assert_eq(_fx_count(&"sparkle"), 2)

func test_build_dust_every_fourth_paid_tick() -> void:
	var spot: BuildSpot = main.world.build_spots["tower_nw"]
	GameState.gold = 10000
	for i in 3:
		spot._on_tick()
	assert_eq(_fx_count(&"dust"), 0)
	spot._on_tick()
	assert_eq(_fx_count(&"dust"), 1)

func test_hero_running_dust() -> void:
	main.hero.input.set_move(Vector2.RIGHT)
	await wait_seconds(0.8)
	assert_gte(_fx_count(&"dust"), 2)
	var before := _fx_count(&"dust")
	main.hero.input.set_move(Vector2.ZERO)
	await wait_seconds(0.2)
	var after_stop := _fx_count(&"dust")
	await wait_seconds(0.8)
	assert_eq(_fx_count(&"dust"), after_stop, "no dust while standing")
	assert_gte(after_stop, before)

func test_carry_squash_on_steak_picked() -> void:
	assert_eq(main.hero.carry_stack.scale.y, 1.0)
	EventBus.steak_picked.emit(1)
	await wait_seconds(0.03)
	assert_gt(main.hero.carry_stack.scale.y, 1.0)
	await wait_seconds(Balance.ui.carry_squash_time + 0.1)
	assert_almost_eq(main.hero.carry_stack.scale.y, 1.0, 0.001)

func test_traveler_hops_on_sale() -> void:
	var sp := main.world.traveler_spawner
	main.phase_controller.debug_skip_to_day()
	GameState.counter_steaks = 5
	var e := Balance.data.economy
	var guard := int(ceil((e.traveler_interval + e.traveler_jitter + 12.0) * 60.0))
	var front: Traveler = null
	while guard > 0:
		await get_tree().physics_frame
		guard -= 1
		if not sp.queue.is_empty() and (sp.queue[0] as Traveler).at_target():
			front = sp.queue[0]
			break
	assert_not_null(front)
	var root_y := front.visual.position.y
	var shadow_y := front.visual.global_position.y  # what the ShadowField reads
	guard = int(ceil(Balance.data.economy.service_time * 60.0 * 1.5)) + 60
	while not front.leaving and guard > 0:
		await get_tree().physics_frame
		guard -= 1
	assert_true(front.leaving, "the sale happened")
	await wait_seconds(0.08)
	assert_gt(front.visual.body.position.y, 0.0, "the Body hops")
	assert_eq(front.visual.position.y, root_y, "the Visual root stays")
	assert_eq(front.visual.global_position.y, shadow_y, "so the blob shadow stays on the ground")
	await wait_seconds(Balance.ui.traveler_hop_time + 0.1)
	assert_almost_eq(front.visual.body.position.y, 0.0, 0.001)

func test_traveler_release_resets_hop() -> void:
	var t: Traveler = main.world.traveler_pool.acquire()
	t.begin(1)
	t.hop()
	await wait_seconds(0.08)
	assert_gt(t.visual.body.position.y, 0.0)
	t.on_release()
	assert_eq(t.visual.body.position.y, 0.0)
	await wait_seconds(0.3)
	assert_eq(t.visual.body.position.y, 0.0, "the killed tween does not move it again")

func test_diner_bar_flash_and_arrow_punch() -> void:
	var hud := main.hud
	EventBus.diner_damaged.emit(1.0, 10.0)
	assert_eq(hud.diner_bar.modulate, Palette.color(&"enemy_red"))
	await wait_seconds(0.2)
	assert_eq(hud.diner_bar.modulate, Color.WHITE)
	EventBus.wave_incoming.emit(0, &"north", &"")
	await wait_seconds(0.03)
	assert_gt(hud.arrows.main.scale.x, 1.0)
	await wait_seconds(Balance.ui.arrow_punch_time + 0.1)
	assert_almost_eq(hud.arrows.main.scale.x, 1.0, 0.001)

func test_card_strip_pop() -> void:
	var strip := main.hud.card_strip
	assert_eq(strip.pop_scale(&"tank"), 1.0)
	GameState.debug_grant_card(&"tank")  # emits card_picked
	assert_gt(strip.pop_scale(&"tank"), 1.0)
	var i := -1
	for j in strip.shown().size():
		if strip.shown()[j][0] == &"tank":
			i = j
	assert_gte(i, 0)
	assert_gt(strip._drawn_rect(i).size.x, CardStrip.ICON_PX, "the popped cell is drawn larger")
	assert_eq(strip.pop_scale(&"archer"), 1.0)
	await wait_seconds(Balance.ui.strip_pop_time + 0.1)
	assert_eq(strip.pop_scale(&"tank"), 1.0)
	assert_eq(strip._drawn_rect(i).size.x, CardStrip.ICON_PX)
