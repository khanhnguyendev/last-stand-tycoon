extends "res://art/env/diner_art.gd"
## Root script of art/env/diner_t2.tscn (E5 slice 2 Task 1): the tier-1 occluder boxes plus ADDED_BOXES, the chimney
## and the sign board the tier-2 diner adds (art/env/src/diner_t2_top.res, tools/make_diner_t2_roof_src.gd). Local space,
## ground at 0. All inside |x|, |z| <= 4.0; the roof cap is below 3.45 and inside the walls box. Each box is the real
## extent of its part (the chimney's cap, the board's plate plus face: z 1.7 to 1.94).
const ADDED_BOXES: Array[AABB] = [
	AABB(Vector3(-1.475, 3.0, -0.475), Vector3(0.95, 1.6, 0.95)),  # chimney: x -1.475..-0.525, z -0.475..0.475, top 4.6
	AABB(Vector3(-1.5, 3.0, 1.7), Vector3(3.0, 1.5, 0.24)),        # sign board: x -1.5..1.5, z 1.7..1.94, top 4.5
]

func _init() -> void:
	occluder_boxes = occluder_boxes.duplicate()
	occluder_boxes.append_array(ADDED_BOXES)
