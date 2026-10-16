class_name TierReveal
extends Node
## E5 spec 7.5 (D-243): the morning after a won boss night. Visual only: the state is saved and the world rebuilt before
## the first step (the tier-up emits tier_changed, which World rebuilds on, before tier_reached); a restore
## kills everything. Steps tier_reveal_step_s apart, each with the build sound and a dust puff: the first yard's dust, its
## stones, the diner pops, the other yards' dust, the yard spot markers pop. The steps start once the camera has arrived.
## Tier 3 (E5 tier 3 Task 20, spec 7) has its own list: the front lot's paving and kerb, the south-west lane strip with its edge stones and
## flag, the fence spot, the tower spot, the diner's second storey (five steps; the branch pads appear with the first tier-3 day, the
## tier-up being a dawn). A tap fast-forwards a reveal (D-273.2): the controller
## opens the card pick and this node, hearing it on the bus, applies what is left and sends the camera back to the hero.

var _world: World
var _tween: Tween
var _pops: Array[Tween] = []
var _steps: Array = []  ## [{at: Vector3, kind: StringName}] not yet run
var _hidden_spots: Array[BuildSpot] = []
var _diner_art: Node3D
var _diner_base := Vector3.ONE
## Tier 3: what the running reveal has hidden or swapped, to put back (see _restore).
var _staged := false  ## the ground, kerb and edge stones show the tier before
var _diner_old := false  ## the diner shows the previous tier's art
var _hidden_markers: Array[TelegraphMarker] = []
## E6 (D-289, spec 5.4): the lane-character step. The markers whose badge the reveal holds (and each badge's scale). The step only pops the
## badges: the two flavour lines are scheduled by the controller after the card pick (D-294.5). Empty with no lane character: no step.
var _badge_markers: Array[TelegraphMarker] = []
var _badge_base := {}
var _diner_kept: Node3D  ## tier 3: the new storey's art, taken out of the diner for the first steps and put back at step 5 (no second instantiation)

## Tier 4: the height (m) above a tower spot that the reveal frame must show (the tower's top).
const TOWER_TOP_M := 3.0

func setup(world: World) -> void:
	_world = world
	name = "TierReveal"
	EventBus.tier_reached.connect(_on_tier_reached)
	EventBus.state_restored.connect(_cancel)
	EventBus.card_offered.connect(_on_pick_opened)
	EventBus.phase_changed.connect(_on_phase_changed)

## Tier 4 (E8 spec 4.5): the yards the ground shows between the two lots' steps: the older tiers' yards and the first of the tier's own.
## The reveal stages it and the warm-up builds its terrain mesh, so both read this one list.
static func stage_yards(tier: int) -> Array:
	var out: Array = MapLayout.yards_for_tier(tier - 1).duplicate()
	for id in MapLayout.yards_for_tier(tier):
		if MapLayout.yard_tier(id) == tier:
			out.append(id)
			break
	return out

## The points the reveal camera must show: the diner's footprint corners and the corners of every yard `tier` opened.
static func subject_points(tier: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var h := MapLayout.DINER_HALF
	if tier == 4:
		return _subject_points_t4()
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

## E8 (spec 4.5): tier 4 changes no diner, so the frame holds the back lot alone: the corners of its yards and both towers (the tower mesh's
## footprint, TOWER_VISUAL_RADIUS, in the four directions and its height above the spot). The two lots are 14.6 m apart in x.
static func _subject_points_t4() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for id in MapLayout.yards_for_tier(4):
		if MapLayout.yard_tier(id) != 4:
			continue
		var r: Rect2 = MapLayout.yard_rect(id)
		for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			out.append(MapLayout.to3(c))
	var rad := MapLayout.TOWER_VISUAL_RADIUS
	for id in MapLayout.TIER_SPOTS[4]:
		var c := MapLayout.spot_position(id)
		for d in [Vector2(rad, 0), Vector2(-rad, 0), Vector2(0, rad), Vector2(0, -rad)]:
			out.append(MapLayout.to3(c + d))
		out.append(MapLayout.to3(c, TOWER_TOP_M))
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

## Pure: the reveal camera for `tier`: the focus is the centre of the subject points' bounding rectangle, the zoom the
## smallest in [1.0, ui.tier_reveal_zoom] (steps of 0.05) that shows every point at `aspect`; the cap when none does.
## `extra` (E6, spec 5.4): more points the frame must show (the lane character's badges); empty leaves the E5 frame.
static func frame_for(tier: int, ui: UiTuning, aspect := CameraMath.ASPECT, extra: Array[Vector3] = []) -> Dictionary:
	var pts := subject_points(tier)
	pts.append_array(extra)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	var focus := (lo + hi) * 0.5
	var proj := CameraMath.projection(ui, aspect)
	var cap := ui.tier_reveal_zoom
	var lim := 1.0  # tier 2 fits to the very edge (pinned); tiers 3 and 4 keep some air
	if tier == 3:
		lim = ui.tier_reveal_fit_t3
	elif tier == 4:
		lim = ui.tier_reveal_fit_t4
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

## E6: the corners of the two lane badges (centre +-BADGE_M/2 across and up) of `character` ({} gives none), where the badges stand.
static func badge_points(character: Dictionary) -> Array[Vector3]:
	var centres: Array[Vector3] = []
	if character.is_empty():
		return centres
	for k in ["siege", "hare"]:
		var lane := String(character.get(k, ""))
		var other := String(character.get("hare" if k == "siege" else "siege", ""))
		var a: Vector2 = TelegraphMarker.ROW_ANCHORS[lane]
		centres.append(LaneCharacterMarker.place(lane, Vector3(a.x, Balance.ui.telegraph_row_height_m, a.y), other))
	return badge_corners(centres)

## The four edge points of a badge centred at each of `centres`.
static func badge_corners(centres: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var h := LaneCharacterMarker.BADGE_M * 0.5
	for c in centres:
		for d in [Vector3(h, 0, 0), Vector3(-h, 0, 0), Vector3(0, h, 0), Vector3(0, -h, 0)]:
			out.append(c + d)
	return out

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
		if _diner_kept != null and is_instance_valid(_diner_kept):
			_world.put_back_diner_art(_diner_kept)
		else:
			_world.show_diner_for()
	_diner_kept = null
	for m in _hidden_markers:
		if is_instance_valid(m):
			m.refresh()
	_hidden_markers.clear()
	for m in _badge_markers:
		if is_instance_valid(m) and m.badge != null and is_instance_valid(m.badge):
			m.badge.scale = _badge_base.get(m.badge, Vector3.ONE)
			m.badge.hold(false)
			m.refresh()  # the badge shows what the lane character says
	_badge_markers.clear()
	_badge_base.clear()

func _on_tier_reached(tier: int) -> void:
	_cancel()
	# World connects its tier signals after this node, so this handler runs before World's _on_tier_reached; the world is
	# already rebuilt because the tier-up emits tier_changed first and World rebuilds on it. This call is a guarded no-op
	# (rebuild_for_tier returns at once when the built tier equals the tier) that keeps the order from mattering.
	_world.rebuild_for_tier()
	EventBus.banner_requested.emit(tr("The back lot opens!") if tier == 4 else tr("The diner grows!"))  # D-314.25: tier 4 grows no storey
	var yards: Array[String] = []
	for id in MapLayout.yards_for_tier(tier):
		if MapLayout.yard_tier(id) == tier:
			yards.append(id)
	_diner_art = null
	_steps = []
	if tier == 3:
		_plan_tier3()
	elif tier == 4:
		_plan_tier4(yards)
	else:
		_plan_default(tier, yards)
	var ui := Balance.ui
	var hold := minf(float(_steps.size()) * ui.tier_reveal_step_s, Balance.data.tiers.tier_reveal_time - ui.tier_reveal_in_s - ui.tier_reveal_out_s)
	var centres: Array[Vector3] = []
	for m in _badge_markers:
		centres.append(m.badge.position)  # the badges this reveal holds: none without a lane character
	var frame := frame_for(tier, ui, CameraMath.ASPECT, badge_corners(centres))
	EventBus.camera_reveal_requested.emit(ui.tier_reveal_in_s, maxf(hold, 0.0), ui.tier_reveal_out_s, frame.zoom, frame.focus)
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# The steps play inside the camera's hold: the first when the camera has reached its frame (in_s), then tier_reveal_step_s apart.
	# The reveal ends at tier_reveal_time (the card pick opens then), at least build_pop_time after the last step.
	var last_at := ui.tier_reveal_in_s + float(_steps.size() - 1) * ui.tier_reveal_step_s
	_tween.tween_interval(ui.tier_reveal_in_s)
	for i in _steps.size():
		_tween.tween_callback(_step)
		if i < _steps.size() - 1:
			_tween.tween_interval(ui.tier_reveal_step_s)
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

## The tier-3 list (spec 7): the lot, the lane, the fence spot, the tower spot, the second storey. Each
## step's things are hidden until it runs: the ground and kerb show the tier-2 yards and lanes only, the lane's flag and the two spots'
## markers are hidden, the diner shows its tier-2 art.
func _plan_tier3() -> void:
	var stretch := TierReveal.lane_stretch_points(Balance.ui.tier_reveal_lane_stretch_m)
	var lane_mid: Vector2 = stretch[0].lerp(stretch[stretch.size() - 1], 0.5)
	_steps.append({"kind": &"lot", "at": MapLayout.to3(MapLayout.yard_rect("front").get_center())})
	_steps.append({"kind": &"lane", "at": MapLayout.to3(lane_mid)})
	var character_step := _plan_lane_character()
	if not character_step.is_empty():
		_steps.append(character_step)
	_steps.append({"kind": &"spot", "id": "fence_sw", "at": MapLayout.to3(MapLayout.spot_position("fence_sw"), 1.0)})
	_steps.append({"kind": &"spot", "id": "tower_sw", "at": MapLayout.to3(MapLayout.spot_position("tower_sw"), 1.0)})
	_steps.append({"kind": &"diner", "at": Vector3(0.0, MapLayout.DINER_HEIGHT + 0.5, 0.0)})
	_world.show_map_stage(MapLayout.yards_for_tier(2), MapLayout.lanes_for_tier(2))
	_staged = true
	_diner_kept = _world.swap_diner_art_keeping(2)  # the old storey shows; the new art waits detached
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

## The tier-4 list (E8 spec 4.5): the back lot, land then tower, for each lot in turn (the north one, then the north-east one). The diner
## is not touched (tier 4 grows no storey), there is no lane-character step (no new lane, no badge) and no sign step (tier 4 is the top, so the
## sign is already hidden). The ground and kerb show the older yards until each lot's step; the two towers' markers are hidden until theirs.
func _plan_tier4(yards: Array[String]) -> void:
	var spot_ids: Array = MapLayout.TIER_SPOTS.get(4, [])
	var middle := stage_yards(4)
	for i in yards.size():
		_steps.append({"kind": &"land", "yards": middle if i < yards.size() - 1 else MapLayout.yards_for_tier(4), "final": i == yards.size() - 1,
			"at": MapLayout.to3(MapLayout.yard_rect(yards[i]).get_center())})
		if i < spot_ids.size():
			_steps.append({"kind": &"spot", "id": spot_ids[i], "at": MapLayout.to3(MapLayout.spot_position(spot_ids[i]), 1.0)})
	_world.show_map_stage(MapLayout.yards_for_tier(3), MapLayout.lanes_for_tier(4))
	_staged = true
	for id in spot_ids:
		var s: BuildSpot = _world.build_spots.get(id)
		if s != null:
			s.marker.visible = false
			_hidden_spots.append(s)

## E6 (spec 5.4): with a lane character, the step after the lane's where both badges pop. Hides the badges until then. Returns the step, or
## {} with no badge (no lane character: the list stays the five steps of E5).
func _plan_lane_character() -> Dictionary:
	# The badges (made by the tier-up's refresh, only with a lane character) say which lane is which: this node reads and writes no game
	# data. The controller schedules the lines after the pick.
	var sum := Vector3.ZERO
	for id in LanePlanner.lanes_for_tier(3):
		var m: TelegraphMarker = _world.telegraph_markers.get(id)
		if m == null or m.badge == null:
			continue
		var kind: StringName = m.badge.shown_kind()
		if kind == &"":
			continue
		_badge_markers.append(m)
		_badge_base[m.badge] = m.badge.scale
		m.badge.hold(true)  # the marker's cover rule re-shows a badge every tick: only a hold keeps it hidden
		sum += m.badge.position
	if _badge_markers.is_empty():
		return {}
	return {"kind": &"character", "at": sum / float(_badge_markers.size())}

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
		&"character":
			for m in _badge_markers:
				if is_instance_valid(m) and m.badge != null and is_instance_valid(m.badge):
					m.badge.hold(false)
					if animate:
						_pops.append(PopFx.pop(self, m.badge, _badge_base.get(m.badge, Vector3.ONE), null))
		&"diner":
			if _diner_old:
				_diner_old = false
				_world.put_back_diner_art(_diner_kept)  # the new storey (the node the world built at the tier-up)
				_diner_kept = null
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
			if _staged and animate:  # a skip goes straight to the full map at the lane step: no mesh built to be replaced at once
				_world.show_map_stage(MapLayout.yards_for_tier(3), MapLayout.lanes_for_tier(2))  # the paving, props and kerb of the lot
		&"land":
			if st.final:
				_staged = false
				_world.show_map_full()  # the last lot: everything the tier built
			elif _staged and animate:
				_world.show_map_stage(st.yards, MapLayout.lanes_for_tier(4))
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
