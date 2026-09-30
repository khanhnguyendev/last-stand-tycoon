extends GutTest

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	GameState.new_game(5)
	main.hero.input.player_control = false
	main.hero.teleport(Vector2(20, 10))  # out of the way

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _pay_full(id: String, levels := 1) -> void:
	for i in levels:
		GameState.add_gold(GameState.next_level_cost(id))
		GameState.pay_into_spot(id, GameState.next_level_cost(id))

func test_five_spots_at_layout_positions() -> void:
	assert_eq(main.world.build_spots.size(), 5)
	for id in MapLayout.SPOT_IDS:
		var s: BuildSpot = main.world.build_spots[id]
		assert_eq(Vector2(s.position.x, s.position.z), MapLayout.spot_position(id))

func test_tower_inactive_until_built() -> void:
	var t: TowerSpot = main.world.build_spots.tower_nw
	assert_false(t.attacker.enabled)
	assert_eq(t.find_children("*", "CollisionObject3D", true, false).size(), 0, "towers never collide (D-125)")
	_pay_full("tower_nw")
	assert_true(t.attacker.enabled)
	assert_eq(t.attacker.attack_range, Balance.data.build.tower_range[0])
	assert_eq(t.attacker.damage, Balance.data.build.tower_damage[0])
	assert_eq(t.attacker.interval, Balance.data.build.tower_interval)

func test_built_tower_kills_boar() -> void:
	_pay_full("tower_nw")
	var b := main.world.wave_director.debug_spawn("north")
	b.dist = 12.0  # (0,-12): 8.6 m from the tower, walks into its level-1 range
	await _ticks(60 * 5)
	assert_false(b.alive)

func test_unbuilt_tower_does_not_shoot() -> void:
	var b := main.world.wave_director.debug_spawn("north")
	b.dist = 12.0
	var hp := b.health.hp
	await _ticks(60 * 2)
	assert_eq(b.health.hp, hp)

func test_upgrade_changes_tower_stats() -> void:
	_pay_full("tower_ne", 2)
	var t: TowerSpot = main.world.build_spots.tower_ne
	assert_eq(t.attacker.damage, Balance.data.build.tower_damage[1])
	assert_eq(t.attacker.attack_range, Balance.data.build.tower_range[1])

func test_label_shows_remaining_cost_then_max() -> void:
	var t: TowerSpot = main.world.build_spots.tower_nw
	assert_eq(t.label.text, str(GameState.remaining_cost("tower_nw")))
	_pay_full("tower_nw", Balance.data.build.max_level)
	assert_eq(t.level, Balance.data.build.max_level)
	assert_eq(t.label.text, tr("MAX"))

func test_label_after_partial_payment() -> void:
	var t: TowerSpot = main.world.build_spots.tower_nw
	GameState.add_gold(1)
	GameState.pay_into_spot("tower_nw", 1)
	assert_eq(t.label.text, str(GameState.next_level_cost("tower_nw") - 1))

func test_restore_into_built_state() -> void:
	_pay_full("tower_ne", 2)
	_pay_full("fence_n")
	var d := GameState.to_dict()
	GameState.new_game(5)
	var t: TowerSpot = main.world.build_spots.tower_ne
	var f: FenceSpot = main.world.build_spots.fence_n
	assert_false(t.attacker.enabled)
	GameState.from_dict(d)
	assert_true(t.attacker.enabled)
	assert_eq(t.attacker.damage, Balance.data.build.tower_damage[1])
	assert_true(f.visual.visible)
	assert_false(f.is_rubble())

func test_fence_rubble_and_restore() -> void:
	var f: FenceSpot = main.world.build_spots.fence_n
	assert_false(f.visual.visible)
	_pay_full("fence_n")
	assert_true(f.visual.visible)
	assert_false(f.is_rubble())
	GameState.damage_fence("fence_n", 1e9)
	assert_true(f.is_rubble())
	GameState.new_game(5)  # emits state_restored
	assert_false(f.visual.visible)
	assert_false(f.is_rubble())
