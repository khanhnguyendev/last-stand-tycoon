class_name CarryStack
extends Node3D
## Visual steak stack on the hero's back, driven by GameState.carried_steaks (D-009).

var _boxes: Array = []

func _ready() -> void:
	EventBus.stocks_changed.connect(refresh)
	EventBus.state_restored.connect(refresh)
	refresh()

func refresh() -> void:
	var n := GameState.carried_steaks
	while _boxes.size() < n:
		var m := Visuals.box(Vector3(0.35, 0.16, 0.25), Visuals.COLORS.steak)
		m.position = Vector3(0, 1.0 + _boxes.size() * 0.2, 0.5)
		add_child(m)
		_boxes.append(m)
	for i in _boxes.size():
		_boxes[i].visible = i < n

func visible_count() -> int:
	return _boxes.filter(func(b): return b.visible).size()
