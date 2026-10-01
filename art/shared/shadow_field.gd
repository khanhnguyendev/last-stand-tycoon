class_name ShadowField
extends MultiMeshInstance3D
## One draw call for every blob shadow (S4 Task 8b, D-201). Actors register a Node3D (their Visual, so the poof's scale
## tween and visibility carry over) with a radius; each frame this writes one instance per registered node that is
## visible in the tree: at the node's XZ, 0.04 above its y, a plane 2 * radius wide (times the node's scale).
## Registration is by the actor: hero and guards in setup(), travelers in begin(), and a pooled actor unregisters on
## release. A node that leaves the tree unregisters itself. Visual-only: reads transforms, writes nothing else.

## The blob under a character (the old per-visual Shadow was a 1 m plane).
const CHARACTER_RADIUS := 0.5
const LIFT := 0.04
const START_CAPACITY := 64
const BLOB := preload("res://art/shared/blob_shadow.png")

var _nodes: Array[Node3D] = []
var _radii: Array[float] = []
## What the last _process wrote, in instance order (read by tests; the MultiMesh buffer is write-only when headless).
var _written: Array[Transform3D] = []

func _init() -> void:
	name = "ShadowField"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = BLOB
	mat.render_priority = -1  # shadows draw first among the transparent surfaces
	plane.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = plane
	mm.instance_count = START_CAPACITY
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-400, -10, -400), Vector3(800, 40, 800))
	multimesh = mm

func register(n: Node3D, radius: float) -> void:
	var i := _nodes.find(n)
	if i >= 0:
		_radii[i] = radius
		return
	_nodes.append(n)
	_radii.append(radius)
	n.tree_exiting.connect(unregister.bind(n))

func unregister(n: Node3D) -> void:
	var i := _nodes.find(n)
	if i < 0:
		return
	_nodes.remove_at(i)
	_radii.remove_at(i)
	if n.tree_exiting.is_connected(unregister.bind(n)):
		n.tree_exiting.disconnect(unregister.bind(n))

func registered_count() -> int:
	return _nodes.size()

## Instances drawn by the last _process.
func shown_count() -> int:
	return _written.size()

func _process(_delta: float) -> void:
	_written.clear()
	for i in _nodes.size():
		var n := _nodes[i]
		if not is_instance_valid(n) or not n.is_inside_tree() or not n.is_visible_in_tree():
			continue
		var g := n.global_transform
		var s := 2.0 * _radii[i] * g.basis.get_scale().x
		_written.append(Transform3D(Basis.from_scale(Vector3(s, 1.0, s)), Vector3(g.origin.x, g.origin.y + LIFT, g.origin.z)))
	if _written.size() > multimesh.instance_count:
		multimesh.instance_count = maxi(_written.size(), multimesh.instance_count * 2)
	multimesh.visible_instance_count = _written.size()
	for i in _written.size():
		multimesh.set_instance_transform(i, _written[i])
