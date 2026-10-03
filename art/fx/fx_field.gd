class_name FxField
extends MultiMeshInstance3D
## Every particle in the game in one draw (S5 spec 5.1, D-214): camera-facing quads, CPU-animated in _process. No
## randomness: each kind has a fixed direction set, rotated by a per-burst counter. Visual only: reads nothing from
## gameplay, writes nothing to GameState. Bursts arrive through EventBus.fx_requested.

const CAPACITY := 192
const CELLS: Array[StringName] = [&"puff", &"spark", &"star", &"dust"]
const ATLAS := preload("res://art/fx/fx_atlas.png")
const SHADER := preload("res://art/fx/fx.gdshader")
## Rotates each burst's direction set so successive bursts do not stack (golden-ratio turn, no randomness).
const BURST_TURN := 0.618
## count, cell, colour (Palette name), speed (m/s), up (m/s), gravity (m/s²), life (s), size (m); "to" = colour at end of life.
const KINDS := {
	&"poof": {"count": 8, "cell": 0, "color": &"enemy_snout", "to": &"apron_white", "speed": 2.2, "up": 1.5, "gravity": 2.0, "life": 0.45, "size": 0.75},
	&"hit": {"count": 4, "cell": 1, "color": &"warm_white", "speed": 3.0, "up": 1.0, "gravity": 0.0, "life": 0.25, "size": 0.8},
	&"sparkle": {"count": 6, "cell": 2, "color": &"gold", "speed": 1.6, "up": 2.4, "gravity": 3.0, "life": 0.6, "size": 0.4},
	&"dust": {"count": 3, "cell": 3, "color": &"stone", "speed": 0.6, "up": 0.4, "gravity": 0.0, "life": 0.45, "size": 0.7},
	&"coin": {"count": 5, "cell": 2, "color": &"gold", "speed": 1.6, "up": 2.6, "gravity": 3.0, "life": 0.6, "size": 0.45},
}

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _age := PackedFloat32Array()
var _kind: Array[StringName] = []
var _alive := PackedByteArray()
var _active := 0
var _burst_n := 0
var _from_colors := {}
var _to_colors := {}

func _init() -> void:
	name = "FxField"
	_pos.resize(CAPACITY)
	_vel.resize(CAPACITY)
	_age.resize(CAPACITY)
	_alive.resize(CAPACITY)
	_kind.resize(CAPACITY)
	for k in KINDS:
		var d: Dictionary = KINDS[k]
		# The palette is sRGB (ART_BIBLE); instance colours are linear.
		_from_colors[k] = Palette.color(d.color).srgb_to_linear()
		_to_colors[k] = Palette.color(d.get("to", d.color)).srgb_to_linear()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"atlas", ATLAS)
	mat.render_priority = 1  # particles draw after the blob shadows (ShadowField is -1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = CAPACITY
	var hidden := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO)
	for i in CAPACITY:
		mm.set_instance_transform(i, hidden)
	multimesh = mm
	material_override = mat
	custom_aabb = AABB(Vector3(-30, -1, -30), Vector3(60, 12, 60))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false  # no draw call while nothing is alive

func _ready() -> void:
	EventBus.fx_requested.connect(burst)

func active_count() -> int:
	return _active

## Starts a burst of `kind` at the world position `pos`. An unknown kind is ignored.
func burst(kind: StringName, pos: Vector3) -> void:
	if not KINDS.has(kind):
		return
	var d: Dictionary = KINDS[kind]
	var n: int = d.count
	var local := global_transform.affine_inverse() * pos if is_inside_tree() else pos
	var slots := _take_slots(n)
	for i in n:
		var s: int = slots[i]
		var ang := TAU * (i + 0.5) / n + BURST_TURN * _burst_n
		if _alive[s] == 0:
			_active += 1
		_alive[s] = 1
		_kind[s] = kind
		_age[s] = 0.0
		_pos[s] = local
		_vel[s] = Vector3(cos(ang) * d.speed, d.up, sin(ang) * d.speed)
	_burst_n += 1
	visible = true
	for s in slots:
		multimesh.set_instance_custom_data(s, Color(float(d.cell), 0, 0, 0))
		_write_one(s)

## n free slots (lowest index first); when fewer are free the oldest live slots (largest age, ties by slot index).
func _take_slots(n: int) -> Array[int]:
	var out: Array[int] = []
	for s in CAPACITY:
		if _alive[s] == 0:
			out.append(s)
			if out.size() == n:
				return out
	while out.size() < n:
		var best := -1
		for s in CAPACITY:
			if out.has(s):
				continue
			if best < 0 or _age[s] > _age[best]:
				best = s
		out.append(best)
	return out

func _process(delta: float) -> void:
	if _active == 0:
		return
	step(delta)

## Advances every live quad by dt and writes the instance buffers.
func step(dt: float) -> void:
	if _active == 0:
		return
	for s in CAPACITY:
		if _alive[s] == 0:
			continue
		var d: Dictionary = KINDS[_kind[s]]
		_age[s] += dt
		if _age[s] >= d.life:
			_alive[s] = 0
			_active -= 1
			multimesh.set_instance_transform(s, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), _pos[s]))
			continue
		_vel[s].y -= d.gravity * dt
		_pos[s] += _vel[s] * dt
		_write_one(s)
	if _active == 0:
		visible = false

func _write_one(s: int) -> void:
	var d: Dictionary = KINDS[_kind[s]]
	var t: float = clampf(_age[s] / d.life, 0.0, 1.0)
	var sz: float = d.size * (sin(PI * t) * 0.6 + 0.4)
	multimesh.set_instance_transform(s, Transform3D(Basis.IDENTITY.scaled(Vector3(sz, sz, sz)), _pos[s]))
	var c: Color = _from_colors[_kind[s]].lerp(_to_colors[_kind[s]], t)
	c.a = 1.0 - t * t
	multimesh.set_instance_color(s, c)

## Per slot: x, y, z, age, alive (for tests; the MultiMesh buffer is write-only when headless).
func instance_snapshot() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for s in CAPACITY:
		out.append_array(PackedFloat32Array([_pos[s].x, _pos[s].y, _pos[s].z, _age[s], float(_alive[s])]))
	return out
