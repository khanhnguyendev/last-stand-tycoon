class_name YardStones
extends RefCounted
## E5 tier 3 spec 5 (D-240 revised): the yard border is a low kerb, not stones and not a fence model (fences are a
## defense). One MultiMesh of box pieces for every open yard, no collision. A piece is skipped where the tier sign or a
## build spot / station pad touches the edge, so nothing hides a pad. The class name stays (World builds `YardStones`).

const SPACING := 1.2
const HEIGHT := 0.2  ## <= 0.25 m (test_yards)
const WIDTH := 0.3
## A piece this close to the tier sign is skipped (the sign stands on the west yard's edge).
const SIGN_CLEAR := 1.3
## A piece this close to a build spot or station pad is skipped (BUILD_RADIUS + half a piece + a margin).
const PAD_CLEAR := MapLayout.BUILD_RADIUS + 0.6

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
			if p.distance_to(MapLayout.TIER_SIGN) < SIGN_CLEAR:
				continue
			var near_pad := false
			for q in pads:
				if p.distance_to(q) < PAD_CLEAR:
					near_pad = true
					break
			if near_pad:
				continue
			var len := a.distance_to(b) / float(n)
			out.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(len, 1.0, 1.0)), Vector3(p.x, HEIGHT * 0.5, p.y)))
	return out

## ONE MultiMeshInstance3D for the kerb of every yard in `yards` (MapLayout.YARDS keys).
static func build(yards: Array) -> MultiMeshInstance3D:
	var xfs: Array[Transform3D] = []
	for id in yards:
		xfs.append_array(transforms(MapLayout.YARDS[id]))
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
