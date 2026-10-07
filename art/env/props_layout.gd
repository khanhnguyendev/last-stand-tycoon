class_name PropsLayout
extends RefCounted
## The hand-placed environment props (S4 Task 13, D-194, D-201): trees and rocks in a ring outside the play bounds, plus a
## few near the diner. Fixed data (no Rng): {model: baked mesh, pos: Vector2 (x, z), rot: yaw radians, scale: float}.
## `near_diner` items stand inside the play bounds, clear of every lane, station and footprint. All props are visual
## only: no collision (test_props_layout).

const B := "res://art/env/baked/"

const ITEMS: Array[Dictionary] = [
	{"model": B + "prop_tree_small.res", "pos": Vector2(-41.6, -35.5), "rot": 3.68, "scale": 1.7},
	{"model": B + "prop_td_tree_large.res", "pos": Vector2(-36.8, -37.9), "rot": 5.79, "scale": 3.37},
	{"model": B + "prop_td_tree.res", "pos": Vector2(-32.1, -40.7), "rot": 5.73, "scale": 3.64},
	{"model": B + "prop_tree_large.res", "pos": Vector2(-28.4, -37.6), "rot": 4.39, "scale": 1.74},
	{"model": B + "prop_td_tree_large.res", "pos": Vector2(-25.5, -31.2), "rot": 4.17, "scale": 4.0},
	{"model": B + "prop_rocks_small.res", "pos": Vector2(-20.7, -36.6), "rot": 5.0, "scale": 2.11},
	{"model": B + "prop_rocks_large.res", "pos": Vector2(-16.2, -29.4), "rot": 1.66, "scale": 1.56},
	{"model": B + "prop_td_tree.res", "pos": Vector2(-13.9, -35.6), "rot": 3.63, "scale": 3.56},
	{"model": B + "prop_td_tree.res", "pos": Vector2(-8.7, -33.6), "rot": 4.24, "scale": 4.33},
	{"model": B + "prop_rocks_large.res", "pos": Vector2(-5.1, -39.4), "rot": 5.76, "scale": 2.04},
	{"model": B + "prop_td_tree.res", "pos": Vector2(-0.6, -31.3), "rot": 2.71, "scale": 4.53},
	{"model": B + "prop_td_tree.res", "pos": Vector2(4.3, -31.6), "rot": 4.06, "scale": 4.6},
	{"model": B + "prop_td_tree.res", "pos": Vector2(7.5, -28.4), "rot": 3.32, "scale": 4.51},
	{"model": B + "prop_td_tree_large.res", "pos": Vector2(11.3, -36.1), "rot": 2.86, "scale": 4.08},
	{"model": B + "prop_td_tree_large.res", "pos": Vector2(17.7, -36.2), "rot": 4.58, "scale": 3.42},
	{"model": B + "prop_tree_small.res", "pos": Vector2(21.2, -34.9), "rot": 0.42, "scale": 1.68},
	{"model": B + "prop_td_rocks.res", "pos": Vector2(23.9, -41.3), "rot": 1.2, "scale": 4.43},
	{"model": B + "prop_td_tree.res", "pos": Vector2(30.4, -30.0), "rot": 2.68, "scale": 4.29},
	{"model": B + "prop_rocks_large.res", "pos": Vector2(34.7, -29.1), "rot": 4.65, "scale": 1.52},
	{"model": B + "prop_tree_large.res", "pos": Vector2(38.2, -38.4), "rot": 2.21, "scale": 1.97},
	{"model": B + "prop_tree_small.res", "pos": Vector2(-37.8, -29.7), "rot": 3.04, "scale": 1.97},
	{"model": B + "prop_td_tree_large.res", "pos": Vector2(-29.4, -25.3), "rot": 5.29, "scale": 3.47},
	{"model": B + "prop_td_tree.res", "pos": Vector2(-38.4, -21.8), "rot": 2.62, "scale": 3.71},
	{"model": B + "prop_tree_small.res", "pos": Vector2(-37.5, -16.5), "rot": 0.19, "scale": 1.96},
	{"model": B + "prop_rocks_small.res", "pos": Vector2(-31.6, -11.4), "rot": 3.43, "scale": 2.58},
	{"model": B + "prop_tree_small.res", "pos": Vector2(-30.4, -6.2), "rot": 2.76, "scale": 1.83},
	{"model": B + "prop_td_rocks.res", "pos": Vector2(-29.2, -2.3), "rot": 4.79, "scale": 3.36},
	{"model": B + "prop_td_tree_large.res", "pos": Vector2(-28.3, 2.8), "rot": 2.15, "scale": 4.01},
	{"model": B + "prop_td_tree.res", "pos": Vector2(-34.9, 5.7), "rot": 2.44, "scale": 3.68},
	{"model": B + "prop_rocks_large.res", "pos": Vector2(-34.6, 16.0), "rot": 4.02, "scale": 1.49},
	{"model": B + "prop_td_tree_large.res", "pos": Vector2(-27.8, 14.7), "rot": 1.33, "scale": 3.64},
	{"model": B + "prop_tree_large.res", "pos": Vector2(35.7, -28.7), "rot": 5.38, "scale": 2.17},
	{"model": B + "prop_td_tree.res", "pos": Vector2(35.9, -25.4), "rot": 4.03, "scale": 4.15},
	{"model": B + "prop_rocks_small.res", "pos": Vector2(29.2, -22.4), "rot": 5.75, "scale": 2.45},
	{"model": B + "prop_td_tree_large.res", "pos": Vector2(41.0, -16.0), "rot": 0.13, "scale": 3.95},
	{"model": B + "prop_td_tree.res", "pos": Vector2(38.3, -12.8), "rot": 4.46, "scale": 4.54},
	{"model": B + "prop_td_tree.res", "pos": Vector2(39.1, -7.4), "rot": 4.72, "scale": 3.53},
	{"model": B + "prop_tree_large.res", "pos": Vector2(38.9, -2.9), "rot": 1.07, "scale": 2.0},
	{"model": B + "prop_td_rocks.res", "pos": Vector2(36.5, 3.0), "rot": 0.99, "scale": 3.3},
	{"model": B + "prop_td_rocks.res", "pos": Vector2(35.3, 5.1), "rot": 3.63, "scale": 3.37},
	{"model": B + "prop_tree_small.res", "pos": Vector2(27.9, 16.2), "rot": 4.95, "scale": 1.8},
	{"model": B + "prop_tree_small.res", "pos": Vector2(34.1, 15.6), "rot": 0.46, "scale": 2.11},
	{"model": B + "prop_td_tree.res", "pos": Vector2(-39.5, 21.7), "rot": 0.17, "scale": 4.72},
	{"model": B + "prop_tree_large.res", "pos": Vector2(-33.7, 29.4), "rot": 3.46, "scale": 1.58},
	{"model": B + "prop_tree_small.res", "pos": Vector2(-28.1, 22.2), "rot": 3.53, "scale": 1.77},
	{"model": B + "prop_td_rocks.res", "pos": Vector2(-22.3, 17.1), "rot": 1.88, "scale": 3.56},
	{"model": B + "prop_td_tree_large.res", "pos": Vector2(-16.3, 21.2), "rot": 0.36, "scale": 3.91},
	{"model": B + "prop_td_tree_large.res", "pos": Vector2(-12.8, 26.9), "rot": 3.91, "scale": 3.48},
	{"model": B + "prop_td_tree.res", "pos": Vector2(-6.7, 23.5), "rot": 1.15, "scale": 3.6},
	{"model": B + "prop_td_tree.res", "pos": Vector2(-0.9, 29.6), "rot": 4.93, "scale": 3.71},
	{"model": B + "prop_tree_large.res", "pos": Vector2(4.9, 24.8), "rot": 1.4, "scale": 1.63},
	{"model": B + "prop_td_tree.res", "pos": Vector2(10.0, 29.5), "rot": 4.75, "scale": 3.64},
	{"model": B + "prop_tree_large.res", "pos": Vector2(18.4, 21.2), "rot": 4.46, "scale": 1.84},
	{"model": B + "prop_td_tree_large.res", "pos": Vector2(23.8, 21.2), "rot": 3.67, "scale": 3.4},
	{"model": B + "prop_td_tree.res", "pos": Vector2(29.2, 18.3), "rot": 4.38, "scale": 3.58},
	{"model": B + "prop_tree_large.res", "pos": Vector2(34.9, 22.2), "rot": 2.51, "scale": 2.19},
	{"model": B + "prop_tree_large.res", "pos": Vector2(-10.5, -2.5), "rot": 0.26, "scale": 1.93, "near_diner": true},
	{"model": B + "prop_tree_large.res", "pos": Vector2(10.5, -1.5), "rot": 2.73, "scale": 1.82, "near_diner": true},
	{"model": B + "prop_rocks_large.res", "pos": Vector2(-9.5, 3.5), "rot": 6.23, "scale": 1.88, "near_diner": true},
	{"model": B + "prop_td_tree.res", "pos": Vector2(10, 4), "rot": 3.86, "scale": 4.23, "near_diner": true},
	{"model": B + "prop_tree_small.res", "pos": Vector2(-14, 8), "rot": 6.01, "scale": 1.65, "near_diner": true},
	{"model": B + "prop_rocks_small.res", "pos": Vector2(13, 7.5), "rot": 6.17, "scale": 2.47, "near_diner": true},
]

## The distinct model paths, in first-appearance order (one MultiMeshInstance3D each).
static func models() -> Array[String]:
	var out: Array[String] = []
	for it in ITEMS:
		if not out.has(it.model):
			out.append(it.model)
	return out

## The items that use `model`.
static func items_of(model: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in ITEMS:
		if it.model == model:
			out.append(it)
	return out

## E5 tier 3 Task 2 (spec 5): small props on owned land, keyed by yard id (MapLayout.YARDS). A later tier adds its plot
## key here. {kind: "crate" | "barrel" | "bench", pos: Vector2 (x, z), rot: yaw radians, scale: float}. Procedural
## (palette vertex colours, Props.owned_arrays), no collision, never inside a lane, zone, pad, sign or station
## (test_yards.test_owned_props_keep_clear checks every entry against MapLayout per tier).
const OWNED := {
	"west": [
		{"kind": "bench", "pos": Vector2(-12.6, -1.0), "rot": 1.5708, "scale": 1.0},
		{"kind": "barrel", "pos": Vector2(-12.7, 2.9), "rot": 0.0, "scale": 1.0},
		{"kind": "crate", "pos": Vector2(-12.6, 4.5), "rot": 0.3, "scale": 1.0},
		{"kind": "crate", "pos": Vector2(-12.0, 5.3), "rot": 1.1, "scale": 0.8},
		{"kind": "barrel", "pos": Vector2(-12.6, 6.4), "rot": 0.0, "scale": 1.0},
	],
	"east": [
		{"kind": "crate", "pos": Vector2(12.3, 2.4), "rot": 0.4, "scale": 1.0},
		{"kind": "crate", "pos": Vector2(11.5, 2.6), "rot": 1.2, "scale": 0.8},
		{"kind": "barrel", "pos": Vector2(12.4, 0.3), "rot": 0.0, "scale": 1.0},
		{"kind": "bench", "pos": Vector2(11.0, 0.2), "rot": 0.0, "scale": 1.0},
	],
}

## The owned-land items of the yards in `ids` (MapLayout.YARDS keys), in yard order.
static func owned_for(ids: Array) -> Array:
	var out := []
	for id in MapLayout.YARDS:
		if id in ids and OWNED.has(id):
			out.append_array(OWNED[id])
	return out
