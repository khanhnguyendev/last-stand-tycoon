class_name Warmup
extends Node3D
## S5 (D-215): draws every first-use visual once, in front of the camera under the boot fade, so the shader, material and
## mesh uploads happen before the first frame the player sees. Builds the temporary nodes from the real scenes, waits three
## frames, frees them, then registers the audio samples (and the resume phase's music track, D-212 lazy mode).
## Visual only: touches no pool, no GameState, no Rng.

signal finished

const DISTANCE := 6.0
const SPREAD := 1.0
const FRAMES := 3
const ROW := 5
const BOAR := preload("res://actors/enemy/boar.gd")
const SCENES: Array[String] = [
	"res://art/pickups/knife_projectile.tscn",
	"res://art/pickups/arrow_projectile.tscn",
	"res://art/env/tower_l1.tscn",
	"res://art/env/fence_l1.tscn",
	"res://art/characters/hero_visual.tscn",
	"res://art/characters/archer_visual.tscn",
	"res://art/characters/tank_visual.tscn",
	"res://art/characters/traveler_visual.tscn",
]

## Temporary nodes built by the last run (tests).
var built_count := 0
## World positions the temporary nodes were placed at by the last run (tests check they are inside the frustum).
var placed: Array[Vector3] = []
var _slot := 0
var _origin := Vector3.ZERO
var _right := Vector3.RIGHT
var _up := Vector3.UP

## The music track the saved run resumes into: night, or day for a DAY or CARD_PICK (dawn) resume.
static func music_for(resume_phase: String) -> StringName:
	return &"day" if resume_phase in ["DAY", "CARD_PICK"] else &"night"

## resume_phase: the saved run's resume_phase ("" for a fresh start: night).
func run(main: Main, resume_phase := "") -> void:
	built_count = 0
	placed.clear()
	_slot = 0
	var cam := main.camera_rig.camera
	var xf := cam.global_transform if cam.is_inside_tree() else cam.transform
	_origin = xf.origin - xf.basis.z * DISTANCE
	_right = xf.basis.x
	_up = xf.basis.y
	for k in MonsterBalance.KINDS:
		var v: BoarVisual = BOAR.VISUAL_SCENE.instantiate()
		_place(v)
		v.set_kind(k)
	for mat in [BossBar.back_material(), BossBar.fill_material()]:
		var bar := MeshInstance3D.new()
		bar.mesh = BoxMesh.new()
		bar.material_override = mat
		_place(bar)
	for path in SCENES:
		_place((load(path) as PackedScene).instantiate())
	_place(_steak_field())
	_place(_fx_field())
	var cube := MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	cube.material_override = main.world.occluder_fade.fade_material_for_warmup()
	_place(cube)
	_prebuild_tier_caches()
	if not MapLayout.yards_for_tier(TierEffects.top_tier(Balance.data.tiers)).is_empty():
		_place(YardStones.build_sample())  # the kerb's mesh and material are first drawn at the tier-2 reveal
	for _i in FRAMES:
		await get_tree().process_frame
	for c in get_children():
		remove_child(c)
		c.free()
	var track := music_for(resume_phase)
	main.audio_director.register_streams()
	main.audio_director.preload_music(track)
	if OS.is_debug_build() or OS.has_feature("profile_overlay"):
		print("WARMUP built=%d track=%s" % [built_count, track])
	finished.emit()

## E5 Task 12: the first tier-up would build the top tier's terrain mesh (10.5k vertices, in GDScript) and re-merge the props
## inside the tier-up frame. Fill both caches now; no node is added, nothing in the world changes.
static func _prebuild_tier_caches() -> void:
	var yards := MapLayout.yards_for_tier(TierEffects.top_tier(Balance.data.tiers))
	if yards.is_empty():
		return
	GroundArt.terrain_mesh(World.ground_rect(), yards, MapLayout.lanes_for_tier(TierEffects.top_tier(Balance.data.tiers)))
	var rects: Array[Rect2] = []
	for id in yards:
		rects.append(MapLayout.yard_rect(id))
	Props.prebuild(rects)

func _place(n: Node3D) -> void:
	add_child(n)
	# 1 m apart, centred on the view axis, in a row inside the frustum.
	n.global_position = _origin + _right * (SPREAD * (float(_slot % ROW) - float(ROW - 1) * 0.5)) + _up * (SPREAD * float(_slot / ROW))
	placed.append(n.global_position)
	_slot += 1
	built_count += 1

## The steak MultiMesh in PickupField's format: transform-only, shadows off.
func _steak_field() -> MultiMeshInstance3D:
	var f := PickupField.new()
	f.setup(PileMesh.steak_mesh(), 1)
	f.set_slot(0, PickupField.slot_transform(Vector3.ZERO, 0.0, PileMesh.steak_xf()))
	return f

## FxField's quad, shader material and instance format, one instance per atlas cell.
func _fx_field() -> MultiMeshInstance3D:
	var cells := FxField.CELLS.size()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = FxField.SHADER
	mat.set_shader_parameter(&"atlas", FxField.ATLAS)
	mat.render_priority = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = cells
	for i in cells:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(float(i) * 0.5, 0.5, 0)))
		mm.set_instance_color(i, Color(1, 1, 1, 0.9))
		mm.set_instance_custom_data(i, Color(float(i), 0, 0, 0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.custom_aabb = AABB(Vector3(-30, -1, -30), Vector3(60, 12, 60))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
