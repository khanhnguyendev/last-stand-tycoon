extends GutTest
## D-192: one surface, within budget, leg mask present, one draw call; pooled reuse is clean (Review Focus 1).

const SCENE := "res://art/boar/boar_visual.tscn"

var main: Main

func _boar_mesh_instance(v: ActorVisual) -> MeshInstance3D:
	return v.body.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D

func test_mesh_shape() -> void:
	var m := BoarMesh.get_mesh()
	assert_eq(m.get_surface_count(), 1)
	var arr := m.surface_get_arrays(0)
	var tris: int = (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	assert_lte(tris, ArtBudgets.budget_for("res://art/boar"))
	var legs := 0
	var body := 0
	for c in (arr[Mesh.ARRAY_COLOR] as PackedColorArray):
		if c.a < 0.5:
			legs += 1
		else:
			body += 1
	assert_gt(legs, 0)
	assert_gt(body, legs, "most vertices are body (a = 1)")
	assert_same(BoarMesh.get_mesh(), m, "cached")
	var bb := m.get_aabb()
	assert_almost_eq(bb.position.y, 0.0, 0.02, "stands on y = 0")
	assert_between(bb.end.y, 0.9, 1.15, "about 1.0 m tall with the ridge")

func test_tusks_flare_at_55_degrees() -> void:
	# The tusk tips are the widest white (apron_white) vertices: they must flare out past the skull (x > 0.3).
	var arr := BoarMesh.get_mesh().surface_get_arrays(0)
	var white := Palette.color(&"apron_white")
	var max_x := 0.0
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	for i in verts.size():
		if cols[i].is_equal_approx(Color(white, 1.0)) and verts[i].y < 0.7:
			max_x = maxf(max_x, absf(verts[i].x))
	assert_gt(max_x, 0.3, "tusks reach out sideways")

func test_single_mesh_instance() -> void:
	var v: ActorVisual = load(SCENE).instantiate()
	add_child_autofree(v)
	assert_eq(v.find_children("*", "MeshInstance3D", true, false).size(), 1, "one draw: the boar mesh; its shadow is in the shared ShadowField (D-201)")

func test_flash_is_pink_white_not_white() -> void:
	var c: Color = BoarVisual.flash_material().get_shader_parameter("flash_color")
	assert_ne(c.to_html(false), "ffffff")
	assert_false(c.is_equal_approx(Palette.color(&"apron_white")), "R2: white belongs to the hero")
	assert_gt(c.r, c.b, "pink-white, warmer than neutral")
	assert_gt(c.get_luminance(), 0.55, "pale")

func test_materials_are_shared() -> void:
	assert_same(BoarVisual.idle_material(), BoarVisual.idle_material())
	assert_ne(BoarVisual.idle_material(), BoarVisual.run_material())
	assert_ne(BoarVisual.run_material(), BoarVisual.flash_material())

func test_motion_and_flash_pick_materials() -> void:
	var v: BoarVisual = load(SCENE).instantiate()
	add_child_autofree(v)
	var mi := _boar_mesh_instance(v)
	assert_eq(mi.material_override, BoarVisual.idle_material())
	v.set_motion(1.0)
	assert_eq(mi.material_override, BoarVisual.run_material())
	v.set_flash(true)
	assert_eq(mi.material_override, BoarVisual.flash_material())
	v.set_flash(false)
	assert_eq(mi.material_override, BoarVisual.run_material(), "flash ends back on the motion material")
	v.set_motion(0.0)
	assert_eq(mi.material_override, BoarVisual.idle_material())

func test_attack_finishes_within_015() -> void:
	var v: BoarVisual = load(SCENE).instantiate()
	add_child_autofree(v)
	v.attack()
	await get_tree().create_timer(0.3).timeout
	assert_almost_eq(v.body.position.z, 0.0, 0.01, "lunge is back at rest")

func test_hit_squash_returns() -> void:
	var v: BoarVisual = load(SCENE).instantiate()
	add_child_autofree(v)
	v.hit()
	await get_tree().create_timer(0.25).timeout
	assert_almost_eq(v.body.scale.y, 1.0, 0.01)

func test_die_squashes_body_not_root() -> void:
	var v: BoarVisual = load(SCENE).instantiate()
	add_child_autofree(v)
	v.die()
	await get_tree().create_timer(0.3).timeout
	assert_almost_eq(v.body.scale.y, Balance.ui.boar_death_squash, 0.01)
	assert_eq(v.scale, Vector3.ONE, "root scale belongs to Boar.play_death")
	assert_true(v.visible)

func test_pool_reuse_after_death_mid_lunge_and_flash() -> void:
	var v: ActorVisual = load(SCENE).instantiate()
	add_child_autofree(v)
	v.attack()
	v.set_flash(true)
	v.die()
	await get_tree().create_timer(0.05).timeout
	v.reset()
	assert_false(v.flash_active)
	assert_eq(v.body.transform, Transform3D.IDENTITY)
	var mi := _boar_mesh_instance(v)
	assert_eq(mi.material_override, BoarVisual.idle_material(), "back to idle, not flash or run")
	# Stale tweens must not move the reset Body.
	await get_tree().create_timer(0.3).timeout
	assert_eq(v.body.scale, Vector3.ONE)
	assert_almost_eq(v.body.position.z, 0.0, 1e-4)

# --- Boar level (Review Focus 1, D-201) ---

func _world() -> World:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(91)
	main.phase_controller.debug_skip_to_day()
	return main.world

func test_boar_release_then_spawn_is_clean() -> void:
	var w := _world()
	var b := w.wave_director.debug_spawn("north", 0.0, 10.0)
	b.visual.set_motion(1.0)
	b.visual.attack()
	b.take_hit(1.0)
	b.play_death(w.enemy_pool)
	await get_tree().create_timer(0.05).timeout
	b.on_release()
	b.spawn("north", 99, 0.0, 1.0, w.wave_director)
	assert_eq(b.visual.scale, Vector3.ONE)
	assert_eq(b.visual.body.transform, Transform3D.IDENTITY)
	assert_false(b.visual.flash_active)
	assert_eq(_boar_mesh_instance(b.visual).material_override, BoarVisual.idle_material())

func test_boar_registers_in_shadow_field_while_spawned() -> void:
	var w := _world()
	var field := w.shadow_field
	var before := field.registered_count()
	var b := w.wave_director.debug_spawn("north", 0.0, 10.0)
	assert_eq(field.registered_count(), before + 1, "spawn registers the Visual")
	assert_eq(b.find_children("*", "MeshInstance3D", true, false).size(), 1, "one draw per Boar")
	b.on_release()
	assert_eq(field.registered_count(), before, "release unregisters it")
