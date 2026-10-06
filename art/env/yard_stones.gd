class_name YardStones
extends RefCounted
## E5 spec 7.3 (D-240): the yard ring is small stones, not a fence model (fences are a defense). One MultiMesh for every
## open yard, no collision, yaw fixed by position hash (no Rng).

const SPACING := 1.2
const SCALE := 0.55
## A stone this close to the tier sign is skipped (the sign stands on the west yard's edge).
const SIGN_CLEAR := 1.3

static func transforms(rect: Rect2) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var n := int(floor(a.distance_to(b) / SPACING))
		for k in n:
			var p := a.lerp(b, (k + 0.5) / float(n))
			if p.distance_to(MapLayout.TIER_SIGN) < SIGN_CLEAR:
				continue
			var yaw := GroundArt.hash01(p.x, p.y) * TAU
			out.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * SCALE), Vector3(p.x, 0.0, p.y)))
	return out

## ONE MultiMeshInstance3D for the stones of every yard in `yards` (MapLayout.YARDS keys).
static func build(yards: Array) -> MultiMeshInstance3D:
	var xfs: Array[Transform3D] = []
	for id in yards:
		xfs.append_array(transforms(MapLayout.YARDS[id]))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = load(LaneStrip.STONE_MODEL) as Mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "YardStones"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
