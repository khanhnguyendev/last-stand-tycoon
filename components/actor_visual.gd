class_name ActorVisual
extends Node3D
## The art side of an actor (S4 spec 6.1, D-190). Named "Visual" (D-016). Gameplay code owns this node's
## scale and visible; subclasses animate only `body`. Facing turns `body` toward the last face() direction.

var body: Node3D
var flash_active := false
var _face_yaw := 0.0
var _has_face := false

func _init() -> void:
	name = "Visual"

func _ready() -> void:
	if body == null:
		body = get_node_or_null("Body") as Node3D
	if body == null:
		body = Node3D.new()
		body.name = "Body"
		add_child(body)

func set_motion(_speed_frac: float) -> void:
	pass

func face(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		return
	_face_yaw = atan2(flat.x, flat.z)
	_has_face = true

func attack() -> void:
	pass

func hit() -> void:
	pass

func set_flash(on: bool) -> void:
	flash_active = on

func die() -> void:
	pass

func cheer() -> void:
	pass

func reset() -> void:
	flash_active = false
	if body != null:
		body.transform = Transform3D.IDENTITY
	_has_face = false

func _process(delta: float) -> void:
	if not _has_face or body == null:
		return
	var turn: float = Balance.ui.visual_turn_speed * delta
	body.rotation.y = rotate_toward(body.rotation.y, _face_yaw, turn)
