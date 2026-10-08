class_name LaneCharacterMarker
extends Node3D
## E6 Task 10 (spec 5.1, D-282.5, D-289): the lasting lane-character badge at a tier-3 lane's entrance, beside tonight's count
## row: the siege icon on the siege lane, the hare icon on the hare lane, nothing on a neutral lane. Shown by day AND by night
## from the moment the game is at tier 3 with the retune flag on (GameState.lane_character() is not empty). It is a world billboard
## and, unlike the count row, does NOT hide under the HUD's top bar: it sits BELOW the row (nearer the camera, so lower on
## screen), see `place`. Visual only: nothing reads it, and there is no per-frame work (no _process, no _physics_process).
## TelegraphMarker owns one per lane, created the first time the lane has a character (so with the flag off no node exists),
## and adds it to its own parent: the marker's flag hides by night and by threat, the badge must not.

## The badge's height and width in the world (m): about 1.5 times the count row's icons so it is the first thing read.
const BADGE_M := 1.7
## Placement rule (`place`), in metres from the lane's count-row anchor (TelegraphMarker.ROW_ANCHORS, height 1.0), found by scanning the
## tier-3 views with tests/unit/test_lane_marker.gd:
##  - west and east: BELOW_M toward the camera (+z) and INWARD_M toward where the row grows, so on screen it is under the row's first icon.
##    Below the row it is lower on screen than the row, so the HUD's top bar never reaches it from a view in which the row is in view.
##  - north: BELOW_M toward the camera and NORTH_SIDE_M to the side (-x), clear of the fence_n cost label that stands under the centred row.
##  - south-west (its row sits at the foot of the map, a badge below it would leave the screen): SW_SIDE_M beside the row's first icon
##    (outer side, -x), at the row's own depth.
const BELOW_M := 5.2
const INWARD_M := 0.45
const NORTH_SIDE_M := -2.8
const SW_SIDE_M := -1.7

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
static func place(lane: String, anchor: Vector3, align: int) -> Vector3:
	if lane == "sw":
		return Vector3(anchor.x + SW_SIDE_M, anchor.y, anchor.z)
	if lane == "north":
		return Vector3(anchor.x + NORTH_SIDE_M, anchor.y, anchor.z + BELOW_M)
	return Vector3(anchor.x - float(align) * INWARD_M, anchor.y, anchor.z + BELOW_M)

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
