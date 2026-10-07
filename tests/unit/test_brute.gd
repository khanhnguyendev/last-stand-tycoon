extends GutTest
## E5 tier 3, Task 10 (spec 3.4, 6.2, D-265): the siege brute. Fence damage x fence_damage_mult, normal damage to guards and
## the diner, the Boar's target order, a heavy slow walk, a ground thump on fence hits only. Literal numbers: the brute does
## 8 damage per hit (x4 = 32 on a fence), the Boar 5; mercy_factor() is asserted 1.0 in before_each; a level-1 fence holds 120 hp.

class FakeDirector:
	extends RefCounted
	var providers := TargetProviders.new()
	var guard_target := {}
	func _init() -> void:
		providers.register(&"fence_on_lane", func(e): return TargetProviders.fence_on_lane(e))
		providers.register(&"guard", func(_e): return guard_target)
		providers.register(&"diner", func(e): return TargetProviders.diner(e))
	func on_enemy_died(_b) -> void:
		pass

const DT := 1.0 / 60.0
var dir: FakeDirector
var _sfx: Array = []
var _fx: Array = []

func before_each() -> void:
	Balance.reset()
	GameState.new_game(7)
	assert_eq(GameState.mercy_factor(), 1.0, "no failed nights: hits are the raw damage")
	dir = FakeDirector.new()
	_sfx = []
	_fx = []
	EventBus.sfx_requested.connect(_on_sfx)
	EventBus.fx_requested.connect(_on_fx)

func after_each() -> void:
	EventBus.sfx_requested.disconnect(_on_sfx)
	EventBus.fx_requested.disconnect(_on_fx)
	Balance.reset()
	GameState.new_game(1)

func _on_sfx(id: StringName) -> void:
	_sfx.append(id)

func _on_fx(kind: StringName, pos: Vector3) -> void:
	_fx.append({"kind": kind, "pos": pos})

func _count_sfx(id: StringName) -> int:
	return _sfx.count(id)

func _count_fx(kind: StringName) -> int:
	var n := 0
	for e in _fx:
		if e.kind == kind:
			n += 1
	return n

func _mon(kind: StringName, lane := "north") -> Boar:
	var b := Boar.new()
	b.process_mode = Node.PROCESS_MODE_DISABLED  # stepped by hand
	add_child_autofree(b)
	b.spawn(lane, 0, 0.0, 1.0, dir, kind)
	return b

func _step(b: Boar, frames: int) -> void:
	for i in frames:
		b._physics_process(DT)

func _build_fence(id := "fence_n") -> void:
	GameState.add_gold(GameState.next_level_cost(id))
	GameState.pay_into_spot(id, GameState.next_level_cost(id))

## Puts the monster at its fence's stop point and lets exactly one attack land (1.0 s interval).
func _one_fence_hit(kind: StringName) -> void:
	var b := _mon(kind)
	b.dist = TargetProviders.fence_stop_dist(b)
	_step(b, 60)

func test_brute_stats_are_the_spec_numbers() -> void:
	var s := Balance.data.monsters.stats(&"brute")
	assert_eq(s.damage, 8.0)
	assert_eq(s.fence_damage_mult, 4.0)
	assert_eq(Balance.data.monsters.stats(&"boar").fence_damage_mult, 1.0)

# Fails if the brute's fence hit is plain damage (88 -> 112 left) or the multiplier is applied to every kind.
func test_brute_hit_removes_32_from_a_fence_and_a_boar_5() -> void:
	_build_fence()
	assert_eq(float(GameState.buildings.fence_n.hp), 120.0)
	_one_fence_hit(&"brute")
	assert_eq(float(GameState.buildings.fence_n.hp), 88.0, "120 - 8 x 4")
	GameState.new_game(7)
	_build_fence()
	_one_fence_hit(&"boar")
	assert_eq(float(GameState.buildings.fence_n.hp), 115.0, "120 - 5 x 1")

# Fails if the attacker kind is not passed to damage_fence (a Stone fence would then take the full 32).
func test_stone_fence_halves_a_brute_hit_only() -> void:
	_build_fence()
	# Direct state edit: choosing Stone through pay_into_branch needs a level-3 fence and tier 3 gold; the branch field is the
	# real state and damage_fence reads it (spec 3.6).
	var b: Dictionary = GameState.buildings.fence_n
	b.level = 3
	b.branch = "stone"
	b.hp = 640.0
	_one_fence_hit(&"brute")
	assert_eq(float(GameState.buildings.fence_n.hp), 624.0, "640 - 32 x 0.5")
	GameState.buildings.fence_n.hp = 640.0
	_one_fence_hit(&"boar")
	assert_eq(float(GameState.buildings.fence_n.hp), 635.0, "stone only reduces brute hits: 640 - 5")

# Fails if the multiplier leaks onto guards (would be 50 - 32) or the diner.
func test_brute_hits_a_guard_and_the_diner_for_normal_damage() -> void:
	GameState.guards[&"g1"] = {"hp": 50.0}
	dir.guard_target = {"kind": &"guard", "guard_id": &"g1"}
	var b := _mon(&"brute")
	_step(b, 60)
	assert_eq(float(GameState.guards[&"g1"].hp), 42.0, "50 - 8")
	dir.guard_target = {}
	b.dist = b.path_length()
	var hp := GameState.diner_hp
	_step(b, 60)
	assert_eq(GameState.diner_hp, hp - 8.0)

# Fails if the brute ignores the lane fence (walks through it) or stops short/at the wrong place.
func test_with_a_standing_fence_it_stops_at_the_fence() -> void:
	_build_fence()
	var b := _mon(&"brute")
	# walk to the stop point, then one hit (a 120 hp fence falls to rubble on the 4th brute hit)
	_step(b, int(TargetProviders.fence_stop_dist(b) / 1.2 * 60.0) + 70)
	assert_almost_eq(b.dist, b.path_length() - MapLayout.FENCE_OFFSET_FROM_END - 1.2, 0.05)
	assert_eq(float(GameState.buildings.fence_n.hp), 88.0, "it stopped and hit the fence once")
	assert_eq(GameState.diner_hp, Balance.data.build.diner_max_hp)

func test_with_no_fence_it_walks_into_the_zone_like_a_boar() -> void:
	var b := _mon(&"brute")
	_step(b, int(MapLayout.path_length("north") / 1.2 * 60.0) + 30)
	assert_true(b.at_path_end())
	assert_true(Geometry.rect_contains(MapLayout.ZONE_RECTS.north, Vector2(b.position.x, b.position.z)))
	assert_eq(_count_sfx(&"thump"), 0, "no fence, no thump")

# Fails if the thump fires per attack of any target, per frame, or not at all, or if the dust is not two bursts either side.
func test_thump_fires_once_per_fence_hit_with_two_dust_bursts_beside_the_body() -> void:
	_build_fence()
	var b := _mon(&"brute")
	b.dist = TargetProviders.fence_stop_dist(b)
	_step(b, 60)
	assert_eq(_count_sfx(&"thump"), 1)
	assert_eq(_count_fx(&"dust"), 2, "two bursts per hit")
	# the north fence spot centre; the zone axis is (-1, 0): the bursts sit at x = c.x + 1.3 and c.x - 1.3, 0.3 m up, on the fence line
	var c := MapLayout.spot_position("fence_n")
	assert_eq(_fx.size(), 2)
	if _fx.size() == 2:
		assert_eq(_fx[0].pos, Vector3(c.x + 1.3, 0.3, c.y))
		assert_eq(_fx[1].pos, Vector3(c.x - 1.3, 0.3, c.y))
		assert_almost_eq(absf(_fx[0].pos.x - _fx[1].pos.x), 2.6, 1e-4, "the bursts are 2.6 m apart across the lane")
		assert_almost_eq(_fx[0].pos.z, _fx[1].pos.z, 1e-4, "on the fence line")
		assert_gt(absf(_fx[0].pos.x - b.global_position.x), 1.0, "outside the body half-width")
	_step(b, 60)
	assert_eq(_count_sfx(&"thump"), 2)
	assert_eq(_count_fx(&"dust"), 4)

func test_no_thump_for_a_guard_or_diner_hit_or_a_boar() -> void:
	GameState.guards[&"g1"] = {"hp": 50.0}
	dir.guard_target = {"kind": &"guard", "guard_id": &"g1"}
	var b := _mon(&"brute")
	_step(b, 60)
	dir.guard_target = {}
	b.dist = b.path_length()
	_step(b, 60)
	assert_eq(_count_sfx(&"thump"), 0)
	assert_eq(_count_fx(&"dust"), 0)
	_build_fence()
	_one_fence_hit(&"boar")
	assert_eq(_count_sfx(&"thump"), 0, "a Boar's fence hit has no thump")

func test_thump_sound_is_in_the_manifest_and_loads() -> void:
	assert_true(AudioManifest.SFX.has(&"thump"))
	var e: Dictionary = AudioManifest.SFX.get(&"thump", {})
	assert_false(e.is_empty())
	assert_not_null(load(String(e.get("path", ""))) if not e.is_empty() else null)

# Fails if the brute is not slower than the Boar or its speed is not read from its own stats.
func test_speed_over_two_seconds() -> void:
	var brute := _mon(&"brute")
	var boar := _mon(&"boar")
	_step(brute, 120)
	_step(boar, 120)
	assert_almost_eq(brute.dist, 2.4, 0.01, "1.2 m/s x 2 s")
	assert_almost_eq(boar.dist, 4.0, 0.01, "2.0 m/s x 2 s")

func test_the_wave_director_spawns_a_brute_with_its_hp() -> void:
	var main := Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	GameState.new_game(1)
	var wd := main.world.wave_director
	wd.start_night(GameState.lane_plan)
	var b := wd.debug_spawn("north", 0.0, 1.0, &"brute")
	assert_eq(b.kind, &"brute")
	assert_eq(b.health.max_hp, 240.0)

# Fails if the brute keeps the Boar's light hop and lunge.
func test_the_brute_walks_heavy_like_the_boss_not_like_the_boar() -> void:
	var v := BoarVisual.new()
	autofree(v)
	var ui := Balance.ui
	v.kind = &"boar"
	assert_eq(v._hop(), Vector2(ui.boar_hop_height, ui.boar_hop_hz))
	v.kind = &"brute"
	assert_eq(v._hop(), Vector2(ui.boss_hop_height, ui.boss_hop_hz))
	assert_eq(v._lunge_dist(), ui.boss_lunge)
	assert_lt(v._hop().y, ui.boar_hop_hz, "slower bob than the Boar")

# Fails if the target order puts the guard before the lane fence (the guard would lose 8 and the fence nothing).
func test_fence_before_guard_when_both_are_in_reach() -> void:
	_build_fence()
	GameState.guards[&"g1"] = {"hp": 50.0}
	dir.guard_target = {"kind": &"guard", "guard_id": &"g1"}
	var b := _mon(&"brute")
	b.dist = TargetProviders.fence_stop_dist(b)
	_step(b, 60)
	assert_eq(float(GameState.buildings.fence_n.hp), 88.0, "the fence took the hit")
	assert_eq(float(GameState.guards[&"g1"].hp), 50.0, "the guard keeps all its hp")

# Fails if brutes are not counted in the enemy pool (a pool of max_wave_size + 1 + 0 would miss the cap night).
func test_enemy_pool_covers_a_tier_3_cap_wave_with_brutes_and_a_boss() -> void:
	var bd := Balance.data
	var pool: int = World.pool_sizes(bd).enemy
	assert_gte(pool, bd.wave.max_wave_size + bd.tiers.brute_cap_main[3] + bd.tiers.brute_cap_side[3] + 1)
	assert_lte(30 + 2 + 1, pool, "30 + 2 brutes + 1 boss = 33")
	assert_eq(pool, 41, "today: max_wave_size 30 + 1 + 10")
