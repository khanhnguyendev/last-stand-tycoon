extends GutTest

func before_each() -> void:
	Balance.reset()

func test_main_builds_world_without_starting() -> void:
	var main := Main.create()
	add_child_autofree(main)
	assert_false(main.auto_start)
	assert_not_null(main.world)
	assert_eq(main.world.lanes.size(), 3)
	assert_not_null(main.world.diner_body)
	assert_eq(main.world.diner_body.collision_layer, 1)
	assert_eq(main.world.diner_body.collision_mask, 0)
	var shape: BoxShape3D = main.world.diner_body.find_children("*", "CollisionShape3D", false, false)[0].shape
	assert_eq(shape.size, Vector3(8, 3, 8))

func test_lane_curve_matches_layout() -> void:
	var main := Main.create()
	add_child_autofree(main)
	var lane: Lane = main.world.lanes["west"]
	assert_eq(lane.path3d.curve.point_count, 3)
	assert_eq(lane.entrance_position(), Vector3(-16, 0, -24))
