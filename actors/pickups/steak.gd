class_name Steak
extends Node3D
## A cartoon steak on the ground (spec 7.8). Picked up by the hero's Magnet.
## One MeshInstance3D per ground steak, sharing the steak mesh and material (D-201).

const SCENE := preload("res://art/pickups/steak.tscn")
var _visual: Node3D

func _init() -> void:
	name = "Steak"
	_visual = SCENE.instantiate()
	_visual.position.y = 0.02
	add_child(_visual)

func place(pos: Vector3) -> void:
	position = Vector3(pos.x, 0.0, pos.z)
	# visual-only spin from a position hash: no rand, no gameplay state
	_visual.rotation.y = fposmod(sin(pos.x * 12.9898 + pos.z * 78.233) * 43758.5453, 1.0) * TAU
