class_name PointerMesh
extends MeshInstance3D
## The Guide's world pointer (S5 Task 10): one small down-pointing arrow solid (shaft and head, lathed), unshaded gold,
## tip at the node's origin. One mesh, one surface, one draw call. It ignores depth so a wall never hides it.

const SEGMENTS := 12
## Profile (radius, height above the tip), tip first.
const PROFILE := [Vector2(0.0, 0.0), Vector2(0.42, 0.62), Vector2(0.16, 0.62), Vector2(0.16, 1.15), Vector2(0.0, 1.15)]

static func build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var a0 := TAU * float(i) / float(SEGMENTS)
		var a1 := TAU * float(i + 1) / float(SEGMENTS)
		for j in PROFILE.size() - 1:
			var p: Vector2 = PROFILE[j]
			var q: Vector2 = PROFILE[j + 1]
			var v00 := Vector3(cos(a0) * p.x, p.y, sin(a0) * p.x)
			var v10 := Vector3(cos(a1) * p.x, p.y, sin(a1) * p.x)
			var v01 := Vector3(cos(a0) * q.x, q.y, sin(a0) * q.x)
			var v11 := Vector3(cos(a1) * q.x, q.y, sin(a1) * q.x)
			if p.x > 0.0:
				_tri(st, v00, v10, v11)
			if q.x > 0.0:
				_tri(st, v00, v11, v01)
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func _ready() -> void:
	mesh = build()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.albedo_color = Palette.color(&"gold")
	material_override = m
