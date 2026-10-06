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
var _zoom := 1.0
var _rv_active := false
var _rv_t := 0.0
var _rv_in := 0.0
var _rv_hold := 0.0
var _rv_out := 0.0
var _rv_zoom := 1.0
var _rv_focus := Vector2.ZERO
var _rv_has_focus := false
var _rv_w := 0.0  ## 0..1: how far into the reveal pose (zoom and focus) the camera is

func _ready() -> void:
	camera = Camera3D.new()
	add_child(camera)
	_apply_lens()
	get_viewport().size_changed.connect(_apply_lens)
	camera.current = true
	EventBus.diner_damaged.connect(_on_diner_damaged)
	EventBus.hero_place_requested.connect(snap_to)
	EventBus.state_restored.connect(_on_state_restored)
	EventBus.camera_reveal_requested.connect(reveal)
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
	cancel_reveal()
	camera.global_transform = CameraMath.camera_transform(_focus, Balance.ui)

func _process(delta: float) -> void:
	if _hero == null:
		return
	_t += delta
	_zoom_step(delta)
	_cooldown -= delta
	var goal := CameraMath.focus_for(_hero.xz())
	_focus = _focus.lerp(goal, 1.0 - exp(-Balance.ui.camera_follow_rate * delta))
	var shown := _focus.lerp(_rv_focus, _rv_w) if _rv_has_focus else _focus  # the reveal focus is used as given (no clamp)
	var xf := CameraMath.zoomed_transform(shown, Balance.ui, _zoom)
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
	cancel_reveal()

## E5 spec 7.5: a visual pull-back (the camera moves away from the focus along its view line, x zoom): eased out over
## seconds_in, held for hold_s, eased back over seconds_out. With `reveal_focus` (not INF) the focus glides from the hero
## follow focus to it during the ease-in and back to the follow focus during the ease-out. Runs in _process; writes
## nothing but the camera transform.
func reveal(seconds_in: float, hold_s: float, seconds_out: float, zoom: float, reveal_focus := Vector2.INF) -> void:
	_rv_has_focus = reveal_focus.is_finite()
	_rv_focus = reveal_focus if _rv_has_focus else Vector2.ZERO
	_rv_in = maxf(seconds_in, 1e-3)
	_rv_hold = maxf(hold_s, 0.0)
	_rv_out = maxf(seconds_out, 1e-3)
	_rv_zoom = zoom
	_rv_t = 0.0
	_rv_active = true

func zoom_now() -> float:
	return _zoom

func has_focus_override() -> bool:
	return _rv_has_focus

## Ends a reveal at once: zoom 1.0 (a restore, snap_to).
func cancel_reveal() -> void:
	_rv_active = false
	_rv_has_focus = false
	_rv_t = 0.0
	_rv_w = 0.0
	_zoom = 1.0

func _zoom_step(delta: float) -> void:
	if not _rv_active:
		return
	_rv_t += delta
	if _rv_t < _rv_in:
		_rv_w = ease(_rv_t / _rv_in, -2.0)
	elif _rv_t < _rv_in + _rv_hold:
		_rv_w = 1.0
	elif _rv_t < _rv_in + _rv_hold + _rv_out:
		_rv_w = 1.0 - ease((_rv_t - _rv_in - _rv_hold) / _rv_out, -2.0)
	else:
		cancel_reveal()
		return
	_zoom = lerpf(1.0, _rv_zoom, _rv_w)

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
