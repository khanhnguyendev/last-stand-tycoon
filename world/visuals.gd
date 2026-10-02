class_name Visuals
extends RefCounted
## What is left of the S1 placeholder helpers (D-016, D-075), after S4 Task 13 replaced every placeholder primitive:
## `visual_root()` (every actor keeps a child named "Visual", D-190) and a coloured box for test fixtures only
## (test_occluder_fade). The asset validator bans `Visuals.box(` and friends in game code (PLACEHOLDERS_ARE_ERRORS).

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

static func visual_root() -> Node3D:
	var n := Node3D.new()
	n.name = "Visual"
	return n
