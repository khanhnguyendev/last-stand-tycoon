class_name ProgressRing
extends MeshInstance3D
## Shared stand-still progress ring (D-073). Flat on the ground; visual only.

const SHADER := preload("res://ui/progress_ring/progress_ring.gdshader")

func _init() -> void:
	var m := PlaneMesh.new()
	m.size = Vector2(2.4, 2.4)
	mesh = m
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material_override = mat
	position.y = 0.03
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## The last value given to set_progress (0..1), readable for tests.
var progress := 0.0

func set_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	(material_override as ShaderMaterial).set_shader_parameter("progress", clampf(p, 0.0, 1.0))
