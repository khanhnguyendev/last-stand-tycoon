extends GutTest
## D-191: hero shoots knives, guards/towers arrows; art never changes flight (positions match the baseline path).

class FakeTarget:
	extends Node3D
	var alive := true
	var spawn_index := 1
	var generation := 1
	func take_hit(_a: float) -> void:
		pass

func test_art_kind_selects_scene() -> void:
	var p := Projectile.new()
	add_child_autofree(p)
	p.set_art(&"knife")
	assert_not_null(p.find_child("Knife", true, false))
	assert_true((p.find_child("Knife", true, false) as Node3D).visible)
	p.set_art(&"arrow")
	assert_true((p.find_child("Arrow", true, false) as Node3D).visible)
	assert_false((p.find_child("Knife", true, false) as Node3D).visible)

func _visible_arts(p: Projectile) -> int:
	var n := 0
	for c in p.find_child("Visual", false, false).get_children():
		if (c as Node3D).visible:
			n += 1
	return n

func test_kind_flips_never_instance_again() -> void:
	var p := Projectile.new()
	add_child_autofree(p)
	p.set_art(&"knife")
	var vis := p.find_child("Visual", false, false)
	var kids := vis.get_child_count()
	var knife := p.find_child("Knife", true, false)
	for i in 10:
		p.set_art(&"arrow" if i % 2 == 0 else &"knife")
		assert_eq(_visible_arts(p), 1, "exactly one art visible")
		assert_eq(vis.get_child_count(), kids, "child count never grows")
	assert_same(p.find_child("Knife", true, false), knife, "same knife instance")

func test_same_kind_keeps_the_instance() -> void:
	var p := Projectile.new()
	add_child_autofree(p)
	p.set_art(&"knife")
	var first := p.find_child("Knife", true, false)
	p.set_art(&"knife")
	assert_same(p.find_child("Knife", true, false), first, "no re-instancing for an unchanged kind")
	assert_eq(_visible_arts(p), 1)

func test_attacker_defaults_to_arrow_and_hero_to_knife() -> void:
	assert_eq(autofree(Attacker.new()).projectile_art, &"arrow")
	var hero := Hero.new()
	add_child_autofree(hero)
	assert_eq(hero.attacker.projectile_art, &"knife")

func test_art_nose_points_along_minus_z() -> void:
	for kind in [&"knife", &"arrow"]:
		var p := Projectile.new()
		add_child_autofree(p)
		p.set_art(kind)
		var mi := p.find_child(String(kind).capitalize(), true, false).find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var bb := mi.get_aabb()
		var long := (mi.global_transform * bb).size
		assert_gt(long.z, 0.45, "%s long axis lies along z" % kind)
		assert_lt(long.y, 0.2, "%s is flat in y" % kind)

func test_art_orients_to_flight_and_knife_spins() -> void:
	Balance.reset()
	var pool := NodePool.new()
	add_child_autofree(pool)
	pool.setup(func(): return Projectile.new(), 2)
	var t := FakeTarget.new()
	add_child_autofree(t)
	t.position = Vector3(10, 0, 0)
	var p: Projectile = pool.acquire()
	p.set_art(&"arrow")
	p.launch(Vector3.ZERO, t, 1, 1.0, 1.0, pool)
	p._process(0.016)
	var v := p.find_child("Visual", false, false) as Node3D
	assert_gt((-v.basis.z).dot(Vector3(10, -0.5, 0).normalized()), 0.99, "-z along the flight")
	var k: Projectile = pool.acquire()
	k.set_art(&"knife")
	k.launch(Vector3.ZERO, t, 1, 1.0, 1.0, pool)
	k._process(0.0)
	var kv := k.find_child("Visual", false, false) as Node3D
	assert_gt((-kv.basis.z).dot(Vector3(10, -0.5, 0).normalized()), 0.99, "unspun knife: -z along the flight")
	var z0 := kv.basis.z
	k._process(0.05)  # 720 deg/s * 0.05 s = 36 deg about the local X (a tumble)
	assert_almost_eq(z0.angle_to(kv.basis.z), deg_to_rad(36.0), 0.02, "the knife spins at knife_spin_deg_s about local X")
	assert_almost_eq(kv.basis.x.dot(Vector3(10, -0.5, 0).normalized().cross(Vector3.UP).normalized()), 1.0, 0.01, "X axis is the spin axis")

func test_flight_unchanged_by_art() -> void:
	Balance.reset()
	var pool := NodePool.new()
	add_child_autofree(pool)
	pool.setup(func(): return Projectile.new(), 2)
	var t := FakeTarget.new()
	add_child_autofree(t)
	t.position = Vector3(6, 0, 0)
	var ends := []
	for kind in [&"knife", &"arrow"]:
		var p: Projectile = pool.acquire()
		p.set_art(kind)
		p.launch(Vector3(0, 1, 0), t, 1, 1.0, 12.0, pool)
		for i in 10:
			p._physics_process(1.0 / 60.0)
		ends.append(p.global_position)
	assert_eq(ends[0], ends[1], "same flight for both art kinds")
	# the S1 flight math, independent of the art: 10 ticks of 12 m/s toward the aim point (target + 0.5 y)
	assert_almost_eq(ends[0], Vector3(0, 1, 0) + 2.0 * Vector3(6, -0.5, 0).normalized(), Vector3.ONE * 1e-5, "analytic flight")
