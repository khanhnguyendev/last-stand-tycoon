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

# --- E6 Task 12 (spec 5.5, D-287.3): the third arrow, and the brute mark on the lane that carries brutes ---

const LANES4 := ["west", "north", "east", "sw"]
## Brute placements of the sweep: [brute_main, brute_side, brutes come in a later wave on the extra lane].
const BRUTE_VARIANTS := [[0, 0, false], [2, 0, false], [0, 2, false], [0, 0, true]]
## A wave of three active lanes: main, side, and an extra hare group on `e` (brutes on top of the groups).
func _w3(m: String, s: String, e: String, bm := 0, bs := 0, side_count := 3) -> Dictionary:
	var w := _w(m, s, bm, bs)
	w["side_count"] = side_count
	w["extra"] = [{"lane": e, "count": 2, "fast": 2}]
	return w

func _night3(plan: Array) -> void:
	GameState.lane_plan = plan
	EventBus.phase_changed.emit(Phase.NIGHT, 5)

## An arrow's footprint in global px, independent of Hud: the square around its disc (44 px wide, centre 2 px along its own axis), plus its mark.
func _footprint(a: HudArrow) -> Rect2:
	var h: float = Balance.ui.arrow_px * 0.5 * a.scale.x
	var c: Vector2 = a.position + hud.root.global_position + Vector2(0, 2).rotated(a.rotation) * a.scale.x
	var r := Rect2(c - Vector2.ONE * h, Vector2.ONE * h * 2.0)
	if a.heavy:
		var m := hud.icons.heavy_rect(a)
		r = r.merge(Rect2(m.position + hud.root.global_position, m.size))
	return r

func _visible_arrows() -> Array:
	return ["main", "side", "extra"].filter(func(k): return hud.arrows[k].visible)

func test_a_wave_with_a_third_lane_shows_three_arrows_each_pointing_at_its_lane() -> void:
	_sized(SIZES["9:16"])
	_hero_at(MapLayout.HOME)
	await get_tree().process_frame
	_night3([_w3("west", "east", "north")])
	EventBus.wave_incoming.emit(0, &"west", &"east")
	await get_tree().process_frame
	assert_eq(_visible_arrows(), ["main", "side", "extra"], "three arrows")
	await get_tree().create_timer(Balance.ui.arrow_punch_time + 0.3).timeout  # the punch has ended
	assert_eq(hud.arrows.extra.scale, hud._rest_scale("extra"), "the extra arrow rests at the side scale")
	assert_eq(hud.arrows.extra.scale, Vector2.ONE * Balance.ui.arrow_side_scale)
	assert_eq(hud.arrows.side.scale, hud.arrows.extra.scale)
	var c := hud.arrow_rect().get_center()
	var cam := main.camera_rig.camera
	var lanes := {"main": "west", "side": "east", "extra": "north"}
	for k in lanes:
		var a: HudArrow = hud.arrows[k]
		var g: Vector2 = a.position + hud.root.position
		var want: Vector2 = cam.unproject_position(main.world.lanes[lanes[k]].entrance_position()) - c
		var tip := Vector2(-sin(a.rotation), cos(a.rotation))
		if a.rotation != 0.0:
			assert_lt(absf(angle_difference(tip.angle(), want.angle())), 0.7, "%s arrow points toward %s (at %s)" % [k, lanes[k], g])
		else:
			assert_lt(g.distance_to(cam.unproject_position(main.world.lanes[lanes[k]].entrance_position())), Balance.ui.arrow_hover_px + 60.0, "%s arrow hovers by its lane" % k)

func test_three_arrows_never_overlap_the_bar_the_gear_or_each_other_at_every_triple_aspect_and_hero_place() -> void:
	var triples := 0
	var checked := 0
	for name in SIZES:
		var vp: Vector2 = Vector2(SIZES[name])
		_sized(SIZES[name])
		assert_true(hud.reserved_rect.is_valid(), "the gear rect is known")
		var places: Array = [["HOME", MapLayout.HOME]]
		for l in LANES4:
			places.append(["the %s zone" % l, MapLayout.zone_rect(l).get_center()])
		# the map's two far north corners: the lane entrances bunch up on screen there, and the separation rule is needed
		places.append(["the north-west corner", Vector2(-21, -21)])
		places.append(["the north-east corner", Vector2(21, -21)])
		for where in places:
			_hero_at(where[1])
			await get_tree().process_frame
			for m in LANES4:
				for s in LANES4:
					for e in LANES4:
						if m == s or m == e or s == e:
							continue
						for variant in BRUTE_VARIANTS:
							var plan: Array = [_w3(m, s, e, variant[0], variant[1])]
							if variant[2]:  # a later wave tonight puts the brutes on the extra lane
								plan.append(_w(e, m, 2, 0))
							_night3(plan)
							EventBus.wave_incoming.emit(0, StringName(m), StringName(s))
							hud._place_arrows()
							var what := "%s %s main %s side %s extra %s brutes %s" % [name, where[0], m, s, e, variant]
							assert_eq(_visible_arrows().size(), 3, what + ": three arrows")
							var want_heavy := {"main": variant[0] > 0, "side": variant[1] > 0, "extra": variant[2]}
							var gear: Rect2 = hud.reserved_rect.call()
							var rects := {}
							for k in _visible_arrows():
								assert_eq(hud.arrows[k].heavy, want_heavy[k], "%s: %s arrow mark" % [what, k])
								rects[k] = _footprint(hud.arrows[k])  # the arrow and, when heavy, its mark
							for k in rects:
								var r: Rect2 = rects[k]
								assert_true(Rect2(Vector2.ZERO, vp).encloses(r), "%s: %s arrow with its mark on screen %s" % [what, k, r])
								assert_gte(hud.arrows[k].position.y + hud.root.position.y - Hud.arrow_extent(), Balance.ui.hud_top_bar_px, "%s: %s arrow not under the top bar" % [what, k])
								assert_gte(r.position.y, Balance.ui.hud_top_bar_px, "%s: %s arrow with its mark below the top bar (top %s)" % [what, k, r.position.y])
								assert_false(r.intersects(gear), "%s: %s arrow with its mark clear of the gear: fp %s gear %s" % [what, k, r, gear])
							for pair in [["main", "side"], ["main", "extra"], ["side", "extra"]]:
								assert_false((rects[pair[0]] as Rect2).grow(4.0).intersects((rects[pair[1]] as Rect2).grow(4.0)), "%s: %s and %s arrows (marks included) apart" % [what, pair[0], pair[1]])
							checked += 1
		triples += 1
	assert_eq(triples, 3)
	assert_eq(checked, 3 * 7 * 24 * BRUTE_VARIANTS.size())

## Where the HUD's plain edge placement puts the arrow of `lane` (no separation) and how it turns; `heavy` shrinks the rect the way a marked arrow's does.
func _plain(lane: String, heavy := false) -> Dictionary:
	var cam := main.camera_rig.camera
	var rect := hud.arrow_rect()
	if heavy:
		var extra := maxf(Balance.ui.arrow_heavy_px, Balance.ui.arrow_heavy_min_px) + Balance.ui.arrow_heavy_gap_px
		rect = Rect2(rect.position + Vector2(0, extra), rect.size - Vector2(0, extra))
	var p := cam.unproject_position(main.world.lanes[lane].entrance_position())
	if rect.has_point(p):
		return {"position": hud._hover_point(p, rect), "rotation": 0.0}
	var e := EdgeClamp.clamp_to_rect(p, rect)
	return {"position": e.position, "rotation": e.rotation}

func _plain_point(lane: String) -> Vector2:
	return _plain(lane).position

func test_the_separation_rule_keeps_main_in_place_and_slides_the_later_arrow_along_the_edge() -> void:
	# From the north-west corner at 9:16, north (main) and east (side) would land on the same spot of the top edge.
	_sized(SIZES["9:16"])
	_hero_at(Vector2(-21, -21))
	await get_tree().process_frame
	var own := {"north": _plain_point("north"), "east": _plain_point("east"), "west": _plain_point("west")}
	assert_lt(own.north.distance_to(own.east), Balance.ui.arrow_px * Balance.ui.arrow_punch_scale, "setup: the plain places touch %s %s" % [own.north, own.east])
	# two lanes: today's places exactly, touching or not
	_night3([_w("north", "east")])
	EventBus.wave_incoming.emit(0, &"north", &"east")
	hud._place_arrows()
	assert_eq(hud.arrows.main.position + hud.root.position, own.north, "two lanes: main as ever")
	assert_eq(hud.arrows.side.position + hud.root.position, own.east, "two lanes: side as ever")
	assert_almost_eq(hud.arrows.main.rotation, _plain("north").rotation, 1e-5, "two lanes: main turns as ever")
	assert_almost_eq(hud.arrows.side.rotation, _plain("east").rotation, 1e-5, "two lanes: side turns as ever")
	# a two-lane wave with a brute: the marked main arrow sits where the old rule put it (shrunken rect), still unseparated
	_night3([_w("north", "east", 1, 0)])
	EventBus.wave_incoming.emit(0, &"north", &"east")
	hud._place_arrows()
	assert_true(hud.arrows.main.heavy)
	assert_eq(hud.arrows.main.position + hud.root.position, _plain("north", true).position, "two lanes with a mark: main as ever")
	assert_almost_eq(hud.arrows.main.rotation, _plain("north", true).rotation, 1e-5)
	assert_eq(hud.arrows.side.position + hud.root.position, own.east, "two lanes with a mark: side as ever")
	# three lanes: main stays, side slides
	_night3([_w3("north", "east", "sw")])
	EventBus.wave_incoming.emit(0, &"north", &"east")
	hud._place_arrows()
	assert_eq(hud.arrows.main.position + hud.root.position, own.north, "three lanes: main keeps its place")
	var side: Vector2 = hud.arrows.side.position + hud.root.position
	assert_gt(side.distance_to(own.east), 1.0, "the side arrow slid off its plain place")
	assert_lt(side.distance_to(own.east), 160.0, "and only by a short way")
	assert_true(hud.arrow_rect().grow(1.0).has_point(side), "still on the arrow rect")
	assert_false(_footprint(hud.arrows.main).grow(4.0).intersects(_footprint(hud.arrows.side).grow(4.0)), "apart")
	# the third arrow slides for both earlier ones
	_night3([_w3("west", "north", "east")])
	EventBus.wave_incoming.emit(0, &"west", &"north")
	hud._place_arrows()
	assert_eq(hud.arrows.main.position + hud.root.position, own.west)
	assert_false(_footprint(hud.arrows.side).grow(4.0).intersects(_footprint(hud.arrows.extra).grow(4.0)), "side and extra apart")
	assert_gt((hud.arrows.extra.position + hud.root.position).distance_to(own.east), 1.0, "the extra arrow slid")

func test_the_brute_mark_sits_on_the_side_arrow_only_when_only_the_side_lane_has_brutes() -> void:
	_night3([_w3("west", "east", "north", 0, 2)])
	EventBus.wave_incoming.emit(0, &"west", &"east")
	assert_eq(_visible_arrows().size(), 3)
	assert_false(hud.arrows.main.heavy, "main has no brute")
	assert_true(hud.arrows.side.heavy, "east carries the brutes")
	assert_false(hud.arrows.extra.heavy, "the extra lane has none")

func test_a_wave_whose_main_lane_is_the_brute_lane_marks_only_main() -> void:
	_night3([_w3("sw", "east", "north", 3, 0)])
	EventBus.wave_incoming.emit(0, &"sw", &"east")
	assert_true(hud.arrows.main.heavy)
	assert_false(hud.arrows.side.heavy)
	assert_false(hud.arrows.extra.heavy)

func test_a_later_wave_tonight_that_brings_the_brutes_marks_the_extra_arrow_now() -> void:
	_night3([_w3("west", "east", "north"), _w("west", "north", 0, 1), _w("east", "west")])
	EventBus.wave_incoming.emit(0, &"west", &"east")
	assert_false(hud.arrows.main.heavy)
	assert_false(hud.arrows.side.heavy)
	assert_true(hud.arrows.extra.heavy, "north's brutes come in wave 2")
	EventBus.wave_incoming.emit(2, &"east", &"west")
	assert_false(hud.arrows.extra.heavy, "no third lane: hidden and unmarked")
	assert_false(hud.arrows.main.heavy, "east never has one")

func test_a_side_group_with_only_brutes_still_shows_its_arrow_with_the_mark() -> void:
	var w := _w3("west", "east", "north", 0, 2, 0)
	assert_eq(w.side_count, 0)
	_night3([w])
	EventBus.wave_incoming.emit(0, &"west", &"east")
	assert_true(hud.arrows.side.visible)
	assert_true(hud.arrows.side.heavy)
	assert_false(hud.arrows.main.heavy)
	assert_false(hud.arrows.extra.heavy)

func test_the_third_arrow_hides_on_spawned_out_and_when_the_next_wave_has_no_third_lane() -> void:
	_night3([_w3("west", "east", "north"), _w("west", "east"), _w3("east", "west", "sw")])
	EventBus.wave_incoming.emit(0, &"west", &"east")
	assert_true(hud.arrows.extra.visible)
	EventBus.wave_spawned_out.emit(0)
	assert_false(hud.arrows.extra.visible, "spawned out")
	EventBus.wave_incoming.emit(0, &"west", &"east")
	EventBus.wave_incoming.emit(1, &"west", &"east")
	assert_false(hud.arrows.extra.visible, "wave 1 has two lanes")
	EventBus.wave_incoming.emit(2, &"east", &"west")
	assert_true(hud.arrows.extra.visible)
	EventBus.phase_changed.emit(Phase.DAWN, 5)
	assert_false(hud.arrows.extra.visible, "by day")

func test_a_wave_without_extra_never_shows_the_third_arrow() -> void:
	_night3([_w("west", "east"), _w("north", "west", 1, 0), _w("east", "")])
	for w in 3:
		EventBus.wave_incoming.emit(w, StringName(GameState.lane_plan[w].main), StringName(GameState.lane_plan[w].side))
		assert_false(hud.arrows.extra.visible, "wave %d" % w)
	EventBus.wave_incoming.emit(1, &"west", &"east")  # and a lane that no wave names
	assert_false(hud.arrows.extra.visible)
	EventBus.wave_incoming.emit(9, &"west", &"east")  # out of the plan
	assert_false(hud.arrows.extra.visible)
	EventBus.wave_incoming.emit(-1, &"west", &"east")  # before the plan
	assert_false(hud.arrows.extra.visible)
	assert_true(hud.arrows.side.visible, "and a two-lane wave still shows its side arrow")

# --- the real chain: LaneCharacter.apply, then the WaveDirector's own announcement ---

## `plan` through the lane character, played by the real director: the HUD sees only what the director emits.
func _announce_through_the_director(plan: Array, character: Dictionary) -> Array:
	var applied := LaneCharacter.apply(plan, character, Balance.data.tiers)
	GameState.lane_plan = applied
	EventBus.phase_changed.emit(Phase.NIGHT, 5)
	main.world.wave_director.start_night(applied)
	return applied

func test_a_side_group_with_count_0_and_only_brutes_shows_its_arrow_with_the_mark_through_the_real_chain() -> void:
	# main west with 2 brutes, no side; the siege lane is sw: the brutes move to a new side group (count 0) on sw
	var wave := _w("west", "", 2, 0)
	var applied := _announce_through_the_director([wave], {"siege": "sw", "hare": "north"})
	assert_eq(applied[0].side, "sw")
	assert_eq(int(applied[0].side_count), 0, "setup: an empty side group that carries only brutes")
	assert_eq(int(applied[0].brute_side), 2)
	assert_true(hud.arrows.main.visible)
	assert_true(hud.arrows.side.visible, "the side arrow shows: its lane has the brutes")
	assert_true(hud.arrows.side.heavy)
	assert_false(hud.arrows.main.heavy)
	assert_false(hud.arrows.extra.visible)
	main.world.wave_director.stop()

func test_a_side_group_emptied_by_the_hare_move_shows_no_arrow_through_the_real_chain() -> void:
	# main west 3 (3 hares), side east 2 (2 hares): the hare lane is north (neither), so 4 hares leave for an extra group
	# on north, the side group gives all of its enemies, and east has nobody left
	var wave := _w("west", "east")
	wave["main_count"] = 3
	wave["side_count"] = 2
	wave["fast_main"] = 3
	wave["fast_side"] = 2
	var applied := _announce_through_the_director([wave], {"siege": "sw", "hare": "north"})
	assert_eq(int(applied[0].side_count), 0, "setup: the side group is empty")
	assert_eq(int(applied[0].get("brute_side", 0)), 0, "setup: and has no brutes")
	assert_eq(String(applied[0].side), "east", "setup: a side lane is still named")
	assert_false(LaneCharacter.active_lanes(applied[0]).has("east"))
	assert_true(hud.arrows.main.visible)
	assert_false(hud.arrows.side.visible, "no arrow for a lane nobody walks")
	assert_true(hud.arrows.extra.visible, "the hare group's lane gets its arrow")
	assert_eq(hud._arrow_lane.extra, "north")
	main.world.wave_director.stop()

func test_the_side_show_rule_switches_only_for_a_wave_with_extra_or_an_emptied_side_group() -> void:
	# today's rule (a named side lane shows) holds while side_count > 0 or brute_side > 0 and there is no `extra`; the active-lane
	# rule applies when the wave has `extra` or side_count == 0 with no brute_side. Pinned both ways.
	var w := _w("west", "east")
	_night3([w])
	EventBus.wave_incoming.emit(0, &"west", &"east")
	assert_true(hud.arrows.side.visible, "side_count 3: the old rule")
	var w0 := _w("west", "east")
	w0["side_count"] = 0
	_night3([w0])
	EventBus.wave_incoming.emit(0, &"west", &"east")
	assert_false(hud.arrows.side.visible, "side_count 0 and no brutes: nobody walks east")
	_night3([_w("west", "east", 0, 0)])
	EventBus.wave_incoming.emit(5, &"west", &"east")  # out of the plan: today's rule
	assert_true(hud.arrows.side.visible)

func after_each() -> void:
	Balance.reset()
	GameState.new_game(1)
