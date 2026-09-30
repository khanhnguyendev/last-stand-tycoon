extends GutTest

class FakeTarget:
	extends Node3D
	var alive := true
	var spawn_index := 1
	var generation := 1
	var hits := 0.0
	func take_hit(a: float) -> void:
		hits += a

var pool: NodePool
var target: FakeTarget

func before_each() -> void:
	Balance.reset()
	pool = NodePool.new()
	add_child_autofree(pool)
	pool.setup(func(): return Projectile.new(), 8)
	target = FakeTarget.new()
	add_child_autofree(target)
	var hb := Balance.data.hero
	target.position = Vector3(hb.attack_range * 0.5, 0, 0)

func _attacker(moving: bool) -> Attacker:
	var hb := Balance.data.hero
	var a := Attacker.new()
	a.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(a)
	a.configure(hb.attack_damage, hb.attack_range, hb.attack_interval, hb.retarget_interval, 0.5, hb.projectile_speed)
	a.candidates = func(): return [{"position": target.global_position, "spawn_index": target.spawn_index, "ref": target}]
	a.projectile_pool = pool
	a.is_moving = func(): return moving
	return a

func _count_shots(a: Attacker, ticks: int) -> int:
	var shots := [0]
	a.fired.connect(func(_t): shots[0] += 1)
	for i in ticks:
		a._physics_process(1.0 / 60.0)
	return shots[0]

## Shots in `ticks` ticks at 60 Hz for a given effective interval (fires at t=0, then every interval).
func _expected(interval: float, ticks: int) -> int:
	return int(floor((ticks - 1) / 60.0 / interval + 1e-6)) + 1

func test_fires_immediately_then_on_interval() -> void:
	var iv := Balance.data.hero.attack_interval
	assert_eq(_count_shots(_attacker(false), 120), _expected(iv, 120))

func test_moving_mult_slows_rate() -> void:
	var iv := Balance.data.hero.attack_interval / 0.5
	assert_eq(_count_shots(_attacker(true), 120), _expected(iv, 120))

func test_no_target_out_of_range() -> void:
	target.position = Vector3(Balance.data.hero.attack_range + 5.0, 0, 0)
	assert_eq(_count_shots(_attacker(false), 60), 0)

func test_dead_target_not_shot() -> void:
	target.alive = false
	assert_eq(_count_shots(_attacker(false), 60), 0)

func test_disabled_does_not_fire() -> void:
	var a := _attacker(false)
	a.enabled = false
	assert_eq(_count_shots(a, 60), 0)

func test_target_recycled_mid_interval_is_dropped() -> void:
	var a := _attacker(false)
	a.retarget_interval = 100.0  # only the generation check can drop the target
	var shots := [0]
	a.fired.connect(func(_t): shots[0] += 1)
	a._physics_process(1.0 / 60.0)
	assert_eq(shots[0], 1)
	target.generation += 1  # pool reuse with the same spawn_index (new night)
	a.candidates = func(): return []
	for i in 60:
		a._physics_process(1.0 / 60.0)
	assert_eq(shots[0], 1, "stale target is not shot again")

func test_projectile_hits_and_releases() -> void:
	var p: Projectile = pool.acquire()
	p.launch(Vector3(0, 1, 0), target, target.spawn_index, 7.0, 14.0, pool)
	for i in 30:
		p._physics_process(1.0 / 60.0)
	assert_eq(target.hits, 7.0)
	assert_false(pool.active().has(p))

func test_projectile_drops_on_generation_change() -> void:
	var p: Projectile = pool.acquire()
	p.launch(Vector3(0, 1, 0), target, target.spawn_index, 7.0, 14.0, pool)
	target.generation += 1
	p._physics_process(1.0 / 60.0)
	assert_eq(target.hits, 0.0)
	assert_false(pool.active().has(p))
