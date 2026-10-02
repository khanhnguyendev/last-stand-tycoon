class_name Props
extends Node3D
## The hand-placed props (S4 Task 13, D-201): one MultiMeshInstance3D per baked model (PropsLayout), no collision.
## Visual only: no Rng, no gameplay state.

func _ready() -> void:
	build()

## Builds the MultiMeshInstance3D children once (idempotent).
func build() -> void:
	if get_child_count() > 0:
		return
	for model in PropsLayout.models():
		var items := PropsLayout.items_of(model)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = load(model) as Mesh
		mm.instance_count = items.size()
		for i in items.size():
			var it: Dictionary = items[i]
			var p: Vector2 = it.pos
			var basis := Basis(Vector3.UP, float(it.rot)).scaled(Vector3.ONE * float(it.scale))
			mm.set_instance_transform(i, Transform3D(basis, MapLayout.to3(p)))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Prop_" + model.get_file().get_basename()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
