extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)

func _check(body: StaticBody3D, visual: Node3D) -> void:
	assert_eq(body.get_child_count(), 2)
	assert_true(body.get_child(0) is CollisionShape3D, "child 0 is the collision shape")
	assert_true(body.get_child(1) is Node3D, "child 1 is the visual root")
	assert_false(body.get_child(1) is CollisionShape3D, "child 1 is not a shape")
	assert_eq(visual, body.get_child(1))
	assert_eq(body.get_child(1).get_child_count(), 1, "the art scene is instanced under the visual root")

func test_the_counter_body_is_shape_then_visual() -> void:
	_check(main.world.get_node("CounterBody") as StaticBody3D, main.world.counter.body_visual)

func test_the_freezer_body_is_shape_then_visual() -> void:
	_check(main.world.get_node("FreezerBody") as StaticBody3D, main.world.freezer.body_visual)

func test_a_box_without_a_visual_scene_keeps_the_order() -> void:
	var body: StaticBody3D = main.world.add_static_box("TestBox", Vector3.ONE, Vector2(20, 20))
	assert_not_null(body)
	assert_eq(body.get_child_count(), 2)
	assert_true(body.get_child(0) is CollisionShape3D)
	assert_true(body.get_child(1) is Node3D)
	assert_false(body.get_child(1) is CollisionShape3D, "child 1 is not a shape")
