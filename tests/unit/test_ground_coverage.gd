extends GutTest
## D-152/D-153: no camera view (any focus corner, any window aspect) shows past the ground.
## 0.30 and 32:9 are outside [ASPECT_MIN, ASPECT_MAX] and must be clamped by CameraMath.

const ASPECTS := [0.30, 9.0 / 21.0, 9.0 / 19.5, CameraMath.ASPECT, 16.0 / 9.0, 21.0 / 9.0, 32.0 / 9.0]

func before_each() -> void:
	Balance.reset()

func _corners() -> Array:
	var lo := CameraMath.FOCUS_MIN
	var hi := CameraMath.FOCUS_MAX
	return [lo, hi, Vector2(lo.x, hi.y), Vector2(hi.x, lo.y)]

## Viewport corners only, in pixels; the farthest ground point of a perspective view is always a corner,
## so a top-mid sample adds nothing.
func _sample_points(size: Vector2) -> Array:
	return [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), size]

func test_ground_rect_contains_bounds() -> void:
	var r := World.ground_rect()
	assert_true(r.encloses(Rect2(MapLayout.BOUNDS_MIN, MapLayout.BOUNDS_MAX - MapLayout.BOUNDS_MIN)))

func test_every_camera_view_hits_ground_inside_rect() -> void:
	var ui := Balance.ui
	var rect := World.ground_rect()
	var max_dist := 0.0
	for aspect in ASPECTS:
		var size := Vector2(maxf(roundf(1280.0 * aspect), 1.0), 1280.0)
		var vp := SubViewport.new()
		vp.size = Vector2i(size)
		add_child_autofree(vp)
		var cam := Camera3D.new()
		CameraMath.apply_lens(cam, ui, size.x / size.y)
		vp.add_child(cam)
		for focus in _corners():
			cam.global_transform = CameraMath.camera_transform(focus, ui)
			var far_hit := Vector2.ZERO
			var far_d := -1.0
			for p in _sample_points(size):
				var o := cam.project_ray_origin(p)
				var d := cam.project_ray_normal(p)
				var label := "aspect %.3f focus %s px %s" % [aspect, focus, p]
				assert_lt(d.y, 0.0, "ray points downward: " + label)
				if d.y >= 0.0:
					continue
				var hit := o + d * (-o.y / d.y)
				var hit_xz := Vector2(hit.x, hit.z)
				assert_true(rect.has_point(hit_xz), "hit %s inside %s: %s" % [hit_xz, rect, label])
				var dist := _outside_bounds(hit_xz)
				if dist > far_d:
					far_d = dist
					far_hit = hit_xz
			max_dist = maxf(max_dist, far_d)
			gut.p("aspect %.3f focus %s: farthest hit %s, %.2f m past bounds" % [aspect, focus, far_hit, far_d])
	gut.p("max distance past bounds over all corners/aspects: %.2f m" % max_dist)
	assert_lt(max_dist, World.GROUND_MARGIN - 5.0, "headroom inside the ground margin")

## Distance from the bounds rectangle (0 when inside).
func _outside_bounds(p: Vector2) -> float:
	var lo := MapLayout.BOUNDS_MIN
	var hi := MapLayout.BOUNDS_MAX
	var dx := maxf(maxf(lo.x - p.x, p.x - hi.x), 0.0)
	var dy := maxf(maxf(lo.y - p.y, p.y - hi.y), 0.0)
	return Vector2(dx, dy).length()

## E5 spec 7.5: the reveal camera (fitted focus, fitted zoom and the cap) at every aspect. The reveal focus is fixed (the
## diner and yards centre), not a follow focus, so only that focus is checked. Aspects from 9:19.5 to 16:9 must be fully
## on the ground. Beyond them (9:21, 21:9 and the clamped ones) the far edge of a pulled-back view shows past the ground by
## a few metres: the world background is the grass colour there (D-153), so the test pins the overshoot, not zero.
const REVEAL_STRICT_MIN := 9.0 / 19.5
const REVEAL_STRICT_MAX := 16.0 / 9.0 + 1e-6
const REVEAL_EDGE_SLACK := 25.0

func test_the_reveal_frame_hits_ground_inside_rect() -> void:
	var ui := Balance.ui
	var rect := World.ground_rect()
	var frame := TierReveal.frame_for(2, ui)
	for aspect in ASPECTS:
		var size := Vector2(maxf(roundf(1280.0 * aspect), 1.0), 1280.0)
		var vp := SubViewport.new()
		vp.size = Vector2i(size)
		add_child_autofree(vp)
		var cam := Camera3D.new()
		CameraMath.apply_lens(cam, ui, size.x / size.y)
		vp.add_child(cam)
		var strict: bool = aspect >= REVEAL_STRICT_MIN and aspect <= REVEAL_STRICT_MAX
		for z in [frame.zoom, ui.tier_reveal_zoom]:
			cam.global_transform = CameraMath.zoomed_transform(frame.focus, ui, z)
			var worst := 0.0
			for p in _sample_points(size):
				var o := cam.project_ray_origin(p)
				var d := cam.project_ray_normal(p)
				assert_lt(d.y, 0.0, "ray points downward")
				if d.y >= 0.0:
					continue
				var hit := o + d * (-o.y / d.y)
				var hxz := Vector2(hit.x, hit.z)
				var past := maxf(maxf(rect.position.x - hxz.x, hxz.x - rect.end.x), maxf(rect.position.y - hxz.y, hxz.y - rect.end.y))
				worst = maxf(worst, past)
				if strict:
					assert_true(rect.has_point(hxz), "hit %s inside ground: aspect %.3f zoom %.2f" % [hxz, aspect, z])
			assert_lt(worst, REVEAL_EDGE_SLACK, "aspect %.3f zoom %.2f" % [aspect, z])
			gut.p("aspect %.3f zoom %.2f: %.1f m past the ground%s" % [aspect, z, maxf(worst, 0.0), "" if strict else " (not strict)"])
