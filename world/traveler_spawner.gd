class_name TravelerSpawner
extends Node
## Day-only traveler queue (spec 8.4, D-064). Purchases are atomic at the service point (D-045).

var pool: NodePool
var _fx: FlyFx
var queue: Array = []
var leaving: Array = []
var active := false
var _timer := 0.0
var _rng: RandomNumberGenerator
## The tier whose service layout (queue slots, exit) the travelers currently use, and the phase as the bus last announced it.
var _layout_tier := 1
var _phase := Phase.NIGHT
## How many travelers the last layout switch dropped (0 at the tier-up dawn: the test reads it).
var dropped_at_switch := 0

func _ready() -> void:
	# The spawner switches its own layout (D-128: only PhaseController drives it from outside). Named methods, not lambdas.
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.tier_changed.connect(_on_tier_changed)
	EventBus.tier_reached.connect(_on_tier_reached)
	EventBus.state_restored.connect(_sync_layout)

func setup(p_pool: NodePool, fly_fx: FlyFx = null) -> void:
	pool = p_pool
	_fx = fly_fx

## D-128 interface: start spawning for today's day number.
func start() -> void:
	active = true
	_rng = Rng.stream(GameState.run_seed, GameState.day, &"travelers")
	_timer = _next_interval()

## D-128 interface: stop spawning; queued travelers walk away holding nothing (D-045).
func stop() -> void:
	active = false
	for t in queue:
		t.leave()
	leaving.append_array(queue)
	queue.clear()

func _on_phase_changed(p: int, _day: int) -> void:
	_phase = p

func _on_tier_changed(_tier: int, _paid: int, _boss: bool) -> void:
	_sync_layout()

func _on_tier_reached(_tier: int) -> void:
	_sync_layout()

## E5 tier 3 (spec 4.2): the queue slots and the exit change with the tier. A traveler alive at that moment would keep the old exit or stand off
## its slot, so none may be. At the tier-up dawn PhaseController has already recalled every traveler and the spawner stopped at close-up, so the
## count is 0 (asserted in debug); any other change (debug_set_tier by day, a load, a new game) drops the travelers, in release builds too.
## When the layout of the new tier equals the old (tiers 1 and 2) nothing happens.
func _sync_layout() -> void:
	var tier := GameState.tier
	if MapLayout.queue_slots(tier) == MapLayout.queue_slots(_layout_tier) and MapLayout.traveler_exit(tier) == MapLayout.traveler_exit(_layout_tier):
		_layout_tier = tier
		return
	_layout_tier = tier
	var alive := live_count()
	if _phase == Phase.DAWN:
		assert(alive == 0, "the service layout switches at the dawn, when no traveler is alive")
	dropped_at_switch = alive
	clear_queue()

## Travelers alive: queued, walking out, or still out of the pool. The tier-3 layout switch asserts this is 0 (World.rebuild_for_tier).
func live_count() -> int:
	return maxi(queue.size() + leaving.size(), pool.active().size() if pool != null else 0)

## D-128 interface: drop every traveler immediately (restore / new game).
func clear_queue() -> void:
	queue.clear()
	leaving.clear()
	pool.recall_all()

func _next_interval() -> float:
	var e := Balance.data.economy
	var base := StationEffects.traveler_interval(GameState.station_level(&"counter"), Balance.data.stations)
	return base + _rng.randf_range(-e.traveler_jitter, e.traveler_jitter)

func _physics_process(delta: float) -> void:
	var e := Balance.data.economy
	var sb := Balance.data.stations
	var counter_level := GameState.station_level(&"counter")
	if active:
		_timer -= delta
		if _timer <= 0.0:
			_timer = _next_interval()
			if queue.size() < StationEffects.queue_max(counter_level, sb):
				var t: Traveler = pool.acquire()
				t.begin(_rng.randi_range(e.traveler_want_min, e.traveler_want_max))
				queue.append(t)
	var slots := MapLayout.queue_slots(GameState.tier)  # E5 tier 3: the east side from tier 3 (spec 4.2); the same slots below
	for i in queue.size():
		(queue[i] as Traveler).set_target(slots[i])
	if active and not queue.is_empty():
		var front: Traveler = queue[0]
		if front.at_target() and GameState.counter_steaks > 0:
			front.service_timer += delta
			if front.service_timer >= StationEffects.service_time(counter_level, sb) - 1e-6:
				var sold := GameState.sell_from_counter(front.want)
				if sold > 0 and _fx != null:
					_fx.fly("coin", MapLayout.to3(MapLayout.SERVICE_POINT, 1.2), MapLayout.to3(MapLayout.GOLD_PILE, 0.3))
				queue.pop_front()
				if sold > 0:
					front.hop()  # visual only
				front.leave()
				leaving.append(front)
	for t in leaving.duplicate():
		if t.gone():
			leaving.erase(t)
			pool.release(t)
