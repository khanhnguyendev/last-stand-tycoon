class_name KayKitVisual
extends ActorVisual
## KayKit-rigged ActorVisual (S4 spec 6.1, D-189, D-190). Body/Model is a KayKit character scene, played by one
## AnimationPlayer holding the shared clip library and an AnimationTree built here in code:
##   loco (BlendSpace1D Idle/Walking_A/Running_A) -> action (OneShot, upper body only) -> react (OneShot, Hit_A)
##   -> cheer (OneShot, Cheer) -> output.
## Visual-only: uses Time for the hit cooldown, never Rng, never touches gameplay nodes.

const LIBRARY := preload("res://art/characters/kaykit_anims.tres")
const UPPER_BODY_PARTS: PackedStringArray = ["spine", "chest", "neck", "head", "arm", "hand", "shoulder", "wrist", "elbow"]

@export var role: StringName
@export var attack_clip: StringName = &"Throw"
## When false (fallback if the bone filter is not honoured), attack() only plays while nearly standing still.
@export var upper_body_attack := true
## A KayKit character scene to use instead of the Model already in the scene (subclasses set this).
@export var model_scene: PackedScene
## Hide the props under the model's BoneAttachment3D nodes (axes, shields, hats, capes), except these by name.
@export var hide_props := true
@export var shown_props: PackedStringArray = []

var anim_tree: AnimationTree
var _player: AnimationPlayer
var _last_hit_ms := -1000000000

func _ready() -> void:
	super._ready()
	if model_scene != null:
		var old := body.get_node_or_null("Model")
		if old != null:
			body.remove_child(old)
			old.queue_free()
		var m := model_scene.instantiate()
		m.name = "Model"
		body.add_child(m)
		body.move_child(m, 0)
	var model := body.get_node("Model")
	if hide_props:
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			if mi.get_parent() is BoneAttachment3D and not shown_props.has(String(mi.name)):
				(mi as Node3D).visible = false
	_build_animation(model)

func _build_animation(model: Node) -> void:
	_player = body.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _player == null:
		_player = AnimationPlayer.new()
		_player.name = "AnimationPlayer"
		body.add_child(_player)
	if not _player.has_animation_library(&""):
		_player.add_animation_library(&"", LIBRARY)
	_player.root_node = _player.get_path_to(model)  # clip tracks are "Rig/Skeleton3D:<bone>", relative to the model root
	var tree_root := _make_tree_root(model)
	anim_tree = body.get_node_or_null("AnimationTree") as AnimationTree
	if anim_tree == null:
		anim_tree = AnimationTree.new()
		anim_tree.name = "AnimationTree"
		body.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(_player)
	anim_tree.tree_root = tree_root
	anim_tree.active = true
	anim_tree.set("parameters/loco/blend_position", 0.0)

func _make_tree_root(model: Node) -> AnimationNodeBlendTree:
	var fade: float = Balance.ui.anim_blend_s
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 1.0
	for p in [[&"Idle", 0.0], [&"Walking_A", 0.5], [&"Running_A", 1.0]]:
		var a := AnimationNodeAnimation.new()
		a.animation = p[0]
		loco.add_blend_point(a, p[1], -1, p[0])
	bt.add_node(&"loco", loco)
	var action := _one_shot(fade)
	if upper_body_attack:
		action.filter_enabled = true
		var sk := model.get_node_or_null(KayKitClips.SKELETON_PATH) as Skeleton3D
		if sk != null:
			for i in sk.get_bone_count():
				var bname := sk.get_bone_name(i)
				var lower := bname.to_lower()
				for part in UPPER_BODY_PARTS:
					if lower.contains(part):
						action.set_filter_path(NodePath("%s:%s" % [KayKitClips.SKELETON_PATH, bname]), true)
						break
		else:
			push_warning("KayKitVisual: no skeleton at %s" % KayKitClips.SKELETON_PATH)
	bt.add_node(&"action", action)
	bt.add_node(&"action_clip", _clip(attack_clip))
	bt.add_node(&"react", _one_shot(fade))
	bt.add_node(&"react_clip", _clip(&"Hit_A"))
	bt.add_node(&"cheer", _one_shot(fade))
	bt.add_node(&"cheer_clip", _clip(&"Cheer"))
	bt.connect_node(&"action", 0, &"loco")
	bt.connect_node(&"action", 1, &"action_clip")
	bt.connect_node(&"react", 0, &"action")
	bt.connect_node(&"react", 1, &"react_clip")
	bt.connect_node(&"cheer", 0, &"react")
	bt.connect_node(&"cheer", 1, &"cheer_clip")
	bt.connect_node(&"output", 0, &"cheer")
	return bt

func _one_shot(fade: float) -> AnimationNodeOneShot:
	var o := AnimationNodeOneShot.new()
	o.fadein_time = fade
	o.fadeout_time = fade
	return o

func _clip(clip: StringName) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = clip
	return a

func _fire(path: String) -> void:
	anim_tree.set(path, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _abort(path: String) -> void:
	anim_tree.set(path, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)

func set_motion(speed_frac: float) -> void:
	anim_tree.set("parameters/loco/blend_position", clampf(speed_frac, 0.0, 1.0))

func attack() -> void:
	if not upper_body_attack and float(anim_tree.get("parameters/loco/blend_position")) >= 0.1:
		return
	_fire("parameters/action/request")

func hit() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hit_ms < int(Balance.ui.hit_react_cooldown * 1000.0):
		return
	_last_hit_ms = now
	_fire("parameters/react/request")

func cheer() -> void:
	_fire("parameters/cheer/request")

func reset() -> void:
	super.reset()
	if anim_tree == null:
		return
	_abort("parameters/action/request")
	_abort("parameters/react/request")
	_abort("parameters/cheer/request")
	anim_tree.set("parameters/loco/blend_position", 0.0)
