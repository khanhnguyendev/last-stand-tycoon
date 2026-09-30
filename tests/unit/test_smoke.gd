extends GutTest

func test_autoloads_registered() -> void:
	assert_not_null(get_node_or_null("/root/EventBus"))
	assert_not_null(get_node_or_null("/root/Balance"))
	assert_not_null(get_node_or_null("/root/GameState"))

func test_physics_rate_is_60() -> void:
	assert_eq(Engine.physics_ticks_per_second, 60)

func test_main_scene_loads() -> void:
	var scene: PackedScene = load("res://world/main.tscn")
	assert_not_null(scene)
