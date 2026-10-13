class_name PipBatch
extends MultiMeshInstance3D
## E6 phase A (D-298.2, visual only): every level pip of the scene in ONE draw call. One MultiMesh of the shared star mesh and material; one instance per LevelPip
## handle, at the handle's global transform (the star is not a billboard: its pitch is the handle's rotation). A hidden or covered pip is an instance with zero
## scale (never rasterised); a removed pip's slot is filled by the last one, so `visible_instance_count` always equals the number of handles.
## The WORLD owns the one batch (`World.pip_batch`, made in its _ready before the spots) and hands it down spot -> LevelPips.make -> each LevelPip. A LevelPips built
## without a world (an isolated unit test) makes a private batch as a child of its parent, which frees it with the parent.

const NODE_NAME := &"LevelPipsBatch"
## The tiers hold 25 / 31 / 37 handles: the buffer is never reallocated by a tier change.
const MIN_CAPACITY := 64
## Pips are tiny and spread over the whole map: culling is per draw, so the box covers the playfield with a margin.
const CULL_BOX := AABB(Vector3(-100, -10, -100), Vector3(200, 40, 200))

var _handles: Array[LevelPip] = []
var _slots := {}  # LevelPip -> slot
var _xforms: Array[Transform3D] = []  # what each slot holds (a copy: the headless renderer keeps no multimesh buffer, so tests read this)

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
