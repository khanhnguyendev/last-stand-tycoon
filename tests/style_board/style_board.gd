extends SceneTree
## S4 style board (D-183): one staging scene in the real game camera, with one of three CC0 character sets.
## Run WITH rendering (not --headless), like tests/sim/capture.gd:
## "$GODOT" --path . --resolution 720x1280 -s res://tests/style_board/style_board.gd -- --set=a --out=docs/review/media/s4_style_board/set_a.png
## --closeup (run at --resolution 1280x720): a low 3/4 view of the lineup instead of the game camera, saved to --out.
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
}
const ROLES := ["hero", "traveler1", "traveler2", "archer", "tank", "boar"]

var _args := {}
var _vis: Dictionary
var _lineup_z := -6.8

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
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
	_build_environment()
	_build_ground(map_layout)
	if not _args.has("closeup"):  # the diner would block the low closeup camera
		_build_diner(map_layout)
	_build_props(map_layout)
	var players: Array = _build_lineup(set_id)
	var cam := Camera3D.new()
	var vp := root.get_visible_rect().size
	camera_math.apply_lens(cam, bal.ui, vp.x / vp.y)  # D-145
	cam.current = true
	root.add_child(cam)
	# Focus: between the lineup (z = -6.8) and the diner (z = 0), as the game camera would frame a hero there.
	cam.global_transform = camera_math.camera_transform(camera_math.focus_for(Vector2(0.0, -2.6)), bal.ui)
	if _args.has("closeup"):  # NOT the game camera: a low 3/4 view of the lineup for judging silhouettes (run at 1280x720)
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = 32.0
		cam.global_transform = Transform3D(Basis(), Vector3(0.0, 3.4, _lineup_z + 9.0)).looking_at(Vector3(0.0, 0.7, _lineup_z), Vector3.UP)
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

# --- staging -----------------------------------------------------------------------------------

func _build_environment() -> void:  # same sun / ambient / background as world.gd
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = false
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = _vis.ground
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
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
		var wrap := _fit(info[0], info[1], role)
		var holder := Node3D.new()
		holder.name = role + "_holder"
		holder.position = Vector3((i - 2.5) * 1.5, 0.0, _lineup_z)
		root.add_child(holder)
		holder.add_child(wrap)
		if role == "boar" and set_id != "a":
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
		if set_id == "c" and role == "archer":
			if not _attach(model, "handslot.r", "c/crossbow_2handed.gltf"):
				push_warning("no handslot.r for the crossbow")
		if set_id == "c" and role == "tank":
			if not _attach(model, "handslot.l", "c/shield_badge.gltf"):
				push_warning("no handslot.l for the shield")
	return players

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
	for set_id in ["a", "b", "c"]:
		var spec: Dictionary = SETS[set_id]
		md += "## Set %s\n\n| role | model | idle | run | attack | hit | death |\n|---|---|---|---|---|---|---|\n" % spec.label
		for role in ROLES:
			var file: String = spec[role][0]
			var names := _anim_names(file)
			md += "| %s | %s | %s | %s | %s | %s | %s |\n" % [role, file.get_file(),
				_match(names, "^(unarmed_)?idle$|^idle$", "lie|sit|jump|2h|ranged|pose|hold"),
				_match(names, "run|sprint"),
				_match(names, "attack|punch|shoot|chop|slice|stab|kick|melee", "ranged_(aim|reload)|2h_ranged"),
				_match(names, "(^|_)hit|recievehit|receivehit|block_hit"),
				_match(names, "death|^die$|defeat", "pose")]
			detail += "### Set %s, %s (%s)\n%s\n\n" % [set_id.to_upper(), role, file.get_file(), ", ".join(names) if not names.is_empty() else "(none)"]
		md += "\n"
	md += "Set C has no cook: the hero is the Barbarian. Set C's Quaternius Pig is the same file and animations as set B.\n"
	md += "Set A's characters share one animation library (character-a..r); the table lists the specific model used.\n\n## Full animation names per model\n\n" + detail
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(path_).get_base_dir())
	var f := FileAccess.open(ProjectSettings.globalize_path("res://").path_join(path_), FileAccess.WRITE)
	f.store_string(md)
	f.close()
	print("wrote ", path_)
