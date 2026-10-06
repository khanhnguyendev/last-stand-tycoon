extends GutTest

var main: Main
var dir := ""

func before_each() -> void:
	Balance.reset()
	dir = "user://test_saves/wu_%d" % Time.get_ticks_usec()

func after_each() -> void:
	SaveStore.with_dir(dir).wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_saves"))

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

func test_fade_material_is_a_transparent_copy() -> void:
	_main()
	var m := main.world.occluder_fade.fade_material_for_warmup()
	assert_not_null(m)
	assert_eq((m as BaseMaterial3D).transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)

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
