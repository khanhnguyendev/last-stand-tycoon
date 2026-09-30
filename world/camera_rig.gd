class_name CameraRig
extends Node3D
## Follow camera (D-071, D-090, D-112). Uses CameraMath so tests and game agree. Visual only (_process).

var camera: Camera3D
var shake_count := 0
var _hero: Hero
var _focus := Vector2.ZERO
var _shake_left := 0.0
var _cooldown := 0.0
var _t := 0.0

func _ready() -> void:
	camera = Camera3D.new()
	add_child(camera)
	_apply_lens()
	get_viewport().size_changed.connect(_apply_lens)
	camera.current = true
	EventBus.diner_damaged.connect(_on_diner_damaged)
	EventBus.hero_place_requested.connect(snap_to)

func _apply_lens() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.y <= 0.0:
		return
	CameraMath.apply_lens(camera, Balance.ui, vp.x / vp.y)  # D-145: KEEP_HEIGHT on windows wider than 9:16

func setup(hero: Hero) -> void:
	_hero = hero
	snap()

func snap() -> void:
	if _hero == null:
		return
	snap_to(_hero.xz())

func snap_to(p: Vector2) -> void:
	_focus = CameraMath.focus_for(p)
	camera.global_transform = CameraMath.camera_transform(_focus, Balance.ui)

func _process(delta: float) -> void:
	if _hero == null:
		return
	_t += delta
	_cooldown -= delta
	var goal := CameraMath.focus_for(_hero.xz())
	_focus = _focus.lerp(goal, 1.0 - exp(-Balance.ui.camera_follow_rate * delta))
	var xf := CameraMath.camera_transform(_focus, Balance.ui)
	if _shake_left > 0.0:
		_shake_left -= delta
		var k := maxf(_shake_left, 0.0) / Balance.ui.shake_time
		xf.origin += Vector3(sin(_t * 97.0), cos(_t * 89.0), 0.0) * Balance.ui.shake_amp * k
	camera.global_transform = xf

func _on_diner_damaged(_amount: float, _hp_left: float) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = Balance.ui.shake_cooldown
	_shake_left = Balance.ui.shake_time
	shake_count += 1
