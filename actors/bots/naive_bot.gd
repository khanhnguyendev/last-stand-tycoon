class_name NaiveBot
extends BotBase
## Night: defend the main lane, then the lane with most live enemies; re-decide every 1 s; never builds.

var _decide_timer := 0.0

func reset_route() -> void:
	super()
	_decide_timer = 0.0

func think(delta: float) -> void:
	var pc := main.phase_controller
	if pc.failing:
		return
	if pc.phase == Phase.NIGHT:
		_night(delta)
	elif pc.phase == Phase.DAY:
		_decide_timer = 0.0
		day_think(delta)

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
	var counts := {"west": 0, "north": 0, "east": 0}
	for b in wd.alive_enemies():
		counts[String(b.lane)] += 1
	var best := ""
	var best_n := 0
	for lane in LanePlanner.LANES:
		if counts[lane] > best_n:
			best = lane
			best_n = counts[lane]
	if best == "":
		best = wd.upcoming_main_lane()
	go_to("zone_" + best)
