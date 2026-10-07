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

## Pads and stations the kerb leaves free (every tier's spots: a spot not yet built is skipped by its position anyway).
static func pad_points() -> Array:
	var out: Array = []
	for id in MapLayout.ALL_SPOT_IDS:
		out.append(MapLayout.spot_position(id))
	out.append_array(MapLayout.STATION_PADS.values())
	return out

## The kerb pieces of `rect`: a transform per piece, origin on the outline at half the height, yawed along the edge,
## x scaled to the piece length (the unit mesh is 1 x HEIGHT x WIDTH).
static func transforms(rect: Rect2) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var pads := pad_points()
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var n := int(floor(a.distance_to(b) / SPACING))
		var yaw := -(b - a).angle()
		for k in n:
			var p := a.lerp(b, (k + 0.5) / float(n))
			var piece_len := a.distance_to(b) / float(n)
			var half := (b - a).normalized() * piece_len * 0.5
			var near_pad := false
			for q in pads:
				if Geometry2D.get_closest_point_to_segment(q, p - half, p + half).distance_to(q) < PAD_CLEAR:
					near_pad = true
					break
			if near_pad:
				continue
			out.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(piece_len, 1.0, 1.0)), Vector3(p.x, HEIGHT * 0.5, p.y)))
	return out

## ONE MultiMeshInstance3D for the kerb of every yard in `yards` (MapLayout yard ids).
static func build(yards: Array) -> MultiMeshInstance3D:
	var xfs: Array[Transform3D] = []
	for id in yards:
		xfs.append_array(transforms(MapLayout.yard_rect(id)))
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
