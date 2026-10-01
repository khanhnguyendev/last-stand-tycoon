extends GutTest
## S4 Task 12 (D-194/D-197, D-201): the level changes the model; resume into DAY shows the saved level; the marker shows
## only at level 0 in DAY; every runtime scene is one baked mesh and the committed bakes match their sources.

const Bake := preload("res://tools/bake_static.gd")
const ENV := "res://art/env/"
const NAMES := ["tower_l1", "tower_l2", "tower_l3", "fence_l1", "fence_l2", "fence_l3", "fence_rubble", "spot_marker",
	"closeup_sign", "telegraph_flag", "lane_gate"]

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	GameState.new_game(5)
	main.hero.input.player_control = false
	main.hero.teleport(Vector2(20, 10))  # out of the way

func _top(n: Node3D) -> float:
	var box := AABB()
	for vi in n.find_children("*", "VisualInstance3D", true, false):
		var a: AABB = (vi as VisualInstance3D).global_transform * (vi as VisualInstance3D).get_aabb()
		box = a if box.size == Vector3.ZERO else box.merge(a)
	return box.end.y

func _height(path: String) -> float:
	var n: Node3D = load(path).instantiate()
	add_child_autofree(n)
	return _top(n)

func _surfaces(n: Node) -> int:
	var count := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible and (mi as MeshInstance3D).mesh != null:
			count += (mi as MeshInstance3D).mesh.get_surface_count()
	return count

## Waits out the build pop (0.2 s), which scales `visual` for a moment after every completed level.
func _settle() -> void:
	for i in int(ceil(Balance.ui.build_pop_time * Engine.physics_ticks_per_second)) + 3:
		await get_tree().physics_frame

func _pay_full(id: String, levels := 1) -> void:
	for i in levels:
		GameState.add_gold(GameState.next_level_cost(id))
		GameState.pay_into_spot(id, GameState.next_level_cost(id))

func test_tower_levels_grow_to_the_scale_table() -> void:
	var h := [_height(ENV + "tower_l1.tscn"), _height(ENV + "tower_l2.tscn"), _height(ENV + "tower_l3.tscn")]
	assert_lt(h[0], h[1])
	assert_lt(h[1], h[2])
	for i in 3:
		assert_almost_eq(h[i], [2.2, 2.8, 3.4][i], [2.2, 2.8, 3.4][i] * 0.1)

func test_fence_height_is_the_scale_table() -> void:
	assert_almost_eq(_height(ENV + "fence_l1.tscn"), 0.9, 0.09, "fence L1")
	assert_almost_eq(_height(ENV + "fence_l3.tscn"), 0.9, 0.09, "fence L3")
	var l2 := _height(ENV + "fence_l2.tscn")  # raised posts stand above the 0.9 m wall
	assert_gt(l2, 0.95, "fence L2 posts rise above the wall")
	assert_lt(l2, 1.15, "and stay under the 1.2 m pip height")

func test_fence_levels_differ() -> void:
	var t := {}
	var sizes := []
	for l in [1, 2, 3]:
		var n: Node = load(ENV + "fence_l%d.tscn" % l).instantiate()
		add_child_autofree(n)
		t[AssetValidator.count_triangles(n)] = true
		sizes.append((n.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_aabb().size)
	assert_eq(t.size(), 3, "three different fence models")
	assert_ne(sizes[0], sizes[1], "fence L1 and L2 outlines differ")
	assert_ne(sizes[1], sizes[2], "fence L2 and L3 outlines differ")
	assert_ne(sizes[0], sizes[2], "fence L1 and L3 outlines differ")

func test_every_runtime_scene_is_one_mesh_instance_within_its_target() -> void:
	for name in NAMES:
		var n: Node = load(ENV + "%s.tscn" % name).instantiate()
		add_child_autofree(n)
		assert_eq(n.find_children("*", "MeshInstance3D", true, false).size(), 1, "%s: one MeshInstance3D" % name)
		assert_eq(_surfaces(n), 1, "%s: one surface (tower level 1, fence level 1, rubble 1)" % name)
		assert_eq(n.find_children("*", "CollisionObject3D", true, false).size(), 0, "%s: no physics" % name)

func test_triangle_budgets() -> void:
	for name in NAMES:
		var budget := ArtBudgets.budget_for(ENV + "%s.tscn" % name)
		if budget < 0:
			continue
		var n: Node = load(ENV + "%s.tscn" % name).instantiate()
		add_child_autofree(n)
		assert_lte(AssetValidator.count_triangles(n), budget, "%s triangles" % name)

## The ballista shares the tower pieces' atlas (the one atlas material), so a tower level stays one surface.
func test_ballista_shares_the_tower_atlas() -> void:
	var mat_path := "res://art/materials/kenney-tower-defense__colormap.tres"
	var ballista: Node = load("res://assets/kenney-tower-defense/weapon-ballista.glb").instantiate()
	add_child_autofree(ballista)
	for mi in ballista.find_children("*", "MeshInstance3D", true, false):
		for s in (mi as MeshInstance3D).mesh.get_surface_count():
			assert_eq((mi as MeshInstance3D).get_active_material(s).resource_path, mat_path, "ballista surface %d" % s)
	for l in [1, 2, 3]:
		var m := load(ENV + "baked/tower_l%d.res" % l) as ArrayMesh
		assert_eq(m.get_surface_count(), 1)
		assert_eq(m.surface_get_material(0).resource_path, mat_path, "tower L%d surface material" % l)

func test_committed_bakes_match_their_sources() -> void:
	for name in NAMES:
		var src: Node3D = load(ENV + "src/%s_src.tscn" % name).instantiate()
		var fresh: ArrayMesh = Bake.bake(src)
		src.free()
		var cur := load(ENV + "baked/%s.res" % name) as ArrayMesh
		assert_not_null(cur, "%s baked" % name)
		assert_eq(cur.get_surface_count(), fresh.get_surface_count(), "%s surfaces" % name)
		for s in mini(cur.get_surface_count(), fresh.get_surface_count()):
			var a := fresh.surface_get_arrays(s)
			var b := cur.surface_get_arrays(s)
			assert_true(a[Mesh.ARRAY_INDEX] == b[Mesh.ARRAY_INDEX], "%s indices are current: rerun tools/bake_static.gd --all" % name)
			assert_true(a[Mesh.ARRAY_TEX_UV] == b[Mesh.ARRAY_TEX_UV], "%s UVs are current" % name)
			for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL]:
				var fa: PackedVector3Array = a[k]
				var fb: PackedVector3Array = b[k]
				assert_eq(fa.size(), fb.size(), "%s array %d size" % [name, k])
				var off := 0
				for i in mini(fa.size(), fb.size()):
					if not fa[i].is_equal_approx(fb[i]):
						off += 1
				assert_eq(off, 0, "%s array %d: vertices that differ from the fresh bake" % [name, k])
			assert_eq(fresh.surface_get_material(s), cur.surface_get_material(s), "%s material" % name)

func test_star_is_one_gold_mesh() -> void:
	var m := LevelStar.mesh()
	assert_eq(m.get_surface_count(), 1)
	assert_almost_eq(m.get_aabb().get_longest_axis_size(), LevelStar.SIZE, 0.02)
	assert_eq(LevelStar.material().albedo_color, Palette.color(&"gold"))
	assert_same(LevelStar.mesh(), LevelStar.mesh(), "built once")

# --- build spots ---

func _model(spot: BuildSpot) -> Node3D:
	assert_eq(spot.visual.get_child_count(), 1, "%s: exactly one model child" % spot.spot_id)
	return spot.visual.get_child(0) as Node3D

func test_unbuilt_spot_has_no_model() -> void:
	for id in MapLayout.SPOT_IDS:
		assert_eq(main.world.build_spots[id].visual.get_child_count(), 0, id)

func test_each_level_swaps_the_model() -> void:
	var t: TowerSpot = main.world.build_spots.tower_nw
	var f: FenceSpot = main.world.build_spots.fence_w
	for l in [1, 2, 3]:
		_pay_full("tower_nw")
		_pay_full("fence_w")
		assert_eq(_model(t).scene_file_path, ENV + "tower_l%d.tscn" % l)
		assert_eq(_model(f).scene_file_path, ENV + "fence_l%d.tscn" % l)

func test_no_instancing_on_payment_ticks_or_fence_hits() -> void:
	var t: TowerSpot = main.world.build_spots.tower_nw
	var f: FenceSpot = main.world.build_spots.fence_w
	_pay_full("tower_nw")
	_pay_full("fence_w")
	var tm := _model(t)
	var fm := _model(f)
	GameState.add_gold(5)
	GameState.pay_into_spot("tower_nw", 3)  # a payment tick toward level 2
	GameState.pay_into_spot("tower_nw", 1)
	t.refresh()
	f.refresh()
	assert_same(_model(t), tm, "payment ticks keep the model")
	GameState.damage_fence("fence_w", 1.0)  # a hit that does not break it
	assert_gt(float(GameState.buildings.fence_w.hp), 0.0, "precondition: the fence survived the hit")
	assert_same(_model(f), fm, "fence hits keep the model")
	GameState.damage_fence("fence_w", 1e9)
	assert_true(f.is_rubble())
	var rm := _model(f)
	assert_ne(rm, fm, "rubble swaps the model")
	GameState.damage_fence("fence_w", 1.0)
	f.refresh()
	assert_same(_model(f), rm, "hits on rubble keep the rubble model")

func test_level_scale_is_identity_once_the_pop_is_over() -> void:
	assert_eq(Balance.ui.build_level_scale, 1.0, "D-197: the art carries the level, not the scale")
	_pay_full("tower_nw", 3)
	assert_gt(main.world.build_spots.tower_nw.visual.scale.x, 1.0, "the pop is running")
	await _settle()
	assert_almost_eq(main.world.build_spots.tower_nw.visual.scale, Vector3.ONE, Vector3.ONE * 1e-4)

func test_pips_sit_above_the_model_top() -> void:
	var t: TowerSpot = main.world.build_spots.tower_nw
	var f: FenceSpot = main.world.build_spots.fence_w
	var want := [2.5, 3.1, 3.7]
	for l in 3:
		_pay_full("tower_nw")
		_pay_full("fence_w")
		await _settle()
		var visible_pips: Array = t._pips.filter(func(p): return p.visible)
		assert_eq(visible_pips.size(), l + 1)
		for p in visible_pips:
			assert_almost_eq(p.position.y, want[l], 0.001, "tower L%d pip height" % (l + 1))
			assert_gt(p.position.y, _top(_model(t)), "pip above the tower top")
			assert_eq(p.get_parent(), t, "pips stay outside Visual")
		for p in f._pips.filter(func(p): return p.visible):
			assert_almost_eq(p.position.y, 1.2, 0.001)
			assert_gt(p.position.y, _top(_model(f)), "pip above the fence top")

func test_pips_face_the_camera() -> void:
	for id in MapLayout.SPOT_IDS:
		for p in main.world.build_spots[id]._pips:
			assert_almost_eq(p.rotation.x, deg_to_rad(Balance.ui.camera_pitch), 1e-5, "%s pip pitch" % id)

func test_marker_only_level0_in_day() -> void:
	main.phase_controller.start_new_game(5)
	main.phase_controller.debug_skip_to_day()
	assert_eq(main.phase_controller.phase, Phase.DAY)
	for id in MapLayout.SPOT_IDS:
		var s: BuildSpot = main.world.build_spots[id]
		assert_true(s.marker.visible, "%s: unbuilt in DAY shows the marker" % id)
		assert_eq(s.marker.get_parent(), s, "the marker is a sibling of Visual")
		assert_ne(s.marker.get_parent(), s.visual)
	_pay_full("tower_nw")
	assert_false(main.world.build_spots.tower_nw.marker.visible, "built: no marker")
	assert_true(main.world.build_spots.tower_ne.marker.visible, "a neighbour is unaffected")
	main.phase_controller.close_up()
	assert_eq(main.phase_controller.phase, Phase.NIGHT)
	assert_false(main.world.build_spots.tower_ne.marker.visible, "unbuilt in NIGHT: no marker")
	assert_false(main.world.build_spots.tower_nw.marker.visible)

func test_marker_exists_from_setup() -> void:
	for id in MapLayout.SPOT_IDS:
		var s: BuildSpot = main.world.build_spots[id]
		assert_not_null(s.marker, id)
		assert_eq(s.marker.scene_file_path, ENV + "spot_marker.tscn")

# --- resume into DAY (Review Focus 3) ---

func _saved_day_state() -> Dictionary:
	var pc := main.phase_controller
	pc.start_new_game(61)
	pc.debug_skip_to_day()
	GameState.add_gold(5000)
	_pay_full("tower_nw", 3)
	_pay_full("fence_w", 2)
	_pay_full("tower_ne", 1)
	var d := GameState.to_dict()
	d.resume_phase = "DAY"
	return d

func test_resume_day_shows_saved_level_model() -> void:
	var saved := _saved_day_state()
	remove_child(main)  # a quit and a fresh boot: the new world builds from the save alone
	main.free()
	GameState.new_game(1)
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.resume_from(saved)
	assert_eq(main.phase_controller.phase, Phase.DAY, "precondition: resumed into DAY")
	var w := main.world
	var tnw: TowerSpot = w.build_spots.tower_nw
	var tne: TowerSpot = w.build_spots.tower_ne
	var fw: FenceSpot = w.build_spots.fence_w
	assert_eq(_model(tnw).scene_file_path, ENV + "tower_l3.tscn", "tower_nw L3")
	assert_eq(_model(tne).scene_file_path, ENV + "tower_l1.tscn", "tower_ne L1")
	assert_eq(_model(fw).scene_file_path, ENV + "fence_l2.tscn", "fence_w L2")
	assert_eq(w.build_spots.fence_n.visual.get_child_count(), 0, "an unbuilt spot shows nothing")
	for s in [tnw, tne, fw]:
		assert_true(s.visual.visible, "%s visible" % s.spot_id)
		assert_false(s.marker.visible, "%s marker hidden" % s.spot_id)
	assert_true(w.build_spots.fence_n.marker.visible, "an unbuilt spot's marker is shown in DAY")
	for pair in [[tnw, 3.7], [tne, 2.5], [fw, 1.2]]:
		var spot: BuildSpot = pair[0]
		var top := _top(_model(spot))
		var shown: Array = spot._pips.filter(func(p): return p.visible)
		assert_eq(shown.size(), spot.level, "%s pips" % spot.spot_id)
		for p in shown:
			assert_almost_eq(p.position.y, float(pair[1]), 0.001)
			assert_gt(p.position.y, top, "%s: the pip is above the model" % spot.spot_id)
	# rubble after the resume
	GameState.damage_fence("fence_w", 1e9)
	assert_true(fw.is_rubble())
	assert_true(_model(fw).scene_file_path.ends_with("fence_rubble.tscn"), "rubble model")
	# and a restore back to the saved state shows the saved fence level again
	GameState.from_dict(saved)
	assert_eq(_model(fw).scene_file_path, ENV + "fence_l2.tscn", "restored fence_w L2")
	assert_false(fw.is_rubble())

# --- sign, telegraph, lane gate ---

func test_sign_is_the_baked_model_with_a_world_label() -> void:
	var s: CloseUpSign = main.world.closeup_sign
	assert_eq(s._visual.name, &"Visual")
	assert_eq(s._visual.scene_file_path, ENV + "closeup_sign.tscn")
	assert_eq(_surfaces(s._visual), 1, "one surface")
	var labels := s.find_children("*", "WorldLabel", true, false)
	assert_eq(labels.size(), 1)
	assert_eq((labels[0] as WorldLabel).text, tr("Close up"))
	assert_gt(_top(s._visual), 1.3)
	assert_lt(_top(s._visual), 1.9, "about 1.6 m")

func test_telegraph_flag_uses_the_enemy_red_override() -> void:
	for lane in main.world.telegraph_markers:
		var m: TelegraphMarker = main.world.telegraph_markers[lane]
		var meshes := m.find_children("*", "MeshInstance3D", true, false)
		assert_eq(meshes.size(), 1, "one flag mesh")
		var mat := (meshes[0] as MeshInstance3D).material_override as StandardMaterial3D
		assert_not_null(mat, "an override material")
		assert_true(mat.albedo_color.is_equal_approx(Palette.color(&"enemy_red")), "enemy_red (R4)")
		assert_eq(m.get_child(0).scene_file_path, ENV + "telegraph_flag.tscn")

func test_lane_gate_stands_at_the_entrance_facing_along_the_lane() -> void:
	for id in MapLayout.LANE_PATHS:
		var lane: Lane = main.world.lanes[id]
		var gate := lane.get_node("Gate") as Node3D
		assert_not_null(gate)
		assert_eq(gate.scene_file_path, ENV + "lane_gate.tscn")
		assert_eq(gate.position, lane.entrance_position())
		var pts: Array = MapLayout.LANE_PATHS[id]
		var d := ((pts[1] as Vector2) - (pts[0] as Vector2)).normalized()
		var fwd := gate.transform.basis * Vector3(0, 0, 1)
		assert_almost_eq(fwd.dot(Vector3(d.x, 0, d.y)), 1.0, 0.001, "%s gate faces along the lane" % id)
