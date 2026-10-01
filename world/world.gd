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
var fly_fx: FlyFx
var occluder_fade: OccluderFade
var guard_roster: GuardRoster
## One draw for every blob shadow (S4 D-201). Actors register their Visual with it: the hero and guards in setup(), the
## travelers in begin() (the factory below hands each one this field).
var shadow_field: ShadowField
## One draw for every ground steak (S4 Task 10b, D-201): the steak factory hands each steak this field and its slot.
var pickup_field: PickupField

@export var enemy_pool: NodePool
@export var steak_pool: NodePool
@export var projectile_pool: NodePool
@export var fx_pool: NodePool
@export var wave_director: WaveDirector
@export var traveler_pool: NodePool
@export var traveler_spawner: TravelerSpawner

## S4 D-191: the n-th traveler the pool creates gets look n % 6. Visual only: no gameplay field, no Rng.
var _traveler_count := 0

## The n-th steak the pool creates owns slot n of the pickup field (visual only).
var _steak_count := 0

func _make_steak() -> Steak:
	var s := Steak.new()
	s.field = pickup_field
	s.slot = _steak_count
	_steak_count += 1
	pickup_field.grow(_steak_count)
	return s

func _make_traveler() -> Traveler:
	var t := Traveler.new()
	t.variant = _traveler_count % 6
	t.shadow_field = shadow_field
	_traveler_count += 1
	return t

## S4 D-201: each pooled Boar registers its Visual with the shared shadow field in spawn().
func _make_boar() -> Boar:
	var b := Boar.new()
	b.shadow_field = shadow_field
	return b

func _ready() -> void:
	_build_environment()
	shadow_field = ShadowField.new()
	add_child(shadow_field)
	_build_ground()
	_build_diner()
	_build_lanes()
	_setup_pools()
	wave_director.setup(enemy_pool, steak_pool)
	_build_spots()
	_build_stations()
	guard_roster = GuardRoster.new()
	guard_roster.name = "GuardRoster"
	add_child(guard_roster)
	guard_roster.setup(self)

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
	# D-151: the diner fades while it hides the hero or a Boar from the camera.
	occluder_fade = OccluderFade.new()
	occluder_fade.name = "OccluderFade"
	diner_body.get_node("Visual").add_child(occluder_fade)
	occluder_fade.setup(
		AABB(Vector3(-MapLayout.DINER_HALF, 0.0, -MapLayout.DINER_HALF),
			Vector3(MapLayout.DINER_HALF * 2.0, MapLayout.DINER_HEIGHT, MapLayout.DINER_HALF * 2.0)),
		get_viewport().get_camera_3d, _occluder_targets)

## Aim points (feet + the actor's AIM_HEIGHT) of everything the diner must not hide: the hero and every alive Boar.
func _occluder_targets() -> Array:
	var out: Array = []
	var hero := get_tree().get_first_node_in_group(&"hero") as Node3D
	if hero != null:
		out.append(hero.global_position + Vector3(0, Hero.AIM_HEIGHT, 0))
	if wave_director != null:
		for b in wave_director.alive_enemies():
			out.append((b as Node3D).global_position + Vector3(0, Boar.AIM_HEIGHT, 0))
	if guard_roster != null:
		out.append_array(guard_roster.occluder_points())
	return out

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
	traveler_pool.setup(_make_traveler, Balance.data.economy.queue_max * 2)
	traveler_spawner.setup(traveler_pool, fly_fx)
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
	enemy_pool.setup(_make_boar, sizes.enemy)
	pickup_field = PickupField.new()
	pickup_field.name = "PickupField"
	pickup_field.setup(PileMesh.steak_mesh(), sizes.steak)
	add_child(pickup_field)
	steak_pool.setup(_make_steak, sizes.steak)
	projectile_pool.setup(func(): return Projectile.new(), sizes.projectile)
	fx_pool.setup(func(): return FlyFx.make_item(), sizes.fx)
	fly_fx = FlyFx.new()
	fly_fx.name = "FlyFx"
	add_child(fly_fx)
	fly_fx.setup(fx_pool)
