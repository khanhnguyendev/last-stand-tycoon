extends GutTest

var main: Main
var pc: PhaseController
var dir := ""

func before_each() -> void:
	Balance.reset()
	dir = "user://test_saves/rs_%d" % Time.get_ticks_usec()

func after_each() -> void:
	SaveStore.with_dir(dir).wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_saves"))

## A fresh Main that boots from the store in `dir`, as the real boot does.
func _boot() -> void:
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	pc = main.phase_controller
	main.save_store = SaveStore.with_dir(dir)
	main.autosave.store = main.save_store
	main._boot()

## Play a first session with autosave on, then drop it (a "quit"). Always `await _session(...)`.
func _session(play: Callable) -> void:
	_boot()
	await play.call()
	remove_child(main)
	main.free()
	GameState.new_game(1)  # a quit is a process restart: every later check must come from the save

func _fail_ticks() -> int:
	return int(ceil(Balance.ui.banner_time * Engine.physics_ticks_per_second)) + 3

func test_no_save_starts_a_new_game() -> void:
	_boot()
	assert_eq([pc.phase, GameState.day], [Phase.NIGHT, 1])

func test_day_resumes_at_home_with_same_state() -> void:
	await _session(func():
		pc.debug_skip_to_day()
		GameState.add_gold(GameState.next_level_cost("fence_w") + 17)
		GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w")))
	var gold := -1
	var s: Dictionary = SaveStore.with_dir(dir).read().state
	gold = int(s.gold)
	_boot()
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.gold, gold)
	assert_eq(int(GameState.buildings.fence_w.level), 1)
	assert_eq(main.hero.xz(), MapLayout.HOME)

func test_card_pick_resumes_with_same_offer_and_overlay() -> void:
	var offer: Array = []
	await _session(func():
		EventBus.wave_cleared.emit(GameState.lane_plan.size() - 1)
		offer.append_array(GameState.card_offer))  # lambdas capture locals by value; mutate, don't reassign
	_boot()
	assert_eq([pc.phase, pc.dawn_substate], [Phase.DAWN, "CARD_PICK"])
	assert_eq(Array(GameState.card_offer), offer)
	assert_true(main.card_overlay.visible)
	assert_true(main.hero.input.blocked)

func test_night_save_resumes_night1_start() -> void:
	var seeds: Array = []
	await _session(func(): seeds.append(GameState.run_seed))  # the new-game save
	_boot()
	assert_eq(GameState.run_seed, seeds[0], "resumed, not a new random seed")
	assert_eq([pc.phase, GameState.day], [Phase.NIGHT, 1])
	assert_eq(main.hero.xz(), MapLayout.NIGHT1_START)

func test_quit_mid_night_resumes_the_day_without_mercy() -> void:
	await _session(func():
		pc.debug_skip_to_day()
		pc.close_up()
		GameState.damage_diner(1e6)
		for i in _fail_ticks():
			await get_tree().physics_frame
		pc.close_up())  # night 3 with night_fails 1 saved; quit mid-night
	_boot()
	assert_eq(pc.phase, Phase.DAY)
	assert_eq(GameState.night_fails, 1, "the quit adds no mercy; the count is what the real fail earned (D-174)")

func test_quit_during_night1_retry_keeps_mercy() -> void:
	await _session(func():
		GameState.damage_diner(1e6)
		for i in _fail_ticks():
			await get_tree().physics_frame)
	await get_tree().process_frame
	_boot()
	assert_false("The monsters look tired tonight." in main.hud._banner_queue)
	assert_ne(main.hud.banner.text, "The monsters look tired tonight.")
	assert_eq([pc.phase, GameState.night_fails], [Phase.NIGHT, 1])
	GameState.damage_diner(1e6)
	for i in _fail_ticks():
		await get_tree().physics_frame
	assert_eq(GameState.night_fails, 2)

func test_corrupt_primary_uses_backup_and_both_corrupt_starts_fresh() -> void:
	await _session(func():
		pc.debug_skip_to_day()
		GameState.add_gold(5)
		main.autosave.flush())
	var f := FileAccess.open(dir.path_join("save.json"), FileAccess.WRITE)
	f.store_string("{bad")
	f.close()
	_boot()
	assert_eq(pc.phase, Phase.DAY, "resumed from the backup")
	remove_child(main)
	main.free()
	for n in ["save.json", "save_bak.json"]:
		var g := FileAccess.open(dir.path_join(n), FileAccess.WRITE)
		g.store_string("{bad")
		g.close()
	_boot()
	assert_eq([pc.phase, GameState.day], [Phase.NIGHT, 1])

func test_newer_save_starts_fresh_and_keeps_it() -> void:
	GameState.new_game(3)
	var s := GameState.to_dict()
	s.resume_phase = "DAY"
	s.v = GameState.SCHEMA_VERSION + 1
	var newer := SaveCodec.encode(s, "future", 1)
	SaveStore.with_dir(dir).write(newer)
	_boot()
	assert_eq([pc.phase, GameState.day], [Phase.NIGHT, 1])
	pc.debug_skip_to_day()
	assert_eq(FileAccess.get_file_as_string(dir.path_join("save.json")), newer, "never overwritten")

func test_debug_fresh_start_wipes() -> void:
	await _session(func():
		pc.debug_skip_to_day()
		GameState.add_gold(1)
		main.autosave.flush())  # two writes: a backup exists
	assert_true(FileAccess.file_exists(dir.path_join("save_bak.json")))
	main = Main.create()
	add_child_autofree(main)
	main.save_store = SaveStore.with_dir(dir)
	main.autosave.store = main.save_store
	main.debug_fresh_start = true
	main._boot()
	assert_eq([main.phase_controller.phase, GameState.day], [Phase.NIGHT, 1])
	assert_ne(GameState.run_seed, 1, "a fresh random seed, not the post-quit state")
	assert_false(FileAccess.file_exists(dir.path_join("save_bak.json")), "wiped: no backup of the old run")

func test_debug_r_key_wipes_and_restarts() -> void:
	if not OS.is_debug_build():
		pass_test("debug build only")
		return
	await _session(func():
		pc.debug_skip_to_day()
		GameState.add_gold(1)
		main.autosave.flush())
	_boot()
	assert_eq(pc.phase, Phase.DAY)
	main.get_node("DebugOverlay").handle_key(KEY_R)
	assert_eq([pc.phase, GameState.day], [Phase.NIGHT, 1])
	assert_false(FileAccess.file_exists(dir.path_join("save_bak.json")))
