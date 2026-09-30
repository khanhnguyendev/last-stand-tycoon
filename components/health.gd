class_name Health
extends Node
## Hit points for enemies. Diner and fence HP live in GameState.

signal died
signal damaged(amount: float)

var max_hp := 1.0
var hp := 1.0

func reset(max_value: float) -> void:
	max_hp = max_value
	hp = max_value

func is_alive() -> bool:
	return hp > 0.0

func damage(amount: float) -> void:
	if hp <= 0.0 or amount <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount)
	if hp <= 0.0:
		died.emit()
