extends GutTest

func test_health_dies_once() -> void:
	var h := Health.new()
	add_child_autofree(h)
	h.reset(10.0)
	watch_signals(h)
	h.damage(4.0)
	h.damage(8.0)
	h.damage(8.0)
	assert_eq(h.hp, 0.0)
	assert_false(h.is_alive())
	assert_signal_emit_count(h, "died", 1)

func test_damage_ignores_non_positive() -> void:
	var h := Health.new()
	add_child_autofree(h)
	h.reset(10.0)
	watch_signals(h)
	h.damage(0.0)
	h.damage(-5.0)
	assert_eq(h.hp, 10.0)
	assert_signal_not_emitted(h, "damaged")

func test_pool_prewarm_acquire_release() -> void:
	var pool := NodePool.new()
	add_child_autofree(pool)
	pool.setup(func(): return Node3D.new(), 2)
	assert_eq(pool.size, 2)
	var a := pool.acquire()
	var b := pool.acquire()
	assert_eq(pool.active(), [a, b])
	assert_true(a.visible)
	pool.release(a)
	assert_false(a.visible)
	assert_eq(pool.active(), [b])
	assert_eq(pool.recall_all(), 1)
	assert_eq(pool.active(), [])

func test_pool_grows_and_warns() -> void:
	var pool := NodePool.new()
	add_child_autofree(pool)
	pool.setup(func(): return Node3D.new(), 1)
	watch_signals(pool)
	pool.acquire()
	pool.acquire()
	assert_eq(pool.size, 2)
	assert_signal_emitted_with_parameters(pool, "grew", [2])

func test_pool_release_is_idempotent() -> void:
	var pool := NodePool.new()
	add_child_autofree(pool)
	pool.setup(func(): return Node3D.new(), 1)
	var a := pool.acquire()
	pool.release(a)
	pool.release(a)
	assert_eq(pool.active(), [])
	assert_eq(pool.acquire(), a)
