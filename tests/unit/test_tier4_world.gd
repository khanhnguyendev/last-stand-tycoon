extends GutTest
## E8 phase 2 Task 7 (spec 4.1, 4.3, 4.5): the world builds tier 4 (the back lot: two towers, four pads, two yards, the kerb and the stones),
## the reveal stages it, the bot's graph follows it. Tier 4 is opened in memory (Tier4Support): it is unreachable in play until Task 9.

var main: Main
var banners: Array = []
var sfx: Array = []
var fx: Array = []

func _on_banner(t) -> void:
	banners.append(t)

func _on_sfx(id) -> void:
	sfx.append(id)

func _on_fx(kind, pos) -> void:
	fx.append([kind, pos])

func before_each() -> void:
	Balance.reset()
	Tier4Support.open_tier4()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	await get_tree().physics_frame
	main.phase_controller.start_new_game(20260930)
	banners.clear()
	sfx.clear()
	fx.clear()
	EventBus.banner_requested.connect(_on_banner)
	EventBus.sfx_requested.connect(_on_sfx)
	EventBus.fx_requested.connect(_on_fx)

func after_each() -> void:
	EventBus.banner_requested.disconnect(_on_banner)
	EventBus.sfx_requested.disconnect(_on_sfx)
	EventBus.fx_requested.disconnect(_on_fx)
	Balance.reset()
	GameState.new_game(1)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _spread() -> float:
	return Balance.data.enemy.lateral_spread

func _reveal() -> TierReveal:
	return main.world.tier_reveal

## Straight to a tier-4 day (no reveal): the state the world follows after a load or a debug jump.
func _day_at_4() -> void:
	GameState.debug_set_tier(4, GameState.day)
	main.phase_controller.debug_skip_to_day()
	await get_tree().physics_frame

## The tier-3 day, the tier-4 sign paid, the boss night skipped: the dawn whose reveal is the tier-4 one. Nothing has run yet.
func _tier4_dawn() -> void:
	GameState.debug_set_tier(3, GameState.day)
	main.phase_controller.debug_skip_to_day()
	GameState.add_gold(5000)  # test-only setup
	GameState.pay_into_tier(GameState.tier_next_cost())
	main.phase_controller.debug_skip_to_night()
	main.phase_controller.debug_skip_to_day()

func _wait_for_steps(n: int, base: int) -> void:
	while sfx.count(&"build_done") - base < n:
		await get_tree().physics_frame

# --- the nodes at tier 4 -----------------------------------------------------

func test_tier_4_builds_the_back_lot_nodes() -> void:
	await _day_at_4()
	var w := main.world
	assert_eq(w.build_spots.size(), 11, "nine old spots and the two towers of the back lot")
	for id in MapLayout.TIER_SPOTS[4]:
		assert_true(w.build_spots.has(id), id)
		assert_true(w.build_spots[id] is TowerSpot, "%s is a tower" % id)
		assert_eq((w.build_spots[id] as Node3D).position, MapLayout.to3(MapLayout.spot_position(id)))
	assert_eq(w.branch_pads.size(), 11, "every spot has its pads")
	var pads := 0
	for id in w.branch_pads:
		pads += (w.branch_pads[id] as Array).size()
	assert_eq(pads, 22, "22 pads: 18 and the back lot's four")
	assert_eq(w.yard_ids(), ["west", "east", "front", "north", "northeast"])
	assert_eq(w.lane_ids().size(), 4, "no new lane at tier 4")
	assert_eq(w.lanes.size(), 4)
	assert_eq(w.telegraph_markers.size(), 4)
	assert_not_null(w.yard_stones)
	assert_same(w.ground.mesh, GroundArt.terrain_mesh(World.ground_rect(), MapLayout.yards_for_tier(4), MapLayout.lanes_for_tier(4), _spread()))
	var kerb := 0
	for id in MapLayout.yards_for_tier(4):
		kerb += YardStones.transforms(MapLayout.yard_rect(id), MapLayout.yard_tier(id) >= 3, _spread(), 4).size()
	assert_eq(w.yard_stones.multimesh.instance_count, kerb, "the kerb reads the tier-4 spots and pads")
	assert_eq(w.edge_stones.multimesh.instance_count, LaneStrip.edge_multimesh(MapLayout.lanes_for_tier(4), 4).instance_count)

func test_tier_3_nodes_are_what_they_were() -> void:
	GameState.debug_set_tier(3, GameState.day)
	await get_tree().physics_frame
	var w := main.world
	assert_eq(w.build_spots.size(), 9)
	assert_eq(w.branch_pads.size(), 9)
	assert_eq(w.yard_ids(), ["west", "east", "front"])
	var kerb := 0
	for id in MapLayout.yards_for_tier(3):
		kerb += YardStones.transforms(MapLayout.yard_rect(id), MapLayout.yard_tier(id) >= 3, _spread()).size()
	assert_eq(w.yard_stones.multimesh.instance_count, kerb, "the tier-3 kerb is the default-tier one")

func test_the_sign_is_gone_at_tier_4() -> void:
	await _day_at_4()
	assert_false(main.world.tier_sign.visible, "tier 4 is the top: nothing is sold")
	assert_false(main.world.tier_sign.zone.is_active() and main.world.tier_sign.state() != &"hidden")

func test_new_game_from_tier_4_removes_every_tier_4_node() -> void:
	await _day_at_4()
	var w := main.world
	assert_true(w.build_spots.has("tower_n2"))
	GameState.new_game(77)
	await get_tree().process_frame
	await get_tree().physics_frame
	for id in MapLayout.TIER_SPOTS[4]:
		assert_false(w.build_spots.has(id), "%s gone" % id)
		assert_false(w.branch_pads.has(id), "%s's pads gone" % id)
	assert_eq(w.build_spots.size(), 0 if GameState.buildings.is_empty() else MapLayout.spots_for_tier(1).size())
	assert_eq(w.branch_pads.size(), 0)
	assert_eq(w.yard_ids(), [])
	assert_null(w.yard_stones, "no yard open: no kerb")
	assert_eq(w.lanes.size(), 3)
	assert_eq(w.edge_stones.multimesh.instance_count, LaneStrip.edge_multimesh(MapLayout.lanes_for_tier(1), 3).instance_count, "the stones are the tier-1 ones")
	for n in w.get_children():
		assert_false(n is BuildSpot and (n as BuildSpot).spot_id in MapLayout.TIER_SPOTS[4], "no tier-4 spot node left in the tree")

# --- the reveal --------------------------------------------------------------

func test_the_tier_4_reveal_runs_land_tower_land_tower_and_hides_what_it_brings() -> void:
	_tier4_dawn()
	var w := main.world
	assert_eq(GameState.tier, 4)
	var reveal := _reveal()
	assert_eq(reveal.steps_left(), 4, "north lot, tower_n2, north-east lot, tower_e2: no diner, no lane character, no sign")
	assert_true(banners.has(tr("The diner grows!")))
	sfx.clear()
	fx.clear()
	var diner := (w.diner_body.get_node("Visual").get_node("DinerArt") as Node).scene_file_path
	assert_eq(diner, "res://art/env/diner_t3.tscn", "the diner is the tier-3 one throughout")
	var tier3 := MapLayout.yards_for_tier(3)
	var north_only: Array = tier3 + ["north"]
	assert_same(w.ground.mesh, GroundArt.terrain_mesh(World.ground_rect(), tier3, MapLayout.lanes_for_tier(4), _spread()), "before step 1: the tier-3 paving")
	assert_false(w.build_spots["tower_n2"].marker.visible)
	assert_false(w.build_spots["tower_e2"].marker.visible)
	var full_kerb := 0
	for id in MapLayout.yards_for_tier(4):
		full_kerb += YardStones.transforms(MapLayout.yard_rect(id), MapLayout.yard_tier(id) >= 3, _spread(), 4).size()
	var older := 0
	for id in tier3:
		older += YardStones.transforms(MapLayout.yard_rect(id), MapLayout.yard_tier(id) >= 3, _spread(), 4).size()
	assert_eq(older, w.yard_stones.multimesh.instance_count, "the stage kerb is the older yards' pieces read at tier 4 (tower_e2's gap)")
	# step 1: the north lot
	await _wait_for_steps(1, 0)
	assert_same(w.ground.mesh, GroundArt.terrain_mesh(World.ground_rect(), north_only, MapLayout.lanes_for_tier(4), _spread()))
	assert_eq(fx[0][1], MapLayout.to3(MapLayout.yard_rect("north").get_center()), "dust on the north lot")
	assert_false(w.build_spots["tower_n2"].marker.visible)
	# step 2: its tower
	await _wait_for_steps(2, 0)
	assert_true(w.build_spots["tower_n2"].marker.visible)
	assert_false(w.build_spots["tower_e2"].marker.visible)
	# step 3: the north-east lot: everything is built
	await _wait_for_steps(3, 0)
	assert_same(w.ground.mesh, GroundArt.terrain_mesh(World.ground_rect(), MapLayout.yards_for_tier(4), MapLayout.lanes_for_tier(4), _spread()))
	assert_eq(w.yard_stones.multimesh.instance_count, full_kerb, "the full kerb is back")
	assert_false(w.build_spots["tower_e2"].marker.visible)
	# step 4
	await _wait_for_steps(4, 0)
	assert_true(w.build_spots["tower_e2"].marker.visible)
	assert_eq(sfx.count(&"build_done"), 4, "one sound per step")
	assert_eq((w.diner_body.get_node("Visual").get_node("DinerArt") as Node).scene_file_path, diner, "the diner was never swapped")

func test_a_skip_applies_the_end_state() -> void:
	_tier4_dawn()
	var w := main.world
	var reveal := _reveal()
	assert_true(reveal.running())
	var full_kerb := 0
	for id in MapLayout.yards_for_tier(4):
		full_kerb += YardStones.transforms(MapLayout.yard_rect(id), MapLayout.yard_tier(id) >= 3, _spread(), 4).size()
	reveal.skip()
	assert_same(w.ground.mesh, GroundArt.terrain_mesh(World.ground_rect(), MapLayout.yards_for_tier(4), MapLayout.lanes_for_tier(4), _spread()))
	assert_eq(w.yard_stones.multimesh.instance_count, full_kerb)
	assert_eq(reveal.steps_left(), 0)

func _on_screen_all(pts: Array, xf: Transform3D, aspect: float) -> bool:
	var proj := CameraMath.projection(Balance.ui, aspect)
	for p in pts:
		if not CameraMath.on_screen(p, xf, proj):
			return false
	return true

func test_the_reveal_camera_shows_both_towers_and_both_lots_at_9_16_and_9_21() -> void:
	for aspect in [CameraMath.ASPECT, CameraMath.ASPECT_MIN]:
		var f := TierReveal.frame_for(4, Balance.ui, aspect)
		var xf := CameraMath.zoomed_transform(f.focus, Balance.ui, f.zoom)
		assert_lt(f.zoom, Balance.ui.tier_reveal_zoom - 1e-6, "aspect %.2f: the fit is found under the cap" % aspect)
		assert_true(_on_screen_all(TierReveal.subject_points(4), xf, aspect), "aspect %.2f: every subject point on screen" % aspect)
		var towers: Array = []
		for id in MapLayout.TIER_SPOTS[4]:
			towers.append(MapLayout.to3(MapLayout.spot_position(id)))
			towers.append(MapLayout.to3(MapLayout.spot_position(id), 3.0))
		assert_true(_on_screen_all(towers, xf, aspect), "aspect %.2f: both towers (ground and top) on screen" % aspect)
		var pads: Array = []
		for id in MapLayout.TIER_SPOTS[4]:
			for p in MapLayout.BRANCH_PADS[id]:
				pads.append(MapLayout.to3(p))
		assert_true(_on_screen_all(pads, xf, aspect), "aspect %.2f: and their pads" % aspect)
		gut.p("tier 4 fit at aspect %.2f: zoom %.2f focus %s" % [aspect, f.zoom, f.focus])

func test_the_held_camera_shows_both_towers_at_the_first_and_the_last_step() -> void:
	_tier4_dawn()
	var frame := TierReveal.frame_for(4, Balance.ui)
	await _wait_for_steps(1, 0)
	await get_tree().process_frame
	assert_almost_eq(main.camera_rig.zoom_now(), frame.zoom, 0.02, "at the first step the camera is at its frame")
	assert_true(_on_screen_all(TierReveal.subject_points(4), main.camera_rig.camera.global_transform, CameraMath.ASPECT), "first step: all on screen")
	await _wait_for_steps(4, 0)
	await get_tree().process_frame
	assert_almost_eq(main.camera_rig.zoom_now(), frame.zoom, 0.02, "at the last step the camera still holds")
	assert_true(_on_screen_all(TierReveal.subject_points(4), main.camera_rig.camera.global_transform, CameraMath.ASPECT), "last step: all on screen")

func test_the_tier_2_and_3_frames_are_unchanged() -> void:
	assert_eq(TierReveal.subject_points(2).size(), 4 + 4 * MapLayout.yards_for_tier(2).filter(func(i): return MapLayout.yard_tier(i) == 2).size())
	assert_gt(TierReveal.subject_points(3).size(), 8, "the diner, the front lot and the lane stretch")

# --- the bot's graph ---------------------------------------------------------

func test_the_tier_4_graphs_hold_the_back_lot_and_no_sign() -> void:
	for g in [WaypointGraph.create_for_tier(4), WaypointGraph.create_for_bot(4)]:
		for n in ["tower_n2", "tower_e2", "pad_tower_n2_a", "pad_tower_n2_b", "pad_tower_e2_a", "pad_tower_e2_b"]:
			assert_true(g.nodes.has(n), n)
		assert_false(g.nodes.has("tier_sign_4"), "tier 4 is the top: no sign node")
		for n in g.nodes.keys():
			if n != "home":
				assert_false(g.shortest("home", n).is_empty(), "home -> %s" % n)

func _node_names(g: WaypointGraph) -> Array:
	var out: Array = g.nodes.keys()
	out.sort()
	return out

func test_the_bot_capped_at_tier_3_walks_the_tier_3_graph() -> void:
	var bot := TierBot.new()
	autofree(bot)
	bot.max_tier = 3
	GameState.debug_set_tier(3, 1)
	bot._sync_graph()
	assert_false(bot.graph.nodes.has("tier_sign_4"))
	assert_false(bot.graph.nodes.has("tower_n2"))
	var want := WaypointGraph.create_for_bot(3)
	for n in want.nodes:
		assert_eq(bot.graph.nodes[n], want.nodes[n], n)
		for e in want.edges[n]:
			assert_true((bot.graph.edges[n] as Array).has(e), "edge %s-%s" % [n, e])
	assert_eq(bot.graph.nodes.size(), want.nodes.size() + 2, "plus the two station pads")

func test_an_uncapped_bot_of_a_build_without_tier_4_keeps_the_tier_3_graph() -> void:
	Balance.reset()  # tier 4 not for sale: top tier 3
	var bot := TierBot.new()
	autofree(bot)
	bot.max_tier = 5
	GameState.debug_set_tier(3, 1)
	bot._sync_graph()
	assert_false(bot.graph.nodes.has("tier_sign_4"))

func test_a_bot_that_may_buy_tier_4_has_its_sign_in_the_tier_3_graph_and_not_after() -> void:
	var bot := TierBot.new()
	autofree(bot)
	bot.max_tier = 4
	GameState.debug_set_tier(3, 1)
	bot._sync_graph()
	assert_true(bot.graph.nodes.has("tier_sign_4"))
	assert_eq(bot.graph.nodes["tier_sign_4"], MapLayout.tier_sign(4))
	for n in bot.graph.nodes.keys():
		assert_false(bot.graph.shortest(n, "tier_sign_4").is_empty(), "%s -> tier_sign_4" % n)
	GameState.debug_set_tier(4, 1)
	bot._sync_graph()
	assert_false(bot.graph.nodes.has("tier_sign_4"), "bought: no sign")
	assert_true(bot.graph.nodes.has("tower_n2"), "the graph follows tier 4, not clamped to 3")
	assert_true(bot.graph.nodes.has("pad_tower_e2_b"))
	for t in [1, 2, 3]:
		GameState.debug_set_tier(t, 1)
		bot._sync_graph()
		assert_false(bot.graph.nodes.has("tower_n2"), "tier %d" % t)

func test_the_tier_4_sign_edges_clear_the_colliders() -> void:
	var g := WaypointGraph.create_for_bot(3)
	WaypointGraph.add_tier_sign_4(g)
	var bodies := [Rect2(-4, -4, 8, 8), Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE)]
	for b in g.edges["tier_sign_4"]:
		var pa: Vector2 = g.position_of("tier_sign_4")
		var pb: Vector2 = g.position_of(b)
		for k in 101:
			var p := pa.lerp(pb, k / 100.0)
			for body in bodies:
				assert_true(Geometry.dist_point_rect(p, body) >= MapLayout.HERO_RADIUS - 0.01, "edge to %s hits a collider at %s" % [b, p])
