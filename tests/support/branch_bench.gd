class_name BranchBench
extends RefCounted
## E6 Task 8 (spec 4.2, D-283, D-288): a micro-simulation of ONE lane at tier 3, for the rule "paying never makes it worse".
## Test support, not shipped. Everything fires through the REAL code: a real `Main`, the real `TowerSpot` / `Attacker` / `Projectile`,
## the real `FenceSpot`, `Boar` and `WaveDirector` (no arithmetic model of damage). Nothing in production is changed.
##
## Choices of the world (all of them, so a later reader can check the measure is not polluted):
##  - Tier 3 (`debug_set_tier(3, 1)`), the retune flag exactly as the CALLER left `Balance.data.tiers.retune_enabled`. Set it BEFORE
##    `run()`: a Longbow snapshots the flag when its level is applied (`TowerSpot._apply_level`), Spike reads it live, and `run()` creates
##    a fresh `Main` every call, so the flag in force at the start of the call is the flag of that run.
##  - ONE lane: `sw`, with `tower_sw` (the only tower that covers a single lane) and `fence_sw`, both bought to the top level through the
##    real payment API and then given the requested branch through `pay_into_branch`. Every other spot stays at level 0 (unbuilt).
##  - No hero influence: the hero is placed with the bus event `hero_place_requested` at (22, -22), the far north-east corner, 45 m from the
##    lane's spawn and 40 m from the diner. It is out of reach of every monster (attack range 4 m, monsters only walk the sw lane) and the steaks
##    drop on the sw lane, so it collects nothing; `player_control` is off so nothing moves it. No bot, no guards (GameState.guards is empty),
##    no cards, stations at level 0 and irrelevant (no travelers: the phase stays NIGHT).
##  - `phase_controller.failing = true`: the PhaseController then ignores `wave_cleared` and `diner_fell`, so the night does not run the dawn
##    (which would heal the diner and the fence before they are read) nor the fail-restore. The bench reads the state itself.
##  - The night: `wave_director.stop()` cancels the night the new game started, then `start_night(plan)` plays THREE waves with the sw lane as
##    the MAIN lane and no side lane, built from the real formulas (see `mix()`). GameState.lane_plan is set to the same plan, so Spike's
##    scaling by the night's HP multiplier (D-272.1) sees the same hp_mult the monsters have.
##  - Fixed run seed (71), day 1: the spawn offsets come from the real `spawns` stream, so two runs of one configuration are identical.
##
## Measures (all read from GameState and the live monsters, each tick):
##  - diner_lost    diner HP lost (the full diner_max_hp when the diner fell).
##  - fence_hp_left HP of fence_sw when the night ends (0 when it was destroyed).
##  - hares_in_zone distinct hares that were inside the sw attack zone (`MapLayout.zone_rect`, grown by 5 cm) at the end of any tick.
##  - clear_s       seconds from the tick of the first spawn until no monster is alive after the last wave spawned out. If the diner
##                  falls, the seconds from the first spawn to the tick it fell (the night is not cleared, so this is "time to defeat").
##  - ticks         physics ticks simulated by the whole run, from the night's start (this includes the 5 s first-wave delay).

const SEED := 71
const PARK := Vector2(22, -22)
const MAX_TICKS := 60 * 400
const LANE := "sw"
const TOWER_ID := "tower_sw"
const FENCE_ID := "fence_sw"

## The three waves of the lane type at `pressure`, from WaveMath / TierEffects, with the tier-3 hare share.
## Per wave: {boars, hares, brutes, hp_mult}.##  - boars: the non-hare part of the wave's MAIN group (`WaveMath.split(...).main - fast_main`); the group count includes its hares.
##  - hares: HARE lane: round(hare_lane_share x all the wave's hares). NEUTRAL and SIEGE lane: the MAIN group's share of the leftover:
##           round((H - round(share x H)) x fast_main / H), with H = fast_main + fast_side.
##  - brutes: SIEGE lane: brute_cap_main[3] on every wave (full ramp); 0 otherwise.
static func mix(lane_type: StringName, pressure: int) -> Array:
	var wb: WaveBalance = Balance.data.wave
	var tb: TierBalance = Balance.data.tiers
	var share := _hare_lane_share(tb)
	var out: Array = []
	for w in wb.base_counts.size():
		var sp := WaveMath.split(pressure, w, wb)
		var fast := TierEffects.fast_counts(int(sp.main), int(sp.side), tb.fast_share[3])
		var h_total := int(fast.fast_main) + int(fast.fast_side)
		var on_hare_lane := int(round(share * h_total))
		var hares := 0
		match lane_type:
			LaneCharacter.HARE:
				hares = on_hare_lane
			_:
				hares = int(round(float(h_total - on_hare_lane) * float(fast.fast_main) / float(h_total))) if h_total > 0 else 0
		out.append({
			"boars": int(sp.main) - int(fast.fast_main), "hares": hares,
			"brutes": tb.brute_cap_main[3] if lane_type == LaneCharacter.SIEGE else 0,
			"hp_mult": WaveMath.hp_mult(pressure, w, wb),
		})
	return out

## `hare_lane_share` is a Balance value from the lane-character task (spec 3.2b, 0.7). Until it exists on the TierBalance this reads the
## spec's value, so the bench is not blocked by task order; once the field exists the real one is used.
static func _hare_lane_share(tb: TierBalance) -> float:
	var v: Variant = tb.get("hare_lane_share")
	return float(v) if v != null else 0.7

static func plan_for(lane_type: StringName, pressure: int) -> Array:
	var waves: Array = []
	for m in mix(lane_type, pressure):
		waves.append({
			"main": LANE, "side": "", "main_count": int(m.boars) + int(m.hares), "side_count": 0, "hp_mult": float(m.hp_mult),
			"fast_main": int(m.hares), "fast_side": 0, "boss": false, "brute_main": int(m.brutes), "brute_side": 0,
		})
	return waves

## `overrides` (sensitivity tables only): {"longbow_brute_mult": float, "spike_pass": float}, applied in memory before the world exists and
## undone on return. `&""` as a branch = unbranched.
static func run(lane_type: StringName, tower_branch: StringName, fence_branch: StringName, pressure: int, overrides := {}) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var bb: BranchBalance = Balance.data.branches
	var saved_lb: Dictionary = bb.longbow_kind_mult_retune.duplicate()
	var saved_spike: float = bb.spike_pass_damage_retune
	if overrides.has("longbow_brute_mult"):
		bb.longbow_kind_mult_retune[&"brute"] = float(overrides.longbow_brute_mult)
	if overrides.has("spike_pass"):
		bb.spike_pass_damage_retune = float(overrides.spike_pass)
	var plan := plan_for(lane_type, pressure)

	var main := Main.create()
	tree.root.add_child(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(SEED)
	await tree.physics_frame
	main.phase_controller.wave_director.stop()
	main.phase_controller.failing = true
	GameState.debug_set_tier(3, 1)
	main.world.rebuild_for_tier()
	EventBus.hero_place_requested.emit(PARK)
	GameState.gold = 1000000
	for id in [TOWER_ID, FENCE_ID]:
		var guard := 0
		while GameState.next_level_cost(id) >= 0 and guard < 10:
			GameState.pay_into_spot(id, 1000000)
			guard += 1
	if tower_branch != &"":
		GameState.pay_into_branch(TOWER_ID, tower_branch, 1000000)
	if fence_branch != &"":
		GameState.pay_into_branch(FENCE_ID, fence_branch, 1000000)
	GameState.gold = 0
	GameState.diner_hp = Balance.data.build.diner_max_hp
	GameState.lane_plan = plan
	var diner_max: float = Balance.data.build.diner_max_hp
	var wd: WaveDirector = main.phase_controller.wave_director
	var zone := MapLayout.zone_rect(LANE).grow(0.05)
	var seen := {}
	var ticks := 0
	var first_spawn_tick := -1
	var end_tick := -1
	var fell := false
	var kills := [0]
	var on_kill := func(_i: int, _l: StringName, _p: Vector3, _k: StringName): kills[0] += 1
	EventBus.enemy_killed.connect(on_kill)
	wd.start_night(plan)
	while ticks < MAX_TICKS:
		await tree.physics_frame
		ticks += 1
		var alive := wd.alive_enemies()
		if first_spawn_tick < 0 and not alive.is_empty():
			first_spawn_tick = ticks
		for e in alive:
			var b: Boar = e
			if b.kind == &"hare" and not seen.has(b.spawn_index) and zone.has_point(Vector2(b.global_position.x, b.global_position.z)):
				seen[b.spawn_index] = true
		if GameState.diner_hp <= 0.0:
			fell = true
			end_tick = ticks
			break
		if first_spawn_tick >= 0 and wd.wave_index == plan.size() - 1 and wd.state == WaveDirector.State.IDLE and alive.is_empty():
			end_tick = ticks
			break
	var result := {
		"diner_lost": diner_max if fell else diner_max - GameState.diner_hp,
		"fence_hp_left": float(GameState.buildings[FENCE_ID].hp),
		"hares_in_zone": seen.size(),
		"clear_s": float(end_tick - first_spawn_tick) / 60.0 if end_tick >= 0 else float(MAX_TICKS) / 60.0,
		"ticks": ticks, "kills": kills[0],
	}
	EventBus.enemy_killed.disconnect(on_kill)
	wd.stop()
	tree.root.remove_child(main)
	main.free()
	bb.longbow_kind_mult_retune = saved_lb
	bb.spike_pass_damage_retune = saved_spike
	return result
