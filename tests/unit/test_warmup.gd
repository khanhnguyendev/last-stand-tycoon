extends GutTest

var main: Main
var dir := ""

func before_each() -> void:
	Balance.reset()
	dir = "user://test_warmup_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]

func after_each() -> void:
	Balance.reset()
	GameState.new_game(1)
	SaveStore.with_dir(dir).wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))

func _main() -> void:
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false

func _pool_sizes() -> Array:
	var w := main.world
	return [w.enemy_pool.size, w.steak_pool.size, w.projectile_pool.size, w.fx_pool.size, w.traveler_pool.size]

func test_run_builds_and_frees_without_touching_state() -> void:
	_main()
	var before := GameState.to_dict()
	var sizes := _pool_sizes()
	var warmup := Warmup.new()
	main.add_child(warmup)
	var fired := [false]
	warmup.finished.connect(func(): fired[0] = true)
	await warmup.run(main)
	assert_true(fired[0])
	assert_eq(GameState.to_dict(), before)
	assert_eq(_pool_sizes(), sizes)
	assert_eq(warmup.get_child_count(), 0)
	assert_gte(warmup.built_count, 9)

func test_warmup_covers_every_monster_kind_and_the_boss_bar() -> void:
	_main()
	var warmup := Warmup.new()
	main.add_child(warmup)
	warmup.run(main)  # no await: runs to its first process_frame, the temporary nodes are in the tree
	var kinds := {}
	var mats: Array = []
	for c in warmup.get_children():
		if c is BoarVisual:
			assert_true(c.is_visible_in_tree())
			assert_eq(c._mesh_node.mesh, BoarMesh.get_mesh(c.kind), "%s mesh is on the node" % c.kind)
			kinds[c.kind] = true
		elif c is MeshInstance3D:
			mats.append(c.material_override)
	for k in MonsterBalance.KINDS:
		assert_true(kinds.has(k), "visual for %s" % k)
	assert_true(mats.has(BossBar.back_material()))
	assert_true(mats.has(BossBar.fill_material()))
	await warmup.finished
	assert_eq(warmup.get_child_count(), 0)

func test_boot_without_warmup_is_synchronous() -> void:
	_main()
	main.save_store = SaveStore.with_dir(dir)
	main.autosave.store = main.save_store
	assert_null(main.warmup)
	main._boot()
	assert_false(main.phase_controller.snapshot.is_empty())
	assert_ne(main.world.wave_director.state, WaveDirector.State.IDLE)

func test_music_track_follows_the_resume_phase() -> void:
	assert_eq(Warmup.music_for("NIGHT"), &"night")
	assert_eq(Warmup.music_for("DAY"), &"day")
	assert_eq(Warmup.music_for("CARD_PICK"), &"day")

func test_fade_material_is_a_dithered_copy() -> void:
	_main()
	var m := main.world.occluder_fade.fade_material_for_warmup()
	assert_not_null(m)
	assert_true(m is ShaderMaterial, "a dithered copy, drawn in the opaque pass")
	assert_almost_eq(OccluderFade.alpha_of(m), Balance.ui.occluder_alpha, 1e-3)

# --- BootFade (D-215 amendment) ---

func _fade() -> BootFade:
	var f := BootFade.new()
	add_child_autofree(f)
	return f

func test_boot_fade_waits_for_fade_out() -> void:
	var f := _fade()
	for i in 30:
		f._tick(0.016)
	assert_false(f.is_lifting())

func test_boot_fade_lifts_after_stable_frames() -> void:
	var f := _fade()
	f.fade_out()
	for i in Balance.ui.boot_fade_stable_frames - 1:
		f._tick(0.016)
	assert_false(f.is_lifting())
	f._tick(0.016)
	assert_true(f.is_lifting())

func test_boot_fade_slow_frame_resets_the_count() -> void:
	var f := _fade()
	f.fade_out()
	for i in 9:
		f._tick(0.016)
	f._tick(0.850)
	for i in 9:
		f._tick(0.016)
	assert_false(f.is_lifting())
	f._tick(0.016)
	assert_true(f.is_lifting())

func test_boot_fade_cap_lifts_anyway() -> void:
	var f := _fade()
	f.fade_out()
	var t := 0.0
	while t < Balance.ui.boot_fade_max_s - 0.2:
		f._tick(0.2)  # never stable
		t += 0.2
	assert_false(f.is_lifting())
	f._tick(0.3)
	assert_true(f.is_lifting())

func test_boot_fade_out_before_ready_is_harmless() -> void:
	var f := BootFade.new()
	f.fade_out()
	f._tick(0.016)
	add_child_autofree(f)
	for i in Balance.ui.boot_fade_stable_frames:
		f._tick(0.016)
	assert_true(f.is_lifting())

func test_warmup_nodes_sit_inside_the_camera_frustum() -> void:
	_main()
	var warmup := Warmup.new()
	main.add_child(warmup)
	await warmup.run(main)
	var cam := main.camera_rig.camera
	assert_eq(warmup.placed.size(), warmup.built_count)
	for p in warmup.placed:
		assert_true(cam.is_position_in_frustum(p), "%s is in view" % p)
	# The real lens at each supported aspect, not the headless viewport's own frustum (mutation: ROW = 8 puts slots 0, 7, 8, 15
	# at x = +-3.5 and +-2.5 m, outside the 2.30 m half-width of 9:16 and 9:21; the old un-centred ROW = 5 with 31 nodes puts the 7th row at y = +6 m).
	var xf := cam.global_transform
	for aspect in [9.0 / 21.0, 9.0 / 16.0, 16.0 / 9.0]:
		var proj := CameraMath.projection(Balance.ui, aspect)
		for p in warmup.placed:
			assert_true(CameraMath.on_screen(p, xf, proj), "%s is on screen at aspect %.3f" % [p, aspect])
	assert_true(warmup.built_count <= Warmup.CAPACITY, "%d nodes fit the %d-slot grid" % [warmup.built_count, Warmup.CAPACITY])

func test_music_track_is_night_without_a_phase() -> void:
	assert_eq(Warmup.music_for(""), &"night")

func test_boot_fade_runs_while_the_tree_is_paused() -> void:
	assert_eq(_fade().process_mode, Node.PROCESS_MODE_ALWAYS)

func test_boot_fade_safety_cap_lifts_without_fade_out() -> void:
	var f := _fade()
	var t := 0.0
	while t < Balance.ui.boot_fade_max_s * 3.0 - 0.5:
		f._tick(0.1)
		t += 0.1
	assert_false(f.is_lifting())
	f._tick(0.6)
	assert_true(f.is_lifting())

func test_warmup_prebuilds_the_top_tier_terrain_and_props() -> void:
	_main()
	var top := TierEffects.top_tier(Balance.data.tiers)
	assert_eq(top, 4, "the shipped build's top tier")
	var yards := MapLayout.yards_for_tier(top)
	var lanes := MapLayout.lanes_for_tier(top)
	var spread: float = Balance.data.enemy.lateral_spread
	var rects: Array[Rect2] = []
	for id in yards:
		rects.append(MapLayout.yard_rect(id))
	GroundArt._cache.erase(GroundArt._terrain_key(World.ground_rect(), yards, lanes, spread))
	Props._merged.erase(Props._key(rects))
	assert_false(GroundArt.is_cached(World.ground_rect(), yards, lanes))
	assert_false(Props.is_cached(rects))
	var warmup := Warmup.new()
	main.add_child(warmup)
	await warmup.run(main)
	assert_true(GroundArt.is_cached(World.ground_rect(), yards, lanes), "top-tier terrain built by the warm-up")
	assert_true(Props.is_cached(rects), "top-tier props merged by the warm-up")
	assert_eq(warmup.get_child_count(), 0, "no node left behind")

func test_warmup_draws_a_kerb_piece_when_the_top_tier_has_yards() -> void:
	_main()
	assert_false(MapLayout.yards_for_tier(TierEffects.top_tier(Balance.data.tiers)).is_empty(), "the top tier has yards")
	var warmup := Warmup.new()
	main.add_child(warmup)
	warmup.run(main)  # no await: the temporary nodes are in the tree
	var kerbs := warmup.get_children().filter(func(c): return c is MultiMeshInstance3D and c.multimesh.mesh is BoxMesh and c.multimesh.mesh.material == YardStones.material())
	assert_eq(kerbs.size(), 1, "one kerb piece with the kerb material")
	await warmup.finished
	assert_eq(warmup.get_child_count(), 0)

## E5 tier 3 Task 20: the tier-3 reveal's first step shows the lot's paving with the tier-2 lanes: that mesh is built before the tier-up.
func test_warmup_prebuilds_the_tier_3_reveals_first_step_mesh() -> void:
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)  # the tier-3 switch is Task 21: the test turns it on
	var spread: float = Balance.data.enemy.lateral_spread
	var first_step := GroundArt._terrain_key(World.ground_rect(), MapLayout.yards_for_tier(3), MapLayout.lanes_for_tier(2), spread)
	var full := GroundArt._terrain_key(World.ground_rect(), MapLayout.yards_for_tier(3), MapLayout.lanes_for_tier(3), spread)
	GroundArt._cache.erase(first_step)
	GroundArt._cache.erase(full)
	assert_false(GroundArt._cache.has(first_step))
	Warmup._prebuild_tier_caches()
	assert_true(GroundArt._cache.has(first_step), "the lot's paving with the tier-2 lanes")
	assert_true(GroundArt._cache.has(full), "the tier-3 terrain too")
	assert_true(GroundArt.is_cached(World.ground_rect(), MapLayout.yards_for_tier(3), MapLayout.lanes_for_tier(2), spread))

## E8 phase 2 Task 7: the tier-4 reveal's middle step shows the first back lot with the tier-4 lanes: that mesh is built before the tier-up.
func test_warmup_prebuilds_the_tier_4_reveals_middle_step_mesh() -> void:
	Tier4Support.open_tier4()
	var spread: float = Balance.data.enemy.lateral_spread
	var middle := TierReveal.stage_yards(4)
	assert_eq(middle, MapLayout.yards_for_tier(3) + ["north"], "the older yards and the first back lot")
	var key := GroundArt._terrain_key(World.ground_rect(), middle, MapLayout.lanes_for_tier(4), spread)
	var full := GroundArt._terrain_key(World.ground_rect(), MapLayout.yards_for_tier(4), MapLayout.lanes_for_tier(4), spread)
	GroundArt._cache.erase(key)
	GroundArt._cache.erase(full)
	assert_false(GroundArt._cache.has(key))
	Warmup._prebuild_tier_caches()
	assert_true(GroundArt._cache.has(key), "the middle step's mesh")
	assert_true(GroundArt._cache.has(full), "the tier-4 terrain too")

## E6 A2. Mutation: the warm-up draws no guard bar, or draws it unshaded (the boss bar's variant, not the guard's), or with shadows on.
func test_warmup_draws_the_guard_hp_bar_variant() -> void:
	_main()
	var warmup := Warmup.new()
	main.add_child(warmup)
	warmup.run(main)  # no await: the temporary nodes are in the tree
	var guard_mats: Array = []
	for c in warmup.get_children():
		if c is MeshInstance3D and c.material_override is StandardMaterial3D and c.mesh is BoxMesh:
			var m := c.material_override as StandardMaterial3D
			if m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and [Palette.color(&"ink"), Palette.color(&"guard_green")].has(m.albedo_color):
				assert_eq(c.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "like the guard's bar")
				assert_eq(m.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "the placed bar box is opaque like the guard's")
				assert_eq(m.cull_mode, BaseMaterial3D.CULL_BACK, "the placed bar box is single-sided like the guard's")
				guard_mats.append(m.albedo_color)
	assert_true(guard_mats.has(Palette.color(&"ink")), "the bar's ink backing")
	assert_true(guard_mats.has(Palette.color(&"guard_green")), "the bar's fill")
	await warmup.finished

## The warm-up builds its guard bars with the guard's own static builder, so they share every material feature that picks the shader.
## Fails if the builder starts to use an unshaded, blended or two-sided material (the warm-up would then compile the wrong variant).
func test_warmup_guard_bar_is_the_real_guards_bar_builder() -> void:
	var real := Guard.bar_box(Vector3.ONE, &"ink")
	var a := real.material_override as StandardMaterial3D
	assert_eq(a.shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL)
	assert_eq(a.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)
	assert_eq(a.cull_mode, BaseMaterial3D.CULL_BACK)
	assert_eq(real.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	real.free()

## E6 Task 14 (D-294.8): the warm-up draws the hero's and his carried pile's draw-after-labels variant (alpha, depth writing: a shader variant the
## opaque ones are not), at the hero's priority.
func test_warmup_draws_a_hero_visual_and_a_pile_in_the_front_variant() -> void:
	var parts := Warmup.hero_front_visuals()
	assert_eq(parts.size(), 2, "a hero visual and a pile")
	assert_true(parts[0] is HeroVisual)
	assert_true(parts[1] is MultiMeshInstance3D)
	var pm := (parts[1] as MultiMeshInstance3D).material_override as BaseMaterial3D
	assert_eq(pm.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_eq(pm.depth_draw_mode, BaseMaterial3D.DEPTH_DRAW_ALWAYS)
	assert_eq(pm.render_priority, Hero.DRAW_AFTER_LABELS_PRIORITY)
	for n in parts:
		n.free()
	_main()
	var warmup := Warmup.new()
	main.add_child(warmup)
	warmup.run(main)  # no await: the temporary nodes are in the tree
	var fronts := warmup.get_children().filter(func(c): return c is HeroVisual and _is_front_hero(c))
	assert_eq(fronts.size(), 1, "the run draws one hero visual in the front variant (the scene list's own hero is opaque)")
	var piles := warmup.get_children().filter(func(c): return c is MultiMeshInstance3D and c.material_override is BaseMaterial3D and (c.material_override as BaseMaterial3D).render_priority == Hero.DRAW_AFTER_LABELS_PRIORITY)
	assert_eq(piles.size(), 1, "the run draws one front-variant pile")
	await warmup.finished
	assert_eq(warmup.get_child_count(), 0)

## True when every surface of the hero visual is alpha, depth-writing, at the hero's draw-after-labels priority.
func _is_front_hero(hv: Node) -> bool:
	var surfaces := 0
	for mi in hv.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for k in m.mesh.get_surface_count():
			var b := m.get_active_material(k) as BaseMaterial3D
			if b == null or b.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA or b.depth_draw_mode != BaseMaterial3D.DEPTH_DRAW_ALWAYS or b.render_priority != Hero.DRAW_AFTER_LABELS_PRIORITY:
				return false
			surfaces += 1
	return surfaces > 0
