class_name Guide
extends Node
## The onboarding Guide (S5 spec 6, D-213): one pointer. Four times a second it builds a plain snapshot of the game, asks
## GuideRules for the first rule that applies, and shows it as a label plus either a bouncing world pointer above the target
## or, when the target is off-screen, an edge arrow on the HUD's arrow rect (inset a further guide_rect_inset_px). `move`
## shows a ghost joystick swiping at the lower third instead. It only reads the game: it never writes GameState, never calls
## Rng, and has no physics body. Every Control ignores the mouse.
## Main builds it through `_maybe_build_guide()`; tests and sims build it with `setup(main)`.

signal evaluated
signal completed

const LAYER := 12
const POINTER_SCENE := preload("res://art/fx/pointer.tscn")
const LABEL_GAP := 24.0
const FINGER_PX := 18.0
const FINGER_ALPHA := 0.55

var rule_id: StringName = &""
var target_id: StringName = &""
var target_position := Vector3.ZERO
## Metres the hero has walked since the last start or restore, summed from `hero.velocity` (a teleport adds nothing).
var walked := 0.0

var main: Main
var layer: CanvasLayer
var overlay: Control
var label: Label
var canvas: GuideCanvas
var pointer: Node3D
var _eval_left := 0.0
var _t := 0.0
var _forced := false
var _arrow_visible := false
var _arrow_pos := Vector2.ZERO
var _arrow_rot := 0.0
var _stick_visible := false
var _stick_center := Vector2.ZERO
## The Boar the `fight` rule picked at the last evaluation; the pointer follows it every frame while it lives.
var _target_boar: Node3D
var _stick_phase := 0.0
## False until a run exists: Main builds the Guide in _ready, before start_new_game or resume.
var _live := false

func setup(p_main: Main) -> void:
	main = p_main
	_live = not GameState.buildings.is_empty()
	layer = CanvasLayer.new()
	layer.name = "GuideLayer"
	layer.layer = LAYER
	add_child(layer)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)
	canvas = GuideCanvas.new()
	canvas.guide = self
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(canvas)
	label = Label.new()
	label.theme_type_variation = &"HudCounter"
	label.add_theme_font_size_override("font_size", int(Balance.ui.guide_font_px))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	overlay.add_child(label)
	pointer = POINTER_SCENE.instantiate()
	pointer.visible = false
	add_child(pointer)
	EventBus.state_restored.connect(_on_state_restored)
	EventBus.phase_changed.connect(_on_phase_changed)
	main.get_viewport().size_changed.connect(_relayout)

func _exit_tree() -> void:
	if EventBus.state_restored.is_connected(_on_state_restored):
		EventBus.state_restored.disconnect(_on_state_restored)
	if EventBus.phase_changed.is_connected(_on_phase_changed):
		EventBus.phase_changed.disconnect(_on_phase_changed)

func _on_state_restored() -> void:
	_live = true
	walked = 0.0

func _on_phase_changed(phase: int, day: int) -> void:
	if phase == Phase.NIGHT and day == 1:
		walked = 0.0
	elif phase == Phase.NIGHT and day >= 2:
		# D-213: the first night after the tutorial day (or any night of day 2 or later) finishes the onboarding for this device.
		if main != null and main.settings_store != null:
			main.settings_store.guide_done = true
			main.settings_store.save_settings()
		completed.emit()
		queue_free()

func _physics_process(delta: float) -> void:
	if main == null or not _live:
		return  # Main builds the Guide before the run starts (boot path): nothing to read until a run exists
	var v := main.hero.velocity
	walked += Vector2(v.x, v.z).length() * delta
	_eval_left -= delta
	if _eval_left <= 0.0:
		_eval_left = Balance.ui.guide_eval_s
		evaluate_now()

func snapshot() -> Dictionary:
	var gs := GameState
	var boars: Array = []
	for b in main.world.wave_director.alive_enemies():
		var p: Vector3 = b.global_position
		boars.append({"xz": Vector2(p.x, p.z), "remaining": b.path_length() - b.dist, "spawn_index": b.spawn_index, "pos": p})
	var steaks: Array = []
	for st in main.world.steak_pool.active():
		steaks.append((st as Node3D).global_position)
	var spots: Array = []
	for id in MapLayout.SPOT_IDS:
		spots.append({"id": id, "remaining": gs.remaining_cost(id), "next_cost": gs.next_level_cost(id), "pos": MapLayout.to3(MapLayout.spot_position(id))})
	return {
		"phase": main.phase_controller.phase, "day": gs.day, "hero_xz": main.hero.xz(), "walked": walked,
		"attack_range": Balance.data.hero.attack_range, "boars": boars, "steaks": steaks, "carried": gs.carried_steaks,
		"carry_capacity": gs.carry_capacity(), "freezer": gs.freezer_steaks, "counter": gs.counter_steaks,
		"counter_capacity": gs.counter_capacity(), "gold": gs.gold, "gold_pile": gs.gold_pile,
		"move_m": Balance.ui.guide_move_m, "spots": spots, "should_pulse": Pulse.should_pulse(gs.to_dict(), Balance.data),
	}

func evaluate_now() -> void:
	if not _forced:
		var r := GuideRules.evaluate(snapshot())
		if main.phase_controller.failing:
			r = {"rule_id": &"", "target_id": &"", "target_position": Vector3.ZERO}  # a bot following the Guide stops during the fail banner
		rule_id = r.rule_id
		target_id = r.target_id
		target_position = r.target_position
		_target_boar = null
		if rule_id == &"fight":
			for b in main.world.wave_director.alive_enemies():
				if (b as Node3D).global_position == target_position:
					_target_boar = b
					break
	_apply()
	evaluated.emit()

## Debug capture only (`--guide=<id>`): shows that rule's text and pointer at a fixed target and stops evaluating.
func debug_force(id: StringName) -> void:
	_forced = true
	rule_id = id
	target_id = &""
	var hero := main.hero.xz() if main != null else MapLayout.NIGHT1_START
	match id:
		&"fight":
			target_id = &"boar"
			target_position = MapLayout.to3(hero + Vector2(1.5, -7.0))
		&"grab":
			target_id = &"steak"
			target_position = MapLayout.to3(hero + Vector2(1.0, -2.5))
		&"build":
			target_id = &"tower_nw"
			target_position = MapLayout.to3(MapLayout.spot_position("tower_nw"))
		&"collect":
			target_id = &"gold_pile"
			target_position = MapLayout.to3(MapLayout.GOLD_PILE)
		&"take":
			target_id = &"freezer"
			target_position = MapLayout.to3(MapLayout.FREEZER_ZONE)
		&"stock":
			target_id = &"counter"
			target_position = MapLayout.to3(MapLayout.COUNTER_DROP)
		&"close":
			target_id = &"sign"
			target_position = MapLayout.to3(MapLayout.SIGN)
		_:
			target_position = Vector3.ZERO
	_apply()

func _apply() -> void:
	var shown := rule_id != &""
	label.visible = shown
	if shown:
		label.text = tr(GuideRules.TEXT[rule_id])
		label.reset_size()
	_relayout()

func _process(delta: float) -> void:
	if main == null:
		return
	_t += delta
	_stick_phase = fmod(_stick_phase + delta / maxf(Balance.ui.guide_swipe_s, 0.01), 1.0)
	_relayout()

## The rect the Guide's arrow and label live in: the HUD's arrow rect, inset a further guide_rect_inset_px.
func edge_rect() -> Rect2:
	return main.hud.arrow_rect().grow(-Balance.ui.guide_rect_inset_px)

func _screen_point(world: Vector3, rect: Rect2) -> Vector2:
	var cam := main.get_viewport().get_camera_3d()
	var p := cam.unproject_position(world)
	if cam.is_position_behind(world):
		p = rect.get_center() - (p - rect.get_center())
	return p

func _relayout() -> void:
	if main == null or overlay == null:
		return
	_arrow_visible = false
	_stick_visible = false
	pointer.visible = false
	# Nothing shows while the night is failing (the restore is about to move everything), nor when no rule applies.
	var shown := rule_id != &"" and (_forced or not main.phase_controller.failing)
	label.visible = shown
	if not shown:
		canvas.queue_redraw()
		return
	# Visual only: the fight pointer follows its Boar every frame instead of jumping at each evaluation.
	if rule_id == &"fight" and is_instance_valid(_target_boar) and _target_boar in main.world.wave_director.alive_enemies():
		target_position = _target_boar.global_position
	var rect := edge_rect()
	var anchor := Vector2.ZERO  # where the label hangs from
	if rule_id == &"move":
		_stick_visible = true
		_stick_center = Vector2(rect.get_center().x, rect.position.y + rect.size.y * Balance.ui.guide_stick_y)
		anchor = _stick_center + Vector2(0.0, -Balance.ui.joystick_radius_px - LABEL_GAP)
	else:
		var ground := _screen_point(target_position, rect)
		var top := _screen_point(target_position + Vector3(0.0, Balance.ui.guide_pointer_h + PointerMesh.HEIGHT, 0.0), rect)
		# The world pointer needs both the target and the top of the pointer inside the rect; a target whose pointer would poke
		# out of the top falls back to the edge arrow, placed on the target itself.
		if rect.has_point(ground) and rect.has_point(top):
			var bounce := sin(_t * TAU * Balance.ui.guide_bounce_hz) * Balance.ui.guide_bounce_m
			pointer.global_position = target_position + Vector3(0.0, Balance.ui.guide_pointer_h + bounce, 0.0)
			# Face the camera: the arrow's axis lies in the view plane, so from the high camera it reads as an arrow
			# rather than a cone seen end-on.
			pointer.global_basis = main.get_viewport().get_camera_3d().global_basis
			pointer.visible = true
			anchor = top + Vector2(0.0, -LABEL_GAP)
		else:
			var e := EdgeClamp.clamp_to_rect(ground, rect)
			_arrow_visible = true
			_arrow_pos = e.position
			_arrow_rot = e.rotation
			# The label sits on the arrow's inner side (towards the rect centre).
			var inward := (rect.get_center() - _arrow_pos).normalized()
			anchor = _arrow_pos + inward * (Balance.ui.guide_arrow_px * 0.5 + 2.0 + LABEL_GAP * 2.0)
	label.reset_size()
	var half := label.size * 0.5
	var pos := anchor - Vector2(half.x, label.size.y)
	pos.x = clampf(pos.x, rect.position.x, maxf(rect.end.x - label.size.x, rect.position.x))
	pos.y = clampf(pos.y, rect.position.y, maxf(rect.end.y - label.size.y, rect.position.y))
	label.position = pos - overlay.global_position
	canvas.queue_redraw()

## The ghost stick's knob offset: a horizontal swipe from left to right over guide_swipe_s, then a restart.
func knob_offset() -> Vector2:
	var r := Balance.ui.joystick_radius_px
	return Vector2(lerpf(-r * Balance.ui.guide_swipe_frac, r * Balance.ui.guide_swipe_frac, ease(_stick_phase, -1.6)), 0.0)

func label_rect() -> Rect2:
	return label.get_global_rect()

func arrow_visible() -> bool:
	return _arrow_visible

func arrow_position() -> Vector2:
	return _arrow_pos

func arrow_rotation() -> float:
	return _arrow_rot

func stick_center() -> Vector2:
	return _stick_center

func stick_visible() -> bool:
	return _stick_visible

## One custom-draw Control for the edge arrow and the ghost stick: atlas cells only (D-201), so it batches.
class GuideCanvas extends Control:
	var guide: Guide

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _draw() -> void:
		if guide == null:
			return
		var atlas := IconAtlas.texture()
		var origin := -global_position
		if guide.arrow_visible():
			var px := Balance.ui.guide_arrow_px
			draw_set_transform(guide.arrow_position() + origin, guide.arrow_rotation(), Vector2.ONE)
			draw_texture_rect_region(atlas, IconAtlas.shape_dest(Rect2(HudIcons.ARROW_CENTER - Vector2.ONE * px * 0.5, Vector2.ONE * px)), IconAtlas.region(&"guide_arrow"), Palette.color(&"gold"))
			draw_set_transform_matrix(Transform2D.IDENTITY)
		if guide.stick_visible():
			var c := guide.stick_center() + origin
			var r := Balance.ui.joystick_radius_px
			draw_texture_rect_region(atlas, IconAtlas.shape_dest(Rect2(c - Vector2.ONE * r, Vector2.ONE * r * 2.0)), IconAtlas.region(&"stick_ring"))
			var k := c + guide.knob_offset()
			var kr := r * 0.45
			draw_texture_rect_region(atlas, IconAtlas.shape_dest(Rect2(k - Vector2.ONE * kr, Vector2.ONE * kr * 2.0)), IconAtlas.region(&"stick_knob"))
			var fr := FINGER_PX
			draw_texture_rect_region(atlas, IconAtlas.shape_dest(Rect2(k - Vector2.ONE * fr, Vector2.ONE * fr * 2.0)), IconAtlas.region(&"disc"), Color(1, 1, 1, FINGER_ALPHA))
