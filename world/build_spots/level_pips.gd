class_name LevelPips
extends RefCounted
## The row of level stars above a build spot or an upgrade pad (Pillar 1: growth reads).

const SPACING := 0.3

static func make(parent: Node3D, count: int, y: float) -> Array:
	var pips: Array = []
	for i in count:
		var pip := MeshInstance3D.new()
		pip.name = "Pip%d" % i
		pip.mesh = LevelStar.mesh()
		pip.material_override = LevelStar.material()
		pip.rotation.x = deg_to_rad(Balance.ui.camera_pitch)  # the star faces the camera
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pip.position = Vector3((i - (count - 1) * 0.5) * SPACING, y, 0)
		parent.add_child(pip)
		pips.append(pip)
	return pips

static func show_level(pips: Array, level: int, y: float) -> void:
	for i in pips.size():
		pips[i].visible = i < level
		pips[i].position.y = y
