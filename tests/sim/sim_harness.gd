class_name SimHarness
extends RefCounted
## Runs a real Main headless with a bot (spec 13.4). Reads results only from signals and GameState (D-113).

var parent: Node
var main: Main
var bot: BotBase
var elapsed := 0.0
var first_combat_s := -1.0
var diner_min := INF
var kills := 0
var failed := false
var guide: Guide
## E5: elapsed at the first hit on the diner while the boss is the only monster alive; at diner_fell (-1 until then).
var first_boss_hit_s := -1.0
var fell_s := -1.0

func _init(p_parent: Node) -> void:
	parent = p_parent

func start(p_seed: int, bot_script: GDScript, with_guide := false) -> void:
	main = Main.create()
	parent.add_child(main)
	if with_guide:  # S5 spec 9: Main.create() never builds a Guide; the guide sim injects one with a throwaway store
		main.settings_store = SettingsStore.with_dir("user://sim_guide")
		main.settings_store.wipe_for_tests()
		main.settings_store.load_settings()
		guide = Guide.new()
		main.add_child(guide)
		guide.setup(main)
	bot = bot_script.new()
	bot.name = "Bot"
	main.add_child(bot)
	bot.setup(main)
	if with_guide:
		bot.guide = guide
	_connect_listeners()
	main.phase_controller.start_new_game(p_seed)

## E5: start from an injected fixture (export/fixtures/<stem>.save.json). `p_seed` != 0 re-seeds the run: the lane plan is
## re-made for that seed and day (the boss stays on the last wave if the fixture's plan had it).
## A non-empty `resume_phase` overrides the fixture's ("DAY" = the real restore point of a boss night: the close-up snapshot).
## `p_mutate` (Task 23, optional): called with the decoded state dictionary before the restore, to build a scenario from a fixture.
func start_from(stem: String, bot_script: GDScript, p_seed := 0, resume_phase := "", p_mutate := Callable()) -> void:
	main = Main.create()
	parent.add_child(main)
	bot = bot_script.new()
	bot.name = "Bot"
	main.add_child(bot)
	bot.setup(main)
	_connect_listeners()
	var text := FileAccess.get_file_as_string("res://export/fixtures/%s.save.json" % stem)
	var r := SaveCodec.decode(text, GameState.SCHEMA_VERSION, Balance.data)
	assert(r.ok, "fixture %s: %s" % [stem, r.reason])
	var state: Dictionary = r.state
	if p_seed != 0:
		var had_boss: bool = not state.lane_plan.is_empty() and bool(state.lane_plan[state.lane_plan.size() - 1].get("boss", false))
		state.run_seed = p_seed
		var plan := LanePlanner.plan(p_seed, int(state.day), Balance.data.wave, int(state.tier), int(state.tier_day), Balance.data.tiers)
		state.lane_plan = LanePlanner.with_boss(plan) if had_boss else plan
	if resume_phase != "":
		state.resume_phase = resume_phase
	if p_mutate.is_valid():
		p_mutate.call(state)
	main.phase_controller.resume_from(state)

func _connect_listeners() -> void:
	EventBus.diner_damaged.connect(_on_diner_damaged)
	EventBus.enemy_killed.connect(_on_killed)
	EventBus.night_failed.connect(_on_failed)
	EventBus.diner_fell.connect(_on_fell)

## Call only from test code between ticks, never from a signal emitted under main (synchronous free).
func finish() -> void:
	for pair in [[EventBus.diner_damaged, _on_diner_damaged], [EventBus.enemy_killed, _on_killed], [EventBus.night_failed, _on_failed], [EventBus.diner_fell, _on_fell]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	if is_instance_valid(main):
		if main.get_parent() != null:
			main.get_parent().remove_child(main)  # so GUT's unfreed-children check doesn't see it
		main.free()

func tick() -> void:
	await parent.get_tree().physics_frame
	elapsed += 1.0 / Engine.physics_ticks_per_second
	if first_combat_s < 0.0 and main.phase_controller.phase == Phase.NIGHT:
		var r := Balance.data.hero.attack_range
		for c in main.world.wave_director.enemy_candidates():
			var p: Vector3 = c.position
			if Vector2(p.x, p.z).distance_to(main.hero.xz()) <= r:
				first_combat_s = elapsed
				break

func run_until(cond: Callable, max_seconds: float) -> bool:
	var n := int(max_seconds * Engine.physics_ticks_per_second)
	for i in n:
		if cond.call():
			return true
		await tick()
	return cond.call()

func run_night(max_seconds := 300.0) -> Dictionary:
	diner_min = GameState.diner_hp
	failed = false
	kills = 0
	first_boss_hit_s = -1.0
	fell_s = -1.0
	var day := GameState.day
	await run_until(func(): return failed or main.phase_controller.phase == Phase.DAY, max_seconds)
	return {
		"day": day, "failed": failed, "cleared": not failed and main.phase_controller.phase == Phase.DAY,
		"diner_frac": diner_min / Balance.data.build.diner_max_hp, "kills": kills,
	}

func run_day(max_seconds := 400.0) -> Dictionary:
	var t0 := elapsed
	await run_until(func(): return main.phase_controller.phase == Phase.NIGHT, max_seconds)
	return {"seconds": elapsed - t0, "closed": main.phase_controller.phase == Phase.NIGHT}

func _on_diner_damaged(_amount: float, hp_left: float) -> void:
	diner_min = minf(diner_min, hp_left)
	if first_boss_hit_s < 0.0 and main.world.wave_director.boss_alive() and main.world.wave_director.alive_count() == 1:
		first_boss_hit_s = elapsed

func _on_fell() -> void:
	fell_s = elapsed

func _on_killed(_i: int, _lane: StringName, _p: Vector3, _kind: StringName) -> void:
	kills += 1

func _on_failed(_day: int) -> void:
	failed = true
