extends GutTest
## E5 spec 7.1: three kinds from one builder; R7 scale table; the boss bar.

func before_each() -> void:
	Balance.reset()

func _height(m: ArrayMesh) -> float:
	return m.get_aabb().size.y

func _length(m: ArrayMesh) -> float:
	return m.get_aabb().size.z

## Captured from the builder before E5 touched it (v, i, AABB, SHA-256 of vertex, normal, colour and index arrays).
func test_boar_mesh_is_unchanged() -> void:
	assert_eq(BoarMesh.get_mesh(), BoarMesh.get_mesh(&"boar"), "the default is the boar")
	var m := BoarMesh.get_mesh(&"boar")
	var a := m.surface_get_arrays(0)
	assert_eq((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 1089)
	assert_eq((a[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 4368)
	var bb := m.get_aabb()
	assert_almost_eq(bb.position.x, -0.5499401, 1e-5)
	assert_almost_eq(bb.position.y, 0.0, 1e-5)
	assert_almost_eq(bb.position.z, -0.63511425, 1e-5)
	assert_almost_eq(bb.size.x, 1.0998802, 1e-5)
	assert_almost_eq(bb.size.y, 1.1146812, 1e-5)
	assert_almost_eq(bb.size.z, 1.5234311, 1e-5)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array())
	ctx.update((a[Mesh.ARRAY_NORMAL] as PackedVector3Array).to_byte_array())
	ctx.update((a[Mesh.ARRAY_COLOR] as PackedColorArray).to_byte_array())
	ctx.update((a[Mesh.ARRAY_INDEX] as PackedInt32Array).to_byte_array())
	assert_eq(ctx.finish().hex_encode(), "d0e9d5fe8f3e4952a925958a00b0b12098bab9da7420f3f205104c008f9d6788")

func test_scale_table_r7() -> void:
	assert_between(_height(BoarMesh.get_mesh(&"hare")), 0.63, 0.77, "hare 0.7 m +- 10%")
	assert_between(_length(BoarMesh.get_mesh(&"hare")), 0.99, 1.21, "hare 1.1 m long +- 10%")
	assert_between(_height(BoarMesh.get_mesh(&"boss")), 1.98, 2.42, "boss 2.2 m +- 10%")
	assert_between(_length(BoarMesh.get_mesh(&"boss")), 2.88, 3.52, "boss 3.2 m long +- 10%")

func test_each_kind_is_within_the_triangle_budget_and_on_palette() -> void:
	for kind in MonsterBalance.KINDS:
		var m := BoarMesh.get_mesh(kind)
		var tris: int = m.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
		assert_lte(tris, ArtBudgets.budget_for("res://art/boar/x"), "%s triangles" % kind)
		if kind == &"boar":
			continue  # the boar keeps its reviewed colours, its white tusks included (D-192)
		var cols: PackedColorArray = m.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		for hero in [&"apron_white", &"warm_white", &"gold", &"gold_dark"]:
			var hc := Palette.color(hero)
			for c in cols:
				assert_false(Color(c.r, c.g, c.b).is_equal_approx(hc), "%s wears the hero colour %s (R2)" % [kind, hero])

func test_visual_swaps_the_mesh_only_when_the_kind_changes() -> void:
	var b := Boar.new()
	add_child_autofree(b)
	var before: Mesh = b.visual._mesh_node.mesh
	b.visual.set_kind(&"boar")
	assert_eq(b.visual._mesh_node.mesh, before)
	b.visual.set_kind(&"hare")
	assert_eq(b.visual._mesh_node.mesh, BoarMesh.get_mesh(&"hare"))
	assert_ne(b.visual._mesh_node.mesh, before)

func test_boss_bar_shows_only_for_a_living_boss() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	GameState.new_game(1)
	var wd := main.world.wave_director
	wd.start_night(GameState.lane_plan)
	var boar := wd.debug_spawn("north")
	await get_tree().process_frame
	assert_false(boar.get_node("BossBar").visible)
	var boss := wd.debug_spawn("north", 0.0, 1.0, &"boss")
	await get_tree().process_frame
	var bar: BossBar = boss.get_node("BossBar")
	assert_true(bar.visible)
	assert_almost_eq(bar.fraction(), 1.0, 1e-6)
	boss.take_hit(boss.health.max_hp * 0.5)
	await get_tree().process_frame
	assert_almost_eq(bar.fraction(), 0.5, 1e-6)
	assert_eq(bar.fill_color(), Palette.color(&"enemy_red"))
	boss.take_hit(1e9)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_false(bar.visible)

## E5 tier 3, Task 10: the siege brute is clearly bigger and heavier than the Boar, in budget, on palette.
func test_brute_is_at_least_1_6x_the_boar_in_height_and_width() -> void:
	var boar := BoarMesh.get_mesh(&"boar").get_aabb()
	var brute := BoarMesh.get_mesh(&"brute").get_aabb()
	assert_gte(brute.size.y, boar.size.y * 1.6, "height")
	assert_gte(brute.size.x, boar.size.x * 1.6, "width")
	assert_lte(brute.size.y, BoarMesh.get_mesh(&"boss").get_aabb().size.y * 0.85, "clearly smaller than the Boar King")
	assert_ne(BoarMesh.params(&"brute").upper, BoarMesh.params(&"boss").upper, "not the King's back colour")
	var king_back: Color = BoarMesh.params(&"boss").upper
	assert_gt(BoarMesh.params(&"brute").upper.r, king_back.r, "a redder, lighter back than the King")
	assert_ne(BoarMesh.params(&"brute").body_scale, BoarMesh.BODY_SCALE, "its own proportions, not a scaled Boar")
