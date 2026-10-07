class_name TierReveal
extends Node
## E5 spec 7.5 (D-243): the morning after a won boss night. Visual only: the state is saved and the world rebuilt before
## the first step (the tier-up emits tier_changed, which World rebuilds on, before tier_reached); a restore
## kills everything. Steps tier_reveal_step_s apart, each with the build sound and a dust puff: the first yard's dust, its
## stones, the diner pops, the other yards' dust, the yard spot markers pop. The steps start once the camera has arrived.
## Tier 3 (E5 tier 3 Task 20, spec 7) has its own list: the front lot's paving and kerb, the south-west lane strip with its edge stones and
## flag, the fence spot, the tower spot, the diner's second storey, the branch pads. A tap fast-forwards a reveal (D-273.2): the controller
## opens the card pick and this node, hearing it on the bus, applies what is left and sends the camera back to the hero.

var _world: World
var _tween: Tween
var _pops: Array[Tween] = []
var _steps: Array = []  ## [{at: Vector3, kind: StringName}] not yet run
var _hidden_spots: Array[BuildSpot] = []
var _diner_art: Node3D
var _diner_base := Vector3.ONE
var _interval := 0.35  ## seconds between two steps of the running reveal
## Tier 3: what the running reveal has hidden or swapped, to put back (see _restore).
var _staged := false  ## the ground, kerb and edge stones show the tier before
var _diner_old := false  ## the diner shows the previous tier's art
var _hidden_markers: Array[TelegraphMarker] = []
var _hidden_pads: Array[BranchPad] = []

func setup(world: World) -> void:
	_world = world
	name = "TierReveal"
	EventBus.tier_reached.connect(_on_tier_reached)
	EventBus.state_restored.connect(_cancel)
	EventBus.card_offered.connect(_on_pick_opened)
	EventBus.phase_changed.connect(_on_phase_changed)

## The points the reveal camera must show: the diner's footprint corners and the corners of every yard `tier` opened.
static func subject_points(tier: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var h := MapLayout.DINER_HALF
	for c in [Vector2(-h, -h), Vector2(h, -h), Vector2(-h, h), Vector2(h, h)]:
		out.append(MapLayout.to3(c))
	for id in MapLayout.yards_for_tier(tier):
		if MapLayout.yard_tier(id) != tier:
			continue
		var r: Rect2 = MapLayout.yard_rect(id)
		for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			out.append(MapLayout.to3(c))
	if tier == 3:
		for p in lane_stretch_points(Balance.ui.tier_reveal_lane_stretch_m):
			out.append(MapLayout.to3(p))
	return out

## The south-west lane's last `stretch` metres (xz): the point that far back from its end, every path vertex nearer the end than that, and
## the end itself.
static func lane_stretch_points(stretch: float) -> Array[Vector2]:
	var path: Array = MapLayout.lane_path("sw")
	var out: Array[Vector2] = [Geometry.point_back_from_end(path, stretch)]
	var total := Geometry.path_length(path)
	for i in range(1, path.size() - 1):
		var d := total - Geometry.path_length(path.slice(0, i + 1))
		if d < stretch:
			out.append(path[i])
	out.append(path[path.size() - 1])
	return out

## Seconds between the steps of a reveal of `n` steps: tier_reveal_step_s while the last step's pop fits the camera's hold, else the
## spacing that makes it fit, never below the build sound's own minimum gap (a closer step would play silent): the reveal's length
## never changes (it ends at tier_reveal_time).
static func step_interval(n: int, ui: UiTuning, total: float) -> float:
	var step := ui.tier_reveal_step_s
	if n <= 1:
		return step
	var hold := total - ui.tier_reveal_in_s - ui.tier_reveal_out_s
	if (n - 1) * step + ui.build_pop_time <= hold + 1e-6:
		return step
	var floor_s: float = AudioManifest.SFX[&"build_done"].min_gap_s + ui.tier_reveal_gap_margin_s
	return maxf((hold - ui.build_pop_time) / float(n - 1), floor_s)

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
	var lim := ui.tier_reveal_fit_t3 if tier == 3 else 1.0  # tier 2 fits to the very edge (pinned); tier 3 keeps some air
	var z := 1.0
	while z < cap - 1e-6:
		var xf := CameraMath.zoomed_transform(focus, ui, z)
		var ok := true
		for p in pts:
			var n := CameraMath.to_ndc(p, xf, proj)
			if absf(n.x) > lim or absf(n.y) > lim:
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
	if _staged:
		_staged = false
		_world.show_map_full()
	if _diner_old:
		_diner_old = false
		_world.show_diner_for()
	for m in _hidden_markers:
		if is_instance_valid(m):
			m.refresh()
	_hidden_markers.clear()
	for p in _hidden_pads:
		if is_instance_valid(p):
			p.body.scale = Vector3.ONE
			p.refresh()
	_hidden_pads.clear()

func _on_tier_reached(tier: int) -> void:
	_cancel()
	# World connects its tier signals after this node, so this handler runs before World's _on_tier_reached; the world is
	# already rebuilt because the tier-up emits tier_changed first and World rebuilds on it. This call is a guarded no-op
	# (rebuild_for_tier returns at once when the built tier equals the tier) that keeps the order from mattering.
	_world.rebuild_for_tier()
	EventBus.banner_requested.emit(tr("The diner grows!"))
	var yards: Array[String] = []
	for id in MapLayout.yards_for_tier(tier):
		if MapLayout.yard_tier(id) == tier:
			yards.append(id)
	_diner_art = null
	_steps = []
	if tier == 3:
		_plan_tier3()
	else:
		_plan_default(tier, yards)
	var ui := Balance.ui
	_interval = TierReveal.step_interval(_steps.size(), ui, Balance.data.tiers.tier_reveal_time)
	var hold := minf(float(_steps.size()) * ui.tier_reveal_step_s, Balance.data.tiers.tier_reveal_time - ui.tier_reveal_in_s - ui.tier_reveal_out_s)
	var frame := frame_for(tier, ui)
	EventBus.camera_reveal_requested.emit(ui.tier_reveal_in_s, maxf(hold, 0.0), ui.tier_reveal_out_s, frame.zoom, frame.focus)
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# The steps play inside the camera's hold: the first when the camera has reached its frame (in_s), then _interval apart.
	# The reveal ends at tier_reveal_time (the card pick opens then), at least build_pop_time after the last step.
	var last_at := ui.tier_reveal_in_s + float(_steps.size() - 1) * _interval
	_tween.tween_interval(ui.tier_reveal_in_s)
	for i in _steps.size():
		_tween.tween_callback(_step)
		if i < _steps.size() - 1:
			_tween.tween_interval(_interval)
	_tween.tween_interval(maxf(Balance.data.tiers.tier_reveal_time - last_at, ui.build_pop_time))
	_tween.tween_callback(_finish)

## The steps of the tier-2 reveal (and of any tier without a list of its own): what the tier opened pops in, the yards' dust first.
func _plan_default(tier: int, yards: Array[String]) -> void:
	var diner_visual := _world.diner_body.get_node_or_null("Visual") if _world.diner_body != null else null
	if diner_visual != null:
		_diner_art = diner_visual.get_node_or_null("DinerArt") as Node3D
	if _diner_art != null:
		_diner_base = _diner_art.scale
	for i in yards.size():
		var centre: Vector2 = MapLayout.yard_rect(yards[i]).get_center()
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

## The tier-3 list (spec 7): the lot, the lane, the fence spot, the tower spot, the second storey, the branch pads that show now. Each
## step's things are hidden until it runs: the ground and kerb show the tier-2 yards and lanes only, the lane's flag and the two spots'
## markers are hidden, the diner shows its tier-2 art, the visible pads are hidden.
func _plan_tier3() -> void:
	var stretch := TierReveal.lane_stretch_points(Balance.ui.tier_reveal_lane_stretch_m)
	var lane_mid: Vector2 = stretch[0].lerp(stretch[stretch.size() - 1], 0.5)
	_steps.append({"kind": &"lot", "at": MapLayout.to3(MapLayout.yard_rect("front").get_center())})
	_steps.append({"kind": &"lane", "at": MapLayout.to3(lane_mid)})
	_steps.append({"kind": &"spot", "id": "fence_sw", "at": MapLayout.to3(MapLayout.spot_position("fence_sw"), 1.0)})
	_steps.append({"kind": &"spot", "id": "tower_sw", "at": MapLayout.to3(MapLayout.spot_position("tower_sw"), 1.0)})
	_steps.append({"kind": &"diner", "at": Vector3(0.0, MapLayout.DINER_HEIGHT + 0.5, 0.0)})
	var pads := _shown_pads()
	if not pads.is_empty():
		_steps.append({"kind": &"pads", "at": pads[0].global_position + Vector3(0.0, 1.0, 0.0)})
	_world.show_map_stage(MapLayout.yards_for_tier(2), MapLayout.lanes_for_tier(2))
	_staged = true
	_world.show_diner_for(2)
	_diner_old = true
	var marker: TelegraphMarker = _world.telegraph_markers.get("sw")
	if marker != null:
		marker.visible = false
		_hidden_markers.append(marker)
	for id in ["fence_sw", "tower_sw"]:
		var s: BuildSpot = _world.build_spots.get(id)
		if s != null:
			s.marker.visible = false
			_hidden_spots.append(s)
	for p in pads:
		p.body.visible = false
		_hidden_pads.append(p)

## The branch pads on the map right now (at a DAY world with a branchable building; at the dawn none shows, the zones being inactive).
func _shown_pads() -> Array[BranchPad]:
	var out: Array[BranchPad] = []
	for id in MapLayout.spots_for_tier(3):
		for p in _world.branch_pads.get(id, []):
			if (p as BranchPad).body.visible:
				out.append(p)
	return out

func _step() -> void:
	if _steps.is_empty():
		return
	var st: Dictionary = _steps.pop_front()
	EventBus.sfx_requested.emit(&"build_done")
	if st.has("at"):
		EventBus.fx_requested.emit(&"dust", st.at)
	_apply(st, true)

## What one step brings in. `animate`: the pops of a reveal that plays; a skip applies the same end state without them.
func _apply(st: Dictionary, animate: bool) -> void:
	match st.kind:
		&"stones":
			# On the tier-2 list the kerb is ONE MultiMesh for every open yard; the tier-3 list stages its multimesh instead (show_map_stage).
			if _world.yard_stones != null and is_instance_valid(_world.yard_stones):
				_world.yard_stones.visible = true
		&"diner":
			if _diner_old:
				_diner_old = false
				_world.show_diner_for()  # the new storey
				var visual := _world.diner_body.get_node_or_null("Visual")
				_diner_art = visual.get_node_or_null("DinerArt") as Node3D if visual != null else null
				_diner_base = _diner_art.scale if _diner_art != null else Vector3.ONE
			if animate and _diner_art != null and is_instance_valid(_diner_art):
				_pops.append(PopFx.pop(self, _diner_art, _diner_base, null))
		&"markers":
			for s in _hidden_spots:
				if is_instance_valid(s):
					s.marker.visible = true
					if animate:
						_pops.append(PopFx.pop(self, s.marker, Vector3.ONE, null))
		&"lot":
			if _staged:
				_world.show_map_stage(MapLayout.yards_for_tier(3), MapLayout.lanes_for_tier(2))  # the paving, props and kerb of the lot
		&"lane":
			if _staged:
				_staged = false
				_world.show_map_full()  # the strip, its edge stones
			for m in _hidden_markers:
				if is_instance_valid(m):
					m.visible = true
					var base := Vector3.ONE * maxf(m.target_scale, Balance.ui.telegraph_scale_min)
					m.scale = base
					if animate:
						_pops.append(PopFx.pop(self, m, base, null))
		&"spot":
			var s: BuildSpot = _world.build_spots.get(st.id)
			if s != null and is_instance_valid(s):
				s.marker.visible = true
				if animate:
					_pops.append(PopFx.pop(self, s.marker, Vector3.ONE, null))
		&"pads":
			for p in _hidden_pads:
				if is_instance_valid(p):
					p.body.visible = true
					if animate:
						_pops.append(PopFx.pop(self, p.body, Vector3.ONE, null))

## After the last step and its pop: the reveal ends. The markers stayed shown from step 5 until now; refresh() puts every
## spot back to what the phase says: at DAWN the zone is inactive, so it hides the markers until day.
func _finish() -> void:
	_restore()

## D-273.2: the card pick (or the day, with no offer) opened while the reveal runs: a tap asked for it. Every step left is applied at
## once (no sound, no dust, no pops), the reveal ends as it would have, and the camera eases back to the hero.
func _on_pick_opened(_offer: Array) -> void:
	skip()

func _on_phase_changed(p: int, _day: int) -> void:
	if p == Phase.DAY:
		skip()

## Fast-forwards a running reveal to its end state. No-op when none runs.
func skip() -> void:
	if not running():
		return
	PopFx.kill(_tween)
	_tween = null
	for t in _pops:
		PopFx.kill(t)
	_pops.clear()
	while not _steps.is_empty():
		_apply(_steps.pop_front(), false)
	_restore()
	EventBus.camera_reveal_requested.emit(0.0, 0.0, Balance.ui.tier_reveal_skip_ease_s, 1.0, Vector2.INF)
