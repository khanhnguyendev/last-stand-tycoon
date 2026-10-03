extends SceneTree
## Renders the HUD and card icons (S4 Task 15, spec 7, D-195). Run WITH rendering (not --headless):
##   "$GODOT" --path . --resolution 512x512 -s res://tools/render_icons.gd
## Each subject is staged alone on a transparent background in its own World3D (fixed 3/4 camera, the day light and
## ambient from Balance.ui), rendered at 512, scaled to 256 with nearest-neighbour, remapped to the palette
## (PaletteMath.remap_image, alpha kept) and saved to art/icons/<name>.png. Poses use AnimationPlayer.seek + advance(0),
## so there is no animation time drift. Deterministic: re-running writes byte-identical PNGs.
## Palettes (R2, R4): the heart remaps against enemy_red, enemy_maroon and ink only; the moon against warm_white,
## diner_cream and traveler_beige; the carry-capacity steak stack drops gold and gold_dark (a steak rim must read as food, not reward);
## every other icon drops the enemy_* and traveler_* names, so steel shades land on steel, steel_dark or stone.
## Byte-identical output holds on the same GPU and driver (the render is hardware-dependent); the committed PNGs are the
## product, and CI never re-renders them.
## `--atlas-only` skips the rendering and only rebuilds art/icons/atlas.png (Task 16b); it needs the committed atlas.png to exist (import) and the per-icon PNGs.
## Editor/test only (tools/ is excluded from every web export).

## Each baked shape is remapped against its own palette (S5 Task 8a).
const SHAPE_PALETTES := {
	&"backing": [&"diner_cream", &"ink"], &"disc": [&"ink"], &"gear": [&"ink", &"warm_white"],
	&"stick_ring": [&"ink", &"warm_white"], &"stick_knob": [&"warm_white"], &"guide_arrow": [&"apron_white", &"ink"],
}
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
	if "--atlas-only" in OS.get_cmdline_user_args():
		quit(0 if _write_atlas() else 1)
		return
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

	for s in _subjects():
		await _render(s, _palette_for(s.name))
	if not _write_atlas():
		_failed = true
	quit(1 if _failed else 0)

## art/icons/atlas.png: every icon halved to IconAtlas.CELL (2x2 box, alpha-weighted colour), remapped to the icon's own
## palette (so the atlas is on-palette, and R4 holds per cell), in IconAtlas.NAMES order. Rebuild alone with
## `-s res://tools/render_icons.gd -- --atlas-only` (needs no rendering). Deterministic.
func _write_atlas() -> bool:
	var sheet := Image.create_empty(IconAtlas.COLS * IconAtlas.CELL, IconAtlas.rows() * IconAtlas.CELL, false, Image.FORMAT_RGBA8)
	for i in IconAtlas.NAMES.size():
		var n := String(IconAtlas.NAMES[i])
		var src := Image.load_from_file(ProjectSettings.globalize_path(OUT_DIR + n + ".png"))
		if src == null:
			push_error("atlas: cannot read %s" % n)
			return false
		src.convert(Image.FORMAT_RGBA8)
		var half := _box_half(src)
		half = PaletteMath.remap_image(half, _palette_for(n), {})
		sheet.blit_rect(half, Rect2i(0, 0, IconAtlas.CELL, IconAtlas.CELL), Vector2i((i % IconAtlas.COLS) * IconAtlas.CELL, (i / IconAtlas.COLS) * IconAtlas.CELL))
	for j in IconAtlas.SHAPES.size():
		var k := IconAtlas.NAMES.size() + j
		var shape := _shape(IconAtlas.SHAPES[j])
		shape = PaletteMath.remap_image(shape, _palette_of(SHAPE_PALETTES[IconAtlas.SHAPES[j]]), {})
		sheet.blit_rect(shape, Rect2i(0, 0, IconAtlas.CELL, IconAtlas.CELL), Vector2i((k % IconAtlas.COLS) * IconAtlas.CELL, (k / IconAtlas.COLS) * IconAtlas.CELL))
	var err := sheet.save_png(ProjectSettings.globalize_path(IconAtlas.PATH))
	if err != OK:
		push_error("save atlas: %s" % error_string(err))
		return false
	print("RENDERED ", IconAtlas.PATH)
	return true

## A solid shape cell, analytic with 4x4 supersampling. "disc": an ink circle. "backing": the theme's Panel box (diner_cream
## at alpha 0.95, ink border, rounded) scaled from its 56 px cell to the atlas cell. "gear": an ink cog, 8 teeth, warm_white
## hub hole. "stick_ring": ink disc at 25% alpha with a 6 px warm_white rim. "stick_knob": warm_white disc at 80% alpha.
## "guide_arrow": an apron_white down arrow with a 4 px ink outline (tinted at draw time). All inset PAD px.
static func _shape(shape: StringName) -> Image:
	var cell := IconAtlas.CELL
	var out := Image.create_empty(cell, cell, false, Image.FORMAT_RGBA8)
	var half := float(cell - 2 * IconAtlas.PAD) * 0.5
	for y in cell:
		for x in cell:
			var a := 0.0
			var rgb := Vector3.ZERO
			for sy in 4:
				for sx in 4:
					var p := Vector2(float(x) + (float(sx) + 0.5) / 4.0, float(y) + (float(sy) + 0.5) / 4.0) - Vector2(cell, cell) * 0.5
					var s := _sample(shape, p, half)
					if s.w <= 0.0:
						continue
					a += s.w
					rgb += Vector3(s.x, s.y, s.z) * s.w
			if a > 0.0:
				rgb /= a
				out.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, a / 16.0))
	return out

## One sub-sample of a shape at p (centre-relative px): Vector4(r, g, b, alpha), alpha 0 outside the shape.
static func _sample(shape: StringName, p: Vector2, half: float) -> Vector4:
	var cream := Palette.color(&"diner_cream")
	var ink := Palette.color(&"ink")
	var white := Palette.color(&"warm_white")
	match shape:
		&"backing":
			var scale := (half * 2.0) / 56.0
			var radius := 20.0 * scale
			var q := p.abs() - Vector2(half - radius, half - radius)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
			if d > 0.0:
				return Vector4()
			if d < -4.0 * scale:
				return Vector4(cream.r, cream.g, cream.b, 0.95)
			return Vector4(ink.r, ink.g, ink.b, 1.0)
		&"disc":
			if p.length() > half:
				return Vector4()
			return Vector4(ink.r, ink.g, ink.b, 1.0)
		&"gear":
			var r := p.length()
			var ang := atan2(p.y, p.x)
			# 8 teeth: the outer radius is half at a tooth (cos 8a > 0) and 0.74 half between teeth
			var outer := half if cos(8.0 * ang) > -0.1 else half * 0.78
			if r > outer or r > half:
				return Vector4()
			if r < half * 0.3:
				return Vector4(white.r, white.g, white.b, 1.0)
			return Vector4(ink.r, ink.g, ink.b, 1.0)
		&"stick_ring":
			var r2 := p.length()
			if r2 > half:
				return Vector4()
			if r2 > half - 6.0:
				return Vector4(white.r, white.g, white.b, 1.0)
			return Vector4(ink.r, ink.g, ink.b, 0.25)
		&"stick_knob":
			if p.length() > half:
				return Vector4()
			return Vector4(white.r, white.g, white.b, 0.8)
		&"guide_arrow":
			var d_out := _arrow_sd(p, half)
			if d_out > 0.0:
				return Vector4()
			var ap := Palette.color(&"apron_white")
			if d_out < -4.0:
				return Vector4(ap.r, ap.g, ap.b, 1.0)
			return Vector4(ink.r, ink.g, ink.b, 1.0)
	return Vector4()

## Signed distance (approx, px) to a down-pointing arrow: a shaft over a triangular head, fitted in +-half.
static func _arrow_sd(p: Vector2, half: float) -> float:
	var shaft := Vector2(half * 0.28, half * 0.42)
	var q := (p - Vector2(0.0, -half * 0.5)).abs() - shaft
	var d_shaft := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
	# head: triangle with base y = -0.05 half (half width 0.95 half) and tip y = +half
	var top := -half * 0.08
	var t := clampf((p.y - top) / (half - top), 0.0, 1.0)
	var hw := half * 0.95 * (1.0 - t)
	var d_head := maxf(absf(p.x) - hw, maxf(top - p.y, p.y - half)) * 0.8
	return minf(d_shaft, d_head)

static func _box_half(src: Image) -> Image:
	var w := src.get_width() / 2
	var h := src.get_height() / 2
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var rgb := Vector3.ZERO
			var asum := 0.0
			for d in 4:
				var c := src.get_pixel(x * 2 + (d & 1), y * 2 + (d >> 1))
				rgb += Vector3(c.r, c.g, c.b) * c.a
				asum += c.a
			if asum <= 0.0:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				rgb /= asum
				out.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, asum / 4.0))
	return out

static func _palette_of(names: Array) -> PackedColorArray:
	var out := PackedColorArray()
	for n in names:
		out.append(Palette.color(n))
	return out

static func _palette_for(icon: String) -> PackedColorArray:
	match icon:
		"heart":
			return _palette_of([&"enemy_red", &"enemy_maroon", &"ink"])
		"moon":
			return _palette_of([&"warm_white", &"diner_cream", &"traveler_beige"])
	var names: Array = []
	for n in Palette.NAMES:
		var t := String(n)
		if t.begins_with("enemy_") or t.begins_with("traveler_"):
			continue
		if icon == "card_carry_capacity" and t.begins_with("gold"):
			continue
		names.append(n)
	return _palette_of(names)

## name, a builder returning the subject root (added to the stage by _render), the view centre, the ortho size.
func _subjects() -> Array:
	return [
		{"name": "card_hero_damage", "fit": true, "build": _knife_big, "center": Vector3(0, 0.0, 0), "size": 2.6},
		{"name": "card_attack_speed", "fit": true, "build": _knife_fan, "center": Vector3(0, 0.0, 0), "size": 2.8},
		{"name": "card_move_speed", "build": _runner, "center": Vector3(0, 0.95, 0), "size": 2.1},
		{"name": "card_carry_capacity", "fit": true, "build": _steak_stack, "center": Vector3(0, 0.3, 0), "size": 1.6},
		{"name": "card_gold_per_steak", "fit": true, "build": _menu, "center": Vector3(0, 0.0, 0), "size": 2.0},
		{"name": "card_archer", "build": _portrait.bind(ARCHER), "center": Vector3(0, 1.15, 0), "size": 1.4},
		{"name": "card_tank", "build": _portrait.bind(TANK), "center": Vector3(0, 1.15, 0), "size": 1.4},
		{"name": "coin", "fit": true, "build": _coin, "center": Vector3(0, 0.0, 0), "size": 1.2},
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
