class_name Joystick
extends Control
## Floating one-thumb joystick (D-015, D-070, D-077). Screen up = north. Ignores edge strips and extra fingers.

var active_index := -2
var _input_api: HeroInput
var _base := Vector2.ZERO
var _knob := Vector2.ZERO
var _vec := Vector2.ZERO

func setup(input: HeroInput) -> void:
	_input_api = input

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _input(event: InputEvent) -> void:
	handle(event)

## While a touch is held, re-send the vector every tick: Hero.teleport clears the stored move
## and a still thumb produces no drag events (Task 15 review).
func _physics_process(_delta: float) -> void:
	if _input_api != null and _input_api.blocked:
		if is_active():
			_end()
		return
	if is_active() and _input_api != null:
		_input_api.set_move(_vec)

func is_active() -> bool:
	return active_index != -2

func handle(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if (not is_active() or event.index == active_index) and _allowed(event.position) and not _blocked():
				_begin(event.index, event.position)
		elif event.index == active_index:
			_end()
	elif event is InputEventScreenDrag:
		if event.index == active_index:
			_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if (not is_active() or active_index == -1) and _allowed(event.position) and not _blocked():
				_begin(-1, event.position)
		elif active_index == -1:
			_end()
	elif event is InputEventMouseMotion and active_index == -1:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
			_end()  # the release happened outside the window
		else:
			_drag(event.position)

func _blocked() -> bool:
	return _input_api != null and _input_api.blocked

func _allowed(p: Vector2) -> bool:
	var w := get_viewport_rect().size.x
	var e := Balance.ui.edge_ignore_px
	return p.x >= e and p.x <= w - e

func _begin(i: int, p: Vector2) -> void:
	active_index = i
	_base = p
	_knob = Vector2.ZERO
	_vec = Vector2.ZERO
	_input_api.set_move(Vector2.ZERO)
	queue_redraw()

func _drag(p: Vector2) -> void:
	var r := Balance.ui.joystick_radius_px
	_knob = (p - _base).limit_length(r)
	var v := _knob / r
	_vec = Vector2.ZERO if v.length() < Balance.ui.joystick_deadzone else v
	_input_api.set_move(_vec)
	queue_redraw()

func _end() -> void:
	active_index = -2
	_knob = Vector2.ZERO
	_vec = Vector2.ZERO
	_input_api.set_move(Vector2.ZERO)
	queue_redraw()

## D-147: a paused tree drops the touch release, so end the stick when the tree pauses (Main's pause reasons, D-218).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and is_active():
		_end()

func _draw() -> void:
	if not is_active():
		return
	var r := Balance.ui.joystick_radius_px
	# Atlas cells only (D-201): the ring and knob are baked with their own colour and alpha (spec 7).
	var atlas := IconAtlas.texture()
	draw_texture_rect_region(atlas, IconAtlas.shape_dest(Rect2(_base - Vector2.ONE * r, Vector2.ONE * r * 2.0)), IconAtlas.region(&"stick_ring"))
	var kr := r * 0.45
	draw_texture_rect_region(atlas, IconAtlas.shape_dest(Rect2(_base + _knob - Vector2.ONE * kr, Vector2.ONE * kr * 2.0)), IconAtlas.region(&"stick_knob"))
