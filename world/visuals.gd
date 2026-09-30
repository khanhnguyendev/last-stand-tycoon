class_name Visuals
extends RefCounted
## Placeholder primitive meshes (D-016, D-075). Every actor keeps a child named "Visual" for S4.

const COLORS := {
	"hero": Color("3a7bd5"), "hat": Color("ffffff"), "boar": Color("d64545"), "traveler": Color("9a9a9a"),
	"diner": Color("e8d8b0"), "counter": Color("8b5a2b"), "freezer": Color("5fd3e0"), "steak": Color("7a3b1e"),
	"coin": Color("f2c230"), "tower": Color("8c8c8c"), "fence": Color("9b6b3a"), "telegraph": Color("e03030"),
	"ground": Color("6fa35a"), "lane": Color("b59a6a"), "road": Color("7d7d7d"), "sign": Color("ffffff"),
	"pip": Color("ffd24a"), "flash": Color("ffffff"), "diner_hp": Color("5ecf5e"),
}

static var _materials := {}

static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		_materials[key] = m
	return _materials[key]

static func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func box(size: Vector3, color: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(m, color)

static func capsule(radius: float, height: float, color: Color) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return _mesh(m, color)

static func cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	return _mesh(m, color)

static func cone(radius: float, height: float, color: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	return _mesh(m, color)

static func plane(size: Vector2, color: Color) -> MeshInstance3D:
	var m := PlaneMesh.new()
	m.size = size
	return _mesh(m, color)

static func visual_root() -> Node3D:
	var n := Node3D.new()
	n.name = "Visual"
	return n
