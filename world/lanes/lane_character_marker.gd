class_name LaneCharacterMarker
extends Node3D
## E6 Task 10 (spec 5.1, D-282.5, D-289): the lasting lane-character badge at a tier-3 lane's entrance, beside tonight's count
## row: the siege icon on the siege lane, the hare icon on the hare lane, nothing on a neutral lane. Shown by day AND by night
## from the moment the game is at tier 3 with the retune flag on (GameState.lane_character() is not empty). It is a world billboard
## and, unlike the count row, does NOT hide under the HUD's top bar: it sits BELOW the row (nearer the camera, so lower on
## screen), see `place`. Visual only: nothing reads it, and there is no per-frame work (no _process, no _physics_process).
## TelegraphMarker owns one per lane, created the first time the lane has a character (so with the flag off no node exists),
## and adds it to its own parent: the marker's flag hides by night and by threat, the badge must not.

## PLACEMENT CONSTANTS (the main session may move them to balance/ui_tuning.gd). D-292.3: the badge sits BELOW its lane's count row (nearer the
## camera, so lower on screen) and OFF the road surface (its rect meets no strip prism: half-width = the enemies' lateral spread, ground to 1.8 m,
## from the lane's own attack-zone view at three aspects). Offsets are metres from the lane's row anchor (TelegraphMarker.ROW_ANCHORS, height 1.0)
## as Vector2(x, z); +z is toward the camera. Found by scanning every offset against tests/unit/test_lane_marker.gd for six seeds. West and east
## are on the DINER side of their road: the far side is off screen at 9:21 or on the road itself (a scan found no valid offset out there).
## North: left of the fence_n label under its centred row. South-west: beside its row (below it would leave the screen).
## The badge's height and width in the world (m).
const BADGE_M := 1.7
const WEST_OFFSET := Vector2(3.9, 4.0)
const EAST_OFFSET := Vector2(-3.9, 4.0)
const NORTH_OFFSET := Vector2(-2.8, 5.2)
const SW_OFFSET := Vector2(-1.7, 0.0)

var lane_id := ""
var icon: MeshInstance3D
var _kind: StringName = &""

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

## The centre of the badge for lane `lane` whose row is anchored at `anchor` and grows toward `align` (TelegraphMarker.row_align():
## -1 toward +x, +1 toward -x, 0 centred), at the anchor's height.
static func place(lane: String, anchor: Vector3, _align := 0) -> Vector3:
	var o: Vector2 = {"west": WEST_OFFSET, "east": EAST_OFFSET, "north": NORTH_OFFSET, "sw": SW_OFFSET}.get(lane, Vector2.ZERO)
	return Vector3(anchor.x + o.x, anchor.y, anchor.z + o.y)

## `character` is GameState.lane_character(); `anchor` and `align` are the lane's row anchor and growth side.
func refresh(character: Dictionary, anchor: Vector3, align: int) -> void:
	var t := LaneCharacter.lane_type(character, lane_id)
	var kind: StringName = &""
	if t == LaneCharacter.SIEGE:
		kind = LaneCharacterIcons.SIEGE
	elif t == LaneCharacter.HARE:
		kind = LaneCharacterIcons.HARE
	position = place(lane_id, anchor, align)
	if kind != _kind:
		_kind = kind
		icon.mesh = LaneCharacterIcons.mesh(kind) if kind != &"" else null
	icon.visible = kind != &""
	visible = kind != &""

## The icon kind the badge shows now (&"siege", &"hare") or &"" when it shows nothing.
func shown_kind() -> StringName:
	return _kind if visible and icon.visible else &""
