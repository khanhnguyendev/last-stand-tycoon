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
	await wait_seconds(Balance.ui.shake_cooldown + 0.1)
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
	GameState.damage_diner(5.0)
	await wait_seconds(Balance.ui.shake_time + 0.1)
	var expect := CameraMath.camera_transform(CameraMath.focus_for(main.hero.xz()), Balance.ui)
	assert_true(main.camera_rig.camera.global_transform.is_equal_approx(expect))
