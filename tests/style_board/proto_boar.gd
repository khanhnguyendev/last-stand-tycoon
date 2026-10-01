extends RefCounted
## S4 style board set E: a procedural cute-dangerous Boar built from Godot primitive meshes (no CC0 rounded animated boar exists).
## The model faces +z, stands on y = 0, is ~1.0 m tall (with the ridge) and ~1.45 m long. 26 mesh instances.
## Tree: Boar > Rig (hop / squash / lunge pivot at the feet) > Body, Head (> face parts), 4 leg pivots, Tail.
## Animations are tweens that take the boar node (the build() result); they replace each other (see _reset).
## No class_name: a -s script cannot see project class_names before the autoloads exist, so callers load() this file.

const BODY_Y := 0.47
const BODY_R := 0.5
const BODY_SCALE := Vector3(1.0, 0.75, 1.15)
const HEAD_POS := Vector3(0.0, 0.43, 0.46)
const HEAD_R := 0.3

static func _mat(color: Color, rough := 0.35, rim := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if rim:
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.4
	return m

static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE, name_ := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	if name_ != "":
		mi.name = name_
	parent.add_child(mi)
	return mi

static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s

static func _cone(bottom_r: float, top_r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = bottom_r
	c.top_radius = top_r
	c.height = h
	c.radial_segments = 12
	c.rings = 1
	return c

## One curved tusk: two stacked segments, the upper one bent further up and inward. `base` is in head space.
static func _tusk(head: Node3D, sx: float, base: Vector3, mat: Material) -> void:
	var out_deg := 70.0   # flare out
	var fwd_deg := 20.0   # lean forward
	var b1 := Basis.from_euler(Vector3(deg_to_rad(fwd_deg), 0.0, deg_to_rad(-sx * out_deg)))
	var d1: Vector3 = b1 * Vector3.UP
	var l1 := 0.28
	_mesh(head, _cone(0.09, 0.06, l1), mat, base + d1 * l1 * 0.5, Vector3(fwd_deg, 0.0, -sx * out_deg), Vector3.ONE, "Tusk1")
	var tip1 := base + d1 * l1
	var b2 := Basis.from_euler(Vector3(deg_to_rad(fwd_deg + 25.0), 0.0, deg_to_rad(-sx * (out_deg - 30.0))))
	var d2: Vector3 = b2 * Vector3.UP
	var l2 := 0.24
	_mesh(head, _cone(0.06, 0.0, l2), mat, tip1 + d2 * l2 * 0.5, Vector3(fwd_deg + 25.0, 0.0, -sx * (out_deg - 30.0)), Vector3.ONE, "Tusk2")

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Boar"
	var rig := Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var mats: Array = []   # materials the hit flash drives
	var fur := _mat(Color("7a2e22"))
	var belly := _mat(Color("a04c3a"))
	var dark := _mat(Color("2b1511"), 0.5)
	var snout_m := _mat(Color("c97a6a"), 0.3)
	var black := _mat(Color("0a0a0c"), 0.05, false)
	var white := _mat(Color("fff6e0"), 0.25)
	var ridge_m := _mat(Color("2a0c0c"), 0.4)
	var white_dot := StandardMaterial3D.new()
	white_dot.albedo_color = Color.WHITE
	white_dot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats.append_array([fur, belly, dark, snout_m, white, ridge_m])

	# body and belly
	var body := _mesh(rig, _sphere(BODY_R), fur, Vector3(0, BODY_Y, 0), Vector3.ZERO, BODY_SCALE, "Body")
	_mesh(rig, _sphere(BODY_R), belly, Vector3(0, BODY_Y - 0.09, 0.02), Vector3.ZERO, Vector3(0.9, 0.62, 1.05), "Belly")

	# ridge: a mohawk of 5 cones along the back, tallest at the shoulders, leaning back
	var rz := [0.26, 0.1, -0.08, -0.26, -0.42]
	var rh := [0.25, 0.31, 0.28, 0.23, 0.17]
	var half_z: float = BODY_R * BODY_SCALE.z
	for k in 5:
		var z: float = rz[k]
		var top: float = BODY_Y + BODY_R * BODY_SCALE.y * sqrt(maxf(0.0, 1.0 - pow(z / half_z, 2.0)))
		var h: float = rh[k]
		_mesh(rig, _cone(0.12, 0.0, h), ridge_m, Vector3(0, top - 0.03 + h * 0.5, z), Vector3(-14.0, 0, 0), Vector3.ONE, "Ridge%d" % k)

	# legs: pivots at the hips so the run cycle can swing them
	var legs := {}
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			var piv := Node3D.new()
			piv.name = "Leg%s%s" % ["R" if lx > 0 else "L", "F" if lz > 0 else "B"]
			piv.position = Vector3(lx * 0.27, 0.25, lz * 0.3)
			rig.add_child(piv)
			_mesh(piv, _cone(0.095, 0.085, 0.25), dark, Vector3(0, -0.125, 0), Vector3.ZERO, Vector3.ONE, "Leg")
			legs[piv.name] = piv

	# tail: a small curl
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, BODY_Y + 0.12, -half_z + 0.02)
	rig.add_child(tail)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.03
	torus.outer_radius = 0.075
	_mesh(tail, torus, fur, Vector3(0, 0.03, -0.04), Vector3(70.0, 0, 0), Vector3.ONE, "Curl")

	# head: big and low at the front, tilted slightly down
	var head := Node3D.new()
	head.name = "Head"
	head.position = HEAD_POS
	head.rotation_degrees.x = 6.0
	rig.add_child(head)
	_mesh(head, _sphere(HEAD_R), fur, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 0.95, 1.0), "Skull")
	_mesh(head, _cone(0.14, 0.13, 0.07), snout_m, Vector3(0, -0.07, 0.275), Vector3(90, 0, 0), Vector3.ONE, "Snout")
	for sx in [-1.0, 1.0]:
		_mesh(head, _sphere(0.022), black, Vector3(sx * 0.05, -0.05, 0.315), Vector3.ZERO, Vector3(1, 1.3, 0.7), "Nostril")
		# eyes: glossy black with a white highlight, set high and wide on the face
		_mesh(head, _sphere(0.05), black, Vector3(sx * 0.125, 0.09, 0.235), Vector3.ZERO, Vector3.ONE, "Eye")
		_mesh(head, _sphere(0.013), white_dot, Vector3(sx * 0.14, 0.11, 0.275), Vector3.ZERO, Vector3.ONE, "EyeShine")
		# angry brow: inner end low (rotation z sign follows the side), tilted up with the face
		_mesh(head, BoxMesh.new(), dark, Vector3(sx * 0.125, 0.165, 0.225), Vector3(-30.0, 0.0, sx * 24.0), Vector3(0.12, 0.035, 0.05), "Brow")
		_tusk(head, sx, Vector3(sx * 0.17, -0.05, 0.18), white)
	# ears are skipped (mesh budget); the ridge and tusks carry the silhouette
	root.set_meta("mats", mats)
	root.set_meta("legs", legs)
	root.set_meta("rig", rig)
	root.set_meta("tweens", [])
	return root

# --- animations (tweens) ----------------------------------------------------------------------

static func _reset(boar: Node3D) -> Node3D:
	for t in boar.get_meta("tweens"):
		if t is Tween and (t as Tween).is_valid():
			(t as Tween).kill()
	boar.set_meta("tweens", [])
	var rig: Node3D = boar.get_meta("rig")
	rig.position = Vector3.ZERO
	rig.scale = Vector3.ONE
	for p in boar.get_meta("legs").values():
		(p as Node3D).rotation = Vector3.ZERO
	for m in boar.get_meta("mats"):
		(m as StandardMaterial3D).emission_enabled = false
	return rig

static func _track(boar: Node3D, t: Tween) -> Tween:
	(boar.get_meta("tweens") as Array).append(t)
	return t

## Breathing: a 3% scale bob, 0.8 s loop.
static func idle(boar: Node3D) -> Tween:
	var rig := _reset(boar)
	var t := _track(boar, boar.create_tween().set_loops())
	t.tween_property(rig, "scale", Vector3.ONE * 1.03, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(rig, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return t

## Run: a 0.08 m body hop at 4 Hz (one hop per 0.25 s) and a diagonal leg swing, one swing cycle per hop pair (2 Hz).
static func run(boar: Node3D) -> Tween:
	var rig := _reset(boar)
	var hop := _track(boar, boar.create_tween().set_loops())
	hop.tween_property(rig, "position:y", 0.08, 0.125).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop.tween_property(rig, "position:y", 0.0, 0.125).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var legs: Dictionary = boar.get_meta("legs")
	var amp := 32.0
	for name_ in legs:
		var dir := 1.0 if (name_ == "LegRF" or name_ == "LegLB") else -1.0
		var leg: Node3D = legs[name_]
		var lt := _track(boar, boar.create_tween().set_loops())
		lt.tween_property(leg, "rotation_degrees:x", -dir * amp, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		lt.tween_property(leg, "rotation_degrees:x", dir * amp, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return hop

## Attack: crouch back 0.15 m over 0.25 s, then lunge forward 0.4 m, then settle.
static func attack(boar: Node3D) -> Tween:
	var rig := _reset(boar)
	var t := _track(boar, boar.create_tween())
	t.set_parallel(true)
	t.tween_property(rig, "position:z", -0.15, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(rig, "scale", Vector3(1.05, 0.88, 1.05), 0.25)
	t.chain().tween_property(rig, "position:z", 0.4, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(rig, "scale", Vector3(0.95, 1.08, 1.1), 0.1)
	t.chain().tween_property(rig, "position:z", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(rig, "scale", Vector3.ONE, 0.25)
	return t

## Hit: a 0.08 s white flash (emission) plus a squash.
static func hit(boar: Node3D) -> Tween:
	var rig := _reset(boar)
	var t := _track(boar, boar.create_tween())
	t.set_parallel(true)
	for m in boar.get_meta("mats"):
		var sm := m as StandardMaterial3D
		sm.emission_enabled = true
		sm.emission = Color.WHITE
		sm.emission_energy_multiplier = 1.5
		t.tween_property(sm, "emission", Color.BLACK, 0.08)
	rig.scale = Vector3(1.18, 0.82, 1.18)
	t.tween_property(rig, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t

## Death: squash, then pop (scale to 0 over 0.2 s).
static func death(boar: Node3D) -> Tween:
	var rig := _reset(boar)
	var t := _track(boar, boar.create_tween())
	t.tween_property(rig, "scale", Vector3(1.25, 0.55, 1.25), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(rig, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	return t

static func mesh_count(boar: Node) -> int:
	return boar.find_children("*", "MeshInstance3D", true, false).size()
