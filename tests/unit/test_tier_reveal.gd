extends GutTest
## E5 spec 7.5: the reveal is visual, ordered, killed by a restore, and the state is already saved before it starts.

var main: Main
var banners: Array = []
var sfx: Array = []
var fx: Array = []

func _on_banner(t) -> void:
	banners.append(t)

func _on_sfx(id) -> void:
	sfx.append(id)

func _on_fx(kind, pos) -> void:
	fx.append([kind, pos])

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	await get_tree().physics_frame
	main.phase_controller.start_new_game(20260930)
	banners.clear()
	sfx.clear()
	fx.clear()
	EventBus.banner_requested.connect(_on_banner)
	EventBus.sfx_requested.connect(_on_sfx)
	EventBus.fx_requested.connect(_on_fx)

func after_each() -> void:
	EventBus.banner_requested.disconnect(_on_banner)
	EventBus.sfx_requested.disconnect(_on_sfx)
	EventBus.fx_requested.disconnect(_on_fx)

func _tier_up() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.add_gold(500)  # test-only setup
	GameState.pay_into_tier(GameState.tier_next_cost())
	main.phase_controller.debug_skip_to_night()
	main.phase_controller.debug_skip_to_day()  # the won boss night's dawn

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _in_frames() -> int:
	return int(round(Balance.ui.tier_reveal_in_s * 60.0))

func _total_frames() -> int:
	return int(round(Balance.data.tiers.tier_reveal_time * 60.0))

func _step_frames() -> int:
	return int(round(Balance.ui.tier_reveal_step_s * 60.0))

func _reveal() -> TierReveal:
	return main.world.tier_reveal

func _new_spots() -> Array:
	var out := []
	for id in MapLayout.TIER_SPOTS[GameState.tier]:
		out.append(main.world.build_spots[id])
	return out

func test_state_is_tier_2_before_the_first_step() -> void:
	_tier_up()
	assert_eq(GameState.tier, 2)
	assert_eq(main.world.yard_ids(), ["west", "east"], "World rebuilt before the reveal pops things in")
	assert_eq(_reveal().steps_left(), 5, "nothing has run yet")

func test_banner_and_pull_back_start_with_the_reveal() -> void:
	_tier_up()
	assert_true(_reveal().running())
	assert_true(banners.has(tr("The diner grows!")))
	await _frames(20)
	assert_gt(main.camera_rig.zoom_now(), 1.0, "pulled back")

func test_steps_run_in_order_one_sound_each_and_things_reappear() -> void:
	_tier_up()
	var reveal := _reveal()
	var base := sfx.count(&"build_done")
	var fx0 := fx.size()
	var west := MapLayout.to3((MapLayout.YARDS["west"] as Rect2).get_center())
	var east := MapLayout.to3((MapLayout.YARDS["east"] as Rect2).get_center())
	assert_false(main.world.yard_stones.visible, "stones hidden at the start")
	for s in _new_spots():
		assert_false(s.marker.visible, "markers hidden at the start")
	# step 1 runs when the camera has reached its frame (tier_reveal_in_s)
	await _frames(_in_frames() - 5)
	assert_eq(sfx.count(&"build_done") - base, 0, "nothing plays while the camera is still moving in")
	await _frames(8)
	assert_eq(sfx.count(&"build_done") - base, 1)
	assert_eq(fx[fx0][1], west, "dust at the west yard")
	assert_false(main.world.yard_stones.visible)
	await _frames(_step_frames())
	assert_eq(sfx.count(&"build_done") - base, 2)
	assert_true(main.world.yard_stones.visible, "stones appear at step 2")
	await _frames(_step_frames())
	assert_eq(sfx.count(&"build_done") - base, 3, "the diner pops")
	var art := main.world.diner_body.get_node("Visual").get_node_or_null("DinerArt") as Node3D
	assert_gt(art.scale.x, 1.0, "pop in flight")
	await _frames(_step_frames())
	assert_eq(sfx.count(&"build_done") - base, 4)
	assert_eq(fx[fx0 + 3][1], east, "dust at the east yard")
	for s in _new_spots():
		assert_false(s.marker.visible, "markers still hidden")
	await _frames(_step_frames())
	assert_eq(sfx.count(&"build_done") - base, 5)
	for s in _new_spots():
		assert_true(s.marker.visible, "markers pop at step 5")
	assert_eq(reveal.steps_left(), 0)
	assert_eq(fx.size() - fx0, 5)

func test_after_the_last_step_nothing_is_left_hidden() -> void:
	_tier_up()
	await _frames(_total_frames() + 5)
	assert_false(_reveal().running())
	assert_true(main.world.yard_stones.visible)
	for s in _new_spots():
		var shown: bool = s.marker.visible
		s.refresh()
		assert_eq(s.marker.visible, shown, "marker is what refresh() says")
		assert_eq(s.marker.scale, Vector3.ONE)
	var art := main.world.diner_body.get_node("Visual").get_node("DinerArt") as Node3D
	assert_eq(art.scale, Vector3.ONE)

func test_restore_kills_the_reveal_and_puts_everything_back() -> void:
	_tier_up()
	await _frames(_step_frames() + 5)
	assert_true(_reveal().running())
	assert_gt(main.camera_rig.zoom_now(), 1.0)
	GameState.new_game(3)
	await get_tree().process_frame
	assert_false(_reveal().running())
	assert_eq(_reveal().steps_left(), 0)
	assert_almost_eq(main.camera_rig.zoom_now(), 1.0, 1e-6)
	assert_true(main.world.yard_stones == null or main.world.yard_stones.visible)

func test_restore_before_the_stones_step_restores_visibility() -> void:
	_tier_up()
	assert_false(main.world.yard_stones.visible)
	var stones := main.world.yard_stones
	var spots := _new_spots()
	EventBus.state_restored.emit()
	assert_true(stones.visible)
	for s in spots:
		var shown: bool = s.marker.visible
		s.refresh()
		assert_eq(s.marker.visible, shown)

func test_a_second_tier_reached_restarts_cleanly() -> void:
	_tier_up()
	await _frames(_in_frames() + _step_frames() * 2 + 3)
	var left := _reveal().steps_left()
	assert_lt(left, 5)
	EventBus.tier_reached.emit(2)
	assert_eq(_reveal().steps_left(), 5, "restarted")
	assert_true(_reveal().running())
	assert_false(main.world.yard_stones.visible)
	await _frames(_total_frames() + 5)
	assert_false(_reveal().running())
	assert_true(main.world.yard_stones.visible)

func test_camera_is_back_at_rest_by_the_card_pick() -> void:
	_tier_up()
	assert_true(main.phase_controller.reveal_pending)
	await _frames(int(Balance.data.tiers.tier_reveal_time * 60.0) + 2)
	assert_almost_eq(main.camera_rig.zoom_now(), 1.0, 0.02)
	assert_false(main.phase_controller.reveal_pending, "the card pick opened on time")

func test_the_reveal_does_not_delay_the_card_pick() -> void:
	_tier_up()
	await _frames(int(Balance.data.tiers.tier_reveal_time * 60.0) - 10)
	assert_true(main.phase_controller.reveal_pending)
	await _frames(15)
	assert_false(main.phase_controller.reveal_pending)

func test_the_whole_camera_move_fits_the_reveal_time() -> void:
	var ui := Balance.ui
	assert_lte(ui.tier_reveal_in_s + ui.tier_reveal_out_s, Balance.data.tiers.tier_reveal_time)

func test_the_reveal_never_writes_game_state() -> void:
	var src := FileAccess.get_file_as_string("res://world/tier_reveal.gd")
	assert_false("GameState" in src, "no GameState access at all")
	assert_false("get_parent()" in src, "no reaching into another system's nodes")
	assert_false("camera_rig" in src, "the camera is asked through the bus")
	assert_false("Rng." in src)
	assert_false("randf" in src or "randi" in src)

# --- Fix round 1: the reveal camera frames the diner and the new yards ---

func _subject_on_screen(xf: Transform3D, aspect: float, tier: int) -> bool:
	var proj := CameraMath.projection(Balance.ui, aspect)
	for p in TierReveal.subject_points(tier):
		if not CameraMath.on_screen(p, xf, proj):
			return false
	return true

func test_fit_frames_every_subject_point_at_9_16() -> void:
	var f := TierReveal.frame_for(2, Balance.ui)
	assert_between(f.zoom, 1.0, Balance.ui.tier_reveal_zoom)
	var xf := CameraMath.zoomed_transform(f.focus, Balance.ui, f.zoom)
	assert_true(_subject_on_screen(xf, CameraMath.ASPECT, 2), "all subject points on screen")
	assert_lt(f.zoom, Balance.ui.tier_reveal_zoom + 1e-6, "fits at or under the cap")
	gut.p("fitted zoom %.2f focus %s cap %.2f" % [f.zoom, f.focus, Balance.ui.tier_reveal_zoom])

func test_fit_at_9_21_for_the_report() -> void:
	var f := TierReveal.frame_for(2, Balance.ui, CameraMath.ASPECT_MIN)
	var xf := CameraMath.zoomed_transform(f.focus, Balance.ui, f.zoom)
	gut.p("9:21 fitted zoom %.2f fits=%s" % [f.zoom, _subject_on_screen(xf, CameraMath.ASPECT_MIN, 2)])
	assert_true(_subject_on_screen(xf, CameraMath.ASPECT_MIN, 2))

func test_fit_with_no_yards_is_the_diner_alone() -> void:
	var f := TierReveal.frame_for(1, Balance.ui)
	assert_eq(f.focus, Vector2.ZERO)
	assert_almost_eq(f.zoom, 1.0, 1e-6)

func test_held_camera_frames_the_subject_at_the_first_and_the_last_step() -> void:
	_tier_up()
	var frame := TierReveal.frame_for(2, Balance.ui)
	var base := sfx.count(&"build_done")
	while sfx.count(&"build_done") == base:
		await get_tree().physics_frame
	await get_tree().process_frame
	assert_almost_eq(main.camera_rig.zoom_now(), frame.zoom, 0.02, "at the first step the camera is at its frame")
	assert_true(_subject_on_screen(main.camera_rig.camera.global_transform, CameraMath.ASPECT, 2), "first step on screen")
	while sfx.count(&"build_done") - base < 5:
		await get_tree().physics_frame
	await get_tree().process_frame
	assert_almost_eq(main.camera_rig.zoom_now(), frame.zoom, 0.02, "at the last step the camera still holds")
	assert_true(_subject_on_screen(main.camera_rig.camera.global_transform, CameraMath.ASPECT, 2), "last step on screen")

func test_after_the_reveal_the_focus_follows_the_hero_again() -> void:
	_tier_up()
	await _frames(int(Balance.data.tiers.tier_reveal_time * 60.0) + 30)
	assert_almost_eq(main.camera_rig.zoom_now(), 1.0, 0.02)
	var hero_xy := main.hero.xz()
	var expect := CameraMath.camera_transform(CameraMath.focus_for(hero_xy), Balance.ui)
	assert_true(main.camera_rig.camera.global_transform.is_equal_approx(expect), "back on the hero")

func test_restore_cancels_zoom_and_focus_override() -> void:
	_tier_up()
	await _frames(60)
	EventBus.state_restored.emit()
	assert_eq(main.camera_rig.zoom_now(), 1.0)
	assert_false(main.camera_rig.has_focus_override())

func test_markers_stay_shown_until_the_reveal_ends_at_tier_reveal_time() -> void:
	_tier_up()
	await _frames(int(2.5 * 60.0))
	assert_true(_reveal().running())
	for s in _new_spots():
		assert_true(s.marker.visible, "shown at 2.5 s")
	await _frames(int(0.4 * 60.0) - 6)  # about 2.9 s
	assert_true(_reveal().running(), "still running at 2.9 s")
	await _frames(int(Balance.data.tiers.tier_reveal_time * 60.0) - int(2.9 * 60.0) + 8)
	assert_false(_reveal().running(), "ended just after tier_reveal_time")
	assert_false(main.phase_controller.reveal_pending, "the card pick opened too")

func test_the_last_step_and_its_pop_fit_before_the_card_pick() -> void:
	var ui := Balance.ui
	var n := 5
	assert_lte(ui.tier_reveal_in_s + (n - 1) * ui.tier_reveal_step_s + ui.build_pop_time, Balance.data.tiers.tier_reveal_time)

func test_a_tier_with_no_yards_and_no_spots_runs_the_diner_step_only() -> void:
	_tier_up()
	await _frames(_total_frames() + 5)
	sfx.clear()
	fx.clear()
	banners.clear()
	EventBus.tier_reached.emit(3)
	assert_true(banners.has(tr("The diner grows!")))
	assert_true(_reveal().running())
	assert_eq(_reveal().steps_left(), 1)
	await _frames(_total_frames() + 5)
	assert_false(_reveal().running())
	assert_eq(sfx.count(&"build_done"), 1, "the diner step")
	for f in fx:
		assert_ne(f[1], Vector3.ZERO, "no dust at the origin")

func test_the_fit_numbers_are_pinned() -> void:
	var f := TierReveal.frame_for(2, Balance.ui)
	assert_almost_eq(f.zoom, 2.15, 1e-3)
	assert_almost_eq(f.focus.x, -0.25, 1e-3)
	assert_almost_eq(f.focus.y, 2.0, 1e-3)
	var xf := CameraMath.zoomed_transform(f.focus, Balance.ui, f.zoom - 0.05)
	assert_false(_subject_on_screen(xf, CameraMath.ASPECT, 2), "one step less does not fit")

func test_step_gap_is_longer_than_the_build_done_min_gap() -> void:
	var gap: float = AudioManifest.SFX[&"build_done"].min_gap_s
	assert_gt(Balance.ui.tier_reveal_step_s, gap, "a retune must not drop the step sounds")
