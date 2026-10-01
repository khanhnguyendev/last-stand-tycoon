class_name PileMesh
extends RefCounted
## One MultiMeshInstance3D per pile (D-201): a fixed set of slot positions of one shared mesh, of which the first n
## are drawn. The factory is `make` so it doesn't shadow Object.new. Visual only (spec 7).

const STEAK_SCENE := "res://art/pickups/steak.tscn"
const COIN_SCENE := "res://art/pickups/coin.tscn"
static var _items := {}  # key -> {mesh: Mesh, xf: Transform3D}

static func make(mesh: Mesh, slots: PackedVector3Array, item_xf: Transform3D = Transform3D.IDENTITY) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = slots.size()
	for i in slots.size():
		mm.set_instance_transform(i, Transform3D(item_xf.basis, item_xf.origin + slots[i]))
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

static func set_count(mmi: MultiMeshInstance3D, n: int) -> void:
	mmi.multimesh.visible_instance_count = clampi(n, 0, mmi.multimesh.instance_count)

static func count(mmi: MultiMeshInstance3D) -> int:
	return mmi.multimesh.visible_instance_count

## The mesh of a pickup scene (taken once from its MeshInstance3D) and the transform that places it flat on y = 0,
## centred on x and z. `lay_flat` turns an upright model (the coin) onto its face.
static func _item(scene_path: String, lay_flat: bool) -> Dictionary:
	var key := "%s:%s" % [scene_path, lay_flat]
	if _items.has(key):
		return _items[key]
	var root: Node3D = (load(scene_path) as PackedScene).instantiate()
	var mi := root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var xf := Transform3D.IDENTITY
	var n: Node = mi
	while n != root:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	if lay_flat:
		# face up, and thinner than the fly-FX coin so a stack at 0.07 spacing shows each coin's face
		xf = Transform3D(Basis.from_scale(Vector3(1, 0.5, 1)) * Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO) * xf
	var box := xf * mi.mesh.get_aabb()
	xf.origin += Vector3(-(box.position.x + box.size.x / 2.0), -box.position.y, -(box.position.z + box.size.z / 2.0))
	var out := {"mesh": mi.mesh, "xf": xf}
	root.free()
	_items[key] = out
	return out

static func steak_mesh() -> Mesh:
	return _item(STEAK_SCENE, false).mesh

static func steak_xf() -> Transform3D:
	return _item(STEAK_SCENE, false).xf

static func coin_mesh() -> Mesh:
	return _item(COIN_SCENE, true).mesh

static func coin_flat_xf() -> Transform3D:
	return _item(COIN_SCENE, true).xf

static func steak_pile(slots: PackedVector3Array) -> MultiMeshInstance3D:
	return make(steak_mesh(), slots, steak_xf())

static func coin_pile(slots: PackedVector3Array) -> MultiMeshInstance3D:
	return make(coin_mesh(), slots, coin_flat_xf())
