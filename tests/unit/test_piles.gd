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

func test_ground_steak_uses_the_shared_mesh_and_material() -> void:
	var a := Steak.new()
	var b := Steak.new()
	add_child_autofree(a)
	add_child_autofree(b)
	var ma := a.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mb := b.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_same(ma.mesh, mb.mesh)
	assert_same(ma.mesh, PileMesh.steak_mesh())
