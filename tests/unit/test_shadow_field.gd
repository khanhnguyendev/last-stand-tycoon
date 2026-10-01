extends GutTest
## S4 Task 8b, D-201: one MultiMesh draw for every blob shadow.

var field: ShadowField

func before_each() -> void:
	field = ShadowField.new()
	add_child_autofree(field)

func _node(x: float, z: float, y := 0.0) -> Node3D:
	var n := Node3D.new()
	add_child_autofree(n)
	n.position = Vector3(x, y, z)
	return n

func test_one_instance_per_visible_registered_node_following_them() -> void:
	var a := _node(1, 2)
	var b := _node(3, 4)
	var c := _node(5, 6)
	for n in [a, b, c]:
		field.register(n, 0.5)
	field._process(0.0)
	assert_eq(field.multimesh.visible_instance_count, 3)
	b.visible = false
	field.unregister(c)
	field._process(0.0)
	assert_eq(field.multimesh.visible_instance_count, 1, "3 registered, 1 hidden, 1 unregistered")
	assert_eq(field.registered_count(), 2)
	a.position = Vector3(-7, 0, 9)
	field._process(0.0)
	assert_eq(field._written[0].origin, Vector3(-7, 0.04, 9), "the instance follows its node, 0.04 above the feet")
	b.visible = true
	field._process(0.0)
	assert_eq(field.multimesh.visible_instance_count, 2)
	assert_eq(field._written[1].origin, Vector3(3, 0.04, 4))

func test_radius_and_scale() -> void:
	var a := _node(0, 0)
	field.register(a, 0.5)
	field._process(0.0)
	assert_almost_eq(field._written[0].basis.get_scale().x, 1.0, 1e-4, "radius 0.5 is the old 1 m blob")
	field.register(a, 0.75)  # re-registering updates the radius, never duplicates
	assert_eq(field.registered_count(), 1)
	a.scale = Vector3.ONE * 0.5  # a poof tween in flight
	field._process(0.0)
	assert_almost_eq(field._written[0].basis.get_scale().x, 0.75, 1e-4)
	assert_almost_eq(field._written[0].basis.get_scale().y, 1.0, 1e-4)

func test_follows_the_nodes_height() -> void:
	var roof := _node(0, 0, 2.0)
	field.register(roof, 0.5)
	field._process(0.0)
	assert_almost_eq(field._written[0].origin.y, 2.04, 1e-4, "an archer on the roof gets its shadow on the roof")

func test_freed_and_removed_nodes_leave_the_field() -> void:
	var a := _node(0, 0)
	var b := _node(1, 0)
	field.register(a, 0.5)
	field.register(b, 0.5)
	b.get_parent().remove_child(b)
	assert_eq(field.registered_count(), 1, "leaving the tree unregisters")
	a.free()
	field._process(0.0)
	assert_eq(field.multimesh.visible_instance_count, 0)
	b.free()

func test_grows_past_its_start_capacity() -> void:
	for i in ShadowField.START_CAPACITY + 5:
		field.register(_node(i, 0), 0.5)
	field._process(0.0)
	assert_eq(field.multimesh.visible_instance_count, ShadowField.START_CAPACITY + 5)
	assert_gte(field.multimesh.instance_count, ShadowField.START_CAPACITY + 5)

func test_is_one_multimesh_instance_with_the_blob_material() -> void:
	assert_true(field is MultiMeshInstance3D)
	assert_eq(field.multimesh.transform_format, MultiMesh.TRANSFORM_3D)
	var mat := (field.multimesh.mesh as PlaneMesh).material as StandardMaterial3D
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_not_null(mat.albedo_texture)
	assert_eq(field.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

func test_a_released_pooled_traveler_leaves_the_field() -> void:
	var pool := NodePool.new()
	add_child_autofree(pool)
	pool.setup(func():
		var t := Traveler.new()
		t.shadow_field = field
		return t, 2)
	var t: Traveler = pool.acquire()
	t.begin(1)
	field._process(0.0)
	assert_eq(field.registered_count(), 1)
	assert_eq(field.multimesh.visible_instance_count, 1)
	assert_eq(field._written[0].origin, t.visual.global_position + Vector3(0, 0.04, 0))
	pool.release(t)
	assert_eq(field.registered_count(), 0, "release unregisters")
	field._process(0.0)
	assert_eq(field.multimesh.visible_instance_count, 0)
	var t2: Traveler = pool.acquire()  # the same traveler comes back: it registers again, once
	t2.begin(1)
	t2.begin(1)
	assert_eq(field.registered_count(), 1)

func test_the_world_owns_one_field_and_the_actors_register_with_it() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	var wf: ShadowField = main.world.shadow_field
	assert_not_null(wf)
	assert_eq(main.world.find_children("*", "ShadowField", false, false).size(), 1)
	wf._process(0.0)
	assert_true(main.hero.visual in wf._nodes, "the hero is registered")
	assert_gte(wf.shown_count(), 1)

func test_a_guard_is_registered_and_skipped_once_poofed_away() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	var wf: ShadowField = main.world.shadow_field
	main.phase_controller.start_new_game(99)
	main.world.wave_director.stop()
	GameState.debug_grant_card(&"tank")
	var guard: Guard = main.world.guard_roster.guards.get(&"tank")
	assert_not_null(guard, "a tank guard exists")
	if guard == null:
		return
	assert_true(guard.visual in wf._nodes, "the guard's visual is registered")
	guard.place_at_post()
	wf._process(0.0)
	var before := wf.shown_count()
	guard.poof(false)
	for i in 12:  # the 0.15 s poof at 60 physics fps
		await get_tree().physics_frame
	assert_false(guard.visual.visible, "the poof hid the visual")
	wf._process(0.0)
	assert_eq(wf.shown_count(), before - 1, "a hidden guard is skipped")
	assert_true(guard.visual in wf._nodes, "still registered, just skipped")
