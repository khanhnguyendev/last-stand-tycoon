extends GutTest

var main: Main
var pc: PhaseController
var _spawned_out: Array = []

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	pc = main.phase_controller
	main.hero.input.player_control = false
	pc.start_new_game(99)

func after_each() -> void:
	if EventBus.wave_spawned_out.is_connected(_on_spawned_out):
		EventBus.wave_spawned_out.disconnect(_on_spawned_out)

func _on_spawned_out(w: int) -> void:
	_spawned_out.append(w)

func _pick_first() -> void:
	EventBus.card_chosen.emit(GameState.card_offer[0])

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Banner time (Balance.ui) in physics ticks, plus a small margin for tick sampling (D-118).
func _fail_ticks() -> int:
	return int(ceil(Balance.ui.banner_time * Engine.physics_ticks_per_second)) + 3

## Runs the real WaveDirector to the point where wave 2 has finished spawning (boars of earlier waves are killed).
func _advance_to_wave_2_spawned_out() -> void:
	var wd := main.world.wave_director
	_spawned_out.clear()
	EventBus.wave_spawned_out.connect(_on_spawned_out)
	var guard := 0
	while not _spawned_out.has(2) and guard < 60 * 300:
		if wd.wave_index < 2:
			wd.debug_kill_all()
		await get_tree().physics_frame
		guard += 1
	assert_true(_spawned_out.has(2), "wave 2 never finished spawning")
	assert_gt(wd.alive_count(), 0, "wave 2 should still have live boars")

## Leaves one Boar and one Steak active, so recall on restore can be checked.
func _leave_pool_items() -> void:
	main.world.wave_director.debug_spawn("north")
	main.world.steak_pool.acquire().place(Vector3(20, 0, 0))
	assert_eq(main.world.enemy_pool.active().size(), 1)
	assert_eq(main.world.steak_pool.active().size(), 1)

func _assert_pools_empty() -> void:
	assert_eq(main.world.enemy_pool.active().size(), 0, "enemy pool not recalled")
	assert_eq(main.world.steak_pool.active().size(), 0, "steak pool not recalled")

func test_phase_controller_uses_only_the_narrow_interface() -> void:
	# D-128: typed @export references only; no node paths, groups or tree searches.
	var src := FileAccess.get_file_as_string("res://world/phase_controller.gd")
	for banned in ["get_node", "$", "get_nodes_in_group", "find_children", "find_child", "get_parent", "owner."]:
		assert_false(src.contains(banned), "phase_controller.gd uses %s" % banned)
	for prop in ["wave_director", "enemy_pool", "steak_pool", "projectile_pool", "fx_pool", "traveler_spawner"]:
		assert_not_null(pc.get(prop), "%s not wired in main.tscn" % prop)
	# D-128 whitelist: the only members PhaseController may use on its exports.
	var allowed := {
		"wave_director": ["start_night", "stop"],
		"enemy_pool": ["recall_all"], "steak_pool": ["recall_all"], "projectile_pool": ["recall_all"],
		"fx_pool": ["recall_all"],
		"traveler_spawner": ["start", "stop", "clear_queue"],
	}
	var re := RegEx.create_from_string("\\b(wave_director|enemy_pool|steak_pool|projectile_pool|fx_pool|traveler_spawner)\\.(\\w+)")
	var uses := 0
	for m in re.search_all(src):
		uses += 1
		var target := m.get_string(1)
		var member := m.get_string(2)
		assert_true(member in allowed[target], "phase_controller.gd uses %s.%s (not in the D-128 interface)" % [target, member])
	assert_gt(uses, 8, "whitelist regex found the calls")

func test_new_game_starts_night_with_night_snapshot() -> void:
	assert_eq(pc.phase, Phase.NIGHT)
	assert_eq(pc.snapshot.resume_phase, "NIGHT")
	assert_eq(main.hero.xz(), MapLayout.NIGHT1_START)
	assert_eq(main.world.wave_director.state, WaveDirector.State.WAITING)

func test_dawn_steps_in_order() -> void:
	GameState.add_gold(GameState.next_level_cost("fence_w"))
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	GameState.damage_fence("fence_w", 1e6)
	GameState.add_gold(GameState.next_level_cost("fence_n"))
	GameState.pay_into_spot("fence_n", GameState.next_level_cost("fence_n"))
	GameState.damage_fence("fence_n", GameState.fence_max_hp(1) * 0.5)
	GameState.damage_diner(50.0)
	GameState.carried_steaks = 2  # test-only setup write
	for i in 3:
		main.world.steak_pool.acquire().place(Vector3(20, 0, 0))
	watch_signals(EventBus)
	var seen := []
	EventBus.card_offered.connect(func(_o): seen.append(GameState.day), CONNECT_ONE_SHOT)
	EventBus.wave_cleared.emit(2)
	assert_eq(seen, [2], "the offer is built after advance_day")
	assert_eq(pc.phase, Phase.DAWN)
	assert_eq(pc.dawn_substate, "CARD_PICK")
	assert_eq(GameState.card_offer.size(), 3)
	assert_eq([GameState.card_offer[0], GameState.card_offer[1]], [&"archer", &"tank"])
	assert_signal_emitted(EventBus, "card_offered")
	assert_eq(GameState.freezer_steaks, 3)
	assert_eq(GameState.carried_steaks, 2)
	assert_eq(GameState.diner_hp, Balance.data.build.diner_max_hp)
	assert_eq(GameState.buildings.fence_w, {"level": 0, "paid": 0, "hp": 0.0})
	assert_eq(GameState.buildings.fence_n.hp, GameState.fence_max_hp(1))
	assert_eq(GameState.day, 2)
	assert_ne(GameState.lane_plan[0].side, "")
	assert_eq(main.world.steak_pool.active().size(), 0)
	_pick_first()
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.card_level(&"archer"), 1)
	assert_eq(get_signal_parameters(EventBus, "phase_changed", 0), [Phase.DAWN, 1])
	assert_eq(get_signal_parameters(EventBus, "phase_changed", 1), [Phase.DAY, 2])
	assert_eq(pc.dawn_substate, "")

func test_early_wave_clear_is_not_dawn() -> void:
	EventBus.wave_cleared.emit(0)
	assert_eq(pc.phase, Phase.NIGHT)

func test_close_up_collects_and_snapshots_day() -> void:
	EventBus.wave_cleared.emit(2)
	_pick_first()
	GameState.gold_pile = 12  # test-only setup write
	main.world.steak_pool.acquire().place(Vector3(20, 0, 0))
	pc.close_up()
	assert_eq(GameState.gold, 12)
	assert_eq(GameState.freezer_steaks, 1)
	assert_eq(pc.snapshot.resume_phase, "DAY")
	assert_eq(pc.snapshot.gold, 12)
	assert_eq(pc.phase, Phase.NIGHT)

func test_close_up_ignored_at_night() -> void:
	pc.close_up()
	assert_eq(pc.snapshot.resume_phase, "NIGHT")

func test_fail_night1_restarts_night() -> void:
	var snap := pc.snapshot.duplicate(true)
	_leave_pool_items()
	GameState.add_gold(5)
	watch_signals(EventBus)
	GameState.damage_diner(1000.0)
	assert_signal_emitted_with_parameters(EventBus, "night_failed", [1])
	assert_true(pc.failing)
	await _ticks(_fail_ticks())
	assert_false(pc.failing)
	assert_eq(pc.phase, Phase.NIGHT)
	var now := GameState.to_dict()
	now.resume_phase = snap.resume_phase
	snap.night_fails = 1  # the night-1 retry carries one mercy step (S3 spec 6)
	assert_eq(now, snap)
	assert_eq(main.hero.xz(), MapLayout.NIGHT1_START)
	_assert_pools_empty()

func test_fail_after_close_up_returns_to_day() -> void:
	EventBus.wave_cleared.emit(2)
	_pick_first()
	GameState.add_gold(30)
	pc.close_up()
	GameState.damage_diner(1000.0)
	await _ticks(_fail_ticks())
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.gold, 30)
	assert_eq(GameState.day, 2)
	assert_eq(main.hero.xz(), MapLayout.HOME)

func test_fall_and_clear_same_tick_fail_wins() -> void:
	# Review Focus 3, hand-emitted: the late wave_cleared(2) changes nothing.
	watch_signals(EventBus)
	GameState.damage_diner(1000.0)
	EventBus.wave_cleared.emit(2)
	assert_eq(pc.phase, Phase.NIGHT)
	assert_eq(GameState.day, 1)
	assert_eq(GameState.diner_hp, 0.0)
	assert_signal_not_emitted(EventBus, "phase_changed")
	await _ticks(_fail_ticks())
	assert_eq(pc.phase, Phase.NIGHT)
	assert_eq(GameState.day, 1)

func test_review_focus_3_diner_falls_then_wave_clears_through_wave_director() -> void:
	await _advance_to_wave_2_spawned_out()
	var wd := main.world.wave_director
	watch_signals(EventBus)
	GameState.damage_diner(1e6)
	wd.debug_kill_all()
	await _ticks(2)
	_assert_no_clear_no_dawn()

func test_review_focus_3_wave_clears_then_diner_falls_through_wave_director() -> void:
	await _advance_to_wave_2_spawned_out()
	var wd := main.world.wave_director
	watch_signals(EventBus)
	wd.debug_kill_all()
	GameState.damage_diner(1e6)
	await _ticks(2)
	_assert_no_clear_no_dawn()

func _assert_no_clear_no_dawn() -> void:
	var cleared: int = get_signal_emit_count(EventBus, "wave_cleared")
	for i in cleared:
		assert_ne(get_signal_parameters(EventBus, "wave_cleared", i), [2], "wave_cleared(2) reached the bus")
	for i in get_signal_emit_count(EventBus, "phase_changed"):
		assert_ne(get_signal_parameters(EventBus, "phase_changed", i), [Phase.DAWN, 1], "dawn started")
	assert_true(pc.failing)
	assert_ne(pc.phase, Phase.DAWN)

func test_new_game_during_fail_banner_cancels_stale_restore() -> void:
	GameState.damage_diner(1000.0)
	pc.start_new_game(7)
	GameState.add_gold(3)
	await _ticks(_fail_ticks())
	assert_eq(GameState.run_seed, 7)
	assert_eq(GameState.gold, 3)
	assert_false(pc.failing)

func test_new_game_recalls_pools() -> void:
	_leave_pool_items()
	pc.start_new_game(5)
	_assert_pools_empty()

func test_debug_skip_to_day_runs_dawn() -> void:
	pc.debug_skip_to_day()
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.day, 2)

func test_invalid_stale_and_night_choices_are_ignored() -> void:
	EventBus.card_chosen.emit(&"tank")  # at night
	assert_eq(GameState.card_level(&"tank"), 0)
	EventBus.wave_cleared.emit(2)
	EventBus.card_chosen.emit(&"gold_per_steak" if GameState.card_offer[2] != &"gold_per_steak" else &"move_speed")
	assert_eq(pc.phase, Phase.DAWN, "a card not in the offer is ignored")
	EventBus.card_chosen.emit(&"tank")
	assert_eq(pc.phase, Phase.DAY)
	EventBus.card_chosen.emit(&"archer")  # stale: the offer is closed
	assert_eq(GameState.card_level(&"archer"), 0)
	assert_eq(GameState.card_level(&"tank"), 1)

func test_pick_shows_banner() -> void:
	EventBus.wave_cleared.emit(2)
	watch_signals(EventBus)
	EventBus.card_chosen.emit(&"archer")
	assert_signal_emitted_with_parameters(EventBus, "banner_requested", ["The Archer joins!"])

func test_empty_offer_skips_to_day() -> void:
	for id in CardCatalog.IDS:
		GameState.cards[id] = Balance.data.cards.max_level  # test-only setup write
	watch_signals(EventBus)
	EventBus.wave_cleared.emit(2)
	assert_signal_emitted_with_parameters(EventBus, "banner_requested", ["Dawn"])
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(pc.dawn_substate, "")
	assert_signal_not_emitted(EventBus, "card_offered")
	pc.close_up()
	EventBus.wave_cleared.emit(2)
	assert_eq(pc.phase, Phase.DAY, "a later dawn still works")
	assert_eq(GameState.day, 3)

func test_no_dawn_banner_when_an_offer_opens() -> void:
	watch_signals(EventBus)
	EventBus.wave_cleared.emit(2)
	assert_eq(pc.dawn_substate, "CARD_PICK")
	assert_signal_not_emitted(EventBus, "banner_requested")

func test_debug_skip_grants_no_card_from_night_and_from_pick() -> void:
	pc.debug_skip_to_day()
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.cards, {})
	assert_eq(GameState.card_offer, [] as Array[StringName])
	pc.close_up()
	EventBus.wave_cleared.emit(2)
	assert_eq(pc.dawn_substate, "CARD_PICK")
	pc.debug_skip_to_day()
	assert_eq([pc.phase, pc.dawn_substate, GameState.cards], [Phase.DAY, "", {}])

func test_new_game_during_pick_resets_substate() -> void:
	EventBus.wave_cleared.emit(2)
	pc.start_new_game(3)
	assert_eq(pc.dawn_substate, "")
	assert_eq(pc.phase, Phase.NIGHT)
	EventBus.card_chosen.emit(&"archer")
	assert_eq(GameState.card_level(&"archer"), 0)
