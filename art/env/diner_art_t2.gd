extends "res://art/env/diner_art.gd"
## Root script of art/env/diner_t2.tscn (E5 slice 2 Task 1): the tier-1 occluder boxes plus the chimney stack and the sign
## board the tier-2 diner adds (art/env/src/diner_t2_top.res, tools/make_diner_t2_roof_src.gd). Local space, ground at 0.
## All inside |x|, |z| <= 4.0. The roof cap is below 3.45 and inside the walls box.

func _init() -> void:
	occluder_boxes = occluder_boxes.duplicate()
	occluder_boxes.append(AABB(Vector3(-3.475, 3.0, -3.475), Vector3(0.95, 3.1, 0.95)))  # chimney stack and cap
	occluder_boxes.append(AABB(Vector3(-1.5, 3.0, -1.3), Vector3(3.0, 2.4, 0.4)))        # sign board and posts
