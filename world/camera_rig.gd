class_name CameraRig
extends Node3D
## Follow camera (D-071, D-090, D-112). Uses CameraMath so tests and game agree. Visual only (_process).

var camera: Camera3D
var shake_count := 0
var _hero: Hero
var _focus := Vector2.ZERO
var _shake_left := 0.0
var _shake_time := 0.0
var _shake_amp := 0.0
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
	EventBus.state_restored.connect(_on_state_restored)
	EventBus.diner_fell.connect(func(): shake(Balance.ui.shake_fell_amp, Balance.ui.shake_fell_time, false))

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
		xf.origin += Vector3(sin(_t * 97.0), cos(_t * 89.0), 0.0) * shake_amp_now()
	camera.global_transform = xf

## A restore ends any shake in progress (the hit that started it never happened, D-045).
func _on_state_restored() -> void:
	_shake_left = 0.0
	_shake_amp = 0.0
	_shake_time = 0.0
	_cooldown = 0.0

func _on_diner_damaged(_amount: float, _hp_left: float) -> void:
	shake(Balance.ui.shake_amp, Balance.ui.shake_time, true)

## Overlapping shakes merge: the larger amplitude and the longer remaining time (S5 spec 5.2).
func shake(amp: float, time: float, respect_cooldown: bool) -> void:
	if not Balance.ui.shake_enabled:
		return
	if respect_cooldown:
		if _cooldown > 0.0:
			return
		_cooldown = Balance.ui.shake_cooldown
	if _shake_left <= 0.0:
		_shake_amp = 0.0
		_shake_time = 0.0
	_shake_amp = maxf(_shake_amp, amp)
	_shake_left = maxf(_shake_left, time)
	_shake_time = maxf(_shake_time, time)
	shake_count += 1

func shake_amp_now() -> float:
	return _shake_amp * maxf(_shake_left, 0.0) / _shake_time if _shake_time > 0.0 else 0.0
