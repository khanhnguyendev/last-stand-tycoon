@tool
extends EditorScenePostImport
## D-189: strips every animation from a KayKit character import. On Knight it also saves the shared
## AnimationLibrary (only KayKitClips.NAMES) to art/characters/kaykit_anims.tres. Editor/import only (tools/ is
## excluded from export, and the release boot check never loads it).

const LIB_PATH := "res://art/characters/kaykit_anims.tres"
const CLIPS := ["Idle", "Running_A", "Walking_A", "Throw", "1H_Melee_Attack_Slice_Diagonal", "2H_Ranged_Shoot", "Hit_A", "Cheer"]

func _post_import(scene: Node) -> Object:
	var src := get_source_file()
	for p in scene.find_children("*", "AnimationPlayer", true, false):
		var ap := p as AnimationPlayer
		if src.ends_with("Knight.glb") and _library_stale(ap):
			var lib := AnimationLibrary.new()
			for name in CLIPS:
				var a := _find(ap, name)
				if a == null:
					push_error("KayKit clip missing: %s" % name)
					continue
				var copy: Animation = a.duplicate(true)
				copy.loop_mode = _loop_for(name)
				lib.add_animation(StringName(name), copy)
			var err := ResourceSaver.save(lib, LIB_PATH)
			if err != OK:
				push_error("KayKit library save failed: %s" % error_string(err))
		for lib_name in ap.get_animation_library_list():
			ap.remove_animation_library(lib_name)
	return scene

## Write the library only when it is missing or its clip set differs, so CI's --import never rewrites it (D-189).
## Delete art/characters/kaykit_anims.tres to force a rebuild after changing Knight's animation import params.
func _library_stale(ap: AnimationPlayer) -> bool:
	if not ResourceLoader.exists(LIB_PATH):
		return true
	var lib := load(LIB_PATH) as AnimationLibrary
	if lib == null:
		return true
	for name in CLIPS:
		var src := _find(ap, name)
		if not lib.has_animation(StringName(name)) or src == null:
			return true
		if not is_equal_approx(lib.get_animation(StringName(name)).length, src.length):
			return true
		if lib.get_animation(StringName(name)).loop_mode != _loop_for(name):
			return true
	return lib.get_animation_list().size() != CLIPS.size()

func _find(ap: AnimationPlayer, name: String) -> Animation:
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		if lib.has_animation(StringName(name)):
			return lib.get_animation(StringName(name))
	return null

func _loop_for(name: String) -> Animation.LoopMode:
	return Animation.LOOP_LINEAR if name in ["Idle", "Running_A", "Walking_A"] else Animation.LOOP_NONE
