extends CanvasLayer
## Debug builds only (D-047, D-099, D-115). Loaded with load() from Main; excluded from release/profile.
## Also hosts the CP2 occluder-alpha picker (D-151): a bottom-right button and the O key cycle
## Balance.ui.occluder_alpha through 0.30 / 0.45 / 0.60; OccluderFade reads it every frame.

const ALPHAS: Array[float] = [0.30, 0.45, 0.60]
const BUTTON_SIZE := Vector2(250, 64)
## Gap to the safe-area edge, on top of the joystick's edge_ignore_px strip.
const BUTTON_MARGIN := 24.0

var fade_button: Button
var _main: Main
var _label: Label
var _warnings: Array = []

func setup(main: Main) -> void:
	_main = main
	name = "DebugOverlay"
	layer = 30
	_label = Label.new()
	_label.position = Vector2(420, 110)
	_label.add_theme_font_size_override("font_size", 20)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	# Visual only: the overlay's own _input handles the press, so the Button never needs the mouse.
	fade_button = Button.new()
	fade_button.focus_mode = Control.FOCUS_NONE
	fade_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_button.add_theme_font_size_override("font_size", 26)
	add_child(fade_button)
	_refresh_button()
	get_viewport().size_changed.connect(_place_button)
	_place_button()
	for pool in main.find_children("*", "NodePool", true, false):
		pool.grew.connect(func(n: int): _warnings.append("%s grew to %d" % [pool.name, n]))

func _process(_delta: float) -> void:
	if _main == null:
		return
	var wd := _main.world.wave_director
	_label.text = "seed %d\nday %d  %s\nwave %d  alive %d\nfps %d\n%s" % [GameState.run_seed, GameState.day,
		Phase.name_of(_main.phase_controller.phase), wd.wave_index, wd.alive_count(),
		Engine.get_frames_per_second(), "\n".join(_warnings)]

## Bottom-right, inside the safe area, clear of the joystick's edge strips and above the bottom inset.
func button_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	var ins := SafeArea.insets(vp)
	var right: float = vp.x - float(ins.right) - Balance.ui.edge_ignore_px - BUTTON_MARGIN
	var bottom: float = vp.y - float(ins.bottom) - BUTTON_MARGIN
	return Rect2(Vector2(right - BUTTON_SIZE.x, bottom - BUTTON_SIZE.y), BUTTON_SIZE)

func _place_button() -> void:
	var r := button_rect()
	fade_button.position = r.position
	fade_button.size = r.size

func _refresh_button() -> void:
	fade_button.text = "Fade alpha %.2f" % Balance.ui.occluder_alpha

func cycle_occluder_alpha() -> void:
	var cur := Balance.ui.occluder_alpha
	var idx := 0
	for i in ALPHAS.size():
		if absf(ALPHAS[i] - cur) < absf(ALPHAS[idx] - cur):
			idx = i
	Balance.ui.occluder_alpha = ALPHAS[(idx + 1) % ALPHAS.size()]
	_refresh_button()

## Runs before the joystick's _input (this node is added after InputLayer; _input goes last-added first),
## so a press on the button is consumed here and never starts the stick. Release is consumed too.
func _input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = event.pressed
	else:
		return
	if not button_rect().has_point(pos):
		return
	if pressed:
		cycle_occluder_alpha()
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		handle_key(event.physical_keycode)

func handle_key(keycode: Key) -> void:
	match keycode:
		KEY_G: GameState.add_gold(100)
		KEY_J: _main.phase_controller.debug_skip_to_day()
		KEY_N: _main.phase_controller.debug_skip_to_night()
		KEY_K: _main.world.wave_director.debug_kill_all()
		KEY_O: cycle_occluder_alpha()
		KEY_F:
			if _main.phase_controller.phase == Phase.NIGHT:
				GameState.damage_diner(1e9)
