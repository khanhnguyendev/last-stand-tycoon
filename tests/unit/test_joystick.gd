extends GutTest

var input: HeroInput
var js: Joystick

func before_each() -> void:
	Balance.reset()
	input = HeroInput.new()
	input.player_control = false
	add_child_autofree(input)
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	js = Joystick.new()
	layer.add_child(js)
	js.setup(input)

func _touch(i: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = pos
	e.pressed = pressed
	js.handle(e)

func _drag(i: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = pos
	js.handle(e)

func test_drag_moves_full_right() -> void:
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(360 + 64, 900))
	assert_almost_eq(input.get_move().x, 1.0, 0.001)
	_drag(0, Vector2(360 + 200, 900))
	assert_almost_eq(input.get_move().length(), 1.0, 0.001, "clamped to radius")

func test_up_is_north() -> void:
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(360, 900 - 64))
	assert_almost_eq(input.get_move().y, -1.0, 0.001)

func test_deadzone() -> void:
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(365, 900))
	assert_eq(input.get_move(), Vector2.ZERO)

func test_release_stops() -> void:
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(424, 900))
	_touch(0, Vector2(424, 900), false)
	assert_eq(input.get_move(), Vector2.ZERO)
	assert_false(js.is_active())

func test_second_finger_ignored() -> void:
	# Review Focus 4
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(424, 900))
	_touch(1, Vector2(200, 400), true)
	_drag(1, Vector2(100, 400))
	_touch(1, Vector2(100, 400), false)
	assert_true(js.is_active())
	assert_almost_eq(input.get_move().x, 1.0, 0.001)

func test_edge_strip_touch_ignored() -> void:
	# Review Focus 4
	_touch(0, Vector2(8, 900), true)
	assert_false(js.is_active())
	var w := js.get_viewport_rect().size.x
	_touch(1, Vector2(w - 8, 900), true)
	assert_false(js.is_active())

func test_mouse_drag_works() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(360, 900)
	js.handle(down)
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(360, 964)
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	js.handle(mv)
	assert_almost_eq(input.get_move().y, 1.0, 0.001)

func test_move_reapplied_every_physics_tick() -> void:
	# Hero.teleport clears the stored move; a still thumb must not leave the hero stopped.
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(360 + 64, 900))
	input.set_move(Vector2.ZERO)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_almost_eq(input.get_move().x, 1.0, 0.001, "restored without a drag event")

func test_idle_stick_leaves_input_alone() -> void:
	input.set_move(Vector2(0.5, 0.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(input.get_move(), Vector2(0.5, 0.0))

func test_pause_notification_ends_stick() -> void:
	# D-147
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(424, 900))
	js.notification(Node.NOTIFICATION_PAUSED)
	assert_false(js.is_active())
	assert_eq(input.get_move(), Vector2.ZERO)

func test_buttonless_mouse_motion_ends_stick() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(360, 900)
	js.handle(down)
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(424, 900)
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	js.handle(mv)
	assert_almost_eq(input.get_move().x, 1.0, 0.001)
	var up := InputEventMouseMotion.new()
	up.position = Vector2(430, 900)
	up.button_mask = 0
	js.handle(up)
	assert_false(js.is_active())
	assert_eq(input.get_move(), Vector2.ZERO)

func test_mouse_release_ends_stick() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(360, 900)
	js.handle(down)
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(424, 900)
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	js.handle(mv)
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = Vector2(424, 900)
	js.handle(rel)
	assert_false(js.is_active())
	assert_eq(input.get_move(), Vector2.ZERO)

func test_repress_with_active_index_restarts_at_new_base() -> void:
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(424, 900))
	_touch(0, Vector2(200, 700), true)
	assert_true(js.is_active())
	assert_eq(input.get_move(), Vector2.ZERO, "new base, knob at centre")
	_drag(0, Vector2(200, 700 - 64))
	assert_almost_eq(input.get_move().y, -1.0, 0.001)

func test_first_finger_lift_ends_while_second_held() -> void:
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(424, 900))
	_touch(1, Vector2(200, 400), true)
	_touch(0, Vector2(424, 900), false)
	assert_false(js.is_active())
	assert_eq(input.get_move(), Vector2.ZERO)
	_drag(1, Vector2(100, 400))
	assert_false(js.is_active())
	assert_eq(input.get_move(), Vector2.ZERO)

func test_real_tree_pause_ends_stick() -> void:
	# D-147: gut keeps running while paused; the stick's own branch is pausable.
	var old_mode := gut.process_mode
	gut.process_mode = Node.PROCESS_MODE_ALWAYS
	js.get_parent().process_mode = Node.PROCESS_MODE_PAUSABLE
	_touch(0, Vector2(360, 900), true)
	_drag(0, Vector2(424, 900))
	get_tree().paused = true
	var ended := not js.is_active()
	get_tree().paused = false
	gut.process_mode = old_mode
	assert_true(ended)
	assert_eq(input.get_move(), Vector2.ZERO)

func test_main_wires_joystick_in_input_layer() -> void:
	var m := Main.create()
	add_child_autofree(m)
	var layer := m.joystick.get_parent() as CanvasLayer
	assert_eq(layer.name, &"InputLayer")
	assert_eq(layer.layer, 5)
