class_name Steak
extends Node3D
## A cartoon steak on the ground (spec 7.8). Picked up by the hero's Magnet.

func _init() -> void:
	name = "Steak"
	var v := Visuals.visual_root()
	var m := Visuals.box(Vector3(0.35, 0.18, 0.25), Visuals.COLORS.steak)
	m.position.y = 0.12
	v.add_child(m)
	add_child(v)

func place(pos: Vector3) -> void:
	position = Vector3(pos.x, 0.0, pos.z)
