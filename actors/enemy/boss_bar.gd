class_name BossBar
extends Node3D
## The boss's world HP bar (E5 spec 7.1): enemy_red on ink, 1.6 m wide, 2.6 m up. Visual only: it reads the Boar's Health and
## never writes game state. Every Boar owns one (the pool is built once), but the two box meshes are made lazily the first time
## this Boar spawns as a boss, from two materials shared by all bars, so a night without a boss draws and allocates nothing.

const WIDTH := 1.6
const Y := 2.6

static var _back_mat: StandardMaterial3D
static var _fill_mat: StandardMaterial3D

var _boar: Boar
var _fill: MeshInstance3D

func setup(boar: Boar) -> void:
	_boar = boar
	name = "BossBar"
	position.y = Y
	visible = false

static func _material(color: StringName) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.color(color)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

static func fill_material() -> StandardMaterial3D:
	if _fill_mat == null:
		_fill_mat = _material(&"enemy_red")
	return _fill_mat

static func back_material() -> StandardMaterial3D:
	if _back_mat == null:
		_back_mat = _material(&"ink")
	return _back_mat

func _box(size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _build() -> void:
	_box(Vector3(WIDTH + 0.1, 0.16, 0.06), back_material())
	_fill = _box(Vector3(WIDTH, 0.1, 0.08), fill_material())

func fraction() -> float:
	var h := _boar.health
	return 0.0 if h.max_hp <= 0.0 else clampf(h.hp / h.max_hp, 0.0, 1.0)

func fill_color() -> Color:
	if _fill != null:
		return (_fill.material_override as StandardMaterial3D).albedo_color
	return fill_material().albedo_color

func _is_living_boss() -> bool:
	return _boar != null and _boar.kind == &"boss" and _boar.alive

func _refresh() -> void:
	var show := _is_living_boss()
	if show and _fill == null:
		_build()
	visible = show
	if not show:
		return
	var f := fraction()
	_fill.scale.x = maxf(f, 0.001)
	_fill.position.x = -WIDTH * 0.5 * (1.0 - f)

func _process(_delta: float) -> void:
	if _boar == null or (not visible and _boar.kind != &"boss"):
		return  # every active Boar ticks this; a non-boss returns at once
	_refresh()
