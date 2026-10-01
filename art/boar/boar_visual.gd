class_name BoarVisual
extends ActorVisual
## The production Boar's art side (S4 Task 9, D-192, ART_BIBLE §6): one merged mesh, shader legs, three shared
## materials, and tweens on Body only. Boar owns this node's root scale (play_death's 0.15 s tween) and its
## `_flash_left` countdown; this class never touches either. Visual-only: no gameplay state, no Rng.

const SHADER := preload("res://art/boar/boar.gdshader")

static var _idle: ShaderMaterial
static var _run: ShaderMaterial
static var _flash: ShaderMaterial

var _mesh_node: MeshInstance3D
var _running := false
var _t := 0.0
var _hop_y := 0.0
## Lunge distance along the facing direction, driven by the attack tween.
var _lunge := 0.0
var _attack_tween: Tween
var _squash_tween: Tween

static func _make_material(run: float, flash: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("run_amount", run)
	m.set_shader_parameter("hop_hz", Balance.ui.boar_hop_hz)
	m.set_shader_parameter("flash", flash)
	# R2: white is the hero's. The hit flash is warm_white pushed toward the snout: a pale pink-white.
	m.set_shader_parameter("flash_color", Palette.color(&"warm_white").lerp(Palette.color(&"enemy_snout"), 0.3))
	return m

static func idle_material() -> ShaderMaterial:
	if _idle == null:
		_idle = _make_material(0.0, false)
	return _idle

static func run_material() -> ShaderMaterial:
	if _run == null:
		_run = _make_material(1.0, false)
	return _run

static func flash_material() -> ShaderMaterial:
	if _flash == null:
		_flash = _make_material(0.0, true)
	return _flash

func _ready() -> void:
	super._ready()
	_mesh_node = body.get_node_or_null("Mesh") as MeshInstance3D
	if _mesh_node == null:
		_mesh_node = MeshInstance3D.new()
		_mesh_node.name = "Mesh"
		body.add_child(_mesh_node)
	_mesh_node.mesh = BoarMesh.get_mesh()
	_mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply_material()

func _apply_material() -> void:
	if _mesh_node == null:
		return
	if flash_active:
		_mesh_node.material_override = flash_material()
	elif _running:
		_mesh_node.material_override = run_material()
	else:
		_mesh_node.material_override = idle_material()

func set_motion(speed_frac: float) -> void:
	var run := speed_frac > 0.1
	if run == _running:
		return
	_running = run
	_apply_material()

func set_flash(on: bool) -> void:
	flash_active = on
	_apply_material()

func attack() -> void:
	if body == null:
		return
	_kill(_attack_tween)
	var ui := Balance.ui
	_attack_tween = create_tween()
	_attack_tween.tween_method(_set_lunge, 0.0, -0.06, 0.04)
	_attack_tween.tween_method(_set_lunge, -0.06, ui.boar_lunge, 0.05)
	_attack_tween.tween_method(_set_lunge, ui.boar_lunge, 0.0, 0.06)

func hit() -> void:
	if body == null:
		return
	_kill(_squash_tween)
	_squash_tween = create_tween()
	_squash_tween.tween_property(body, "scale:y", Balance.ui.boar_squash, 0.04)
	_squash_tween.tween_property(body, "scale:y", 1.0, 0.04)

func die() -> void:
	if body == null:
		return
	_kill(_squash_tween)
	_squash_tween = create_tween()
	_squash_tween.tween_property(body, "scale:y", Balance.ui.boar_death_squash, 0.12)

func reset() -> void:
	_kill(_attack_tween)
	_kill(_squash_tween)
	_attack_tween = null
	_squash_tween = null
	_lunge = 0.0
	_hop_y = 0.0
	_running = false
	super.reset()
	_apply_material()

func _kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()

func _set_lunge(v: float) -> void:
	_lunge = v
	_apply_offset()

## Body offset: the hop / bob on y, the lunge along the way the Body faces.
func _apply_offset() -> void:
	body.position = Vector3(0.0, _hop_y, 0.0) + body.basis.z * _lunge

func _process(delta: float) -> void:
	super._process(delta)
	if body == null:
		return
	var ui := Balance.ui
	_t += delta
	if _running:
		_hop_y = ui.boar_hop_height * absf(sin(_t * PI * ui.boar_hop_hz))
	else:
		_hop_y = sin(_t * TAU / ui.boar_idle_period) * ui.boar_idle_bob * 0.5
	_apply_offset()
