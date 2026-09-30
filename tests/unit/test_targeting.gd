extends GutTest

func _c(x: float, z: float, idx: int) -> Dictionary:
	return {"position": Vector3(x, 0, z), "spawn_index": idx, "ref": null}

func test_nearest_in_range_wins() -> void:
	var got := Targeting.select(Vector3.ZERO, 4.0, [_c(3, 0, 5), _c(1, 1, 9), _c(0, 5, 1)])
	assert_eq(got.spawn_index, 9)

func test_out_of_range_ignored() -> void:
	assert_eq(Targeting.select(Vector3.ZERO, 4.0, [_c(0, 4.5, 1)]), {})

func test_tie_breaks_by_lower_spawn_index_regardless_of_order() -> void:
	assert_eq(Targeting.select(Vector3.ZERO, 4.0, [_c(2, 0, 8), _c(-2, 0, 3)]).spawn_index, 3)
	assert_eq(Targeting.select(Vector3.ZERO, 4.0, [_c(-2, 0, 3), _c(2, 0, 8)]).spawn_index, 3)

func test_height_is_ignored() -> void:
	var c := {"position": Vector3(0, 10, 3), "spawn_index": 1, "ref": null}
	assert_eq(Targeting.select(Vector3.ZERO, 4.0, [c]).spawn_index, 1)

func test_candidate_exactly_at_range_is_selected() -> void:
	assert_eq(Targeting.select(Vector3.ZERO, 4.0, [_c(0, 4.0, 7)]).spawn_index, 7)
	assert_eq(Targeting.select(Vector3.ZERO, 4.0, [_c(-4.0, 0, 2)]).spawn_index, 2)
