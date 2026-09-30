class_name World
extends Node3D
## Builds the map in code from MapLayout (spec 3.3, 6.1). Extended by later tasks.

## Ground margin past MapLayout bounds. The projection test proves it covers every camera view for
## window aspects 9:21..21:9 (CameraMath clamps beyond that) at every focus corner (D-152, D-153).
const GROUND_MARGIN := 80.0

var lanes := {}
var diner_body: StaticBody3D
var build_spots := {}
var freezer: Freezer
var counter: Counter
var gold_pile: GoldPile
var closeup_sign: CloseUpSign
var telegraph_markers := {}

@export var enemy_pool: NodePool
@export var steak_pool: NodePool
@export var projectile_pool: NodePool
@export var wave_director: WaveDirector
@export var traveler_pool: NodePool
@export var traveler_spawner: TravelerSpawner

func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_diner()
	_build_lanes()
	_setup_pools()
	wave_director.setup(enemy_pool, steak_pool)
	_build_spots()
	_build_stations()

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = false
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Visuals.COLORS.ground  # fallback: anything past the ground reads as ground (D-153)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)

## The area the single ground plane covers, in xz.
static func ground_rect() -> Rect2:
	var lo := MapLayout.BOUNDS_MIN - Vector2(GROUND_MARGIN, GROUND_MARGIN)
	var hi := MapLayout.BOUNDS_MAX + Vector2(GROUND_MARGIN, GROUND_MARGIN)
	return Rect2(lo, hi - lo)

func _build_ground() -> void:
	var rect := ground_rect()
	var ground := Visuals.plane(rect.size, Visuals.COLORS.ground)
	ground.name = "Ground"
	ground.position = MapLayout.to3(rect.get_center())
	add_child(ground)
	var road := Visuals.box(Vector3(MapLayout.BOUNDS_MAX.x - MapLayout.BOUNDS_MIN.x, 0.02, 2.0), Visuals.COLORS.road)
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

func _build_spots() -> void:
	for id in MapLayout.SPOT_IDS:
		var s: BuildSpot = TowerSpot.new() if MapLayout.spot_kind(id) == "tower" else FenceSpot.new()
		add_child(s)
		s.setup(id, self)
		build_spots[id] = s

func _build_stations() -> void:
	freezer = Freezer.new()
	add_child(freezer)
	freezer.setup(self)
	counter = Counter.new()
	add_child(counter)
	counter.setup(self)
	gold_pile = GoldPile.new()
	add_child(gold_pile)
	gold_pile.setup(self)
	traveler_pool.setup(func(): return Traveler.new(), Balance.data.economy.queue_max * 2)
	traveler_spawner.setup(traveler_pool)
	closeup_sign = CloseUpSign.new()
	add_child(closeup_sign)
	closeup_sign.setup(self)
	for id in LanePlanner.LANES:
		var m := TelegraphMarker.new()
		add_child(m)
		m.setup(id)
		telegraph_markers[id] = m

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
