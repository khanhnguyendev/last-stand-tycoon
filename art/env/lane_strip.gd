class_name LaneStrip
extends RefCounted
## A lane's dirt strip and its stone edge pieces (S4 Task 13, D-194, D-201). One mesh per lane: a mitred ribbon along the
## whole polyline (dirt centre, dirt_dark edges), so bends have no overlap. The edge stones are one MultiMesh per lane.
## Static, visual only: no Rng (the stone yaw is a position hash).

const WIDTH := 3.0
const EDGE := 0.3
const Y := 0.02
const STONE_SPACING := 2.5
const STONE_SCALE := 0.8
## Stones inside this rect (the diner and its walls) are skipped.
const STONE_SKIP := Rect2(-4.5, -4.5, 9, 9)
## A lane beyond the tier-1 three (the south-west one) is drawn this much above the road (ROAD_Y = Y): it crosses the road's strip.
const LIFT := 0.005
## A stone's footprint radius (the 0.8-scaled rock is about 0.8 m across).
const STONE_RADIUS := 0.4
const STONE_MODEL := "res://art/env/baked/prop_rocks_small.res"

## The per-point mitre: the unit normal (xz) and the length factor 1 / dot(miter, segment normal).
static func _frames(pts: Array) -> Array:
	var out := []
	for i in pts.size():
		var n := Vector2.ZERO
		var k := 0.0
		if i > 0:
			var d: Vector2 = ((pts[i] as Vector2) - (pts[i - 1] as Vector2)).normalized()
			n += Vector2(-d.y, d.x)
		if i < pts.size() - 1:
			var d2: Vector2 = ((pts[i + 1] as Vector2) - (pts[i] as Vector2)).normalized()
			n += Vector2(-d2.y, d2.x)
		n = n.normalized()
		var seg: Vector2 = ((pts[i + 1] as Vector2) - (pts[i] as Vector2)).normalized() if i < pts.size() - 1 else ((pts[i] as Vector2) - (pts[i - 1] as Vector2)).normalized()
		k = 1.0 / maxf(n.dot(Vector2(-seg.y, seg.x)), 0.25)
		out.append([n, k])
	return out

## The strip's vertex arrays along `pts` (Array of Vector2 xz), `width` wide, with `edge`-wide dirt_dark borders.
static func strip_arrays(pts: Array, width := WIDTH, edge := EDGE, y := Y) -> Dictionary:
	var frames := _frames(pts)
	var half := width * 0.5
	var offsets := [-half, -half + edge, half - edge, half]
	var dirt := Palette.color(&"dirt")
	var dark := Palette.color(&"dirt_dark")
	var cols := [dark, dirt, dirt, dark]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for i in pts.size():
		var n: Vector2 = frames[i][0]
		var k: float = frames[i][1]
		for o in 4:
			var p: Vector2 = (pts[i] as Vector2) + n * (offsets[o] * k)
			verts.append(Vector3(p.x, y, p.y))
			normals.append(Vector3.UP)
			colors.append(cols[o])
	var idx := PackedInt32Array()
	for i in range(1, pts.size()):
		for o in 3:
			var a := (i - 1) * 4 + o
			var b := i * 4 + o
			idx.append_array([a, a + 1, b, a + 1, b + 1, b])
	_fix_winding(verts, idx)
	return {"v": verts, "n": normals, "c": colors, "i": idx}

## The strip as a mesh (tests).
static func build_mesh(pts: Array) -> ArrayMesh:
	return GroundArt.mesh_from(strip_arrays(pts))

## Make the faces front-facing from above whatever the polyline direction is (Godot's front face is clockwise: its
## right-hand normal points down).
static func _fix_winding(verts: PackedVector3Array, idx: PackedInt32Array) -> void:
	if idx.size() < 3:
		return
	var a := verts[idx[0]]
	if (verts[idx[1]] - a).cross(verts[idx[2]] - a).y <= 0.0:
		return
	for t in idx.size() / 3:
		var tmp := idx[t * 3 + 1]
		idx[t * 3 + 1] = idx[t * 3 + 2]
		idx[t * 3 + 2] = tmp

## Edge-stone transforms: every STONE_SPACING m along the path, on both sides at the strip's outer edge.
static func edge_transforms(pts: Array, spacing := STONE_SPACING, width := WIDTH, avoid := false) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var side := width * 0.5 + 0.25
	var walked := 0.0
	var next := spacing * 0.5
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var len := a.distance_to(b)
		var d := (b - a) / len
		var nrm := Vector2(-d.y, d.x)
		while next <= walked + len:
			var c := a + d * (next - walked)
			for s in [-1.0, 1.0]:
				var p: Vector2 = c + nrm * (side * s)
				if STONE_SKIP.has_point(p) or (avoid and blocked(p)):
					continue
				var yaw := GroundArt.hash01(p.x, p.y) * TAU
				out.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * STONE_SCALE), Vector3(p.x, 0.0, p.y)))
			next += spacing
		walked += len
	return out

## The order the tier-1/2 lanes were always drawn in (the old dictionary's key order): a mesh and a stone list built in it are
## byte-identical to the S4 ones. Lanes past these (sw, tier 3) follow in the order given. Empty `lanes` = the tier-1 lanes.
const DRAW_ORDER: Array[String] = ["north", "west", "east"]

## The y a lane's strip is drawn at: Y for the tier-1 three (their bytes never changed), a hair above for the rest.
static func strip_y(lane: String) -> float:
	return Y if lane in DRAW_ORDER else Y + LIFT

## Circles (centre, radius) and rects a lane beyond the tier-1 three keeps its edge stones off: the branch pads, every build-spot and
## upgrade pad, the station zones and the signs, the gold pile, HOME, the tier-3 queue slots; and the counter and freezer rects.
static func avoid_circles() -> Array:
	var out := []
	for id in MapLayout.BRANCH_PADS:
		for c in MapLayout.BRANCH_PADS[id]:
			out.append([c, MapLayout.BRANCH_PAD_RADIUS])
	for id in MapLayout.ALL_SPOT_IDS:
		out.append([MapLayout.spot_position(id), MapLayout.BUILD_RADIUS])
	for c in MapLayout.STATION_PADS.values():
		out.append([c, MapLayout.BUILD_RADIUS])
	for c in [MapLayout.SIGN, MapLayout.FREEZER_ZONE, MapLayout.COUNTER_DROP, MapLayout.GOLD_PILE, MapLayout.HOME]:
		out.append([c, MapLayout.STATION_RADIUS])
	for t in MapLayout.TIER_SIGNS:
		out.append([MapLayout.tier_sign(t), MapLayout.STATION_RADIUS])
	for c in MapLayout.queue_slots(3):
		out.append([c, 0.5])
	return out

static func avoid_rects() -> Array[Rect2]:
	return [Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE * 0.5, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE * 0.5, MapLayout.FREEZER_SIZE)]

static func blocked(p: Vector2) -> bool:
	for c in avoid_circles():
		if p.distance_to(c[0]) < float(c[1]) + STONE_RADIUS:
			return true
	for r in avoid_rects():
		if r.grow(STONE_RADIUS).has_point(p):
			return true
	return false

static func draw_order(lanes: Array) -> Array[String]:
	var want: Array = MapLayout.lanes_for_tier(1) if lanes.is_empty() else lanes
	var out: Array[String] = []
	for id in DRAW_ORDER:
		if id in want:
			out.append(id)
	for id in want:
		if not id in out:
			out.append(id)
	return out

## The MultiMesh of the edge stones of `lanes` (World swaps it into its EdgeStones node when the lane set changes).
static func edge_multimesh(lanes: Array = []) -> MultiMesh:
	var xfs: Array[Transform3D] = []
	for id in draw_order(lanes):
		xfs.append_array(edge_transforms(MapLayout.lane_path(id), STONE_SPACING, WIDTH, not id in DRAW_ORDER))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = load(STONE_MODEL) as Mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	return mm

## One world-level MultiMeshInstance3D with the edge stones of the lanes in `lanes` (D-201); none = the tier-1 lanes.
static func edge_stones(lanes: Array = []) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "EdgeStones"
	mmi.multimesh = edge_multimesh(lanes)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
