extends GutTest
## S5 Task 10 (spec 6, D-213): the Guide node. Built directly with setup(main); Task 11 wires it into Main.

const NOTCH_LANDSCAPE := {"top": 0.0, "bottom": 42.0, "left": 88.0, "right": 88.0}

var main: Main
var guide: Guide
var vp: SubViewport

func before_each() -> void:
	Balance.reset()

func after_each() -> void:
	SafeArea.override_for_tests = {}
	GameState.new_game(0)

func _boot(size := Vector2i(720, 1280), insets := {}) -> void:
	SafeArea.override_for_tests = insets
	vp = SubViewport.new()
	vp.size = size
	add_child_autofree(vp)
	main = Main.create()
	vp.add_child(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(20260930)
	guide = Guide.new()
	main.add_child(guide)
	guide.setup(main)
	await get_tree().process_frame
	vp.size_changed.emit()
	await get_tree().process_frame

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _day_with_freezer(hero_at: Vector2) -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.freezer_steaks = 10
	main.hero.teleport(hero_at)
	await _frames(40)
	await get_tree().process_frame
	guide.evaluate_now()
	await get_tree().process_frame

func test_snapshot_matches_the_game() -> void:
	await _boot()
	var b := main.world.wave_director.debug_spawn("north")
	b.dist = 3.0
	var st = main.world.steak_pool.acquire()
	st.place(Vector3(4, 0, -9))
	GameState.gold = 33
	GameState.carried_steaks = 2
	GameState.freezer_steaks = 5
	GameState.counter_steaks = 1
	GameState.gold_pile = 7
	var s := guide.snapshot()
	assert_eq(s.phase, Phase.NIGHT)
	assert_eq(s.day, GameState.day)
	assert_eq(s.gold, 33)
	assert_eq(s.carried, 2)
	assert_eq(s.freezer, 5)
	assert_eq(s.counter, 1)
	assert_eq(s.gold_pile, 7)
	assert_eq(s.carry_capacity, GameState.carry_capacity())
	assert_eq(s.counter_capacity, Balance.data.economy.counter_capacity)
	assert_eq(s.attack_range, Balance.data.hero.attack_range)
	assert_eq(s.move_m, Balance.ui.guide_move_m)
	assert_eq(s.hero_xz, main.hero.xz())
	assert_eq(s.boars.size(), 1)
	assert_almost_eq(float(s.boars[0].remaining), b.path_length() - 3.0, 0.001)
	assert_eq(s.boars[0].spawn_index, b.spawn_index)
	assert_eq(s.boars[0].pos, b.global_position)
	assert_eq(s.steaks, [Vector3(4, 0, -9)])
	assert_eq(s.spots.size(), MapLayout.SPOT_IDS.size())
	for i in MapLayout.SPOT_IDS.size():
		var id: String = MapLayout.SPOT_IDS[i]
		assert_eq(s.spots[i].id, id)
		assert_eq(s.spots[i].remaining, GameState.remaining_cost(id))
		assert_eq(s.spots[i].next_cost, GameState.next_level_cost(id))
	assert_eq(s.should_pulse, Pulse.should_pulse(GameState.to_dict(), Balance.data))

func test_walked_integrates_velocity_and_ignores_teleports() -> void:
	await _boot()
	assert_eq(guide.walked, 0.0)
	main.hero.input.set_move(Vector2(1, 0))
	await _frames(60)
	main.hero.input.set_move(Vector2.ZERO)
	await _frames(3)
	var w := guide.walked
	assert_gt(w, 1.0)
	main.hero.teleport(Vector2(8, 8))
	await _frames(10)
	assert_almost_eq(guide.walked, w, 0.001)
	EventBus.state_restored.emit()
	assert_eq(guide.walked, 0.0)

func test_evaluates_four_times_a_second_of_game_time() -> void:
	await _boot()
	var n := [0]
	guide.evaluated.connect(func() -> void: n[0] += 1)
	await _frames(60)
	assert_between(n[0], 3, 5)

func test_move_rule_shows_the_ghost_stick_and_no_pointer() -> void:
	await _boot()
	guide.evaluate_now()
	await get_tree().process_frame
	assert_eq(guide.rule_id, &"move")
	assert_true(guide.stick_visible())
	assert_false(guide.pointer.visible)
	assert_false(guide.arrow_visible())
	assert_true(guide.label.visible)
	assert_eq(guide.label.text, "Drag to move")
	assert_true(guide.edge_rect().grow(0.5).encloses(guide.label_rect()))

func test_offscreen_target_shows_an_edge_arrow_pointing_at_it() -> void:
	await _boot()
	await _day_with_freezer(MapLayout.NIGHT1_START)
	assert_eq(guide.rule_id, &"take")
	assert_eq(guide.target_id, &"freezer")
	assert_false(guide.pointer.visible)
	assert_true(guide.arrow_visible())
	var rect := main.hud.arrow_rect().grow(-Balance.ui.guide_rect_inset_px)
	assert_true(rect.grow(0.5).has_point(guide.arrow_position()), "arrow %s in %s" % [guide.arrow_position(), rect])
	var cam := vp.get_camera_3d()
	var target := cam.unproject_position(guide.target_position)
	var dir := (target - rect.get_center()).normalized()
	var down := Vector2(0, 1).rotated(guide.arrow_rotation())
	assert_gt(down.dot(dir), 0.9)
	assert_true(rect.grow(0.5).encloses(guide.label_rect()), "label %s in %s" % [guide.label_rect(), rect])

func test_onscreen_target_shows_the_world_pointer() -> void:
	await _boot()
	await _day_with_freezer(Vector2(3.0, 8.0))  # the freezer is in the middle of the screen
	assert_eq(guide.rule_id, &"take")
	assert_true(guide.pointer.visible)
	assert_false(guide.arrow_visible())
	var p := guide.pointer.global_position
	assert_almost_eq(p.x, guide.target_position.x, 0.001)
	assert_almost_eq(p.z, guide.target_position.z, 0.001)
	assert_between(p.y - guide.target_position.y, Balance.ui.guide_pointer_h - Balance.ui.guide_bounce_m - 0.001, Balance.ui.guide_pointer_h + Balance.ui.guide_bounce_m + 0.001)

func test_landscape_resize_keeps_arrow_and_label_in_the_safe_rect() -> void:
	await _boot(Vector2i(1280, 720), NOTCH_LANDSCAPE)
	await _day_with_freezer(Vector2(-12, -20))  # far from the freezer: off-screen in landscape
	assert_eq(guide.rule_id, &"take")
	var rect := main.hud.arrow_rect().grow(-Balance.ui.guide_rect_inset_px)
	var safe := Rect2(88, 0, 1280 - 176, 720 - 42)
	assert_true(safe.encloses(rect), "rect %s in safe %s" % [rect, safe])
	assert_true(guide.arrow_visible())
	assert_true(rect.grow(0.5).has_point(guide.arrow_position()), "arrow %s in %s" % [guide.arrow_position(), rect])
	assert_true(rect.grow(0.5).encloses(guide.label_rect()), "label %s in %s" % [guide.label_rect(), rect])
	# And back to portrait: still inside.
	vp.size = Vector2i(720, 1280)
	await get_tree().process_frame
	await get_tree().process_frame
	rect = main.hud.arrow_rect().grow(-Balance.ui.guide_rect_inset_px)
	assert_true(guide.arrow_visible())
	assert_true(rect.grow(0.5).has_point(guide.arrow_position()), "arrow %s in %s" % [guide.arrow_position(), rect])
	assert_true(rect.grow(0.5).encloses(guide.label_rect()), "label %s in %s" % [guide.label_rect(), rect])

func test_every_control_ignores_the_mouse() -> void:
	await _boot()
	var stack: Array = [guide.layer]
	var n := 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is Control:
			n += 1
			assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(node.get_path()))
	assert_gt(n, 2)

func test_layer_is_twelve() -> void:
	await _boot()
	assert_eq(guide.layer.layer, 12)

func test_pointer_is_one_surface_one_draw() -> void:
	await _boot()
	var mi := guide.pointer as MeshInstance3D
	assert_eq(mi.mesh.get_surface_count(), 1)
	assert_not_null(mi.material_override)

func test_debug_force_shows_each_rule() -> void:
	await _boot()
	for id in GuideRules.TEXT:
		guide.debug_force(id)
		await get_tree().process_frame
		assert_eq(guide.rule_id, id)
		assert_eq(guide.label.text, GuideRules.TEXT[id], str(id))
		assert_true(guide.label.visible)

func test_completes_at_night_two_not_at_night_one() -> void:
	await _boot()
	var n := [0]
	guide.completed.connect(func() -> void: n[0] += 1)
	guide.walked = 5.0
	EventBus.phase_changed.emit(Phase.NIGHT, 1)
	assert_eq(n[0], 0)
	assert_true(is_instance_valid(guide) and not guide.is_queued_for_deletion())
	assert_eq(guide.walked, 0.0)
	EventBus.phase_changed.emit(Phase.NIGHT, 2)
	assert_eq(n[0], 1)

func test_shows_nothing_while_the_night_is_failing() -> void:
	await _boot()
	guide.evaluate_now()
	await get_tree().process_frame
	assert_true(guide.label.visible)
	assert_true(guide.stick_visible())
	main.phase_controller.failing = true
	await get_tree().process_frame
	assert_false(guide.label.visible)
	assert_false(guide.stick_visible())
	assert_false(guide.pointer.visible)
	assert_false(guide.arrow_visible())
	main.phase_controller.failing = false

func test_fight_pointer_follows_its_boar_between_evaluations() -> void:
	await _boot()
	guide.walked = 5.0
	var b := main.world.wave_director.debug_spawn("north")
	b.dist = 10.0
	b.set_physics_process(false)
	b._update_position()
	guide.evaluate_now()
	assert_eq(guide.rule_id, &"fight")
	b.dist = 11.0
	b._update_position()
	await get_tree().process_frame
	assert_eq(guide.target_position, b.global_position)
