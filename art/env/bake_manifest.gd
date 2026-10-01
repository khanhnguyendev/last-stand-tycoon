extends RefCounted
## Static environment bakes run by `bake_static.gd --all` (S4 Tasks 11-13, D-201). Each entry: {in: scene, out: mesh}.

const ENTRIES := [
	{"in": "res://art/env/src/diner_src.tscn", "out": "res://art/env/baked/diner.res"},
	{"in": "res://art/env/src/counter_src.tscn", "out": "res://art/env/baked/counter.res"},
	{"in": "res://art/env/src/freezer_src.tscn", "out": "res://art/env/baked/freezer.res"},
]
