class_name HeroInput
extends Node
## The hero's only movement API (D-034). Joystick, WASD and bots all go through it.

var player_control := true
var _move := Vector2.ZERO

static func ensure_actions() -> void:
	var map := {
		&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
		&"move_up": [KEY_W, KEY_UP], &"move_down": [KEY_S, KEY_DOWN],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

func _ready() -> void:
	HeroInput.ensure_actions()

func set_move(v: Vector2) -> void:
	_move = v.limit_length(1.0)

func get_move() -> Vector2:
	if player_control:
		var k := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if k != Vector2.ZERO:
			return k
	return _move
