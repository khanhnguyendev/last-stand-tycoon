extends SceneTree
## S4 style board (D-183): one staging scene in the real game camera, with one of three CC0 character sets.
## Run WITH rendering (not --headless), like tests/sim/capture.gd:
## "$GODOT" --path . --resolution 720x1280 -s res://tests/style_board/style_board.gd -- --set=a --out=docs/review/media/s4_style_board/set_a.png
## --closeup (run at --resolution 1280x720): a low 3/4 view of the lineup instead of the game camera, saved to --out.
## --boars (run at --resolution 1280x720): three boars side by side (C tinted farm Pig, cute-monster Pig untinted, cute-monster Pig tinted + tusks + ridge).
## --night (any --set): the same framing under a dim blue-tinted sun and ambient (the game has no night lighting yet; world.gd's sun / ambient are day-only).
## --focus_z=-6.8 (game camera): follows a hero standing at the lineup (the default -2.6 frames the whole yard, lineup at the top edge).
## --lineup_z=-9.5: moves the lineup north, out from behind the diner roof, which hides the front (tusks) of anything at the default -6.8.
## --turnaround (run at --resolution 600x600; set e): the procedural boar from front, 3/4, side and top, each 300 px, side by side in --out.
## --remapped (any --set, S4 Task 3): swaps every albedo texture for its palette-remapped atlas in art/palette/atlas/ (matched by
## texture path / file name), to judge the D-188 remap on the real scene.
## --visual=<scene path> (S4 Task 6; run at --resolution 1280x720): that ActorVisual scene alone, side-on (--cam_x=-7 sees the hero's right, throwing, side; --attack_wait=<s> after fire). --out = idle shot,
## --out_run = the same visual at set_motion(1) with attack() fired. --attack_clip=<name> overrides its attack clip.
## --variants (with --visual=<traveler_visual.tscn>; S4 Task 8): all six traveler looks in a row, side by side, walking toward the camera; --out = that shot.
## --no_run (with --visual): --out_run is the attack from standing still (the Archer's attack only plays while standing).
## --face=x,z turns the visual (default 0,1; --variants default -1,0 = toward the camera).
## --anims=<md path> (any --set) writes the animation inventory for all three sets and quits without rendering.
## Candidate assets live in assets/_candidates/ (gitignored, CC0). A -s script compiles before the autoloads exist,
## so project scripts are load()ed at run time and used untyped, like capture.gd.

const C := "res://assets/_candidates/"
const ENV := C + "env/"
## Role -> [file, target height m]. "extra" entries are attached / added by _build_set.
const SETS := {
	"a": {
		"label": "A: Kenney Blocky Characters + Cube Pets hog",
		"hero": ["a/character-i.glb", 1.6], "traveler1": ["a/character-c.glb", 1.5], "traveler2": ["a/character-q.glb", 1.5],
		"archer": ["a/character-m.glb", 1.6], "tank": ["a/character-h.glb", 1.6], "boar": ["a/pet/animal-hog.glb", 0.95],
	},
	"b": {
		"label": "B: Quaternius Ultimate Animated Characters + Farm Pig",
		"hero": ["b/Chef_Male.fbx", 1.6], "traveler1": ["b/Casual_Male.fbx", 1.5], "traveler2": ["b/Casual2_Female.fbx", 1.5],
		"archer": ["b/Elf.fbx", 1.6], "tank": ["b/Knight_Male.fbx", 1.6], "boar": ["b/Pig.fbx", 0.95],
	},
	"c": {
		"label": "C: KayKit Adventurers (+ Quaternius Pig)",
		"hero": ["c/Barbarian.glb", 1.6], "traveler1": ["c/Rogue.glb", 1.5], "traveler2": ["c/Mage.glb", 1.5],
		"archer": ["c/Rogue_Hooded.glb", 1.6], "tank": ["c/Knight.glb", 1.6], "boar": ["c/Pig.fbx", 0.95],
	},
	"d": {
		"label": "D: KayKit Adventurers, chef-hat Barbarian cook + Quaternius cute-monster Pig",
		"hero": ["c/Barbarian.glb", 1.6], "traveler1": ["c/Rogue.glb", 1.5], "traveler2": ["c/Mage.glb", 1.5],
		"archer": ["c/Rogue_Hooded.glb", 1.6], "tank": ["c/Knight.glb", 1.6], "boar": ["d/Pig.fbx", 0.9],
	},
	"e": {
		"label": "E: set D + procedural Boar, muted travelers, hero ring",
		"hero": ["c/Barbarian.glb", 1.6], "traveler1": ["c/Rogue.glb", 1.5], "traveler2": ["c/Mage.glb", 1.5],
		"archer": ["c/Rogue_Hooded.glb", 1.6], "tank": ["c/Knight.glb", 1.6], "boar": ["proto", 0.95],
	},
}
const ROLES := ["hero", "traveler1", "traveler2", "archer", "tank", "boar"]

var _args := {}
var _vis: Dictionary
var _lineup_z := -6.8

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_lineup_z = float(_args.get("lineup_z", _lineup_z))
	_run.call_deferred()

func _run() -> void:
	if _args.has("anims"):
		_write_anims(String(_args.anims))
		quit(0)
		return
	var set_id: String = _args.get("set", "a")
	if not SETS.has(set_id):
		push_error("bad --set %s" % set_id)
		quit(2)
		return
	var camera_math = load("res://core/camera_math.gd")
	var map_layout = load("res://core/map_layout.gd")
	_vis = load("res://world/visuals.gd").COLORS
	var bal = root.get_node("Balance")
	bal.reset()
	_build_environment(_args.has("night"))
	_build_ground(map_layout)
	if _args.has("turnaround"):
		await _turnaround()
		return
	if _args.has("visual"):
		await _visual(String(_args.visual))
		return
	if not _args.has("closeup") and not _args.has("boars"):  # the diner would block the low closeup camera
		_build_diner(map_layout)
	if not _args.has("boars"):
		_build_props(map_layout)
	var players: Array = _build_boars() if _args.has("boars") else _build_lineup(set_id)
	var cam := Camera3D.new()
	var vp := root.get_visible_rect().size
	camera_math.apply_lens(cam, bal.ui, vp.x / vp.y)  # D-145
	cam.current = true
	root.add_child(cam)
	# Focus: between the lineup (z = -6.8) and the diner (z = 0), as the game camera would frame a hero there.
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(Vector2(0.0, float(_args.get("focus_z", -2.6)))), bal.ui)
	if _args.has("closeup") or _args.has("boars"):  # NOT the game camera: a low 3/4 view of the lineup for judging silhouettes (run at 1280x720)
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = 32.0
		cam.global_transform = Transform3D(Basis(), Vector3(0.0, 3.4, _lineup_z + 9.0)).looking_at(Vector3(0.0, 0.7, _lineup_z), Vector3.UP)
	if _args.has("remapped"):
		_remap_textures()
	var t0 := Time.get_ticks_msec()  # idle animations run for 1 s before capture
	while Time.get_ticks_msec() - t0 < 1000:
		await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	var out: String = _args.get("out", "docs/review/media/s4_style_board/set_%s.png" % set_id)
	var path := out if out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if img.save_png(path) != OK:
		push_error("save failed")
		quit(1)
		return
	print("saved ", out, " ", img.get_size(), " idle players: ", players.size())
	quit(0)

# --- ActorVisual review (S4 Task 6) ---

func _save(img: Image, out: String) -> bool:
	var path := out if out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if img.save_png(path) != OK:
		push_error("save failed")
		quit(1)
		return false
	print("saved ", out, " ", img.get_size())
	return true

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame

func _visual(scene_path: String) -> void:
	if _args.has("variants"):
		await _variants(scene_path)
		return
	var v = load(scene_path).instantiate()
	if _args.has("attack_clip"):
		v.attack_clip = StringName(_args.attack_clip)
	root.add_child(v)
	v.position = Vector3(0, 0, _lineup_z)
	var cam := Camera3D.new()
	cam.current = true
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 32.0
	root.add_child(cam)
	cam.global_transform = Transform3D(Basis(), Vector3(float(_args.get("cam_x", -7.0)), 1.5, _lineup_z)).looking_at(Vector3(0.0, 0.85, _lineup_z), Vector3.UP)
	var fd := String(_args.get("face", "0,1")).split(",")
	v.face(Vector3(float(fd[0]), 0, float(fd[1])))
	await _wait(1.0)
	if not _save(root.get_texture().get_image(), String(_args.get("out", "docs/review/media/s4/task06/base_idle.png"))):
		return
	if not _args.has("no_run"):
		v.set_motion(1.0)
	await _wait(0.6)
	v.attack()
	await _wait(float(_args.get("attack_wait", 0.45)))
	if not _save(root.get_texture().get_image(), String(_args.get("out_run", "docs/review/media/s4/task06/base_run_attack.png"))):
		return
	quit(0)

## The six traveler looks side by side (S4 Task 8), each walking toward the camera at the Walking_A blend.
func _variants(scene_path: String) -> void:
	var tv = load("res://art/characters/traveler_variants.gd")
	var scene: PackedScene = load(scene_path)
	for i in 6:
		var v = scene.instantiate()
		root.add_child(v)
		v.position = Vector3(0, 0, _lineup_z + (i - 2.5) * float(_args.get("spacing", 1.15)))
		tv.apply(v, i)
		v.set_motion(0.5)
		var fd := String(_args.get("face", "-1,0")).split(",")
		v.face(Vector3(float(fd[0]), 0, float(fd[1])))
	var cam := Camera3D.new()
	cam.current = true
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 32.0
	root.add_child(cam)
	cam.global_transform = Transform3D(Basis(), Vector3(float(_args.get("cam_x", -9.0)), 1.5, _lineup_z)).looking_at(Vector3(0.0, 0.85, _lineup_z), Vector3.UP)
	await _wait(1.2)
	if _save(root.get_texture().get_image(), String(_args.get("out", "docs/review/media/s4/task08/travelers.png"))):
		quit(0)

# --- remap review (S4 Task 3) ---

const ATLAS := "res://art/palette/atlas/"
const KIT_PACK := {"td": "kenney-tower-defense", "castle": "kenney-castle", "town": "kenney-fantasy-town",
	"food": "kenney-food", "plat": "kenney-platformer"}

## The remapped atlas file for a source texture, or "" when none matches.
func _atlas_for(tex: Texture2D) -> String:
	var path := tex.resource_path
	var file := path.get_file()
	if file == "" or "::" in path:
		file = String(tex.resource_name) + ".png"
	if file.begins_with("colormap"):
		var rel := path.get_base_dir()  # .../env/<kit>/Textures
		var kit := rel.get_base_dir().get_file()
		if KIT_PACK.has(kit):
			return ATLAS + KIT_PACK[kit] + "__colormap.png"
		if kit.begins_with("kenney-"):  # the real assets/<pack>/Textures layout
			return ATLAS + kit + "__colormap.png"
		return ""
	if file == "restaurantbits_texture.png":
		return ATLAS + "kaykit-restaurant__restaurantbits_texture.png"
	var i := file.to_lower().find("_texture")
	if i >= 0:
		var who := file.to_lower().substr(0, i).split("_")[-1]  # Rogue_Hooded_rogue_texture.png -> rogue
		return ATLAS + "kaykit-adventurers__%s_texture.png" % who
	return ""

func _remap_textures() -> void:
	var swapped := 0
	var skipped := {}
	var cache := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if not (mat is BaseMaterial3D) or (mat as BaseMaterial3D).albedo_texture == null:
				continue
			var tex := (mat as BaseMaterial3D).albedo_texture
			var atlas := _atlas_for(tex)
			if atlas == "" or not ResourceLoader.exists(atlas):
				skipped[tex.resource_path if tex.resource_path != "" else String(tex.resource_name)] = true
				continue
			var key := "%d|%s" % [mat.get_instance_id(), atlas]
			if not cache.has(key):
				var d := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.albedo_texture = load(atlas)
				cache[key] = d
			m.set_surface_override_material(i, cache[key])
			swapped += 1
	print("remapped surfaces: ", swapped, " unmatched textures: ", skipped.keys())

# --- staging -----------------------------------------------------------------------------------

func _build_environment(night := false) -> void:  # same sun / ambient / background as world.gd
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	if night:  # approximation: moonlight
		sun.light_color = Color(0.55, 0.62, 1.0)
		sun.light_energy = 0.55
	sun.shadow_enabled = false
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = _vis.ground
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	if night:
		env.environment.background_color = Color(_vis.ground).darkened(0.65) * Color(0.7, 0.8, 1.2)
		env.environment.ambient_light_color = Color(0.30, 0.36, 0.62)
		env.environment.ambient_light_energy = 0.8
	root.add_child(env)

func _flat(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	return mi

func _build_ground(ml) -> void:
	_flat(Vector3(80, 0.02, 80), _vis.ground, Vector3(0, -0.01, 0))
	_flat(Vector3(48, 0.02, 2.0), _vis.road, Vector3(0, 0.01, ml.ROAD_Z))
	# the north lane strip, from the lane's far end to the diner wall
	var p: Array = ml.LANE_PATHS["north"]
	var z0: float = p[0].y
	var z1: float = p[p.size() - 1].y
	_flat(Vector3(2.0, 0.03, absf(z1 - z0)), _vis.lane, Vector3(p[0].x, 0.015, (z0 + z1) * 0.5))

func _kit(file: String, pos: Vector3, yaw_deg := 0.0, scl := Vector3.ONE) -> Node3D:
	var n: Node3D = load(ENV + (file if "/" in file else "town/" + file)).instantiate()
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	n.scale = scl
	root.add_child(n)
	return n

func _build_diner(ml) -> void:
	# ~8 x 8 m footprint, ~3 m tall: a ring of fantasy-town wall pieces at 2x, a door + windows on the south
	# (counter) face, and a two-row gable roof of roof.glb pieces.
	var s := 2.0
	var xs := [-3.0, -1.0, 1.0, 3.0]
	for i in 4:
		var u: float = xs[i]
		var south := "wall-wood-door.glb" if i == 1 else "wall-wood-window-glass.glb"
		_kit(south, Vector3(u, 0, 4), -90, Vector3.ONE * s)
		_kit("wall-wood-window-small.glb" if i % 2 == 0 else "wall-wood.glb", Vector3(u, 0, -4), 90, Vector3.ONE * s)
		_kit("wall-wood-window-glass.glb" if i % 2 == 1 else "wall-wood.glb", Vector3(4, 0, u), 0, Vector3.ONE * s)
		_kit("wall-wood-window-glass.glb" if i % 2 == 0 else "wall-wood.glb", Vector3(-4, 0, u), 180, Vector3.ONE * s)
	var roof_s := Vector3(2.0, 0.8, 2.0)
	for i in 4:
		var u: float = xs[i]
		_kit("roof.glb", Vector3(u, 2.0, 3.0), 0, roof_s)    # sloping rows: tweak yaw per visual check
		_kit("roof.glb", Vector3(u, 2.0, 1.0), 0, roof_s)
		_kit("roof.glb", Vector3(u, 2.0, -1.0), 180, roof_s)
		_kit("roof.glb", Vector3(u, 2.0, -3.0), 180, roof_s)
	# roadside diner read: red stall awning as the order counter, a banner on the south face
	_kit("stall-red.glb", ml.to3(ml.COUNTER), 0, Vector3.ONE * 1.6)
	_kit("banner-red.glb", Vector3(-1.0, 1.2, 4.15), 0, Vector3.ONE * 1.5)

func _build_props(ml) -> void:
	# tower: round tower-defense pieces stacked, ~2.3 m, at tower_nw
	var tp: Vector2 = ml.TOWER_SPOTS["tower_nw"]
	var y := 0.0
	var ts := 0.75
	for piece in [["td_base", 0.21], ["td_bottom-a", 0.6], ["td_middle-a", 0.6], ["td_top-a", 0.5], ["td_roof-a", 1.15]]:
		var f: String = {"td_base": "tower-round-base", "td_bottom-a": "tower-round-bottom-a", "td_middle-a": "tower-round-middle-a",
			"td_top-a": "tower-round-top-a", "td_roof-a": "tower-round-roof-a"}[piece[0]]
		var n: Node3D = load(ENV + "td/%s.glb" % f).instantiate()
		n.position = Vector3(tp.x, y, tp.y)
		n.scale = Vector3.ONE * ts
		root.add_child(n)
		y += float(piece[1]) * ts
	# fence at fence_n: a short run of castle wood-fence pieces across the lane (the kit piece is ~1 m wide)
	var fp: Vector2 = ml.fence_spot("north")
	for dx in [-1.0, 0.0, 1.0]:
		var f := _kit("castle/wall-narrow-wood-fence.glb", Vector3(fp.x + dx * 1.0, 0, fp.y), 90, Vector3.ONE * 0.8)
		f.name = "Fence"
	# 3 steaks (~0.45 m) at the counter drop, 3 coins (~0.3 m) at the gold pile
	for p in [Vector2(1.8, 5.9), Vector2(2.5, 6.2), Vector2(3.2, 5.8)]:
		_kit("food/meat-cooked.glb", ml.to3(p), 20.0 * p.x, Vector3.ONE * 0.95)
	for p in [Vector2(-3.0, 6.2), Vector2(-2.4, 6.5), Vector2(-1.8, 6.1)]:
		var coin := _kit("plat/coin-gold.glb", ml.to3(p, 0.1), 0, Vector3.ONE * 0.75)
		coin.rotation_degrees.x = -90.0  # lying flat, face up

# --- characters --------------------------------------------------------------------------------

## Mesh bounds (rest pose) of a node in its own local space.
static func _bounds(n: Node) -> AABB:
	var r := AABB()
	var first := true
	var stack: Array = [[n, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var t: Transform3D = it[1]
		if node is Node3D and node != n:
			t = t * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var bb: AABB = t * (node as MeshInstance3D).mesh.get_aabb()
			r = bb if first else r.merge(bb)
			first = false
		for c in node.get_children():
			stack.append([c, t])
	return r

## Instances `file`, scales it to `height` metres, stands it on y = 0, centred in xz. Returns the wrapper.
func _fit(file: String, height: float, name_: String) -> Node3D:
	var model: Node3D = load(C + file).instantiate()
	var bb := _bounds(model)
	var s := height / bb.size.y
	var wrap := Node3D.new()
	wrap.name = name_
	wrap.add_child(model)
	model.position = Vector3(-(bb.position.x + bb.size.x * 0.5), -bb.position.y, -(bb.position.z + bb.size.z * 0.5))
	wrap.scale = Vector3.ONE * s
	wrap.set_meta("fit", {"s": s, "bb": bb})
	return wrap

func _play_idle(node: Node) -> int:
	var n := 0
	for ap in node.find_children("*", "AnimationPlayer", true, false):
		var pick := ""
		for want in ["Idle", "idle", "CharacterArmature|Idle", "Armature|Idle"]:
			if (ap as AnimationPlayer).has_animation(want):
				pick = want
				break
		if pick != "":
			(ap as AnimationPlayer).get_animation(pick).loop_mode = Animation.LOOP_LINEAR
			(ap as AnimationPlayer).play(pick)
			n += 1
	return n

func _attach(model_root: Node, bone: String, file: String, rot := Vector3.ZERO) -> bool:
	var skels := model_root.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty() or (skels[0] as Skeleton3D).find_bone(bone) < 0:
		return false
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skels[0].add_child(ba)
	var w: Node3D = load(C + file).instantiate()
	w.rotation_degrees = rot
	ba.add_child(w)
	return true

func _recolor_pig(wrap: Node3D) -> void:
	var dark := Color("6e2118")
	for mi in wrap.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat is BaseMaterial3D:
				var c: Color = (mat as BaseMaterial3D).albedo_color
				if c.r >= 0.6:  # the pink body; keep the dark eyes / hooves as they are
					var d := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					d.albedo_color = dark
					d.albedo_texture = null
					m.set_surface_override_material(i, d)

## The Quaternius FBX "Skin" material imports near-black (albedo ~0.10), so faces and hands render black.
## The board lifts it to a skin tone so the set is judged fairly; a real pipeline would fix it at import.
func _fix_skin(wrap: Node3D) -> void:
	for mi in wrap.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat is BaseMaterial3D and String(mat.resource_name) == "Skin" and (mat as BaseMaterial3D).albedo_color.v < 0.3:
				var d := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.albedo_color = Color("e6b58f")
				m.set_surface_override_material(i, d)

func _add_tusks(wrap: Node3D, height: float) -> void:
	var fit: Dictionary = wrap.get_meta("fit")
	var bb: AABB = fit.bb
	var s: float = fit.s
	var front: float = (bb.size.z * 0.5) * s  # snout (model faces +z after the yaw fix in _build_lineup)
	for sx in [-1.0, 1.0]:
		var t := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.035
		cone.height = 0.2
		t.mesh = cone
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("fff6e0")
		t.material_override = mat
		t.position = Vector3(sx * 0.11, height * 0.30, front * 0.82 - 0.0)
		t.rotation_degrees = Vector3(-35.0, 0.0, -sx * 15.0)  # up and forward, flaring out
		wrap.get_parent().add_child(t)

func _build_lineup(set_id: String) -> Array:
	var spec: Dictionary = SETS[set_id]
	var players: Array = []
	for i in ROLES.size():
		var role: String = ROLES[i]
		var info: Array = spec[role]
		var holder := Node3D.new()
		holder.name = role + "_holder"
		holder.position = Vector3((i - 2.5) * 1.5, 0.0, _lineup_z)
		root.add_child(holder)
		if info[0] == "proto":  # set E's procedural Boar: tween idle, no AnimationPlayer
			var pb = load("res://tests/style_board/proto_boar.gd")
			var boar: Node3D = pb.build()
			holder.add_child(boar)
			pb.idle(boar)
			print("proto boar mesh instances: ", pb.mesh_count(boar))
			players.append(1)
			continue
		var wrap := _fit(info[0], info[1], role)
		holder.add_child(wrap)
		if role == "boar" and set_id == "d":
			_dress_cute_boar(wrap, holder, info[1], true)
		elif role == "boar" and set_id != "a":
			_recolor_pig(wrap)
			_add_tusks(wrap, info[1])
		var model: Node = wrap.get_child(0)
		if set_id == "b" and role != "boar":
			_fix_skin(wrap)
		players.append(_play_idle(model))
		if set_id == "b" and role == "hero":
			var hat := _fit("b/Chef_Hat.fbx", 1.6, "hat")  # same rig as the chef: shares its fit so it sits on the head
			var chef_fit: Dictionary = wrap.get_meta("fit")
			var hat_model: Node3D = load(C + "b/Chef_Hat.fbx").instantiate()
			hat_model.position = (wrap.get_child(0) as Node3D).position
			wrap.add_child(hat_model)
			hat.free()
			_fix_skin(wrap)
			_play_idle(hat_model)
			wrap.set_meta("fit", chef_fit)
		if (set_id == "d" or set_id == "e") and role == "hero":
			_dress_cook(model)
		if set_id == "e" and role == "hero":
			_hero_ring(holder)
		if set_id == "e" and role.begins_with("traveler"):
			_mute_traveler(model)
		if set_id == "c" and role == "archer":
			if not _attach(model, "handslot.r", "c/crossbow_2handed.gltf"):
				push_warning("no handslot.r for the crossbow")
		if set_id == "c" and role == "tank":
			if not _attach(model, "handslot.l", "c/shield_badge.gltf"):
				push_warning("no handslot.l for the shield")
	return players

# --- set D: chef hero, cute-monster Boar -----------------------------------------------------------

const D_BOAR_YAW := 0.0  # degrees about y so the cute-monster Pig faces +z (tuned from the closeup)

## Barbarian -> diner cook: hide the bear hood, cape and every held item, add a procedural chef hat on the head bone,
## a white apron over the torso (material_overlay: the clothes share one atlas), and a frying pan in handslot.r.
func _dress_cook(model: Node) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.get_parent() is BoneAttachment3D:  # Barbarian_Hat / _Cape / axes / shield / mug: all rest-pose clutter
			m.visible = false
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var body := skel.get_node("Barbarian_Body") as MeshInstance3D
	var apron := StandardMaterial3D.new()
	apron.albedo_color = Color(1, 1, 1, 0.82)
	apron.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body.material_overlay = apron
	# chef hat: a cylinder band + a puffy sphere, on a BoneAttachment3D at the head bone ("head" in the KayKit rig)
	var ba := BoneAttachment3D.new()
	ba.name = "ChefHat"
	ba.bone_name = "head"
	skel.add_child(ba)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("fbfbf6")
	var band := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.40
	cyl.bottom_radius = 0.37
	cyl.height = 0.42
	band.mesh = cyl
	band.material_override = white
	band.position = Vector3(0, HAT_Y, 0)
	ba.add_child(band)
	var puff := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.46
	sph.height = 0.78
	puff.mesh = sph
	puff.material_override = white
	puff.position = Vector3(0, HAT_Y + 0.38, 0)
	ba.add_child(puff)
	# pan
	var hand := skel.get_node("handslot_r") as BoneAttachment3D
	var pan: Node3D = load(C + "d/pan_A.gltf").instantiate()
	pan.scale = Vector3.ONE * PAN_S
	pan.rotation_degrees = PAN_ROT
	pan.position = PAN_POS
	hand.add_child(pan)

## Set E: a flat warm-white ring decal under the hero (thin torus, radius 0.7 m, alpha 0.6, unshaded).
func _hero_ring(holder: Node3D) -> void:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.64
	t.outer_radius = 0.76   # centre line 0.7 m, 0.12 m wide
	t.rings = 48
	ring.mesh = t
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.953, 0.769, 0.6)  # #fff3c4
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	ring.scale = Vector3(1, 0.04, 1)
	ring.position.y = 0.04
	ring.name = "HeroRing"
	holder.add_child(ring)

## Set E: travelers carry no weapons (every handslot prop hidden; hat and cape kept) and are desaturated toward grey-beige with an
## unshaded #9a9488 overlay at alpha 0.45, so they read as secondary next to the hero and guards.
func _mute_traveler(model: Node) -> void:
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.604, 0.580, 0.533, 0.45)
	grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var pa := m.get_parent()
		if pa is BoneAttachment3D and String((pa as BoneAttachment3D).bone_name).begins_with("handslot"):
			m.visible = false  # weapons, books, throwables; the hat and cape stay (clothing)
		else:
			m.material_overlay = grey

## --turnaround: 4 views of the procedural boar, 300 px each (rendered at 600x600 and halved), joined into one image.
func _turnaround() -> void:
	_vis = load("res://world/visuals.gd").COLORS
	_build_environment()
	_flat(Vector3(40, 0.02, 40), _vis.ground, Vector3(0, -0.01, 0))
	var pb = load("res://tests/style_board/proto_boar.gd")
	var boar: Node3D = pb.build()
	root.add_child(boar)
	pb.idle(boar)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.current = true
	root.add_child(cam)
	var target := Vector3(0, 0.5, 0.05)
	var views := [
		[Vector3(0.0, 0.9, 3.6), Vector3.UP],     # front
		[Vector3(2.2, 1.7, 2.6), Vector3.UP],     # 3/4
		[Vector3(3.8, 0.6, 0.0), Vector3.UP],     # side
		[Vector3(0.0, 4.4, 0.8), Vector3(0, 0, -1)],  # top
	]
	var sheet := Image.create(1200, 300, false, Image.FORMAT_RGB8)
	for i in 4:
		cam.global_transform = Transform3D(Basis(), views[i][0]).looking_at(target, views[i][1])
		await process_frame
		await process_frame
		var img := root.get_texture().get_image()
		img.resize(300, 300, Image.INTERPOLATE_LANCZOS)
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(0, 0, 300, 300), Vector2i(i * 300, 0))
	var out: String = _args.get("out", "docs/review/media/s4_style_board/boar_proto_turnaround.png")
	var path := out if out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	sheet.save_png(path)
	print("saved ", out, " mesh instances: ", pb.mesh_count(boar))
	quit(0)

const HAT_Y := 1.0
const PAN_S := 0.8
const PAN_ROT := Vector3(0, 0, 0)
const PAN_POS := Vector3(0, 0, 0)

## Quaternius cute-monster Pig as a cute-dangerous Boar: dark brown-red albedo tint (texture kept for the eyes),
## two white cone tusks at the mouth corners, a 3-cone dark-red ridge on the back. `holder` is the lineup node at
## the boar's feet; decorations are children of it (not of the scaled wrapper) so their sizes are metres.
func _dress_cute_boar(wrap: Node3D, holder: Node3D, height: float, tinted: bool) -> void:
	wrap.rotation_degrees.y = D_BOAR_YAW
	if not tinted:
		return
	var tint := Color(0.62, 0.30, 0.25)
	for mi in wrap.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat is BaseMaterial3D:
				var d := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.albedo_color = tint
				m.set_surface_override_material(i, d)
	var fit: Dictionary = wrap.get_meta("fit")
	var s: float = fit.s
	var bb: AABB = fit.bb
	var ext := Vector3(bb.size.x, bb.size.y, bb.size.z) * s
	var half_len := maxf(ext.x, ext.z) * 0.5   # length axis after the yaw fix = z
	var half_w := minf(ext.x, ext.z) * 0.5
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("fff6e0")
	for sx in [-1.0, 1.0]:
		var t := _cone(0.045, 0.2, white)
		t.position = Vector3(sx * half_w * TUSK_X, height * TUSK_Y, half_len * TUSK_Z)
		t.rotation_degrees = Vector3(-30.0, 0.0, -sx * 18.0)
		holder.add_child(t)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("5a0f0f")
	for k in 3:
		var r := _cone(0.085, 0.26 - 0.04 * k, red)
		r.position = Vector3(0, height * RIDGE_Y, half_len * (RIDGE_Z0 - 0.5 * k))
		r.rotation_degrees.x = -12.0  # leaning back (the head faces +z)
		holder.add_child(r)

const TUSK_X := 0.35
const TUSK_Y := 0.3
const TUSK_Z := 0.92
const RIDGE_Y := 0.92
const RIDGE_Z0 := 0.1

func _cone(radius: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = h
	mi.mesh = c
	mi.material_override = mat
	return mi

## --boars: farm Pig tinted (set C) | cute-monster Pig untinted | cute-monster Pig tinted + tusks + ridge.
func _build_boars() -> Array:
	var out: Array = []
	for i in 3:
		var file := "c/Pig.fbx" if i == 0 else "d/Pig.fbx"
		var h := 0.95 if i == 0 else 0.9
		var wrap := _fit(file, h, "boar%d" % i)
		var holder := Node3D.new()
		holder.position = Vector3((i - 1) * 2.0, 0.0, _lineup_z)
		root.add_child(holder)
		holder.add_child(wrap)
		if i == 0:
			_recolor_pig(wrap)
			_add_tusks(wrap, h)
		else:
			_dress_cute_boar(wrap, holder, h, i == 2)
		out.append(_play_idle(wrap.get_child(0)))
	return out

# --- animation inventory -----------------------------------------------------------------------

func _anim_names(file: String) -> Array:
	var n: Node = load(C + file).instantiate()
	var out: Array = []
	for ap in n.find_children("*", "AnimationPlayer", true, false):
		for a in (ap as AnimationPlayer).get_animation_list():
			if a != "RESET":
				out.append(String(a))
	n.free()
	return out

func _match(names: Array, rx: String, ban := "") -> String:
	var r := RegEx.create_from_string("(?i)" + rx)
	var b: RegEx = RegEx.create_from_string("(?i)" + ban) if ban != "" else null
	var hits: Array = []
	for a in names:
		var short: String = String(a).get_slice("|", String(a).get_slice_count("|") - 1)
		if r.search(short) != null and (b == null or b.search(short) == null):
			hits.append(short)
	return ", ".join(hits.slice(0, 4)) if not hits.is_empty() else "NONE"

func _write_anims(path_: String) -> void:
	var md := "# S4 style board: animation inventory (D-183)\n\nGenerated by `tests/style_board/style_board.gd --anims=...` from each model's AnimationPlayer after import.\n"
	md += "Role coverage is a name match (idle / run|sprint / attack|punch|shoot|chop|slice|stab|kick|melee / hit|death|die|defeat).\n\n"
	var detail := ""
	for set_id in ["a", "b", "c", "d", "e"]:
		var spec: Dictionary = SETS[set_id]
		md += "## Set %s\n\n| role | model | idle | run | attack | hit | death |\n|---|---|---|---|---|---|---|\n" % spec.label
		for role in ROLES:
			var file: String = spec[role][0]
			var names := ["idle", "run", "attack", "hit", "death"] if file == "proto" else _anim_names(file)
			md += "| %s | %s | %s | %s | %s | %s | %s |\n" % [role, file.get_file(),
				_match(names, "^(unarmed_)?idle$|^idle$", "lie|sit|jump|2h|ranged|pose|hold"),
				_match(names, "run|sprint"),
				_match(names, "attack|punch|shoot|chop|slice|stab|kick|melee", "ranged_(aim|reload)|2h_ranged"),
				_match(names, "(^|_)hit|recievehit|receivehit|block_hit"),
				_match(names, "death|^die$|defeat", "pose")]
			detail += "### Set %s, %s (%s)\n%s\n\n" % [set_id.to_upper(), role, file.get_file(), ", ".join(names) if not names.is_empty() else "(none)"]
		md += "\n"
	md += "Set E is set D with a procedural Boar (`proto_boar.gd`, Godot primitive meshes; its idle / run / attack / hit / death are Tweens, not AnimationPlayer clips), travelers with props hidden and a grey overlay, and a hero ring decal.\n"
	md += "Set D's hero is the Barbarian with a procedural chef hat, apron overlay and a Restaurant Bits pan (animations as set C); its Boar is the Quaternius cute-monster Pig (idle only).\n"
	md += "Set C has no cook: the hero is the Barbarian. Set C's Quaternius Pig is the same file and animations as set B.\n"
	md += "Set A's characters share one animation library (character-a..r); the table lists the specific model used.\n\n## Full animation names per model\n\n" + detail
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(path_).get_base_dir())
	var f := FileAccess.open(ProjectSettings.globalize_path("res://").path_join(path_), FileAccess.WRITE)
	f.store_string(md)
	f.close()
	print("wrote ", path_)
