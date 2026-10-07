class_name Reactions
extends Node
## Gameplay events -> particle requests (S5 spec 5.2, D-214). Listener only: reads nothing from GameState, writes nothing,
## and emits only EventBus.fx_requested. The local reactions (boar hit, build and hero dust, hops, flashes) live next to
## their owners.

## E5 tier 3 Task 17: a branch refund is gold coming back from a pad (the coins fly to the hero), not gold arriving at the pile,
## so it must not sparkle at the pile. Two cases, no change to the bus: (1) at DAWN no pile is ever collected, so a gain then
## is a destroyed fence's refund; (2) by day the refund's gold_changed comes right after the payment's own (negative) one in the
## same physics frame, so such a gain waits one idle for branch_refunded (fired just after) and is dropped when it names the amount.
var _phase := -1
var _spend_frame := -1
## Gains that followed a payment in the same physics frame and wait one idle for branch_refunded to claim them (a queue: two
## gains in one frame both wait). A freed node never flushes (the deferred call is dropped with it).
var _held_gains: Array[int] = []

func _ready() -> void:
	# Named methods, not lambdas: a freed Reactions must disconnect itself (a capture-free lambda would outlive it).
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.steak_sold.connect(_on_steak_sold)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.build_completed.connect(_on_build_completed)
	EventBus.station_upgraded.connect(_on_station_upgraded)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.tier_paid_up.connect(_on_tier_paid_up)
	EventBus.branch_refunded.connect(_on_branch_refunded)

func _on_enemy_killed(_spawn_index: int, _lane: StringName, pos: Vector3, _kind: StringName) -> void:
	EventBus.fx_requested.emit(&"poof", pos)

func _on_steak_sold(_count: int, _gold: int) -> void:
	EventBus.fx_requested.emit(&"coin", MapLayout.to3(MapLayout.COUNTER, 1.2))

func _on_gold_changed(_gold: int, delta: int) -> void:
	if delta < 0:
		_spend_frame = Engine.get_physics_frames()
	elif delta > 0 and _phase != Phase.DAWN:
		if _spend_frame == Engine.get_physics_frames():
			_held_gains.append(delta)
			if _held_gains.size() == 1:
				_flush_gain.call_deferred()
		else:
			_pile_sparkle()

func _flush_gain() -> void:
	var n := _held_gains.size()
	_held_gains.clear()
	for i in n:
		_pile_sparkle()

func _pile_sparkle() -> void:
	EventBus.fx_requested.emit(&"sparkle", MapLayout.to3(MapLayout.GOLD_PILE, 0.6))

func _on_branch_refunded(_spot_id: StringName, amount: int) -> void:
	var i := _held_gains.find(amount)
	if i >= 0:
		_held_gains.remove_at(i)

func _on_build_completed(spot_id: StringName, _level: int) -> void:
	EventBus.fx_requested.emit(&"sparkle", MapLayout.to3(MapLayout.spot_position(String(spot_id)), 1.0))

func _on_station_upgraded(id: StringName, _level: int) -> void:
	EventBus.fx_requested.emit(&"sparkle", MapLayout.to3(MapLayout.STATION_PADS[id], 1.0))

func _on_phase_changed(phase: int, _day: int) -> void:
	_phase = phase
	if phase == Phase.DAWN:
		EventBus.fx_requested.emit(&"sparkle", Vector3(0, 3.5, 0))

## The sparkle goes where the sign that sold `next_tier` stands (tier 2: the west yard, as before; tier 3: the front lot).
func _on_tier_paid_up(next_tier: int) -> void:
	if MapLayout.has_tier_sign(next_tier):
		EventBus.fx_requested.emit(&"sparkle", MapLayout.to3(MapLayout.tier_sign(next_tier), 1.0))
