extends GutTest
## S5 Task 9: HUD safe-area pass, card-strip gap, world-label dimming (spec 7, D-216, Review Focus 5).

const NOTCH_PORTRAIT := {"top": 88.0, "bottom": 68.0, "left": 0.0, "right": 0.0}
const NOTCH_LANDSCAPE := {"top": 0.0, "bottom": 42.0, "left": 88.0, "right": 88.0}
const NONE := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}

var main: Main
var hud: Hud
var vp: SubViewport

func before_each() -> void:
	Balance.reset()

func after_each() -> void:
	SafeArea.override_for_tests = {}
	GameState.new_game(0)

func _boot(size: Vector2i, insets: Dictionary) -> void:
	SafeArea.override_for_tests = insets
	vp = SubViewport.new()
	vp.size = size
	add_child_autofree(vp)
	main = Main.create()
	vp.add_child(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(91)
	hud = main.hud
	await get_tree().process_frame
	vp.size_changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

func _safe(size: Vector2i, ins: Dictionary) -> Rect2:
	return Rect2(ins.left, ins.top, size.x - ins.left - ins.right, size.y - ins.top - ins.bottom)

func _inside(safe: Rect2, r: Rect2, what: String) -> void:
	assert_true(safe.grow(0.5).encloses(r), "%s %s inside %s" % [what, r, safe])

func _blocks() -> Dictionary:
	return {
		"coin": hud.icons.coin_rect(), "gold": hud.gold_label.get_global_rect(),
		"top_column": hud._top_column.get_global_rect(), "strip": hud.card_strip.get_global_rect(),
		"gear": main.settings_layer.gear_rect(),
	}

func _check_blocks(size: Vector2i, ins: Dictionary) -> void:
	GameState.debug_grant_card(&"hero_damage")
	hud.card_strip.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var safe := _safe(size, ins)
	var b := _blocks()
	for k in b:
		_inside(safe, b[k], k)

func test_blocks_inside_safe_rect_no_insets() -> void:
	await _boot(Vector2i(720, 1280), NONE)
	await _check_blocks(Vector2i(720, 1280), NONE)

func test_blocks_inside_safe_rect_notch_portrait() -> void:
	await _boot(Vector2i(720, 1280), NOTCH_PORTRAIT)
	await _check_blocks(Vector2i(720, 1280), NOTCH_PORTRAIT)

func test_blocks_inside_safe_rect_notch_landscape() -> void:
	await _boot(Vector2i(1280, 720), NOTCH_LANDSCAPE)
	await _check_blocks(Vector2i(1280, 720), NOTCH_LANDSCAPE)

func test_settings_buttons_inside_safe_rect_landscape() -> void:
	await _boot(Vector2i(1280, 720), NOTCH_LANDSCAPE)
	main.settings_layer.open()
	await get_tree().process_frame
	var safe := _safe(Vector2i(1280, 720), NOTCH_LANDSCAPE)
	var rects: Dictionary = main.settings_layer.button_rects()
	assert_eq(rects.size(), 3)
	for k in rects:
		_inside(safe, rects[k], "button %s" % k)
	main.settings_layer.close()

func test_resize_portrait_to_landscape_relayouts_inside_the_safe_rect() -> void:
	await _boot(Vector2i(720, 1280), NOTCH_PORTRAIT)
	GameState.debug_grant_card(&"hero_damage")
	hud.card_strip.refresh()
	EventBus.wave_incoming.emit(0, &"north", &"west")
	main.settings_layer.open()
	await get_tree().process_frame
	SafeArea.override_for_tests = NOTCH_LANDSCAPE  # first: size_changed re-reads the insets as it fires
	vp.size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var safe := _safe(Vector2i(1280, 720), NOTCH_LANDSCAPE)
	var b := _blocks()
	for k in b:
		_inside(safe, b[k], k)
	var rects: Dictionary = main.settings_layer.button_rects()
	assert_eq(rects.size(), 3)
	for k in rects:
		_inside(safe, rects[k], "button %s" % k)
	_inside(safe, main.settings_layer.gear_rect(), "gear")
	_inside(safe, hud.arrow_rect(), "arrow_rect")
	main.settings_layer.close()

func test_card_strip_gap_below_coin_row_and_diner_bar() -> void:
	await _boot(Vector2i(720, 1280), NONE)
	GameState.debug_grant_card(&"hero_damage")
	hud.card_strip.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var coin_row := maxf(hud.gold_label.get_global_rect().end.y, hud.icons.coin_rect().end.y)
	var bar := hud.diner_bar.get_global_rect().end.y
	assert_almost_eq(hud.card_strip.get_global_rect().position.y, maxf(coin_row, bar) + Balance.ui.strip_gap_px, 0.6)

func _label_at(screen: Vector2) -> WorldLabel:
	var l := WorldLabel.make("x")
	main.world.add_child(l)
	l.global_position = main.camera_rig.camera.project_position(screen, 18.0)
	return l

func test_label_under_top_column_dims_and_recovers() -> void:
	await _boot(Vector2i(720, 1280), NONE)
	var l := _label_at(hud._top_column.get_global_rect().get_center())
	assert_true(l.is_in_group(&"world_labels"))
	await wait_seconds(0.3)
	assert_almost_eq(l.modulate.a, Balance.ui.label_dim_alpha, 0.001)
	assert_almost_eq(l.outline_modulate.a, Balance.ui.label_dim_alpha, 0.001, "the outline dims too")
	assert_eq(l.modulate.r, Palette.color(&"apron_white").r, "rgb is kept")
	l.global_position = main.camera_rig.camera.project_position(Vector2(360, 700), 18.0)
	await wait_seconds(0.3)
	assert_eq(l.modulate.a, 1.0)
	assert_eq(l.outline_modulate.a, 1.0)

func test_label_owned_by_occluder_fade_is_never_dimmed() -> void:
	await _boot(Vector2i(720, 1280), NONE)
	var fade := main.world.occluder_fade
	var board := WorldLabel.make("board")
	fade.get_parent().add_child(board)
	board.global_position = main.camera_rig.camera.project_position(hud._top_column.get_global_rect().get_center(), 18.0)
	assert_true(fade.owns_label(board))
	var other := _label_at(Vector2(360, 700))
	assert_false(fade.owns_label(other))
	await wait_seconds(0.4)
	assert_eq(board.modulate.a, 1.0)

func test_safe_area_override_returns_a_copy() -> void:
	SafeArea.override_for_tests = NOTCH_PORTRAIT
	var a := SafeArea.insets(Vector2(720, 1280))
	assert_eq(a.top, 88.0)
	a.top = 1.0
	assert_eq(SafeArea.insets(Vector2(720, 1280)).top, 88.0, "mutating the result leaves the override alone")

func test_lane_arrows_are_not_polygons_and_are_drawn_by_hud_icons() -> void:
	await _boot(Vector2i(720, 1280), NONE)
	for n in hud.root.find_children("*", "Polygon2D", true, false):
		fail_test("Polygon2D left in the HUD: %s" % n.name)
	EventBus.wave_incoming.emit(0, &"north", &"west")
	await get_tree().process_frame
	assert_true(hud.arrows.main.visible)
	assert_eq(hud.icons.arrow_nodes.size(), 2, "HudIcons draws the two holders")
	assert_true(hud.icons.arrow_nodes.has(hud.arrows.main))
	assert_true(hud.icons.arrow_nodes.has(hud.arrows.side))
	var draws := [0]
	hud.icons.draw.connect(func(): draws[0] += 1)
	EventBus.wave_spawned_out.emit(0)
	assert_false(hud.arrows.main.visible or hud.arrows.side.visible)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gte(draws[0], 1, "hiding both arrows redraws once more")
	var after: int = draws[0]
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(draws[0], after, "and then stops redrawing")
