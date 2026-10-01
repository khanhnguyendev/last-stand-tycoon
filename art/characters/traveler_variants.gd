class_name TravelerVariants
extends RefCounted
## The six muted traveler looks (S4 Task 8, D-191): (Rogue, Mage) x (grey, beige, brown). Variant n is
## body n % 2 and tone n % 3, so neighbours in the queue differ in both and all six combinations appear.
## Visual-only: the variant comes from the factory counter in world.gd, never from Rng or gameplay state.
## traveler_visual.tscn holds one rig; apply() gives its single baked MeshInstance3D the variant's body (a baked
## mesh and skin, D-201) and the variant's tone atlas as the material. Nothing is instanced here, and a body or
## material that is already set is not reassigned.

const BODIES: Array[StringName] = [&"rogue", &"mage"]
const TONES: Array[StringName] = [&"grey", &"beige", &"brown"]
## Indexed by body; preloaded so begin() never calls load().
const MESHES: Array[Mesh] = [
	preload("res://art/characters/baked/traveler_rogue.res"), preload("res://art/characters/baked/traveler_mage.res"),
]
const SKINS: Array[Skin] = [
	preload("res://art/characters/baked/traveler_rogue_skin.res"), preload("res://art/characters/baked/traveler_mage_skin.res"),
]
## Indexed body * 3 + tone.
const MATERIALS: Array[Material] = [
	preload("res://art/materials/traveler_rogue_grey.tres"), preload("res://art/materials/traveler_rogue_beige.tres"),
	preload("res://art/materials/traveler_rogue_brown.tres"), preload("res://art/materials/traveler_mage_grey.tres"),
	preload("res://art/materials/traveler_mage_beige.tres"), preload("res://art/materials/traveler_mage_brown.tres"),
]
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
	var baked := (visual as KayKitVisual).baked if visual is KayKitVisual else null
	if baked == null:
		return
	var b := body_index(variant)
	if baked.mesh != MESHES[b]:
		baked.mesh = MESHES[b]
		baked.skin = SKINS[b]
	var mat := MATERIALS[b * 3 + tone_index(variant)]
	if baked.material_override != mat:
		baked.material_override = mat

## "body/material path" of the shown variant.
static func signature(visual: ActorVisual) -> String:
	var baked := (visual as KayKitVisual).baked if visual is KayKitVisual else null
	if baked == null:
		return ""
	var body := MESHES.find(baked.mesh)
	if body < 0:
		return ""
	var m := baked.material_override
	return "%s/%s" % [BODIES[body], m.resource_path if m != null else ""]
