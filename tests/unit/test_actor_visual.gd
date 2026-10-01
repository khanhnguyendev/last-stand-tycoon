extends GutTest
## D-190 contract: every role visual survives the full cycle headless and never touches root scale/visible.

const HERO := "res://art/characters/hero_visual.tscn"
const ARCHER := "res://art/characters/archer_visual.tscn"
const TANK := "res://art/characters/tank_visual.tscn"
const TRAVELER := "res://art/characters/traveler_visual.tscn"
const BOAR := "res://art/boar/boar_visual.tscn"
const ROLE_SCENES := [HERO, ARCHER, TANK, TRAVELER, BOAR]  # Task 9 appends its scenes here
const BASE := "res://art/characters/kaykit_character.tscn"

func _cycle(v: ActorVisual) -> void:
	v.reset()
	v.set_motion(1.0)
	v.face(Vector3(1, 0, 0))
	v.attack()
	v.hit()
	v.set_flash(true)
	v.set_flash(false)
	v.cheer()
	v.die()
	v.reset()

func test_base_contract_on_kaykit_base() -> void:
	var v: ActorVisual = load(BASE).instantiate()
	add_child_autofree(v)
	v.scale = Vector3(0.5, 0.5, 0.5)
	v.visible = false
	_cycle(v)
	assert_eq(v.scale, Vector3(0.5, 0.5, 0.5), "root scale untouched")
	assert_false(v.visible, "root visible untouched")
	assert_eq(v.name, &"Visual")

func test_flash_mirrors() -> void:
	var v: ActorVisual = load(BASE).instantiate()
	add_child_autofree(v)
	v.set_flash(true)
	assert_true(v.flash_active)
	v.set_flash(false)
	assert_false(v.flash_active)

func test_face_converges() -> void:
	var v: ActorVisual = load(BASE).instantiate()
	add_child_autofree(v)
	v.face(Vector3(1, 0, 0))
	for i in 60:
		await get_tree().process_frame
	var fwd: Vector3 = v.body.global_transform.basis.z
	assert_almost_eq(fwd.x, 1.0, 0.05, "body faces +x")

func test_face_ignores_zero() -> void:
	var v: ActorVisual = load(BASE).instantiate()
	add_child_autofree(v)
	var before := v.body.rotation
	v.face(Vector3(0.001, 0, 0))
	for i in 10:
		await get_tree().process_frame
	assert_eq(v.body.rotation, before)

func test_role_scenes_cycle() -> void:
	if ROLE_SCENES.is_empty():
		pass_test("no role scenes yet")
	for p in ROLE_SCENES:
		var v: ActorVisual = load(p).instantiate()
		var holder := Node3D.new()  # one parent each: sibling "Visual" nodes would be auto-renamed
		add_child_autofree(holder)
		holder.add_child(v)
		_cycle(v)
		assert_eq(v.scale, Vector3.ONE, "%s root scale" % p)
		assert_true(v.visible, "%s root visible" % p)
		assert_eq(v.name, &"Visual", "%s root name" % p)

# --- KayKitVisual specifics ---

func test_kaykit_tree_and_filter() -> void:
	var v: KayKitVisual = load(BASE).instantiate()
	add_child_autofree(v)
	assert_not_null(v.anim_tree, "anim_tree exposed")
	assert_true(v.anim_tree.active)
	var action := (v.anim_tree.tree_root as AnimationNodeBlendTree).get_node(&"action") as AnimationNodeOneShot
	assert_true(action.filter_enabled)
	var sk := "%s:" % KayKitClips.SKELETON_PATH
	for b in ["spine", "chest", "head", "upperarm.l", "lowerarm.r", "hand.l", "wrist.r"]:
		assert_true(action.is_path_filtered(NodePath(sk + b)), "%s filtered in" % b)
	for b in ["root", "hips", "upperleg.l", "lowerleg.r", "foot.l", "toes.r"]:
		assert_false(action.is_path_filtered(NodePath(sk + b)), "%s filtered out" % b)

func _manual_visual() -> KayKitVisual:
	var v: KayKitVisual = load(BASE).instantiate()
	add_child_autofree(v)
	v.anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	v.set_motion(1.0)
	return v

func test_kaykit_upper_body_filter_keeps_legs() -> void:
	var a := _manual_visual()
	var b := _manual_visual()
	b.attack()
	for i in 3:  # the first advance consumes the one-shot request, the rest play it
		a.anim_tree.advance(0.1)
		b.anim_tree.advance(0.1)
	var ska := a.body.get_node("Model/Rig/Skeleton3D") as Skeleton3D
	var skb := b.body.get_node("Model/Rig/Skeleton3D") as Skeleton3D
	for bone in ["hips", "upperleg.l"]:
		var i := ska.find_bone(bone)
		assert_lt(ska.get_bone_pose_rotation(i).angle_to(skb.get_bone_pose_rotation(i)), 1e-3, "%s unchanged by attack" % bone)
	var arm := ska.find_bone("upperarm.r")
	assert_gt(ska.get_bone_pose_rotation(arm).angle_to(skb.get_bone_pose_rotation(arm)), 0.1, "arm throws")

func test_kaykit_motion_blend_clamped() -> void:
	var v: KayKitVisual = load(BASE).instantiate()
	add_child_autofree(v)
	v.set_motion(3.0)
	assert_eq(v.anim_tree.get("parameters/loco/blend_position"), 1.0)
	v.set_motion(-1.0)
	assert_eq(v.anim_tree.get("parameters/loco/blend_position"), 0.0)

func test_kaykit_props_hidden_and_clips_resolve() -> void:
	var v: KayKitVisual = load(BASE).instantiate()
	add_child_autofree(v)
	var model := v.body.get_node("Model")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		assert_false(mi.get_parent() is BoneAttachment3D, "%s prop freed" % mi.name)
	assert_eq(model.find_children("*", "BoneAttachment3D", true, false).size(), 0, "empty attachments freed")
	var ap := v.body.get_node("AnimationPlayer") as AnimationPlayer
	var anim := ap.get_animation(&"Running_A")
	var t := anim.find_track(NodePath(KayKitClips.SKELETON_PATH + ":hips"), Animation.TYPE_ROTATION_3D)
	assert_gt(t, -1)
	assert_not_null(ap.get_node_or_null(ap.root_node).get_node_or_null(KayKitClips.SKELETON_PATH), "track path resolves")

func test_kaykit_hit_cooldown() -> void:
	var v: KayKitVisual = load(BASE).instantiate()
	add_child_autofree(v)
	v.hit()
	assert_eq(v.anim_tree.get("parameters/react/request"), AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var first := v._last_hit_ms
	v.hit()
	assert_eq(v._last_hit_ms, first, "second hit inside the cooldown is ignored")
	v._last_hit_ms = first - int(Balance.ui.hit_react_cooldown * 1000.0) - 1
	v.hit()
	assert_gt(v._last_hit_ms, first - 1, "fires again after the cooldown")

func test_blob_shadow_scene() -> void:
	var s: Node3D = load("res://art/shared/blob_shadow.tscn").instantiate()
	add_child_autofree(s)
	assert_almost_eq(s.position.y, 0.04, 0.0001)
	var mi := s as MeshInstance3D
	var mat := mi.material_override as StandardMaterial3D
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_not_null(mat.albedo_texture)

# --- Hero visual (S4 Task 7b, D-191) ---

func _hero_visual() -> KayKitVisual:
	var v: KayKitVisual = load(HERO).instantiate()
	add_child_autofree(v)
	return v

func _baked_props(v: KayKitVisual) -> Array:
	return (v.baked.mesh.get_meta("props") as Array).map(func(p): return p.name)

func test_hero_visual_is_a_cook() -> void:
	var v := _hero_visual()
	assert_eq(v.attack_clip, &"Throw")
	assert_true(v.upper_body_attack)
	var sk := v.body.get_node("Model/Rig/Skeleton3D") as Skeleton3D
	assert_eq(_baked_props(v), ["pan_A", "ChefHat"], "the pan and the hat are baked in")
	assert_eq(sk.find_children("*", "BoneAttachment3D", true, false).size(), 0, "no attachments: the props are in the mesh")
	for gone in ["Barbarian_Hat", "Barbarian_Cape", "1H_Axe", "2H_Axe", "1H_Axe_Offhand", "Barbarian_Round_Shield", "Mug",
			"Barbarian_Body", "Barbarian_ArmLeft"]:
		assert_null(sk.find_child(gone, true, false), "%s removed" % gone)
	assert_eq(v.baked.mesh.surface_get_material(0).resource_path, "res://art/materials/kaykit-adventurers__barbarian_apron.tres",
		"the whole body is on the apron atlas (D-201: white sleeves)")

func test_hero_visual_within_budget() -> void:
	var v := _hero_visual()
	var tris := AssetValidator.count_triangles(v)
	assert_lte(tris, ArtBudgets.budget_for(HERO), "hero triangles %d" % tris)

func test_chef_hat_is_one_merged_vertex_coloured_surface() -> void:
	var hat := ChefHat.build()
	add_child_autofree(hat)
	assert_eq(hat.mesh.get_surface_count(), 1)
	var mat := hat.mesh.surface_get_material(0) as StandardMaterial3D
	assert_true(mat.vertex_color_use_as_albedo)
	assert_true(mat.vertex_color_is_srgb)
	var arr := hat.mesh.surface_get_arrays(0)
	var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	assert_eq(col.size(), (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	assert_eq(col[0], Palette.color(&"apron_white"))
	assert_lt(AssetValidator.count_triangles(hat), 500)

func test_apron_atlas_whitens_only_the_torso_column() -> void:
	var apron := Image.load_from_file(ProjectSettings.globalize_path("res://art/palette/atlas/kaykit-adventurers__barbarian_apron.png"))
	var base := Image.load_from_file(ProjectSettings.globalize_path("res://art/palette/atlas/kaykit-adventurers__barbarian_texture.png"))
	apron.convert(Image.FORMAT_RGBA8)
	base.convert(Image.FORMAT_RGBA8)
	# the 512 px atlases are the 1024 px source halved: torso column x 0..127 -> 0..63, sleeve column 128..255 -> 64..127
	assert_eq(apron.get_pixel(25, 150).to_html(false), Palette.HEX[Palette.index_of(&"apron_white")], "apron torso")
	assert_eq(base.get_pixel(25, 150).to_html(false), Palette.HEX[Palette.index_of(&"cloth_blue")], "default torso column is cloth_blue")
	assert_eq(apron.get_pixel(85, 150).to_html(false), Palette.HEX[Palette.index_of(&"apron_white")], "the apron atlas is blue-free")
	assert_eq(base.get_pixel(85, 150).to_html(false), Palette.HEX[Palette.index_of(&"cloth_blue")], "sleeves are cloth_blue")
	# every pixel that differs is apron_white in the apron atlas and cloth_blue in the base atlas
	var aw := Palette.HEX[Palette.index_of(&"apron_white")]
	var cb := Palette.HEX[Palette.index_of(&"cloth_blue")]
	var bad := 0
	for y in apron.get_height():
		for x in apron.get_width():
			var pa := apron.get_pixel(x, y)
			var pb := base.get_pixel(x, y)
			if pa != pb and not (pa.to_html(false) == aw and pb.to_html(false) == cb):
				bad += 1
	assert_eq(bad, 0, "the atlases differ only where blue became apron white")

func test_hero_ring_scene() -> void:
	Balance.reset()
	var ring: MeshInstance3D = load("res://art/shared/hero_ring.tscn").instantiate()
	add_child_autofree(ring)
	var mat := ring.material_override as StandardMaterial3D
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_almost_eq(mat.albedo_color.a, Balance.ui.hero_ring_alpha, 0.0001)
	assert_eq(Color(mat.albedo_color, 1.0), Palette.color(&"warm_white"))
	assert_almost_eq(ring.position.y, 0.03, 0.0001)
	assert_almost_eq(ring.scale.y, 0.05, 0.0001)
	var t := ring.mesh as TorusMesh
	assert_almost_eq(t.inner_radius, 0.62, 0.0001)
	assert_almost_eq(t.outer_radius, 0.7, 0.0001)

# --- guards and travelers (S4 Task 8) ---

func _kaykit(path: String) -> KayKitVisual:
	var v: KayKitVisual = load(path).instantiate()
	add_child_autofree(v)
	return v

func _prop_names(v: KayKitVisual) -> Array:
	var out := _baked_props(v)
	out.sort()
	return out

func test_archer_and_tank_props_and_clips() -> void:
	var a := _kaykit(ARCHER)
	assert_eq(a.attack_clip, &"2H_Ranged_Shoot")
	assert_false(a.upper_body_attack, "the archer never moves while shooting")
	assert_eq(_prop_names(a), ["2H_Crossbow"])
	assert_eq(a.baked.mesh.surface_get_material(0).resource_path, "res://art/materials/kaykit-adventurers__rogue_texture.tres")
	var t := _kaykit(TANK)
	assert_eq(t.attack_clip, &"1H_Melee_Attack_Slice_Diagonal")
	assert_eq(_prop_names(t), ["1H_Sword", "Badge_Shield", "Knight_Helmet"])
	assert_eq(t.baked.mesh.surface_get_material(0).resource_path, "res://art/materials/kaykit-adventurers__knight_texture.tres")

func test_role_scenes_within_budget() -> void:
	for p in [ARCHER, TANK, TRAVELER]:
		var v := _kaykit(p)
		var tris := AssetValidator.count_triangles(v)
		assert_lte(tris, ArtBudgets.budget_for(p), "%s triangles %d" % [p, tris])
		assert_gt(tris, 3000, "%s is a full character" % p)

func test_role_scenes_hold_only_their_own_models() -> void:
	# A Godot inherited scene can't replace an inherited instance (it adds a sibling), so the role scenes are
	# standalone: no Barbarian is ever instanced, discarded or left as a second Model.
	var want := {ARCHER: ["Rogue_Hooded.glb"], TANK: ["Knight.glb"], TRAVELER: ["Rogue.glb"]}
	for p in want:
		var v := _kaykit(p)
		var models := []
		for c in v.body.get_children():
			if c.scene_file_path != "":
				models.append(c.scene_file_path.get_file())
		assert_eq(models, want[p], "%s models" % p)
		assert_null((load(p).instantiate() as KayKitVisual).model_scene, "%s sets no model_scene" % p)

func _atlas_names(file: String) -> Dictionary:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/palette/atlas/%s" % file))
	img.convert(Image.FORMAT_RGBA8)
	var names := {}
	var by_hex := {}
	for i in Palette.HEX.size():
		by_hex[Palette.HEX[i]] = Palette.NAMES[i]
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 1.0:
				continue
			var n: StringName = by_hex.get(c.to_html(false), &"?")
			names[n] = int(names.get(n, 0)) + 1
	return names

func test_guard_atlases_keep_the_hero_and_traveler_colours_out() -> void:
	# ART_BIBLE R2 / colour discipline: apron_white, warm_white, gold, gold_dark and traveler_* are not guard colours.
	for f in ["kaykit-adventurers__knight_texture.png", "kaykit-adventurers__rogue_texture.png"]:
		var names := _atlas_names(f)
		assert_false(names.has(&"?"), "%s is palette-only" % f)
		for n in [&"apron_white", &"warm_white", &"gold", &"gold_dark", &"traveler_grey", &"traveler_beige", &"traveler_brown"]:
			assert_false(names.has(n), "%s has no %s" % [f, n])
		assert_true(names.has(&"steel") and names.has(&"steel_dark") or names.has(&"guard_green"), "%s keeps its steel / green" % f)

func test_tank_is_steel_and_archer_is_green() -> void:
	var k := _atlas_names("kaykit-adventurers__knight_texture.png")
	assert_gt(int(k.get(&"steel", 0)) + int(k.get(&"steel_dark", 0)), 20000, "the knight reads as steel")
	var r := _atlas_names("kaykit-adventurers__rogue_texture.png")
	assert_gt(int(r.get(&"guard_green", 0)) + int(r.get(&"guard_green_dark", 0)), 5000, "the rogue keeps its guard green")

func test_traveler_visual_swaps_bodies_and_keeps_animating() -> void:
	var v := _kaykit(TRAVELER)
	var rogue := TravelerVariants.MESHES[0]
	var mage := TravelerVariants.MESHES[1]
	assert_eq(v.baked.mesh, rogue)
	TravelerVariants.apply(v, 1)  # mage, beige
	assert_eq(v.baked.mesh, mage)
	assert_eq(v.baked.skin, TravelerVariants.SKINS[1])
	assert_eq(v.baked.material_override, TravelerVariants.MATERIALS[4])
	TravelerVariants.apply(v, 2)  # rogue, brown
	assert_eq(v.baked.mesh, rogue)
	assert_eq(v.baked.material_override, TravelerVariants.MATERIALS[2])
	var player := v.body.get_node("AnimationPlayer") as AnimationPlayer
	assert_eq(player.get_node(player.root_node), v.body.get_node("Model"), "the player drives the one rig")
	assert_eq(v.body.find_children("Model*", "Node3D", false, false).size(), 1, "no hidden second model")
	assert_lte(AssetValidator.count_triangles(v), ArtBudgets.budget_for(TRAVELER), "one baked body")
	v.set_motion(0.5)
	v.face(Vector3(1, 0, 0))
	await get_tree().process_frame
	assert_eq(v.anim_tree.get("parameters/loco/blend_position"), 0.5)

# --- one draw per character (S4 Task 8b, D-201) ---

func _visible_meshes(root: Node) -> Array:
	return root.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.is_visible_in_tree())

func test_exactly_one_visible_mesh_instance_per_role_visual() -> void:
	for p in ROLE_SCENES:
		var holder := Node3D.new()
		add_child_autofree(holder)
		var v: ActorVisual = load(p).instantiate()
		holder.add_child(v)
		var meshes := _visible_meshes(v)
		assert_eq(meshes.size(), 1, "%s visible MeshInstance3D" % p)
		if meshes.size() == 1:
			var mi := meshes[0] as MeshInstance3D
			assert_eq(mi.mesh.get_surface_count(), 1, "%s surfaces" % p)
			if p == BOAR:
				continue  # the procedural Boar has no skeleton: its legs are shader-driven (D-192)
			assert_eq(mi.skeleton, NodePath(".."), "%s: the mesh is bound to its skeleton (empty draws it unskinned, in T-pose)" % p)
			assert_not_null(mi.skin, "%s skin" % p)
			assert_true(mi.get_parent() is Skeleton3D, "%s mesh sits on the skeleton" % p)
	var t := _kaykit(TRAVELER)
	for variant in 6:
		TravelerVariants.apply(t, variant)
		assert_eq(_visible_meshes(t).size(), 1, "traveler variant %d" % variant)
		assert_eq(t.find_children("*", "MeshInstance3D", true, false).size(), 1, "traveler variant %d has no hidden meshes" % variant)
