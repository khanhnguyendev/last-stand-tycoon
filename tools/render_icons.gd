extends SceneTree
## Renders the HUD and card icons (S4 Task 15, spec 7, D-195). Run WITH rendering (not --headless):
##   "$GODOT" --path . --resolution 512x512 -s res://tools/render_icons.gd
## Each subject is staged alone on a transparent background in its own World3D (fixed 3/4 camera, the day light and
## ambient from Balance.ui), rendered at 512, scaled to 256 with nearest-neighbour, remapped to the palette
## (PaletteMath.remap_image, alpha kept) and saved to art/icons/<name>.png. Poses use AnimationPlayer.seek + advance(0),
## so there is no animation time drift. Deterministic: re-running writes byte-identical PNGs.
## R4: only the heart may use enemy_* colours, so every other icon remaps against the palette without them.
## Editor/test only (tools/ is excluded from every web export).

const OUT_DIR := "res://art/icons/"
const SIZE := 512
const OUT_SIZE := 256
const KNIFE := preload("res://assets/kaykit-restaurant/Assets/gltf/knife.gltf")
const MENU := preload("res://assets/kaykit-restaurant/Assets/gltf/menu.gltf")
const COIN := preload("res://art/pickups/coin.tscn")
const STEAK := preload("res://art/pickups/steak.tscn")
## The role visuals use the Balance autoload: loaded at run time, after the autoloads exist (a preload would not compile).
var HERO: PackedScene
var ARCHER: PackedScene
var TANK: PackedScene

## View direction (from the subject towards the camera): a fixed 3/4 view, slightly above and to the right.
const VIEW_DIR := Vector3(0.35, 0.55, 1.0)

var _vp: SubViewport
var _stage: Node3D
var _cam: Camera3D
var _failed := false

func _initialize() -> void:
	_run()

func _run() -> void:
	var ui: UiTuning = load("res://balance/ui_tuning.tres")
	HERO = load("res://art/characters/hero_visual.tscn")
	ARCHER = load("res://art/characters/archer_visual.tscn")
	TANK = load("res://art/characters/tank_visual.tscn")
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)  # world.gd's sun
	sun.light_color = ui.day_sun_color
	sun.light_energy = ui.day_sun_energy
	_vp.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ui.day_ambient
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 0.05
	_cam.far = 60.0
	_vp.add_child(_cam)
	_stage = Node3D.new()
	_vp.add_child(_stage)

	var full := Palette.colors()
	var no_enemy := PackedColorArray()
	for n in Palette.NAMES:
		if not String(n).begins_with("enemy_"):
			no_enemy.append(Palette.color(n))
	for s in _subjects():
		await _render(s, full if s.name == "heart" else no_enemy)
	quit(1 if _failed else 0)

## name, a builder returning the subject root (added to the stage by _render), the view centre, the ortho size.
func _subjects() -> Array:
	return [
		{"name": "card_hero_damage", "fit": true, "build": _knife_big, "center": Vector3(0, 0.0, 0), "size": 2.6},
		{"name": "card_attack_speed", "fit": true, "build": _knife_fan, "center": Vector3(0, 0.0, 0), "size": 2.8},
		{"name": "card_move_speed", "build": _runner, "center": Vector3(0, 0.95, 0), "size": 2.1},
		{"name": "card_carry_capacity", "fit": true, "build": _steak_stack, "center": Vector3(0, 0.3, 0), "size": 1.6},
		{"name": "card_gold_per_steak", "fit": true, "build": _menu, "center": Vector3(0, 0.0, 0), "size": 2.0},
		{"name": "card_archer", "build": _portrait.bind(ARCHER), "center": Vector3(0, 1.3, 0), "size": 1.9},
		{"name": "card_tank", "build": _portrait.bind(TANK), "center": Vector3(0, 1.35, 0), "size": 2.0},
		{"name": "coin", "fit": true, "build": _coin, "center": Vector3(0, 0.0, 0), "size": 1.2},
		{"name": "steak", "fit": true, "build": _steak, "center": Vector3(0, 0.0, 0), "size": 1.2},
		{"name": "heart", "fit": true, "build": _heart, "center": Vector3.ZERO, "size": 2.6},
		{"name": "moon", "fit": true, "build": _moon, "center": Vector3.ZERO, "size": 2.6},
	]

func _render(s: Dictionary, palette: PackedColorArray) -> void:
	for c in _stage.get_children():
		_stage.remove_child(c)
		c.free()
	var subject: Node3D = await s.build.call()
	_stage.add_child(subject)
	await _settle(subject)
	var dir := VIEW_DIR if not s.name in ["heart", "moon"] else Vector3(0.0, 0.0, 1.0)
	_cam.position = dir.normalized() * 20.0
	_cam.look_at(Vector3.ZERO, Vector3.UP)
	var center: Vector3 = s.center
	var size: float = s.size
	if s.get("fit", false):
		var f := _fit(subject)
		center = f.center
		size = f.size * 1.12
	_cam.position = center + dir.normalized() * 20.0
	_cam.look_at(center, Vector3.UP)
	_cam.size = size
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(OUT_SIZE, OUT_SIZE, Image.INTERPOLATE_NEAREST)
	var out := PaletteMath.remap_image(img, palette, {})
	var path: String = OUT_DIR + s.name + ".png"
	var err := out.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("save %s: %s" % [path, error_string(err)])
		_failed = true
	print("RENDERED ", path)

## Centre and ortho size that frame the subject's mesh bounds as seen by the camera (static meshes only).
func _fit(subject: Node3D) -> Dictionary:
	var basis := _cam.global_transform.basis
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var meshes := subject.find_children("*", "MeshInstance3D", true, false)
	if subject is MeshInstance3D:
		meshes.append(subject)
	for mi in meshes:
		var m := mi as MeshInstance3D
		var box := m.get_aabb()
		for i in 8:
			var corner := m.global_transform * box.get_endpoint(i)
			var c := basis.inverse() * corner
			lo = lo.min(c)
			hi = hi.max(c)
	var mid := (lo + hi) * 0.5
	return {"center": basis * mid, "size": maxf(hi.x - lo.x, hi.y - lo.y)}

## Two frames so _ready ran and a seeked pose reached the skeleton.
func _settle(subject: Node3D) -> void:
	await process_frame
	if subject.has_meta("pose"):
		var pose: Array = subject.get_meta("pose")
		var ap := subject.get_node("Body/AnimationPlayer") as AnimationPlayer  # not the glb's own player under Model
		(subject.get_node("Body/AnimationTree") as AnimationTree).active = false
		ap.play(pose[0])
		ap.seek(pose[1], true)
		ap.advance(0)
		ap.pause()
	await process_frame
	await process_frame

# --- subjects -----------------------------------------------------------------------------------------------------

func _knife_one() -> Node3D:
	var k: Node3D = KNIFE.instantiate()
	var holder := Node3D.new()
	holder.add_child(k)
	return holder

func _knife_big() -> Node3D:
	var n := _knife_one()
	n.rotation_degrees = Vector3(0, 0, 40)
	n.scale = Vector3.ONE * 2.2
	return n

func _knife_fan() -> Node3D:
	var root3 := Node3D.new()
	for a in [-25.0, 0.0, 25.0]:
		var n := _knife_one()
		n.rotation_degrees = Vector3(0, 0, 90 + a)
		n.scale = Vector3.ONE * 1.9
		root3.add_child(n)
	return root3

func _runner() -> Node3D:
	var v: Node3D = HERO.instantiate()
	v.rotation_degrees = Vector3(0, 25, 0)
	v.set_meta("pose", [&"Running_A", 0.3])
	return v

func _portrait(scene: PackedScene) -> Node3D:
	var v: Node3D = scene.instantiate()
	v.set_meta("pose", [&"Idle", 0.0])
	return v

func _steak() -> Node3D:
	var n: Node3D = STEAK.instantiate()
	n.scale = Vector3.ONE * 1.6
	return n

func _steak_stack() -> Node3D:
	var root3 := Node3D.new()
	for i in 3:
		var n: Node3D = STEAK.instantiate()
		n.position = Vector3(0.0, 0.0 + 0.2 * float(i), 0.0)
		n.rotation_degrees = Vector3(0, 35.0 * float(i), 0)
		n.scale = Vector3.ONE * 1.5
		root3.add_child(n)
	return root3

func _menu() -> Node3D:
	var n: Node3D = MENU.instantiate()
	n.scale = Vector3.ONE * 2.2
	return n

func _coin() -> Node3D:
	var n: Node3D = COIN.instantiate()
	n.rotation_degrees = Vector3(-25, -30, 0)
	n.scale = Vector3.ONE * 2.0
	return n

func _solid(mesh: Mesh, color: Color, glow: float) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow  # keeps the pale moon at warm_white under the day light
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi

func _heart() -> Node3D:
	return _solid(HeartMesh.build(), Palette.color(&"enemy_red"), 0.0)

func _moon() -> Node3D:
	return _solid(MoonMesh.build(), Palette.color(&"warm_white"), 0.6)
