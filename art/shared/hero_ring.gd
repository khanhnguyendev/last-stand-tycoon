extends MeshInstance3D
## The hero's ground ring (S4 spec 7): palette warm_white, alpha Balance.ui.hero_ring_alpha, unshaded. A child of Hero
## beside Visual, so it never turns or scales with the art.

func _ready() -> void:
	var m := material_override as StandardMaterial3D
	m.albedo_color = Color(Palette.color(&"warm_white"), Balance.ui.hero_ring_alpha)
