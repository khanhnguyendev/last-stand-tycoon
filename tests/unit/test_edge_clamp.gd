extends GutTest
## S5 Task 10: the edge-arrow clamp maths (was Hud._place_arrows).

const RECT := Rect2(100, 200, 400, 600)

func test_inside_point_unchanged() -> void:
	var r := EdgeClamp.clamp_to_rect(Vector2(300, 500), RECT)
	assert_true(r.inside)
	assert_eq(r.position, Vector2(300, 500))
	assert_eq(r.rotation, 0.0)

func test_far_right_lands_on_right_edge() -> void:
	var r := EdgeClamp.clamp_to_rect(Vector2(5000, 500), RECT)
	assert_false(r.inside)
	assert_almost_eq(r.position.x, RECT.end.x, 0.001)
	assert_almost_eq(r.rotation, -PI / 2.0, 0.001)

func test_far_below_lands_on_bottom_edge() -> void:
	var r := EdgeClamp.clamp_to_rect(Vector2(300, 9000), RECT)
	assert_almost_eq(r.position.y, RECT.end.y, 0.001)
	assert_almost_eq(r.rotation, 0.0, 0.001)

func test_corner_direction_lands_on_boundary() -> void:
	var r := EdgeClamp.clamp_to_rect(Vector2(-4000, -4000), RECT)
	assert_false(r.inside)
	var pos: Vector2 = r.position
	assert_true(RECT.grow(0.01).has_point(pos))
	var on_edge := is_equal_approx(pos.x, RECT.position.x) or is_equal_approx(pos.x, RECT.end.x) \
		or is_equal_approx(pos.y, RECT.position.y) or is_equal_approx(pos.y, RECT.end.y)
	assert_true(on_edge, "on the boundary: %s" % pos)
