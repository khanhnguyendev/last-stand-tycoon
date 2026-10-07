class_name NaiveBot
extends BotBase
## Night: defend the main lane, then the lane with most live enemies; re-decide every 1 s; never builds.

var _decide_timer := 0.0

func reset_route() -> void:
	super()
	_decide_timer = 0.0

## D-168: the Archer when offered (the strongest unaided pick, so the night-2 check is the worst case).
func choose_card(offer: Array) -> StringName:
	return &"archer" if &"archer" in offer else offer[0]

func think(delta: float) -> void:
	var pc := main.phase_controller
	if pc.failing:
		return
	if pc.phase == Phase.NIGHT:
		_night(delta)
	elif pc.phase == Phase.DAY:
		_decide_timer = 0.0
		day_think(delta)

## Goals dropped because this bot's graph has no node for them (tier 3 only; a later task removes the skips and asserts 0).
var skipped_goals := 0

func _night(delta: float) -> void:
	_decide_timer -= delta
	if _decide_timer > 0.0:
		return
	_decide_timer = 1.0
	var wd := main.world.wave_director
	var r := Balance.data.hero.attack_range
	for c in wd.enemy_candidates():
		var p: Vector3 = c.position
		if Vector2(p.x, p.z).distance_to(hero.xz()) <= r:
			return  # enemies in range: stay
	var lanes := MapLayout.lanes_for_tier(GameState.tier)
	var counts := {}
	for lane in lanes:
		counts[lane] = 0
	for b in wd.alive_enemies():
		counts[String(b.lane)] += 1
	var best := ""
	var best_n := 0
	for lane in lanes:
		if counts[lane] > best_n:
			best = lane
			best_n = counts[lane]
	if best == "":
		best = wd.upcoming_main_lane()
	if graph.nodes.has("zone_" + best):
		go_to("zone_" + best)
	else:
		skipped_goals += 1  # the tier-1 graph has no south-west zone node (Task 22 adds it)
