class_name Hero
extends CharacterBody3D
## The player's cook (spec 7.3). Moves only through HeroInput.

var input: HeroInput
var magnet: Magnet
var carry_stack: CarryStack
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
	var v := Visuals.visual_root()
	var body := Visuals.capsule(MapLayout.HERO_RADIUS, 1.6, Visuals.COLORS.hero)
	body.position.y = 0.8
	v.add_child(body)
	var hat := Visuals.box(Vector3(0.5, 0.3, 0.5), Visuals.COLORS.hat)
	hat.position.y = 1.75
	v.add_child(hat)
	add_child(v)
	input = HeroInput.new()
	add_child(input)
	magnet = Magnet.new()
	add_child(magnet)
	carry_stack = CarryStack.new()
	add_child(carry_stack)

func _ready() -> void:
	EventBus.hero_place_requested.connect(teleport)

func setup(world: World) -> void:
	magnet.setup(world.steak_pool)

func _physics_process(delta: float) -> void:
	var mv := input.get_move()
	velocity = Vector3(mv.x, 0.0, mv.y) * Balance.data.hero.move_speed
	move_and_slide()
	position.y = 0.0
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < Balance.data.economy.stand_still_speed:
		still_time += delta
	else:
		still_time = 0.0

func is_moving() -> bool:
	return still_time <= 0.0

func xz() -> Vector2:
	return Vector2(global_position.x, global_position.z)

func teleport(p: Vector2) -> void:
	global_position = MapLayout.to3(p)
	velocity = Vector3.ZERO
	still_time = 0.0
	teleport_serial += 1
	input.set_move(Vector2.ZERO)
