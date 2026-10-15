extends GutTest
## E8 phase 2 Task 5 (spec 4.1, 4.2; B14): the Wrecker in play: the swap rule, the banner, the bar's name, the look.
## The wave literals below are written out by hand; the swap moves a group whole (lane, count, hares, brutes).

var main: Main
var banners: Array = []

func before_each() -> void:
	Balance.reset()
	Tier4Support.open_tier4()
	banners.clear()

func after_each() -> void:
	if EventBus.banner_requested.is_connected(_on_banner):
		EventBus.banner_requested.disconnect(_on_banner)
	Balance.reset()
	GameState.new_game(1)

func _on_banner(t: String) -> void:
	banners.append(t)

## Main west 5 (2 hares, 0 brutes); side north 3 (1 hare, 2 brutes); side2 east 4 (2 hares, 1 brute).
func _wave() -> Dictionary:
	return {"main": "west", "side": "north", "side2": "east", "main_count": 5, "side_count": 3, "side2_count": 4, "hp_mult": 1.0,
		"fast_main": 2, "fast_side": 1, "fast_side2": 2, "boss": false, "brute_main": 0, "brute_side": 2, "brute_side2": 1}

# --- the swap rule --------------------------------------------------------------------------------------------

func test_a_siege_side_group_swaps_with_main_whole_on_the_last_wave_only() -> void:
	var first := _wave()
	var plan := [first, _wave()]
	var out := LanePlanner.with_boss(plan, {"siege": "north", "hare": "west"})
	assert_eq(out[0], first, "an earlier wave is untouched")
	var w: Dictionary = out[1]
	assert_true(w.boss)
	assert_eq([w.main, w.main_count, w.fast_main, w.brute_main], ["north", 3, 1, 2], "the siege group is main now")
	assert_eq([w.side, w.side_count, w.fast_side, w.brute_side], ["west", 5, 2, 0], "main went to the side slot")
	assert_eq([w.side2, w.side2_count, w.fast_side2, w.brute_side2], ["east", 4, 2, 1], "side2 is as it was")
	assert_eq(LaneCharacter.brute_lane(w), "north")
	assert_false(plan[1].boss, "with_boss returns a copy")
	assert_eq(plan[1].main, "west")

func test_a_siege_side2_group_swaps_with_main() -> void:
	var w: Dictionary = LanePlanner.with_boss([_wave()], {"siege": "east", "hare": "sw"})[0]
	assert_eq([w.main, w.main_count, w.fast_main, w.brute_main], ["east", 4, 2, 1])
	assert_eq([w.side2, w.side2_count, w.fast_side2, w.brute_side2], ["west", 5, 2, 0])
	assert_eq([w.side, w.side_count, w.fast_side, w.brute_side], ["north", 3, 1, 2], "side is as it was")
	assert_eq(LaneCharacter.brute_lane(w), "east")

func test_a_siege_lane_already_main_swaps_nothing() -> void:
	var want := _wave()
	want.boss = true
	assert_eq(LanePlanner.with_boss([_wave()], {"siege": "west", "hare": "north"})[0], want)

func test_no_character_swaps_nothing_and_a_two_group_wave_swaps_main_and_side() -> void:
	var want := _wave()
	want.boss = true
	assert_eq(LanePlanner.with_boss([_wave()])[0], want, "no character: today's with_boss")
	var two := {"main": "west", "side": "north", "main_count": 5, "side_count": 3, "hp_mult": 1.0, "fast_main": 2, "fast_side": 1,
		"boss": false, "brute_main": 0, "brute_side": 2}
	var w: Dictionary = LanePlanner.with_boss([two], {"siege": "north", "hare": "west"})[0]
	assert_eq([w.main, w.main_count, w.fast_main, w.brute_main, w.side, w.side_count, w.fast_side, w.brute_side],
		["north", 3, 1, 2, "west", 5, 2, 0], "a two-group wave swaps main and side")
	assert_false(w.has("side2"))
	var lone := {"main": "west", "side": "north", "main_count": 5, "side_count": 3, "hp_mult": 1.0, "boss": false}
	assert_eq(LanePlanner.with_boss([lone], {"siege": "east", "hare": "sw"})[0].main, "west", "a siege lane with no group here: no swap")

func test_the_swap_is_deterministic_and_touches_only_the_last_wave() -> void:
	var tb := Balance.data.tiers
	for s in [1, 2, 3, 4, 5, 6, 7, 8]:
		var c := LaneCharacter.for_run(s)
		var p := LaneCharacter.apply(LanePlanner.plan(s, 20, Balance.data.wave, 3, 8, tb), c, tb)
		assert_eq(LanePlanner.with_boss(p, c), LanePlanner.with_boss(p, c), "seed %d: deterministic" % s)
		assert_eq(LanePlanner.with_boss(p, c).slice(0, -1), p.slice(0, -1), "seed %d: only the last wave changes" % s)

## The boss night on a tier-3 run whose tier 4 is open: the boss and the siege brutes share a lane, whichever lane the siege is.
func test_brute_lane_of_the_boss_wave_is_the_siege_lane_on_a_tier_3_boss_night() -> void:
	var swapped := 0
	for seed in [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]:
		Balance.reset()
		Tier4Support.open_tier4()
		GameState.new_game(seed)
		GameState.day = 9
		GameState.debug_set_tier(3, 8)
		GameState.lane_plan = GameState._plan_today()
		var before_main := String(GameState.lane_plan.back().main)
		GameState.add_gold(GameState.tier_next_cost())
		assert_eq(GameState.pay_into_tier(GameState.tier_next_cost()), 3500)
		var snap := GameState.to_dict()
		assert_eq(SaveCodec.validate(snap, Balance.data), "", "seed %d: the swapped plan validates" % seed)
		var kept: Array = GameState.lane_plan.duplicate(true)
		GameState.from_dict(snap)
		assert_eq(GameState.lane_plan, kept, "seed %d: the swapped boss wave survives a reload" % seed)
		assert_true(GameState.is_boss_night(), "seed %d" % seed)
		assert_eq(TierEffects.boss_kind_for(3, Balance.data.tiers), &"wrecker")
		var last: Dictionary = GameState.lane_plan.back()
		var siege := String(GameState.lane_character().siege)
		assert_gt(int(last.get("brute_main", 0)) + int(last.get("brute_side", 0)) + int(last.get("brute_side2", 0)), 0, "seed %d: the last wave has brutes" % seed)
		assert_eq(LaneCharacter.brute_lane(last), siege, "seed %d" % seed)
		assert_eq(String(last.main), siege, "seed %d: the boss walks the siege lane" % seed)
		if before_main != siege:
			swapped += 1
	assert_gt(swapped, 0, "at least one seed really swapped")

# --- the banner, the bar, the look ----------------------------------------------------------------------------

func test_the_boss_night_banner_names_the_wrecker() -> void:
	main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	main.phase_controller.start_new_game(20260930)
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_tier(3, GameState.day)
	main.world.rebuild_for_tier()
	GameState.add_gold(3500)
	assert_eq(GameState.pay_into_tier(3500), 3500)
	banners.clear()
	EventBus.banner_requested.connect(_on_banner)
	main.phase_controller.debug_skip_to_night()
	assert_true(banners.has(tr("The Wrecker comes")), str(banners))
	assert_false(banners.has(tr("The Boar King comes")), str(banners))
	assert_false(banners.has(tr("Baron von Hop comes")), str(banners))
	var kinds := WaveSchedule.build(GameState.lane_plan.back(), Balance.data.wave, Balance.data.tiers, GameState.tier).map(func(e): return e.kind)
	assert_eq(kinds[0], &"wrecker", "the boss wave opens with the Wrecker")

func test_the_bar_names_the_wrecker_and_the_wrecker_is_a_boss() -> void:
	main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	main.phase_controller.start_new_game(20260930)
	await get_tree().process_frame
	var wd: WaveDirector = main.world.wave_director
	var w := wd.debug_spawn("north", 0.0, 1.0, &"wrecker")
	assert_true(w.is_boss)
	assert_true(wd.boss_alive())
	await get_tree().process_frame
	var bar: BossBar = w.get_node("BossBar")
	assert_true(bar.visible)
	assert_eq(bar.name_text(), tr("The Wrecker"))
	assert_eq(bar.display_name(&"wrecker"), "The Wrecker")
	assert_almost_eq(bar.fraction(), 1.0, 1e-6)
	w.take_hit(w.health.max_hp * 0.5)
	await get_tree().process_frame
	assert_almost_eq(bar.fraction(), 0.5, 1e-6)

func _count_color(kind: StringName, c: Color) -> int:
	var cols: PackedColorArray = BoarMesh.get_mesh(kind).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var n := 0
	for v in cols:
		if v.a > 0.5 and v.is_equal_approx(Color(c, 1.0)):
			n += 1
	return n

func test_the_wrecker_mesh_is_a_bigger_brute_with_stone_plates_and_does_not_read_as_the_king() -> void:
	var m := BoarMesh.get_mesh(&"wrecker")
	assert_eq(m.get_surface_count(), 1)
	assert_same(BoarMesh.get_mesh(&"wrecker"), m, "cached")
	var tris: int = (m.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	assert_lte(tris, ArtBudgets.budget_for("res://art/boar"))
	var bb := m.get_aabb()
	assert_almost_eq(bb.position.y, 0.0, 0.02, "stands on y = 0")
	assert_gt(bb.size.x, BoarMesh.get_mesh(&"brute").get_aabb().size.x * 1.3, "wider than the brute")
	assert_gt(bb.size.x, BoarMesh.get_mesh(&"boss").get_aabb().size.x, "wider than the Boar King")
	assert_lt(bb.end.y, 2.6, "under its HP bar")
	var stone := Palette.color(&"stone")
	assert_gt(_count_color(&"wrecker", stone), _count_color(&"brute", stone) + 40, "the plates and the brow: far more stone than the brute")
	assert_gt(_count_color(&"wrecker", stone), _count_color(&"boss", stone) + 40)
	# the coat is darker than the King's and no hero colour is used (R2)
	var verts_body := BoarMesh.params(&"wrecker").upper as Color
	assert_lt(verts_body.get_luminance(), (BoarMesh.params(&"boss").upper as Color).get_luminance(), "a darker coat than the King's")
	assert_eq(_count_color(&"wrecker", Palette.color(&"apron_white")), 0, "no hero white")
	assert_eq(BoarMesh.params(&"wrecker").ridge, 0, "no ink spikes: the King's silhouette is spikes, the Wrecker's is slabs")

func test_the_visual_builds_and_hops_like_a_boss() -> void:
	var v: BoarVisual = load("res://art/boar/boar_visual.tscn").instantiate()
	add_child_autofree(v)
	v.set_kind(&"wrecker")
	assert_same(v.find_children("*", "MeshInstance3D", true, false)[0].mesh, BoarMesh.get_mesh(&"wrecker"))
	assert_eq(v._hop(), Vector2(Balance.ui.boss_hop_height, Balance.ui.boss_hop_hz), "the heavy hop")
	assert_almost_eq(v._lunge_dist(), Balance.ui.boss_lunge, 1e-6)
