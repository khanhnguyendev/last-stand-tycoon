extends GutTest
## S4 Task 11 (D-194, D-201): the diner, counter and freezer art. One baked mesh each, within budget, no physics, the
## roof top where the Archer stands, and the committed bake equals a fresh bake of its source scene.

## A stale bake moves vertices by cm. Cross-platform noise: positions < 1e-4; normals ~1.2e-4 (compressed normal
## encoding differs between macOS arm64 and Linux x86), so normals get 2e-3.
const BAKE_TOL := 1e-4
const BAKE_NORMAL_TOL := 2e-3

const Bake := preload("res://tools/bake_static.gd")
const SCENES := {
	"res://art/env/diner.tscn": ["res://art/env/src/diner_src.tscn", "res://art/env/baked/diner.res", 3],
	"res://art/env/diner_t2.tscn": ["res://art/env/src/diner_t2_src.tscn", "res://art/env/baked/diner_t2.res", 3],
	"res://art/env/diner_t3.tscn": ["res://art/env/src/diner_t3_src.tscn", "res://art/env/baked/diner_t3.res", 3],
	"res://art/env/counter_visual.tscn": ["res://art/env/src/counter_src.tscn", "res://art/env/baked/counter.res", 1],
	"res://art/env/freezer_visual.tscn": ["res://art/env/src/freezer_src.tscn", "res://art/env/baked/freezer.res", 1],
}

func _inst(path: String) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	add_child_autofree(n)
	return n

func _body(n: Node) -> MeshInstance3D:
	return n.get_node("Body") as MeshInstance3D

func test_diner_instantiates_with_board() -> void:
	var d := _inst("res://art/env/diner.tscn")
	assert_eq(d.name, &"DinerArt")
	var board := d.get_node("Board") as WorldLabel
	assert_not_null(board, "the Board is a WorldLabel")
	assert_eq(board.text, tr("DINER"))

func test_no_physics_and_no_multimesh() -> void:
	for path in SCENES:
		var n := _inst(path)
		assert_eq(n.find_children("*", "CollisionObject3D", true, false).size(), 0, "%s: no CollisionObject3D (validator rule 6)" % path)
		assert_eq(n.find_children("*", "MultiMeshInstance3D", true, false).size(), 0, "%s: no MultiMeshInstance3D (D-194)" % path)

func test_one_mesh_and_surfaces_within_target() -> void:
	for path in SCENES:
		var n := _inst(path)
		var meshes := n.find_children("*", "MeshInstance3D", true, false)
		assert_eq(meshes.size(), 1, "%s: one MeshInstance3D" % path)
		var surfaces := 0
		for m in meshes:
			surfaces += (m as MeshInstance3D).mesh.get_surface_count()
		assert_between(surfaces, 1, int(SCENES[path][2]), "%s: draws (D-201)" % path)

func test_diner_within_triangle_budget() -> void:
	var d := _inst("res://art/env/diner.tscn")
	var budget := ArtBudgets.budget_for("res://art/env/diner.tscn")
	assert_eq(budget, 12000)
	assert_between(AssetValidator.count_triangles(d), 1, budget)

func test_every_surface_uses_a_shared_material() -> void:
	for path in SCENES:
		var mesh := _body(_inst(path)).mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			assert_not_null(mat, "%s surface %d has a material" % [path, i])
			if mat != null:
				assert_true(mat.resource_path.begins_with("res://art/materials/"), "%s surface %d: %s" % [path, i, mat.resource_path])

## Area of the upward-facing triangles whose three vertices lie in [y0, y1].
func _flat_area(mesh: ArrayMesh, y0: float, y1: float) -> float:
	var area := 0.0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in idx.size() / 3:
			var a := v[idx[t * 3]]
			var b := v[idx[t * 3 + 1]]
			var c := v[idx[t * 3 + 2]]
			if minf(a.y, minf(b.y, c.y)) < y0 or maxf(a.y, maxf(b.y, c.y)) > y1:
				continue
			var n := (b - a).cross(c - a)
			if n.y < 0.0:  # Godot's front faces wind clockwise, so the outward normal is the negated cross
				area += n.length() * 0.5
	return area

func test_roof_top_is_the_archer_perch() -> void:
	var mesh := _body(_inst("res://art/env/diner.tscn")).mesh as ArrayMesh
	var flat := _flat_area(mesh, MapLayout.DINER_HEIGHT - 0.05, MapLayout.DINER_HEIGHT + 0.05)
	assert_gt(flat, 50.0, "an 8 m roof surface faces up at y = 3.0 +- 0.05 (the Archer stands there)")
	var archer := MapLayout.guard_post(&"archer")
	assert_lt(absf(archer.x), MapLayout.DINER_HALF - 0.6, "the perch is clear of the parapet")
	assert_lt(absf(archer.y), MapLayout.DINER_HALF - 0.6)

func test_diner_footprint_and_height() -> void:
	var bb := _body(_inst("res://art/env/diner.tscn")).get_aabb()
	assert_between(bb.position.x, -4.5, -3.9)
	assert_between(bb.end.x, 3.9, 4.5)
	assert_between(bb.position.z, -4.5, -3.9)
	assert_between(bb.end.z, 3.9, 4.5, "the awning is a lip, not a porch (hero at the counter must not fade it)")
	assert_between(bb.position.y, -0.01, 0.01)
	assert_gt(bb.end.y, MapLayout.DINER_HEIGHT + 0.3, "a parapet stands above the roof")

func test_counter_and_freezer_match_their_footprints() -> void:
	var c := _body(_inst("res://art/env/counter_visual.tscn")).get_aabb()
	assert_almost_eq(c.end.y, 1.0, 0.05, "counter top at 1.0 m")
	assert_almost_eq(c.size.x, MapLayout.COUNTER_SIZE.x, 0.2)
	assert_almost_eq(c.size.z, MapLayout.COUNTER_SIZE.y, 0.2)
	var f := _body(_inst("res://art/env/freezer_visual.tscn")).get_aabb()
	assert_almost_eq(f.end.y, 1.4, 0.05, "fridge about 1.4 m")
	assert_lt(f.size.x, MapLayout.FREEZER_SIZE.x + 0.1)
	assert_lt(f.size.z, MapLayout.FREEZER_SIZE.y + 0.1)

func test_committed_bake_is_current() -> void:
	for path in SCENES:
		var src := (load(SCENES[path][0]) as PackedScene).instantiate() as Node3D
		add_child_autofree(src)
		var fresh: ArrayMesh = Bake.bake(src)
		var committed := load(SCENES[path][1]) as ArrayMesh
		assert_eq(fresh.get_surface_count(), committed.get_surface_count(), "%s surfaces" % path)
		for s in mini(fresh.get_surface_count(), committed.get_surface_count()):
			var a := fresh.surface_get_arrays(s)
			var b := committed.surface_get_arrays(s)
			assert_true(a[Mesh.ARRAY_INDEX] == b[Mesh.ARRAY_INDEX], "%s surface %d indices are current: rerun tools/bake_static.gd --all" % [path, s])
			assert_true(a[Mesh.ARRAY_TEX_UV] == b[Mesh.ARRAY_TEX_UV], "%s surface %d UVs" % [path, s])
			assert_true(a[Mesh.ARRAY_COLOR] == b[Mesh.ARRAY_COLOR], "%s surface %d vertex colours" % [path, s])
			for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL]:
				var fa: PackedVector3Array = a[k]
				var fb: PackedVector3Array = b[k]
				assert_eq(fa.size(), fb.size(), "%s surface %d array %d size" % [path, s, k])
				var off := 0
				for i in mini(fa.size(), fb.size()):
					if fa[i].distance_to(fb[i]) > (BAKE_NORMAL_TOL if k == Mesh.ARRAY_NORMAL else BAKE_TOL):
						off += 1
				assert_eq(off, 0, "%s surface %d array %d: vertices that differ from the fresh bake" % [path, s, k])
			assert_eq(fresh.surface_get_material(s), committed.surface_get_material(s), "%s surface %d material" % [path, s])

func test_tall_vertices_lie_inside_the_occluder_boxes() -> void:
	var d := _inst("res://art/env/diner.tscn")
	var boxes: Array[AABB] = d.occluder_boxes
	var mesh := _body(d).mesh
	var outside := 0
	var tall := 0
	for s in mesh.get_surface_count():
		for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			if v.y <= 3.45:
				continue
			tall += 1
			var inside := false
			for b in boxes:
				if b.grow(0.05).has_point(v):
					inside = true
					break
			if not inside:
				outside += 1
	assert_gt(tall, 0, "the diner has vertices above the parapet")
	assert_eq(outside, 0, "vertices above y 3.45 outside every DinerArt.occluder_boxes (grown 0.05): the boxes drifted from the art")


# ---- E5 Task 11: the tier-2 diner (cream terraces on the flanks, nothing above the ground) ----

func _triangles(mesh: ArrayMesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n

func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		out.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	return out

func test_tier2_diner_keeps_the_footprint_and_adds_the_flanks() -> void:
	var t1: ArrayMesh = load("res://art/env/baked/diner.res")
	var t2: ArrayMesh = load("res://art/env/baked/diner_t2.res")
	var a1 := t1.get_aabb()
	var a2 := t2.get_aabb()
	assert_between(a2.size.y, a1.size.y - 0.01, a1.size.y + 0.2, "same height class: the parts stay under tier 1's sign plank (E5 slice 2 Task 1, ruling A; was +-0.3 around equal, now a range)")
	assert_gt(a2.size.x, a1.size.x + 1.0, "the terraces widen the look")
	assert_lte(a2.size.x, 11.3, "but stay inside the yards' inner edges")
	assert_lte(_triangles(t2), ArtBudgets.budget_for("res://art/env/diner"))

func test_tier2_diner_surfaces_use_shared_materials() -> void:
	var t2: ArrayMesh = load("res://art/env/baked/diner_t2.res")
	for i in t2.get_surface_count():
		var m := t2.surface_get_material(i)
		assert_not_null(m)
		assert_true(m.resource_path.begins_with("res://art/materials/"), m.resource_path)

func test_tier2_diner_adds_nothing_above_the_ground_outside_the_tier1_footprint() -> void:
	var half: float = (load("res://art/env/baked/diner.res") as ArrayMesh).get_aabb().end.x
	var t2: ArrayMesh = load("res://art/env/baked/diner_t2.res")
	var checked := 0
	for v in _vertices(t2):
		if absf(v.x) > half + 1e-3:
			checked += 1
			assert_lte(v.y, 0.02, "vertex %s above the ground beside the diner" % v)
	assert_gt(checked, 0, "the terraces exist")

func test_tier2_terrace_top_is_below_the_shadows_and_steaks() -> void:
	var t2: ArrayMesh = load("res://art/env/baked/diner_t2.res")
	var top := 0.0
	for v in _vertices(t2):
		if absf(v.x) > 4.0 + 1e-3:
			top = maxf(top, v.y)
	assert_gt(top, 0.0)
	assert_lt(top, 0.02, "under the ground steaks (0.02) and blob shadows (0.04)")

## The tier-2 source copies the tier-1 source's nodes (the bake needs real nodes): a later edit of one must not diverge.
func test_tier2_source_copies_the_tier1_source() -> void:
	var s1 := (load("res://art/env/src/diner_src.tscn") as PackedScene).instantiate() as Node3D
	var s2 := (load("res://art/env/src/diner_t2_src.tscn") as PackedScene).instantiate() as Node3D
	add_child_autofree(s1)
	add_child_autofree(s2)
	assert_gt(s1.get_child_count(), 50)
	for c in s1.get_children():
		var d := s2.get_node_or_null(NodePath(c.name)) as Node3D
		assert_not_null(d, "tier-2 source has %s" % c.name)
		if d == null:
			continue
		assert_eq(d.transform, (c as Node3D).transform, "%s transform" % c.name)
		assert_eq(d.scene_file_path, c.scene_file_path, "%s scene" % c.name)
		if c is MeshInstance3D:
			assert_eq((d as MeshInstance3D).mesh, (c as MeshInstance3D).mesh)
			assert_eq((d as MeshInstance3D).material_override, (c as MeshInstance3D).material_override)

func test_tier2_diner_stays_inside_its_envelope() -> void:
	var a1: AABB = (load("res://art/env/baked/diner.res") as ArrayMesh).get_aabb()
	var a2: AABB = (load("res://art/env/baked/diner_t2.res") as ArrayMesh).get_aabb()
	assert_gte(a2.position.x, -5.65)
	assert_lte(a2.end.x, 5.65)
	assert_lte(a2.end.y, a1.end.y + 1e-3, "nothing rises above the tier-1 diner (ruling A keeps the new parts below its sign plank; original assertion restored)")
	assert_almost_eq(a2.position.z, a1.position.z, 1e-3)
	assert_almost_eq(a2.end.z, a1.end.z, 1e-3)

func _diner_body_mesh(main: Node) -> MeshInstance3D:
	return main.world.diner_body.get_node("Visual").get_node("DinerArt").get_node("Body") as MeshInstance3D

func test_world_swaps_the_diner_on_tier_reached() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	main.phase_controller.start_new_game(1)
	assert_eq(_diner_body_mesh(main).mesh.resource_path, "res://art/env/baked/diner.res")
	var vis := main.world.diner_body.get_node("Visual")
	var kids := vis.get_child_count()
	GameState.debug_set_tier(2, 1)
	await get_tree().process_frame
	assert_eq(_diner_body_mesh(main).mesh.resource_path, "res://art/env/baked/diner_t2.res")
	assert_eq(vis.get_child_count(), kids, "no leaked second art node")
	assert_not_null(vis.get_node_or_null("OccluderFade"), "the fade survives the swap")
	assert_eq(vis.get_child(0).name, &"DinerArt", "the art stays child 0")
	var shape: BoxShape3D = main.world.diner_body.find_children("*", "CollisionShape3D", false, false)[0].shape
	assert_eq(shape.size, Vector3(8, 3, 8), "collision never changes")
	GameState.new_game(3)
	await get_tree().process_frame
	assert_eq(_diner_body_mesh(main).mesh.resource_path, "res://art/env/baked/diner.res", "a new game is tier 1 again")
	assert_eq(vis.get_child_count(), kids, "no leaked second art node")
	assert_eq(World.diner_scene_for(1), World.DINER_ART)
	assert_eq(World.diner_scene_for(2), World.DINER_ART_T2)

func test_world_built_at_tier_2_starts_with_the_tier_2_diner() -> void:
	GameState.new_game(5)
	GameState.debug_set_tier(2, 1)
	var main := Main.create()
	add_child_autofree(main)
	assert_eq(_diner_body_mesh(main).mesh.resource_path, "res://art/env/baked/diner_t2.res")
	GameState.new_game(1)

func test_swapping_the_diner_while_faded_fades_the_new_art_then_ends_opaque() -> void:
	var main := Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(72)
	var vis := main.world.diner_body.get_node("Visual")
	var fade: OccluderFade = vis.get_node("OccluderFade")
	main.hero.teleport((MapLayout.ZONE_RECTS["north"] as Rect2).get_center())
	main.camera_rig.snap()
	for i in 30:
		await get_tree().process_frame
	assert_true(fade.is_faded(), "the diner is faded")
	var kids := vis.get_child_count()
	GameState.debug_set_tier(2, 1)
	await get_tree().process_frame
	assert_eq(vis.get_child_count(), kids, "no leaked second art node")
	var body := _diner_body_mesh(main)
	assert_eq(body.mesh.resource_path, "res://art/env/baked/diner_t2.res")
	assert_true(fade.is_faded(), "still faded: the hero is still behind the diner")
	assert_not_null(body.get_surface_override_material(0), "the new Body is faded at once, not opaque over the hero")
	main.hero.teleport(MapLayout.HOME)
	main.camera_rig.snap()
	for i in 40:
		await get_tree().process_frame
	assert_false(fade.is_faded())
	for i in body.mesh.get_surface_count():
		assert_null(body.get_surface_override_material(i), "surface %d is back to its shared material" % i)
	GameState.new_game(1)

func test_tier2_terraces_are_diner_cream() -> void:
	var t2: ArrayMesh = load("res://art/env/baked/diner_t2.res")
	var want := Palette.color(&"diner_cream")
	var checked := 0
	for s in t2.get_surface_count():
		var arr := t2.surface_get_arrays(s)
		var img := ((t2.surface_get_material(s) as BaseMaterial3D).albedo_texture as Texture2D).get_image()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		for i in v.size():
			if v[i].y > 0.02 or absf(v[i].x) <= 4.0 + 1e-3:
				continue
			checked += 1
			var c := img.get_pixel(clampi(int(uv[i].x * img.get_width()), 0, img.get_width() - 1), clampi(int(uv[i].y * img.get_height()), 0, img.get_height() - 1))
			assert_lt(absf(c.r - want.r) + absf(c.g - want.g) + absf(c.b - want.b), 0.03, "vertex %s samples %s, not diner_cream" % [v[i], c])
	assert_gt(checked, 0, "the terraces exist")


# ---- E5 slice 2 Task 1: the tier-2 diner grows upward (roof colour, chimney, sign board), inside the footprint ----

const T2 := "res://art/env/baked/diner_t2.res"
const T1 := "res://art/env/baked/diner.res"
const TopTool := preload("res://tools/make_diner_t2_roof_src.gd")
const DinerArtT2 := preload("res://art/env/diner_art_t2.gd")
## The window aspects the camera supports (CameraMath: 9:21 .. 21:9) plus the two between.
const ASPECTS := [9.0 / 21.0, 9.0 / 16.0, 16.0 / 9.0, 21.0 / 9.0]
## The cap's thickness: the Archer's feet stand on 3.0 + CAP_THICKNESS at most (the tool's box 0 is 0.03 thick).
const CAP_THICKNESS := 0.03
const ROOF_CAP_TOP := MapLayout.DINER_HEIGHT + CAP_THICKNESS

func _color_at(mesh: ArrayMesh, s: int, uv: Vector2) -> Color:
	var img := ((mesh.surface_get_material(s) as BaseMaterial3D).albedo_texture as Texture2D).get_image()
	return img.get_pixel(clampi(int(uv.x * img.get_width()), 0, img.get_width() - 1), clampi(int(uv.y * img.get_height()), 0, img.get_height() - 1))

static func _key(v: Vector3) -> Vector3i:
	return Vector3i((v * 1000.0).round())

## Tier 1 keeps its own lip (the awning reaches z 4.3, S4); what tier 2 ADDS never overhangs: every vertex above
## terrace height outside |x|, |z| <= 4.0 is a tier-1 vertex.
func test_tier2_adds_nothing_outside_the_footprint_above_terrace_height() -> void:
	var t1 := {}
	for v in _vertices(load(T1) as ArrayMesh):
		t1[_key(v)] = true
	var checked := 0
	var added := 0
	for v in _vertices(load(T2) as ArrayMesh):
		if v.y <= 0.02:
			continue
		checked += 1
		if t1.has(_key(v)):
			continue
		added += 1
		assert_lte(absf(v.x), 4.0 + 1e-3, "added vertex %s overhangs in x" % v)
		assert_lte(absf(v.z), 4.0 + 1e-3, "added vertex %s overhangs in z" % v)
	assert_gt(checked, 0)
	# 8 tool boxes x 24 vertices = 192, all above terrace height; 12 of them coincide exactly with a tier-1 vertex (so are not "added"): 180.
	assert_eq(added, 180, "the roof cap, chimney and board boxes are new vertices (measured: 180)")

## Ruling A (fix round 1): the parts sit low in the middle and south of the roof (the sweeps below pick the heights), so
## they top out at 4.6 (the chimney cap), BELOW tier 1's own sign plank (5.1). The silhouette gain is the roof, the stack and
## the board (all above the roof surface at 3.0), not a new highest point. Before: "tier-2 AABB top >= tier-1 top + 0.9".
func test_tier2_adds_a_chimney_and_a_board_above_the_roof() -> void:
	var t1 := {}
	for v in _vertices(load(T1) as ArrayMesh):
		t1[_key(v)] = true
	var top := 0.0
	var tall_added := 0
	for v in _vertices(load(T2) as ArrayMesh):
		if t1.has(_key(v)) or v.y <= MapLayout.DINER_HEIGHT + CAP_THICKNESS + 1e-3:
			continue
		top = maxf(top, v.y)
		tall_added += 1
	assert_between(top, 4.55, 4.65, "the chimney cap is the highest added point")
	assert_gte(tall_added, 6 * 12, "the stack, band, cap, posts, plate and face stand above the roof")
	assert_gte(top - MapLayout.DINER_HEIGHT, 1.5, "at least 1.5 m of chimney above the roof")

## The new roof: wood (a world role, not gold or steak_brown), clearly unlike the tier-1 roof, and a real roof's worth of it.
func test_tier2_roof_is_a_new_palette_colour() -> void:
	var t1: ArrayMesh = load(T1)
	var t2: ArrayMesh = load(T2)
	var want := Palette.color(&"wood")
	# the tier-1 roof: the colour most up-facing vertices at roof height (3.0) sample (walls' tops are few)
	var counts := {}
	for s in t1.get_surface_count():
		var arr := t1.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		for i in v.size():
			if nrm[i].y > 0.9 and absf(v[i].y - 3.0) < 0.01 and absf(v[i].x) <= 4.0:
				var c := _color_at(t1, s, uv[i])
				counts[c] = int(counts.get(c, 0)) + 1
	var tier1_roof_color := Color.BLACK
	var best := 0
	for c in counts:
		if counts[c] > best:
			best = counts[c]
			tier1_roof_color = c
	assert_gt(best, 0, "found the tier-1 roof")
	var cap := 0
	var area := 0.0
	for s in t2.get_surface_count():
		var arr := t2.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for i in v.size():
			if absf(v[i].y - ROOF_CAP_TOP) < 1e-3:
				cap += 1
				var c := _color_at(t2, s, uv[i])
				assert_lt(absf(c.r - want.r) + absf(c.g - want.g) + absf(c.b - want.b), 0.03, "roof cap vertex %s samples %s, not wood" % [v[i], c])
				assert_gt(absf(c.r - tier1_roof_color.r) + absf(c.g - tier1_roof_color.g) + absf(c.b - tier1_roof_color.b), 0.25, "clearly unlike the tier-1 roof %s" % tier1_roof_color)
		for t in idx.size() / 3:
			var a := v[idx[t * 3]]
			var b := v[idx[t * 3 + 1]]
			var d := v[idx[t * 3 + 2]]
			var n := (b - a).cross(d - a)
			if n.y < 0.0 and absf(a.y - ROOF_CAP_TOP) < 1e-3 and absf(b.y - ROOF_CAP_TOP) < 1e-3 and absf(d.y - ROOF_CAP_TOP) < 1e-3:
				var c := _color_at(t2, s, uv[idx[t * 3]])
				if absf(c.r - want.r) + absf(c.g - want.g) + absf(c.b - want.b) < 0.03:
					area += n.length() * 0.5
	assert_gt(cap, 0, "the roof cap exists")
	assert_gt(area, 55.0, "the wood roof covers the roof out to the parapet (7.7 x 7.7 = 59 m2); a 0.5 m cap would not")

## The surface under the Archer: the highest up-facing triangle below y 4.0 that contains the perch point.
func test_tier2_surface_under_the_archer_is_the_roof_plus_the_cap() -> void:
	var p := MapLayout.guard_post(&"archer")
	var top := -1.0
	var m := load(T2) as ArrayMesh
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in idx.size() / 3:
			var a := v[idx[t * 3]]
			var b := v[idx[t * 3 + 1]]
			var c := v[idx[t * 3 + 2]]
			if (b - a).cross(c - a).y >= 0.0 or maxf(a.y, maxf(b.y, c.y)) >= 4.0:
				continue  # not up-facing (Godot's front faces wind clockwise), or not under the Archer's head
			if _in_triangle_xz(p, a, b, c):
				top = maxf(top, (a.y + b.y + c.y) / 3.0)
	assert_between(top, MapLayout.DINER_HEIGHT - 0.01, MapLayout.DINER_HEIGHT + CAP_THICKNESS + 0.01, "the Archer stands on the roof (3.0) plus at most the cap (0.03); a dais fails")
	for b in DinerArtT2.ADDED_BOXES:
		var near := Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z)).grow(0.5)
		assert_false(near.has_point(p), "no raised part within 0.5 m of the perch")

static func _in_triangle_xz(p: Vector2, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var pa := Vector2(a.x, a.z)
	var pb := Vector2(b.x, b.z)
	var pc := Vector2(c.x, c.z)
	var d1 := (p - pb).cross(pa - pb)
	var d2 := (p - pc).cross(pb - pc)
	var d3 := (p - pa).cross(pc - pa)
	return not ((d1 < 0.0 or d2 < 0.0 or d3 < 0.0) and (d1 > 0.0 or d2 > 0.0 or d3 > 0.0))

func test_tier2_tall_vertices_lie_inside_its_occluder_boxes() -> void:
	var d := _inst("res://art/env/diner_t2.tscn")
	var boxes: Array[AABB] = d.occluder_boxes
	var tall := 0
	var outside := 0
	for v in _vertices(_body(d).mesh as ArrayMesh):
		if v.y <= 3.45:
			continue
		tall += 1
		var inside := false
		for b in boxes:
			if b.grow(0.05).has_point(v):
				inside = true
				break
		if not inside:
			outside += 1
	assert_gt(tall, 0)
	assert_eq(outside, 0, "vertices above 3.45 outside the tier-2 DinerArt boxes")
	for b in boxes:
		assert_lte(b.end.z, 4.0 + 1e-3)
		assert_gte(b.position.z, -4.0 - 1e-3)
		assert_gte(b.position.x, -4.0 - 1e-3)
		assert_lte(b.end.x, 4.0 + 1e-3)
	# the added boxes match their parts: the board box is the plate plus face (z 1.7 to 1.94), not a deeper slab
	assert_almost_eq(DinerArtT2.ADDED_BOXES[1].size.z, 0.24, 1e-3)

## The committed diner_t2_top.res is the tool's box list: 24 vertices per box, in order, each part's bounding box equal.
func test_baked_roof_parts_match_the_tool_box_list() -> void:
	var m := load("res://art/env/src/diner_t2_top.res") as ArrayMesh
	assert_eq(m.get_surface_count(), 1)
	var v := m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	assert_eq(v.size(), TopTool.BOXES.size() * 24, "24 vertices per box")
	for i in TopTool.BOXES.size():
		var b: Array = TopTool.BOXES[i]
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for k in 24:
			lo = lo.min(v[i * 24 + k])
			hi = hi.max(v[i * 24 + k])
		var want_lo := Vector3(b[1] - b[4] / 2.0, b[2], b[3] - b[6] / 2.0)
		var want_hi := Vector3(b[1] + b[4] / 2.0, b[2] + b[5], b[3] + b[6] / 2.0)
		assert_true(lo.distance_to(want_lo) < 1e-4 and hi.distance_to(want_hi) < 1e-4, "part %d (%s) %s..%s, tool says %s..%s: rerun the tool and the bake" % [i, b[0], lo, hi, want_lo, want_hi])
		var want_c := Palette.color(b[0])
		var uvs := m.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		for k in 24:
			var c := _color_at(m, 0, uvs[i * 24 + k])
			assert_lt(absf(c.r - want_c.r) + absf(c.g - want_c.g) + absf(c.b - want_c.b), 0.03, "part %d vertex %d samples %s, not %s" % [i, k, c, b[0]])

# ---- camera sweeps (ruling A, fix round 1): nothing tier 2 adds hides what tier 1 does not already hide ----

## FOCUS_MIN..FOCUS_MAX every `step`, with the max edge always included (for a step that does not divide the range).
func _focus_axis(lo: float, hi: float, step: float) -> Array:
	var out := []
	var v := lo
	while v < hi - 1e-6:
		out.append(v)
		v += step
	out.append(hi)
	return out

func _foci(step: float) -> Array:
	var out := []
	for x in _focus_axis(CameraMath.FOCUS_MIN.x, CameraMath.FOCUS_MAX.x, step):
		for z in _focus_axis(CameraMath.FOCUS_MIN.y, CameraMath.FOCUS_MAX.y, step):
			out.append(Vector2(x, z))
	return out

static func _blocked(boxes: Array, from: Vector3, to: Vector3) -> bool:
	for b in boxes:
		if (b as AABB).intersects_segment(from, to) != null:
			return true
	return false

func _tier1_boxes() -> Array:
	return (_inst("res://art/env/diner.tscn").occluder_boxes as Array).duplicate()

## Camera-to-point segments of `points` that an `added` box blocks, the point is on screen, and the tier-1 building
## does not block: returns the first few as strings (an empty array passes).
## E5 tier 3 (the tier-3 camera ruling, D-279): `foci_override` replaces the step grid; `aspects` picks the windows; with `exempt_far` below INF a LANDSCAPE (aspect > 1) pair whose point lies
## farther than `exempt_far` (ground distance to the clamped focus) from the focus is not a violation but is counted in
## `stats` {"exempt": count, "nearest": the smallest exempted distance}. The defaults are the tier-2 behaviour.
func _new_occlusions(added: Array, points: Array, step: float, tier1: Array, aspects: Array = ASPECTS, exempt_far := INF, stats := {}, foci_override: Array = []) -> Array:
	var bad := []
	var foci := foci_override if not foci_override.is_empty() else _foci(step)
	stats["exempt"] = 0
	stats["nearest"] = INF
	for aspect in aspects:
		var proj := CameraMath.projection(Balance.ui, aspect)
		for f in foci:
			var xf := CameraMath.camera_transform(CameraMath.focus_for(f), Balance.ui)
			var from := xf.origin
			for p in points:
				if not _blocked(added, from, p):
					continue
				if not CameraMath.on_screen(p, xf, proj):
					continue
				if _blocked(tier1, from, p):
					continue
				if aspect > 1.0 and exempt_far < INF:
					var d := Vector2(p.x, p.z).distance_to(CameraMath.focus_for(f))
					if d > exempt_far:
						stats["exempt"] += 1
						stats["nearest"] = minf(stats["nearest"], d)
						continue
				bad.append("aspect %.2f focus %s point %s" % [aspect, f, p])
				if bad.size() >= 5:
					return bad
	return bad

func _archer_points() -> Array:
	var feet := MapLayout.to3(MapLayout.guard_post(&"archer"), MapLayout.DINER_HEIGHT)
	return [feet + Vector3(0, 0.3, 0), feet + Vector3(0, Guard.AIM_HEIGHT, 0), feet + Vector3(0, Guard.BAR_Y, 0)]

## Whenever the Archer (feet + 0.3, aim point, head) is on screen the segment to the camera misses every added part.
## 1 m focus grid, 4 aspects. (The roof-skip in OccluderFade means a hidden Archer would never fade the diner.)
func test_added_roof_parts_never_hide_the_archer() -> void:
	var t0 := Time.get_unix_time_from_system()
	var bad := _new_occlusions(DinerArtT2.ADDED_BOXES, _archer_points(), 1.0, [])
	gut.p("archer sweep: %d foci x 4 aspects x 3 points, %.1f s" % [_foci(1.0).size(), Time.get_unix_time_from_system() - t0])
	assert_eq(bad.size(), 0, "the added parts hide the Archer: %s" % [bad])
	# positive control: the first version's mid-roof board hides the Archer, so this sweep can fail
	assert_gt(_new_occlusions([AABB(Vector3(-1.5, 3, -1.3), Vector3(3, 2.4, 0.4))], _archer_points(), 1.0, []).size(), 0, "the sweep detects a bad board")

func _ground_ring(heights: Array) -> Array:
	var pts := []
	var x := -14.0
	while x <= 14.0 + 1e-6:
		var z := -14.0
		while z <= 14.0 + 1e-6:
			if maxf(absf(x), absf(z)) > MapLayout.DINER_HALF + 1e-6:
				for y in heights:
					pts.append(Vector3(x, y, z))
			z += 0.5
		x += 0.5
	return pts

## Ground points (y 0, 0.5, 1.0, 0.5 m grid, 4 < max(|x|,|z|) <= 14): an added part blocks one only if tier 1 does too.
## 2 m focus grid (a 1 m grid is 4x the time in GDScript), 4 aspects.
func test_added_roof_parts_hide_no_new_ground() -> void:
	var t0 := Time.get_unix_time_from_system()
	var pts := _ground_ring([0.0, 0.5, 1.0])
	var bad := _new_occlusions(DinerArtT2.ADDED_BOXES, pts, 2.0, _tier1_boxes())
	gut.p("ground sweep: %d foci x 4 aspects x %d points, %.1f s" % [_foci(2.0).size(), pts.size(), Time.get_unix_time_from_system() - t0])
	assert_eq(bad.size(), 0, "the added parts hide ground that tier 1 leaves visible: %s" % [bad])
	# positive control: the first version's 6.1 m north-west chimney hides ground tier 1 leaves visible
	assert_gt(_new_occlusions([AABB(Vector3(-3.475, 3, -3.475), Vector3(0.95, 3.1, 0.95))], pts, 2.0, _tier1_boxes()).size(), 0, "the sweep detects a bad chimney")

## The tower pads (tier-3 Task 19 reuses this with its own added boxes): pad centres at y 0 and 0.5, 1 m focus grid.
func test_added_roof_parts_never_hide_the_tower_pads() -> void:
	var pts := []
	for id in ["tower_nw", "tower_ne"]:
		var xz: Vector2 = MapLayout.TOWER_SPOTS[id]
		for y in [0.0, 0.5]:
			pts.append(MapLayout.to3(xz, y))
	var bad := _new_occlusions(DinerArtT2.ADDED_BOXES, pts, 1.0, _tier1_boxes())
	assert_eq(bad.size(), 0, "the added parts hide a tower pad that tier 1 leaves visible: %s" % [bad])
	assert_gt(_new_occlusions([AABB(Vector3(-3.475, 3, -3.475), Vector3(0.95, 3.1, 0.95))], pts, 1.0, _tier1_boxes()).size(), 0, "the sweep detects a bad chimney")



# ---- E5 tier-3 Task 19: the diner's second storey (D-268, the tier-3 camera ruling D-279) ----
# The storey is the tier-3 silhouette change. Camera rule (D-279): (a1) at the portrait aspects the added parts never newly hide a
# static point; (a2) at the landscape aspects only a point more than 10 m from the focus may be newly hidden; (a3) the Archer may be
# hidden by an added part only where the building then fades (OccluderFade tests roof actors against the parts above the roof);
# (b) ground the parts newly hide fades the building for an actor standing there; (c) nothing overhangs, the storey is set back
# (|x|, |z| <= 3.0); (d) the top is at least 6.0 m (lantern posts included).

const T3 := "res://art/env/baked/diner_t3.res"
const T3Tool := preload("res://tools/make_diner_t3_src.gd")
const DinerArtT3 := preload("res://art/env/diner_art_t3.gd")
const PORTRAIT := [9.0 / 21.0, 9.0 / 16.0]
const LANDSCAPE := [16.0 / 9.0, 21.0 / 9.0]
const EXEMPT_DIST := 10.0

func _top_y(mesh: ArrayMesh, only_new_vs: ArrayMesh = null) -> float:
	var known := {}
	if only_new_vs != null:
		for v in _vertices(only_new_vs):
			known[_key(v)] = true
	var top := 0.0
	for v in _vertices(mesh):
		if not known.has(_key(v)):
			top = maxf(top, v.y)
	return top

## Added vertices (not in the tier-1 mesh) above the terrace: inside the footprint; those above the roof cap inside the storey's
## |x|, |z| <= 3.0 (set back from the 4.0 footprint); the measured count is the tool boxes' 24 vertices each minus the 12 that coincide with tier 1.
func test_tier3_adds_nothing_outside_the_footprint_and_the_storey_is_set_back() -> void:
	var t1 := {}
	for v in _vertices(load(T1) as ArrayMesh):
		t1[_key(v)] = true
	var added := 0
	var above_cap := 0
	for v in _vertices(load(T3) as ArrayMesh):
		if v.y <= 0.02 or t1.has(_key(v)):
			continue
		added += 1
		assert_lte(absf(v.x), 4.0 + 1e-3, "added vertex %s overhangs in x" % v)
		assert_lte(absf(v.z), 4.0 + 1e-3, "added vertex %s overhangs in z" % v)
		if v.y > ROOF_CAP_TOP + 1e-3:
			above_cap += 1
			# set back to |x|, |z| <= 3.0; the windows are 1 cm plates on the walls (3.01)
			assert_lte(absf(v.x), 3.0 + 0.011, "storey vertex %s is not set back (x)" % v)
			assert_lte(absf(v.z), 3.0 + 0.011, "storey vertex %s is not set back (z)" % v)
	assert_eq(added, T3Tool.BOXES.size() * 24 - 12, "every tool box adds new vertices except 12 that coincide with tier 1")
	assert_eq(above_cap, (T3Tool.BOXES.size() - 1) * 24 - 12, "every box but the roof cap stands above it, except the 12 bottom-ring vertices of the walls that sit at cap height")

## (d): the top is the lamp cap at 6.08, clearly above tier 1's 5.1 m sign plank and tier 2's 4.6; the storey (walls and rim) ends at 5.10 and the short lantern at 5.38.
func test_tier3_diner_is_within_the_triangle_budget() -> void:
	var tris := _triangles(load(T3) as ArrayMesh)
	gut.p("tier-3 diner triangles: %d (budget 12000)" % tris)
	assert_lte(tris, ArtBudgets.budget_for("res://art/env/diner.tscn"))
	assert_lte(tris, 12000)

## The fade's roof-body offsets (literals: components must not depend on actors) are the guard's own heights relative to the aim point.
func test_the_fade_roof_body_offsets_match_the_guard_constants() -> void:
	assert_eq(OccluderFade.ROOF_BODY_OFFSETS, [0.3 - Guard.AIM_HEIGHT, 0.0, Guard.BAR_Y - Guard.AIM_HEIGHT], "feet + 0.3, the aim point, the head bar")

func test_tier3_diner_is_clearly_taller_than_tiers_1_and_2() -> void:
	var t1: ArrayMesh = load(T1)
	var t2: ArrayMesh = load(T2)
	var t3: ArrayMesh = load(T3)
	assert_almost_eq(t1.get_aabb().end.y, 5.1, 0.01, "tier 1's sign plank is the tier-1 top")
	assert_between(t3.get_aabb().end.y, 6.0, 6.2, "tier 3's top, lantern posts included (rule d)")
	assert_gte(t3.get_aabb().end.y, t1.get_aabb().end.y + 0.9)
	assert_gte(_top_y(t3, t1), _top_y(t2, t1) + 1.4, "the new top is well above what tier 2 added (4.6)")
	var storey := DinerArtT3.ADDED_BOXES[0]
	assert_almost_eq(storey.end.y, 5.10, 1e-3, "storey top (the first limit was about 5.178; with a 5 cm margin it is 5.10)")
	assert_lte(storey.end.y, 5.10 + 1e-4)
	assert_gte(storey.end.y - MapLayout.DINER_HEIGHT, 2.0, "still a storey of at least 2.0 m")
	assert_almost_eq(DinerArtT3.ADDED_BOXES[2].end.y, 5.38, 1e-3, "the south-west lantern top (first limit about 5.544)")
	assert_gte(DinerArtT3.ADDED_BOXES[1].end.y, 6.0, "the lamp tops the diner (rule d)")
	for i in [0, 2, 3, 4]:
		assert_lt(DinerArtT3.ADDED_BOXES[i].end.y, DinerArtT3.ADDED_BOXES[1].end.y, "the lamp is the highest part")
	assert_gte(storey.end.y - MapLayout.DINER_HEIGHT, 2.0 - 1e-3, "a storey at least 2.0 m above the roof")
	assert_gte(storey.size.x * storey.size.z, 12.0, "a footprint of at least 12 m2")
	for b in DinerArtT3.ADDED_BOXES:
		assert_lte(b.end.y, 6.1)

## The committed diner_t3_top.res is the tool's box list; every part samples its palette colour; gold and warm_white (the hero's) are absent.
func test_tier3_baked_parts_match_the_tool_box_list_and_palette() -> void:
	var m := load("res://art/env/src/diner_t3_top.res") as ArrayMesh
	assert_eq(m.get_surface_count(), 1)
	var arrays := m.surface_get_arrays(0)
	var v := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	assert_eq(v.size(), T3Tool.BOXES.size() * 24)
	var banned := [Palette.color(&"gold"), Palette.color(&"warm_white"), Palette.color(&"gold_dark"), Palette.color(&"steak_brown")]
	var lantern_glass := 0
	for i in T3Tool.BOXES.size():
		var b: Array = T3Tool.BOXES[i]
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for k in 24:
			lo = lo.min(v[i * 24 + k])
			hi = hi.max(v[i * 24 + k])
		var want_lo := Vector3(b[1] - b[4] / 2.0, b[2], b[3] - b[6] / 2.0)
		var want_hi := Vector3(b[1] + b[4] / 2.0, b[2] + b[5], b[3] + b[6] / 2.0)
		assert_true(lo.distance_to(want_lo) < 1e-4 and hi.distance_to(want_hi) < 1e-4, "part %d (%s) %s..%s, tool says %s..%s: rerun the tool and the bake" % [i, b[0], lo, hi, want_lo, want_hi])
		var want_c := Palette.color(b[0])
		for k in 24:
			var c := _color_at(m, 0, uvs[i * 24 + k])
			assert_lt(absf(c.r - want_c.r) + absf(c.g - want_c.g) + absf(c.b - want_c.b), 0.03, "part %d vertex %d samples %s, not %s" % [i, k, c, b[0]])
			for bc in banned:
				assert_gt(absf(c.r - bc.r) + absf(c.g - bc.g) + absf(c.b - bc.b), 0.03, "part %d wears a hero or reward colour" % i)
		if b[0] == &"diner_cream" and b[2] >= 4.5 and b[4] < 0.3:
			lantern_glass += 1
	assert_eq(lantern_glass, 4, "four lantern glasses in the diner's trim colour (the atlas has no warm `dirt` texel)")

## Tier 3 omits tier 1's sign plank and its two posts (the "DINER" label moves onto the storey's south wall) and adds nothing but
## the terraces and the top mesh: allow-lists both ways.
func test_tier3_source_copies_the_tier1_source_and_keeps_the_terraces() -> void:
	var s1 := (load("res://art/env/src/diner_src.tscn") as PackedScene).instantiate() as Node3D
	var s3 := (load("res://art/env/src/diner_t3_src.tscn") as PackedScene).instantiate() as Node3D
	add_child_autofree(s1)
	add_child_autofree(s3)
	var omitted := ["sign_plank", "post_l", "post_r"]
	var seen_omitted := 0
	for c in s1.get_children():
		var d := s3.get_node_or_null(NodePath(c.name)) as Node3D
		if str(c.name) in omitted:
			seen_omitted += 1
			assert_null(d, "tier-3 source omits %s (it would hide the storey's south wall)" % c.name)
			continue
		assert_not_null(d, "tier-3 source has %s" % c.name)
		if d != null:
			assert_eq(d.transform, (c as Node3D).transform, "%s transform" % c.name)
			assert_eq(d.scene_file_path, c.scene_file_path, "%s scene" % c.name)
	assert_eq(seen_omitted, 3, "all three omitted names exist in the tier-1 source")
	var extra := []
	for c in s3.get_children():
		if s1.get_node_or_null(NodePath(c.name)) == null:
			extra.append(str(c.name))
	extra.sort()
	assert_eq(extra, ["terrace_e", "terrace_w", "top"], "tier 3 adds only the terraces and the top mesh")
	assert_eq((s3.get_node("top") as MeshInstance3D).mesh.resource_path, "res://art/env/src/diner_t3_top.res")

## The plank is gone from the bake and the "DINER" label sits on the storey's south wall, inside it and fitting its width.
func test_tier3_sign_is_on_the_storey_wall_and_the_plank_is_gone() -> void:
	var d := _inst("res://art/env/diner_t3.tscn")
	for v in _vertices(_body(d).mesh as ArrayMesh):
		if v.y > 3.45:
			assert_lte(v.z, 3.05 + 1e-3, "vertex %s: nothing tall in front of the storey's south wall (the tier-1 plank stood at z 3.4 to 3.8)" % v)
	var board := d.get_node("Board") as WorldLabel
	assert_eq(board.text, tr("DINER"))
	var storey := DinerArtT3.ADDED_BOXES[0]
	assert_between(board.position.x, storey.position.x + 0.5, storey.end.x - 0.5, "centred on the wall")
	assert_between(board.position.y, 3.5, 4.95, "on the wall, below the rim")
	assert_between(board.position.z, 3.0, 3.2, "just in front of the south wall (z 3.0)")
	assert_lte(board.get_aabb().size.x, 3.3, "the text fits the 3.5 m wall with a margin (font 90 unchanged)")
	for b in d.occluder_boxes:
		assert_ne(b, DinerArtT3.TIER1_PLANK_BOX, "the plank's occluder box is not part of tier 3")

## The storey's roof is a lighter panel inside a wood_dark rim (a second roof at 40% scale), lower than the rim.
func test_tier3_storey_roof_is_a_light_panel_inside_a_dark_rim() -> void:
	var panel: Array = []
	var rims: Array = []
	for b in T3Tool.BOXES:
		if b[2] == 4.95 and b[0] == &"diner_cream":
			panel = b
		elif b[2] == 4.95 and b[0] == &"wood_dark":
			rims.append(b)
	assert_eq(panel.size(), 7, "one cream roof panel")
	assert_eq(rims.size(), 4, "four rim strips")
	assert_almost_eq(panel[2] + panel[5], 5.05, 1e-4, "panel top")
	for r in rims:
		assert_almost_eq(r[2] + r[5], 5.10, 1e-4, "rim top is 5 cm above the panel")
		assert_lte(absf(r[1] - panel[1]) - r[4] / 2.0, panel[4] / 2.0 + 1e-4)
	assert_lt(Palette.color(&"wood_dark").v, Palette.color(&"diner_cream").v - 0.3, "light inside dark")

## The surface under the Archer is the roof plus the cap, as at tier 2 (the storey and the lanterns stay away from the perch).
func test_tier3_surface_under_the_archer_is_the_roof_plus_the_cap() -> void:
	var p := MapLayout.guard_post(&"archer")
	var top := -1.0
	var m := load(T3) as ArrayMesh
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in idx.size() / 3:
			var a := v[idx[t * 3]]
			var b := v[idx[t * 3 + 1]]
			var c := v[idx[t * 3 + 2]]
			if (b - a).cross(c - a).y >= 0.0 or maxf(a.y, maxf(b.y, c.y)) >= 4.0:
				continue
			if _in_triangle_xz(p, a, b, c):
				top = maxf(top, (a.y + b.y + c.y) / 3.0)
	assert_between(top, MapLayout.DINER_HEIGHT - 0.01, MapLayout.DINER_HEIGHT + CAP_THICKNESS + 0.01, "the Archer stands on the roof (3.0) plus at most the cap")
	for b in DinerArtT3.ADDED_BOXES:
		var near := Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z)).grow(0.5)
		assert_false(near.has_point(p), "no raised part within 0.5 m of the perch")

func test_tier3_tall_vertices_lie_inside_its_occluder_boxes_and_the_fade_covers_every_mesh() -> void:
	var d := _inst("res://art/env/diner_t3.tscn")
	var boxes: Array[AABB] = d.occluder_boxes
	assert_eq(boxes.size(), 2 + DinerArtT3.ADDED_BOXES.size(), "the tier-1 walls and chimney boxes (the plank's is dropped) plus the storey and four lanterns")
	var tall := 0
	for v in _vertices(_body(d).mesh as ArrayMesh):
		if v.y <= 3.45:
			continue
		tall += 1
		var inside := false
		for b in boxes:
			if b.grow(0.05).has_point(v):
				inside = true
				break
		assert_true(inside, "vertex %s above 3.45 is outside every tier-3 DinerArt box" % v)
	assert_gt(tall, 0)
	for b in DinerArtT3.ADDED_BOXES:
		assert_lte(b.end.y, 6.1)
		assert_lte(maxf(absf(b.position.x), maxf(absf(b.end.x), maxf(absf(b.position.z), absf(b.end.z)))), 4.0 + 1e-3)
	# the fade's set: its boxes are the art's, and fading touches every MeshInstance3D of the building
	var rig := _fade_rig("res://art/env/diner_t3.tscn")
	var fade: OccluderFade = rig.fade
	assert_eq(fade.boxes().size(), 7, "the fade's box count at tier 3: 2 tier-1 boxes, the storey and 4 lanterns")
	rig.cam.global_transform = CameraMath.camera_transform(CameraMath.focus_for(Vector2(0, -4.6)), Balance.ui)
	rig.targets.append(Vector3(0, 0.5, -4.6))
	for i in 20:
		fade._process(1.0 / 60.0)
	assert_true(fade.is_faded())
	var meshes: Array = rig.visual.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0)
	for m in meshes:
		for i in (m as MeshInstance3D).mesh.get_surface_count():
			var mat := (m as MeshInstance3D).get_surface_override_material(i) as BaseMaterial3D
			assert_not_null(mat, "%s surface %d is faded" % [m.name, i])
			if mat != null:
				assert_almost_eq(mat.albedo_color.a, Balance.ui.occluder_alpha, 1e-3)

## A fade over a diner art scene with a real camera, as the world wires it (art child of the Visual, OccluderFade beside it).
func _fade_rig(scene_path: String) -> Dictionary:
	var vis := Visuals.visual_root()
	add_child_autofree(vis)
	vis.add_child((load(scene_path) as PackedScene).instantiate() as Node3D)
	var cam := Camera3D.new()
	add_child_autofree(cam)
	var targets := []
	var fade := OccluderFade.new()
	vis.add_child(fade)
	fade.setup(AABB(), func(): return cam, func(): return targets)
	return {"fade": fade, "cam": cam, "targets": targets, "visual": vis}

func _faded_at(rig: Dictionary, focus: Vector2, aim: Vector3) -> bool:
	rig.cam.global_transform = CameraMath.camera_transform(CameraMath.focus_for(focus), Balance.ui)
	rig.targets.clear()
	rig.targets.append(aim)
	return rig.fade._any_occluded(Balance.ui.occluder_grow)

## Pad-like points (spots, branch pads, telegraph marker feet) at y 0.0 to 0.5 in 0.05 steps: the reviewer's slivers lay between the
## old samples 0 and 0.5. `north_only` keeps the ones north of z = -3 (where the storey's shadow edge passes at the HOME framings).
func _pad_points(north_only := false) -> Array:
	var xzs := []
	for id in MapLayout.spots_for_tier(3):
		xzs.append(MapLayout.spot_position(id))  # tower pads and the fence spots' marker centres
	for id in MapLayout.BRANCH_PADS:
		xzs.append_array(MapLayout.BRANCH_PADS[id])
	for lane in MapLayout.lanes_for_tier(3):
		xzs.append(MapLayout.telegraph_spot(lane))  # north, west, east and sw telegraph marker feet
	var pts := []
	for xz in xzs:
		if north_only and xz.y >= -3.0:
			continue
		for k in 11:
			pts.append(MapLayout.to3(xz, k * 0.05))
	return pts

func _static_points_t3() -> Array:
	var pts := _pad_points()
	var spots := [MapLayout.SIGN, MapLayout.HOME, MapLayout.TIER_SIGNS[2], MapLayout.TIER_SIGNS[3], MapLayout.COUNTER, MapLayout.COUNTER_DROP,
		MapLayout.FREEZER, MapLayout.FREEZER_ZONE, MapLayout.SERVICE_POINT, MapLayout.DINER_DOOR]
	for xz in spots:
		for y in [0.0, 0.5, 1.0, 1.95]:
			pts.append(MapLayout.to3(xz, y))
	for k in MapLayout.STATION_PADS:
		for y in [0.0, 0.5]:
			pts.append(MapLayout.to3(MapLayout.STATION_PADS[k], y))
	return pts

## The tier-3 building's own base boxes (the tier-1 walls and chimney, no plank): what is hidden by them anyway is not "new".
func _t3_base_boxes() -> Array:
	var out := (_inst("res://art/env/diner_t3.tscn").occluder_boxes as Array).duplicate()
	for b in DinerArtT3.ADDED_BOXES:
		out.erase(b)
	return out

## The foci where the storey's shadow edge passes a pad at the portrait framings (focus z 6.5 to 8.0, every 0.05; x every 0.1).
func _fine_foci() -> Array:
	var out := []
	var x := CameraMath.FOCUS_MIN.x
	while x <= CameraMath.FOCUS_MAX.x + 1e-6:
		var z := 6.5
		while z <= 8.0 + 1e-6:
			out.append(Vector2(x, z))
			z += 0.05
		x += 0.1
	return out

func _grown(boxes: Array, by: float) -> Array:
	var out := []
	for b in boxes:
		out.append((b as AABB).grow(by))
	return out

## (a1) portrait: strict, every focus on a 1 m grid; the Archer included (feet + 0.3, aim, head). Static points are sampled every
## 5 cm of height (0 to 0.5) and a fine second pass walks the focus band where the shadow edge passes.
func test_tier3_parts_hide_no_static_point_at_portrait_aspects() -> void:
	var t0 := Time.get_unix_time_from_system()
	var pts := _static_points_t3()
	pts.append_array(_archer_points())
	var base := _t3_base_boxes()
	var bad := _new_occlusions(DinerArtT3.ADDED_BOXES, pts, 1.0, base, PORTRAIT)
	assert_eq(bad.size(), 0, "the tier-3 parts newly hide a static point at a portrait aspect: %s" % [bad])
	# the Archer is strict even against the base building (the filter above would excuse his feet point)
	assert_eq(_new_occlusions(DinerArtT3.ADDED_BOXES, _archer_points(), 1.0, [], PORTRAIT).size(), 0, "the Archer is never hidden at a portrait aspect")
	var t1 := Time.get_unix_time_from_system()
	var fine := _new_occlusions(DinerArtT3.ADDED_BOXES, _pad_points(true), 1.0, base, PORTRAIT, INF, {}, _fine_foci())
	assert_eq(fine.size(), 0, "fine pass: a part hides a pad sliver at a portrait aspect: %s" % [fine])
	var t2 := Time.get_unix_time_from_system()
	# a margin: every added box grown by 5 cm still hides nothing (coarse and fine)
	var grown_bad := _new_occlusions(_grown(DinerArtT3.ADDED_BOXES, 0.05), pts, 1.0, base, PORTRAIT)
	assert_eq(grown_bad.size(), 0, "with every added box grown by 5 cm a static point is hidden (no margin): %s" % [grown_bad])
	var grown_fine := _new_occlusions(_grown(DinerArtT3.ADDED_BOXES, 0.05), _pad_points(true), 1.0, base, PORTRAIT, INF, {}, _fine_foci())
	assert_eq(grown_fine.size(), 0, "fine pass with 5 cm grown boxes: %s" % [grown_fine])
	gut.p("portrait sweep: coarse %.1f s, fine %.1f s, grown %.1f s" % [t1 - t0, t2 - t1, Time.get_unix_time_from_system() - t2])
	# positive control: a part the scan rejected: a roof lantern on the north-east corner hides the fence_n and branch pads
	var ne_roof_lantern := AABB(Vector3(0.66, 5.2, -0.5), Vector3(0.34, 0.5, 0.34))
	assert_gt(_new_occlusions([ne_roof_lantern], pts, 1.0, base, PORTRAIT).size(), 0, "the sweep detects a rejected lantern")

## The reviewer's three slivers, which the old heights (rim 5.2, south-west lantern top 5.67) hid between the sampled pad heights 0
## and 0.5 at the 9:16 framing. Each is hidden by the OLD box and by none of the current ones. Mutation: put the old heights back.
func test_tier3_regression_slivers_the_old_heights_hid() -> void:
	var old_rim := AABB(Vector3(-2.5, 3.03, -0.5), Vector3(3.5, 2.17, 3.5))              # top 5.2
	var old_lantern := AABB(Vector3(-2.5, 5.2, 2.66), Vector3(0.34, 0.47, 0.34))        # top 5.67
	var cases := [
		["above the fence_w pad", Vector2(3.70, 7.78), Vector3(-6.1, 0.35, -6.1), old_lantern],
		["above a fence_n pad", Vector2(-5.0, 8.0), Vector3(2.5, 0.16, -10.4), old_rim],
		["the north telegraph marker's foot", Vector2(0.0, 8.0), Vector3(0.0, 0.0, -10.7), old_rim],
	]
	assert_lt(MapLayout.to3(MapLayout.telegraph_spot("north")).distance_to(Vector3(0, 0, -10.7)), 1e-3, "the third point is the north telegraph marker")
	for c in cases:
		var xf := CameraMath.camera_transform(CameraMath.focus_for(c[1]), Balance.ui)
		assert_true((c[3] as AABB).intersects_segment(xf.origin, c[2]) != null, "%s: the old box hides it" % c[0])
		assert_false(_blocked(DinerArtT3.ADDED_BOXES, xf.origin, c[2]), "%s: no current part hides it" % c[0])
		assert_false(_blocked(_grown(DinerArtT3.ADDED_BOXES, 0.05), xf.origin, c[2]), "%s: nor with a 5 cm margin" % c[0])

## (a2) landscape: a static point may be newly hidden only farther than 10 m from the focus; the exempted pairs are counted.
func test_tier3_parts_hide_no_static_point_within_10_m_at_landscape_aspects() -> void:
	var pts := _static_points_t3()
	var stats := {}
	var bad := _new_occlusions(DinerArtT3.ADDED_BOXES, pts, 1.0, _t3_base_boxes(), LANDSCAPE, EXEMPT_DIST, stats)
	gut.p("landscape exemption: %d pairs hidden beyond %.0f m, nearest %.2f m" % [stats["exempt"], EXEMPT_DIST, stats["nearest"]])
	assert_eq(bad.size(), 0, "the tier-3 parts hide a static point within 10 m of the focus at a landscape aspect: %s" % [bad])
	assert_gt(float(stats["nearest"]), 13.0, "no exempted pair is within 13 m (measured nearest 13.07 m; none is within the 10 m rule)")
	assert_gt(int(stats["exempt"]), 0, "the exemption is live: some far pads are hidden at landscape")
	# positive control: a 3 m storey (top 6.03) hides pads within 10 m of the focus at a landscape aspect
	var too_tall := AABB(Vector3(-2.5, 3.03, -0.5), Vector3(3.5, 3.0, 3.5))
	assert_gt(_new_occlusions([too_tall], pts, 1.0, _t3_base_boxes(), LANDSCAPE, EXEMPT_DIST).size(), 0, "the sweep detects a storey that is too tall")

## The Archer's feet + 0.3, aim and head, at every aspect and focus: the pairs an added part hides him in.
func _archer_hidden_pairs(added: Array, aspects: Array, step: float) -> Array:
	var out := []
	var pts := _archer_points()
	for aspect in aspects:
		var proj := CameraMath.projection(Balance.ui, aspect)
		for f in _foci(step):
			var xf := CameraMath.camera_transform(CameraMath.focus_for(f), Balance.ui)
			for p in pts:
				if _blocked(added, xf.origin, p) and CameraMath.on_screen(p, xf, proj):
					out.append([aspect, f, p])
					break
	return out

## (a3) wherever an added part hides the Archer (any of his three points) the building fades for him, through the fade component
## (an actor standing on the roof is tested against the parts above it); portrait never hides him.
func test_tier3_where_the_storey_hides_the_archer_the_building_fades() -> void:
	var rig := _fade_rig("res://art/env/diner_t3.tscn")
	var feet := MapLayout.to3(MapLayout.guard_post(&"archer"), MapLayout.DINER_HEIGHT)
	var aim := feet + Vector3(0, Guard.AIM_HEIGHT, 0)
	assert_eq(_archer_hidden_pairs(DinerArtT3.ADDED_BOXES, PORTRAIT, 1.0).size(), 0, "portrait: he is never hidden")
	var pairs := _archer_hidden_pairs(DinerArtT3.ADDED_BOXES, LANDSCAPE, 1.0)
	gut.p("Archer hidden by an added part at landscape: %d (aspect, focus) pairs" % pairs.size())
	assert_gt(pairs.size(), 0, "the test is live: at landscape the storey does hide him from far-west / south foci")
	var unfaded := []
	var per_aspect := {}
	for pr in pairs:
		if not _faded_at(rig, pr[1], aim):
			unfaded.append("aspect %.2f focus %s point %s" % [pr[0], pr[1], pr[2]])
		per_aspect[pr[0]] = int(per_aspect.get(pr[0], 0)) + 1
	assert_eq(unfaded.size(), 0, "the Archer is hidden with no fade: %d pairs, first %s" % [unfaded.size(), unfaded.slice(0, 5)])
	# the real path: _process fades the building (not just the predicate) for a sample of such foci at each aspect
	for aspect in per_aspect:
		var n := 0
		for pr in pairs:
			if pr[0] != aspect or n >= 3:
				continue
			n += 1
			rig.fade._alpha = 1.0
			rig.fade._apply()
			assert_true(_faded_at(rig, pr[1], aim))
			for i in 20:
				rig.fade._process(1.0 / 60.0)
			assert_true(rig.fade.is_faded(), "aspect %.2f focus %s: the building fades and the Archer is visible through it" % [aspect, pr[1]])
	# positive control: with the roof-part check disabled he is hidden and nothing fades
	rig.fade._roof_boxes.clear()
	var silent := 0
	for pr in pairs:
		if not _faded_at(rig, pr[1], aim):
			silent += 1
	assert_eq(silent, pairs.size(), "without the roof-part boxes the Archer is hidden with no fade in every one of the %d pairs" % pairs.size())

## Wherever the Archer is on screen at a portrait aspect, he alone never fades the building (the sweep says no part hides him there).
func test_tier3_the_archer_alone_does_not_fade_the_building_at_portrait_aspects() -> void:
	var rig := _fade_rig("res://art/env/diner_t3.tscn")
	var feet := MapLayout.to3(MapLayout.guard_post(&"archer"), MapLayout.DINER_HEIGHT)
	var checked := 0
	for aspect in PORTRAIT:
		var proj := CameraMath.projection(Balance.ui, aspect)
		for f in _foci(1.0):
			var xf := CameraMath.camera_transform(CameraMath.focus_for(f), Balance.ui)
			if not CameraMath.on_screen(feet + Vector3(0, 1.0, 0), xf, proj):
				continue
			checked += 1
			assert_false(_faded_at(rig, f, feet + Vector3(0, Guard.AIM_HEIGHT, 0)), "the Archer alone fades the diner at aspect %.2f focus %s" % [aspect, f])
	assert_gt(checked, 100)

## Tiers 1 and 2: the fade never triggers on the Archer alone, at any focus and aspect (they have no parts the Archer can hide behind).
func test_tier2_and_tier1_fade_never_triggers_on_the_archer_alone() -> void:
	var feet := MapLayout.to3(MapLayout.guard_post(&"archer"), MapLayout.DINER_HEIGHT)
	for path in ["res://art/env/diner.tscn", "res://art/env/diner_t2.tscn"]:
		var rig := _fade_rig(path)
		var checked := 0
		for aspect in ASPECTS:
			var proj := CameraMath.projection(Balance.ui, aspect)
			for f in _foci(1.0):
				for dy in [0.3, Guard.AIM_HEIGHT, Guard.BAR_Y]:
					assert_false(_faded_at(rig, f, feet + Vector3(0, dy, 0)), "%s: the Archer alone fades the diner (aspect %.2f focus %s)" % [path, aspect, f])
					checked += 1
		assert_gt(checked, 1000)

## (b) ground the added parts newly hide (0.5 m grid, y 0 / 0.5 / 1.0, out to 14 m, foci every 2 m, all four aspects) is not empty
## and an actor standing on EVERY such point fades the building (seen from the focus that newly hides it). The set lies off to the
## sides (x -14 to 13.5, z -10.5 to 2.5): none of it is in the north zone, on the north lane or on the west zone, where tier 1's walls
## already hide everything the storey could; the test prints the nearest hidden point to each of those three places.
func test_tier3_ground_the_storey_newly_hides_fades_the_building() -> void:
	var added := DinerArtT3.ADDED_BOXES
	var tier1 := _t3_base_boxes()
	var rig := _fade_rig("res://art/env/diner_t3.tscn")
	var hidden := {}  # Vector3 -> first focus that newly hides it
	var pairs := 0
	var t0 := Time.get_unix_time_from_system()
	var ring := _ground_ring([0.0, 0.5, 1.0])
	for aspect in ASPECTS:
		var proj := CameraMath.projection(Balance.ui, aspect)
		for f in _foci(2.0):
			var xf := CameraMath.camera_transform(CameraMath.focus_for(f), Balance.ui)
			for p in ring:
				if _blocked(added, xf.origin, p) and CameraMath.on_screen(p, xf, proj) and not _blocked(tier1, xf.origin, p):
					pairs += 1
					if not hidden.has(p):
						hidden[p] = f
	gut.p("ground newly hidden by the tier-3 parts: %d points, %d (point, focus, aspect) pairs, %.1f s" % [hidden.size(), pairs, Time.get_unix_time_from_system() - t0])
	assert_gt(hidden.size(), 0, "the storey is tall: it newly hides some ground (not empty)")
	# every such ground point fades the building for an actor standing on it, seen from the focus that newly hides it
	var silent := []
	for p in hidden:
		if not _faded_at(rig, hidden[p], p):
			silent.append("%s from focus %s" % [p, hidden[p]])
	assert_eq(silent.size(), 0, "ground the parts hide that does not fade the building: %s" % [silent.slice(0, 5)])
	# the samples the author asked about: the hidden point nearest to the north zone's centre, the north lane and the west wall
	var north_reach := 0.0
	for p in hidden:
		north_reach = minf(north_reach, p.z)
	var names := {"north zone": Vector2(0, -4.6), "north lane": Vector2(0, -9.0), "west wall": Vector2(-4.6, 0.0)}
	for n in names:
		var best = null
		for p in hidden:
			if best == null or Vector2(p.x, p.z).distance_to(names[n]) < Vector2(best.x, best.z).distance_to(names[n]):
				best = p
		var d := Vector2(best.x, best.z).distance_to(names[n])
		gut.p("nearest newly hidden ground to the %s: %s (%.1f m away), from focus %s" % [n, best, d, hidden[best]])
		assert_true(_faded_at(rig, hidden[best], best), "an actor at %s fades the diner" % best)
	gut.p("northmost newly hidden ground: z %.1f" % north_reach)
