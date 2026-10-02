class_name FixtureBox
extends RefCounted
## Test-only coloured boxes (moved out of world/visuals.gd in S4 Task 13).

const COLORS := {"diner": Color("e8d8b0")}

static var _materials := {}

static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		_materials[key] = m
	return _materials[key]

static func box(size: Vector3, color: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
