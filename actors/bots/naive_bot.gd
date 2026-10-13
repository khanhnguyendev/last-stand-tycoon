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

## Goals dropped because this bot's graph has no node for them (tier 3 only; the TierBot's graph has them all, so it stays 0 there), plus a
## TierBot branch pad it waited on past its cap.
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
	var best := _pick_lane(lanes, counts, wd)
	if best == "":
		best = wd.upcoming_main_lane()
	if graph.nodes.has("zone_" + best):
		go_to("zone_" + best)
	else:
		skipped_goals += 1  # the tier-1 graph has no south-west zone node (Task 22 adds it)

## Which lane the hero goes to at a re-decision; "" when no lane has an enemy. NaiveBot: the lane with the most live enemies.
## TierBot overrides it (E6 phase 4).
func _pick_lane(lanes: Array, counts: Dictionary, _wd: WaveDirector) -> String:
	return most_enemies(lanes, counts)

## Pure: the first lane (in `lanes` order) with the strictly most enemies, "" when every count is 0.
static func most_enemies(lanes: Array, counts: Dictionary) -> String:
	var best := ""
	var best_n := 0
	for lane in lanes:
		if counts[lane] > best_n:
			best = lane
			best_n = counts[lane]
	return best

## Pure (E6 phase 4): with a non-empty lane `character`, lanes are ranked first by `breached` (enemies inside the diner's attack zone or past
## a fallen fence), and only on a tie (also all zero) by `most_enemies`. An empty character is `most_enemies` alone.
static func pick_lane(lanes: Array, counts: Dictionary, breached: Dictionary, character: Dictionary) -> String:
	if character.is_empty():
		return most_enemies(lanes, counts)
	var top := 0
	for lane in lanes:
		top = maxi(top, int(breached.get(lane, 0)))
	if top == 0:
		return most_enemies(lanes, counts)
	var tied: Array = []
	for lane in lanes:
		if int(breached.get(lane, 0)) == top:
			tied.append(lane)
	return most_enemies(tied, counts)
