class_name BotBase
extends Node
## Scripted player for sims (spec 13.3). Drives the hero only through HeroInput on a fixed graph.

var main: Main
var hero: Hero
var graph := WaypointGraph.create_default()
var goal := ""
var stuck_count := 0
var _route: Array = []
var _stuck_pos := Vector2.ZERO
var _stuck_ticks := 0

func setup(m: Main) -> void:
	main = m
	hero = m.hero
	hero.input.player_control = false
	EventBus.state_restored.connect(reset_route)
	EventBus.hero_place_requested.connect(func(_p): reset_route())

func reset_route() -> void:
	goal = ""
	_route = []
	_reset_stuck()

func go_to(node_name: String) -> void:
	if goal == node_name:
		return
	goal = node_name
	_route = graph.route_from(hero.xz(), node_name)
	_reset_stuck()

func arrived() -> bool:
	return goal != "" and _route.is_empty() and hero.xz().distance_to(graph.position_of(goal)) < 0.15

func _physics_process(delta: float) -> void:
	if main == null:
		return
	think(delta)
	_steer()

func think(_delta: float) -> void:
	pass

func day_think(_delta: float) -> void:
	go_to("sign")  # walking in arms the sign (D-121); standing there closes up

func _steer() -> void:
	var step := Balance.data.hero.move_speed / float(Engine.physics_ticks_per_second)
	while not _route.is_empty():
		var tol := step if _route.size() > 1 else 0.02
		if hero.xz().distance_to(_route[0]) <= tol:
			_route.pop_front()
		else:
			break
	if _route.is_empty():
		hero.input.set_move(Vector2.ZERO)
		_reset_stuck()
		return
	_check_stuck()
	var d: Vector2 = _route[0] - hero.xz()
	if _route.size() > 1 or d.length() > step:
		hero.input.set_move(d.normalized())
	else:
		hero.input.set_move(d / step)

func _reset_stuck() -> void:
	_stuck_ticks = 0
	_stuck_pos = hero.xz() if hero != null else Vector2.ZERO

## Moved < 0.01 m over 60 ticks while a route is pending: warn (never an error) and re-route.
func _check_stuck() -> void:
	_stuck_ticks += 1
	if _stuck_ticks < 60:
		return
	if hero.xz().distance_to(_stuck_pos) < 0.01:
		stuck_count += 1
		push_warning("BotBase stuck at %s -> %s" % [hero.xz(), goal])
		_route = graph.route_from(hero.xz(), goal)
	_reset_stuck()
