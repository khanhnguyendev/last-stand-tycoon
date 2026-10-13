class_name PipBatch
extends MultiMeshInstance3D
## E6 phase A (D-298.2, visual only): every level pip of the scene in ONE draw call. One MultiMesh of the shared star mesh and material; one instance per LevelPip
## handle, at the handle's global transform (the star is not a billboard: its pitch is the handle's rotation). A hidden or covered pip is an instance with zero
## scale (never rasterised); a removed pip's slot is filled by the last one, so `visible_instance_count` always equals the number of handles.
## The first handle creates the batch lazily, at the origin, under the node ABOVE its spots' parent (Main, when the spots live in the World): the tests pin the
## World's children (names and counts), and the batch is not a part of the world's layout. A spot whose parent is the scene root gets it beside the spot.

const NODE_NAME := &"LevelPipsBatch"
const META := &"level_pips_batch"
const MIN_CAPACITY := 32
## Pips are tiny and spread over the whole map: culling is per draw, so the box covers the playfield with a margin.
const CULL_BOX := AABB(Vector3(-100, -10, -100), Vector3(200, 40, 200))

var _handles: Array[LevelPip] = []
var _slots := {}  # LevelPip -> slot
var _xforms: Array[Transform3D] = []  # what each slot holds (a copy: the headless renderer keeps no multimesh buffer, so tests read this)

## The batch for a handle: found (or made) under the node above its spot's parent. null when the spot has no parent (nothing to draw into).
static func for_node(handle: Node) -> PipBatch:
	var spot := handle.get_parent()
	var host: Node = spot.get_parent() if spot != null else null
	if host == null:
		return null
	if host.get_parent() != null:
		host = host.get_parent()
	if host.has_meta(META):
		var found = host.get_meta(META)
		if is_instance_valid(found):
			return found
	var made := PipBatch.new()
	host.set_meta(META, made)  # found again at once, before it is in the tree
	host.add_child.call_deferred(made)  # the host is often still busy setting up its children (the world is built inside Main's own setup)
	return made

func _init() -> void:
	name = NODE_NAME
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = LevelStar.mesh()
	material_override = LevelStar.material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = CULL_BOX
	multimesh.instance_count = MIN_CAPACITY
	multimesh.visible_instance_count = 0

## The number of instances drawn (the visible_instance_count the batch sets).
func instance_total() -> int:
	return _handles.size()

## The transform written to a handle's slot (batch-local; zero scale = hidden).
func transform_of(handle: LevelPip) -> Transform3D:
	return _xforms[_slots[handle]]

## The slot of a handle, -1 when it is not attached.
func slot_of(handle: LevelPip) -> int:
	return int(_slots.get(handle, -1))

func attach(handle: LevelPip) -> void:
	if _slots.has(handle):
		return
	if _handles.size() == multimesh.instance_count:
		multimesh.instance_count = _handles.size() * 2  # resets the buffer: every slot is written again below
		multimesh.visible_instance_count = _handles.size()
		for i in _handles.size():
			multimesh.set_instance_transform(i, _xforms[i])
	_slots[handle] = _handles.size()
	_handles.append(handle)
	_xforms.append(Transform3D())
	multimesh.visible_instance_count = _handles.size()
	_write(_handles.size() - 1)

func detach(handle: LevelPip) -> void:
	if not _slots.has(handle):
		return
	var slot: int = _slots[handle]
	var last := _handles.size() - 1
	if slot != last:
		var moved := _handles[last]
		_handles[slot] = moved
		_slots[moved] = slot
	_handles.pop_back()
	_xforms.pop_back()
	_slots.erase(handle)
	multimesh.visible_instance_count = _handles.size()
	if slot != last:
		_write(slot)

func refresh_slot(handle: LevelPip) -> void:
	if _slots.has(handle):
		_write(_slots[handle])

func _enter_tree() -> void:
	for i in _handles.size():  # the handles that attached before the batch was in the tree
		_write(i)

## A batch not in the tree yet sits at the origin (its host is Main, which has no transform).
func _write(slot: int) -> void:
	var h := _handles[slot]
	if not h.is_inside_tree():
		return
	var xf := h.global_transform if not is_inside_tree() else global_transform.affine_inverse() * h.global_transform
	if not h.is_visible_in_tree():
		xf.basis = Basis.from_scale(Vector3.ZERO)
	_xforms[slot] = xf
	multimesh.set_instance_transform(slot, xf)
