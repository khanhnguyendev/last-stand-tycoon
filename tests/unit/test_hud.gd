extends GutTest

var main: Main
var hud: Hud

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(81)
	hud = main.hud
	# start_new_game emits a banner; drain it so each test starts with no banner showing.
	hud._banner_queue.clear()
	hud._banner_left = 0.0
	hud._show_next_banner()

func test_gold_label_follows_gold() -> void:
	GameState.add_gold(42)
	assert_eq(hud.gold_label.text, "42")

func test_moons_fill_and_reset() -> void:
	EventBus.wave_cleared.emit(0)
	EventBus.wave_cleared.emit(1)
	assert_eq(hud.filled_moons(), 2)
	EventBus.phase_changed.emit(Phase.NIGHT, 2)
	assert_eq(hud.filled_moons(), 0)

func test_day_label_and_moons_visibility() -> void:
	main.phase_controller.debug_skip_to_day()
	assert_true(hud.day_label.visible)
	assert_eq(hud.day_label.text, "Day 2")
	assert_false(hud.moons[0].visible)
	assert_false(hud.arrows.main.visible)
	assert_false(hud.arrows.side.visible)

func test_arrows_hidden_when_night_ends_mid_wave() -> void:
	EventBus.wave_incoming.emit(1, &"west", &"east")
	assert_true(hud.arrows.main.visible)
	EventBus.phase_changed.emit(Phase.DAY, 2)
	assert_false(hud.arrows.main.visible)
	assert_false(hud.arrows.side.visible)
	await get_tree().process_frame
	assert_false(hud.arrows.main.visible)

func test_moons_match_lane_plan() -> void:
	EventBus.phase_changed.emit(Phase.NIGHT, 1)
	assert_eq(hud.moons.size(), GameState.lane_plan.size())

func test_diner_bar() -> void:
	var max_hp := Balance.data.build.diner_max_hp
	GameState.damage_diner(30.0)
	assert_almost_eq(hud.diner_bar.value, max_hp - 30.0, 0.001)
	GameState.from_dict(main.phase_controller.snapshot)
	assert_almost_eq(hud.diner_bar.value, max_hp, 0.001)

func test_banner_shows_then_hides() -> void:
	EventBus.banner_requested.emit("Dawn")
	assert_true(hud.banner.visible)
	assert_eq(hud.banner.text, "Dawn")
	for i in int(Balance.ui.banner_time * 60 * 0.875):
		await get_tree().process_frame
	assert_between(hud.banner_panel.modulate.a, 0.05, 0.95)
	for i in int(Balance.ui.banner_time * 60 * 0.125) + 30:
		await get_tree().process_frame
	assert_false(hud.banner.visible)

func test_arrows_follow_wave_events_and_stay_on_screen() -> void:
	EventBus.wave_incoming.emit(1, &"west", &"east")
	await get_tree().process_frame
	assert_true(hud.arrows.main.visible)
	assert_true(hud.arrows.side.visible)
	var rect := hud.root.get_viewport_rect()
	assert_true(rect.has_point(hud.arrows.main.position))
	assert_lt(hud.arrows.side.scale.x, hud.arrows.main.scale.x)
	EventBus.wave_spawned_out.emit(1)
	assert_false(hud.arrows.main.visible)

func test_safe_area_insets_non_negative_and_applied() -> void:
	var ins := SafeArea.insets(Vector2(720, 1280))
	for k in ["top", "bottom", "left", "right"]:
		assert_true(float(ins[k]) >= 0.0, k)
	assert_eq(hud.root.offset_top, float(ins.top))

func test_safe_area_reapplied_on_resize() -> void:
	hud.root.offset_top = 999.0
	hud.root.offset_left = 999.0
	hud.get_viewport().size_changed.emit()
	var ins := SafeArea.insets(hud.root.get_viewport_rect().size)
	assert_eq(hud.root.offset_top, float(ins.top))
	assert_eq(hud.root.offset_left, float(ins.left))

func test_offscreen_arrow_is_pinned_inside_root_space() -> void:
	var cam := main.camera_rig.camera
	var grown := hud._arrow_rect()
	var far := ""
	for k in main.world.lanes:
		var pos: Vector3 = main.world.lanes[k].entrance_position()
		if cam.is_position_behind(pos) or not grown.has_point(cam.unproject_position(pos)):
			far = String(k)
	assert_ne(far, "", "a lane entrance is off-screen")
	EventBus.wave_incoming.emit(1, &"west", StringName(far))
	await get_tree().process_frame
	var arrow: Polygon2D = hud.arrows.side
	var g := arrow.position + hud.root.position
	assert_true(hud.root.get_global_rect().has_point(g))
	var d := minf(minf(absf(g.x - grown.position.x), absf(g.x - grown.end.x)), minf(absf(g.y - grown.position.y), absf(g.y - grown.end.y)))
	assert_lt(d, 1.0)

func test_banner_is_horizontally_centred_and_wraps() -> void:
	# The backing panel owns the layout; the label fills it.
	var p := hud.banner_panel
	assert_eq(p.anchor_left, 0.0)
	assert_eq(p.anchor_right, 1.0)
	assert_almost_eq(p.anchor_top, 0.4, 0.0001)
	assert_almost_eq(p.anchor_bottom, 0.4, 0.0001)
	assert_eq(p.offset_left, -p.offset_right, "symmetric side margins")
	assert_eq(hud.banner.get_parent(), p)
	assert_eq(hud.banner.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)

func test_top_column_is_centred_at_any_width() -> void:
	var col := hud.diner_bar.get_parent().get_parent() as Control
	assert_eq(col.anchor_left, 0.5)
	assert_eq(col.anchor_right, 0.5)
	assert_eq(col.anchor_top, 0.0)
	assert_eq(col.grow_horizontal, Control.GROW_DIRECTION_BOTH)

func test_diner_bar_shake_returns_to_rest() -> void:
	GameState.damage_diner(5.0)
	GameState.damage_diner(5.0)
	for i in int(Balance.ui.diner_bar_shake_time * 60 * 2) + 10:
		await get_tree().process_frame
	assert_eq(hud.diner_bar.position.x, 0.0)

func test_diner_bar_is_visible_with_real_size_and_styles() -> void:
	await get_tree().process_frame
	assert_true(hud.diner_bar.is_visible_in_tree(), "always visible (day and night)")
	var r := hud.diner_bar.get_global_rect()
	assert_gte(r.size.x, Hud.BAR_SIZE.x, "fills its slot, not the 4px default")
	assert_gte(r.size.y, Hud.BAR_SIZE.y)
	assert_not_null(hud.diner_bar.get_theme_stylebox("fill"))
	assert_true(hud.diner_bar.has_theme_stylebox_override("fill"))
	assert_true(hud.diner_bar.has_theme_stylebox_override("background"))
	var fill := hud.diner_bar.get_theme_stylebox("fill") as StyleBoxFlat
	assert_eq(fill.bg_color, Visuals.COLORS.diner_hp)
	main.phase_controller.debug_skip_to_night()
	await get_tree().process_frame
	assert_true(hud.diner_bar.is_visible_in_tree(), "still visible at night")
	var before := hud.diner_bar.value
	GameState.damage_diner(10.0)
	assert_lt(hud.diner_bar.value, before)

func test_banner_has_readable_backing() -> void:
	EventBus.banner_requested.emit("Night 1")
	var panel: PanelContainer = hud.banner_panel
	assert_true(panel.visible)
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(sb)
	assert_almost_eq(sb.bg_color.a, Balance.ui.banner_panel_alpha, 0.001)
	for i in int(Balance.ui.banner_time * 60) + 30:
		await get_tree().process_frame
	assert_false(panel.visible)
	assert_false(hud.banner.visible)

func test_arrows_stay_below_the_top_hud() -> void:
	EventBus.wave_incoming.emit(0, &"north", &"")
	await get_tree().process_frame
	var col := hud._top_column
	var arrow_top: float = hud.arrows.main.position.y + hud.root.position.y - Hud.ARROW_EXTENT
	assert_gte(arrow_top, col.get_global_rect().end.y)
	assert_gte(arrow_top, hud.gold_label.get_global_rect().end.y)

func test_second_banner_shortens_the_first_then_plays_in_full() -> void:
	EventBus.banner_requested.emit("One")
	var shown := int(Balance.ui.banner_time * 60 * 0.9)
	for i in shown:
		await get_tree().process_frame
	EventBus.banner_requested.emit("Two")
	var r := minf(Balance.ui.banner_time - shown / 60.0, Balance.ui.banner_min_s)
	for i in int(ceil(r * 60.0)) + 3:
		await get_tree().process_frame
	assert_eq(hud.banner.text, "Two")
	assert_almost_eq(hud.banner_panel.modulate.a, 1.0, 1e-3)
	for i in int(Balance.ui.banner_time * 60 * 0.7):
		await get_tree().process_frame
	assert_true(hud.banner_panel.visible)
	assert_almost_eq(hud.banner_panel.modulate.a, 1.0, 1e-3)

func test_queued_banners_play_in_order() -> void:
	EventBus.banner_requested.emit("A")
	EventBus.banner_requested.emit("B")
	EventBus.banner_requested.emit("C")
	assert_eq(hud.banner.text, "A")
	var seen := ["A"]
	for i in int((Balance.ui.banner_min_s * 2.0 + Balance.ui.banner_time) * 60.0) + 30:
		await get_tree().process_frame
		if hud.banner.visible and seen[-1] != hud.banner.text:
			seen.append(hud.banner.text)
	assert_eq(seen, ["A", "B", "C"])

func test_queue_survives_state_restored() -> void:
	EventBus.banner_requested.emit("The monsters return")
	EventBus.banner_requested.emit("The monsters look tired tonight.")
	GameState.new_game(3)  # emits state_restored
	for i in int(ceil(Balance.ui.banner_min_s * 60.0)) + 3:
		await get_tree().process_frame
	assert_eq(hud.banner.text, "The monsters look tired tonight.")

func test_arrow_rect_top_clears_the_hud() -> void:
	var need := maxf(hud._top_column.get_global_rect().end.y, hud.gold_label.get_global_rect().end.y) \
		+ Balance.ui.arrow_hud_gap + Hud.ARROW_EXTENT
	assert_gte(hud._arrow_rect().position.y, need)
	GameState.debug_grant_card(&"tank")
	assert_ne(hud.card_strip.text, "")
	need = maxf(need, hud.card_strip.get_global_rect().end.y + Balance.ui.arrow_hud_gap + Hud.ARROW_EXTENT)
	assert_gte(hud._arrow_rect().position.y, need)

func test_empty_card_strip_does_not_push_the_arrow_rect_down() -> void:
	assert_eq(hud.card_strip.text, "")
	hud.card_strip.position.y = 400.0  # test-only: park the strip well below the top column
	var strip_y := hud.card_strip.get_global_rect().position.y
	assert_gt(strip_y, hud._top_column.get_global_rect().end.y, "strip is parked below the column")
	assert_lt(hud._arrow_rect().position.y, strip_y, "an empty strip is ignored")
	GameState.debug_grant_card(&"tank")
	assert_ne(hud.card_strip.text, "")
	assert_gte(hud._arrow_rect().position.y, hud.card_strip.get_global_rect().end.y)

func test_hover_point_is_clamped_below_the_hud() -> void:
	var rect := Rect2(0, 200, 600, 800)
	assert_eq(hud._hover_point(Vector2(100, 210), rect), Vector2(100, 200), "clamped to the rect top")
	assert_eq(hud._hover_point(Vector2(100, 700), rect), Vector2(100, 700 - Balance.ui.arrow_hover_px))

func test_card_strip_lists_owned_cards_in_catalog_order() -> void:
	assert_eq(main.hud.card_strip.text, "")
	GameState.debug_grant_card(&"tank")
	GameState.debug_grant_card(&"hero_damage")
	GameState.debug_grant_card(&"tank")
	assert_eq(main.hud.card_strip.text, "DM1  TK2")
	GameState.new_game(2)
	assert_eq(main.hud.card_strip.text, "")

func test_day_label_shows_new_day_on_offer() -> void:
	EventBus.wave_cleared.emit(2)
	assert_eq(main.hud.day_label.text, "Day 2")

func test_queued_banner_shown_late_plays_min_time() -> void:
	EventBus.banner_requested.emit("X")
	var guard := int(Balance.ui.banner_time * 60) + 10
	while hud._banner_left >= 2.0 / 60.0 and guard > 0:
		await get_tree().process_frame
		guard -= 1
	assert_gt(guard, 0, "X nearly expired")
	EventBus.banner_requested.emit("Y")
	EventBus.banner_requested.emit("Z")
	var n := int(ceil((Balance.ui.banner_min_s + 2.0 / 60.0) * 60.0)) + 3
	var saw_y := false
	while hud.banner.text != "Z" and n > 0:
		await get_tree().process_frame
		if hud.banner.text == "Y":
			saw_y = true
		n -= 1
	assert_true(saw_y, "Y was shown")
	assert_eq(hud.banner.text, "Z")
	assert_almost_eq(hud._banner_left, Balance.ui.banner_time, 3.0 / 60.0)
