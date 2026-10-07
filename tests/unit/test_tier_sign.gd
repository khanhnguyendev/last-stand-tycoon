extends GutTest
## E5 spec 7.2: the tier sign's states, payment and night hiding.

var main: Main
var sign: TierSign

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	main.phase_controller.start_new_game(20260930)
	sign = main.world.tier_sign
	main.phase_controller.debug_skip_to_day()
	await get_tree().physics_frame

func test_sells_the_yards_by_day_and_hides_at_night() -> void:
	var cost := GameState.tier_next_cost()
	assert_gt(cost, 0)
	assert_eq(sign.state(), &"selling")
	assert_true(sign.label.visible)
	assert_true(sign.marker.visible, "the marker shows while selling by day")
	assert_eq(sign.label.text, tr("Open the yards") + "\n" + str(cost))
	assert_true(sign.position.is_equal_approx(MapLayout.to3(MapLayout.TIER_SIGN)))
	main.phase_controller.debug_skip_to_night()
	await get_tree().physics_frame
	assert_false(sign.label.visible)
	assert_false(sign.marker.visible, "no marker at night")
	assert_false(sign.zone.ring.visible)

func test_standing_still_pays_and_completes() -> void:
	var cost := GameState.tier_next_cost()
	GameState.add_gold(cost + 100)
	var held := GameState.gold
	await TestHelpers.walk_in(main.hero, MapLayout.TIER_SIGN)
	var ticks := 0
	while not GameState.boss_pending and ticks < 60 * 20:
		await get_tree().physics_frame
		ticks += 1
	assert_true(GameState.boss_pending, "paid in full within 20 s")
	assert_eq(GameState.gold, held - cost)
	assert_eq(sign.state(), &"boss")
	assert_eq(sign.label.text, tr("Boss tonight"), "Review Focus 2: the label flips on the completing tick")
	assert_false(sign.zone.ring.visible)
	assert_false(sign.marker.visible, "no marker in the boss state")
	var g := GameState.gold
	for i in 30:
		await get_tree().physics_frame
	assert_eq(GameState.gold, g, "Review Focus 2: no more gold is taken")
	assert_eq(sign.label.text, tr("Boss tonight"))

func test_partial_payment_shows_on_the_ring_and_survives_a_restore() -> void:
	var cost := GameState.tier_next_cost()
	var offer := cost / 4
	GameState.add_gold(offer)
	await TestHelpers.walk_in(main.hero, MapLayout.TIER_SIGN)
	var ticks := 0
	while GameState.gold > 0 and ticks < 60 * 20:
		await get_tree().physics_frame
		ticks += 1
	assert_eq(GameState.gold, 0, "the offer was taken within 20 s")
	assert_eq(GameState.tier_paid, offer)
	assert_true(sign.zone.ring.visible)
	assert_almost_eq(sign.zone.ring.progress, float(offer) / float(cost), 1e-6)
	var d := GameState.to_dict()
	GameState.new_game(3)
	await get_tree().physics_frame
	assert_eq(sign.label.text, tr("Open the yards") + "\n" + str(cost), "a fresh game starts unpaid")
	assert_false(sign.zone.ring.visible)
	GameState.from_dict(d)
	await get_tree().physics_frame
	assert_eq(sign.label.text, tr("Open the yards") + "\n" + str(cost - offer))
	assert_true(sign.zone.ring.visible, "the restore redraws the ring")
	assert_almost_eq(sign.zone.ring.progress, float(offer) / float(cost), 1e-6)

func test_walking_through_pays_nothing() -> void:
	GameState.add_gold(100)
	main.hero.teleport(MapLayout.TIER_SIGN + Vector2(0, 3.0))
	for i in 90:
		main.hero.input.set_move(Vector2(0, -1))
		await get_tree().physics_frame
	main.hero.input.set_move(Vector2.ZERO)
	assert_lt(main.hero.xz().y, MapLayout.TIER_SIGN.y - MapLayout.STATION_RADIUS, "the hero crossed the whole zone")
	assert_eq(GameState.gold, 100)

func test_standing_on_the_sign_at_night_pays_nothing() -> void:
	GameState.add_gold(GameState.tier_next_cost())
	var held := GameState.gold
	main.phase_controller.debug_skip_to_night()
	await get_tree().physics_frame
	await TestHelpers.walk_in(main.hero, MapLayout.TIER_SIGN)
	for i in 90:
		await get_tree().physics_frame
	assert_eq(GameState.gold, held)
	assert_eq(GameState.tier_paid, 0)

func test_hidden_at_the_top_tier() -> void:
	GameState.debug_set_tier(TierEffects.top_tier(Balance.data.tiers), GameState.day)
	await get_tree().physics_frame
	assert_eq(sign.state(), &"hidden")
	assert_false(sign.label.visible)
	assert_false(sign.visible)

# --- E5 tier 3, Task 3: readable at phone size -------------------------------------------------------------------
# project.godot stretches a 720x1280 base (canvas_items, expand): a 9:21 window is 720 x 1680 base px (KEEP_WIDTH),
# 9:16 is 720 x 1280, and 16:9 keeps the 1280 base height (the 3D lens keeps the portrait vertical FOV, D-153).
# So the base-pixel height of the view is 1680, 1280 and 1280 at the three aspects below.

const ASPECTS := [9.0 / 21.0, 9.0 / 16.0, 16.0 / 9.0]

func _base_h(aspect: float) -> float:
	return 720.0 / aspect if aspect < 1.0 else 1280.0

func _xf(hero: Vector2) -> Transform3D:
	return CameraMath.camera_transform(CameraMath.focus_for(hero), Balance.ui)

## World height (m) of one text line of a label (font px x pixel_size). Label3D.get_aabb() is a placeholder without a
## renderer, so the font supplies the metrics.
func _line_h(font_size: int, pixel_size: float) -> float:
	return (load(WorldLabel.BOLD_PATH) as Font).get_height(font_size) * pixel_size

## NDC rectangle of a billboard text block of w x h metres centred on `center`.
func _block_rect(center: Vector3, w: float, h: float, xf: Transform3D, proj: Projection) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			var n := CameraMath.to_ndc(center + xf.basis.x * (w * sx) + xf.basis.y * (h * sy), xf, proj)
			lo = lo.min(Vector2(n.x, n.y))
			hi = hi.max(Vector2(n.x, n.y))
	return Rect2(lo, hi - lo)

func _box_rect(box: AABB, xf: Transform3D, proj: Projection) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				var n := CameraMath.to_ndc(Vector3(x, y, z), xf, proj)
				lo = lo.min(Vector2(n.x, n.y))
				hi = hi.max(Vector2(n.x, n.y))
	return Rect2(lo, hi - lo)

func _model_box() -> AABB:
	var mi := sign._visual.get_child(0) as MeshInstance3D
	return mi.global_transform * mi.get_aabb()

func _label_block_m(scale := 1.0) -> Vector2:
	var font := load(WorldLabel.BOLD_PATH) as Font
	var lines: PackedStringArray = sign.label.text.split("\n")
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, sign.label.font_size).x)
	return Vector2(w, _line_h(sign.label.font_size, 1.0) * lines.size()) * sign.label.pixel_size * scale

## Base-pixel height of one label line, through the real camera math.
func _label_line_px(aspect: float, hero: Vector2) -> float:
	var xf := _xf(hero)
	var proj := CameraMath.projection(Balance.ui, aspect)
	var lh := _line_h(sign.label.font_size, sign.label.pixel_size)
	var mid := sign.label.global_position
	var a := CameraMath.to_ndc(mid - xf.basis.y * lh * 0.5, xf, proj)
	var b := CameraMath.to_ndc(mid + xf.basis.y * lh * 0.5, xf, proj)
	return absf(b.y - a.y) * 0.5 * _base_h(aspect)

func test_label_line_meets_the_minimum_base_px_at_every_aspect() -> void:
	await get_tree().physics_frame
	assert_gte(Balance.ui.tier_sign_min_px, 36.0, "the floor is above what font 36 gave (30 px)")
	for aspect in ASPECTS:
		for hero in [MapLayout.TIER_SIGN, MapLayout.SIGN, MapLayout.HOME]:
			var px := _label_line_px(aspect, hero)
			gut.p("label line %.1f base px, aspect %.3f, hero %s (base height %d)" % [px, aspect, hero, _base_h(aspect)])
			assert_gte(px, Balance.ui.tier_sign_min_px, "aspect %.3f hero %s: %.1f px" % [aspect, hero, px])
	var xf := _xf(MapLayout.HOME)
	gut.p("from HOME (info): sign on screen = %s" % CameraMath.on_screen(sign.global_position, xf, CameraMath.projection(Balance.ui)))

func test_old_font_size_would_fail_the_floor() -> void:
	await get_tree().physics_frame
	var keep := sign.label.font_size
	sign.label.font_size = 36
	for aspect in ASPECTS:
		assert_lt(_label_line_px(aspect, MapLayout.TIER_SIGN), Balance.ui.tier_sign_min_px, "font 36 at aspect %.3f" % aspect)
	# smallest passing font size, for the report
	var smallest := 0
	for f in range(36, 80):
		sign.label.font_size = f
		var ok := true
		for aspect in ASPECTS:
			ok = ok and _label_line_px(aspect, MapLayout.TIER_SIGN) >= Balance.ui.tier_sign_min_px
		if ok:
			smallest = f
			break
	gut.p("smallest passing font size: %d (shipped %d)" % [smallest, keep])
	sign.label.font_size = keep
	assert_lte(smallest, keep)

func test_sign_board_and_label_top_are_on_screen_at_the_sign() -> void:
	await get_tree().physics_frame
	var xf := _xf(MapLayout.TIER_SIGN)
	var top := sign.label.global_position + xf.basis.y * (_label_block_m().y * 0.5)
	var model_top := _model_box().end.y
	for aspect in ASPECTS:
		var proj := CameraMath.projection(Balance.ui, aspect)
		assert_true(CameraMath.on_screen(sign.global_position, xf, proj), "sign base, aspect %.3f" % aspect)
		assert_true(CameraMath.on_screen(top, xf, proj), "label top, aspect %.3f" % aspect)
		assert_true(CameraMath.on_screen(Vector3(sign.global_position.x, model_top, sign.global_position.z), xf, proj), "board top, aspect %.3f" % aspect)

func test_sign_model_stays_inside_the_station_radius() -> void:
	await get_tree().physics_frame
	var box := _model_box()
	var c := Vector2(sign.global_position.x, sign.global_position.z)
	for x in [box.position.x, box.end.x]:
		for z in [box.position.z, box.end.z]:
			assert_lte(Vector2(x, z).distance_to(c), MapLayout.STATION_RADIUS + 1e-4, "corner (%.2f, %.2f)" % [x, z])

func test_baked_model_is_the_taller_sign() -> void:
	# Designed: star top at 2.4 + 0.34 = 2.74 m (the old mesh topped out at 2.21). A stale bake fails.
	await get_tree().physics_frame
	assert_gte(_model_box().end.y - sign.global_position.y, 2.7, "the baked sign's top")

func test_label_is_clear_of_the_star() -> void:
	await get_tree().physics_frame
	var xf := _xf(MapLayout.TIER_SIGN)
	var bottom := sign.label.global_position - xf.basis.y * (_label_block_m().y * 0.5)
	var tip := Vector3(sign.global_position.x, _model_box().end.y, sign.global_position.z)
	var gap := (bottom - tip).dot(xf.basis.y)
	gut.p("label block bottom above the star tip along camera up: %.2f m" % gap)
	assert_gte(gap, 0.1, "a visible gap between the label and the star")

## The real tower_w pad geometry from a tier-2 game: the marker's transformed AABB and the cost label's centre, font size,
## pixel size and a text ("500") at that size. Read after the sign geometry (the sign is hidden at tier 2).
func _pad_geometry() -> Dictionary:
	var spot = main.world.build_spots["tower_w"]
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for n in spot.marker.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
		lo = lo.min(b.position)
		hi = hi.max(b.end)
	return {"marker": AABB(lo, hi - lo), "label_pos": spot.label.global_position, "font": spot.label.font_size, "pixel": spot.label.pixel_size}

## NDC rect of the sign (model box plus label block) and of the tower_w pad (real marker plus its real cost label).
func _sign_and_pad_rects(aspect: float, label_scale: float) -> Array:
	var xf := _xf(MapLayout.TIER_SIGN)
	var proj := CameraMath.projection(Balance.ui, aspect)
	var blk := _label_block_m(label_scale)
	var sign_rect := _box_rect(_model_box(), xf, proj).merge(_block_rect(sign.label.global_position, blk.x, blk.y, xf, proj))
	var pg: Dictionary = _pad
	var font := load(WorldLabel.BOLD_PATH) as Font
	var pw: float = font.get_string_size("500", HORIZONTAL_ALIGNMENT_LEFT, -1, pg["font"]).x * float(pg["pixel"])
	var ph: float = _line_h(pg["font"], pg["pixel"])
	var pad_rect := _block_rect(pg["label_pos"], pw, ph, xf, proj).merge(_box_rect(pg["marker"], xf, proj))
	return [sign_rect, pad_rect]

var _pad := {}

func test_the_sign_stays_clear_of_the_west_tower_pad_and_its_label() -> void:
	await get_tree().physics_frame
	var blk_scale_sign := _label_block_m(1.0)  # text-dependent: measure before the tier-2 switch hides the sign
	var text := sign.label.text
	GameState.debug_set_tier(2, GameState.day)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_pad = _pad_geometry()
	# restore the tier-1 sign for the metrics: at tier 2 it now sells the front lot, on its own land with a shifted label
	sign.label.text = text
	sign.position = MapLayout.to3(MapLayout.TIER_SIGN)
	sign.label.position.x = 0.0
	assert_true(blk_scale_sign.y > 0.0)
	for aspect in ASPECTS:
		var r := _sign_and_pad_rects(aspect, 1.0)
		var gap: float = r[1].position.y - r[0].end.y
		gut.p("aspect %.3f: sign rect %s, pad rect %s, vertical NDC gap %.4f (pad marker %s)" % [aspect, r[0], r[1], gap, _pad["marker"]])
		assert_false((r[0] as Rect2).grow(0.01).intersects(r[1]), "aspect %.3f: sign (with 0.01 NDC margin) overlaps the tower_w marker or its label" % aspect)
		# Sensitivity: with a label twice as tall the sign reaches the pad marker at every aspect.
		var twice := _sign_and_pad_rects(aspect, 2.0)
		assert_true((twice[0] as Rect2).grow(0.01).intersects(twice[1]), "a label twice as tall must reach the pad MARKER at aspect %.3f" % aspect)
