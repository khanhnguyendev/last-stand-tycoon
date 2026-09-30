extends GutTest
## Task 32: overlays, build label and the CP2 occluder-alpha picker (D-151). Picker tests go through the
## overlay Main itself adds (debug builds), so they also prove it is added after InputLayer.

func before_each() -> void:
	Balance.reset()

func _touch(vp: Viewport, pos: Vector2, pressed: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	vp.push_input(e, true)  # local coords: the headless window would rescale the point

func _main_with_overlay() -> Array:
	var main := Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	return [main, main.get_node_or_null("DebugOverlay")]

func test_perf_overlay_stats() -> void:
	var p := PerfOverlay.new()
	add_child_autofree(p)
	for i in 59:
		p.record(1.0 / 60.0)
	p.record(0.120)
	assert_almost_eq(p.worst_ms(), 120.0, 0.01)
	assert_lt(p.avg_fps(), 60.0)

func test_perf_overlay_window_drops_old_frames() -> void:
	var p := PerfOverlay.new()
	add_child_autofree(p)
	p.record(0.5)
	for i in 4000:
		p.record(1.0 / 60.0)
	assert_lt(p.worst_ms(), 100.0, "the 0.5 s frame left the 60 s window")

func test_debug_overlay_hotkey_gold() -> void:
	if not OS.is_debug_build():
		pass_test("release runner: overlay intentionally absent")
		return
	var main := Main.create()
	add_child_autofree(main)
	main.phase_controller.start_new_game(101)
	var o := main.get_node_or_null("DebugOverlay")
	assert_not_null(o)
	o.handle_key(KEY_G)
	assert_eq(GameState.gold, 100)

func test_main_does_not_preload_debug() -> void:
	var src := FileAccess.get_file_as_string("res://world/main.gd")
	assert_false(src.contains("preload(\"res://ui/debug"), "debug overlay must be load()ed, never preloaded (D-099)")

func test_build_label_off_web_is_dev() -> void:
	assert_eq(BuildLabel.build_id(), "dev")
	var b := BuildLabel.new()
	add_child_autofree(b)
	assert_eq(b.layer, 100)
	var l: Label = b.get_child(0)
	assert_eq(l.text, "dev")
	assert_almost_eq(l.modulate.a, 0.5, 1e-4)
	assert_eq(l.get_theme_font_size("font_size"), 14)

func test_main_adds_build_label_once() -> void:
	var main := Main.create()
	add_child_autofree(main)
	assert_eq(main.get_children().filter(func(c): return c is BuildLabel).size(), 1)

func test_main_gates_overlays_by_build_and_feature() -> void:
	var src := FileAccess.get_file_as_string("res://world/main.gd")
	assert_true(src.contains("profile_overlay"))
	assert_true(src.contains("OS.is_debug_build()"))

func test_d157_export_keeps_tres_as_text() -> void:
	assert_false(ProjectSettings.get_setting("editor/export/convert_text_resources_to_binary", true),
		"D-157: export must keep .tres as text")

# --- occluder-alpha picker (D-151); debug builds only ---

func test_fade_alpha_cycles_three_values_and_writes_balance() -> void:
	if not OS.is_debug_build():
		pass_test("debug build only")
		return
	var o: Node = _main_with_overlay()[1]
	assert_not_null(o)
	assert_almost_eq(Balance.ui.occluder_alpha, 0.30, 1e-4)
	o.cycle_occluder_alpha()
	assert_almost_eq(Balance.ui.occluder_alpha, 0.45, 1e-4)
	o.cycle_occluder_alpha()
	assert_almost_eq(Balance.ui.occluder_alpha, 0.60, 1e-4)
	o.cycle_occluder_alpha()
	assert_almost_eq(Balance.ui.occluder_alpha, 0.30, 1e-4)

func test_real_o_key_event_cycles_exactly_once_and_button_shows_value() -> void:
	if not OS.is_debug_build():
		pass_test("debug build only")
		return
	var pair := _main_with_overlay()
	var main: Main = pair[0]
	var o: Node = pair[1]
	assert_eq(o.fade_button.text, "Fade alpha 0.30")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_O
	e.keycode = KEY_O
	e.pressed = true
	main.get_viewport().push_input(e, true)
	assert_almost_eq(Balance.ui.occluder_alpha, 0.45, 1e-4)
	assert_eq(o.fade_button.text, "Fade alpha 0.45")

func test_active_occluder_fade_follows_live_alpha_change() -> void:
	if not OS.is_debug_build():
		pass_test("debug build only")
		return
	var pair := _main_with_overlay()
	var main: Main = pair[0]
	var o: Node = pair[1]
	main.phase_controller.start_new_game(72)
	main.hero.teleport((MapLayout.ZONE_RECTS["north"] as Rect2).get_center())
	main.camera_rig.snap()
	for i in 40:
		await get_tree().process_frame
	assert_true(main.world.occluder_fade.is_faded())
	assert_almost_eq(main.world.occluder_fade.current_alpha(), 0.30, 1e-3)
	o.cycle_occluder_alpha()
	for i in 40:
		await get_tree().process_frame
	assert_almost_eq(main.world.occluder_fade.current_alpha(), 0.45, 1e-3)

func test_button_rect_is_bottom_right_inside_safe_area_clear_of_edge_strips() -> void:
	if not OS.is_debug_build():
		pass_test("debug build only")
		return
	var pair := _main_with_overlay()
	var main: Main = pair[0]
	var o: Node = pair[1]
	var vp := main.get_viewport().get_visible_rect().size
	var r: Rect2 = o.button_rect()
	var ins := SafeArea.insets(vp)
	assert_lte(r.end.x, vp.x - ins.right - Balance.ui.edge_ignore_px - 8.0, "clear of the joystick edge strip")
	assert_lte(r.end.y, vp.y - ins.bottom, "above the bottom inset")
	assert_gt(r.position.x, vp.x * 0.5, "right half")
	assert_gt(r.position.y, vp.y * 0.75, "bottom quarter")

func test_touch_on_button_cycles_and_does_not_start_the_stick() -> void:
	if not OS.is_debug_build():
		pass_test("debug build only")
		return
	var pair := _main_with_overlay()
	var main: Main = pair[0]
	var c: Vector2 = pair[1].button_rect().get_center()
	_touch(main.get_viewport(), c, true)
	assert_false(main.joystick.is_active(), "a press on the button must not start the stick")
	assert_almost_eq(Balance.ui.occluder_alpha, 0.45, 1e-4, "press cycles once")
	_touch(main.get_viewport(), c, false)
	assert_almost_eq(Balance.ui.occluder_alpha, 0.45, 1e-4, "release does not cycle")

func test_stick_released_over_button_still_ends() -> void:
	if not OS.is_debug_build():
		pass_test("debug build only")
		return
	var pair := _main_with_overlay()
	var main: Main = pair[0]
	_touch(main.get_viewport(), Vector2(200, 700), true)
	assert_true(main.joystick.is_active())
	_touch(main.get_viewport(), pair[1].button_rect().get_center(), false)
	assert_false(main.joystick.is_active(), "the stick's release must not be swallowed by the button")
	assert_almost_eq(Balance.ui.occluder_alpha, 0.30, 1e-4, "no cycle")

func test_touch_elsewhere_still_starts_the_stick() -> void:
	if not OS.is_debug_build():
		pass_test("debug build only")
		return
	var main: Main = _main_with_overlay()[0]
	_touch(main.get_viewport(), Vector2(200, 700), true)
	assert_true(main.joystick.is_active())
	_touch(main.get_viewport(), Vector2(200, 700), false)

func test_mouse_click_on_button_cycles_once_and_skips_stick() -> void:
	if not OS.is_debug_build():
		pass_test("debug build only")
		return
	var pair := _main_with_overlay()
	var main: Main = pair[0]
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pair[1].button_rect().get_center()
	e.pressed = true
	main.get_viewport().push_input(e, true)
	assert_false(main.joystick.is_active())
	assert_almost_eq(Balance.ui.occluder_alpha, 0.45, 1e-4)

func test_emulated_mouse_event_on_button_is_ignored() -> void:
	if not OS.is_debug_build():
		pass_test("debug build only")
		return
	var pair := _main_with_overlay()
	var main: Main = pair[0]
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.device = InputEvent.DEVICE_ID_EMULATION
	e.position = pair[1].button_rect().get_center()
	e.pressed = true
	main.get_viewport().push_input(e, true)
	assert_almost_eq(Balance.ui.occluder_alpha, 0.30, 1e-4)

func test_stale_owned_finger_does_not_swallow_the_stick_release() -> void:
	if not OS.is_debug_build():
		pass_test("debug build only")
		return
	var pair := _main_with_overlay()
	var main: Main = pair[0]
	var vp := main.get_viewport()
	_touch(vp, pair[1].button_rect().get_center(), true)  # index 0 owned by the button, release dropped
	_touch(vp, Vector2(200, 700), true)                    # same index again: starts the stick
	assert_true(main.joystick.is_active())
	_touch(vp, pair[1].button_rect().get_center(), false)
	assert_false(main.joystick.is_active(), "the stale owned index must not swallow this release")
