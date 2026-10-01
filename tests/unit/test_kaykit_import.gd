extends GutTest
## D-189: one shared library with the needed clips; character imports carry no clips and stay small.

const CHARS := ["Barbarian", "Knight", "Rogue", "Rogue_Hooded", "Mage"]

func test_library_has_every_clip() -> void:
	var lib: AnimationLibrary = load("res://art/characters/kaykit_anims.tres")
	for c in KayKitClips.NAMES:
		assert_true(lib.has_animation(StringName(c)), "missing clip %s" % c)
	assert_eq(lib.get_animation_list().size(), KayKitClips.NAMES.size())
	for c in KayKitClips.NAMES:
		var a := lib.get_animation(StringName(c))
		var want := Animation.LOOP_LINEAR if c in ["Idle", "Running_A", "Walking_A"] else Animation.LOOP_NONE
		assert_eq(a.loop_mode, want, "%s loop mode" % c)
		for i in a.get_track_count():
			assert_true(String(a.track_get_path(i)).begins_with(KayKitClips.SKELETON_PATH + ":"), "%s track %d path" % [c, i])

func test_character_imports_carry_no_animations() -> void:
	var lib: AnimationLibrary = load("res://art/characters/kaykit_anims.tres")
	for c in CHARS:
		var inst: Node = load("res://assets/kaykit-adventurers/Characters/gltf/%s.glb" % c).instantiate()
		var players := inst.find_children("*", "AnimationPlayer", true, false)
		for p in players:
			assert_eq((p as AnimationPlayer).get_animation_list().size(), 0, "%s still has clips" % c)
		var skel := inst.find_children("*", "Skeleton3D", true, false)
		assert_eq(skel.size(), 1, "%s has one skeleton" % c)
		var sk := inst.get_node_or_null(KayKitClips.SKELETON_PATH) as Skeleton3D
		assert_not_null(sk, c)
		if sk != null:
			for n in lib.get_animation_list():
				var a := lib.get_animation(n)
				for i in a.get_track_count():
					var bone := String(a.track_get_path(i)).get_slice(":", 1)
					assert_true(sk.find_bone(bone) > -1, "%s lacks bone %s (clip %s)" % [c, bone, n])
		inst.free()

func test_imported_character_scene_size() -> void:
	for c in CHARS:
		var imp := ConfigFile.new()
		imp.load("res://assets/kaykit-adventurers/Characters/gltf/%s.glb.import" % c)
		var dest: String = imp.get_value("remap", "path")
		var f := FileAccess.open(dest, FileAccess.READ)
		assert_not_null(f, "imported scene for %s" % c)
		assert_lt(f.get_length(), 500 * 1024, "%s imported scene < 500 KB" % c)
