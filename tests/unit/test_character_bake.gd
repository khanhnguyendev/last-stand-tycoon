extends GutTest
## S4 Task 8b, D-201: the baked characters (tools/bake_characters.gd) are one surface each, their props sit where the
## unbaked BoneAttachment3D props sit, and the retargeted prop UVs keep the prop's colours.

const BAKE := preload("res://tools/bake_characters.gd")
const SKELETON := "Rig/Skeleton3D"
const SCENES := {
	"hero": "res://art/characters/hero_visual.tscn",
	"archer": "res://art/characters/archer_visual.tscn",
	"tank": "res://art/characters/tank_visual.tscn",
}
const TOLERANCE := 0.01  # 1 cm

func _mesh(role: String) -> ArrayMesh:
	return load("res://art/characters/baked/%s.res" % role) as ArrayMesh

func test_every_baked_mesh_is_one_surface_inside_the_budget() -> void:
	for role in BAKE.ROLES:
		var m := _mesh(role)
		assert_not_null(m, "%s baked mesh" % role)
		assert_eq(m.get_surface_count(), 1, "%s surfaces" % role)
		var arr := m.surface_get_arrays(0)
		var tris := (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		assert_lte(tris, ArtBudgets.budget_for("res://art/characters/%s" % role.split("_")[0]), "%s triangles %d" % [role, tris])
		var verts := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		assert_eq((arr[Mesh.ARRAY_BONES] as PackedInt32Array).size(), verts * 4, "%s bones per vertex" % role)
		assert_eq((arr[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).size(), verts * 4, "%s weights per vertex" % role)
		assert_not_null(m.surface_get_material(0), "%s material" % role)
		var skin := load("res://art/characters/baked/%s_skin.res" % role) as Skin
		assert_eq(skin.get_bind_count(), 41, "%s skin binds" % role)
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var bad := 0
		for v in verts:
			if bones[v * 4] >= skin.get_bind_count() or absf(weights[v * 4] + weights[v * 4 + 1] + weights[v * 4 + 2] + weights[v * 4 + 3] - 1.0) > 0.01:
				bad += 1
		assert_eq(bad, 0, "%s: every vertex has valid bones and weights summing to 1" % role)

func test_committed_bake_is_current() -> void:
	for role in BAKE.ROLES:
		var fresh: Dictionary = BAKE.bake_role(role)
		assert_eq(fresh.errors, [], "%s bakes cleanly" % role)
		var a := (fresh.mesh as ArrayMesh).surface_get_arrays(0)
		var b := _mesh(role).surface_get_arrays(0)
		for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_BONES, Mesh.ARRAY_INDEX]:
			assert_eq(a[k].size(), b[k].size(), "%s array %d size" % [role, k])
		assert_true((a[Mesh.ARRAY_TEX_UV] as PackedVector2Array) == (b[Mesh.ARRAY_TEX_UV] as PackedVector2Array), "%s UVs are current: rerun tools/bake_characters.gd" % role)
		assert_eq(fresh.mesh.get_meta("props"), _mesh(role).get_meta("props"), "%s prop ranges" % role)

func _cloud_of_baked(v: KayKitVisual, first: int, count: int) -> PackedVector3Array:
	var sk := v.body.get_node("Model").get_node(SKELETON) as Skeleton3D
	var arr := v.baked.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var skin := v.baked.skin
	var out := PackedVector3Array()
	for i in range(first, first + count):
		assert_eq(weights[i * 4], 1.0, "a prop vertex is weighted 100% to one bone")
		var bind := bones[i * 4]
		var bone := sk.find_bone(skin.get_bind_name(bind))
		out.append(sk.global_transform * sk.get_bone_global_pose(bone) * skin.get_bind_pose(bind) * verts[i])
	return out

func _cloud_of_unbaked(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		out.append(mi.global_transform * p)
	return out

func _aabb(cloud: PackedVector3Array) -> AABB:
	var box := AABB(cloud[0], Vector3.ZERO)
	for p in cloud:
		box = box.expand(p)
	return box

## The baked visual and the unbaked reference (the raw glb with its BoneAttachment3D props), same pose.
func _posed_pair(role: String, motion: float) -> Array:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var v: KayKitVisual = load(SCENES[role]).instantiate()
	holder.add_child(v)
	v.anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	v.set_motion(motion)
	for i in 3:
		v.anim_tree.advance(0.1)  # Idle / Running_A at 0.3 s
	var model := v.body.get_node("Model") as Node3D
	var sk := model.get_node(SKELETON) as Skeleton3D
	var ref: Node3D = BAKE.build_reference(role)
	holder.add_child(ref)
	ref.global_transform = model.global_transform
	var rsk := ref.get_node(SKELETON) as Skeleton3D
	var moved := 0
	for i in sk.get_bone_count():
		rsk.set_bone_pose_position(i, sk.get_bone_pose_position(i))
		rsk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i))
		rsk.set_bone_pose_scale(i, sk.get_bone_pose_scale(i))
		if sk.get_bone_pose_rotation(i).angle_to(sk.get_bone_rest(i).basis.get_rotation_quaternion()) > 0.05:
			moved += 1
	assert_gt(moved, 3, "%s is really posed (%d bones off rest)" % [role, moved])
	rsk.force_update_all_bone_transforms()
	await get_tree().process_frame  # the BoneAttachment3Ds follow their bones
	return [v, ref]

func _check_prop_placement(role: String, motion: float) -> void:
	var pair: Array = await _posed_pair(role, motion)
	var v: KayKitVisual = pair[0]
	var ref: Node3D = pair[1]
	var props: Array = v.baked.mesh.get_meta("props")
	assert_gt(props.size(), 0, "%s has props" % role)
	for p in props:
		var mi := ref.find_child(p.name, true, false) as MeshInstance3D
		assert_not_null(mi, "%s reference has %s" % [role, p.name])
		if mi == null:
			continue
		assert_true(mi.get_parent() is BoneAttachment3D or mi.get_parent().get_parent() is BoneAttachment3D, "%s is an attachment prop" % p.name)
		var a := _aabb(_cloud_of_baked(v, p.first, p.count))
		var b := _aabb(_cloud_of_unbaked(mi))
		var d := maxf(a.position.distance_to(b.position), a.end.distance_to(b.end))
		var dmax := maxf(maxf(absf(a.position.x - b.position.x), absf(a.position.y - b.position.y)), absf(a.position.z - b.position.z))
		dmax = maxf(dmax, maxf(maxf(absf(a.end.x - b.end.x), absf(a.end.y - b.end.y)), absf(a.end.z - b.end.z)))
		gut.p("PROP %s %s motion %.1f: AABB delta %.5f m (size %s)" % [role, p.name, motion, dmax, b.size])
		assert_lt(dmax, TOLERANCE, "%s %s at motion %.1f: skinned baked AABB vs BoneAttachment AABB (delta %.4f, corner %.4f)" % [role, p.name, motion, dmax, d])
		assert_gt(b.size.length(), 0.1, "%s is a real prop" % p.name)

func test_hero_pan_and_hat_placement_idle() -> void:
	await _check_prop_placement("hero", 0.0)

func test_hero_pan_and_hat_placement_running() -> void:
	await _check_prop_placement("hero", 1.0)

func test_archer_crossbow_placement_idle() -> void:
	await _check_prop_placement("archer", 0.0)

func test_archer_crossbow_placement_running() -> void:
	await _check_prop_placement("archer", 1.0)

func test_tank_sword_shield_helmet_placement_idle() -> void:
	await _check_prop_placement("tank", 0.0)

func test_tank_sword_shield_helmet_placement_running() -> void:
	await _check_prop_placement("tank", 1.0)

func test_prop_uvs_sample_the_colour_the_prop_had() -> void:
	for role in SCENES:
		var ref: Node3D = BAKE.build_reference(role)
		var m := _mesh(role)
		var arr := m.surface_get_arrays(0)
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var atlas := BAKE.atlas_image((m.surface_get_material(0) as BaseMaterial3D).albedo_texture.resource_path)
		for p in m.get_meta("props"):
			var mi := ref.find_child(p.name, true, false) as MeshInstance3D
			var want := BAKE.prop_colors(mi, mi.mesh.surface_get_arrays(0))
			assert_eq(want.size(), p.count)
			var wrong := 0
			for i in p.count:
				var uv := uvs[p.first + i]
				assert_true(uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0, "%s UV in range" % p.name)
				var got := BAKE.color_key(atlas.get_pixel(int(floor(uv.x * atlas.get_width())), int(floor(uv.y * atlas.get_height()))))
				if got != want[i]:
					wrong += 1
			assert_eq(wrong, 0, "%s %s: every vertex samples a texel of its original colour" % [role, p.name])
		ref.free()

func test_hero_props_are_retargeted_onto_the_apron_atlas() -> void:
	# the pan (restaurant atlas) and the hat (vertex colour) really moved; the colours are the pan's steel/stone and apron white
	var arr := _mesh("hero").surface_get_arrays(0)
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var props: Array = _mesh("hero").get_meta("props")
	var hat: Dictionary = props[1]
	assert_eq(hat.name, "ChefHat")
	var texels := {}
	for i in range(hat.first, hat.first + hat.count):
		texels[uvs[i]] = true
	assert_eq(texels.size(), 1, "a flat-white hat maps every vertex onto one apron_white texel")
	var atlas := BAKE.atlas_image("res://art/palette/atlas/kaykit-adventurers__barbarian_apron.png")
	var uv: Vector2 = texels.keys()[0]
	assert_eq(atlas.get_pixel(int(uv.x * 512.0), int(uv.y * 512.0)).to_html(false), Palette.HEX[Palette.index_of(&"apron_white")])

func test_a_colour_missing_from_the_role_atlas_fails_with_its_name() -> void:
	var cube := BoxMesh.new()
	var arr := cube.get_mesh_arrays()
	var cols := PackedColorArray()
	for i in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		cols.append(Color("ff00ff"))
	arr[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "Mystery"
	mi.mesh = mesh
	var errors: Array[String] = []
	BAKE._prop_uvs(mi, mesh.surface_get_arrays(0), "res://art/palette/atlas/kaykit-adventurers__knight_texture.png", {}, errors)
	mi.free()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "Mystery")
	assert_string_contains(errors[0], "ff00ff")
