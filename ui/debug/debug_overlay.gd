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
var _rect := Rect2()
var _owned := {}
var _label: Label
var _warnings: Array = []
var _scene_query := {}
var _state_left := 0.0

func _init() -> void:
	name = "DebugOverlay"

func setup(main: Main) -> void:
	_main = main
	name = "DebugOverlay"
	layer = 30
	_label = Label.new()
	_label.theme_type_variation = &"HudLabel"
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
	if OS.has_feature("web"):
		var raw := str(JavaScriptBridge.eval("window.location.search", true))
		var scenes = load("res://ui/debug/debug_scenes.gd")
		_scene_query = scenes.parse(raw)
		if scenes.has_fresh_start_key(raw):
			main.debug_fresh_start = true
		EventBus.phase_changed.connect(_on_first_phase, CONNECT_ONE_SHOT)

## The URL scene waits for the game's first NIGHT (Main starts it deferred) and then runs deferred, so it never
## re-enters PhaseController while _enter_night is still emitting phase_changed.
func _on_first_phase(_phase: int, _day: int) -> void:
	_apply_scene.call_deferred()

func _apply_scene() -> void:
	load("res://ui/debug/debug_scenes.gd").apply(_main, _scene_query)

func _process(delta: float) -> void:
	if _main == null:
		return
	_publish_state(delta)
	var wd := _main.world.wave_director
	_label.text = "seed %d\nday %d  %s\nwave %d  alive %d\nfps %d\n%s" % [GameState.run_seed, GameState.day,
		Phase.name_of(_main.phase_controller.phase), wd.wave_index, wd.alive_count(),
		Engine.get_frames_per_second(), "\n".join(_warnings)]

## Web debug only (S5 Task 11): window.LST_STATE = {unlocked, muted, music_id}, once a second, for export/pw_s5_check.mjs.
func _publish_state(delta: float) -> void:
	_state_left -= delta
	if _state_left > 0.0 or not OS.has_feature("web") or _main.audio_director == null:
		return
	_state_left = 1.0
	var a := _main.audio_director
	JavaScriptBridge.eval("window.LST_STATE=" + JSON.stringify({"unlocked": a.unlocked, "muted": a.muted, "music_id": String(a.music_id)}), true)

## Bottom-right, inside the safe area, clear of the joystick's edge strips and above the bottom inset.
func button_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	var ins := SafeArea.insets(vp)
	var right: float = vp.x - float(ins.right) - Balance.ui.edge_ignore_px - BUTTON_MARGIN
	var bottom: float = vp.y - float(ins.bottom) - BUTTON_MARGIN
	return Rect2(Vector2(right - BUTTON_SIZE.x, bottom - BUTTON_SIZE.y), BUTTON_SIZE)

func _place_button() -> void:
	_rect = button_rect()
	var r := _rect
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
## so a press on the button is consumed here and never starts the stick. A release is consumed only when
## this button owns that finger, so the release of a stick touch that ends over the button still reaches
## the joystick.
func _input(event: InputEvent) -> void:
	var idx := -1
	var pressed := false
	if event is InputEventScreenTouch:
		idx = event.index
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
	else:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if pressed:
		_owned.erase(idx)  # a new press of this index means its old touch ended (a dropped release)
		if _rect.has_point(event.position):
			_owned[idx] = true
			cycle_occluder_alpha()
			get_viewport().set_input_as_handled()
	elif _owned.erase(idx):
		get_viewport().set_input_as_handled()

## D-147: a paused tree drops touch releases, so forget every owned finger.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_owned.clear()

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
		KEY_R: _main.fresh_start()
		KEY_F:
			if _main.phase_controller.phase == Phase.NIGHT:
				GameState.damage_diner(1e9)
