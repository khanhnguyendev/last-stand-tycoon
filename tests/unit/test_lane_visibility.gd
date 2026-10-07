extends GutTest
## Spec 6.4 / D-076: a Boar is on screen ≥ 2.0 s before it enters hero range, hero standing at the zone.

func before_each() -> void:
	Balance.reset()

func test_camera_centers_focus() -> void:
	var ui := Balance.ui
	var xf := CameraMath.camera_transform(Vector2(3, -2), ui)
	var proj := CameraMath.projection(ui, CameraMath.ASPECT)
	var ndc := CameraMath.to_ndc(Vector3(3, 0, -2), xf, proj)
	assert_almost_eq(ndc.x, 0.0, 0.001)
	assert_almost_eq(ndc.y, 0.0, 0.001)

func test_visible_width_about_14m() -> void:
	var ui := Balance.ui
	var xf := CameraMath.camera_transform(Vector2.ZERO, ui)
	var proj := CameraMath.projection(ui, CameraMath.ASPECT)
	var edge := 0.0
	while CameraMath.on_screen(Vector3(edge, 0, 0), xf, proj):
		edge += 0.05
	gut.p("half width at focus = %.2f m" % edge)
	assert_between(edge * 2.0, 12.5, 15.5)

func test_boar_visible_two_seconds_before_range() -> void:
	var ui := Balance.ui
	var eb := Balance.data.enemy
	var hero_range := Balance.data.hero.attack_range
	var dt := 1.0 / 60.0
	for aspect in [0.30, CameraMath.ASPECT_MIN, CameraMath.ASPECT, 16.0 / 9.0, CameraMath.ASPECT_MAX, 32.0 / 9.0]:
		var proj := CameraMath.projection(ui, aspect)
		# tiers 1 and 2 run the three lanes, tier 3 the four (the same three plus sw)
		assert_eq(MapLayout.lanes_for_tier(2), LanePlanner.LANES as Array)
		for lane in MapLayout.lanes_for_tier(3):
			var length := MapLayout.path_length(lane)
			var worst := INF
			for hero in [MapLayout.zone_rect(lane).get_center(), MapLayout.lane_end(lane)]:
				var xf := CameraMath.camera_transform(CameraMath.focus_for(hero), ui)
				for offset in [-eb.lateral_spread, 0.0, eb.lateral_spread]:
					var samples: Array = []
					var d := 0.0
					while d <= length:
						samples.append(EnemyPath.position_at(lane, d, offset, eb.offset_fade_distance))
						d += eb.speed * dt
					var range_idx := -1
					for i in samples.size():
						if (samples[i] as Vector2).distance_to(hero) <= hero_range:
							range_idx = i
							break
					assert_gt(range_idx, 0, "%s hero %s offset %.2f" % [lane, hero, offset])
					var first_visible := range_idx
					while first_visible > 0 and CameraMath.on_screen(MapLayout.to3(samples[first_visible - 1], 0.5), xf, proj):
						first_visible -= 1
					var seconds := (range_idx - first_visible) * dt
					worst = minf(worst, seconds)
					assert_true(seconds >= 2.0, "%s aspect %.3f hero %s offset %.2f only %.2f s" % [lane, aspect, hero, offset, seconds])
			gut.p("%s @ aspect %.3f: min %.2f s on screen before range" % [lane, aspect, worst])

func test_projection_matches_godot_camera() -> void:
	var ui := Balance.ui
	# Round trip: the portrait vertical FOV reproduces the horizontal FOV at 9:16.
	assert_almost_eq(tan(deg_to_rad(CameraMath.portrait_fov_v(ui)) / 2.0) * CameraMath.ASPECT, tan(deg_to_rad(ui.camera_fov_h) / 2.0), 1e-6)
	# 384x1280 (0.30) and 4096x1152 (32:9) exercise the clamped branches.
	for size in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(384, 1280), Vector2i(4096, 1152)]:
		var vp := SubViewport.new()
		vp.size = size
		add_child_autofree(vp)
		var cam := Camera3D.new()
		var aspect := float(size.x) / float(size.y)
		CameraMath.apply_lens(cam, ui, aspect)
		vp.add_child(cam)
		var got := cam.get_camera_projection()
		var want := CameraMath.projection(ui, aspect)
		for c in 4:
			for r in 4:
				assert_almost_eq(got[c][r], want[c][r], 1e-4, "%s [%d][%d]" % [size, c, r])

func test_lens_clamp_and_continuity() -> void:
	var ui := Balance.ui
	# Below ASPECT_MIN and above ASPECT_MAX the lens is clamped.
	assert_almost_eq(CameraMath.projection(ui, 0.30)[1][1], CameraMath.projection(ui, CameraMath.ASPECT_MIN)[1][1], 1e-4)
	assert_almost_eq(CameraMath.projection(ui, 32.0 / 9.0)[0][0], CameraMath.projection(ui, CameraMath.ASPECT_MAX)[0][0], 1e-4)
	# The lens is continuous across the 9:16 and 21:9 branch switches.
	for edge in [CameraMath.ASPECT, CameraMath.ASPECT_MAX]:
		var lo := CameraMath.projection(ui, edge - 1e-4)
		var hi := CameraMath.projection(ui, edge + 1e-4)
		assert_almost_eq(lo[0][0], hi[0][0], 1e-3, "[0][0] at %.4f" % edge)
		assert_almost_eq(lo[1][1], hi[1][1], 1e-3, "[1][1] at %.4f" % edge)
