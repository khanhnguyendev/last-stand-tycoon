class_name GuideBot
extends BotBase
## Follows only the Guide (S5 spec 9 sim): walks north while `move` shows, else to the target; stands still when no
## rule shows; takes the first offered card.

var guide: Guide
const STATION_NODES := {&"freezer": "freezer", &"counter": "counter_drop", &"gold_pile": "gold_pile", &"sign": "sign"}
## The graph node the current chase route leads to (for a Boar or a steak), and whether the last leg is already straight.
var _chase_node := ""
var _chase_straight := false
var _chasing := false

func think(_delta: float) -> void:
	if guide == null or not is_instance_valid(guide) or guide.is_queued_for_deletion():
		_stand()  # the Guide is gone (night 2 began): the sim ends there
		return
	if main.phase_controller.failing:
		return
	var r := guide.rule_id
	var chase := false
	if r == &"move":
		go_to("zone_north")
	elif r == &"":
		_stand()
	elif STATION_NODES.has(guide.target_id):
		go_to(STATION_NODES[guide.target_id])
	elif String(guide.target_id) in MapLayout.SPOT_IDS:
		go_to(String(guide.target_id))
	else:
		chase = true
		_chase(Vector2(guide.target_position.x, guide.target_position.z))
	if not chase:
		_chasing = false

## Not reset_route(): that would drop a card offer still pending at dawn.
func _stand() -> void:
	goal = ""
	_route = []
	_chasing = false

func reset_route() -> void:
	super()
	_chasing = false

## Route to the graph node nearest `p`, then walk the last leg straight to `p`. The route is rebuilt only when that nearest
## node changes (a Boar moving a metre does not rebuild it: BotBase.route_from restarts at the node nearest the hero, so a
## rebuild every metre makes the hero dither between two nodes). `_chase_target` records the node's anchor point.
func _chase(p: Vector2) -> void:
	var node := graph.nearest(p)
	if not _chasing or node != _chase_node:
		_chasing = true
		_chase_straight = false
		_chase_node = node
		goal = ""
		go_to(node)
	if not _chase_straight and (arrived() or hero.xz().distance_to(graph.position_of(goal)) < 1.0):
		_chase_straight = true
	if _chase_straight:
		_route = [p]
