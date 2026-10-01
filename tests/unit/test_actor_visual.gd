extends GutTest
## D-190 contract: every role visual survives the full cycle headless and never touches root scale/visible.

const ROLE_SCENES := []  # Tasks 7–9 append their scenes here, e.g. "res://art/characters/hero_visual.tscn"
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
		if mi.get_parent() is BoneAttachment3D:
			assert_false((mi as Node3D).visible, "%s hidden" % mi.name)
	var ap := v.body.get_node("AnimationPlayer") as AnimationPlayer
	var anim := ap.get_animation(&"Running_A")
	var t := anim.find_track(NodePath(KayKitClips.SKELETON_PATH + ":hips"), Animation.TYPE_ROTATION_3D)
	assert_gt(t, -1)
	assert_not_null(ap.get_node_or_null(ap.root_node).get_node_or_null(KayKitClips.SKELETON_PATH), "track path resolves")

func test_kaykit_hit_cooldown() -> void:
	var v: KayKitVisual = load(BASE).instantiate()
	add_child_autofree(v)
	v.hit()
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
