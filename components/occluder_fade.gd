class_name OccluderFade
extends Node
## D-151: fades the MeshInstance3Ds (and Label3Ds, S4) under its parent (the occluder's "Visual") while the occluder
## hides an actor from the camera. The boxes come from a node under the parent that exposes `occluder_boxes` (local-space
## AABBs, e.g. the diner's walls, chimney and board: any grown box hit fades); with none, the box is the merged AABB of
## every VisualInstance3D under the parent (S4, D-194). Aim points on the diner's own roof (the Archer) never fade it through the
## base boxes (D-164: he stands on them), but ARE tested against `roof_part_boxes` (D-276), the boxes of the parts that rise
## above the roof (the tier-3 storey and lanterns): when one stands between the camera and him the building fades.
## Visual only: runs in _process and never touches GameState.
## A mesh with a material_override gets a transparent duplicate of it as its override; a mesh without one gets
## transparent duplicates of its surface materials as surface overrides. At full opacity the originals are
## put back (the override, or null surface overrides), so nothing transparent is left behind.

## The merge of the occluder boxes (or of the parent's visuals when it provides none), plus any box passed to setup().
var bounds := AABB()
var _boxes: Array[AABB] = []
## World-space boxes of the parts above the roof, from any node under the parent that exposes `roof_part_boxes` (also in _boxes).
var _roof_boxes: Array[AABB] = []
var _extra := AABB()
var _camera_source: Callable
var _targets: Callable
## Offsets from a roof target's aim point (Guard.AIM_HEIGHT 1.0) to his feet + 0.3, the aim point and his head (Guard.BAR_Y 2.0).
const ROOF_BODY_OFFSETS := [-0.7, 0.0, 1.0]
var _alpha := 1.0
var _warned := false
## MeshInstance3D -> {"override": Material or null, "fade": BaseMaterial3D or null, "surfaces": {i: {"prior", "fade"}}}
var _meshes := {}
## Label3D -> {"a": modulate.a, "outline_a": outline_modulate.a} while faded.
var _labels := {}

func _ready() -> void:
	refresh_bounds()

## box: an extra world AABB merged into the bounds; a zero-size box is ignored (the art's own bounds are used).
## camera_source() -> Camera3D.
## targets() -> Array of world-space AIM points (each actor adds its own AIM_HEIGHT, e.g. Hero.AIM_HEIGHT).
func setup(box: AABB, camera_source: Callable, targets: Callable) -> void:
	_extra = box
	_camera_source = camera_source
	_targets = targets
	refresh_bounds()

## Recomputes the boxes and `bounds`: the parent's `occluder_boxes` (world space) when a node provides them, else the
## merged global AABB of every visible VisualInstance3D under the parent; plus the box from setup() when it has a size.
## Call after the art changes.
func refresh_bounds() -> void:
	_boxes = []
	_roof_boxes = []
	var parent := get_parent()
	if parent != null:
		for n in parent.find_children("*", "Node3D", true, false):
			if "occluder_boxes" in n:
				var xf := (n as Node3D).global_transform if (n as Node3D).is_inside_tree() else (n as Node3D).transform
				for b in n.get("occluder_boxes"):
					_boxes.append(xf * (b as AABB))
				if "roof_part_boxes" in n:
					for b in n.get("roof_part_boxes"):
						_roof_boxes.append(xf * (b as AABB))
		if _boxes.is_empty():
			var merged := AABB()
			var any := false
			for n in parent.find_children("*", "VisualInstance3D", true, false):
				var vi := n as VisualInstance3D
				var local := vi.get_aabb()
				if local.size == Vector3.ZERO or not vi.visible:
					continue
				var world := (vi.global_transform if vi.is_inside_tree() else vi.transform) * local
				merged = world if not any else merged.merge(world)
				any = true
			if any:
				_boxes.append(merged)
	if _extra.size != Vector3.ZERO:
		_boxes.append(_extra)
	bounds = AABB()
	for i in _boxes.size():
		bounds = _boxes[i] if i == 0 else bounds.merge(_boxes[i])
	if _alpha < 1.0:
		_forget_gone_nodes()
		_apply()  # art swapped while faded: the new meshes and labels take the current fade now

## The world-space boxes the fade tests (each grown by Balance.ui.occluder_grow).
func boxes() -> Array[AABB]:
	return _boxes

## True for a label under this fade's parent: it owns that label's alpha, so the HUD dimmer leaves it alone (S5 Task 9).
func owns_label(l: Node) -> bool:
	return get_parent().is_ancestor_of(l)

func is_faded() -> bool:
	return _alpha < 1.0

func current_alpha() -> float:
	return _alpha

func _process(delta: float) -> void:
	var ui := Balance.ui
	var target := ui.occluder_alpha if _any_occluded(ui.occluder_grow) else 1.0
	if _alpha == target:  # exact: move_toward lands on the target, and an approx test would strand a rise just under 1.0
		return
	var step := (1.0 - ui.occluder_alpha) / maxf(ui.occluder_fade_s, 1e-4) * delta
	_alpha = move_toward(_alpha, target, step)
	_apply()

func _any_occluded(grow: float) -> bool:
	if not _camera_source.is_valid() or not _targets.is_valid():
		return false
	var cam := _camera_source.call() as Camera3D
	if cam == null or not cam.is_inside_tree():
		return false
	var from := cam.global_position
	for p in _targets.call():
		if _on_own_roof(p as Vector3):
			# the Archer on the roof: only the parts above the roof can hide him (the walls and slab he stands on never do), and
			# the aim point stands for his body: a part that hides his feet or his head fades the building too
			for dy in ROOF_BODY_OFFSETS:
				for box in _roof_boxes:
					if box.intersects_segment(from, (p as Vector3) + Vector3(0, dy, 0)) != null:  # exact: a near miss does not fade
						return true
			continue
		for box in _boxes:
			if box.grow(grow).intersects_segment(from, p as Vector3) != null:
				return true
	return false

## An aim point above the diner's footprint at roof height or higher: the Archer on its perch (D-164).
func _on_own_roof(p: Vector3) -> bool:
	var origin := Vector3.ZERO
	var parent := get_parent() as Node3D
	if parent != null and parent.is_inside_tree():
		origin = parent.global_position
	return p.y >= MapLayout.DINER_HEIGHT and absf(p.x - origin.x) <= MapLayout.DINER_HALF and absf(p.z - origin.z) <= MapLayout.DINER_HALF

## Drops the meshes and labels that left the tree (an art swap) so nothing keeps a stale entry.
func _forget_gone_nodes() -> void:
	var parent := get_parent()
	for mi in _meshes.keys():
		if not is_instance_valid(mi) or parent == null or not parent.is_ancestor_of(mi):
			_meshes.erase(mi)
	for l in _labels.keys():
		if not is_instance_valid(l) or parent == null or not parent.is_ancestor_of(l):
			_labels.erase(l)

func _apply() -> void:
	if _alpha >= 1.0:
		_alpha = 1.0
		_restore()
		return
	var parent := get_parent()
	if parent == null:
		return
	for m in parent.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not _meshes.has(mi):
			_meshes[mi] = _make_entry(mi)
		var e: Dictionary = _meshes[mi]
		if e.fade != null:
			(e.fade as BaseMaterial3D).albedo_color.a = _alpha
		for i in e.surfaces:
			(e.surfaces[i].fade as BaseMaterial3D).albedo_color.a = _alpha
	for n in parent.find_children("*", "Label3D", true, false):
		var l := n as Label3D
		if not _labels.has(l):
			_labels[l] = {"a": l.modulate.a, "outline_a": l.outline_modulate.a}
		l.modulate.a = _labels[l].a * _alpha
		l.outline_modulate.a = _labels[l].outline_a * _alpha

## One faded copy of a material the diner uses, for the boot warm-up (D-215): drawing it once compiles the transparent
## pipeline before the first occlusion fade. Nothing is applied to the diner.
func fade_material_for_warmup() -> Material:
	var src := StandardMaterial3D.new()
	var parent := get_parent()
	if parent != null:
		for m in parent.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var base: BaseMaterial3D = mi.material_override as BaseMaterial3D
			if base == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
				base = (mi.get_surface_override_material(0) if mi.get_surface_override_material(0) != null else mi.mesh.surface_get_material(0)) as BaseMaterial3D
			if base != null:
				src = base
				break
	var f := _fade_copy(src)
	f.albedo_color.a = Balance.ui.occluder_alpha
	return f

func _fade_copy(src: BaseMaterial3D) -> BaseMaterial3D:
	var f := src.duplicate() as BaseMaterial3D
	f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return f

func _make_entry(mi: MeshInstance3D) -> Dictionary:
	var e := {"override": null, "fade": null, "surfaces": {}}
	if mi.material_override != null:
		if mi.material_override is BaseMaterial3D:
			e.override = mi.material_override
			e.fade = _fade_copy(e.override)
			mi.material_override = e.fade
	elif mi.mesh != null:
		for i in mi.mesh.get_surface_count():
			var prior := mi.get_surface_override_material(i)
			var base := (prior if prior != null else mi.mesh.surface_get_material(i)) as BaseMaterial3D
			if base == null:
				continue
			var f := _fade_copy(base)
			e.surfaces[i] = {"prior": prior, "fade": f}
			mi.set_surface_override_material(i, f)
	if e.fade == null and e.surfaces.is_empty() and not _warned:
		_warned = true
		push_warning("OccluderFade: %s has no BaseMaterial3D to fade; it stays opaque" % mi.get_path())
	return e

func _restore() -> void:
	for mi in _meshes:
		if not is_instance_valid(mi):
			continue
		var e: Dictionary = _meshes[mi]
		if e.fade != null:
			(mi as MeshInstance3D).material_override = e.override
		for i in e.surfaces:
			(mi as MeshInstance3D).set_surface_override_material(i, e.surfaces[i].prior)
	_meshes.clear()
	for l in _labels:
		if is_instance_valid(l):
			(l as Label3D).modulate.a = _labels[l].a
			(l as Label3D).outline_modulate.a = _labels[l].outline_a
	_labels.clear()
