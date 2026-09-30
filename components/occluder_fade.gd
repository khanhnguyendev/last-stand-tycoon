class_name OccluderFade
extends Node
## D-151: fades the MeshInstance3Ds under its parent (the occluder's "Visual") while the occluder hides an
## actor from the camera. Generic: knows only a world AABB, a camera source and a list of aim points.
## Visual only: runs in _process and never touches GameState.
## A mesh with a material_override gets a transparent duplicate of it as its override; a mesh without one gets
## transparent duplicates of its surface materials as surface overrides. At full opacity the originals are
## put back (the override, or null surface overrides), so nothing transparent is left behind.

var _box := AABB()
var _camera_source: Callable
var _targets: Callable
var _alpha := 1.0
var _warned := false
## MeshInstance3D -> {"override": Material or null, "fade": BaseMaterial3D or null, "surfaces": {i: {"prior", "fade"}}}
var _meshes := {}

## box: the occluder's world AABB. camera_source() -> Camera3D.
## targets() -> Array of world-space AIM points (each actor adds its own AIM_HEIGHT, e.g. Hero.AIM_HEIGHT).
func setup(box: AABB, camera_source: Callable, targets: Callable) -> void:
	_box = box
	_camera_source = camera_source
	_targets = targets

func is_faded() -> bool:
	return _alpha < 1.0

func current_alpha() -> float:
	return _alpha

func _process(delta: float) -> void:
	var ui := Balance.ui
	var target := ui.occluder_alpha if _any_occluded(ui.occluder_grow) else 1.0
	if is_equal_approx(_alpha, target):
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
	var grown := _box.grow(grow)
	for p in _targets.call():
		if grown.intersects_segment(from, p as Vector3) != null:
			return true
	return false

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
