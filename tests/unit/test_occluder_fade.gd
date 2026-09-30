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
		var m := Visuals.box(Vector3(8, 3, 8) if part.y < 3.0 else Vector3(8.4, 0.2, 8.4), Visuals.COLORS.diner)
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
	var shared := Visuals.material(Visuals.COLORS.diner)
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
