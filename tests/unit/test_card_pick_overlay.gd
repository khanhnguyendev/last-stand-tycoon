extends GutTest

var main: Main
var pc: PhaseController
var ov: CardPickOverlay

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	pc = main.phase_controller
	main.hero.input.player_control = false
	pc.start_new_game(99)
	ov = main.get_node("CardPickOverlay")

func _dawn() -> void:
	EventBus.wave_cleared.emit(2)

func _wait_guard() -> void:
	for i in int(ceil(Balance.ui.card_input_guard_s * Engine.physics_ticks_per_second)) + 2:
		await get_tree().physics_frame

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	main.get_viewport().push_input(e, true)

func _mouse(pos: Vector2, pressed: bool, device := 0) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.pressed = pressed
	e.device = device
	main.get_viewport().push_input(e, true)

func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	main.get_viewport().push_input(e, true)

func test_hidden_until_offer_then_panels_match() -> void:
	assert_false(ov.visible)
	_dawn()
	assert_true(ov.visible)
	assert_eq(ov.offer, GameState.card_offer)
	assert_eq(ov.panel_rects().size(), 3)

func test_tap_release_on_same_panel_picks() -> void:
	_dawn()
	await _wait_guard()
	var want: StringName = GameState.card_offer[1]
	var c := ov.panel_rects()[1].get_center()
	_touch(0, c, true)
	_touch(0, c, false)
	assert_eq(GameState.card_level(want), 1)
	assert_eq(pc.phase, Phase.DAY)
	assert_false(ov.visible)

func test_press_one_release_other_does_nothing() -> void:
	_dawn()
	await _wait_guard()
	_touch(0, ov.panel_rects()[0].get_center(), true)
	_touch(0, ov.panel_rects()[2].get_center(), false)
	assert_eq(pc.phase, Phase.DAWN)
	assert_eq(GameState.cards, {})

func test_input_guard_ignores_early_taps() -> void:
	_dawn()
	var c := ov.panel_rects()[0].get_center()
	_touch(0, c, true)
	_touch(0, c, false)
	assert_eq(pc.phase, Phase.DAWN, "tap inside the guard time is ignored")
	await _wait_guard()
	_touch(1, c, true)
	_touch(1, c, false)
	assert_eq(pc.phase, Phase.DAY)

func test_keys_pick_after_guard() -> void:
	_dawn()
	var want: StringName = GameState.card_offer[2]
	_key(KEY_3)
	assert_eq(pc.phase, Phase.DAWN)
	await _wait_guard()
	_key(KEY_3)
	assert_eq(GameState.card_level(want), 1)

func test_mouse_click_picks_and_emulated_mouse_is_ignored() -> void:
	_dawn()
	await _wait_guard()
	var c := ov.panel_rects()[0].get_center()
	_mouse(c, true, InputEvent.DEVICE_ID_EMULATION)
	_mouse(c, false, InputEvent.DEVICE_ID_EMULATION)
	assert_eq(pc.phase, Phase.DAWN)
	_mouse(c, true)
	_mouse(c, false)
	assert_eq(pc.phase, Phase.DAY)

func test_held_stick_release_over_panel_does_not_pick() -> void:
	_touch(0, Vector2(200, 700), true)
	await get_tree().physics_frame
	assert_true(main.joystick.is_active())
	_dawn()
	await _wait_guard()
	assert_false(main.joystick.is_active(), "the dawn block ended the stick")
	_touch(0, ov.panel_rects()[1].get_center(), false)
	assert_eq(pc.phase, Phase.DAWN)

func test_after_debug_skip_overlay_hides_and_press_reaches_joystick() -> void:
	_dawn()
	await _wait_guard()
	var c := ov.panel_rects()[0].get_center()
	pc.debug_skip_to_day()
	assert_false(ov.visible)
	_touch(0, c, true)
	assert_true(main.joystick.is_active())
	_touch(0, c, false)

func test_pause_then_resume_still_picks() -> void:
	_dawn()
	await _wait_guard()
	var c := ov.panel_rects()[0].get_center()
	_touch(0, c, true)
	ov.notification(Node.NOTIFICATION_PAUSED)
	_touch(0, c, false)
	assert_eq(pc.phase, Phase.DAWN, "the paused press no longer owns the finger")
	_touch(1, c, true)
	_touch(1, c, false)
	assert_eq(pc.phase, Phase.DAY)

func test_layout_fits_landscape_and_two_cards() -> void:
	var ui := Balance.ui
	var none := {"top": 0, "bottom": 0, "left": 0, "right": 0}
	for vp in [Vector2(720, 1280), Vector2(1280, 720), Vector2(720, 1560)]:
		for n in [1, 2, 3]:
			var rects := CardPickOverlay.layout(vp, none, n, ui)
			assert_eq(rects.size(), n)
			for i in n:
				assert_true(Rect2(Vector2.ZERO, vp).encloses(rects[i]), "%s n=%d panel %d on screen" % [vp, n, i])
				assert_gte(rects[i].size.y, ui.card_panel_min_h)
				if i > 0:
					assert_false(rects[i].intersects(rects[i - 1]), "no overlap")
	assert_eq(CardPickOverlay.layout(Vector2(720, 1280), none, 3, ui)[0].size, ui.card_panel_size)
	var notch := {"top": 90, "bottom": 60, "left": 0, "right": 0}
	var r := CardPickOverlay.layout(Vector2(720, 1280), notch, 3, ui)
	assert_eq(r[0].size, ui.card_panel_size)
	assert_gte(r[0].position.y, 90.0)
	assert_lte(r[2].end.y, 1280.0 - 60.0)

func test_state_restored_hides_the_overlay() -> void:
	_dawn()
	assert_true(ov.visible)
	EventBus.state_restored.emit()
	assert_false(ov.visible)

func test_cancelled_touch_does_not_pick() -> void:
	_dawn()
	await _wait_guard()
	var c := ov.panel_rects()[0].get_center()
	_touch(0, c, true)
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = c
	e.pressed = false
	e.canceled = true
	main.get_viewport().push_input(e, true)
	assert_eq(pc.phase, Phase.DAWN)
	assert_eq(GameState.cards, {})
	_touch(0, c, true)
	_touch(0, c, false)
	assert_eq(pc.phase, Phase.DAY, "the cancelled finger was freed, so a normal tap picks")

func test_each_panel_has_a_portrait_of_its_card() -> void:
	_dawn()
	var panels: Array = ov._panels
	assert_eq(panels.size(), ov.offer.size())
	for i in panels.size():
		var portrait := panels[i].find_child("Portrait", true, false) as TextureRect
		assert_not_null(portrait, "panel %d" % i)
		assert_eq(portrait.texture.resource_path, CardCatalog.ICONS[ov.offer[i]])
		assert_eq(portrait.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_lte(portrait.custom_minimum_size.y, ov.panel_rects()[i].size.y - 32.0 + 0.01, "fits the panel")

func test_card_entrance_fits_input_guard() -> void:
	var ui := Balance.ui
	assert_lte(ui.card_stagger_s * 2.0 + ui.card_rise_s, ui.card_input_guard_s)

func _frames(seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		await get_tree().process_frame

func test_card_entrance_fades_rises_and_lands_on_final_rect() -> void:
	_dawn()
	var last: Control = ov._panels[2]
	var final_rect := ov.panel_rects()[2]
	assert_eq(last.modulate.a, 0.0)
	assert_almost_eq(last.position.y, final_rect.position.y + Balance.ui.card_rise_px, 0.01)
	await _frames(0.35)
	assert_eq(last.modulate.a, 1.0)
	assert_eq(last.position, final_rect.position)
	assert_eq(ov._panels[0].position, ov.panel_rects()[0].position)

func test_card_entrance_is_staggered() -> void:
	_dawn()
	await _frames(Balance.ui.card_stagger_s + 0.05)
	assert_gt(ov._panels[0].modulate.a, ov._panels[1].modulate.a)
	assert_gt(ov._panels[1].modulate.a, ov._panels[2].modulate.a)

func test_tap_at_final_rect_after_entrance_picks() -> void:
	_dawn()
	await _frames(0.6)
	var want: StringName = GameState.card_offer[2]
	var c := ov.panel_rects()[2].get_center()
	_touch(0, c, true)
	_touch(0, c, false)
	assert_eq(GameState.card_level(want), 1)
