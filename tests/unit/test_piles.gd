extends GutTest
## Task 10 (Review Focus 4): MultiMesh piles show exactly n items, no off-by-one in visible_instance_count.

func _slots(n: int) -> PackedVector3Array:
	var s := PackedVector3Array()
	for i in n:
		s.append(Vector3(i, 0, 0))
	return s

func test_zero_cap_and_clamp() -> void:
	var mmi := PileMesh.make(BoxMesh.new(), _slots(5))
	add_child_autofree(mmi)
	PileMesh.set_count(mmi, 0)
	assert_eq(PileMesh.count(mmi), 0)
	assert_eq(mmi.multimesh.visible_instance_count, 0)
	PileMesh.set_count(mmi, 5)
	assert_eq(mmi.multimesh.visible_instance_count, 5)
	PileMesh.set_count(mmi, 9)
	assert_eq(PileMesh.count(mmi), 5)
	PileMesh.set_count(mmi, -1)
	assert_eq(PileMesh.count(mmi), 0)

func test_one_instance_per_slot_and_starts_empty() -> void:
	# transforms are not readable under the headless dummy renderer; the shots check placement
	var mmi := PileMesh.make(BoxMesh.new(), _slots(4))
	add_child_autofree(mmi)
	assert_eq(mmi.multimesh.instance_count, 4)
	assert_eq(PileMesh.count(mmi), 0)

func _main() -> Main:
	Balance.reset()
	var m := Main.create()
	add_child_autofree(m)
	m.hero.input.player_control = false
	m.phase_controller.start_new_game(5)
	return m

func test_each_pile_is_one_multimesh() -> void:
	var m := _main()
	assert_eq(m.world.counter.find_children("*", "MultiMeshInstance3D", true, false).size(), 1)
	assert_eq(m.world.freezer.find_children("*", "MultiMeshInstance3D", true, false).size(), 1)
	assert_eq(m.world.gold_pile.find_children("*", "MultiMeshInstance3D", true, false).size(), 1)
	assert_eq(m.hero.carry_stack.find_children("*", "MultiMeshInstance3D", true, false).size(), 1)

func test_carry_stack_shows_the_max_capacity_exactly() -> void:
	var m := _main()
	var cb := Balance.data.cards
	var cap := CardEffects.carry_capacity(Balance.data.hero.carry_capacity, {&"carry_capacity": cb.max_level}, cb)
	assert_eq(cap, Balance.data.hero.carry_capacity + cb.carry_step * cb.max_level)
	assert_eq(m.hero.carry_stack._pile.multimesh.instance_count, cap, "one slot per steak the hero can ever carry")
	GameState.carried_steaks = cap  # test-only setup write
	EventBus.stocks_changed.emit()
	assert_eq(m.hero.carry_stack.visible_count(), cap)
	GameState.carried_steaks = 0
	EventBus.stocks_changed.emit()
	assert_eq(m.hero.carry_stack.visible_count(), 0)

func test_stations_at_zero_and_cap() -> void:
	var m := _main()
	var ecap: int = Balance.data.economy.counter_capacity
	GameState.counter_steaks = ecap
	GameState.freezer_steaks = 10
	GameState.gold_pile = GoldPile.MAX_COINS
	EventBus.stocks_changed.emit()
	assert_eq(m.world.counter.stack_count(), ecap)
	assert_eq(m.world.freezer.stack_count(), 10)
	assert_eq(m.world.gold_pile.coin_count(), GoldPile.MAX_COINS)
	GameState.counter_steaks = 0
	GameState.freezer_steaks = 0
	GameState.gold_pile = 0
	EventBus.stocks_changed.emit()
	assert_eq(m.world.counter.stack_count(), 0)
	assert_eq(m.world.freezer.stack_count(), 0)
	assert_eq(m.world.gold_pile.coin_count(), 0)

func test_fly_items_prebuild_both_kinds_and_never_instance() -> void:
	var item := FlyFx.make_item()
	add_child_autofree(item)
	var kids := item.get_child_count()
	assert_eq(kids, 2, "a steak and a coin child")
	var pool := NodePool.new()
	add_child_autofree(pool)
	pool.setup(func(): return FlyFx.make_item(), 2)
	var fx := FlyFx.new()
	add_child_autofree(fx)
	fx.setup(pool)
	fx.fly("coin", Vector3.ZERO, Vector3.ONE)
	var it: Node3D = pool.active()[0]
	assert_eq(it.get_child_count(), 2)
	assert_true((it.find_child("CoinArt", true, false) as Node3D).visible)
	assert_false((it.find_child("SteakArt", true, false) as Node3D).visible)
	pool.recall_all()
	fx.fly("steak", Vector3.ZERO, Vector3.ONE)
	it = pool.active()[0]
	assert_eq(it.get_child_count(), 2, "no per-fly instancing")
	assert_true((it.find_child("SteakArt", true, false) as Node3D).visible)
	assert_false((it.find_child("CoinArt", true, false) as Node3D).visible)

func _field(cap: int) -> PickupField:
	var f := PickupField.new()
	f.setup(BoxMesh.new(), cap)
	add_child_autofree(f)
	return f

func test_pickup_field_set_and_clear_slot() -> void:
	var f := _field(3)
	assert_eq(f.capacity(), 3)
	assert_true(f.is_slot_clear(1), "slots start cleared")
	var xf := Transform3D(Basis.IDENTITY, Vector3(1, 2, 3))
	f.set_slot(1, xf)
	assert_eq(f.slot_xf(1), xf)
	assert_false(f.is_slot_clear(1))
	f.clear_slot(1)
	assert_true(f.is_slot_clear(1))
	assert_eq(f.slot_xf(1).basis.get_scale(), Vector3.ZERO)

func test_pickup_field_grow_keeps_slots() -> void:
	var f := _field(2)
	var xf := Transform3D(Basis.IDENTITY, Vector3(4, 0, 4))
	f.set_slot(0, xf)
	f.grow(5)
	assert_eq(f.capacity(), 5)
	assert_eq(f.slot_xf(0), xf)
	assert_true(f.is_slot_clear(1))
	assert_true(f.is_slot_clear(4))
	f.grow(3)
	assert_eq(f.capacity(), 5, "grow never shrinks")

func test_slot_transform_places_and_turns() -> void:
	var item := Transform3D(Basis.from_scale(Vector3(2, 1, 2)), Vector3(1, 0, 0))
	var xf := PickupField.slot_transform(Vector3(10, 0.02, 5), PI / 2.0, item)
	assert_eq(xf.basis.get_scale(), Vector3(2, 1, 2))
	assert_almost_eq(xf.origin.x, 10.0, 1e-4)
	assert_almost_eq(xf.origin.y, 0.02, 1e-4)
	assert_almost_eq(xf.origin.z, 4.0, 1e-4)  # the item's +x offset is turned 90 degrees about y: x -> -z

func test_slot_transform_scale_applies_on_top_of_the_item() -> void:
	var item := Transform3D(Basis.from_scale(Vector3(2, 1, 2)), Vector3(1, 0, 0))
	var xf := PickupField.slot_transform(Vector3(10, 0.02, 5), 0.0, item, 1.6)
	assert_almost_eq(xf.basis.get_scale().x, 3.2, 1e-4)
	assert_almost_eq(xf.basis.get_scale().y, 1.6, 1e-4)
	assert_almost_eq(xf.origin.x, 11.6, 1e-4, "the centring offset scales too")
	assert_eq(PickupField.slot_transform(Vector3.ZERO, 0.0, item).basis.get_scale(), Vector3(2, 1, 2), "default 1.0")

func test_ground_steak_draws_at_the_tuned_scale_and_piles_do_not() -> void:
	var m := _main()
	assert_eq(Balance.ui.ground_steak_scale, 1.6)
	var s: Steak = m.world.steak_pool.acquire()
	s.place(Vector3(3, 0, 3))
	var base := PileMesh.steak_xf().basis.get_scale().x
	assert_almost_eq(m.world.pickup_field.slot_xf(s.slot).basis.get_scale().x, base * 1.6, 1e-4)
	assert_almost_eq(PileMesh.steak_xf().basis.get_scale().x, base, 1e-6)

func test_ground_steaks_are_one_field_with_no_mesh_of_their_own() -> void:
	var m := _main()
	var field: PickupField = m.world.pickup_field
	assert_eq(field.capacity(), m.world.steak_pool.size)
	var s: Steak = m.world.steak_pool.acquire()
	assert_eq(s.find_children("*", "MeshInstance3D", true, false).size(), 0)
	assert_true(field.is_slot_clear(s.slot), "not drawn until placed")
	s.place(Vector3(7, 0, 3))
	assert_false(field.is_slot_clear(s.slot))
	assert_almost_eq(field.slot_xf(s.slot).origin.x, 7.0, 0.5)
	m.world.steak_pool.release(s)
	assert_true(field.is_slot_clear(s.slot), "a released steak's slot is zero-scale")

func test_steak_slots_are_stable_and_unique() -> void:
	var m := _main()
	var seen := {}
	for n in m.world.steak_pool.get_children():
		assert_false(seen.has(n.slot))
		seen[n.slot] = true
	assert_eq(seen.size(), m.world.steak_pool.size)

func test_pool_growth_grows_the_field() -> void:
	var m := _main()
	var pool: NodePool = m.world.steak_pool
	var n := pool.size
	var held: Array = []
	for i in n + 2:
		var s: Steak = pool.acquire()
		s.place(Vector3(i, 0, 0))
		held.append(s)
	assert_eq(m.world.pickup_field.capacity(), n + 2)
	for s in held:
		assert_false(m.world.pickup_field.is_slot_clear(s.slot), "growth kept every placed steak")
	assert_push_warning_count(2)

func test_slot_transforms_order_and_offsets() -> void:
	var item := Transform3D(Basis.from_scale(Vector3(2, 2, 2)), Vector3(0, 0.5, 0))
	var xs := PileMesh.slot_transforms(_slots(3), item)
	assert_eq(xs.size(), 3)
	for i in 3:
		assert_eq(xs[i].origin, Vector3(i, 0.5, 0), "slot %d keeps its order and the item offset" % i)
		assert_eq(xs[i].basis, item.basis)

func test_steak_item_sits_on_the_floor_centred() -> void:
	var box := PileMesh.steak_xf() * PileMesh.steak_mesh().get_aabb()
	assert_almost_eq(box.position.y, 0.0, 1e-4)
	assert_almost_eq(box.position.x + box.size.x / 2.0, 0.0, 1e-4)
	assert_almost_eq(box.position.z + box.size.z / 2.0, 0.0, 1e-4)

func test_coin_item_lies_flat_centred_and_thin() -> void:
	var box := PileMesh.coin_flat_xf() * PileMesh.coin_mesh().get_aabb()
	assert_almost_eq(box.position.y, 0.0, 1e-4)
	assert_almost_eq(box.position.x + box.size.x / 2.0, 0.0, 1e-4)
	assert_almost_eq(box.position.z + box.size.z / 2.0, 0.0, 1e-4)
	assert_lt(box.size.y, 0.07, "thinner than the 0.07 stack spacing")
	assert_almost_eq(box.size.x, 0.3, 0.02)

func test_pickup_meshes_use_the_shared_material_with_no_override() -> void:
	for mesh in [PileMesh.steak_mesh(), PileMesh.coin_mesh()]:
		for i in mesh.get_surface_count():
			var mat: Material = mesh.surface_get_material(i)
			assert_not_null(mat)
			assert_true(mat.resource_path.begins_with("res://art/materials/"), "%s" % mat.resource_path)
	for path in [PileMesh.STEAK_SCENE, PileMesh.COIN_SCENE]:
		var root: Node = (load(path) as PackedScene).instantiate()
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			assert_null((mi as MeshInstance3D).material_override, "no overall override")
			for i in (mi as MeshInstance3D).mesh.get_surface_count():
				assert_null((mi as MeshInstance3D).get_surface_override_material(i), "no surface override")
		root.free()
