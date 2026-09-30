class_name Main
extends Node3D
## Scene root (world/main.tscn, spec 3.3). Orchestrated nodes live in the scene and are wired with
## typed @export references (D-128); everything else is built in code. Extended in Tasks 13–32.

const SCENE_PATH := "res://world/main.tscn"

@export var auto_start := true
@export var world: World
@export var phase_controller: PhaseController

static func create(p_auto_start := false) -> Main:
	var m: Main = (load(SCENE_PATH) as PackedScene).instantiate()
	m.auto_start = p_auto_start
	return m

var hero: Hero
var camera_rig: CameraRig
var joystick: Joystick

func _ready() -> void:
	hero = Hero.new()
	add_child(hero)
	hero.setup(world)
	hero.teleport(MapLayout.HOME)
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.setup(hero)
	var input_layer := CanvasLayer.new()
	input_layer.name = "InputLayer"
	input_layer.layer = 5
	add_child(input_layer)
	joystick = Joystick.new()
	input_layer.add_child(joystick)
	joystick.setup(hero.input)
	if auto_start:
		phase_controller.start_new_game.call_deferred()
