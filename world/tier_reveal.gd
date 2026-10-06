class_name TierReveal
extends Node
## E5 spec 7.5 (D-243): the morning after a won boss night. Visual only: the state is saved and the world rebuilt before
## the first step (the tier-up emits tier_changed, which World rebuilds on, before tier_reached); a restore
## kills everything. Steps tier_reveal_step_s apart, each with the build sound and a dust puff: the first yard's dust, its
## stones, the diner pops, the other yards' dust, the yard spot markers pop. The camera pulls back meanwhile.

var _world: World
var _tween: Tween
var _pops: Array[Tween] = []
var _steps: Array = []  ## [{at: Vector3, kind: StringName}] not yet run
var _hidden_spots: Array[BuildSpot] = []
var _diner_art: Node3D
var _diner_base := Vector3.ONE

func setup(world: World) -> void:
	_world = world
	name = "TierReveal"
	EventBus.tier_reached.connect(_on_tier_reached)
	EventBus.state_restored.connect(_cancel)

## The points the reveal camera must show: the diner's footprint corners and the corners of every yard `tier` opened.
static func subject_points(tier: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var h := MapLayout.DINER_HALF
	for c in [Vector2(-h, -h), Vector2(h, -h), Vector2(-h, h), Vector2(h, h)]:
		out.append(MapLayout.to3(c))
	for id in MapLayout.YARDS:
		if int(MapLayout.YARD_TIER[id]) != tier:
			continue
		var r: Rect2 = MapLayout.YARDS[id]
		for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			out.append(MapLayout.to3(c))
	return out

## Pure: the reveal camera for `tier`: the focus is the centre of the subject points' bounding rectangle, the zoom the
## smallest in [1.0, ui.tier_reveal_zoom] (steps of 0.05) that shows every point at `aspect`; the cap when none does.
static func frame_for(tier: int, ui: UiTuning, aspect := CameraMath.ASPECT) -> Dictionary:
	var pts := subject_points(tier)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	var focus := (lo + hi) * 0.5
	var proj := CameraMath.projection(ui, aspect)
	var cap := ui.tier_reveal_zoom
	var z := 1.0
	while z < cap - 1e-6:
		var xf := CameraMath.zoomed_transform(focus, ui, z)
		var ok := true
		for p in pts:
			if not CameraMath.on_screen(p, xf, proj):
				ok = false
				break
		if ok:
			return {"focus": focus, "zoom": z}
		z += 0.05
	return {"focus": focus, "zoom": cap}

func running() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()

func steps_left() -> int:
	return _steps.size()

## Kills the tweens and puts back everything the reveal hid or scaled.
func _cancel() -> void:
	PopFx.kill(_tween)
	_tween = null
	for t in _pops:
		PopFx.kill(t)
	_pops.clear()
	_steps = []
	_restore()

func _restore() -> void:
	if _world == null:
		return
	if _world.yard_stones != null and is_instance_valid(_world.yard_stones):
		_world.yard_stones.visible = true
	if _diner_art != null and is_instance_valid(_diner_art):
		_diner_art.scale = _diner_base
	_diner_art = null
	for s in _hidden_spots:
		if is_instance_valid(s):
			s.marker.scale = Vector3.ONE
			s.refresh()
	_hidden_spots.clear()

func _on_tier_reached(tier: int) -> void:
	_cancel()
	# World connects its tier signals after this node, so this handler runs before World's _on_tier_reached; the world is
	# already rebuilt because the tier-up emits tier_changed first and World rebuilds on it. This call is a guarded no-op
	# (rebuild_for_tier returns at once when the built tier equals the tier) that keeps the order from mattering.
	_world.rebuild_for_tier()
	EventBus.banner_requested.emit(tr("The diner grows!"))
	var yards: Array[String] = []
	for id in MapLayout.YARDS:
		if int(MapLayout.YARD_TIER[id]) == tier:
			yards.append(id)
	_diner_art = null
	var diner_visual := _world.diner_body.get_node_or_null("Visual") if _world.diner_body != null else null
	if diner_visual != null:
		_diner_art = diner_visual.get_node_or_null("DinerArt") as Node3D
	if _diner_art != null:
		_diner_base = _diner_art.scale
	_steps = []
	for i in yards.size():
		var centre: Vector2 = (MapLayout.YARDS[yards[i]] as Rect2).get_center()
		_steps.append({"kind": &"dust", "at": MapLayout.to3(centre)})
		if i == 0:
			_steps.append({"kind": &"stones", "at": MapLayout.to3(centre, 0.3)})
			_steps.append({"kind": &"diner", "at": Vector3(0.0, MapLayout.DINER_HEIGHT + 0.5, 0.0)})
	if yards.is_empty():
		_steps.append({"kind": &"diner", "at": Vector3(0.0, MapLayout.DINER_HEIGHT + 0.5, 0.0)})
	var spot_ids: Array = MapLayout.TIER_SPOTS.get(tier, [])
	if not spot_ids.is_empty():
		_steps.append({"kind": &"markers", "at": MapLayout.to3(MapLayout.spot_position(spot_ids[0]), 1.0)})
	# hide what the steps bring in
	if _world.yard_stones != null and not yards.is_empty():
		_world.yard_stones.visible = false
	for id in spot_ids:
		var s: BuildSpot = _world.build_spots.get(id)
		if s != null:
			s.marker.visible = false
			_hidden_spots.append(s)
	var ui := Balance.ui
	var hold := minf(float(_steps.size()) * ui.tier_reveal_step_s, Balance.data.tiers.tier_reveal_time - ui.tier_reveal_in_s - ui.tier_reveal_out_s)
	var frame := frame_for(tier, ui)
	EventBus.camera_reveal_requested.emit(ui.tier_reveal_in_s, maxf(hold, 0.0), ui.tier_reveal_out_s, frame.zoom, frame.focus)
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# The steps play inside the camera's hold: the first when the camera has reached its frame (in_s), then step_s apart.
	# The reveal ends at tier_reveal_time (the card pick opens then), at least build_pop_time after the last step.
	var last_at := ui.tier_reveal_in_s + float(_steps.size() - 1) * ui.tier_reveal_step_s
	_tween.tween_interval(ui.tier_reveal_in_s)
	for i in _steps.size():
		_tween.tween_callback(_step)
		if i < _steps.size() - 1:
			_tween.tween_interval(ui.tier_reveal_step_s)
	_tween.tween_interval(maxf(Balance.data.tiers.tier_reveal_time - last_at, ui.build_pop_time))
	_tween.tween_callback(_finish)

func _step() -> void:
	if _steps.is_empty():
		return
	var st: Dictionary = _steps.pop_front()
	EventBus.sfx_requested.emit(&"build_done")
	if st.has("at"):
		EventBus.fx_requested.emit(&"dust", st.at)
	match st.kind:
		&"stones":
			# yard_stones is ONE MultiMesh for every open yard: a later tier that opens more yards must split it per tier
			# before this step is reused.
			if _world.yard_stones != null and is_instance_valid(_world.yard_stones):
				_world.yard_stones.visible = true
		&"diner":
			if _diner_art != null and is_instance_valid(_diner_art):
				_pops.append(PopFx.pop(self, _diner_art, _diner_base, null))
		&"markers":
			for s in _hidden_spots:
				if is_instance_valid(s):
					s.marker.visible = true
					_pops.append(PopFx.pop(self, s.marker, Vector3.ONE, null))

## After the last step and its pop: the reveal ends. The markers stayed shown from step 5 until now; refresh() puts every
## spot back to what the phase says: at DAWN the zone is inactive, so it hides the markers until day.
func _finish() -> void:
	_restore()
