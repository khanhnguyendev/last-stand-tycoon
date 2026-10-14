class_name LaneCharacterMarker
extends Node3D
## E6 Task 10 (spec 5.1, D-282.5, D-289): the lasting lane-character badge at a tier-3 lane's entrance, beside tonight's count
## row: the siege icon on the siege lane, the hare icon on the hare lane, nothing on a neutral lane. Shown by day AND by night
## from the moment the game is at tier 3 (GameState.lane_character() is not empty). It is a world billboard
## and, unlike the count row, does NOT hide under the HUD's top bar: it sits BELOW the row (nearer the camera, so lower on
## screen), see `place`. Visual only: nothing reads it, and there is no per-frame work (no _process, no _physics_process): a Timer
## ticks `Balance.ui.label_dim_hz` times a second and HIDES the badge (its `visible`, written only on a change) while its screen rect,
## grown COVER_GROW_PX, would cover the hero, a build spot's cost / MAX label or level pips, or a station's label (E6 fix round 3).
## TelegraphMarker owns one per lane, created the first time the lane has a character (so below tier 3 no node exists),
## and adds it to its own parent: the marker's flag hides by night and by threat, the badge must not.

## PLACEMENT CONSTANTS (the main session may move them to balance/ui_tuning.gd). D-292.3: the badge sits BELOW its lane's count row (nearer the
## camera, so lower on screen) and OFF the road: from its own lane's zone view at three aspects its rect, grown 4 px, meets neither the drawn
## road (surface + kerb: LaneStrip.WIDTH / 2 + 0.25 on each side, on the ground) nor the enemies' volume (half-width lateral_spread + 0.975,
## a brute at the spread's limit, 1.5 m high); tests/unit/test_lane_marker.gd measures both. Offsets are metres from the lane's row anchor
## (TelegraphMarker.ROW_ANCHORS, height 1.0) as Vector2(x, z); +z is toward the camera. West and east are on the DINER side of their road:
## the far side is off screen at 9:21 or on the road itself.
## The badge's height and width in the world (m).
const BADGE_M := 1.6
const WEST_OFFSET := Vector2(4.2, 3.2)
const EAST_OFFSET := Vector2(-4.2, 3.2)
## The north badge mirrors to the east side (x +4.0) when the run's OTHER badge is on the west lane (and stays on the west side when it is on the east lane
## or the south-west one): west + north would put both in the same grass wedge, 175 px apart.
const NORTH_OFFSET := Vector2(-4.0, 5.0)
const SW_OFFSET := Vector2(-1.7, 1.05)
## The hide rule: a margin (screen px) around the badge and the hero's body box (m, relative to its ground point).
const COVER_GROW_PX := 4.0
const HERO_BOX := AABB(Vector3(-0.4, 0.0, -0.05), Vector3(0.8, 1.8, 0.1))

var lane_id := ""
var icon: MeshInstance3D
var _kind: StringName = &""
var _tick: Timer
## How many times the cover rule has run (a test reads it: at most `label_dim_hz` a second).
var ticks := 0
## The physics frame of the last cover evaluation (a test reads it: two badges do not evaluate in the same frame).
var last_tick_frame := -1
## True while the dawn reveal holds the badge hidden (`hold`): the cover rule does not show it.
var held := false
## Where in the tick period each lane's timer starts (fraction), so two badges never evaluate in the same physics frame.
const TICK_PHASE := {"west": 0.0, "east": 0.25, "north": 0.5, "sw": 0.75}

func setup(id: String) -> void:
	lane_id = id
	name = "LaneCharacter_" + id
	top_level = true
	icon = MeshInstance3D.new()
	icon.name = "Icon"
	icon.material_override = LaneCharacterIcons.material()
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	icon.scale = Vector3.ONE * BADGE_M
	icon.visible = false
	add_child(icon)
	visible = false
	_tick = Timer.new()
	_tick.name = "CoverTick"
	_tick.wait_time = 1.0 / maxf(Balance.ui.label_dim_hz, 0.01)
	_tick.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_tick.timeout.connect(_on_timer)
	add_child(_tick)
	var period := _tick.wait_time
	var first := period * (1.0 + float(TICK_PHASE.get(lane_id, 0.0)))
	if is_inside_tree():
		_tick.start(first)
	else:
		_tick.autostart = true

func _on_timer() -> void:
	var period := 1.0 / maxf(Balance.ui.label_dim_hz, 0.01)
	if not is_equal_approx(_tick.wait_time, period):
		_tick.wait_time = period  # the first wait carried the lane's phase
	tick()

## The centre of the badge for lane `lane` whose row is anchored at `anchor`, at the anchor's height. An unknown lane is a bug.
static func place(lane: String, anchor: Vector3, other_lane := "") -> Vector3:
	var offsets := {"west": WEST_OFFSET, "east": EAST_OFFSET, "north": NORTH_OFFSET, "sw": SW_OFFSET}
	assert(offsets.has(lane), "LaneCharacterMarker.place: unknown lane %s" % lane)
	var o: Vector2 = offsets[lane]
	if lane == "north" and other_lane == "west":
		o.x = -o.x
	return Vector3(anchor.x + o.x, anchor.y, anchor.z + o.y)

## `character` is GameState.lane_character(); `anchor` is the lane's row anchor.
func refresh(character: Dictionary, anchor: Vector3) -> void:
	var t := LaneCharacter.lane_type(character, lane_id)
	var kind: StringName = &""
	if t == LaneCharacter.SIEGE:
		kind = LaneCharacterIcons.SIEGE
	elif t == LaneCharacter.HARE:
		kind = LaneCharacterIcons.HARE
	var other := ""
	for k in ["siege", "hare"]:
		if String(character.get(k, "")) != lane_id:
			other = String(character.get(k, ""))
	position = place(lane_id, anchor, other)
	if kind != _kind:
		_kind = kind
		icon.mesh = LaneCharacterIcons.mesh(kind) if kind != &"" else null
	icon.visible = kind != &""
	visible = kind != &"" and not held
	if visible and is_inside_tree():
		tick()  # no flicker: a refresh never shows the badge over a label for a tick

## The icon kind the badge stands for now (&"siege", &"hare") or &"" when it has none (a neutral lane). It does not change while the
## cover rule hides the badge: see `is_covered`.
func shown_kind() -> StringName:
	return _kind if icon.visible else &""

## True while the cover rule hides a badge that has a kind.
func is_covered() -> bool:
	return icon.visible and not visible and not held

## The dawn reveal holds the badge hidden (on) and lets it go (off): the cover rule then decides again at once.
func hold(on: bool) -> void:
	held = on
	if on:
		visible = false
	else:
		visible = icon.visible
		if is_inside_tree():
			tick()

## The cover rule once, from the viewport's camera and the hero node.
func tick() -> void:
	if icon == null or not icon.visible or held:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	ticks += 1
	last_tick_frame = Engine.get_physics_frames()
	var hero_pos: Variant = null
	var heroes := get_tree().get_nodes_in_group(&"hero")
	if not heroes.is_empty():
		hero_pos = (heroes[0] as Node3D).global_position
	evaluate(cam.global_transform, func(w: Vector3) -> Vector2:
		return Vector2(INF, INF) if cam.is_position_behind(w) else cam.unproject_position(w), hero_pos, get_viewport().get_visible_rect())

## Hides the badge while `covers` is true, shows it when clear; `visible` is written only on a change. `project` maps a world point to
## screen px, `xf` is the camera's transform (its basis gives the billboard axes), `hero_pos` the hero's ground point or null, `screen` the
## viewport rect in the same px (an empty Rect2 = unknown).
func evaluate(xf: Transform3D, project: Callable, hero_pos: Variant, screen := Rect2()) -> void:
	if held:
		return
	var want := not covers(xf, project, hero_pos, screen)
	if visible != want:
		visible = want

## True when this badge's screen rect, grown COVER_GROW_PX, meets the hero's body, a visible spot cost / MAX label or level pip, or a
## visible station label (the labels of the "world_labels" group whose parent is a build spot, an upgrade pad, the counter, the freezer,
## the gold pile, the close-up sign or the tier sign).
func covers(xf: Transform3D, project: Callable, hero_pos: Variant, screen := Rect2()) -> bool:
	if icon == null or icon.mesh == null:
		return false
	var bb := icon.mesh.get_aabb()
	var c := icon.global_position + xf.basis.x * (bb.get_center().x * icon.scale.x) + xf.basis.y * (bb.get_center().y * icon.scale.y)
	var mine := _quad(xf, project, c, Vector2(bb.size.x, bb.size.y) * icon.scale.x).grow(COVER_GROW_PX)
	if screen.has_area() and not screen.intersects(mine):
		return false  # off screen: nothing to cover
	if hero_pos != null:
		var p: Vector3 = hero_pos
		if mine.intersects(_box(project, AABB(p + HERO_BOX.position, HERO_BOX.size))):
			return true
	for n in get_tree().get_nodes_in_group(&"world_labels"):
		var l := n as Label3D
		if l == null or not l.is_inside_tree():
			continue
		var owner_node := l.get_parent()
		if not (owner_node is BuildSpot or owner_node is UpgradePad or owner_node is Counter or owner_node is Freezer \
				or owner_node is GoldPile or owner_node is CloseUpSign or owner_node is TierSign):
			continue
		if l.is_visible_in_tree() and l.text != "":
			var b := BranchPad.text_box(l)
			var lc := l.global_position
			if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT:
				lc += xf.basis.x * b.x * 0.5
			if mine.intersects(_quad(xf, project, lc, b)):
				return true
	# the level pips of every spot and upgrade pad (a pip is in the group `level_pips`; its label may be hidden: a branch spot's cost is on its pads)
	for n in get_tree().get_nodes_in_group(&"level_pips"):
		var pip := n as LevelPip
		if pip != null and pip.is_visible_in_tree():
			var pb: AABB = LevelStar.mesh().get_aabb()
			if mine.intersects(_quad(xf, project, pip.global_position, Vector2(pb.size.x, pb.size.y))):
				return true
	return false

func _quad(xf: Transform3D, project: Callable, c: Vector3, sz: Vector2) -> Rect2:
	var hx := xf.basis.x * sz.x * 0.5
	var hy := xf.basis.y * sz.y * 0.5
	return _bounds(project, [c + hx + hy, c - hx + hy, c + hx - hy, c - hx - hy])

func _box(project: Callable, b: AABB) -> Rect2:
	var pts: Array = []
	for k in 8:
		pts.append(b.position + Vector3(b.size.x * (k & 1), b.size.y * ((k >> 1) & 1), b.size.z * ((k >> 2) & 1)))
	return _bounds(project, pts)

func _bounds(project: Callable, pts: Array) -> Rect2:
	var r := Rect2(project.call(pts[0]), Vector2.ZERO)
	for q in pts:
		r = r.expand(project.call(q))
	return r
