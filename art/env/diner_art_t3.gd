extends "res://art/env/diner_art.gd"
## Root script of art/env/diner_t3.tscn (E5 tier-3 Task 19): the tier-1 occluder boxes plus ADDED_BOXES, everything tier 3 adds
## on top of tier 1 (art/env/src/diner_t3_top.res, tools/make_diner_t3_src.gd): the set-back second storey (walls and cornice,
## x -2.5..1.0, z -0.5..3.0, y 3.03..5.2) and one box per lantern. The wood roof cap (below 3.45) lies inside the walls box.
## Tier 2's chimney and sign board are gone: they would stand inside the storey. Local space, ground at 0; everything is inside
## |x|, |z| <= 3.0, so the storey is set back 1 m from the 4.0 footprint.
## roof_part_boxes: the parts that rise above the roof. OccluderFade tests an actor standing on the roof (the Archer) against
## these only, so a storey between the camera and him fades the diner (D-276), while the walls and slab he stands on never do.
const ADDED_BOXES: Array[AABB] = [
	AABB(Vector3(-2.5, 3.03, -0.5), Vector3(3.5, 2.17, 3.5)),       # storey: walls + cornice, top 5.2
	AABB(Vector3(0.66, 5.2, 2.66), Vector3(0.34, 0.88, 0.34)),      # south-east lamp, top 6.08
	AABB(Vector3(-2.5, 5.2, 2.66), Vector3(0.34, 0.47, 0.34)),      # south-west lantern, top 5.67
	AABB(Vector3(-2.62, 4.5, -0.62), Vector3(0.24, 0.45, 0.24)),    # north-west wall lantern
	AABB(Vector3(0.88, 4.5, -0.62), Vector3(0.24, 0.45, 0.24)),     # north-east wall lantern
]
var roof_part_boxes: Array[AABB] = []

func _init() -> void:
	occluder_boxes = occluder_boxes.duplicate()
	occluder_boxes.append_array(ADDED_BOXES)
	roof_part_boxes = ADDED_BOXES.duplicate()
