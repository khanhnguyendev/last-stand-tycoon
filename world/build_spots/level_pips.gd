class_name LevelPips
extends RefCounted
## The row of level stars above a build spot or an upgrade pad (Pillar 1: growth reads). Each star is a LevelPip handle; the scene's PipBatch draws them all in one call.

const SPACING := 0.3

## `batch`: the world's PipBatch. Null (no world): a private one, a child of `parent`, freed with it.
static func make(parent: Node3D, count: int, y: float, batch: PipBatch = null) -> Array:
	if batch == null:
		batch = PipBatch.new()
		parent.add_child(batch)
	var pips: Array = []
	for i in count:
		var pip := LevelPip.new()
		pip.name = "Pip%d" % i
		pip.use_batch(batch)
		pip.add_to_group(&"level_pips")  # the lane badge's cover rule reads them (visual only)
		pip.rotation.x = deg_to_rad(Balance.ui.camera_pitch)  # the star faces the camera
		pip.position = Vector3((i - (count - 1) * 0.5) * SPACING, y, 0)
		parent.add_child(pip)
		pips.append(pip)
	return pips

## `covered`: the row hides whatever the level (see set_covered).
static func show_level(pips: Array, level: int, y: float, covered := false) -> void:
	for i in pips.size():
		pips[i].visible = i < level and not covered
		if not is_equal_approx(pips[i].position.y, y):  # a write is a notification and a buffer upload: only when it moves
			pips[i].position.y = y

## E6 (visual only; no game state): the row of a building hides while one of its own branch pads shows a cost (author's decision, task 14 round 7) and
## returns when the cost hides. `level` is the number of stars the building shows when uncovered.
static func set_covered(pips: Array, on: bool, level: int) -> void:
	for i in pips.size():
		pips[i].visible = i < level and not on
