class_name TelegraphMarker
extends Node3D
## Day-only threat marker near each lane's fence spot (D-029, D-093). Hidden when threat is 0.

const FLAG_SCENE := preload("res://art/env/telegraph_flag.tscn")

## E5 tier 3 Task 14 (D-264): the composition row above the flag, a Boar / hare / brute icon + count for each kind above 0
## on this lane tonight, and the boss icon (no number) on the boss lane. Visual only: nothing in the game reads it.
const ROW_KINDS: Array[StringName] = [&"boar", &"hare", &"brute"]
const BOSS := &"boss"
## WorldLabel's pixel_size, which sets how large a font_size reads in the world.
const LABEL_PIXEL := 0.01
## A digit is about this fraction of the font size wide (layout only).
const DIGIT_EM := 0.6

var lane_id := ""
var target_scale := 0.0
## The row node (top level, so the flag's scale does not scale it) and its parts by kind: {icon: MeshInstance3D, num: WorldLabel or null}.
var row: Node3D
var items := {}
var _phase := Phase.NIGHT
## E5 tier 3 Task 20: the row's local x range [from, to] as _fill_row laid it out (empty when it shows nothing), and the HUD top bar's
## height in viewport pixels (the safe-area inset + UiTuning.hud_top_bar_px; refreshed on a resize and on a phase change).
var _row_span := Vector2.ZERO
var _bar_px := 0.0

func setup(id: String) -> void:
	lane_id = id
	name = "Telegraph_" + id
	position = MapLayout.to3(MapLayout.telegraph_spot(id))
	var visual := FLAG_SCENE.instantiate()  # root "Visual"; the flag mesh carries the enemy_red override (R4)
	add_child(visual)
	_build_row()
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.state_restored.connect(refresh)
	EventBus.tier_changed.connect(_on_tier_changed)  # the day the tier is paid, the boss lane already shows
	_refresh_bar()
	refresh()

## A marker made mid-game missed phase_changed: the world hands it the phase it last announced.
func sync_phase(p: int) -> void:
	_phase = p
	refresh()

func _on_phase_changed(p: int, _day: int) -> void:
	_phase = p
	_refresh_bar()
	refresh()

## The HUD top bar's height (viewport px), cached: SafeArea.insets may ask the browser, so it is not read every frame.
func _refresh_bar() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport()
	if not vp.size_changed.is_connected(_refresh_bar):
		vp.size_changed.connect(_refresh_bar)
	_bar_px = float(SafeArea.insets(vp.get_visible_rect().size).top) + Balance.ui.hud_top_bar_px

## Visual only, and nothing reads it: a row whose screen rect touches the HUD's top bar (the gold counter and the day label draw over it)
## is hidden, shown again when it clears. Once per physics frame, only while the flag shows; `visible` is written only on a change.
func _physics_process(_delta: float) -> void:
	if row == null or not visible:
		return
	var want := not row_under_hud()
	if row.visible != want:
		row.visible = want

## True while the row's projected rect (its icons' extent, from the camera now) intersects the top bar. False for an empty row, with
## no camera, or when any corner is behind the camera.
func row_under_hud() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _row_span.x >= _row_span.y:
		return false
	var anchor := row_anchor()
	var half := Balance.ui.telegraph_icon_m * 0.5
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for x in [_row_span.x, _row_span.y]:
		for dy in [-half, half]:
			var w := Vector3(anchor.x + x, anchor.y + dy, anchor.z)
			if cam.is_position_behind(w):
				return false
			var p := cam.unproject_position(w)
			lo = lo.min(p)
			hi = hi.max(p)
	return lo.y < _bar_px

func _on_tier_changed(_tier: int, _paid: int, _boss_pending: bool) -> void:
	refresh()

func refresh() -> void:
	if GameState.lane_plan.is_empty():
		target_scale = 0.0
		visible = false
		_fill_row({})
		return
	var threat := LanePlanner.threat_by_lane(GameState.lane_plan, Balance.data.enemy.hp, GameState.tier)
	var mx: float = threat.values().max()
	target_scale = LanePlanner.marker_scale(float(threat.get(lane_id, 0.0)), mx, Balance.ui.telegraph_scale_min, Balance.ui.telegraph_scale_max)
	visible = _phase == Phase.DAY and target_scale > 0.0
	if target_scale > 0.0:
		scale = Vector3.ONE * target_scale
	_fill_row(LanePlanner.composition_by_lane(GameState.lane_plan, GameState.tier).get(lane_id, {}))

func _build_row() -> void:
	row = Node3D.new()
	row.name = "Composition"
	row.top_level = true
	add_child(row)
	for kind in ROW_KINDS + [BOSS]:
		var icon := MeshInstance3D.new()
		icon.name = "Icon_" + String(kind)
		icon.mesh = LaneIcons.mesh(kind)
		icon.material_override = LaneIcons.material()
		icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		icon.visible = false
		row.add_child(icon)
		var num: WorldLabel = null
		if kind != BOSS:
			num = WorldLabel.make("", int(roundf(Balance.ui.telegraph_number_em_m / LABEL_PIXEL)))
			num.name = "Num_" + String(kind)
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			num.visible = false
			row.add_child(num)
		items[kind] = {"icon": icon, "num": num}

## What the row shows now: {kind: count} for the visible number items, plus `boss: 1` when the boss icon shows.
func shown() -> Dictionary:
	var out := {}
	for kind in items:
		var it: Dictionary = items[kind]
		if not (it.icon as Node3D).visible:
			continue
		out[kind] = 1 if kind == BOSS else int((it.num as Label3D).text)
	return out

## Where each lane's row is anchored (ground x, z), chosen by a search over the whole tier-3 build (every cost label and level
## pip at every level, the hero on every spot, pad, zone and HOME, three aspects; tests/unit/test_telegraph.gd re-checks it):
## the three northern lanes share the one band at z = -15, past the towers' tall labels and still on screen from HOME, each
## growing inward from where its lane crosses it (the west and east ends are clamped to x = -11 and 11 so a full row stays
## on screen); the south-west lane's row sits on the open ground south of its road, off the queue, the sign and HOME.
const ROW_ANCHORS := {
	"west": Vector2(-11.0, -15.0), "north": Vector2(0.0, -15.0), "east": Vector2(11.0, -15.0), "sw": Vector2(-4.5, 13.0),
}

## The row's anchor: its ground point at the fixed row height (no threat term).
func row_anchor() -> Vector3:
	var p: Vector2 = ROW_ANCHORS[lane_id]
	return Vector3(p.x, Balance.ui.telegraph_row_height_m, p.y)

## -1 grows toward +x (west side), +1 toward -x (east side), 0 centred (the north lane): always inward, so the row stays on screen.
func row_align() -> int:
	var x := row_anchor().x
	if absf(x) < 1.0:
		return 0
	return -1 if x < 0.0 else 1

## Lays out the kinds above 0 left to right from the anchor, inward, at the fixed height.
func _fill_row(comp: Dictionary) -> void:
	if row == null:
		return
	var ui := Balance.ui
	var icon_m: float = ui.telegraph_icon_m
	var em: float = ui.telegraph_number_em_m
	var gap: float = ui.telegraph_row_gap_m
	var kinds: Array = []
	for kind in ROW_KINDS + [BOSS]:
		var n := int(comp.get(kind, 0))
		var it: Dictionary = items[kind]
		(it.icon as Node3D).visible = n > 0
		if it.num != null:
			(it.num as Label3D).visible = n > 0
			(it.num as Label3D).text = str(n) if n > 0 else ""
		if n > 0:
			kinds.append(kind)
	var widths: Array[float] = []
	var total := 0.0
	for kind in kinds:
		var w := icon_m
		if kind != BOSS:
			w += gap * 0.5 + float(str(int(comp[kind])).length()) * em * DIGIT_EM
		widths.append(w)
		total += w
	total += gap * maxf(float(kinds.size() - 1), 0.0)
	row.position = row_anchor()
	row.scale = Vector3.ONE
	var x := 0.0
	match row_align():
		0:
			x = -total * 0.5
		1:
			x = -total
	_row_span = Vector2(x, x + total) if not kinds.is_empty() else Vector2.ZERO
	for i in kinds.size():
		var it: Dictionary = items[kinds[i]]
		var icon := it.icon as Node3D
		icon.scale = Vector3.ONE * icon_m
		icon.position = Vector3(x + icon_m * 0.5, 0, 0)
		if it.num != null:
			(it.num as Node3D).position = Vector3(x + icon_m + gap * 0.5, 0, 0.02)
		x += widths[i] + gap
