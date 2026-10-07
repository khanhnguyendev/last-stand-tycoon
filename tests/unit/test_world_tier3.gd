extends GutTest
## E5 tier 3 Task 9: the world builds and uses the south-west lane, fence and tower from tier 3, and nothing of them below.

const TIER1_CHILDREN := ["EnemyPool", "SteakPool", "ProjectilePool", "FxPool", "WaveDirector", "TravelerPool", "TravelerSpawner",
	"LightingDirector", "ShadowField", "Ground", "EdgeStones", "Props", "Diner", "Lane_west", "Lane_north", "Lane_east", "PickupField",
	"FlyFx", "Spot_tower_nw", "Spot_tower_ne", "Spot_fence_w", "Spot_fence_n", "Spot_fence_e", "Freezer", "FreezerBody", "Counter",
	"CounterBody", "Pad_counter", "Pad_freezer", "GoldPile", "CloseUpSign", "TierSign", "Telegraph_west", "Telegraph_north",
	"Telegraph_east", "GuardRoster", "FxField", "Reactions", "TierReveal"]
const SW_NODES := ["Lane_sw", "Telegraph_sw", "Spot_tower_sw", "Spot_fence_sw"]

var main: Main

func before_each() -> void:
	Balance.reset()
	Balance.data.tiers.tier_costs.append(1500)  # test-only: the build knows tier 3
	main = Main.create()
	add_child_autofree(main)
	GameState.new_game(1)
	await get_tree().physics_frame
	main.hero.input.player_control = false
	main.hero.teleport(Vector2(20, 10))

func after_each() -> void:
	Balance.reset()
	GameState.new_game(1)

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _names() -> Array:
	var out := []
	for c in main.world.get_children():
		if not c.name.begins_with("@"):  # the unnamed light and environment
			out.append(String(c.name))
	return out

func _pay(id: String) -> void:
	GameState.add_gold(GameState.next_level_cost(id))
	GameState.pay_into_spot(id, GameState.next_level_cost(id))

func _sw_plan() -> Array:
	var w := {"main": "sw", "side": "", "main_count": 4, "side_count": 0, "hp_mult": 1.0, "fast_main": 0, "fast_side": 0,
		"boss": false, "brute_main": 0, "brute_side": 0}
	return [w.duplicate(), w.duplicate(), w.duplicate()]

func test_tier_1_scene_is_exactly_as_before() -> void:
	var names := _names()
	var want := TIER1_CHILDREN.duplicate()
	names.sort()
	want.sort()
	assert_eq(names, want)
	assert_eq(main.world.lanes.keys(), ["west", "north", "east"])
	assert_eq(main.world.telegraph_markers.keys(), ["west", "north", "east"])
	assert_eq(main.world.build_spots.keys(), ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e"])

func test_tier_2_adds_only_the_yards_and_never_a_south_west_node() -> void:
	GameState.debug_set_tier(2, 3)
	var names := _names()
	for n in SW_NODES:
		assert_false(n in names, n)
	var want := TIER1_CHILDREN.duplicate()
	want.append_array(["YardStones", "Spot_tower_w", "Spot_tower_e"])
	names.sort()
	want.sort()
	assert_eq(names, want)
	assert_eq(main.world.lanes.keys(), ["west", "north", "east"])
	assert_eq(main.world.telegraph_markers.keys(), ["west", "north", "east"])

func test_tier_3_builds_the_south_west_lane_marker_and_spots() -> void:
	var stones_t1: int = main.world.edge_stones.multimesh.instance_count
	var mesh_t1 := main.world.ground.mesh
	GameState.debug_set_tier(2, 3)
	assert_eq(main.world.edge_stones.multimesh.instance_count, stones_t1, "tier 2 keeps tier 1's stones")
	var kept = main.world.lanes["west"]
	GameState.debug_set_tier(3, 5)
	for n in SW_NODES:
		assert_true(n in _names(), n)
	assert_eq(main.world.lanes.keys(), ["west", "north", "east", "sw"])
	assert_same(main.world.lanes["west"], kept, "the tier-1 lanes are not rebuilt")
	assert_eq(main.world.telegraph_markers.keys(), ["west", "north", "east", "sw"])
	assert_true(main.world.build_spots["tower_sw"] is TowerSpot)
	assert_true(main.world.build_spots["fence_sw"] is FenceSpot)
	assert_eq(Vector2(main.world.lanes["sw"].entrance_position().x, main.world.lanes["sw"].entrance_position().z), MapLayout.lane_path("sw")[0])
	assert_gt(main.world.edge_stones.multimesh.instance_count, stones_t1, "the south-west strip has edge stones")
	assert_ne(main.world.ground.mesh, mesh_t1)
	assert_eq(main.world.ground.mesh, GroundArt.terrain_mesh(World.ground_rect(), MapLayout.yards_for_tier(3), MapLayout.lanes_for_tier(3)))
	assert_eq(main.world.find_children("Ground", "MeshInstance3D", true, false).size(), 1, "still one ground draw")

func test_new_game_removes_every_south_west_node() -> void:
	var stones_t1: int = main.world.edge_stones.multimesh.instance_count
	var mesh_t1 := main.world.ground.mesh
	GameState.debug_set_tier(3, 5)
	GameState.new_game(1)
	var names := _names()
	for n in SW_NODES:
		assert_false(n in names, n)
	assert_eq(main.world.lanes.keys(), ["west", "north", "east"])
	assert_eq(main.world.telegraph_markers.keys(), ["west", "north", "east"])
	assert_eq(main.world.build_spots.keys(), MapLayout.spots_for_tier(1))
	assert_eq(main.world.edge_stones.multimesh.instance_count, stones_t1)
	assert_eq(main.world.ground.mesh, mesh_t1)
	assert_eq(names.size(), TIER1_CHILDREN.size())

func test_the_ground_mesh_below_tier_3_does_not_depend_on_the_lane_argument() -> void:
	var rect := World.ground_rect()
	assert_same(GroundArt.terrain_mesh(rect, []), GroundArt.terrain_mesh(rect, [], MapLayout.lanes_for_tier(2)))
	assert_same(GroundArt.terrain_mesh(rect, ["west", "east"]), GroundArt.terrain_mesh(rect, ["west", "east"], MapLayout.lanes_for_tier(2)))
	var t3 := GroundArt.terrain_mesh(rect, MapLayout.yards_for_tier(3), MapLayout.lanes_for_tier(3))
	assert_ne(t3, GroundArt.terrain_mesh(rect, MapLayout.yards_for_tier(3)), "the lane set is part of the cache key")

func test_the_warm_up_prebuilds_the_top_tier_lanes() -> void:
	# the top tier is 3 in this test (tier_costs gained a third entry)
	Warmup._prebuild_tier_caches()
	assert_true(GroundArt.is_cached(World.ground_rect(), MapLayout.yards_for_tier(3), MapLayout.lanes_for_tier(3)))

func test_a_boar_walks_the_south_west_lane_into_its_zone_and_hits_the_diner() -> void:
	GameState.debug_set_tier(3, 5)
	var b := main.world.wave_director.debug_spawn("sw")
	assert_eq(b.lane, "sw")
	assert_almost_eq(b.path_length(), Geometry.path_length(MapLayout.lane_path("sw")), 1e-4)
	var diner_hp := GameState.diner_hp
	var guard := 0
	while not b.at_path_end() and guard < 60 * 60:
		await _ticks(1)
		guard += 1
	assert_true(b.at_path_end(), "it arrived")
	assert_true(MapLayout.zone_rect("sw").grow(0.01).has_point(Vector2(b.position.x, b.position.z)), "the stop point is inside the SW zone")
	await _ticks(60 * 3)
	assert_lt(GameState.diner_hp, diner_hp, "no fence: it attacks the diner")

func test_a_fence_on_the_south_west_lane_stops_a_boar_and_takes_the_hits() -> void:
	GameState.debug_set_tier(3, 5)
	_pay("fence_sw")
	var b := main.world.wave_director.debug_spawn("sw")
	b.dist = b.path_length() - 8.0
	var diner_hp := GameState.diner_hp
	var fence_hp: float = GameState.buildings["fence_sw"].hp
	await _ticks(60 * 6)
	assert_almost_eq(b.dist, TargetProviders.fence_stop_dist(b), 1e-3, "it stopped at the fence")
	assert_lt(b.dist, b.path_length() - 3.0)
	assert_lt(float(GameState.buildings["fence_sw"].hp), fence_hp, "the fence took the damage")
	assert_eq(GameState.diner_hp, diner_hp, "the diner took none")

func test_the_south_west_tower_shoots_a_monster_in_the_south_west_zone() -> void:
	GameState.debug_set_tier(3, 5)
	_pay("tower_sw")
	var t: TowerSpot = main.world.build_spots["tower_sw"]
	assert_true(t.attacker.enabled)
	var b := main.world.wave_director.debug_spawn("sw", 0.0, 50.0)  # a lot of hp: it must survive to show the hit
	b.dist = b.path_length() - 1.0  # it walks the last metre into the zone (a monster at the end does not move its node)
	var hp := b.health.hp
	await _ticks(60 * 4)
	assert_true(MapLayout.zone_rect("sw").grow(0.01).has_point(Vector2(b.position.x, b.position.z)), "it stands in the zone")
	assert_lt(b.health.hp, hp, "the tower hit it")

func test_the_south_west_marker_shows_a_threat_for_a_south_west_plan() -> void:
	GameState.debug_set_tier(3, 5)
	GameState.lane_plan = _sw_plan()
	EventBus.phase_changed.emit(Phase.DAY, GameState.day)
	var m: TelegraphMarker = main.world.telegraph_markers["sw"]
	m.refresh()
	assert_true(m.visible)
	assert_gt(m.target_scale, 0.0)
	assert_eq(Vector2(m.position.x, m.position.z), MapLayout.telegraph_spot("sw"))
	assert_false((main.world.telegraph_markers["north"] as TelegraphMarker).visible, "no threat on north")
	EventBus.phase_changed.emit(Phase.NIGHT, GameState.day)

func test_a_brute_spawns_from_a_tier_3_schedule_and_walks_the_south_west_lane() -> void:
	GameState.debug_set_tier(3, 5)
	var plan := _sw_plan()
	for w in plan:
		w.brute_main = 1
	var sched := WaveSchedule.build(plan[0], Balance.data.wave, Balance.data.tiers)
	var brutes := sched.filter(func(e): return e.get("kind", &"boar") == &"brute")
	assert_eq(brutes.size(), 1)
	var wd := main.world.wave_director
	wd.start_night(plan)
	var found: Boar = null
	for i in 60 * 60:
		await _ticks(1)
		for b in wd.alive_enemies():
			if (b as Boar).kind == &"brute":
				found = b
		if found != null:
			break
	assert_not_null(found, "a brute spawned")
	if found != null:
		assert_eq(found.lane, "sw")
		var d := found.dist
		await _ticks(30)
		assert_gt(found.dist, d, "it walks")
	wd.stop()
