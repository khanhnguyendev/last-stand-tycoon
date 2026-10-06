class_name Reactions
extends Node
## Gameplay events -> particle requests (S5 spec 5.2, D-214). Listener only: reads nothing from GameState, writes nothing,
## and emits only EventBus.fx_requested. The local reactions (boar hit, build and hero dust, hops, flashes) live next to
## their owners.

func _ready() -> void:
	# Named methods, not lambdas: a freed Reactions must disconnect itself (a capture-free lambda would outlive it).
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.steak_sold.connect(_on_steak_sold)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.build_completed.connect(_on_build_completed)
	EventBus.station_upgraded.connect(_on_station_upgraded)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.tier_paid_up.connect(_on_tier_paid_up)

func _on_enemy_killed(_spawn_index: int, _lane: StringName, pos: Vector3, _kind: StringName) -> void:
	EventBus.fx_requested.emit(&"poof", pos)

func _on_steak_sold(_count: int, _gold: int) -> void:
	EventBus.fx_requested.emit(&"coin", MapLayout.to3(MapLayout.COUNTER, 1.2))

func _on_gold_changed(_gold: int, delta: int) -> void:
	if delta > 0:
		EventBus.fx_requested.emit(&"sparkle", MapLayout.to3(MapLayout.GOLD_PILE, 0.6))

func _on_build_completed(spot_id: StringName, _level: int) -> void:
	EventBus.fx_requested.emit(&"sparkle", MapLayout.to3(MapLayout.spot_position(String(spot_id)), 1.0))

func _on_station_upgraded(id: StringName, _level: int) -> void:
	EventBus.fx_requested.emit(&"sparkle", MapLayout.to3(MapLayout.STATION_PADS[id], 1.0))

func _on_phase_changed(phase: int, _day: int) -> void:
	if phase == Phase.DAWN:
		EventBus.fx_requested.emit(&"sparkle", Vector3(0, 3.5, 0))

func _on_tier_paid_up(_next_tier: int) -> void:
	EventBus.fx_requested.emit(&"sparkle", MapLayout.to3(MapLayout.TIER_SIGN, 1.0))
