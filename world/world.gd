class_name World
extends Node3D
## Builds the map in code from MapLayout (spec 3.3, 6.1). Extended by later tasks.

var lanes := {}
var diner_body: StaticBody3D

@export var enemy_pool: NodePool
@export var steak_pool: NodePool
@export var projectile_pool: NodePool
@export var wave_director: WaveDirector

func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_diner()
	_build_lanes()
	_setup_pools()
	wave_director.setup(enemy_pool, steak_pool)

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = false
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9fd3e8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)

func _build_ground() -> void:
	var size := MapLayout.BOUNDS_MAX - MapLayout.BOUNDS_MIN
	var ground := Visuals.plane(size, Visuals.COLORS.ground)
	ground.name = "Ground"
	ground.position = MapLayout.to3((MapLayout.BOUNDS_MIN + MapLayout.BOUNDS_MAX) * 0.5)
	add_child(ground)
	var road := Visuals.box(Vector3(size.x, 0.02, 2.0), Visuals.COLORS.road)
	road.name = "Road"
	road.position = Vector3(0, 0.01, MapLayout.ROAD_Z)
	add_child(road)

func _build_diner() -> void:
	diner_body = add_static_box("Diner", Vector3(8, MapLayout.DINER_HEIGHT, 8), Vector2.ZERO, Visuals.COLORS.diner)

func _build_lanes() -> void:
	for id in LanePlanner.LANES:
		var lane := Lane.new()
		lane.setup(id)
		add_child(lane)
		lanes[id] = lane

## Static collider + visual box on layer 1, standing on the ground at xz.
func add_static_box(node_name: String, size: Vector3, xz: Vector2, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	body.add_child(shape)
	var vis := Visuals.visual_root()
	var mesh := Visuals.box(size, color)
	mesh.position.y = size.y * 0.5
	vis.add_child(mesh)
	body.add_child(vis)
	body.position = MapLayout.to3(xz)
	add_child(body)
	return body

static func pool_sizes(bd: BalanceData) -> Dictionary:
	var steaks := 0
	for w in bd.wave.base_counts.size():
		steaks += WaveMath.total_count(10, w, bd.wave)  # capped counts (D-124)
	return {
		"enemy": bd.wave.max_wave_size + 10,
		"steak": int(ceil(steaks * bd.economy.steaks_per_kill * 1.2)),
		"projectile": 24,
		"fx": 32,
	}

func _setup_pools() -> void:
	var sizes := World.pool_sizes(Balance.data)
	enemy_pool.setup(func(): return Boar.new(), sizes.enemy)
	steak_pool.setup(func(): return Steak.new(), sizes.steak)
	projectile_pool.setup(func(): return Projectile.new(), sizes.projectile)
