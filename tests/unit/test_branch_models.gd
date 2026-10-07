extends GutTest
## E5 tier 3 Task 18 (spec 7, D-264): the four branch models (Longbow, Volley, Stone wall, Spike fence) are chosen by the spot, differ by
## SILHOUETTE (literal thresholds below, read off the baked meshes), stay in the triangle budgets, are not colliders and not part of the
## diner's fade set, and the tall Longbow hides none of the ground the player needs (camera check through CameraMath).

const ENV := "res://art/env/"
const TOWER_BRANCHES := {&"longbow": "tower_longbow", &"volley": "tower_volley"}
const FENCE_BRANCHES := {&"stone": "fence_stone", &"spike": "fence_spike"}
const ASPECTS := [9.0 / 21.0, 9.0 / 16.0, 16.0 / 9.0]
## Design thresholds (metres). Measured: Longbow 4.32 x 1.06 wide (x), Volley 2.30 x 1.78, level 3 3.40 x 1.33;
## Stone 1.20 x 0.90 deep, Spike 1.30 high and reaching 0.74 up-lane, wooden level-3 fence 0.90 x 0.50, up-lane 0.25.
const LONGBOW_TALLER := 0.8    ## Longbow is at least this much taller than the level-3 tower
const LONGBOW_SLIMMER := 0.2   ## ... and at least this much narrower than it
const LONGBOW_VS_VOLLEY := 0.6  ## ... and narrower than Volley by this much (x extent: the screen-horizontal one)
const VOLLEY_WIDER := 0.4      ## Volley is at least this much wider than level 3 ...
const VOLLEY_LOWER := 0.8      ## ... and its top at least this much lower
const STONE_TALLER := 0.25
const STONE_DEEPER := 0.3
const SPIKE_REACH := 0.4       ## Spike's most up-lane vertex (-z) reaches this much further than the level-3 fence's
const SPIKE_TALLER := 0.3
const SPAN_TOL := 0.1

var main: Main

func before_each() -> void:
	Balance.reset()
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)
	main = Main.create()
	add_child_autofree(main)
	GameState.new_game(1)
	main.hero.input.player_control = false
	main.hero.teleport(Vector2(20, 10))

func after_each() -> void:
	Balance.reset()
	GameState.new_game(1)

# --- helpers ---

func _mesh(name: String) -> ArrayMesh:
	return load(ENV + "baked/%s.res" % name) as ArrayMesh

func _box(name: String) -> AABB:
	return _mesh(name).get_aabb()

func _scene_name(spot: BuildSpot) -> String:
	assert_eq(spot.visual.get_child_count(), 1, "%s: exactly one model child" % spot.spot_id)
	return (spot.visual.get_child(0) as Node).scene_file_path.get_file().get_basename()

func _tier3() -> void:
	GameState.debug_set_tier(3, 1)
	GameState.add_gold(100000)

func _max_out(id: String) -> void:
	while GameState.next_level_cost(id) > 0:
		GameState.pay_into_spot(id, GameState.next_level_cost(id))

func _branch(id: String, branch: StringName) -> void:
	GameState.add_gold(5000)
	GameState.pay_into_branch(id, branch, GameState.branch_cost(id))
	assert_eq(GameState.branch_of(id), branch, "precondition: %s bought %s" % [id, branch])

func _tris(path: String) -> int:
	var n: Node = load(path).instantiate()
	add_child_autofree(n)
	return AssetValidator.count_triangles(n)

# --- model selection ---

func test_each_branch_shows_its_own_model_and_unbranched_level_3_shows_l3() -> void:
	_tier3()
	var spots := {&"longbow": "tower_nw", &"volley": "tower_ne", &"stone": "fence_w", &"spike": "fence_n"}
	for id in spots.values():
		_max_out(id)
		var spot: BuildSpot = main.world.build_spots[id]
		await get_tree().physics_frame
		assert_eq(_scene_name(spot), "tower_l3" if id.begins_with("tower") else "fence_l3", "%s: unbranched level 3" % id)
	for br in spots:
		_branch(spots[br], br)
		var spot: BuildSpot = main.world.build_spots[spots[br]]
		var want: String = (TOWER_BRANCHES if br in TOWER_BRANCHES else FENCE_BRANCHES)[br]
		assert_eq(_scene_name(spot), want, "%s shows %s the moment it is bought" % [spots[br], br])
		assert_eq(spot.visual.get_child(0).scene_file_path, ENV + want + ".tscn")

func test_branch_models_are_shown_only_at_level_3() -> void:
	_tier3()
	assert_eq(TowerSpot.shown_branch(2, &"longbow"), &"", "a level-2 tower never shows a branch")
	assert_eq(FenceSpot.shown_branch(2, &"stone"), &"", "a level-2 fence never shows a branch")
	assert_eq(TowerSpot.shown_branch(3, &"longbow"), &"longbow")
	assert_eq(TowerSpot.shown_branch(3, &""), &"")
	assert_eq(TowerSpot.model_for(2, &"volley").resource_path, ENV + "tower_l2.tscn")
	assert_eq(FenceSpot.model_for(1, &"spike").resource_path, ENV + "fence_l1.tscn")
	assert_null(TowerSpot.model_for(0, &"longbow"))

func test_a_rubble_branched_fence_shows_rubble_a_restored_snapshot_its_branch_and_dawn_clears_it() -> void:
	_tier3()
	for pair in [["fence_w", &"stone"], ["fence_n", &"spike"]]:
		_max_out(pair[0])
		_branch(pair[0], pair[1])
		var f: FenceSpot = main.world.build_spots[pair[0]]
		var saved := GameState.to_dict()  # taken while the fence still stands
		GameState.damage_fence(pair[0], 1e9)
		assert_true(f.is_rubble(), "%s: broken" % pair[0])
		assert_eq(_scene_name(f), "fence_rubble", "%s rubble whatever its branch" % pair[1])
		assert_eq(GameState.branch_of(pair[0]), pair[1], "precondition: the branch is still recorded at night")
		for p in f._pips.filter(func(q): return q.visible):
			assert_almost_eq(p.position.y, FenceSpot.PIP_Y, 0.001, "%s: a rubble fence keeps the unbranched rubble pip height" % pair[1])
		assert_almost_eq(f.label.position.y, FenceSpot.PIP_Y + 0.55, 0.001, "%s: and its label" % pair[1])
		# (a) a snapshot taken before the fence broke (a failed night restores one): the branch model is back
		GameState.from_dict(saved)
		assert_false(f.is_rubble(), "%s: the snapshot's fence stands" % pair[1])
		assert_eq(_scene_name(f), FENCE_BRANCHES[pair[1]], "%s shows its branch again after restoring the snapshot" % pair[1])
		# (b) dawn: the broken fence is reset to nothing; rebuilding it shows the plain level-3 fence, not the branch
		GameState.damage_fence(pair[0], 1e9)
		GameState.reset_destroyed_fences()
		assert_eq(f.visual.get_child_count(), 0, "%s: after dawn the spot shows no model" % pair[1])
		assert_eq(GameState.branch_of(pair[0]), &"", "%s: the branch is gone" % pair[1])
		_max_out(pair[0])
		assert_eq(_scene_name(f), "fence_l3", "%s: rebuilt to level 3 it is the unbranched fence" % pair[1])

func test_the_branch_model_survives_a_save_round_trip_and_new_game_clears_it() -> void:
	_tier3()
	for id in ["tower_nw", "tower_ne", "fence_w", "fence_n"]:
		_max_out(id)
	_branch("tower_nw", &"longbow")
	_branch("tower_ne", &"volley")
	_branch("fence_w", &"stone")
	_branch("fence_n", &"spike")
	var saved := GameState.to_dict()
	GameState.new_game(1)
	for id in ["tower_nw", "tower_ne", "fence_w", "fence_n"]:
		assert_eq(main.world.build_spots[id].visual.get_child_count(), 0, "%s: new_game(1) shows nothing" % id)
	GameState.from_dict(saved)
	assert_eq(_scene_name(main.world.build_spots.tower_nw), "tower_longbow", "load: Longbow")
	assert_eq(_scene_name(main.world.build_spots.tower_ne), "tower_volley", "load: Volley")
	assert_eq(_scene_name(main.world.build_spots.fence_w), "fence_stone", "load: Stone")
	assert_eq(_scene_name(main.world.build_spots.fence_n), "fence_spike", "load: Spike")
	GameState.new_game(1)
	for id in ["tower_nw", "tower_ne", "fence_w", "fence_n"]:
		assert_eq(main.world.build_spots[id].visual.get_child_count(), 0, "%s: after new_game(1) none shows" % id)
	assert_true(GameState.branch_of("tower_nw") == &"", "and no branch is recorded")

func test_pips_and_labels_clear_every_branch_model() -> void:
	_tier3()
	var cases := [["tower_nw", &"longbow", "tower_longbow"], ["tower_ne", &"volley", "tower_volley"],
		["fence_w", &"stone", "fence_stone"], ["fence_n", &"spike", "fence_spike"]]
	for c in cases:
		_max_out(c[0])
		var spot: BuildSpot = main.world.build_spots[c[0]]
		var plain_pip := spot._pip_y(3)
		_branch(c[0], c[1])
		var top := _box(c[2]).end.y
		assert_gt(spot._pip_y(3), top, "%s: the pips sit above the model" % c[1])
		assert_lt(spot._pip_y(3), top + 0.35, "%s: and stay close to it" % c[1])
		assert_gt(spot._label_y(3), spot._pip_y(3), "%s: the label rides above the pips" % c[1])
		for p in spot._pips.filter(func(q): return q.visible):
			assert_almost_eq(p.position.y, spot._pip_y(3), 0.001, "%s: shown pips follow the branch height" % c[1])
		assert_ne(spot._pip_y(3), plain_pip, "%s: the height is the branch's, not level 3's" % c[1])

# --- silhouettes ---

func test_longbow_is_taller_and_slimmer_than_level_3_and_narrower_than_volley() -> void:
	var lb := _box("tower_longbow")
	var vy := _box("tower_volley")
	var l3 := _box("tower_l3")
	assert_gte(lb.end.y, l3.end.y + LONGBOW_TALLER, "taller than the level-3 tower (%.2f vs %.2f)" % [lb.end.y, l3.end.y])
	assert_lte(lb.size.x, l3.size.x - LONGBOW_SLIMMER, "slimmer than level 3 (%.2f vs %.2f)" % [lb.size.x, l3.size.x])
	assert_lte(lb.size.x, vy.size.x - LONGBOW_VS_VOLLEY, "narrower than Volley (%.2f vs %.2f)" % [lb.size.x, vy.size.x])

func test_volley_is_wider_and_lower_set_than_level_3() -> void:
	var vy := _box("tower_volley")
	var l3 := _box("tower_l3")
	assert_gte(vy.size.x, l3.size.x + VOLLEY_WIDER, "wider than level 3 (%.2f vs %.2f)" % [vy.size.x, l3.size.x])
	assert_lte(vy.end.y, l3.end.y - VOLLEY_LOWER, "its top sits lower (%.2f vs %.2f)" % [vy.end.y, l3.end.y])

func test_stone_is_taller_and_deeper_than_the_level_3_fence() -> void:
	var st := _box("fence_stone")
	var f3 := _box("fence_l3")
	assert_gte(st.end.y, f3.end.y + STONE_TALLER, "taller (%.2f vs %.2f)" % [st.end.y, f3.end.y])
	assert_gte(st.size.z, f3.size.z + STONE_DEEPER, "deeper (%.2f vs %.2f)" % [st.size.z, f3.size.z])

func test_spike_reaches_further_up_lane_and_stands_taller_than_the_level_3_fence() -> void:
	var sp := _box("fence_spike")
	var f3 := _box("fence_l3")
	assert_lte(sp.position.z, f3.position.z - SPIKE_REACH, "stakes reach further up-lane, -z (%.2f vs %.2f)" % [sp.position.z, f3.position.z])
	assert_gte(sp.end.y, f3.end.y + SPIKE_TALLER, "taller (%.2f vs %.2f)" % [sp.end.y, f3.end.y])
	# stakes are vertices, not a box: some vertex at least 0.5 m up-lane of the fence body sits above the rail height
	var reach_high := false
	for v in (_mesh("fence_spike").surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		if v.z < -0.6 and v.y > 0.9:
			reach_high = true
	assert_true(reach_high, "a stake tip stands up-lane and above 0.9 m")

func test_the_four_branch_models_and_level_3_all_differ_by_size() -> void:
	var sizes := {}
	for n in ["tower_l3", "tower_longbow", "tower_volley"]:
		sizes[_box(n).size.snapped(Vector3.ONE * 0.05)] = n
	assert_eq(sizes.size(), 3, "towers: three different outlines")
	sizes = {}
	for n in ["fence_l3", "fence_stone", "fence_spike"]:
		sizes[_box(n).size.snapped(Vector3.ONE * 0.05)] = n
	assert_eq(sizes.size(), 3, "fences: three different outlines")
	var h := [_box("fence_stone").end.y, _box("fence_spike").end.y]
	assert_ne(snappedf(h[0], 0.05), snappedf(h[1], 0.05), "Stone and Spike differ in height as well as depth")

func test_every_fence_keeps_the_three_metre_span() -> void:
	for n in ["fence_l3", "fence_stone", "fence_spike"]:
		assert_almost_eq(_box(n).size.x, 3.0, SPAN_TOL, "%s spans 3 m across" % n)
		assert_almost_eq(_box(n).get_center().x, 0.0, SPAN_TOL, "%s is centred on its spot" % n)

# --- pipeline: budgets, one surface, no physics, not the diner's fade ---

func test_triangle_counts_are_inside_the_budgets() -> void:
	# ArtBudgets.budget_for takes the LONGEST matching res:// prefix: "res://art/env/tower" covers tower_longbow and tower_volley
	# (4000) and "res://art/env/fence" covers fence_stone and fence_spike (1500).
	var want := {"tower_longbow": 4000, "tower_volley": 4000, "fence_stone": 1500, "fence_spike": 1500}
	for n in want:
		var path: String = ENV + n + ".tscn"
		assert_eq(ArtBudgets.budget_for(path), want[n], "%s: the budget lookup finds the family prefix" % n)
		assert_lte(_tris(path), want[n], "%s triangles" % n)
		assert_gt(_tris(path), 100, "%s has real geometry" % n)

func test_each_branch_scene_is_one_mesh_one_surface_on_the_shared_atlas() -> void:
	var mats := {"tower_longbow": "kenney-tower-defense__colormap", "tower_volley": "kenney-tower-defense__colormap",
		"fence_stone": "kenney-fantasy-town__colormap", "fence_spike": "kenney-fantasy-town__colormap"}
	for n in mats:
		var scene: Node = load(ENV + n + ".tscn").instantiate()
		assert_eq(scene.name, &"Model", "%s: wrapper root" % n)
		add_child_autofree(scene)
		assert_eq(scene.find_children("*", "MeshInstance3D", true, false).size(), 1, "%s: one MeshInstance3D" % n)
		var m := _mesh(n)
		assert_eq(m.get_surface_count(), 1, "%s: one surface" % n)
		assert_eq(m.surface_get_material(0).resource_path, "res://art/materials/%s.tres" % mats[n], "%s: the shared atlas material" % n)

func test_each_wrapper_points_at_its_own_baked_mesh() -> void:
	for n in ["tower_longbow", "tower_volley", "fence_stone", "fence_spike"]:
		var scene: Node = load(ENV + n + ".tscn").instantiate()
		var mi := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		assert_eq(mi.mesh.resource_path, ENV + "baked/%s.res" % n, "%s: the wrapper shows its own bake" % n)
		scene.free()

func test_committed_bakes_match_their_sources() -> void:
	const Bake := preload("res://tools/bake_static.gd")
	for n in ["tower_longbow", "tower_volley", "fence_stone", "fence_spike"]:
		var src: Node3D = load(ENV + "src/%s_src.tscn" % n).instantiate()
		var fresh: ArrayMesh = Bake.bake(src)
		src.free()
		var cur := _mesh(n)
		assert_eq(cur.get_surface_count(), fresh.get_surface_count(), n)
		var a := fresh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var b := cur.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		assert_eq(a.size(), b.size(), "%s: vertex count is current, rerun tools/bake_static.gd --all" % n)
		var off := 0
		for i in mini(a.size(), b.size()):
			if a[i].distance_to(b[i]) > 1e-4:
				off += 1
		assert_eq(off, 0, "%s: vertices differ from a fresh bake" % n)

func test_no_branch_model_is_a_collider_or_in_the_diners_fade_set() -> void:
	_tier3()
	var fade_meshes: Array = main.world.occluder_fade.get_parent().find_children("*", "MeshInstance3D", true, false)
	var all := [["tower_nw", &"longbow"], ["tower_ne", &"volley"], ["fence_w", &"stone"], ["fence_n", &"spike"]]
	for c in all:
		_max_out(c[0])
		_branch(c[0], c[1])
		var spot: BuildSpot = main.world.build_spots[c[0]]
		var model := spot.visual.get_child(0)
		assert_eq(model.find_children("*", "CollisionObject3D", true, false).size(), 0, "%s: no physics body (D-125)" % c[1])
		assert_eq(model.find_children("*", "CollisionShape3D", true, false).size(), 0, "%s: no shape" % c[1])
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			assert_false(fade_meshes.has(mi), "%s is not part of the diner's fade set" % c[1])
			assert_eq((mi as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % c[1])
		# the fade set is every mesh under the fade's parent (the diner's Visual): a model there would be faded with the diner
		assert_false(main.world.occluder_fade.get_parent().is_ancestor_of(model), "%s does not hang under the diner's Visual" % c[1])
		assert_false(main.world.occluder_fade.is_ancestor_of(model), "%s is not under the fade node" % c[1])
		assert_false(main.world.build_spots[c[0]].marker.visible, "%s: a built spot shows no pad marker, so nothing to cover (a)" % c[1])

# --- camera: the tall model hides no pad and no stop point ---

## The mesh as one box per triangle (each triangle's own AABB) under its whole-mesh box as a broad phase: a thin arm hides what a thin
## arm hides, not a prism from the ground to its tip.
static func _tri_boxes(mesh: ArrayMesh) -> Dictionary:
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		for i in v.size():
			idx.append(i)
	var boxes: Array = []
	for t in range(0, idx.size(), 3):
		var lo := v[idx[t]]
		var hi := lo
		for k in 3:
			lo = lo.min(v[idx[t + k]])
			hi = hi.max(v[idx[t + k]])
		boxes.append(AABB(lo, hi - lo))
	return {"all": mesh.get_aabb(), "tris": boxes}

## True when the segment from the camera to ground point `p` passes through `box` (slab test; the end point itself is not inside).
static func _hits(cam: Vector3, p: Vector3, box: AABB) -> bool:
	var d := p - cam
	var t0 := 0.0
	var t1 := 1.0 - 1e-4
	for axis in 3:
		var lo := box.position[axis]
		var hi := box.end[axis]
		if absf(d[axis]) < 1e-9:
			if cam[axis] < lo or cam[axis] > hi:
				return false
		else:
			var a := (lo - cam[axis]) / d[axis]
			var b := (hi - cam[axis]) / d[axis]
			t0 = maxf(t0, minf(a, b))
			t1 = minf(t1, maxf(a, b))
			if t0 > t1:
				return false
	return true

static func _hides(cam: Vector3, p: Vector3, model: Dictionary) -> bool:
	if not _hits(cam, p, model.all):
		return false
	for b in model.tris:
		if _hits(cam, p, b):
			return true
	return false

## A point behind a thin rod is not "covered": the centre must be hidden AND at least RING_MIN of the four points RING metres around it.
const RING := 0.4
const RING_MIN := 3

static func _ring(cam: Vector3, g: Vector3, boxes: Dictionary) -> int:
	var n := 0
	for d in [Vector3(RING, 0, 0), Vector3(-RING, 0, 0), Vector3(0, 0, RING), Vector3(0, 0, -RING)]:
		if _hides(cam, g + d, boxes):
			n += 1
	return n

func _tower_ids() -> Array:
	return MapLayout.TOWER_LANES.keys() + MapLayout.TOWER_LANES_T3.keys()

## What a branched tower at `id` could hide that matters while it stands: the pads of every OTHER spot (a spot's own pads exist only
## while it has no branch), every other spot's centre (its marker or building), the station pads and the stop points of every lane.
func _points_for(id: String) -> Array:
	var out: Array = []
	for sid in MapLayout.spots_for_tier(3):
		if sid == id:
			continue
		for i in 2:
			out.append(["pad %s/%d" % [sid, i], (MapLayout.BRANCH_PADS[sid] as Array)[i]])
		out.append(["spot " + sid, MapLayout.spot_position(sid)])
	for st in MapLayout.STATION_PADS:
		out.append(["station pad %s" % st, MapLayout.STATION_PADS[st]])
	for lane in MapLayout.lanes_for_tier(3):
		out.append(["stop (fence) " + lane, MapLayout.fence_spot(lane)])
		out.append(["stop (wall) " + lane, MapLayout.lane_end(lane)])
	return out

## Camera foci: each tower spot, each lane's zone centre, and every point itself (the hero standing on it).
func _foci_for(points: Array) -> Array:
	var out: Array = []
	for t in _tower_ids():
		out.append(MapLayout.spot_position(t))
	for lane in MapLayout.lanes_for_tier(3):
		var r := MapLayout.zone_rect(lane)
		out.append(r.position + r.size * 0.5)
	for p in points:
		out.append(p[1])
	return out

## {"hidden": sorted "label@focus" keys hidden at some aspect with the 3-of-4 ring rule, "centre": count hidden by centre alone}.
func _hidden(id: String, model: Dictionary) -> Dictionary:
	var spot2 := MapLayout.spot_position(id)
	var at := Vector3(spot2.x, 0.0, spot2.y)  # the model sits at its spot: the camera and the point move by the opposite instead
	var points := _points_for(id)
	var keys := {}
	var centre := 0
	for f in _foci_for(points):
		var xf := CameraMath.camera_transform(CameraMath.focus_for(f), Balance.ui)
		for pt in points:
			var g := MapLayout.to3(pt[1])
			var seen := false
			for aspect in ASPECTS:
				seen = seen or CameraMath.on_screen(g, xf, CameraMath.projection(Balance.ui, aspect))
			if not seen or not _hides(xf.origin - at, g - at, model):
				continue
			centre += 1
			if _ring(xf.origin - at, g - at, model) >= RING_MIN:
				keys["%s@%s" % [pt[0], f]] = true
	var sorted := keys.keys()
	sorted.sort()
	return {"hidden": sorted, "centre": centre}

## Pairs a branch model hides that the unbranched level-3 tower at the same spot does not (the model may hide FEWER: a subset is fine).
func _extras(id: String, branch_model: Dictionary, l3: Dictionary, label := "") -> Array:
	var base: Array = _hidden(id, l3).hidden
	var res := _hidden(id, branch_model)
	var out: Array = []
	for k in res.hidden:
		if not base.has(k):
			out.append(k)
	print("CAMERA [%s] %s: level 3 hides %d (centre-only %d); this model hides %d (centre-only %d); extra %s" % [
		label, id, base.size(), _hidden(id, l3).centre, res.hidden.size(), res.centre, out])
	return out

## The pinned extra pairs, per spot ("pad/spot/station/stop label@focus"), of each branch model over the unbranched level 3.
const LONGBOW_EXTRA := {
	"tower_nw": ["pad fence_n/0@(-10.6, 0.6)"], "tower_e": ["pad fence_e/1@(7.9, 7.0)"],
	"tower_sw": ["pad tower_w/1@(-1.0, 10.7)", "spot tower_w@(2.6, 7.2)"],
}
const VOLLEY_EXTRA := {
	"tower_nw": ["pad fence_w/1@(-1.0, 10.7)", "pad fence_w/1@(2.6, 7.2)"],
	"tower_ne": ["pad fence_e/0@(-1.0, 10.7)", "pad fence_e/0@(-3.26297, 9.166971)"],
}

func _check_extras(model_name: String, pinned: Dictionary) -> void:
	var l3 := _tri_boxes(_mesh("tower_l3"))
	var m := _tri_boxes(_mesh(model_name))
	for id in _tower_ids():
		var extra := _extras(id, m, l3, model_name)
		for k in extra:
			assert_false(String(k).begins_with("stop"), "%s at %s hides a stop point: %s" % [model_name, id, k])
		assert_eq(extra, pinned.get(id, []), "%s at %s: the extra pairs over level 3 are exactly the pinned list" % [model_name, id])

func test_the_longbow_hides_nothing_the_level_3_tower_does_not_beyond_the_pinned_pairs() -> void:
	_check_extras("tower_longbow", LONGBOW_EXTRA)

func test_the_volley_hides_nothing_the_level_3_tower_does_not_beyond_the_pinned_pairs() -> void:
	_check_extras("tower_volley", VOLLEY_EXTRA)

func test_a_far_too_tall_longbow_would_hide_more_so_the_check_can_fail() -> void:
	var model := _tri_boxes(_mesh("tower_longbow"))
	var tall := {"all": AABB(model.all.position, model.all.size * Vector3(1, 2.5, 1)),
		"tris": model.tris.map(func(b: AABB) -> AABB: return AABB(b.position * Vector3(1, 2.5, 1), b.size * Vector3(1, 2.5, 1)))}
	var more := 0
	for id in _tower_ids():
		more += _extras(id, tall, _tri_boxes(_mesh("tower_l3"))).size()
	assert_gt(more, 0, "a 10.8 m Longbow hides pairs the level-3 tower does not")

func test_tower_nw_hides_fence_ws_second_pad_from_the_north_zone_centre_() -> void:
	# the reviewer's example: tower_nw (-5, -5) and fence_w's pad (-6.1, -6.1) are 1.56 m apart; the hero in the north zone (0, -4.6)
	var key := "pad fence_w/1@(0.0, -4.6)"
	assert_true((_hidden("tower_nw", _tri_boxes(_mesh("tower_l3"))).hidden as Array).has(key), "the unbranched level 3 at tower_nw hides %s" % key)
	assert_false((_hidden("tower_w", _tri_boxes(_mesh("tower_longbow"))).hidden as Array).has(key), "a far tower does not (the check discriminates)")
