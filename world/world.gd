class_name World
extends Node3D
## Builds the map in code from MapLayout (spec 3.3, 6.1). Extended by later tasks.

## Ground margin past MapLayout bounds. The projection test proves it covers every camera view for
## window aspects 9:21..21:9 (CameraMath clamps beyond that) at every focus corner (D-152, D-153).
const GROUND_MARGIN := 80.0
## S4 art (D-194, D-201): the diner is one baked mesh plus its rooftop board; instanced once.
const DINER_ART := preload("res://art/env/diner.tscn")
const DINER_ART_T2 := preload("res://art/env/diner_t2.tscn")

var lanes := {}
var lighting: LightingDirector
var props: Props
var diner_body: StaticBody3D
var build_spots := {}
var upgrade_pads := {}
var freezer: Freezer
var counter: Counter
var gold_pile: GoldPile
var closeup_sign: CloseUpSign
var tier_sign: TierSign
var telegraph_markers := {}
var fly_fx: FlyFx
var occluder_fade: OccluderFade
var guard_roster: GuardRoster
## One draw for every blob shadow (S4 D-201). Actors register their Visual with it: the hero and guards in setup(), the
## travelers in begin() (the factory below hands each one this field).
var shadow_field: ShadowField
## One draw for every ground steak (S4 Task 10b, D-201): the steak factory hands each steak this field and its slot.
var pickup_field: PickupField
## One draw for every particle (S5 Task 4, D-214). Listens to EventBus.fx_requested.
var fx_field: FxField
## E5 Task 12: stages the tier-up (visual only).
var tier_reveal: TierReveal
## E5 Task 10: the merged ground carries the open yards; the stones ring them (one MultiMesh, no collision).
var ground: MeshInstance3D
var yard_stones: MultiMeshInstance3D
## The lane edge stones (one MultiMesh); rebuilt when the lane set changes (tier 3 adds the south-west strip's).
var edge_stones: MultiMeshInstance3D
var _stone_lanes: Array[String] = []
## The tier the ground, the stones, the props and the spots were last built for (rebuild_for_tier is a no-op if equal).
var _built_tier := 1
## The phase as the bus last announced it: a spot created mid-game must know it (its zone missed the signal).
var _phase := Phase.NIGHT

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
	EventBus.phase_changed.connect(_on_phase_changed)  # before any spot exists: the spots read _phase when built
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
	fx_field = FxField.new()
	fx_field.name = "FxField"
	add_child(fx_field)
	var reactions := Reactions.new()
	reactions.name = "Reactions"
	add_child(reactions)
	tier_reveal = TierReveal.new()
	add_child(tier_reveal)
	tier_reveal.setup(self)
	_built_tier = _effective_tier()
	EventBus.tier_changed.connect(_on_tier_changed)
	EventBus.tier_reached.connect(_on_tier_reached)
	EventBus.state_restored.connect(rebuild_for_tier)

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = false
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR  # day_bg is the grass: anything past the ground reads as ground (D-153)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	# S4 Task 13: the colours, energies and the day/night tween come from the LightingDirector.
	lighting = LightingDirector.new()
	lighting.name = "LightingDirector"
	add_child(lighting)
	lighting.setup(sun, env.environment)

## The area the single ground plane covers, in xz.
static func ground_rect() -> Rect2:
	var lo := MapLayout.BOUNDS_MIN - Vector2(GROUND_MARGIN, GROUND_MARGIN)
	var hi := MapLayout.BOUNDS_MAX + Vector2(GROUND_MARGIN, GROUND_MARGIN)
	return Rect2(lo, hi - lo)

func _build_ground() -> void:
	var rect := ground_rect()
	# S4 D-201: ground + road + lane strips + open yards are ONE mesh, the edge stones ONE MultiMesh, the props 2 meshes.
	var yards := yard_ids()
	ground = GroundArt.instance(GroundArt.terrain_mesh(rect, yards, lane_ids()), "Ground")
	add_child(ground)
	_stone_lanes = lane_ids()
	edge_stones = LaneStrip.edge_stones(_stone_lanes)
	add_child(edge_stones)
	props = Props.new()
	props.name = "Props"
	add_child(props)
	props.build(_yard_rects(yards))
	_set_yard_stones(yards)

func _on_phase_changed(p: int, _day: int) -> void:
	_phase = p

func _on_tier_changed(_tier: int, _paid: int, _boss_pending: bool) -> void:
	rebuild_for_tier()  # debug_set_tier and the tier-up both announce here; a payment tick finds nothing to do

func _on_tier_reached(_tier: int) -> void:
	rebuild_for_tier()

## The tier the map follows: tier 1 until the first new_game (buildings is empty then).
func _effective_tier() -> int:
	return GameState.tier if not GameState.buildings.is_empty() else 1

## The yards open now; empty before the first new_game.
func yard_ids() -> Array[String]:
	return MapLayout.yards_for_tier(_effective_tier())

## The lanes monsters use now (E5 tier 3: the south-west one joins at tier 3).
func lane_ids() -> Array[String]:
	return MapLayout.lanes_for_tier(_effective_tier())

func _yard_rects(yards: Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for id in yards:
		out.append(MapLayout.yard_rect(id))
	return out

func _set_yard_stones(yards: Array) -> void:
	if yard_stones != null:
		remove_child(yard_stones)
		yard_stones.queue_free()
		yard_stones = null
	if not yards.is_empty():
		yard_stones = YardStones.build(yards, Balance.data.enemy.lateral_spread)
		add_child(yard_stones)

## E5 Task 11: the tier-2 diner (the flank terraces) from tier 2; tier 1 keeps DINER_ART.
static func diner_scene_for(tier: int) -> PackedScene:
	return DINER_ART_T2 if tier >= 2 else DINER_ART

## E5 spec 7.3: the ground mesh, the yard stones, the props and the spot set follow the tier (tier_changed, tier_reached,
## restore, new game). Visual only; cheap to call: nothing happens unless the tier changed.
func rebuild_for_tier() -> void:
	var tier := _effective_tier()
	if tier == _built_tier:
		return
	var moves_service := MapLayout.queue_slots(tier) != MapLayout.queue_slots(_built_tier) or MapLayout.traveler_exit(tier) != MapLayout.traveler_exit(_built_tier)
	_built_tier = tier
	if moves_service:
		_switch_service_layout()
	var yards := yard_ids()
	ground.mesh = GroundArt.terrain_mesh(ground_rect(), yards, lane_ids())
	_sync_lanes()
	props.build(_yard_rects(yards))
	_set_yard_stones(yards)
	var want := MapLayout.spots_for_tier(tier)
	for id in build_spots.keys():
		if not id in want:
			var gone: BuildSpot = build_spots[id]
			build_spots.erase(id)
			remove_child(gone)  # at once: queue_free is deferred
			gone.queue_free()
	for id in want:
		if not build_spots.has(id):
			_make_spot(id)
	_swap_diner_art(tier)

## The queue slots and the exit change with the tier (tier 3: the east side, spec 4.2). A traveler alive at that moment would keep
## the old exit or stand off its slot, so none may be. The normal switch is the tier-up dawn: PhaseController._run_dawn recalls every
## traveler (and the spawner stopped at close-up) before complete_tier_up changes the tier, so the count is 0 there and this only asserts
## it. Any other change (debug_set_tier by day, a load, a new game) drops the travelers: the simplest safe behaviour.
func _switch_service_layout() -> void:
	if _phase == Phase.DAWN:
		assert(traveler_spawner.live_count() == 0, "the service layout switches at the dawn, when no traveler is alive")
		return
	traveler_spawner.clear_queue()

## The lane nodes, their edge stones and their telegraph markers follow the tier: the lanes of `lane_ids()` exist, no others.
## Tiers 1 and 2 have the same three, so nothing is touched for them.
func _sync_lanes() -> void:
	var want := lane_ids()
	for id in lanes.keys():
		if not id in want:
			var gone: Lane = lanes[id]
			lanes.erase(id)
			remove_child(gone)
			gone.queue_free()
			var marker: TelegraphMarker = telegraph_markers.get(id)
			if marker != null:
				telegraph_markers.erase(id)
				remove_child(marker)
				marker.queue_free()
	for id in want:
		if not lanes.has(id):
			_make_lane(id)
			_make_marker(id)
	if want != _stone_lanes:
		edge_stones.multimesh = LaneStrip.edge_multimesh(want)
		_stone_lanes = want

## Replaces only the DinerArt child of the diner's Visual (the OccluderFade stays), as child 0, when the scene differs.
func _swap_diner_art(tier: int) -> void:
	var vis := diner_body.get_node("Visual")
	var want := diner_scene_for(tier)
	var art := vis.get_node_or_null("DinerArt")
	if art != null and art.scene_file_path == want.resource_path:
		return
	if art != null:
		vis.remove_child(art)  # at once: the fade's find_children must not see the old art
		art.queue_free()
	var fresh := want.instantiate()
	vis.add_child(fresh)
	vis.move_child(fresh, 0)
	occluder_fade.refresh_bounds()

func _build_diner() -> void:
	diner_body = add_static_box("Diner", Vector3(8, MapLayout.DINER_HEIGHT, 8), Vector2.ZERO, diner_scene_for(_effective_tier()))
	# D-151: the diner fades while it hides the hero or a Boar from the camera.
	occluder_fade = OccluderFade.new()
	occluder_fade.name = "OccluderFade"
	diner_body.get_node("Visual").add_child(occluder_fade)
	# S4: the box comes from the art's merged bounds (walls, parapet, chimney, board), so no box is passed.
	occluder_fade.setup(AABB(), get_viewport().get_camera_3d, _occluder_targets)

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
	for id in lane_ids():
		_make_lane(id)

func _make_lane(id: String) -> void:
	var lane := Lane.new()
	lane.setup(id)
	add_child(lane)
	lanes[id] = lane

func _make_marker(id: String) -> void:
	var m := TelegraphMarker.new()
	add_child(m)
	m.setup(id)
	m.sync_phase(_phase)  # a marker made mid-day missed phase_changed
	telegraph_markers[id] = m

## Static collider on layer 1, standing on the ground at xz. The art (S4) is `visual_scene`, instanced once under a
## "Visual" Node3D (no primitives: collision shapes and sizes are the gameplay truth).
func add_static_box(node_name: String, size: Vector3, xz: Vector2, visual_scene: PackedScene = null) -> StaticBody3D:
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
	if visual_scene != null:
		vis.add_child(visual_scene.instantiate())
	body.add_child(vis)
	body.position = MapLayout.to3(xz)
	add_child(body)
	return body

func _build_spots() -> void:
	for id in MapLayout.spots_for_tier(_effective_tier()):
		_make_spot(id)

func _make_spot(id: String) -> void:
	var s: BuildSpot = TowerSpot.new() if MapLayout.spot_kind(id) == "tower" else FenceSpot.new()
	add_child(s)
	s.setup(id, self)
	s.zone.sync_phase(_phase)  # a spot made mid-game missed phase_changed
	s.refresh()
	build_spots[id] = s

func _build_stations() -> void:
	freezer = Freezer.new()
	add_child(freezer)
	freezer.setup(self)
	counter = Counter.new()
	add_child(counter)
	counter.setup(self)
	for id in StationEffects.IDS:
		var pad := UpgradePad.new()
		add_child(pad)
		pad.setup(id, self)
		upgrade_pads[id] = pad
	gold_pile = GoldPile.new()
	add_child(gold_pile)
	gold_pile.setup(self)
	traveler_pool.setup(_make_traveler, StationEffects.traveler_pool_size(Balance.data.stations, Balance.data.economy))
	traveler_spawner.setup(traveler_pool, fly_fx)
	closeup_sign = CloseUpSign.new()
	add_child(closeup_sign)
	closeup_sign.setup(self)
	tier_sign = TierSign.new()
	add_child(tier_sign)
	tier_sign.setup(self)
	for id in lane_ids():
		_make_marker(id)

## Single shooters besides towers that can have shots in flight at once (hero, archer guard, tank guard).
const HERO_SHOTS_IN_FLIGHT := 2
const ARCHER_SHOTS_IN_FLIGHT := 2
const TANK_SHOTS_IN_FLIGHT := 1

## Shots of one tower in flight at once: `count` per attack, a shot lives range / speed seconds, one attack per interval.
static func in_flight(count: int, attack_range: float, interval: float, speed: float) -> int:
	return count * (floori(attack_range / speed / interval) + 1)

## Projectiles for the top tier: every tower of the top tier at its worst in_flight (levels 1 to 3 and both branches)
## plus the single shooters, with the 20% margin. The pool must never grow at runtime.
static func projectile_pool_size(bd: BalanceData) -> int:
	var speed := bd.build.tower_projectile_speed
	var worst := 0
	for lv in bd.build.max_level:
		worst = maxi(worst, World.in_flight(1, bd.build.tower_range[lv], bd.build.tower_interval, speed))
	for id in BranchBalance.TOWER_BRANCHES:
		var st := bd.branches.tower(id)
		worst = maxi(worst, World.in_flight(st.count, st.attack_range, st.interval, speed))
	var towers := 0
	for id in MapLayout.spots_for_tier(TierEffects.top_tier(bd.tiers)):
		if MapLayout.spot_kind(id) == "tower":
			towers += 1
	return int(ceil((towers * worst + HERO_SHOTS_IN_FLIGHT + ARCHER_SHOTS_IN_FLIGHT + TANK_SHOTS_IN_FLIGHT) * 1.2))

static func pool_sizes(bd: BalanceData) -> Dictionary:
	# E5: the steak pool holds the top tier's capped night plus the boss drop, with the old 20% margin (spec 7.1).
	var top := TierEffects.top_tier(bd.tiers)
	var steaks := 0
	for w in bd.wave.base_counts.size():
		steaks += WaveMath.total_count(bd.tiers.tier_cap[top], w, bd.wave)  # capped counts (D-124)
	return {
		"enemy": bd.wave.max_wave_size + 1 + 10,
		"steak": int(ceil((steaks * bd.economy.steaks_per_kill + bd.monsters.stats(&"boss").steaks_per_kill) * 1.2)),
		"projectile": World.projectile_pool_size(bd),
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
