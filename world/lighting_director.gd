class_name LightingDirector
extends Node
## Day and night lighting (S4 Task 13, D-194): a warm day and a readable blue night. On `phase_changed` it tweens the
## sun's colour and energy, the ambient colour and the background over `lighting_tween_s`. DAWN equals DAY (the card
## pick is a DAWN sub-state). The first phase_changed after setup snaps (no tween): a new game or a resume starts in
## its phase's light. Visual only: it never touches gameplay state. Values live in `Balance.ui`.

var _light: DirectionalLight3D
var _env: Environment
var _tween: Tween
var _first := true

func setup(light: DirectionalLight3D, env: Environment) -> void:
	_light = light
	_env = env
	_apply(target_for(Phase.DAY))
	if not EventBus.phase_changed.is_connected(_on_phase_changed):
		EventBus.phase_changed.connect(_on_phase_changed)

func target_for(phase: int) -> Dictionary:
	var ui := Balance.ui
	if phase == Phase.NIGHT:
		return {"sun_color": ui.night_sun_color, "sun_energy": ui.night_sun_energy, "ambient": ui.night_ambient, "bg": ui.night_bg}
	return {"sun_color": ui.day_sun_color, "sun_energy": ui.day_sun_energy, "ambient": ui.day_ambient, "bg": ui.day_bg}

func _apply(t: Dictionary) -> void:
	_light.light_color = t.sun_color
	_light.light_energy = t.sun_energy
	_env.ambient_light_color = t.ambient
	_env.background_color = t.bg

func _on_phase_changed(phase: int, _day: int) -> void:
	if _light == null or not is_inside_tree():
		return
	var t := target_for(phase)
	if _first:
		_first = false
		_apply(t)
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	var s := Balance.ui.lighting_tween_s
	_tween.tween_property(_light, "light_color", t.sun_color, s)
	_tween.tween_property(_light, "light_energy", t.sun_energy, s)
	_tween.tween_property(_env, "ambient_light_color", t.ambient, s)
	_tween.tween_property(_env, "background_color", t.bg, s)
