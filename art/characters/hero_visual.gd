extends KayKitVisual
## The diner cook (S4 Task 7b, D-191): the Barbarian with an apron-white tunic (the apron atlas on Barbarian_Body only,
## the sleeves keep the cloth_blue atlas), a frying pan in the right hand and the chef hat on the head bone. KayKitVisual
## frees the Barbarian's own hat, cape, axes, shield and mug first (hide_props), then this adds the cook's props.
## Visual-only: no gameplay state, no Rng.

const PAN_SCENE := preload("res://assets/kaykit-restaurant/Assets/gltf/pan_A.gltf")
const APRON := preload("res://art/materials/kaykit-adventurers__barbarian_apron.tres")
## Pan in the right hand's slot (skeleton units; the slot's +Y runs along the forearm).
const PAN_SCALE := 0.6
const PAN_ROTATION_DEG := Vector3(90, 0, 0)
const PAN_OFFSET := Vector3(0, 0.45, 0)

func _ready() -> void:
	super._ready()
	var skeleton := body.get_node("Model").get_node_or_null(KayKitClips.SKELETON_PATH) as Skeleton3D
	if skeleton == null:
		push_warning("HeroVisual: no skeleton at %s" % KayKitClips.SKELETON_PATH)
		return
	var torso := skeleton.get_node_or_null("Barbarian_Body") as MeshInstance3D
	if torso != null:
		torso.material_override = APRON
	var pan: Node3D = PAN_SCENE.instantiate()
	pan.scale = Vector3.ONE * PAN_SCALE
	pan.rotation_degrees = PAN_ROTATION_DEG
	pan.position = PAN_OFFSET
	_attach(skeleton, &"handslot.r", pan)
	_attach(skeleton, &"head", ChefHat.build())

func _attach(skeleton: Skeleton3D, bone: StringName, node: Node3D) -> void:
	var att := BoneAttachment3D.new()
	att.name = "Cook_%s" % String(bone).replace(".", "_")
	att.bone_name = bone
	skeleton.add_child(att)
	att.add_child(node)
