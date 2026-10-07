class_name YardStones
extends RefCounted
## E5 tier 3 spec 5 (D-240 revised, D-262, D-268): the yard border is a low kerb, not stones and not a fence model
## (fences are a defense). One MultiMesh of box pieces for every open yard, no collision. A piece is skipped where a build
## spot or station pad touches the edge, so nothing hides a pad. The kerb is closed everywhere else, also by the tier sign:
## the sign of tier N+1 and an open yard of tier N+1 never coexist (main-session ruling, fix round 1). The class name stays
## (World builds `YardStones`).

const SPACING := 1.2
const HEIGHT := 0.2  ## <= 0.25 m (test_yards)
const WIDTH := 0.3
## A piece whose centre line comes closer than this to a build spot or station pad is skipped: the pad radius, half the
## kerb width, and PAD_MARGIN of room for the marker's corner brackets and the hero's body.
const PAD_MARGIN := 0.5
const PAD_CLEAR := MapLayout.BUILD_RADIUS + WIDTH * 0.5 + PAD_MARGIN

static var _material: StandardMaterial3D

static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.resource_name = "yard_kerb"
		_material.albedo_color = Palette.color(&"steel_dark")
		_material.roughness = 1.0
	return _material

## EnemyBalance.lateral_spread's default (art code does not reach the Balance autoload: tools compile this file without it);
## World passes the live value.
const DEFAULT_LANE_SPREAD := 1.0
## Room kept between a kerb piece's edge and the SW lane's monster spread (tier 3, the front lot).
const LANE_MARGIN := 0.2
## The front lot is 6.1 x 4.3 m and holds a tower pad, a fence bar, the lane's width and branch pads at its edges: whole 1.2 m pieces and
## the 0.5 m margin of the side yards leave no kerb at all (probed: 0 of 15 pieces). Its kerb is cut in short pieces and keeps PAD_MARGIN_T3
## of air from what it leaves free instead; the side yards keep SPACING and PAD_MARGIN (their kerb is byte-identical to tier 2's).
const SPACING_T3 := 0.4
const PAD_MARGIN_T3 := 0.2
## A tier-3 piece closer than these to a centre line is skipped: the pad or bar radius, half the kerb width, and PAD_MARGIN_T3.
const BRANCH_PAD_CLEAR := MapLayout.BRANCH_PAD_RADIUS + WIDTH * 0.5 + PAD_MARGIN_T3
const PAD_CLEAR_T3 := MapLayout.BUILD_RADIUS + WIDTH * 0.5 + PAD_MARGIN_T3

## Pads and stations the kerb leaves free (every tier's spots: a spot not yet built is skipped by its position anyway).
## Unchanged by tier 3 (pinned byte-identical by test_tier3_world_layout); the tier-3 plot adds branch_pad_points() and tier3_keep_free().
static func pad_points() -> Array:
	var out: Array = []
	for id in MapLayout.ALL_SPOT_IDS:
		out.append(MapLayout.spot_position(id))
	out.append_array(MapLayout.STATION_PADS.values())
	return out

## The branch pad centres of tier 3 (spec 4.3): the tier-3 plot's kerb leaves every one of them free where it touches an edge.
static func branch_pad_points() -> Array:
	var out: Array = []
	for id in MapLayout.BRANCH_PADS:
		out.append_array(MapLayout.BRANCH_PADS[id])
	return out

## The tier-3 plot's extra no-kerb zones as segments with the clear distance each keeps from a piece's centre line:
## the south-west lane (centre line, the monsters' lateral spread + half the kerb width + LANE_MARGIN: the whole lane width, no piece
## across it) and every fence bar (half depth 0.5 + half the kerb width + PAD_MARGIN_T3). Fence pads and tower pads are in pad_points().
static func tier3_keep_free(lane_spread := DEFAULT_LANE_SPREAD) -> Array:
	var out: Array = []
	var lane_clear := lane_spread + WIDTH * 0.5 + LANE_MARGIN
	var path: Array = MapLayout.lane_path("sw")
	for i in range(1, path.size()):
		out.append([path[i - 1], path[i], lane_clear])
	var bar_clear := 0.5 + WIDTH * 0.5 + PAD_MARGIN_T3
	for lane in MapLayout.lanes_for_tier(3):
		var pts: Array = MapLayout.lane_path(lane)
		var t := Geometry.tangent_at(pts, Geometry.path_length(pts) - MapLayout.FENCE_OFFSET_FROM_END)
		var n := Vector2(-t.y, t.x)
		var f := MapLayout.fence_spot(lane)
		out.append([f - n * MapLayout.FENCE_BAR_HALF, f + n * MapLayout.FENCE_BAR_HALF, bar_clear])
	return out

## The kerb pieces of `rect`: a transform per piece, origin on the outline at half the height, yawed along the edge,
## x scaled to the piece length (the unit mesh is 1 x HEIGHT x WIDTH).
## `tier3` (the front lot only): also leave free the SW lane's width, every fence bar and every branch pad.
static func transforms(rect: Rect2, tier3 := false, lane_spread := DEFAULT_LANE_SPREAD) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var pads := pad_points()
	var branch := branch_pad_points() if tier3 else []
	var free := tier3_keep_free(lane_spread) if tier3 else []
	var spacing := SPACING_T3 if tier3 else SPACING
	var pad_clear := PAD_CLEAR_T3 if tier3 else PAD_CLEAR
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var n := int(floor(a.distance_to(b) / spacing))
		var yaw := -(b - a).angle()
		for k in n:
			var p := a.lerp(b, (k + 0.5) / float(n))
			var piece_len := a.distance_to(b) / float(n)
			var half := (b - a).normalized() * piece_len * 0.5
			var near_pad := false
			for q in pads:
				if Geometry2D.get_closest_point_to_segment(q, p - half, p + half).distance_to(q) < pad_clear:
					near_pad = true
					break
			if not near_pad:
				for q in branch:
					if Geometry2D.get_closest_point_to_segment(q, p - half, p + half).distance_to(q) < BRANCH_PAD_CLEAR:
						near_pad = true
						break
			if not near_pad:
				for f in free:
					if _segments_closer(p - half, p + half, f[0], f[1], float(f[2])):
						near_pad = true
						break
			if near_pad:
				continue
			out.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(piece_len, 1.0, 1.0)), Vector3(p.x, HEIGHT * 0.5, p.y)))
	return out

## True when segments a-b and c-d come within `dist` of each other.
static func _segments_closer(a: Vector2, b: Vector2, c: Vector2, d: Vector2, dist: float) -> bool:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
		return true
	return minf(minf(Geometry.dist_point_segment(a, c, d), Geometry.dist_point_segment(b, c, d)),
		minf(Geometry.dist_point_segment(c, a, b), Geometry.dist_point_segment(d, a, b))) < dist

## ONE MultiMeshInstance3D for the kerb of every yard in `yards` (MapLayout yard ids).
static func build(yards: Array, lane_spread := DEFAULT_LANE_SPREAD) -> MultiMeshInstance3D:
	var xfs: Array[Transform3D] = []
	for id in yards:
		xfs.append_array(transforms(MapLayout.yard_rect(id), MapLayout.yard_tier(id) >= 3, lane_spread))
	return _instance(xfs)

## One piece at the origin: the warm-up draws it so the kerb's mesh and material are uploaded before the tier-2 reveal.
static func build_sample() -> MultiMeshInstance3D:
	return _instance([Transform3D(Basis.IDENTITY, Vector3(0.0, HEIGHT * 0.5, 0.0))] as Array[Transform3D])

static func _instance(xfs: Array[Transform3D]) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(1.0, HEIGHT, WIDTH)
	box.material = material()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "YardStones"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
