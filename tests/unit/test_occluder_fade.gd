extends GutTest
## D-151: the diner fades when it hides the hero or a Boar. Geometry is checked through CameraMath, so no
## renderer is needed. The "wired" test uses the World's own OccluderFade (D-139 wiring, applied).

const DT := 1.0 / 60.0
var _visual: Node3D
var _fade: OccluderFade
var _cam: Camera3D
var _targets: Array = []
var _diner := AABB(
	Vector3(-MapLayout.DINER_HALF, 0.0, -MapLayout.DINER_HALF),
	Vector3(MapLayout.DINER_HALF * 2.0, MapLayout.DINER_HEIGHT, MapLayout.DINER_HALF * 2.0))

func before_each() -> void:
	Balance.reset()
	_targets = []
	_visual = Visuals.visual_root()
	add_child_autofree(_visual)
	for part in [Vector3(0, 1.5, 0), Vector3(0, 3.1, 0)]:  # walls + roof: separate meshes (S4 note)
		var m := FixtureBox.box(Vector3(8, 3, 8) if part.y < 3.0 else Vector3(8.4, 0.2, 8.4), FixtureBox.COLORS.diner)
		m.position = part
		_visual.add_child(m)
	_cam = Camera3D.new()
	add_child_autofree(_cam)
	_fade = OccluderFade.new()
	_visual.add_child(_fade)
	_fade.setup(_diner, func(): return _cam, func(): return _targets)

func _aim_camera_at(hero_xz: Vector2) -> void:
	_cam.global_transform = CameraMath.camera_transform(CameraMath.focus_for(hero_xz), Balance.ui)

func _run(seconds: float) -> void:
	for i in ceili(seconds / DT):
		_fade._process(DT)

func _meshes() -> Array:
	return _visual.find_children("*", "MeshInstance3D", true, false)

func _hero_aim(feet: Vector3) -> Vector3:
	return feet + Vector3(0, Hero.AIM_HEIGHT, 0)

func _boar_aim(feet: Vector3) -> Vector3:
	return feet + Vector3(0, Boar.AIM_HEIGHT, 0)

func _hero_at_north_center() -> Vector3:
	return MapLayout.to3((MapLayout.ZONE_RECTS["north"] as Rect2).get_center())

func test_hero_at_north_zone_center_fades() -> void:
	var hero := _hero_at_north_center()
	_aim_camera_at(Vector2(hero.x, hero.z))
	_targets = [_hero_aim(hero)]
	# The hero is on screen, and the camera->hero segment (at the hero's aim height) crosses the grown AABB:
	# an opaque diner face would cover the hero's screen point.
	var proj := CameraMath.projection(Balance.ui, CameraMath.ASPECT)
	assert_true(CameraMath.on_screen(hero, _cam.global_transform, proj))
	var aim := _hero_aim(hero)
	assert_not_null(_diner.grow(Balance.ui.occluder_grow).intersects_segment(_cam.global_position, aim))
	assert_not_null(_diner.intersects_segment(_cam.global_position, aim), "even the un-grown diner hides the hero")
	_run(Balance.ui.occluder_fade_s)
	assert_true(_fade.is_faded())
	assert_almost_eq(_fade.current_alpha(), Balance.ui.occluder_alpha, 1e-3)
	for m in _meshes():
		var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
		assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
		assert_almost_eq(mat.albedo_color.a, Balance.ui.occluder_alpha, 1e-3)

func test_fade_takes_fade_time_not_instant() -> void:
	var hero := _hero_at_north_center()
	_aim_camera_at(Vector2(hero.x, hero.z))
	_targets = [_hero_aim(hero)]
	_run(Balance.ui.occluder_fade_s * 0.5)
	assert_gt(_fade.current_alpha(), Balance.ui.occluder_alpha + 0.05)
	assert_lt(_fade.current_alpha(), 1.0)

func test_boar_in_north_zone_with_hero_at_home_fades() -> void:
	_aim_camera_at(MapLayout.HOME)
	var boar_pos := (MapLayout.ZONE_RECTS["north"] as Rect2).get_center()
	var aim := _boar_aim(MapLayout.to3(boar_pos))
	_targets = [_hero_aim(MapLayout.to3(MapLayout.HOME)), aim]
	assert_not_null(_diner.grow(Balance.ui.occluder_grow).intersects_segment(_cam.global_position, aim))
	assert_not_null(_diner.intersects_segment(_cam.global_position, aim), "even the un-grown diner hides the Boar")
	_run(Balance.ui.occluder_fade_s)
	assert_true(_fade.is_faded())
	assert_almost_eq(_fade.current_alpha(), Balance.ui.occluder_alpha, 1e-3)

func test_nothing_occluded_stays_opaque_without_override_change() -> void:
	var originals := {}
	for m in _meshes():
		originals[m] = (m as MeshInstance3D).material_override
	_aim_camera_at(MapLayout.HOME)
	_targets = [_hero_aim(MapLayout.to3(MapLayout.HOME))]  # south of the diner, camera further south
	_run(1.0)
	assert_false(_fade.is_faded())
	assert_eq(_fade.current_alpha(), 1.0)
	for m in _meshes():
		assert_same((m as MeshInstance3D).material_override, originals[m], "opaque material untouched")

func test_no_targets_stays_opaque() -> void:
	_aim_camera_at(MapLayout.HOME)
	_run(0.5)
	assert_eq(_fade.current_alpha(), 1.0)
	assert_false(_fade.is_faded())

func test_fades_back_and_restores_opaque_material() -> void:
	var originals := {}
	for m in _meshes():
		originals[m] = (m as MeshInstance3D).material_override
	var hero := _hero_at_north_center()
	_aim_camera_at(Vector2(hero.x, hero.z))
	_targets = [_hero_aim(hero)]
	_run(1.0)
	assert_true(_fade.is_faded())
	_targets = []
	_run(Balance.ui.occluder_fade_s * 0.5)
	assert_true(_fade.is_faded(), "still mid-fade back")
	_run(1.0)
	assert_eq(_fade.current_alpha(), 1.0)
	assert_false(_fade.is_faded())
	for m in _meshes():
		var mat := (m as MeshInstance3D).material_override as BaseMaterial3D
		assert_same(mat, originals[m], "the original opaque material is back")
		assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)

func test_faded_material_does_not_leak_into_shared_cache() -> void:
	var shared := FixtureBox.material(FixtureBox.COLORS.diner)
	var hero := _hero_at_north_center()
	_aim_camera_at(Vector2(hero.x, hero.z))
	_targets = [_hero_aim(hero)]
	_run(1.0)
	assert_eq(shared.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)
	assert_eq(shared.albedo_color.a, 1.0)

func test_far_boar_hidden_only_at_its_own_aim_height() -> void:
	# Regression: a Boar at z = -9 with the hero at HOME. Aimed at 0.5 m the segment grazes the diner
	# (fades); a hero-height 1.0 m aim would clear the roof line and miss it.
	_aim_camera_at(MapLayout.HOME)
	var feet := MapLayout.to3(Vector2(0, -9.0))
	var grown := _diner.grow(Balance.ui.occluder_grow)
	assert_not_null(grown.intersects_segment(_cam.global_position, _boar_aim(feet)))
	_targets = [_hero_aim(MapLayout.to3(MapLayout.HOME)), _boar_aim(feet)]
	_run(Balance.ui.occluder_fade_s)
	assert_true(_fade.is_faded())

func test_surface_material_meshes_fade_and_restore_to_null() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color.RED
	bm.material = surface
	mi.mesh = bm
	_visual.add_child(mi)
	var hero := _hero_at_north_center()
	_aim_camera_at(Vector2(hero.x, hero.z))
	_targets = [_hero_aim(hero)]
	_run(Balance.ui.occluder_fade_s)
	var faded := mi.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(faded)
	assert_eq(faded.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_almost_eq(faded.albedo_color.a, Balance.ui.occluder_alpha, 1e-3)
	assert_eq(faded.albedo_color.r, 1.0, "colour kept")
	assert_eq(surface.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "the mesh's own material is untouched")
	_targets = []
	_run(1.0)
	assert_null(mi.get_surface_override_material(0), "restored to no override")

func test_mesh_without_any_material_is_skipped_safely() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	_visual.add_child(mi)
	var hero := _hero_at_north_center()
	_aim_camera_at(Vector2(hero.x, hero.z))
	_targets = [_hero_aim(hero)]
	_run(Balance.ui.occluder_fade_s)
	assert_true(_fade.is_faded())
	assert_null(mi.material_override)
	_targets = []
	_run(1.0)
	assert_null(mi.material_override)

func test_missing_camera_is_safe() -> void:
	_fade.setup(_diner, func(): return null, func(): return [Vector3(0, 1, 0)])
	_run(0.2)
	assert_eq(_fade.current_alpha(), 1.0)

func test_wired_hero_at_north_zone_center_fades_world_diner() -> void:
	var main := Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(72)
	var found := main.world.diner_body.find_children("*", "OccluderFade", true, false)
	assert_eq(found.size(), 1, "wired: World creates an OccluderFade under the diner's Visual")
	if found.is_empty():
		return
	var fade: OccluderFade = found[0]
	assert_eq(fade.get_parent(), main.world.diner_body.get_node("Visual"))
	main.hero.teleport((MapLayout.ZONE_RECTS["north"] as Rect2).get_center())
	main.camera_rig.snap()
	for i in 30:
		await get_tree().process_frame
	assert_true(fade.is_faded())
	main.hero.teleport(MapLayout.HOME)
	main.camera_rig.snap()
	for i in 30:
		await get_tree().process_frame
	assert_false(fade.is_faded(), "hero south of the diner, no Boars: opaque again")
	var b := main.world.wave_director.debug_spawn("north")
	b.set_physics_process(false)
	var d := 0.0
	while EnemyPath.position_at("north", d, 0.0, Balance.data.enemy.offset_fade_distance).y < -9.0:
		d += 0.05
	b.dist = d
	b._update_position()
	assert_almost_eq(b.global_position.z, -9.0, 0.6, "staged near z = -9")
	for i in 30:
		await get_tree().process_frame
	assert_true(fade.is_faded(), "wired: a Boar behind the diner (hero at HOME) fades it, with per-actor aim heights")

# ---- S4 Task 11: the real diner art (occluder boxes, Label3D fade, Archer roof skip) ----

## Builds the diner the way world.gd does: Visual(Node3D) > DinerArt + OccluderFade, setup() with AABB().
func _real_diner() -> OccluderFade:
	var visual := Visuals.visual_root()
	add_child_autofree(visual)
	visual.add_child(load("res://art/env/diner.tscn").instantiate())
	var fade := OccluderFade.new()
	fade.name = "RealFade"
	visual.add_child(fade)
	fade.setup(AABB(), func(): return _cam, func(): return _targets)
	return fade

func _real_meshes(fade: OccluderFade) -> Array:
	return fade.get_parent().find_children("*", "MeshInstance3D", true, false)

func _real_board(fade: OccluderFade) -> Label3D:
	return fade.get_parent().find_child("Board", true, false) as Label3D

func _run_fade(fade: OccluderFade, seconds: float) -> void:
	for i in ceili(seconds / DT):
		fade._process(DT)

## True when any of the fade's grown boxes is hit by the camera -> aim segment.
func _hits(fade: OccluderFade, aim: Vector3) -> bool:
	for b in fade.boxes():
		if b.grow(Balance.ui.occluder_grow).intersects_segment(_cam.global_position, aim) != null:
			return true
	return false

const WALLS := AABB(Vector3(-4, 0, -4), Vector3(8, 3.4, 8))  # walls + parapet, as DinerArt reports them
const CHIMNEY_POINT := Vector3(3.2, 4.6, -3.3)               # inside the chimney box

func test_real_diner_bounds_cover_roof_parts_and_board_fades() -> void:
	var fade := _real_diner()
	assert_gte(fade.bounds.end.y, MapLayout.DINER_HEIGHT + 0.8, "the bounds reach the board and chimney")
	# A Boar north of the diner whose line to the camera passes through the chimney and clears the walls and
	# parapet (the camera is placed on that line, so this is geometry, not the game camera).
	var aim := _boar_aim(MapLayout.to3(Vector2(3.2, -9.0)))
	_cam.global_position = aim + (CHIMNEY_POINT - aim).normalized() * 20.0
	assert_null(_diner.grow(Balance.ui.occluder_grow).intersects_segment(_cam.global_position, aim),
		"precondition: the old 3 m box alone would not fade")
	assert_null(WALLS.grow(Balance.ui.occluder_grow).intersects_segment(_cam.global_position, aim),
		"precondition: neither would the walls + parapet box")
	assert_true(_hits(fade, aim), "precondition: the chimney box is in the way")
	_targets = [aim]
	_run_fade(fade, Balance.ui.occluder_fade_s * 3.0)
	assert_true(fade.is_faded(), "the chimney hides it, so the diner fades")
	var board := _real_board(fade)
	assert_not_null(board)
	assert_almost_eq(board.modulate.a, Balance.ui.occluder_alpha, 1e-3, "the Board's text fades with the walls")
	for m in _real_meshes(fade):
		assert_almost_eq(((m as MeshInstance3D).get_surface_override_material(0) as BaseMaterial3D).albedo_color.a, Balance.ui.occluder_alpha, 1e-3)
	_targets = []
	_run_fade(fade, 1.0)
	assert_eq(board.modulate.a, 1.0, "the text is back at full alpha")

func test_board_box_hides_a_target_and_fades_the_label() -> void:
	var fade := _real_diner()
	var board_center := Vector3(0, 4.2, 3.6)
	var aim := Vector3(0, 0.5, 9.0)  # south of the diner; the camera sits north of the board, looking down the line
	_cam.global_position = board_center + (board_center - aim).normalized() * 12.0
	assert_null(WALLS.grow(Balance.ui.occluder_grow).intersects_segment(_cam.global_position, aim), "precondition: not the walls")
	assert_true(_hits(fade, aim), "precondition: the sign box is in the way")
	_targets = [aim]
	_run_fade(fade, Balance.ui.occluder_fade_s * 3.0)
	assert_true(fade.is_faded())
	assert_almost_eq(_real_board(fade).modulate.a, Balance.ui.occluder_alpha, 1e-3)

func test_archer_on_roof_never_fades_the_diner() -> void:
	var fade := _real_diner()
	var archer_aim := MapLayout.to3(MapLayout.guard_post(&"archer"), 4.0)  # guard_roster.gd reports y 4.0
	# The camera sits on the line from the Archer through the chimney, so the chimney box is between them.
	_cam.global_position = archer_aim + (Vector3(3.2, 3.9, -3.3) - archer_aim).normalized() * 25.0
	assert_true(_hits(fade, archer_aim), "precondition: without the roof skip a box WOULD hide the Archer")
	_targets = [archer_aim]
	_run_fade(fade, Balance.ui.occluder_fade_s * 3.0)
	assert_false(fade.is_faded())
	for m in _real_meshes(fade):
		assert_null((m as MeshInstance3D).get_surface_override_material(0), "back at its opaque material")
	assert_eq(_real_board(fade).modulate.a, 1.0)

func test_hero_at_night1_start_leaves_the_diner_opaque() -> void:
	var fade := _real_diner()
	_aim_camera_at(MapLayout.NIGHT1_START)
	var aim := _hero_aim(MapLayout.to3(MapLayout.NIGHT1_START))
	assert_false(_hits(fade, aim), "precondition: no box is between the camera and the hero")
	_targets = [aim]
	_run_fade(fade, Balance.ui.occluder_fade_s * 3.0)
	assert_false(fade.is_faded(), "nothing is hidden, so nothing fades (the sign plank must not fade the whole footprint)")

func test_far_north_boar_with_hero_home_leaves_the_diner_opaque() -> void:
	var fade := _real_diner()
	_aim_camera_at(MapLayout.HOME)
	var boar := _boar_aim(Vector3(0, 0, -14))
	_targets = [_hero_aim(MapLayout.to3(MapLayout.HOME)), boar]
	assert_false(_hits(fade, boar), "precondition: the line to the Boar clears every box")
	_run_fade(fade, Balance.ui.occluder_fade_s * 3.0)
	assert_false(fade.is_faded())

func test_hero_serving_at_the_counter_does_not_fade_the_diner() -> void:
	var fade := _real_diner()
	_aim_camera_at(MapLayout.COUNTER_DROP)
	_targets = [_hero_aim(MapLayout.to3(MapLayout.COUNTER_DROP))]
	_run_fade(fade, Balance.ui.occluder_fade_s * 3.0)
	assert_false(fade.is_faded(), "the awning and board must not widen the box over the counter")

func test_south_face_stays_clear_of_where_the_hero_can_stand() -> void:
	var fade := _real_diner()
	assert_lt(fade.bounds.end.z + Balance.ui.occluder_grow, MapLayout.DINER_HALF + MapLayout.HERO_RADIUS,
		"the grown south face never passes the hero's reach (counter and awning are not occluders)")

func test_setup_merges_a_passed_box_and_empty_box_is_ignored() -> void:
	var fade := _real_diner()
	var without := fade.bounds
	var big := AABB(Vector3(-20, 0, -20), Vector3(40, 10, 40))
	fade.setup(big, func(): return _cam, func(): return _targets)
	assert_true(fade.bounds.encloses(big) and fade.bounds.encloses(without))
	fade.setup(AABB(), func(): return _cam, func(): return _targets)
	assert_eq(fade.bounds, without)

# ---- E5 slice 2 Task 1: guards trigger the fade; every mesh of the building is in the fade's set at every tier ----

func _wired_main_with_tank_at_north() -> Main:
	var main := Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(72)
	main.world.wave_director.stop()
	main.hero.teleport(MapLayout.HOME)
	GameState.debug_grant_card(&"tank")
	var g: Guard = main.world.guard_roster.guards[&"tank"]
	g.place_at_post()
	g.set_physics_process(false)  # stays where the test puts it
	g.global_position = MapLayout.to3((MapLayout.ZONE_RECTS["north"] as Rect2).get_center())
	main.camera_rig.snap()
	return main

func test_wired_a_guard_alone_at_the_north_zone_fades_the_diner() -> void:
	var main := _wired_main_with_tank_at_north()
	assert_eq(main.world.wave_director.alive_enemies().size(), 0, "no monster")
	var fade: OccluderFade = main.world.occluder_fade
	for i in 40:
		await get_tree().process_frame
	assert_true(fade.is_faded(), "a guard behind the diner fades it, as the hero does")

func test_wired_without_a_guard_behind_the_diner_it_stays_opaque() -> void:
	var main := _wired_main_with_tank_at_north()
	var g: Guard = main.world.guard_roster.guards[&"tank"]
	g.global_position = MapLayout.to3(MapLayout.guard_post(&"tank"))  # back at its post, clear of the diner
	main.camera_rig.snap()
	for i in 40:
		await get_tree().process_frame
	assert_false(main.world.occluder_fade.is_faded(), "nobody is behind the diner")

func test_wired_every_mesh_of_the_building_is_faded_at_every_tier() -> void:
	var main := _wired_main_with_tank_at_north()
	var fade: OccluderFade = main.world.occluder_fade
	var vis := main.world.diner_body.get_node("Visual")
	for tier in [1, 2]:
		GameState.debug_set_tier(tier, 1)
		await get_tree().process_frame
		for i in 40:
			await get_tree().process_frame
		assert_true(fade.is_faded(), "tier %d faded" % tier)
		var meshes := vis.find_children("*", "MeshInstance3D", true, false)
		assert_gt(meshes.size(), 0)
		for m in meshes:
			var mi := m as MeshInstance3D
			assert_not_null(mi.get_surface_override_material(0), "tier %d: %s is in the fade's set" % [tier, mi.get_path()])
			assert_almost_eq((mi.get_surface_override_material(0) as BaseMaterial3D).albedo_color.a, Balance.ui.occluder_alpha, 0.02)
	GameState.new_game(1)

func test_tier2_chimney_and_board_boxes_fade_for_a_target_behind_them() -> void:
	var visual := Visuals.visual_root()
	add_child_autofree(visual)
	visual.add_child(load("res://art/env/diner_t2.tscn").instantiate())
	var fade := OccluderFade.new()
	visual.add_child(fade)
	fade.setup(AABB(), func(): return _cam, func(): return _targets)
	assert_gte(fade.bounds.end.y, 6.0, "the bounds reach the tier-2 chimney cap (6.1)")
	# a target whose line to a camera on the far side passes through the new chimney only
	var chimney := Vector3(-3.0, 5.0, -3.0)
	var aim := _boar_aim(MapLayout.to3(Vector2(-3.0, -12.0)))
	_cam.global_position = aim + (chimney - aim).normalized() * 25.0
	assert_null(WALLS.grow(Balance.ui.occluder_grow).intersects_segment(_cam.global_position, aim), "precondition: not the walls")
	assert_true(_hits(fade, aim), "precondition: the chimney box is in the way")
	_targets = [aim]
	_run_fade(fade, Balance.ui.occluder_fade_s * 3.0)
	assert_true(fade.is_faded())
