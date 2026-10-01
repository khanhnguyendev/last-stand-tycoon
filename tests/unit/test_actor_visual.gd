extends GutTest
## D-190 contract: every role visual survives the full cycle headless and never touches root scale/visible.

const HERO := "res://art/characters/hero_visual.tscn"
const ROLE_SCENES := [HERO]  # Tasks 8–9 append their scenes here
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
		add_child_autofree(v)
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

func test_hero_visual_is_a_cook() -> void:
	var v := _hero_visual()
	assert_eq(v.attack_clip, &"Throw")
	assert_true(v.upper_body_attack)
	var sk := v.body.get_node("Model/Rig/Skeleton3D") as Skeleton3D
	var hat := sk.find_child("ChefHat", true, false) as MeshInstance3D
	assert_not_null(hat, "chef hat")
	assert_eq((hat.get_parent() as BoneAttachment3D).bone_name, &"head")
	var pan := sk.find_child("pan_A", true, false)
	assert_not_null(pan, "pan")
	assert_eq(((pan.get_parent() as Node3D).get_parent() as BoneAttachment3D).bone_name, &"handslot.r")
	for gone in ["Barbarian_Hat", "Barbarian_Cape", "1H_Axe", "2H_Axe", "1H_Axe_Offhand", "Barbarian_Round_Shield", "Mug"]:
		assert_null(sk.find_child(gone, true, false), "%s removed" % gone)
	var torso := sk.get_node("Barbarian_Body") as MeshInstance3D
	assert_eq(torso.material_override.resource_path, "res://art/materials/kaykit-adventurers__barbarian_apron.tres")
	assert_null((sk.get_node("Barbarian_ArmLeft") as MeshInstance3D).material_override, "sleeves keep the default atlas")

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
	var diff := 0
	for y in range(0, 128):
		for x in range(256, 512):  # the fur, belt, boots and skin columns are untouched
			if apron.get_pixel(x, y) != base.get_pixel(x, y):
				diff += 1
	assert_eq(diff, 0, "other swatches identical between the two atlases")

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
