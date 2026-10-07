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

## Viewport (w, h) in pixels per aspect: portrait phones are 720 wide; a 16:9 desktop window is 1920x1080.
func _viewport_px(aspect: float) -> Vector2:
	if aspect >= 1.0:
		return Vector2(1920, 1080)
	return Vector2(720, 720 / aspect)

## Projected height in pixels of ONE text line of the sign label, through the real camera math.
func _label_line_px(aspect: float, hero: Vector2) -> float:
	var xf := CameraMath.camera_transform(CameraMath.focus_for(hero), Balance.ui)
	var proj := CameraMath.projection(Balance.ui, aspect)
	# Label3D.get_aabb() is a placeholder without a renderer: the line height comes from the font (px) x pixel_size (m/px).
	var line_h := sign.label.font.get_height(sign.label.font_size) * sign.label.pixel_size
	var up := xf.basis.y
	var mid := sign.label.global_position
	var a := CameraMath.to_ndc(mid - up * line_h * 0.5, xf, proj)
	var b := CameraMath.to_ndc(mid + up * line_h * 0.5, xf, proj)
	return absf(b.y - a.y) * 0.5 * _viewport_px(aspect).y

func test_label_line_meets_the_minimum_px_at_every_aspect() -> void:
	await get_tree().physics_frame
	assert_gt(Balance.ui.tier_sign_min_px, 27.9, "the minimum is 28 px")
	for aspect in [CameraMath.ASPECT_MIN, CameraMath.ASPECT, 16.0 / 9.0]:
		for hero in [MapLayout.TIER_SIGN, MapLayout.SIGN]:
			var px := _label_line_px(aspect, hero)
			gut.p("label line %.1f px at aspect %.3f hero %s" % [px, aspect, hero])
			assert_gte(px, Balance.ui.tier_sign_min_px, "aspect %.3f hero %s: %.1f px" % [aspect, hero, px])
	gut.p("from HOME (info): sign on screen = %s" % CameraMath.on_screen(sign.global_position, CameraMath.camera_transform(CameraMath.focus_for(MapLayout.HOME), Balance.ui), CameraMath.projection(Balance.ui)))

func test_sign_board_and_label_top_are_on_screen_at_the_sign() -> void:
	await get_tree().physics_frame
	var xf := CameraMath.camera_transform(CameraMath.focus_for(MapLayout.TIER_SIGN), Balance.ui)
	var line_h := sign.label.font.get_height(sign.label.font_size) * sign.label.pixel_size
	var lines := sign.label.text.count("\n") + 1
	var top := sign.label.global_position + xf.basis.y * (line_h * lines * 0.5)
	var mi := sign._visual.get_child(0) as MeshInstance3D
	var model_top: float = (mi.global_transform * mi.get_aabb()).end.y
	for aspect in [CameraMath.ASPECT_MIN, CameraMath.ASPECT, 16.0 / 9.0]:
		var proj := CameraMath.projection(Balance.ui, aspect)
		assert_true(CameraMath.on_screen(sign.global_position, xf, proj), "sign base, aspect %.3f" % aspect)
		assert_true(CameraMath.on_screen(top, xf, proj), "label top, aspect %.3f" % aspect)
		assert_true(CameraMath.on_screen(Vector3(sign.global_position.x, model_top, sign.global_position.z), xf, proj), "board top, aspect %.3f" % aspect)

func test_sign_model_stays_inside_the_station_radius() -> void:
	await get_tree().physics_frame
	var mi := sign._visual.get_child(0) as MeshInstance3D
	var box := mi.global_transform * mi.get_aabb()
	var c := Vector2(sign.global_position.x, sign.global_position.z)
	for x in [box.position.x, box.end.x]:
		for z in [box.position.z, box.end.z]:
			assert_lte(Vector2(x, z).distance_to(c), MapLayout.STATION_RADIUS + 1e-4, "corner (%.2f, %.2f)" % [x, z])

func test_the_sign_does_not_cover_the_west_tower_pad() -> void:
	# A taller sign hides ground to its NORTH. The tower_w pad (and its label) must stay clear of the sign's screen rect.
	await get_tree().physics_frame
	var xf := CameraMath.camera_transform(CameraMath.focus_for(MapLayout.TIER_SIGN), Balance.ui)
	var proj := CameraMath.projection(Balance.ui)
	var mi := sign._visual.get_child(0) as MeshInstance3D
	var box := mi.global_transform * mi.get_aabb()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				var n := CameraMath.to_ndc(Vector3(x, y, z), xf, proj)
				lo = lo.min(Vector2(n.x, n.y))
				hi = hi.max(Vector2(n.x, n.y))
	var pad := MapLayout.spot_position("tower_w")
	for p in [Vector3(pad.x, 0, pad.y), Vector3(pad.x, 1.0, pad.y), Vector3(pad.x, 2.5, pad.y)]:
		var n := CameraMath.to_ndc(p, xf, proj)
		var inside := n.x >= lo.x and n.x <= hi.x and n.y >= lo.y and n.y <= hi.y
		assert_false(inside, "tower_w point %s is under the sign's screen box" % p)
