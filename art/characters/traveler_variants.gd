class_name TravelerVariants
extends RefCounted
## The six muted traveler looks (S4 Task 8, D-191): (Rogue, Mage) x (grey, beige, brown). Variant n is
## body n % 2 and tone n % 3, so neighbours in the queue differ in both and all six combinations appear.
## Visual-only: the variant comes from the factory counter in world.gd, never from Rng or gameplay state.
## traveler_visual.tscn holds both models; apply() shows one, gives it the variant's atlas material and points the
## shared AnimationPlayer at it. Nothing is instanced here.

const BODIES: Array[StringName] = [&"rogue", &"mage"]
const TONES: Array[StringName] = [&"grey", &"beige", &"brown"]
const MODEL_NODES: Array[StringName] = [&"Model", &"ModelMage"]
const MATERIAL_DIR := "res://art/materials/"

static func body_index(variant: int) -> int:
	return posmod(variant, 2)

static func tone_index(variant: int) -> int:
	return posmod(variant, 3)

static func material_path(variant: int) -> String:
	return "%straveler_%s_%s.tres" % [MATERIAL_DIR, BODIES[body_index(variant)], TONES[tone_index(variant)]]

## The variant's non-skin palette colours (R3 limits apply to these).
static func colors_of(variant: int) -> PackedColorArray:
	return PackedColorArray([Palette.color(StringName("traveler_%s" % TONES[tone_index(variant)]))])

static func apply(visual: ActorVisual, variant: int) -> void:
	var body := visual.body
	if body == null:
		return
	var chosen := body_index(variant)
	var mat := load(material_path(variant)) as Material
	for i in MODEL_NODES.size():
		var model := body.get_node_or_null(NodePath(MODEL_NODES[i])) as Node3D
		if model == null:
			continue
		model.visible = i == chosen
		if i != chosen:
			continue
		_free_props(model)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
		var player := body.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if player != null:
			var path := player.get_path_to(model)
			if player.root_node != path:
				player.root_node = path

## Travelers carry nothing: free the model's hat, cape and hand props (KayKitVisual does this for "Model" only).
static func _free_props(model: Node) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var att := mi.get_parent() as BoneAttachment3D
		if att != null:
			att.remove_child(mi)
			mi.free()
	for att in model.find_children("*", "BoneAttachment3D", true, false):
		if att.find_children("*", "MeshInstance3D", true, false).is_empty():
			att.get_parent().remove_child(att)
			att.free()

## "body/material path" of the shown model.
static func signature(visual: ActorVisual) -> String:
	for i in MODEL_NODES.size():
		var model := visual.body.get_node_or_null(NodePath(MODEL_NODES[i])) as Node3D
		if model == null or not model.visible:
			continue
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var path := ""
		if not meshes.is_empty():
			var m := (meshes[0] as MeshInstance3D).material_override
			path = m.resource_path if m != null else ""
		return "%s/%s" % [BODIES[i], path]
	return ""
