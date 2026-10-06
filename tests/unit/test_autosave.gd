extends GutTest

var main: Main
var pc: PhaseController
var store: SaveStore
var dir := ""

func before_each() -> void:
	Balance.reset()
	dir = "user://test_saves/as_%d" % Time.get_ticks_usec()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	pc = main.phase_controller
	store = SaveStore.with_dir(dir)
	main.autosave.store = store

func after_each() -> void:
	get_tree().paused = false
	store.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_saves"))

func _saved() -> Dictionary:
	return SaveStore.with_dir(dir).read().state

func _fail_ticks() -> int:
	return int(ceil(Balance.ui.banner_time * Engine.physics_ticks_per_second)) + 3

func test_new_game_writes_its_night_snapshot() -> void:
	pc.start_new_game(9)
	assert_eq(String(_saved().resume_phase), "NIGHT")
	assert_eq(int(_saved().day), 1)

func test_no_writes_at_night() -> void:
	pc.start_new_game(9)
	var w := main.autosave.writes
	GameState.add_gold(5)
	for i in int(Balance.ui.autosave_interval_s * Engine.physics_ticks_per_second) + 10:
		await get_tree().physics_frame
	assert_eq(main.autosave.writes, w)

func test_offer_pick_build_and_day_writes() -> void:
	pc.start_new_game(9)
	EventBus.wave_cleared.emit(GameState.lane_plan.size() - 1)
	assert_eq(String(_saved().resume_phase), "CARD_PICK")
	EventBus.card_chosen.emit(GameState.card_offer[0])
	assert_eq(String(_saved().resume_phase), "DAY")
	assert_eq(int(_saved().day), 2)
	GameState.add_gold(GameState.next_level_cost("fence_w"))
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	assert_eq(int(_saved().buildings.fence_w.level), 1, "build_completed writes at once")

func test_close_up_writes_the_restore_point() -> void:
	pc.start_new_game(9)
	pc.debug_skip_to_day()
	GameState.add_gold(12)
	pc.close_up()
	var s := _saved()
	assert_eq(String(s.resume_phase), "DAY")
	assert_eq(int(s.gold), 12)

func test_throttled_day_writes() -> void:
	pc.start_new_game(9)
	pc.debug_skip_to_day()
	var w := main.autosave.writes
	for i in 10:
		GameState.add_gold(1)
	assert_eq(main.autosave.writes, w, "no write before the interval")
	var n := int(Balance.ui.autosave_interval_s * Engine.physics_ticks_per_second)
	for i in n - 5:
		await get_tree().physics_frame
	assert_eq(main.autosave.writes, w, "no write before the interval")
	for i in 10:
		await get_tree().physics_frame
	assert_eq(main.autosave.writes, w + 1, "one write for many changes")
	assert_eq(int(_saved().gold), GameState.gold)

func test_hidden_flushes_when_dirty() -> void:
	pc.start_new_game(9)
	pc.debug_skip_to_day()
	GameState.add_gold(3)
	main.autosave.flush()
	assert_eq(int(_saved().gold), GameState.gold)

func test_night1_retry_writes_during_the_fail_flow() -> void:
	pc.start_new_game(9)
	GameState.damage_diner(1e6)
	for i in _fail_ticks():
		await get_tree().physics_frame
	var s := _saved()
	assert_eq([String(s.resume_phase), int(s.night_fails)], ["NIGHT", 1])

func test_day_fail_restore_writes_the_new_mercy() -> void:
	pc.start_new_game(9)
	pc.debug_skip_to_day()
	pc.close_up()
	GameState.damage_diner(1e6)
	for i in _fail_ticks():
		await get_tree().physics_frame
	var s := _saved()
	assert_eq([String(s.resume_phase), int(s.night_fails)], ["DAY", 1])

func test_main_create_has_no_store() -> void:
	var m := Main.create()
	add_child_autofree(m)
	assert_null(m.autosave.store)
	m.phase_controller.start_new_game(9)
	m.phase_controller.debug_skip_to_day()
	GameState.add_gold(1)
	await get_tree().physics_frame
	assert_false(m.autosave._dirty)

func test_empty_offer_dawn_writes_day() -> void:
	pc.start_new_game(9)
	for id in CardCatalog.IDS:
		GameState.cards[id] = Balance.data.cards.max_level  # test-only setup write
	pc.debug_skip_to_day()
	pc.close_up()
	EventBus.wave_cleared.emit(GameState.lane_plan.size() - 1)
	var s := _saved()
	assert_eq([String(s.resume_phase), int(s.day)], ["DAY", 3])

func test_nothing_written_during_a_day_snapshot_fail() -> void:
	pc.start_new_game(9)
	pc.debug_skip_to_day()
	pc.close_up()
	GameState.damage_diner(1e6)
	var w := main.autosave.writes
	for i in _fail_ticks() - 5:
		await get_tree().physics_frame
	assert_eq(main.autosave.writes, w, "no write before the restore")
	for i in 10:
		await get_tree().physics_frame
	assert_eq(main.autosave.writes, w + 1)
	assert_eq(String(_saved().resume_phase), "DAY")

func test_throttle_holds_while_paused() -> void:
	pc.start_new_game(9)
	pc.debug_skip_to_day()
	GameState.add_gold(1)
	var w := main.autosave.writes
	get_tree().paused = true
	var n := int(Balance.ui.autosave_interval_s * Engine.physics_ticks_per_second)
	for i in n + 10:
		await get_tree().physics_frame
	var during := main.autosave.writes
	get_tree().paused = false
	assert_eq(during, w, "no write while paused")
	for i in n - 5:
		await get_tree().physics_frame
	assert_eq(main.autosave.writes, w, "timer did not run during the pause")
	for i in 10:
		await get_tree().physics_frame
	assert_eq(main.autosave.writes, w + 1)

func test_a_station_upgrade_writes_at_once() -> void:
	pc.start_new_game(9)
	pc.debug_skip_to_day()
	var cost := GameState.station_next_cost(&"counter")
	GameState.add_gold(cost)
	var before: int = main.autosave.writes
	GameState.pay_into_station(&"counter", cost)
	assert_gt(main.autosave.writes, before, "station_upgraded writes at once")
	assert_eq(int(_saved().stations.counter.level), 1)

func test_tier_payment_marks_dirty_and_paid_up_writes() -> void:
	pc.start_new_game(9)
	pc.debug_skip_to_day()
	GameState.add_gold(500)
	main.autosave.flush()
	assert_false(main.autosave._dirty)
	EventBus.tier_changed.emit(1, 100, false)
	assert_true(main.autosave._dirty, "a tier payment is dirty")
	main.autosave.flush()
	var w0: int = main.autosave.writes
	GameState.pay_into_tier(500)
	assert_gt(main.autosave.writes, w0, "paid in full writes at once")
	assert_true(bool(_saved().boss_pending))

func test_tier_up_dawn_writes_the_card_pick_at_tier_2() -> void:
	pc.start_new_game(9)
	pc.debug_skip_to_day()
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	pc.debug_skip_to_night()
	pc.debug_skip_to_day()  # the won boss night: tier_reached writes before the reveal ends
	assert_true(pc.reveal_pending)
	var s := _saved()
	assert_eq(String(s.resume_phase), "CARD_PICK")
	assert_eq(int(s.tier), 2)
	assert_false(s.card_offer.is_empty())
