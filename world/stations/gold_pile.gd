class_name GoldPile
extends Node3D
## Coins waiting to be collected by walking over (spec 8.5). Drawn from GameState.gold_pile.

const MAX_COINS := 30
var label: WorldLabel
var _coins: Array = []

func setup(_world: World) -> void:
	name = "GoldPile"
	position = MapLayout.to3(MapLayout.GOLD_PILE)
	for i in MAX_COINS:
		var c := Visuals.cylinder(0.18, 0.06, Visuals.COLORS.coin)
		c.position = Vector3((i % 3) * 0.38 - 0.38, 0.04 + floori(i / 3.0) * 0.07, 0)
		add_child(c)
		_coins.append(c)
	label = WorldLabel.make("")
	label.position.y = 1.6
	add_child(label)
	EventBus.stocks_changed.connect(refresh)
	EventBus.state_restored.connect(refresh)
	refresh()

func refresh() -> void:
	var n := GameState.gold_pile
	for i in _coins.size():
		_coins[i].visible = i < n
	label.text = str(n) if n > 0 else ""

func coin_count() -> int:
	return _coins.filter(func(c): return c.visible).size()
