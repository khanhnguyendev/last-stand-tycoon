class_name Hero
extends CharacterBody3D
## The player's cook (spec 7.3). Moves only through HeroInput.

## Height above the feet the camera aims at when checking occlusion (D-151); the body capsule is 1.6 m.
const AIM_HEIGHT := 1.0

var input: HeroInput
var magnet: Magnet
var carry_stack: CarryStack
var attacker: Attacker
## The cook's art (S4 Task 7b, D-190, D-191); animation and facing only, never gameplay state.
var visual: ActorVisual
var still_time := 0.0
## Incremented by teleport(); StationZone disarms when it changes (D-121).
var teleport_serial := 0

func _init() -> void:
	name = "Hero"
	add_to_group(&"hero")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = MapLayout.HERO_RADIUS
	cap.height = 1.6
	shape.shape = cap
	shape.position.y = 0.8
	add_child(shape)
	visual = load("res://art/characters/hero_visual.tscn").instantiate()
	add_child(visual)
	add_child(load("res://art/shared/hero_ring.tscn").instantiate())
	input = HeroInput.new()
	add_child(input)
	magnet = Magnet.new()
	add_child(magnet)
	carry_stack = CarryStack.new()
	add_child(carry_stack)
	attacker = Attacker.new()
	attacker.projectile_art = &"knife"
	attacker.fired.connect(func(_target): visual.attack())
	attacker.fired.connect(func(_target): EventBus.sfx_requested.emit(&"throw"))
	add_child(attacker)

func _ready() -> void:
	EventBus.hero_place_requested.connect(teleport)
	EventBus.card_picked.connect(_apply_card_stats.unbind(2))
	EventBus.state_restored.connect(_apply_card_stats)
	EventBus.phase_changed.connect(_on_phase_changed)

func setup(world: World) -> void:
	magnet.setup(world.steak_pool, world.fly_fx)
	world.shadow_field.register(visual, ShadowField.CHARACTER_RADIUS)  # S4 D-201: one draw for every blob shadow
	_apply_card_stats()
	attacker.candidates = world.wave_director.enemy_candidates
	attacker.projectile_pool = world.projectile_pool
	attacker.is_moving = is_moving

func _physics_process(delta: float) -> void:
	var mv := input.get_move()
	var spd := move_speed()
	velocity = Vector3(mv.x, 0.0, mv.y) * spd
	move_and_slide()
	position.y = 0.0
	visual.set_motion(velocity.length() / maxf(spd, 0.01))
	visual.face(velocity)
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < Balance.data.economy.stand_still_speed:
		still_time += delta
	else:
		still_time = 0.0

## True only while actually moving: still_time is reset by teleport(), but velocity is zero then.
func is_moving() -> bool:
	return still_time <= 0.0 and velocity.length_squared() > 0.0

func xz() -> Vector2:
	return Vector2(global_position.x, global_position.z)

func teleport(p: Vector2) -> void:
	global_position = MapLayout.to3(p)
	velocity = Vector3.ZERO
	still_time = 0.0
	teleport_serial += 1
	input.set_move(Vector2.ZERO)

## Effective move speed with cards (S2 spec 4.2).
func move_speed() -> float:
	return CardEffects.hero_move_speed(Balance.data.hero.move_speed, GameState.cards, Balance.data.cards)

## Attack stats with cards; S1 configured these once in setup().
func _apply_card_stats() -> void:
	var hb := Balance.data.hero
	var cb := Balance.data.cards
	attacker.configure(CardEffects.hero_damage(hb.attack_damage, GameState.cards, cb), hb.attack_range,
		CardEffects.hero_attack_interval(hb.attack_interval, GameState.cards, cb), hb.retarget_interval,
		hb.moving_attack_speed_mult, hb.projectile_speed)

func _on_phase_changed(phase: int, _day: int) -> void:
	input.blocked = phase == Phase.DAWN
	if phase == Phase.DAWN:
		visual.cheer()
