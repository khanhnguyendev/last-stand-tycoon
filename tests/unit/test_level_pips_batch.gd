extends GutTest
## E6 phase A (D-298.2): every level pip of the scene is an instance of ONE MultiMesh (one draw call). The LevelPip nodes stay as the pips' handles
## (visible, position, group `level_pips`: what the tests and the lane badge read); the batch draws them.

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(8)

func after_each() -> void:
	Balance.reset()
	GameState.new_game(1)

func _batches() -> Array:
	return main.find_children("*", "MultiMeshInstance3D", true, false).filter(func(m): return (m as MultiMeshInstance3D).multimesh.mesh == LevelStar.mesh())

func _handles() -> Array:
	return main.find_children("Pip*", "LevelPip", true, false)

func _batch() -> MultiMeshInstance3D:
	return _batches()[0]

## The number of instances the batch really draws for these handles: in range and not zero scale.
func _drawn(handles: Array) -> int:
	var b := _batch() as PipBatch
	var n := 0
	for h in handles:
		var slot := b.slot_of(h)
		if slot >= 0 and slot < b.instance_total() and not b.transform_of(h).basis.is_equal_approx(Basis.from_scale(Vector3.ZERO)):
			n += 1
	return n

func _pay_full(id: String, levels := 1) -> void:
	for i in levels:
		GameState.add_gold(GameState.next_level_cost(id))
		GameState.pay_into_spot(id, GameState.next_level_cost(id))

func test_the_scene_has_exactly_one_pips_multimesh_and_no_per_pip_mesh_instance() -> void:
	assert_eq(_batches().size(), 1, "one MultiMeshInstance3D holds every pip")
	var per_pip := main.find_children("*", "MeshInstance3D", true, false).filter(func(m): return (m as MeshInstance3D).mesh == LevelStar.mesh())
	assert_eq(per_pip.size(), 0, "no pip is a MeshInstance3D")
	assert_same((_batch() as MultiMeshInstance3D).material_override, LevelStar.material(), "one material")

func test_every_pip_is_an_instance_at_its_own_global_position() -> void:
	var hs := _handles()
	assert_eq(hs.size(), 5 * Balance.data.build.max_level + 2 * Balance.data.stations.max_level, "setup: 5 spots and 2 pads")
	var b := _batch() as PipBatch
	assert_eq(b.instance_total(), hs.size(), "one instance per pip")
	assert_eq(b.multimesh.visible_instance_count, hs.size(), "and the MultiMesh draws exactly those")
	for h in hs:
		var xf: Transform3D = b.global_transform * b.transform_of(h)
		assert_true(b.slot_of(h) >= 0, "%s has a slot" % h.get_path())
		assert_true(xf.origin.is_equal_approx((h as Node3D).global_position), "%s: instance at the pip's place" % h.get_parent().name)

func test_the_instances_drawn_per_spot_equal_its_level() -> void:
	_pay_full("tower_nw", 2)
	_pay_full("fence_w", 1)
	for id in MapLayout.SPOT_IDS:
		var s: BuildSpot = main.world.build_spots[id]
		assert_eq(_drawn(s._pips), s.level, "%s: stars drawn = level %d" % [id, s.level])
	assert_eq(_drawn(main.world.build_spots.tower_nw._pips), 2)

func test_covering_a_spot_hides_only_its_instances_and_uncovering_brings_them_back() -> void:
	_pay_full("tower_nw", 3)
	_pay_full("tower_ne", 3)
	var a: BuildSpot = main.world.build_spots.tower_nw
	var o: BuildSpot = main.world.build_spots.tower_ne
	assert_eq(_drawn(a._pips), 3)
	LevelPips.set_covered(a._pips, true, a.level)
	assert_eq(_drawn(a._pips), 0, "covered: no instance drawn")
	assert_eq(_drawn(o._pips), 3, "another spot is untouched")
	LevelPips.set_covered(a._pips, false, a.level)
	assert_eq(_drawn(a._pips), 3, "uncovered: back")

func test_a_pad_pip_follows_its_station_level() -> void:
	var pad: UpgradePad = main.world.upgrade_pads[&"counter"]
	assert_eq(_drawn(pad._pips), 0)
	GameState.add_gold(GameState.station_next_cost(&"counter"))
	GameState.pay_into_station(&"counter", GameState.station_next_cost(&"counter"))
	assert_eq(_drawn(pad._pips), 1)

func test_a_hidden_parent_hides_the_instances() -> void:
	_pay_full("tower_nw", 2)
	var s: BuildSpot = main.world.build_spots.tower_nw
	s.visible = false
	assert_eq(_drawn(s._pips), 0, "a hidden spot draws no star")
	s.visible = true
	assert_eq(_drawn(s._pips), 2)

func test_freeing_a_spot_removes_its_instances() -> void:
	var before := _handles().size()
	var s: BuildSpot = main.world.build_spots.fence_w
	var n := s._pips.size()
	main.world.remove_child(s)
	assert_eq((_batch() as PipBatch).instance_total(), before - n, "removed at once, not at the next idle frame")
	s.free()
	main.world.build_spots.erase("fence_w")
	assert_eq(_handles().size(), before - n)
	# every remaining pip still lands at its own place after the swap-removal
	var b := _batch() as PipBatch
	for h in _handles():
		assert_true((b.global_transform * b.transform_of(h)).origin.is_equal_approx((h as Node3D).global_position), "a moved slot keeps its pip's place")

func test_a_new_game_leaves_no_stale_instance() -> void:
	main.phase_controller.start_new_game(9)
	assert_eq((_batch() as PipBatch).instance_total(), _handles().size())

func test_the_multimesh_holds_no_stale_instance_after_30_rebuilds() -> void:
	var want := _handles().size()
	for i in 30:
		var s: BuildSpot = main.world.build_spots.fence_w
		main.world.remove_child(s)
		s.free()
		main.world.build_spots.erase("fence_w")
		main.world._make_spot("fence_w")
	assert_eq(_batches().size(), 1, "still one batch")
	assert_eq(_handles().size(), want)
	assert_eq((_batch() as PipBatch).instance_total(), want, "no stale instance")
	var seen := {}
	for h in _handles():
		var slot := (_batch() as PipBatch).slot_of(h)
		assert_false(seen.has(slot), "every pip has its own slot")
		seen[slot] = true

func test_a_tier_drop_and_rise_keeps_the_batch_in_step() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_tier(2, GameState.day)
	main.world.rebuild_for_tier()
	assert_eq((_batch() as PipBatch).instance_total(), _handles().size())
	GameState.debug_set_tier(1, GameState.day)
	main.world.rebuild_for_tier()
	assert_eq((_batch() as PipBatch).instance_total(), _handles().size())
	assert_eq(_batches().size(), 1)

func test_tier_3_fits_the_buffer_without_a_reallocation() -> void:
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_tier(3, GameState.day)
	main.world.rebuild_for_tier()
	var b := _batch() as PipBatch
	var want := 9 * Balance.data.build.max_level + 2 * Balance.data.stations.max_level
	assert_eq(want, 37, "setup: nine spots and two pads")
	assert_eq(_handles().size(), 37)
	assert_eq(b.instance_total(), 37)
	assert_eq(b.multimesh.visible_instance_count, 37)
	assert_gte(b.multimesh.instance_count, 37)
	assert_eq(b.multimesh.instance_count, PipBatch.MIN_CAPACITY, "no reallocation at the tier-3 reveal")
	var seen := {}
	for h in _handles():
		var slot := b.slot_of(h)
		assert_false(seen.has(slot), "unique slots")
		seen[slot] = true

func test_a_reallocation_keeps_every_earlier_pip_intact() -> void:
	_pay_full("tower_nw", 2)
	var b := _batch() as PipBatch
	var before := {}
	for h in _handles():
		before[h] = [b.transform_of(h), (h as Node3D).is_visible_in_tree()]
	var extra := Node3D.new()
	main.world.add_child(extra)
	var n := PipBatch.MIN_CAPACITY - b.instance_total() + 5
	var made: Array = LevelPips.make(extra, n, 1.0, b)  # more than the capacity: the buffer grows
	assert_gt(b.multimesh.instance_count, PipBatch.MIN_CAPACITY, "the buffer was reallocated")
	assert_eq(b.instance_total(), _handles().size())
	for h in before:
		assert_true(b.transform_of(h) == before[h][0], "%s keeps its transform" % h.get_parent().name)
		assert_eq((h as Node3D).is_visible_in_tree(), before[h][1])
	assert_eq(_drawn(main.world.build_spots.tower_nw._pips), 2, "levels still drawn after the growth")
	extra.free()
	assert_eq(b.instance_total(), _handles().size() - 0, "the extra pips left with their parent")

func test_a_lone_pip_row_without_a_world_owns_a_private_batch() -> void:
	var host := Node3D.new()
	add_child(host)
	var pips: Array = LevelPips.make(host, 3, 1.0)
	var batches := host.find_children("*", "PipBatch", true, false)
	assert_eq(batches.size(), 1, "its own batch, a child of the parent")
	assert_eq((batches[0] as PipBatch).instance_total(), 3)
	host.free()
	assert_eq(pips.size(), 3)

## A Main built and freed with no frame in between leaves no PipBatch behind (an orphan would be a batch added later, to a host that is gone).
func test_building_and_freeing_a_main_synchronously_leaves_no_pip_batch_orphan() -> void:
	var before := _pip_batch_orphans()
	var m := Main.create()
	add_child(m)
	m.phase_controller.start_new_game(3)
	remove_child(m)
	m.free()
	assert_eq(_pip_batch_orphans(), before, "no PipBatch orphan")

func _pip_batch_orphans() -> int:
	var n := 0
	for id in Node.get_orphan_node_ids():
		var o := instance_from_id(id)
		if o is PipBatch:
			n += 1
	return n
