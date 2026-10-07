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
	assert_false(hud.moons_shown())
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
	var grown := hud.arrow_rect()
	var far := ""
	for k in main.world.lanes:
		var pos: Vector3 = main.world.lanes[k].entrance_position()
		if cam.is_position_behind(pos) or not grown.has_point(cam.unproject_position(pos)):
			far = String(k)
	assert_ne(far, "", "a lane entrance is off-screen")
	EventBus.wave_incoming.emit(1, &"west", StringName(far))
	await get_tree().process_frame
	var arrow = hud.arrows.side
	var g: Vector2 = arrow.position + hud.root.position
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
	assert_false(hud.diner_bar.has_theme_stylebox_override("fill"), "the style comes from the theme (S4 Task 14)")
	assert_eq((hud.diner_bar.get_theme_stylebox("background") as StyleBoxFlat).bg_color, Palette.color(&"ink"))
	var fill := hud.diner_bar.get_theme_stylebox("fill") as StyleBoxFlat
	assert_eq(fill.bg_color, Palette.color(&"guard_green"))
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
	var arrow_top: float = hud.arrows.main.position.y + hud.root.position.y - Hud.arrow_extent()
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
		+ Balance.ui.arrow_hud_gap + Hud.arrow_extent()
	assert_gte(hud.arrow_rect().position.y, need)
	GameState.debug_grant_card(&"tank")
	assert_ne(hud.card_strip.text, "")
	need = maxf(need, hud.card_strip.get_global_rect().end.y + Balance.ui.arrow_hud_gap + Hud.arrow_extent())
	assert_gte(hud.arrow_rect().position.y, need)

func test_empty_card_strip_does_not_push_the_arrow_rect_down() -> void:
	assert_eq(hud.card_strip.text, "")
	hud.card_strip.position.y = 400.0  # test-only: park the strip well below the top column
	var strip_y := hud.card_strip.get_global_rect().position.y
	assert_gt(strip_y, hud._top_column.get_global_rect().end.y, "strip is parked below the column")
	assert_lt(hud.arrow_rect().position.y, strip_y, "an empty strip is ignored")
	GameState.debug_grant_card(&"tank")
	assert_ne(hud.card_strip.text, "")
	assert_gte(hud.arrow_rect().position.y, hud.card_strip.get_global_rect().end.y)

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

func test_moon_tint_lit_and_unlit_after_a_wave_clears() -> void:
	EventBus.phase_changed.emit(Phase.NIGHT, 1)
	EventBus.wave_cleared.emit(0)
	assert_gte(hud.moons.size(), 2)
	assert_true(hud.moon_lit(0))
	assert_false(hud.moon_lit(1))
	assert_eq(hud.moon_color(0), Hud.MOON_LIT)
	assert_eq(hud.moon_color(1), Palette.color(&"ink_soft"))
	assert_ne(hud.moon_color(0), hud.moon_color(1))
	assert_true(hud.moons_shown(), "the ink discs and moons are drawn at night")

func _frames(seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		await get_tree().process_frame

func test_banner_slides_down_and_label_fades_in() -> void:
	var ui := Balance.ui
	EventBus.banner_requested.emit("Dawn")
	var top0 := hud.banner_panel.offset_top
	var bottom0 := hud.banner_panel.offset_bottom
	assert_eq(hud.banner.modulate.a, 0.0)
	await _frames(ui.banner_in_s * 0.5)
	assert_between(hud.banner.modulate.a, 0.05, 0.95)
	assert_gt(hud.banner_panel.offset_top, top0)
	await _frames(ui.banner_in_s * 0.5 + 0.05)
	assert_eq(hud.banner.modulate.a, 1.0)
	assert_almost_eq(hud.banner_panel.offset_top - top0, ui.banner_slide_px, 0.01, "slid down to rest")
	assert_almost_eq(hud.banner_panel.offset_bottom - bottom0, ui.banner_slide_px, 0.01)
	assert_almost_eq(hud.banner_panel.offset_bottom - hud.banner_panel.offset_top, bottom0 - top0, 0.01, "height unchanged")

func test_banner_rest_offsets_are_stable_across_banners() -> void:
	EventBus.banner_requested.emit("One")
	await _frames(Balance.ui.banner_in_s + 0.05)
	var rest_top := hud.banner_panel.offset_top
	EventBus.banner_requested.emit("Two")  # shortens "One" to banner_min_s, then plays "Two"
	await _frames(Balance.ui.banner_min_s + Balance.ui.banner_in_s + 0.1)
	assert_eq(hud.banner.text, "Two")
	assert_almost_eq(hud.banner_panel.offset_top, rest_top, 0.01)

func test_boss_moon_on_a_boss_night() -> void:
	assert_eq(hud.boss_moon_index(), -1)
	main.phase_controller.debug_skip_to_day()
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	main.phase_controller.debug_skip_to_night()
	await get_tree().physics_frame
	assert_eq(hud.boss_moon_index(), 2)
	assert_eq(hud.icons.boss_moon, 2)
	assert_eq(hud.moon_color(2), Palette.color(&"enemy_red"), "unlit boss moon is red, not ink_soft")
	assert_almost_eq(hud.icons.moon_scale(2), Balance.ui.boss_moon_scale, 1e-6)
	assert_almost_eq(hud.icons.moon_scale(0), 1.0, 1e-6)

func _boss_night() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	main.phase_controller.debug_skip_to_night()
	await get_tree().physics_frame

func test_boss_moon_breathes_from_its_wave_until_the_boss_dies() -> void:
	await _boss_night()
	EventBus.wave_started.emit(2, &"north", &"")
	assert_true(hud.icons.boss_alive)
	EventBus.enemy_killed.emit(1, &"north", Vector3.ZERO, &"boar")
	assert_true(hud.icons.boss_alive, "a killed boar does not clear it")
	EventBus.enemy_killed.emit(0, &"north", Vector3.ZERO, &"boss")
	assert_false(hud.icons.boss_alive)

## Mutation: `kind == &"boss"` leaves the moon lit after Baron von Hop dies; clearing on any kill clears it for the hare.
func test_the_moon_clears_for_the_baron_and_not_for_a_hare() -> void:
	await _boss_night()
	EventBus.wave_started.emit(2, &"north", &"")
	EventBus.enemy_killed.emit(3, &"north", Vector3.ZERO, &"hare")
	assert_true(hud.icons.boss_alive, "a killed hare leaves it lit")
	EventBus.enemy_killed.emit(4, &"north", Vector3.ZERO, &"baron")
	assert_false(hud.icons.boss_alive, "the Baron clears it")
	EventBus.wave_started.emit(2, &"north", &"")
	assert_true(hud.icons.boss_alive)
	EventBus.enemy_killed.emit(0, &"north", Vector3.ZERO, &"boss")
	assert_false(hud.icons.boss_alive, "the King clears it")

func test_a_restore_clears_the_breathing_moon() -> void:
	await _boss_night()
	EventBus.wave_started.emit(2, &"north", &"")
	assert_true(hud.icons.boss_alive)
	hud.icons.boss_moon = -1  # test-only setup
	EventBus.state_restored.emit()
	assert_false(hud.icons.boss_alive)
	assert_eq(hud.icons.boss_moon, GameState.lane_plan.size() - 1)
	assert_gte(hud.icons.boss_moon, 0)

func _icons_with_cells(n: int) -> HudIcons:
	var ic := HudIcons.new()
	add_child_autofree(ic)
	for i in n:
		var c := Control.new()
		c.size = Vector2(HudIcons.MOON_CELL_PX, HudIcons.MOON_CELL_PX)
		add_child_autofree(c)
		c.position = Vector2(100, 100 + float(i) * (HudIcons.MOON_CELL_PX + 12.0))
		ic.moon_cells.append(c)
	return ic

func test_disc_rect_is_the_cell_for_a_normal_moon() -> void:
	var ic := _icons_with_cells(3)
	ic.boss_moon = 2
	assert_eq(ic.disc_rect(0), ic.moon_cells[0].get_global_rect())

func test_boss_disc_is_centred_larger_and_holds_the_moon() -> void:
	var ic := _icons_with_cells(3)
	ic.boss_moon = 2
	ic.boss_alive = true
	var cell: Rect2 = ic.moon_cells[2].get_global_rect()
	var d := ic.disc_rect(2)
	var grow: float = HudIcons.MOON_CELL_PX * (Balance.ui.boss_moon_scale - 1.0) * 0.5
	assert_almost_eq(d.get_center().x, cell.get_center().x, 1e-4)
	assert_almost_eq(d.get_center().y, cell.get_center().y, 1e-4)
	assert_almost_eq(d.size.x, cell.size.x + grow * 2.0, 1e-4)
	assert_almost_eq(d.size.y, cell.size.y + grow * 2.0, 1e-4)
	assert_true(d.encloses(ic.moon_rect(2)), "at rest")
	ic._t = 0.25 / Balance.ui.pulse_hz
	assert_true(d.encloses(ic.moon_rect(2)), "at the breath's peak")
	assert_false(d.intersects(ic.disc_rect(1)))

func test_day_label_shows_the_new_day_at_the_tier_up_dawn_before_the_reveal() -> void:
	main.phase_controller.debug_skip_to_day()
	var cost := GameState.tier_next_cost()
	GameState.add_gold(cost)
	GameState.pay_into_tier(cost)
	main.phase_controller.debug_skip_to_night()
	main.phase_controller.debug_skip_to_day()
	assert_true(main.phase_controller.reveal_pending, "the reveal has not fired")
	assert_eq(hud.day_label.text, tr("Day %d") % GameState.day)

# --- E5 tier 3 Task 14 (spec 6.5, D-264): the heavy mark beside the arrow of a lane that brings a brute ---

func _w(m: String, s: String, bm := 0, bs := 0) -> Dictionary:
	return {"main": m, "side": s, "main_count": 5, "side_count": 3 if s != "" else 0, "hp_mult": 1.0, "fast_main": 0, "fast_side": 0, "boss": false, "brute_main": bm, "brute_side": bs}

## West brings a brute in wave 1 only (its main slot); east in wave 2 (its side slot); north none.
func _brute_plan() -> Array:
	return [_w("west", "east"), _w("west", "north", 1, 0), _w("north", "east", 0, 1), _w("west", "north")]

func _night_with(plan: Array) -> void:
	GameState.lane_plan = plan
	EventBus.phase_changed.emit(Phase.NIGHT, 5)

func test_the_mark_shows_while_this_or_a_later_wave_brings_a_brute_there() -> void:
	_night_with(_brute_plan())
	EventBus.wave_incoming.emit(0, &"west", &"east")
	assert_true(hud.arrows.main.heavy, "west: its brute is in wave 1, still to come")
	assert_true(hud.arrows.side.heavy, "east: its brute is in wave 2, still to come")
	EventBus.wave_incoming.emit(1, &"west", &"north")
	assert_true(hud.arrows.main.heavy, "west: the brute is in this wave")
	assert_false(hud.arrows.side.heavy, "north never has one")
	EventBus.wave_incoming.emit(3, &"west", &"north")
	assert_false(hud.arrows.main.heavy, "the wave-3 arrow of west: its only brute has come")
	assert_false(hud.arrows.side.heavy)
	EventBus.wave_incoming.emit(2, &"north", &"east")
	assert_false(hud.arrows.main.heavy)
	assert_true(hud.arrows.side.heavy, "east: the brute is in this wave")

func test_no_arrow_carries_the_mark_when_the_plan_has_no_brute() -> void:
	_night_with([_w("west", "east"), _w("north", "west")])
	for pair in [[&"west", &"east"], [&"east", &"west"], [&"north", &"west"]]:
		EventBus.wave_incoming.emit(0, pair[0], pair[1])
		assert_false(hud.arrows.main.heavy)
		assert_false(hud.arrows.side.heavy)
		await get_tree().process_frame
		assert_eq(hud.icons.heavy_drawn.size(), 0, "nothing drawn")

func test_the_heavy_rect_is_big_enough_beside_the_arrow_and_leaves_the_tip_free() -> void:
	_night_with(_brute_plan())
	EventBus.wave_incoming.emit(0, &"west", &"east")
	await get_tree().process_frame
	var min_px: float = Balance.ui.arrow_heavy_min_px
	assert_eq(min_px, 22.0)
	for key in ["main", "side"]:
		var a: HudArrow = hud.arrows[key]
		for rot in [0.0, PI * 0.5, -PI * 0.5, PI]:  # rotated as at the screen edges
			a.rotation = rot
			var r := hud.icons.heavy_rect(a)
			assert_gte(minf(r.size.x, r.size.y), min_px, "%s arrow, rotation %.2f" % [key, rot])
			var px: float = Balance.ui.arrow_px
			var tip := a.position + Vector2(0.0, (px * 0.5 + HudIcons.ARROW_CENTER.y) * a.scale.y).rotated(rot)
			assert_false(r.has_point(tip), "%s arrow: the mark does not cover the tip" % key)
			# and does not sit on the arrow body either
			var body := Rect2(a.position - Vector2.ONE * px * a.scale.x * 0.5, Vector2.ONE * px * a.scale.x)
			var rotated_body := Transform2D(rot, a.position) * Transform2D(0.0, -a.position) * body
			assert_false(r.intersects(rotated_body.grow(-1.0)), "%s arrow, rotation %.2f: beside the arrow, not on it" % [key, rot])

func test_the_heavy_mark_reaches_the_canvas_only_for_heavy_arrows() -> void:
	_night_with(_brute_plan())
	EventBus.wave_incoming.emit(1, &"west", &"north")  # west heavy, north plain
	for i in 3:
		await get_tree().process_frame
	assert_true(hud.icons.visible)
	assert_eq(hud.icons.heavy_drawn.size(), 1, "one mark drawn: west's")
	assert_lt(hud.icons.heavy_drawn[0].get_center().distance_to(hud.icons.heavy_rect(hud.arrows.main).get_center()), 3.0, "beside the main arrow (the arrow may still be punching)")
	EventBus.wave_incoming.emit(3, &"west", &"north")  # nobody heavy any more
	for i in 3:
		await get_tree().process_frame
	assert_eq(hud.icons.heavy_drawn.size(), 0)

func test_the_brute_mark_texture_is_on_palette_and_within_the_texture_rule() -> void:
	var tex := IconAtlas.brute_mark()
	assert_not_null(tex)
	var img := tex.get_image()
	assert_lte(maxi(img.get_width(), img.get_height()), 256, "icons are at most 256 px")
	var c := img.get_pixel(32, 26)  # the heavy brow: palette ink
	assert_gt(c.a, 0.9)
	assert_true(c.is_equal_approx(Palette.color(&"ink")), "the baked brow is palette ink, got %s" % c)
	var m := img.get_pixel(32, 36)  # the face: apron_white, tinted enemy_maroon at draw time (R4: no enemy colour in an icon file)
	assert_true(m.is_equal_approx(Palette.color(&"apron_white")), "the baked face is the tint base, got %s" % m)

# --- E5 tier 3 Task 20: the edge arrows serve the south-west lane ---

const SIZES := {"9:21": Vector2i(720, 1680), "9:16": Vector2i(720, 1280), "16:9": Vector2i(1280, 720)}

func _sized(size: Vector2i) -> SubViewport:
	var old := main.get_parent()
	old.remove_child(main)
	main.free()
	if old != self:
		old.queue_free()
	var vp := SubViewport.new()
	vp.size = size
	add_child_autofree(vp)
	main = Main.create()
	vp.add_child(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(81)
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)  # the tier-3 switch is Task 21: the test turns it on
	GameState.debug_set_tier(3, 5)
	hud = main.hud
	return vp

func _hero_at(p: Vector2) -> void:
	main.hero.teleport(p)
	main.camera_rig.snap()

## Where the thumb rests on a floating stick (there is no fixed pad): the lower middle of the screen, radius joystick_radius_px
## around 80% of the height. Nothing in the HUD may sit there.
func _thumb_zone(vp: Vector2) -> Rect2:
	var r: float = Balance.ui.joystick_radius_px
	return Rect2(Vector2(vp.x * 0.5 - r, vp.y * 0.8 - r), Vector2(r, r) * 2.0)

func _check_sw_arrow(arrow: HudArrow, size: Vector2i, what: String) -> void:
	var vp := Vector2(size)
	var g: Vector2 = arrow.position + hud.root.position
	assert_true(arrow.visible, what + ": shown")
	assert_true(Rect2(Vector2.ZERO, vp).has_point(g), what + ": on screen, at %s" % g)
	assert_true(hud.arrow_rect().grow(1.0).has_point(g), what + ": inside the arrow rect")
	assert_almost_eq(g.x, hud.arrow_rect().position.x, 1.0, what + ": on the left edge, the one nearest the lane's approach")
	assert_gt(g.y, vp.y * 0.5, what + ": below the middle: the lane comes in from the south-west")
	assert_almost_eq(arrow.rotation, PI * 0.5, 0.5, what + ": points left (tip down at 0, so +90 degrees)")
	assert_gte(g.y - Hud.arrow_extent(), Balance.ui.hud_top_bar_px, what + ": not under the HUD's top bar")
	assert_false(_thumb_zone(vp).grow(Hud.arrow_extent()).has_point(g), what + ": clear of the joystick's rest area")

func test_the_sw_arrow_sits_on_the_left_edge_for_a_main_and_a_side_slot_at_every_aspect_and_hero_place() -> void:
	var checked := 0
	for name in SIZES:
		_sized(SIZES[name])
		for where in [["HOME", MapLayout.HOME], ["the SW zone", MapLayout.zone_rect("sw").get_center()]]:
			_hero_at(where[1])
			await get_tree().process_frame
			EventBus.wave_incoming.emit(0, &"sw", &"west")
			await get_tree().process_frame
			await get_tree().process_frame
			_check_sw_arrow(hud.arrows.main, SIZES[name], "%s %s sw as main" % [name, where[0]])
			EventBus.wave_incoming.emit(0, &"west", &"sw")
			await get_tree().process_frame
			await get_tree().process_frame
			_check_sw_arrow(hud.arrows.side, SIZES[name], "%s %s sw as side" % [name, where[0]])
			checked += 2
	assert_eq(checked, 12)

func test_the_sw_arrow_carries_the_brute_mark_when_due_and_the_mark_is_clear_of_the_bar() -> void:
	for name in SIZES:
		_sized(SIZES[name])
		_hero_at(MapLayout.HOME)
		GameState.lane_plan = [_w("sw", "west", 1, 0), _w("north", "west")]
		EventBus.phase_changed.emit(Phase.NIGHT, 5)
		EventBus.wave_incoming.emit(0, &"sw", &"west")
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(hud.arrows.main.heavy, name + ": sw brings a brute in wave 1")
		assert_false(hud.arrows.side.heavy, name + ": west does not")
		assert_eq(hud.icons.heavy_drawn.size(), 1, name + ": one mark reached the canvas")
		var r: Rect2 = hud.icons.heavy_drawn[0]
		var g := r.position + hud.root.position
		assert_gte(g.y, Balance.ui.hud_top_bar_px, name + ": the mark is below the bar")
		assert_true(Rect2(Vector2.ZERO, Vector2(SIZES[name])).encloses(Rect2(g, r.size)), name + ": the mark is on screen")
		EventBus.wave_incoming.emit(1, &"north", &"west")
		await get_tree().process_frame
		assert_false(hud.arrows.main.heavy, name + ": wave 2's sw has no brute (north)")

func test_the_sw_arrow_does_not_appear_below_tier_3() -> void:
	# a tier-2 world has no sw lane: an arrow naming it stays where it was and is not placed (no crash)
	main.phase_controller.debug_skip_to_day()
	assert_false(main.world.lanes.has("sw"))
	var before: Vector2 = hud.arrows.main.position
	EventBus.wave_incoming.emit(0, &"sw", &"west")
	await get_tree().process_frame
	assert_eq(hud.arrows.main.position, before, "not placed: no lane to point at")
