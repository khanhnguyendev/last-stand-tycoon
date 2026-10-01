class_name PickupField
extends MultiMeshInstance3D
## One draw for every ground pickup (D-201): a MultiMesh with one slot per pooled pickup. A free slot is a zero-scale
## transform. Slots are kept in `_xf`, so growing the pool keeps them (changing instance_count resets the buffer).
## Visual only (spec 7).

const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
var _xf: Array[Transform3D] = []

## The transform written for a pickup lying at `pos`, turned by `yaw`; `item_xf` is the model's own placement.
## `scale` is applied on top of `item_xf` (its centring offset scales with it, so the item still sits on `pos`).
static func slot_transform(pos: Vector3, yaw: float, item_xf: Transform3D, scale := 1.0) -> Transform3D:
	var turn := Basis(Vector3.UP, yaw)
	return Transform3D(turn * Basis.from_scale(Vector3.ONE * scale) * item_xf.basis, pos + turn * (item_xf.origin * scale))

func setup(mesh: Mesh, capacity: int) -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_xf.clear()
	_resize(capacity)

func capacity() -> int:
	return _xf.size()

func slot_xf(i: int) -> Transform3D:
	return _xf[i]

func is_slot_clear(i: int) -> bool:
	return _xf[i].basis.get_scale() == Vector3.ZERO

func set_slot(i: int, xf: Transform3D) -> void:
	_xf[i] = xf
	multimesh.set_instance_transform(i, xf)

func clear_slot(i: int) -> void:
	set_slot(i, HIDDEN)

## Make room for at least n slots; existing slots keep their transforms.
func grow(n: int) -> void:
	if n > _xf.size():
		_resize(n)

func _resize(n: int) -> void:
	var old := _xf.duplicate()
	multimesh.instance_count = 0
	multimesh.instance_count = n
	multimesh.visible_instance_count = -1
	_xf.clear()
	for i in n:
		_xf.append(old[i] if i < old.size() else HIDDEN)
		multimesh.set_instance_transform(i, _xf[i])
