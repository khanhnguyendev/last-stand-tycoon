extends GutTest

const DIR := "user://test_settings_layer"
const SAVE_DIR := "user://test_settings_layer_save"

var main: Main
var sl: SettingsLayer
var ss: SettingsStore

func before_each() -> void:
	Balance.reset()
	SettingsStore.with_dir(DIR).wipe_for_tests()
	main = Main.create()
	add_child_autofree(main)
	main.settings_store = SettingsStore.with_dir(DIR)
	main.save_store = SaveStore.with_dir(SAVE_DIR)
	main.save_store.wipe()
	main.audio_director.setup(main.settings_store)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(77)
	sl = main.settings_layer
	ss = main.settings_store

func after_each() -> void:
	AudioServer.set_bus_mute(0, false)
	get_tree().paused = false
	SettingsStore.with_dir(DIR).wipe_for_tests()
	main.save_store.wipe()
	GameState.new_game(0)

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	main.get_viewport().push_input(e, true)

func _tap(pos: Vector2, index := 0) -> void:
	_touch(index, pos, true)
	_touch(index, pos, false)

func _tick(seconds: float) -> void:
	# The layer counts delta in _process; step it by hand so the test never depends on wall-clock time.
	var left := seconds
	while left > 0.0:
		var d := minf(left, 1.0 / 60.0)
		sl._process(d)
		left -= d

func test_gear_tap_opens_panel_and_joystick_stays_idle() -> void:
	assert_false(sl.panel_open())
	_touch(0, sl.gear_rect().get_center(), true)
	assert_false(main.joystick.is_active())
	_touch(0, sl.gear_rect().get_center(), false)
	assert_true(sl.panel_open())
	assert_false(main.joystick.is_active())
	assert_true(get_tree().paused, "the settings pause reason pauses the tree")

func test_panel_swallows_presses_behind_it() -> void:
	sl.open()
	_touch(1, Vector2(40, 900), true)
	assert_true(main.get_viewport().is_input_handled(), "the press was consumed")
	assert_false(main.joystick.is_active(), "a press anywhere while open never reaches the joystick")
	_touch(1, Vector2(40, 900), false)
	assert_true(sl.panel_open(), "a tap outside the buttons does not close the panel")

func test_sound_toggles_audio_and_display() -> void:
	sl.open()
	assert_false(main.audio_director.muted)
	_tap(sl.button_rects()[&"sound"].get_center())
	assert_true(main.audio_director.muted)
	assert_true(ss.muted)
	assert_eq(sl.sound_text(), "Sound: Off")
	_tap(sl.button_rects()[&"sound"].get_center())
	assert_false(main.audio_director.muted)
	assert_eq(sl.sound_text(), "Sound: On")

func test_new_game_arm_guard_and_expiry() -> void:
	sl.open()
	watch_signals(sl)
	var c: Vector2 = sl.button_rects()[&"new_game"].get_center()
	_tap(c)
	assert_true(sl.confirm_armed)
	assert_signal_not_emitted(sl, "new_game_requested")
	_tick(Balance.ui.card_input_guard_s * 0.5)
	_tap(c)
	assert_signal_not_emitted(sl, "new_game_requested", "a second tap inside the guard does nothing")
	assert_true(sl.confirm_armed)
	_tick(Balance.ui.card_input_guard_s)
	_tap(c)
	assert_signal_emitted(sl, "new_game_requested")
	assert_false(sl.confirm_armed)

func test_new_game_arm_expires() -> void:
	sl.open()
	watch_signals(sl)
	var c: Vector2 = sl.button_rects()[&"new_game"].get_center()
	_tap(c)
	_tick(Balance.ui.new_game_confirm_s + 0.2)
	assert_false(sl.confirm_armed, "the arm expired")
	_tap(c)
	assert_signal_not_emitted(sl, "new_game_requested")
	assert_true(sl.confirm_armed, "a late tap arms again")

func test_new_game_arm_counts_game_time_while_paused() -> void:
	sl.open()
	assert_true(get_tree().paused)
	_tap(sl.button_rects()[&"new_game"].get_center())
	for i in int(Balance.ui.new_game_confirm_s * 60.0) + 10:
		await get_tree().process_frame
	assert_false(sl.confirm_armed, "process frames expire the arm even though the tree is paused")

func test_full_new_game_through_main() -> void:
	main.save_store.write("{}")
	GameState.add_gold(500)
	main.settings_store.muted = true
	main.settings_store.save_settings()
	sl.open()
	var c: Vector2 = sl.button_rects()[&"new_game"].get_center()
	_tap(c)
	_tick(Balance.ui.card_input_guard_s + 0.1)
	_tap(c)
	assert_false(sl.panel_open())
	assert_false(main.pause_reasons.has(&"settings"))
	assert_false(get_tree().paused)
	assert_eq(GameState.day, 1)
	assert_eq(main.phase_controller.phase, Phase.NIGHT)
	assert_true(main.settings_store.muted)

func test_fresh_start_wipes_save_and_keeps_settings() -> void:
	main.settings_store.muted = true
	main.save_store.write("{\"x\":1}")
	main.phase_controller.debug_skip_to_day()
	main.fresh_start()
	assert_false(main.save_store.read().ok, "the save is gone")
	assert_eq(GameState.day, 1)
	assert_eq(main.phase_controller.phase, Phase.NIGHT)
	assert_true(main.settings_store.muted)

func test_close_unpauses() -> void:
	sl.open()
	assert_true(get_tree().paused)
	_tap(sl.button_rects()[&"close"].get_center())
	assert_false(sl.panel_open())
	assert_false(get_tree().paused)

func test_close_while_unfocused_stays_paused() -> void:
	main.add_pause_reason(&"focus")
	sl.open()
	_tap(sl.button_rects()[&"close"].get_center())
	assert_false(sl.panel_open())
	assert_true(get_tree().paused, "focus still holds the pause")
	main.remove_pause_reason(&"focus")
	assert_false(get_tree().paused)

func test_freeing_the_layer_while_open_releases_its_reason() -> void:
	sl.open()
	assert_true(main.pause_reasons.has(&"settings"))
	main.remove_child(sl)
	sl.free()
	assert_false(main.pause_reasons.has(&"settings"))
	assert_false(get_tree().paused)

func test_gear_over_open_card_overlay() -> void:
	var ov: CardPickOverlay = main.card_overlay
	watch_signals(EventBus)
	EventBus.card_offered.emit([&"hero_damage", &"archer", &"tank"])
	assert_true(ov.visible)
	assert_false(ov.accepting(), "inside the card input guard")
	_tap(sl.gear_rect().get_center())
	assert_true(sl.panel_open())
	assert_false(main.joystick.is_active())
	assert_signal_not_emitted(EventBus, "card_chosen")
	sl.close()
	for i in int(ceil(Balance.ui.card_input_guard_s * 60.0)) + 2:
		await get_tree().physics_frame
	assert_true(ov.accepting())
	assert_signal_not_emitted(EventBus, "card_chosen")

func test_landscape_resize_keeps_rects_inside() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(720, 1280)
	add_child_autofree(sv)
	var layer := SettingsLayer.new()
	sv.add_child(layer)
	layer.open()
	var vp := Rect2(Vector2.ZERO, Vector2(sv.size))
	for size in [Vector2i(720, 1280), Vector2i(1280, 720)]:
		sv.size = size
		await get_tree().process_frame
		vp = Rect2(Vector2.ZERO, Vector2(size))
		assert_true(vp.encloses(layer.gear_rect()), "gear inside %s" % size)
		for k in layer.button_rects():
			assert_true(vp.encloses(layer.button_rects()[k]), "%s inside %s" % [k, size])
		assert_almost_eq(layer.gear_rect().end.x, float(size.x) - Balance.ui.gear_margin, 0.01)
	layer.close()

func test_hud_arrow_rect_is_below_the_gear() -> void:
	assert_true(main.hud.reserved_rect.is_valid())
	assert_gte(main.hud.arrow_rect().position.y, sl.gear_rect().end.y)

func test_reserved_rect_pushes_the_arrow_rect_down() -> void:
	main.hud.reserved_rect = func(): return Rect2(0, 0, 10, 600)
	assert_gte(main.hud.arrow_rect().position.y, 600.0 + Balance.ui.arrow_hud_gap + Hud.arrow_extent())

func test_freed_layer_does_not_break_the_hud() -> void:
	main.remove_child(sl)
	sl.free()
	for i in 5:
		await get_tree().process_frame
	assert_false(main.hud.reserved_rect.is_valid())
	main.hud.arrow_rect()

func test_click_sound_fires_on_press_not_release() -> void:
	sl.open()
	watch_signals(EventBus)
	_touch(0, sl.button_rects()[&"close"].get_center(), true)
	assert_signal_emitted_with_parameters(EventBus, "sfx_requested", [&"click"])
	assert_signal_emit_count(EventBus, "sfx_requested", 1)
	_touch(0, sl.button_rects()[&"close"].get_center(), false)
	assert_signal_emit_count(EventBus, "sfx_requested", 1)
