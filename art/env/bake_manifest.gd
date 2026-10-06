extends RefCounted
## Static environment bakes run by `bake_static.gd --all` (S4 Tasks 11-13, D-201). Each entry: {in: scene, out: mesh}.

const ENTRIES := [
	{"in": "res://art/env/src/diner_src.tscn", "out": "res://art/env/baked/diner.res"},
	# E5 Task 11: the tier-2 diner (flank terraces, corner awnings).
	{"in": "res://art/env/src/diner_t2_src.tscn", "out": "res://art/env/baked/diner_t2.res"},
	{"in": "res://art/env/src/counter_src.tscn", "out": "res://art/env/baked/counter.res"},
	{"in": "res://art/env/src/freezer_src.tscn", "out": "res://art/env/baked/freezer.res"},
	# Task 12: towers, fences, rubble, spot marker, close-up sign, telegraph flag, lane gate.
	{"in": "res://art/env/src/tower_l1_src.tscn", "out": "res://art/env/baked/tower_l1.res"},
	{"in": "res://art/env/src/tower_l2_src.tscn", "out": "res://art/env/baked/tower_l2.res"},
	{"in": "res://art/env/src/tower_l3_src.tscn", "out": "res://art/env/baked/tower_l3.res"},
	{"in": "res://art/env/src/fence_l1_src.tscn", "out": "res://art/env/baked/fence_l1.res"},
	{"in": "res://art/env/src/fence_l2_src.tscn", "out": "res://art/env/baked/fence_l2.res"},
	{"in": "res://art/env/src/fence_l3_src.tscn", "out": "res://art/env/baked/fence_l3.res"},
	{"in": "res://art/env/src/fence_rubble_src.tscn", "out": "res://art/env/baked/fence_rubble.res"},
	{"in": "res://art/env/src/spot_marker_src.tscn", "out": "res://art/env/baked/spot_marker.res"},
	{"in": "res://art/env/src/closeup_sign_src.tscn", "out": "res://art/env/baked/closeup_sign.res"},
	{"in": "res://art/env/src/telegraph_flag_src.tscn", "out": "res://art/env/baked/telegraph_flag.res"},
	{"in": "res://art/env/src/lane_gate_src.tscn", "out": "res://art/env/baked/lane_gate.res"},
	# Task 13: prop models (one MultiMesh each), the rocks-small one also lines the lane edges.
	{"in": "res://art/env/src/prop_tree_large_src.tscn", "out": "res://art/env/baked/prop_tree_large.res"},
	{"in": "res://art/env/src/prop_tree_small_src.tscn", "out": "res://art/env/baked/prop_tree_small.res"},
	{"in": "res://art/env/src/prop_rocks_large_src.tscn", "out": "res://art/env/baked/prop_rocks_large.res"},
	{"in": "res://art/env/src/prop_rocks_small_src.tscn", "out": "res://art/env/baked/prop_rocks_small.res"},
	{"in": "res://art/env/src/prop_td_tree_src.tscn", "out": "res://art/env/baked/prop_td_tree.res"},
	{"in": "res://art/env/src/prop_td_tree_large_src.tscn", "out": "res://art/env/baked/prop_td_tree_large.res"},
	{"in": "res://art/env/src/prop_td_rocks_src.tscn", "out": "res://art/env/baked/prop_td_rocks.res"},
]
