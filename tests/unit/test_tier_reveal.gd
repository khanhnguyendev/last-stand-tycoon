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
	if EventBus.card_offered.is_connected(_on_offered):
		EventBus.card_offered.disconnect(_on_offered)
	EventBus.banner_requested.disconnect(_on_banner)
	EventBus.sfx_requested.disconnect(_on_sfx)
	EventBus.fx_requested.disconnect(_on_fx)
	Balance.reset()  # drops the tier-3 cost entry
	GameState.new_game(1)

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
	EventBus.tier_reached.emit(4)  # tier 3 now has spots (E5 tier 3, Task 8): tier 4 is the first with neither yards nor spots
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

# --- E5 tier 3 Task 20: the tier-3 reveal, tap to skip (D-273.2), a reload mid-reveal ---

const DIR_BASE := "user://test_saves/tr_"

func _tier3_cost() -> void:
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)  # the tier-3 switch is Task 21: the test turns it on

## Plays to the tier-3 dawn through the real controller: tier 2 (its reveal ended by finish_reveal_now), the tier-3 sign paid, the
## boss night won. Nothing has run yet: the reveal's first frame.
func _tier2_day() -> void:
	_tier3_cost()
	_tier_up()
	main.phase_controller.finish_reveal_now()
	main.phase_controller.debug_skip_to_day()  # skips the tier-2 card pick

func _tier3_dawn() -> void:
	_tier2_day()
	_tier3_dawn_from_tier2_day()

func _tier3_dawn_from_tier2_day() -> void:
	GameState.add_gold(2000)  # test-only setup
	GameState.pay_into_tier(GameState.tier_next_cost())
	main.phase_controller.debug_skip_to_night()
	main.phase_controller.debug_skip_to_day()  # the won boss night's dawn

func _spread() -> float:
	return Balance.data.enemy.lateral_spread

## The terrain mesh the world shows at each stage of the tier-3 reveal (cached objects: same key, same mesh).
func _mesh_before_lot() -> Mesh:
	return GroundArt.terrain_mesh(World.ground_rect(), MapLayout.yards_for_tier(2), MapLayout.lanes_for_tier(2), _spread())

func _mesh_after_lot() -> Mesh:
	return GroundArt.terrain_mesh(World.ground_rect(), MapLayout.yards_for_tier(3), MapLayout.lanes_for_tier(2), _spread())

func _mesh_full() -> Mesh:
	return GroundArt.terrain_mesh(World.ground_rect(), MapLayout.yards_for_tier(3), MapLayout.lanes_for_tier(3), _spread())

func _kerb_count(yards: Array) -> int:
	var n := 0
	for id in yards:
		n += YardStones.transforms(MapLayout.yard_rect(id), MapLayout.yard_tier(id) >= 3, _spread()).size()
	return n

func _edge_count(lanes: Array) -> int:
	return LaneStrip.edge_multimesh(lanes).instance_count

func _diner_scene() -> String:
	return (main.world.diner_body.get_node("Visual").get_node("DinerArt") as Node).scene_file_path

func _wait_for_steps(n: int, base: int) -> void:
	while sfx.count(&"build_done") - base < n:
		await get_tree().physics_frame

## Everything the reveal hides or swaps, as one comparable value.
func _signature() -> Dictionary:
	var w := main.world
	var vis := w.diner_body.get_node("Visual")
	var art := vis.get_node("DinerArt") as Node3D
	var sw: TelegraphMarker = w.telegraph_markers["sw"]
	return {
		"ground": w.ground.mesh, "kerb": w.yard_stones.multimesh.instance_count, "edges": w.edge_stones.multimesh.instance_count,
		"diner": art.scene_file_path, "diner_scale": art.scale,
		"sw_flag": [sw.visible, sw.scale], "fence_sw": [w.build_spots["fence_sw"].marker.visible, w.build_spots["fence_sw"].marker.scale],
		"tower_sw": [w.build_spots["tower_sw"].marker.visible, w.build_spots["tower_sw"].marker.scale],
		"stones_visible": w.yard_stones.visible,
	}

func test_tier3_state_is_tier_3_with_five_steps_waiting_at_the_dawn() -> void:
	_tier3_dawn()
	assert_eq(GameState.tier, 3)
	assert_true(_reveal().running())
	# five steps: the lot, the lane, the fence spot, the tower spot, the storey (the branch pads appear with the first tier-3 day)
	assert_eq(_reveal().steps_left(), 5)

func test_tier3_things_are_hidden_before_their_step_and_shown_after_it_in_the_spec_order() -> void:
	_tier2_day()
	var w := main.world
	var kerb_tier2 := _hash_transforms(w.yard_stones.multimesh, w.yard_stones.multimesh.instance_count)  # what the player saw at tier 2
	var kerb_tier2_n: int = w.yard_stones.multimesh.instance_count
	var art_at_tier2 := _diner_scene()
	assert_eq(art_at_tier2, "res://art/env/diner_t2.tscn")
	_tier3_dawn_from_tier2_day()
	var reveal := _reveal()
	await _frames(_total_frames() + 5)  # the dawn's own reveal runs out; the same steps are replayed below so that every hidden thing is a change
	# the flag and the spots' markers are hidden at a dawn anyway: show them, so that hiding them is a change the reveal must make
	sfx.clear()
	fx.clear()
	(w.telegraph_markers["sw"] as TelegraphMarker).visible = true
	w.build_spots["fence_sw"].marker.visible = true
	w.build_spots["tower_sw"].marker.visible = true
	EventBus.tier_reached.emit(3)
	var kept := reveal._diner_kept
	assert_not_null(kept, "the new storey's art waits detached: the world built it once at the tier-up, the step puts the same node back")
	var kept_id := kept.get_instance_id()
	assert_eq(reveal.steps_left(), 5)
	# before step 1: everything the five steps bring is hidden / old
	assert_same(w.ground.mesh, _mesh_before_lot(), "ground: tier-2 paving only")
	assert_eq(w.yard_stones.multimesh.instance_count, kerb_tier2_n, "kerb: the tier-2 yards' pieces only")
	assert_eq(_hash_transforms(w.yard_stones.multimesh, kerb_tier2_n), kerb_tier2, "the pieces the player saw at tier 2, byte for byte")
	assert_eq(w.edge_stones.multimesh.instance_count, _edge_count(MapLayout.lanes_for_tier(2)), "edge stones: no south-west strip")
	assert_false((w.telegraph_markers["sw"] as TelegraphMarker).visible)
	assert_false(w.build_spots["fence_sw"].marker.visible)
	assert_false(w.build_spots["tower_sw"].marker.visible)
	assert_eq(_diner_scene(), "res://art/env/diner_t2.tscn", "the old storey")
	# step 1: the front lot
	await _wait_for_steps(1, 0)
	assert_same(w.ground.mesh, _mesh_after_lot(), "paving of the lot")
	assert_eq(w.yard_stones.multimesh.instance_count, _kerb_count(MapLayout.yards_for_tier(3)), "its kerb")
	assert_eq(_hash_transforms(w.yard_stones.multimesh, kerb_tier2_n), kerb_tier2, "the tier-2 pieces did not move")
	assert_eq(w.edge_stones.multimesh.instance_count, _edge_count(MapLayout.lanes_for_tier(2)), "no strip yet")
	assert_false((w.telegraph_markers["sw"] as TelegraphMarker).visible)
	assert_eq(fx[0][1], MapLayout.to3(MapLayout.yard_rect("front").get_center()), "dust on the lot")
	# step 2: the lane strip, its edge stones, its flag
	await _wait_for_steps(2, 0)
	assert_same(w.ground.mesh, _mesh_full())
	assert_eq(w.edge_stones.multimesh.instance_count, _edge_count(MapLayout.lanes_for_tier(3)))
	assert_true((w.telegraph_markers["sw"] as TelegraphMarker).visible, "the lane's flag")
	assert_false(w.build_spots["fence_sw"].marker.visible, "the spots wait")
	var lane_pt: Vector3 = fx[1][1]
	var path: Array = MapLayout.lane_path("sw")
	assert_lt(Geometry.dist_point_segment(Vector2(lane_pt.x, lane_pt.z), path[1], path[2]), 3.0, "dust on the lane's last stretch")
	# step 3: the fence spot, step 4: the tower spot
	await _wait_for_steps(3, 0)
	assert_true(w.build_spots["fence_sw"].marker.visible)
	assert_false(w.build_spots["tower_sw"].marker.visible)
	assert_eq(fx[2][1], MapLayout.to3(MapLayout.spot_position("fence_sw"), 1.0))
	await _wait_for_steps(4, 0)
	assert_true(w.build_spots["tower_sw"].marker.visible)
	assert_eq(fx[3][1], MapLayout.to3(MapLayout.spot_position("tower_sw"), 1.0))
	assert_eq(_diner_scene(), "res://art/env/diner_t2.tscn", "the storey still waits")
	# step 5: the second storey: the very node the world built, not a new instance
	await _wait_for_steps(5, 0)
	assert_eq(_diner_scene(), "res://art/env/diner_t3.tscn")
	var art := w.diner_body.get_node("Visual").get_node("DinerArt") as Node3D
	assert_eq(art.get_instance_id(), kept_id, "one instantiation of the tier-3 art in the tier-up, none at the step")
	assert_gt(art.scale.x, 1.0, "it pops")
	assert_eq(fx.size(), 5)
	assert_eq(reveal.steps_left(), 0)

func test_tier3_steps_are_the_literal_times_and_the_reveal_ends_at_tier_reveal_time() -> void:
	_tier3_dawn()
	var times := []
	var frame := 0
	while times.size() < 5 and frame < 400:
		var before := sfx.count(&"build_done")
		await get_tree().physics_frame
		frame += 1
		if sfx.count(&"build_done") > before:
			times.append(float(frame) / 60.0)
	gut.p("tier-3 step times (s): %s" % [times])
	assert_eq(times.size(), 5)
	var want := [0.60, 0.95, 1.30, 1.65, 2.00]
	for i in 5:
		assert_almost_eq(float(times[i]), float(want[i]), 0.02, "step %d" % (i + 1))
	assert_true(_reveal().running())
	assert_true(main.phase_controller.reveal_pending)
	await _frames(int(Balance.data.tiers.tier_reveal_time * 60.0) - frame - 8)
	assert_true(_reveal().running(), "still running just before 3.0 s")
	assert_true(main.phase_controller.reveal_pending)
	await _frames(16)
	assert_false(_reveal().running(), "over at 3.0 s")
	assert_false(main.phase_controller.reveal_pending, "the card pick opened")

func test_tier3_the_card_pick_opens_at_tier_reveal_time_and_the_world_is_whole() -> void:
	_tier3_dawn()
	assert_true(main.phase_controller.reveal_pending)
	await _frames(_total_frames() - 10)
	assert_true(main.phase_controller.reveal_pending)
	await _frames(15)
	assert_false(main.phase_controller.reveal_pending)
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK")
	var w := main.world
	assert_same(w.ground.mesh, _mesh_full())
	assert_eq(w.yard_stones.multimesh.instance_count, _kerb_count(MapLayout.yards_for_tier(3)))
	assert_eq(w.edge_stones.multimesh.instance_count, _edge_count(MapLayout.lanes_for_tier(3)))
	assert_eq(_diner_scene(), "res://art/env/diner_t3.tscn")
	assert_almost_eq(main.camera_rig.zoom_now(), 1.0, 0.02)

func test_tier2_reveal_is_unchanged_by_the_tier_3_list() -> void:
	_tier_up()
	assert_eq(_reveal().steps_left(), 5)
	assert_eq(Balance.ui.tier_reveal_step_s, 0.35, "tier 2 plays at the tuning's step time")
	assert_same(main.world.ground.mesh, GroundArt.terrain_mesh(World.ground_rect(), MapLayout.yards_for_tier(2), MapLayout.lanes_for_tier(2), _spread()), "tier 2 does not stage the ground")
	assert_eq(_diner_scene(), "res://art/env/diner_t2.tscn")

func test_a_restore_mid_tier3_reveal_puts_everything_back() -> void:
	_tier3_dawn()
	await _frames(_in_frames() + 3)  # step 1 ran
	assert_ne(main.world.ground.mesh, _mesh_full())
	EventBus.state_restored.emit()
	assert_same(main.world.ground.mesh, _mesh_full())
	assert_eq(main.world.yard_stones.multimesh.instance_count, _kerb_count(MapLayout.yards_for_tier(3)))
	assert_eq(main.world.edge_stones.multimesh.instance_count, _edge_count(MapLayout.lanes_for_tier(3)))
	assert_eq(_diner_scene(), "res://art/env/diner_t3.tscn")
	assert_false(_reveal().running())

func test_a_new_game_mid_tier3_reveal_rebuilds_tier_1() -> void:
	_tier3_dawn()
	await _frames(20)
	GameState.new_game(5)
	await get_tree().process_frame
	assert_eq(_diner_scene(), "res://art/env/diner.tscn")
	assert_eq(main.world.yard_ids(), [])
	assert_null(main.world.yard_stones)
	assert_same(main.world.ground.mesh, GroundArt.terrain_mesh(World.ground_rect(), [], MapLayout.lanes_for_tier(1), _spread()))

# --- the kerb: only the new yard's pieces are staged ---

func test_the_tier2_kerb_pieces_never_leave_during_the_tier3_reveal() -> void:
	_tier2_day()
	var w := main.world
	var tier2: int = w.yard_stones.multimesh.instance_count  # the kerb the player saw at tier 2, before the payment
	var hash_seen := _hash_transforms(w.yard_stones.multimesh, tier2)
	_tier3_dawn_from_tier2_day()
	assert_gt(_kerb_count(MapLayout.yards_for_tier(3)), tier2, "the front lot adds pieces")
	assert_eq(w.yard_stones.multimesh.instance_count, tier2, "staged: only the tier-2 pieces")
	assert_eq(_hash_transforms(w.yard_stones.multimesh, tier2), hash_seen, "the pieces the player saw, byte for byte, at the first frame")
	await _frames(_total_frames() + 5)
	assert_eq(w.yard_stones.multimesh.instance_count, _kerb_count(MapLayout.yards_for_tier(3)))
	assert_eq(_hash_transforms(w.yard_stones.multimesh, tier2), hash_seen, "and after the lot's step the same first pieces")
	assert_eq(w.find_children("YardStones*", "MultiMeshInstance3D", false, false).size(), 1, "still ONE kerb draw call")

func _hash_transforms(mm: MultiMesh, n: int) -> int:
	var arr := PackedFloat32Array()
	for i in n:
		var t := mm.get_instance_transform(i)
		arr.append_array([t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z])
	return hash(arr)

# --- the camera ---

func test_tier3_camera_frames_the_diner_the_lot_and_the_lanes_last_stretch() -> void:
	var pts := TierReveal.subject_points(3)
	var stretch := TierReveal.lane_stretch_points(Balance.ui.tier_reveal_lane_stretch_m)
	for q in stretch:
		assert_true(pts.has(MapLayout.to3(q)), "lane point %s is a subject" % q)
	for c in Geometry.rect_corners(MapLayout.yard_rect("front")):
		assert_true(pts.has(MapLayout.to3(c)), "front lot corner %s is a subject" % c)
	for aspect in [CameraMath.ASPECT, CameraMath.ASPECT_MIN]:
		var f := TierReveal.frame_for(3, Balance.ui, aspect)
		var xf := CameraMath.zoomed_transform(f.focus, Balance.ui, f.zoom)
		assert_true(_subject_on_screen(xf, aspect, 3), "every tier-3 subject point on screen at %.2f (zoom %.2f)" % [aspect, f.zoom])
		gut.p("tier 3 frame at aspect %.3f: zoom %.2f focus %s" % [aspect, f.zoom, f.focus])
	# without the lane's stretch the frame would be a different (tighter) one: the lane's far point is outside it
	var no_lane := pts.filter(func(p): return not stretch.any(func(q): return MapLayout.to3(q) == p))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in no_lane:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	var f3 := TierReveal.frame_for(3, Balance.ui)
	assert_ne(f3.focus, (lo + hi) * 0.5, "the lane's stretch moves the frame")

func test_tier3_held_camera_shows_every_subject_at_the_first_and_the_last_step() -> void:
	_tier3_dawn()
	var frame := TierReveal.frame_for(3, Balance.ui)
	var base := sfx.count(&"build_done")
	await _wait_for_steps(1, base)
	await get_tree().process_frame
	assert_almost_eq(main.camera_rig.zoom_now(), frame.zoom, 0.03)
	assert_true(_subject_on_screen(main.camera_rig.camera.global_transform, CameraMath.ASPECT, 3), "step 1")
	await _wait_for_steps(5, base)
	await get_tree().process_frame
	assert_true(_subject_on_screen(main.camera_rig.camera.global_transform, CameraMath.ASPECT, 3), "step 5")
	await _frames(_total_frames() + 30)
	var expect := CameraMath.camera_transform(CameraMath.focus_for(main.hero.xz()), Balance.ui)
	assert_true(main.camera_rig.camera.global_transform.is_equal_approx(expect), "back on the hero")

# --- tap to skip (D-273.2) ---

func _mouse(pressed := true, button := MOUSE_BUTTON_LEFT, device := 0) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = Vector2(360, 700)
	e.device = device
	return e

func _touch(pressed := true, pos := Vector2(360, 700)) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	e.index = 0
	e.position = pos
	return e

func _tap(ev: InputEvent) -> void:
	get_viewport().push_input(ev, true)  # local coordinates: the stretch must not rescale the position

var offered: Array = []

func _on_offered(o: Array) -> void:
	offered.append(o)

func test_a_click_during_the_tier3_reveal_applies_every_step_and_opens_the_pick() -> void:
	_tier3_dawn()
	EventBus.card_offered.connect(_on_offered)
	offered.clear()
	await _frames(_in_frames() + 5)  # after step 1
	assert_true(_reveal().steps_left() > 0 and _reveal().running())
	_tap(_mouse())
	EventBus.card_offered.disconnect(_on_offered)
	assert_false(main.phase_controller.reveal_pending)
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK")
	assert_eq(offered.size(), 1, "the pick opened at once")
	assert_false(_reveal().running())
	assert_eq(_reveal().steps_left(), 0)
	var w := main.world
	assert_same(w.ground.mesh, _mesh_full())
	assert_eq(w.yard_stones.multimesh.instance_count, _kerb_count(MapLayout.yards_for_tier(3)))
	assert_eq(w.edge_stones.multimesh.instance_count, _edge_count(MapLayout.lanes_for_tier(3)))
	assert_eq(_diner_scene(), "res://art/env/diner_t3.tscn")
	assert_eq((w.diner_body.get_node("Visual").get_node("DinerArt") as Node3D).scale, Vector3.ONE, "no pop left running")

func test_a_touch_skips_too_and_the_camera_eases_back_to_the_hero() -> void:
	_tier3_dawn()
	await _frames(_in_frames() + 10)
	assert_gt(main.camera_rig.zoom_now(), 1.1, "pulled back")
	var z0: float = main.camera_rig.zoom_now()
	_tap(_touch())
	assert_false(main.phase_controller.reveal_pending)
	await _frames(5)
	var z1: float = main.camera_rig.zoom_now()
	assert_lt(z1, z0, "easing back")
	assert_gt(z1, 1.0, "not a snap: a short ease")
	await _frames(int(Balance.ui.tier_reveal_skip_ease_s * 60.0) + 8)
	assert_almost_eq(main.camera_rig.zoom_now(), 1.0, 0.01)
	var expect := CameraMath.camera_transform(CameraMath.focus_for(main.hero.xz()), Balance.ui)
	assert_true(main.camera_rig.camera.global_transform.is_equal_approx(expect), "on the hero again")

func test_the_skip_leaves_the_state_a_reveal_that_ran_to_its_end_leaves() -> void:
	_tier3_dawn()
	await _frames(_total_frames() + 5)
	var natural := _signature()
	EventBus.tier_reached.emit(3)
	await _frames(_in_frames() + 5)  # step 1 ran, the lane's step has not
	assert_true(_reveal().running())
	assert_ne(_signature().ground, natural.ground, "mid-reveal differs")
	_reveal().skip()
	var skipped := _signature()
	for k in natural:
		assert_eq(skipped[k], natural[k], "after the skip: %s as after the full reveal" % k)

func test_a_click_during_the_tier2_reveal_skips_it_too() -> void:
	_tier_up()
	await _frames(_in_frames() + 5)
	assert_gt(_reveal().steps_left(), 0)
	_tap(_mouse())
	assert_false(main.phase_controller.reveal_pending)
	assert_eq(_reveal().steps_left(), 0)
	assert_false(_reveal().running())
	assert_true(main.world.yard_stones.visible)
	for s in _new_spots():
		var shown: bool = s.marker.visible
		s.refresh()
		assert_eq(s.marker.visible, shown, "markers are what refresh() says")
	assert_eq((main.world.diner_body.get_node("Visual").get_node("DinerArt") as Node3D).scale, Vector3.ONE)

func test_the_stale_reveal_timer_opens_no_second_pick_after_a_skip() -> void:
	_tier3_dawn()
	EventBus.card_offered.connect(_on_offered)
	offered.clear()
	await _frames(40)
	_tap(_mouse())
	assert_eq(offered.size(), 1)
	await _frames(_total_frames() + 20)  # the controller's own timer would have fired here
	EventBus.card_offered.disconnect(_on_offered)
	assert_eq(offered.size(), 1, "no second pick")
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK")

func test_only_a_press_of_the_left_button_or_a_touch_skips() -> void:
	_tier3_dawn()
	await _frames(40)
	_tap(_mouse(false))
	assert_true(main.phase_controller.reveal_pending, "a release is not a tap")
	_tap(_mouse(true, MOUSE_BUTTON_RIGHT))
	assert_true(main.phase_controller.reveal_pending, "a right click is not a tap")
	_tap(_touch(false))
	assert_true(main.phase_controller.reveal_pending, "a touch release is not a tap")
	_tap(_mouse(true, MOUSE_BUTTON_LEFT, InputEvent.DEVICE_ID_EMULATION))
	assert_true(main.phase_controller.reveal_pending, "the mouse event a touch emulates is not a second tap")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	_tap(key)
	assert_true(main.phase_controller.reveal_pending, "keyboard is not required")
	_tap(_mouse())
	assert_false(main.phase_controller.reveal_pending)

func test_a_tap_with_no_reveal_is_not_consumed_and_changes_nothing() -> void:
	main.phase_controller.debug_skip_to_day()  # a plain dawn: no reveal; then DAY
	assert_false(main.phase_controller.reveal_pending)
	var phase0 := main.phase_controller.phase
	var seen := []
	var catcher := _UnhandledCatcher.new()
	catcher.seen = seen
	add_child_autofree(catcher)
	_tap(_mouse())
	assert_eq(main.phase_controller.phase, phase0)
	assert_eq(seen.size(), 1, "the click goes on to everything else: it is not consumed outside a reveal")

## Stands for any button under the finger: it sees a press only when nothing handled it first (the GUI pass is not driven headless).
class _UnhandledCatcher extends Node:
	var seen: Array
	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			seen.append(e)

func test_the_skipping_tap_reaches_no_button_under_the_finger_and_starts_no_drag() -> void:
	_tier3_dawn()
	await _frames(40)
	var seen := []
	var catcher := _UnhandledCatcher.new()
	catcher.seen = seen
	add_child_autofree(catcher)
	_tap(_mouse())
	assert_false(main.phase_controller.reveal_pending, "it skipped")
	assert_eq(seen.size(), 0, "the press was consumed: nothing under the finger saw it")
	assert_false(main.joystick.is_active(), "and it started no drag")
	await _frames(10)
	assert_eq(main.hero.input.get_move(), Vector2.ZERO)

func test_the_joystick_is_disabled_from_the_dawn_until_the_reveal_ends_or_is_skipped() -> void:
	_tier3_dawn()
	var hero := main.hero
	var at := hero.xz()
	assert_true(main.phase_controller.reveal_pending)
	assert_true(hero.input.blocked, "blocked at the first frame of the reveal")
	# a drag during the reveal moves nothing (a touch on the joystick's own handler, away from the skipping controller)
	main.joystick.handle(_joy_touch(true, Vector2(360, 900)))
	main.joystick.handle(_joy_drag(Vector2(460, 900)))
	assert_false(main.joystick.is_active(), "the stick does not start")
	await _frames(30)
	assert_true(hero.input.blocked, "still blocked mid-reveal")
	assert_eq(hero.input.get_move(), Vector2.ZERO)
	assert_eq(hero.xz(), at)
	await _frames(10)
	_tap(_mouse())  # skip (past the guard): the card pick is open now
	assert_true(hero.input.blocked, "blocked at the card pick")
	main.joystick.handle(_joy_touch(true, Vector2(360, 900)))
	assert_false(main.joystick.is_active())
	EventBus.card_chosen.emit(GameState.card_offer[0])
	assert_false(hero.input.blocked, "free on the day")

func _joy_touch(pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	e.index = 3
	e.position = pos
	return e

func _joy_drag(pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = 3
	e.position = pos
	return e

# --- a reload mid-reveal ---

func test_a_reload_in_the_middle_of_the_tier3_reveal_resumes_at_the_card_pick_with_the_world_built() -> void:
	var dir := DIR_BASE + str(Time.get_ticks_usec())
	remove_child(main)
	main.free()
	GameState.new_game(1)
	_tier3_cost()
	# session 1: real autosave, up to the middle of the tier-3 reveal, then the tab closes
	main = Main.create()
	add_child(main)
	main.hero.input.player_control = false
	main.save_store = SaveStore.with_dir(dir)
	main.autosave.store = main.save_store
	main._boot()
	await get_tree().physics_frame
	_tier3_dawn()
	await _frames(_in_frames() + _step_frames() + 5)
	assert_true(_reveal().running(), "mid-reveal")
	assert_true(main.phase_controller.reveal_pending)
	var saved: Dictionary = SaveStore.with_dir(dir).read().state
	assert_eq(String(saved.resume_phase), "CARD_PICK", "the autosave wrote the card pick at the tier-up")
	assert_eq(int(saved.tier), 3)
	remove_child(main)
	main.free()
	GameState.new_game(1)  # a reload is a process restart
	# session 2: boots from the save
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.save_store = SaveStore.with_dir(dir)
	main.autosave.store = main.save_store
	main._boot()
	await get_tree().physics_frame
	var pc := main.phase_controller
	assert_eq([pc.phase, pc.dawn_substate, pc.reveal_pending], [Phase.DAWN, "CARD_PICK", false])
	assert_eq(GameState.tier, 3)
	assert_true(main.card_overlay.visible, "the card pick is open")
	assert_false(_reveal().running(), "no replay")
	var w := main.world
	assert_eq(_diner_scene(), "res://art/env/diner_t3.tscn")
	assert_same(w.ground.mesh, _mesh_full())
	assert_eq(w.yard_stones.multimesh.instance_count, _kerb_count(MapLayout.yards_for_tier(3)))
	assert_eq(w.edge_stones.multimesh.instance_count, _edge_count(MapLayout.lanes_for_tier(3)))
	assert_true(w.lanes.has("sw"))
	assert_true(w.telegraph_markers.has("sw"))
	assert_true(w.build_spots.has("tower_sw") and w.build_spots.has("fence_sw"))
	assert_eq(w.branch_pads.size(), 9, "the pads of every spot exist (18 pads)")  # their look is Task 17's; here only that the world is built
	await _frames(_total_frames() + 10)
	assert_eq(pc.dawn_substate, "CARD_PICK", "nothing else happens")
	SaveStore.with_dir(dir).wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_saves"))

# --- the skip guard (the first tier_reveal_skip_guard_s) ---

func test_a_press_in_the_first_0_6_s_is_consumed_and_skips_nothing_one_after_it_skips() -> void:
	_tier3_dawn()
	await _frames(10)
	var seen := []
	var catcher := _UnhandledCatcher.new()
	catcher.seen = seen
	add_child_autofree(catcher)
	_tap(_mouse())
	assert_true(main.phase_controller.reveal_pending, "a press at frame 10 (0.17 s) leaves the reveal running")
	assert_true(_reveal().running())
	assert_eq(seen.size(), 0, "the ignored press was consumed: it started nothing else")
	assert_false(main.joystick.is_active())
	await _frames(30)  # frame 40 (0.67 s)
	_tap(_mouse())
	assert_false(main.phase_controller.reveal_pending, "a press at frame 40 skips")
	assert_false(_reveal().running())

func test_the_guard_also_applies_to_the_tier2_reveal() -> void:
	_tier_up()
	await _frames(10)
	_tap(_touch())
	assert_true(main.phase_controller.reveal_pending)
	await _frames(30)
	_tap(_touch())
	assert_false(main.phase_controller.reveal_pending)

func test_the_guard_equals_the_camera_arrival() -> void:
	assert_eq(Balance.ui.tier_reveal_skip_guard_s, Balance.ui.tier_reveal_in_s, "step 1 is always seen")

# --- a tap that skips picks no card (the real targets read _input before the controller) ---

var chosen: Array = []

func _on_chosen(id: StringName) -> void:
	chosen.append(id)

func _card_centre(i: int) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return CardPickOverlay.layout(vp, SafeArea.insets(vp), GameState.card_offer.size(), Balance.ui)[i].get_center()

func test_a_full_tap_that_skips_picks_no_card() -> void:
	_tier3_dawn()
	await _frames(40)
	var offer := GameState.card_offer.duplicate()
	assert_gt(offer.size(), 0)
	EventBus.card_chosen.connect(_on_chosen)
	chosen.clear()
	var c := _card_centre(0)
	_tap(_touch(true, c))  # the press on the first card's rect skips the reveal
	assert_false(main.phase_controller.reveal_pending)
	assert_true(main.card_overlay.visible, "the pick is open")
	_tap(_touch(false, c))  # its release, at once: the overlay never owned the press
	assert_eq(chosen, [], "no card picked by the release")
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK")
	await _frames(int(ceil(Balance.ui.card_input_guard_s * 60.0)) + 5)
	assert_true(main.card_overlay.accepting())
	_tap(_touch(false, c))  # a release after the guard: still not owned
	assert_eq(chosen, [], "a late release picks nothing either")
	assert_eq(main.phase_controller.dawn_substate, "CARD_PICK")
	assert_eq(GameState.card_offer, offer, "the offer is intact")
	_tap(_touch(true, c))  # a fresh press and release picks
	_tap(_touch(false, c))
	EventBus.card_chosen.disconnect(_on_chosen)
	assert_eq(chosen.size(), 1, "a fresh tap picks the first card")
	assert_eq(chosen[0], offer[0])

func test_with_no_offer_the_skip_opens_the_day_and_the_drag_of_that_touch_moves_nobody() -> void:
	_tier3_dawn()
	var none: Array[StringName] = []
	GameState.stash_card_offer(none)  # test-only: a dawn with every card maxed
	await _frames(40)
	_tap(_touch(true, Vector2(360, 900)))
	assert_false(main.phase_controller.reveal_pending)
	assert_eq(main.phase_controller.phase, Phase.DAY, "no offer: the day begins at once")
	assert_false(main.hero.input.blocked)
	var at := main.hero.xz()
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(460, 900)
	_tap(drag)  # the same finger keeps moving
	assert_false(main.joystick.is_active(), "the stick follows only a press it began")
	assert_eq(main.hero.input.get_move(), Vector2.ZERO)
	await _frames(10)
	assert_eq(main.hero.xz(), at)
	_tap(_touch(false, Vector2(460, 900)))
	_tap(_touch(true, Vector2(360, 900)))  # a fresh press begins a drag
	assert_true(main.joystick.is_active())
