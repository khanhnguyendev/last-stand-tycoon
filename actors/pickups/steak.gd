class_name Steak
extends Node3D
## A cartoon steak on the ground (spec 7.8). Picked up by the hero's Magnet.
## It draws through the World's PickupField, one slot per pooled steak (D-201); it has no mesh of its own.

var field: PickupField
var slot := -1

func _init() -> void:
	name = "Steak"

func place(pos: Vector3) -> void:
	position = Vector3(pos.x, 0.0, pos.z)
	if field != null:
		# visual-only spin from a position hash: no rand, no gameplay state
		var yaw := fposmod(sin(pos.x * 12.9898 + pos.z * 78.233) * 43758.5453, 1.0) * TAU
		field.set_slot(slot, PickupField.slot_transform(Vector3(pos.x, 0.02, pos.z), yaw, PileMesh.steak_xf()))

func on_release() -> void:
	if field != null:
		field.clear_slot(slot)
