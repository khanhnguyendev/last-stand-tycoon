extends GutTest

var main: Main
var pc: PhaseController
var roster: GuardRoster

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	pc = main.phase_controller
	main.hero.input.player_control = false
	pc.start_new_game(99)
	main.world.wave_director.stop()  # test setup: no scheduled waves; boars come from debug_spawn
	main.hero.teleport(Vector2(15, 8))  # hero out of every fight
	roster = main.world.guard_roster

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func test_hire_spawns_guards_at_posts() -> void:
	GameState.debug_grant_card(&"archer")
	var a: Guard = roster.guards[&"archer"]
	assert_eq(a.xz(), MapLayout.guard_post(&"archer"))
	assert_almost_eq(a.global_position.y, MapLayout.DINER_HEIGHT, 1e-4)
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	assert_eq(t.state, Guard.State.RETURNING, "a new Tank walks in from the door")
	await _ticks(60 * 8)
	assert_eq(t.state, Guard.State.POSTED)
	assert_eq(t.xz(), MapLayout.guard_post(&"tank"))

func test_upgrade_card_spawns_no_guard() -> void:
	GameState.debug_grant_card(&"move_speed")
	assert_eq(roster.guards.size(), 0)

func test_archer_is_never_targeted() -> void:
	GameState.debug_grant_card(&"archer")
	for lane in ["west", "north", "east"]:
		var b: Boar = main.world.wave_director.debug_spawn(lane)
		b.dist = b.path_length()
		b._update_position()
		assert_eq(roster.guard_target(b), {}, lane)

func test_archer_kills_a_north_boar() -> void:
	GameState.debug_grant_card(&"archer")
	var b: Boar = main.world.wave_director.debug_spawn("north")
	var killed := false
	for i in 60 * 20:
		await get_tree().physics_frame
		if not b.alive:
			killed = true
			break
	assert_true(killed, "the roof archer kills a north boar")

func test_tank_stops_a_west_boar_and_takes_damage() -> void:
	GameState.debug_grant_card(&"tank")
	await _ticks(60 * 8)
	var b: Boar = main.world.wave_director.debug_spawn("west")
	var engaged := false
	for i in 60 * 25:
		await get_tree().physics_frame
		if not b.alive:
			break
		if b.current_target.get("kind", &"") == &"guard":
			engaged = true
	assert_true(engaged, "the boar targeted the tank")
	assert_lt(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"), "the tank took hits")
	assert_lt(b.dist, b.path_length() - 1.0, "the boar never reached the diner")

func test_knockout_respawn_at_door_then_return() -> void:
	GameState.debug_grant_card(&"tank")
	await _ticks(60 * 8)
	var t: Guard = roster.guards[&"tank"]
	GameState.damage_guard(&"tank", 1e6)
	assert_eq(t.state, Guard.State.DOWN)
	assert_false(t.is_targetable())
	await _ticks(12)
	assert_false(t.visual.visible, "the knockout poof hides the guard")
	var b: Boar = main.world.wave_director.debug_spawn("west")
	b.dist = MapLayout.path_length("west") - MapLayout.TANK_POST_BACK - 1.0
	b._update_position()
	assert_eq(roster.guard_target(b), {}, "a downed tank is not a target")
	await _ticks(int(ceil(Balance.data.guards.tank.respawn_s * 60.0)) + 2 - 12)  # 12 ticks already waited above
	assert_eq(t.state, Guard.State.RETURNING)
	assert_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"))
	assert_lt(t.xz().distance_to(MapLayout.DINER_DOOR), 0.2, "respawns at the door")
	await _ticks(60 * 8)
	assert_eq(t.state, Guard.State.POSTED)
	assert_true(t.visual.visible)
	assert_almost_eq(t.visual.scale.x, 1.0, 1e-3, "the respawned tank is full size")

func test_dawn_restores_a_downed_tank() -> void:
	GameState.debug_grant_card(&"tank")
	GameState.damage_guard(&"tank", 1e6)
	EventBus.wave_cleared.emit(2)  # dawn
	var t: Guard = roster.guards[&"tank"]
	assert_eq(t.state, Guard.State.POSTED)
	assert_eq(t.xz(), MapLayout.guard_post(&"tank"))
	assert_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"))
	await _ticks(int(ceil(Balance.data.guards.tank.respawn_s * 60.0)) + 2)
	assert_eq(t.state, Guard.State.POSTED, "no respawn timer carried into the day")

func test_level_up_reconfigures() -> void:
	var ts := Balance.data.guards.tank
	GameState.debug_grant_card(&"tank")
	var t: Guard = roster.guards[&"tank"]
	assert_almost_eq(t.attacker.damage, ts.damage, 1e-5)
	GameState.debug_grant_card(&"tank")
	assert_almost_eq(t.attacker.damage, ts.damage * (1.0 + ts.damage_growth), 1e-5)
	assert_eq(float(GameState.guards[&"tank"].hp), GameState.guard_max_hp(&"tank"))
	assert_eq(roster.guards.size(), 1, "a duplicate levels up; no second tank")

func test_occluder_points_include_visible_guards() -> void:
	GameState.debug_grant_card(&"archer")
	assert_eq(roster.occluder_points().size(), 1)

func test_priority_fence_then_guard_then_diner() -> void:
	assert_eq(Array(Balance.data.wave.target_priority.kinds), [&"fence_on_lane", &"guard", &"diner"])
	GameState.debug_grant_card(&"tank")
	main.world.guard_roster.guards[&"tank"].place_at_post()  # skip the walk in from the door
	GameState.add_gold(GameState.next_level_cost("fence_w"))
	GameState.pay_into_spot("fence_w", GameState.next_level_cost("fence_w"))
	var b: Boar = main.world.wave_director.debug_spawn("west")
	b.dist = TargetProviders.fence_stop_dist(b)
	b._update_position()
	assert_eq(main.world.wave_director.providers.find_target(b).kind, &"fence_on_lane")
	GameState.damage_fence("fence_w", 1e6)
	b.dist = b.path_length() - MapLayout.TANK_POST_BACK - 1.0
	b._update_position()
	assert_eq(main.world.wave_director.providers.find_target(b).kind, &"guard")
	GameState.damage_guard(&"tank", 1e6)
	b.dist = b.path_length()
	b._update_position()
	assert_eq(main.world.wave_director.providers.find_target(b).kind, &"diner")
