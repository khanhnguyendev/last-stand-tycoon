extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(71)

func test_camera_lens_follows_d145() -> void:
	var cam := main.camera_rig.camera
	var vp := main.get_viewport().get_visible_rect().size
	assert_true(vp.x > 0.0 and vp.y > 0.0)
	var probe := Camera3D.new()
	CameraMath.apply_lens(probe, Balance.ui, vp.x / vp.y)
	assert_eq(cam.keep_aspect, probe.keep_aspect)
	assert_almost_eq(cam.fov, probe.fov, 0.0001)
	assert_true(cam.current)
	probe.free()

func test_snap_matches_camera_math() -> void:
	main.hero.teleport(Vector2(3, -2))
	main.camera_rig.snap()
	var expect := CameraMath.camera_transform(CameraMath.focus_for(Vector2(3, -2)), Balance.ui)
	assert_true(main.camera_rig.camera.global_transform.is_equal_approx(expect))

func test_shake_has_cooldown() -> void:
	GameState.damage_diner(5.0)
	GameState.damage_diner(5.0)
	assert_eq(main.camera_rig.shake_count, 1)
	assert_almost_eq(main.camera_rig.shake_amp_now(), Balance.ui.shake_amp, Balance.ui.shake_amp * 0.1)
	await wait_seconds(Balance.ui.shake_time + 0.05)
	assert_eq(main.camera_rig.shake_amp_now(), 0.0, "the damaged shake lasts shake_time")
	await wait_seconds(Balance.ui.shake_cooldown)
	assert_eq(main.camera_rig.shake_count, 1)
	GameState.damage_diner(5.0)
	assert_eq(main.camera_rig.shake_count, 2)

func test_lens_reapplied_on_resize_d145() -> void:
	var svp := SubViewport.new()
	svp.size = Vector2i(720, 1280)
	add_child_autofree(svp)
	var m := Main.create()
	svp.add_child(m)
	var cam := m.camera_rig.camera
	assert_eq(cam.keep_aspect, Camera3D.KEEP_WIDTH)
	svp.size = Vector2i(1280, 720)
	assert_eq(cam.keep_aspect, Camera3D.KEEP_HEIGHT)
	assert_almost_eq(cam.fov, CameraMath.portrait_fov_v(Balance.ui), 0.0001)

func test_shake_decays_to_rest() -> void:
	GameState.damage_diner(1e9)  # damaged, then fell: the longer fell shake is the one that must end
	await wait_seconds(Balance.ui.shake_fell_time + 0.1)
	var expect := CameraMath.camera_transform(CameraMath.focus_for(main.hero.xz()), Balance.ui)
	assert_true(main.camera_rig.camera.global_transform.is_equal_approx(expect))

func test_fell_shake_ignores_cooldown() -> void:
	GameState.damage_diner(1e9)
	assert_eq(main.camera_rig.shake_count, 2, "damaged then fell")
	assert_gte(main.camera_rig.shake_amp_now(), Balance.ui.shake_fell_amp * 0.9)

func test_shake_disabled() -> void:
	Balance.ui.shake_enabled = false
	GameState.damage_diner(1e9)
	assert_eq(main.camera_rig.shake_count, 0)
	assert_eq(main.camera_rig.shake_amp_now(), 0.0)
	await wait_physics_frames(2)
	var expect := CameraMath.camera_transform(CameraMath.focus_for(main.hero.xz()), Balance.ui)
	assert_true(main.camera_rig.camera.global_transform.is_equal_approx(expect))

func test_damaged_after_fell_is_full_strength() -> void:
	var rig := main.camera_rig
	rig.shake(Balance.ui.shake_fell_amp, Balance.ui.shake_fell_time, false)
	await wait_seconds(Balance.ui.shake_fell_time + 0.1)
	await wait_seconds(Balance.ui.shake_cooldown)
	GameState.damage_diner(5.0)
	assert_almost_eq(rig.shake_amp_now(), Balance.ui.shake_amp, Balance.ui.shake_amp * 0.05)

func test_reveal_zooms_out_holds_and_comes_back() -> void:
	var rig := main.camera_rig
	var d0 := Balance.ui.camera_distance
	rig.reveal(0.2, 0.3, 0.2, 1.25)
	rig._process(0.1)
	assert_between(rig.zoom_now(), 1.0, 1.25)
	rig._process(0.1)
	assert_almost_eq(rig.zoom_now(), 1.25, 0.001, "out")
	rig._process(0.2)
	assert_almost_eq(rig.zoom_now(), 1.25, 0.001, "held")
	var focus_dist := rig.camera.global_position.distance_to(Vector3(rig._focus.x, 0.0, rig._focus.y))
	assert_almost_eq(focus_dist, d0 * 1.25, 0.01, "the camera moved along its view line")
	rig._process(0.15)
	rig._process(0.2)
	assert_almost_eq(rig.zoom_now(), 1.0, 0.001, "back")
	assert_eq(Balance.ui.camera_distance, d0, "UiTuning is never written")

func test_snap_to_and_restore_end_a_reveal() -> void:
	main.camera_rig.reveal(0.2, 0.3, 0.2, 1.25)
	main.camera_rig._process(0.2)
	assert_gt(main.camera_rig.zoom_now(), 1.0)
	main.camera_rig.snap_to(Vector2(1, 1))
	assert_eq(main.camera_rig.zoom_now(), 1.0)
	main.camera_rig.reveal(0.2, 0.3, 0.2, 1.25)
	main.camera_rig._process(0.2)
	EventBus.state_restored.emit()
	assert_eq(main.camera_rig.zoom_now(), 1.0)

func test_reveal_focus_override_moves_and_returns() -> void:
	var rig := main.camera_rig
	main.hero.teleport(Vector2(0, 8))
	rig.snap()
	var hero_focus := CameraMath.focus_for(Vector2(0, 8))
	rig.reveal(0.2, 0.3, 0.2, 1.5, Vector2(-5, 2))
	assert_true(rig.has_focus_override())
	rig._process(0.2)
	rig._process(0.1)
	var held := CameraMath.zoomed_transform(Vector2(-5, 2), Balance.ui, 1.5)
	assert_true(rig.camera.global_transform.is_equal_approx(held), "held at the reveal focus, as given")
	rig._process(0.2)
	rig._process(0.2)
	assert_false(rig.has_focus_override())
	assert_true(rig.camera.global_transform.is_equal_approx(CameraMath.camera_transform(hero_focus, Balance.ui)))

func test_snap_to_cancels_the_focus_override() -> void:
	main.camera_rig.reveal(0.2, 0.3, 0.2, 1.5, Vector2(-5, 2))
	main.camera_rig.snap_to(Vector2(1, 1))
	assert_false(main.camera_rig.has_focus_override())
	assert_eq(main.camera_rig.zoom_now(), 1.0)
