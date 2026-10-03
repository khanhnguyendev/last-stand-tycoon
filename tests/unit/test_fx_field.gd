extends GutTest

var f: FxField

func before_each() -> void:
	f = FxField.new()
	add_child_autofree(f)

func test_burst_fills_quads() -> void:
	f.burst(&"poof", Vector3.ZERO)
	assert_eq(f.active_count(), FxField.KINDS[&"poof"].count)

func test_life_ends_quads() -> void:
	f.burst(&"hit", Vector3.ZERO)
	for i in 120:
		f.step(1.0 / 60.0)
	assert_eq(f.active_count(), 0)

func test_capacity_never_exceeded_oldest_replaced() -> void:
	for i in 100:
		f.burst(&"poof", Vector3(i, 0, 0))
	assert_eq(f.active_count(), FxField.CAPACITY)
	assert_eq(f.multimesh.instance_count, FxField.CAPACITY)

func test_one_multimesh_with_custom_aabb() -> void:
	assert_eq(f.find_children("*", "GeometryInstance3D", true, false).size(), 0)
	assert_true(f.custom_aabb.has_volume())

func test_deterministic() -> void:
	var g := FxField.new()
	add_child_autofree(g)
	for x in [f, g]:
		x.burst(&"sparkle", Vector3(1, 0, 2))
		x.burst(&"dust", Vector3(0, 0, 0))
		for i in 10:
			x.step(1.0 / 60.0)
	assert_eq(f.instance_snapshot(), g.instance_snapshot())

func test_listens_to_fx_requested() -> void:
	EventBus.fx_requested.emit(&"coin", Vector3.ZERO)
	assert_eq(f.active_count(), FxField.KINDS[&"coin"].count)

func test_unknown_kind_is_ignored() -> void:
	f.burst(&"nope", Vector3.ZERO)
	assert_eq(f.active_count(), 0)

func test_every_kind_uses_a_known_cell_and_palette_colour() -> void:
	for k in FxField.KINDS:
		var d: Dictionary = FxField.KINDS[k]
		assert_true(int(d.cell) >= 0 and int(d.cell) < FxField.CELLS.size(), "%s cell" % k)
		assert_true(Palette.index_of(d.color) >= 0, "%s colour" % k)

func test_atlas_is_256x64_with_four_cells() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/fx/fx_atlas.png"))
	assert_not_null(img)
	assert_eq(img.get_size(), Vector2i(256, 64))
	for c in 4:
		assert_gt(img.get_pixel(c * 64 + 32, 32).a, 0.5, "cell %d centre is filled" % c)
		assert_eq(img.get_pixel(c * 64, 0).a, 0.0, "cell %d corner is clear" % c)

func test_idle_field_stays_unprocessed_work_free() -> void:
	assert_eq(f.active_count(), 0)
	f.step(0.1)
	assert_eq(f.active_count(), 0)

func test_gravity_pulls_velocity_down() -> void:
	f.burst(&"sparkle", Vector3.ZERO)
	var y0: float = f.instance_snapshot()[1]
	f.step(0.1)
	var y1: float = f.instance_snapshot()[1]
	f.step(0.1)
	var y2: float = f.instance_snapshot()[1]
	assert_gt(y1, y0, "rises first")
	assert_lt(y2 - y1, y1 - y0, "the rise slows under gravity")
