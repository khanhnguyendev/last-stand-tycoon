class_name AssetValidator
extends RefCounted
## S4 asset rules (spec 5.4, D-187, D-188, D-196). Static; each check returns problem strings. Editor/test only:
## tools/ is excluded from every web export.
## Every check skips the `assets/_candidates` folder (local style-board sources, gitignored), so local runs match CI.
## PNGs are loaded through ProjectSettings.globalize_path: a plain res:// or user:// load raises an engine error.

const MODEL_EXT := ["glb", "gltf", "fbx", "obj", "png", "jpg", "jpeg"]
const AUDIO_EXT := ["ogg", "mp3", "wav"]
const STRAY_ALLOWED := ["assets", "art", "ui/fonts", "export", "docs", "addons", "tests", ".godot", "build"]
const PLACEHOLDER_RE := "Visuals\\s*\\.\\s*(box|capsule|cylinder|cone|plane)\\s*\\("
## True since Task 13: the last placeholder primitive is gone, so any new one is an error.
const PLACEHOLDERS_ARE_ERRORS := true

static func _files(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = false
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		var path := dir.path_join(sub)
		if path.ends_with("assets/_candidates"):
			continue
		_files(path, out)

static func _load_png(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img

static func _rows(md_path: String) -> Dictionary:
	var rows := {}  # folder -> {sha, count}
	var text := FileAccess.get_file_as_string(md_path)
	for line in text.split("\n"):
		var cols := line.split("|")
		if cols.size() < 8:
			continue
		var folder := cols[2].strip_edges().trim_suffix("/")
		if not folder.begins_with("assets/"):
			continue
		rows[folder.trim_prefix("assets/")] = {"sha": cols[6].strip_edges(), "count": cols[7].strip_edges().to_int()}
	return rows

static func check_licenses(assets_dir: String, licenses_md_path: String) -> Array[String]:
	var out: Array[String] = []
	var rows := _rows(licenses_md_path)
	var d := DirAccess.open(assets_dir)
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".import"):
			out.append("%s: file outside a pack folder" % assets_dir.path_join(f))
	for pack in d.get_directories():
		if pack == "_candidates":
			continue
		var base := assets_dir.path_join(pack)
		var lic := base.path_join("LICENSE.txt")
		if not FileAccess.file_exists(lic):
			out.append("%s: no LICENSE.txt" % base)
			continue
		var lt := FileAccess.get_file_as_string(lic)
		if not ("CC0" in lt or "Creative Commons Zero" in lt):
			out.append("%s: licence is not CC0" % base)
		if not rows.has(pack):
			out.append("%s: no row in ASSET_LICENSES.md" % base)
			continue
		var files: Array = []
		_files(base, files)
		var n := files.filter(func(p): return not String(p).ends_with(".import")).size()
		if n != rows[pack].count:
			out.append("%s: %d files on disk, %d in ASSET_LICENSES.md" % [base, n, rows[pack].count])
		if FileAccess.get_sha256(lic) != rows[pack].sha:
			out.append("%s: LICENSE.txt SHA-256 differs from ASSET_LICENSES.md" % base)
	return out

static func check_palette(dirs: PackedStringArray, hexes: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for dir in dirs:
		var files: Array = []
		_files(dir, files)
		for p in files:
			if not String(p).ends_with(".png"):
				continue
			var img := _load_png(p)
			if img == null:
				out.append("%s: unreadable" % p)
				continue
			var bad := 0
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a8 == 255 and not hexes.has(c.to_html(false)):
						bad += 1
			if bad > 0:
				out.append("%s: %d opaque pixels off-palette" % [p, bad])
	return out

## The enemy_* palette hexes (lowercase, no '#'), as a set.
static func enemy_hexes() -> Dictionary:
	var d := {}
	for n in Palette.NAMES:
		if String(n).begins_with("enemy_"):
			d[Palette.HEX[Palette.index_of(n)]] = true
	return d

## ART_BIBLE R4: no enemy_* colour in any remapped atlas or icon. `skip` lists file names exempt from the rule (the
## HUD heart is the allowed danger/health exception).
static func check_no_enemy_colors(dir: String, enemy_hexes: Dictionary, skip: PackedStringArray = PackedStringArray()) -> Array[String]:
	var out: Array[String] = []
	var files: Array = []
	_files(dir, files)
	for p in files:
		if not String(p).ends_with(".png") or skip.has(String(p).get_file()):
			continue
		var img := _load_png(p)
		if img == null:
			out.append("%s: unreadable" % p)
			continue
		var found := ""
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a8 == 255 and enemy_hexes.has(c.to_html(false)):
					found = c.to_html(false)
					break
			if found != "":
				break
		if found != "":
			out.append("%s: enemy colour %s in an atlas (R4)" % [p, found])
	return out

static func check_texture_sizes(dir: String, max_px: int, skip: PackedStringArray = PackedStringArray()) -> Array[String]:
	var out: Array[String] = []
	var files: Array = []
	_files(dir, files)
	for p in files:
		if skip.has(String(p).get_file()):
			continue
		if String(p).get_extension() in ["png", "jpg", "jpeg"]:
			var img := Image.load_from_file(ProjectSettings.globalize_path(p))
			if img != null and (img.get_width() > max_px or img.get_height() > max_px):
				out.append("%s: %dx%d > %d" % [p, img.get_width(), img.get_height(), max_px])
	return out

static func check_stray_models(root: String, allowed: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	var files: Array = []
	_files(root, files)
	for p in files:
		var rel := String(p).trim_prefix(root).trim_prefix("/")
		if not rel.get_extension().to_lower() in MODEL_EXT:
			continue
		var ok := false
		for a in allowed:
			if rel.begins_with(a + "/"):
				ok = true
		if not ok:
			out.append("%s: model/texture outside allowed folders" % rel)
	return out

static func check_no_placeholders(dirs: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.new()
	re.compile(PLACEHOLDER_RE)
	for dir in dirs:
		var files: Array = []
		_files(dir, files)
		for p in files:
			if String(p).ends_with(".gd") and not String(p).ends_with("world/visuals.gd"):
				if re.search(FileAccess.get_file_as_string(p)) != null:
					out.append("%s: uses a Visuals placeholder primitive" % p)
	return out

static func _visible_chain(n: Node) -> bool:
	var cur := n
	while cur != null:
		if cur is Node3D and not (cur as Node3D).visible:
			return false
		cur = cur.get_parent()
	return true

## Triangles of visible MeshInstance3D surfaces only (a hidden ancestor hides the mesh).
static func count_triangles(node: Node) -> int:
	var n := 0
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.push_front(node)
	for mi in meshes:
		var m := mi as MeshInstance3D
		if m.mesh == null or not _visible_chain(m):
			continue
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			n += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n

## `host` must be inside the tree: scenes hide props in _ready(), which only runs once the instance is added.
static func check_triangles(scenes: PackedStringArray, host: Node) -> Array[String]:
	var out: Array[String] = []
	for p in scenes:
		var b := ArtBudgets.budget_for(p)
		if b < 0:
			continue
		var inst: Node = (load(p) as PackedScene).instantiate()
		host.add_child(inst)
		var t := count_triangles(inst)
		host.remove_child(inst)
		inst.free()
		if t > b:
			out.append("%s: %d triangles > %d" % [p, t, b])
	return out

static func check_animations(lib_path: String, required: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	var lib := load(lib_path) as AnimationLibrary
	if lib == null:
		return ["%s: not an AnimationLibrary" % lib_path]
	for c in required:
		if not lib.has_animation(StringName(c)):
			out.append("%s: missing clip %s" % [lib_path, c])
	return out

static func check_no_physics(dirs: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	for dir in dirs:
		var files: Array = []
		_files(dir, files)
		for p in files:
			if not (String(p).ends_with(".tscn") or String(p).ends_with(".glb") or String(p).ends_with(".gltf")):
				continue
			var ps := load(p) as PackedScene
			if ps == null:
				continue
			var inst := ps.instantiate()
			var physics := inst.find_children("*", "CollisionObject3D", true, false)
			physics.append_array(inst.find_children("*", "CollisionShape3D", true, false))
			physics.append_array(inst.find_children("*", "CollisionPolygon3D", true, false))
			if inst is CollisionObject3D or inst is CollisionShape3D or inst is CollisionPolygon3D or not physics.is_empty():
				out.append("%s: contains physics nodes" % p)
			inst.free()
	return out

## S5 (D-211): every manifest path exists; every audio file under assets_dir is named by the manifest; the total
## size fits the budget; music is at most max_music_s long.
static func check_audio(sfx: Dictionary, music: Dictionary, assets_dir: String, budget: int, max_music_s: float) -> Array[String]:
	var out: Array[String] = []
	var named := {}
	for d in [sfx, music]:
		for id in d:
			var p := String(d[id].path)
			named[p] = true
			if not FileAccess.file_exists(p):
				out.append("audio %s: missing %s" % [id, p])
	var files: Array = []
	_files(assets_dir, files)
	var total := 0
	for f in files:
		if String(f).get_extension().to_lower() in AUDIO_EXT:
			total += FileAccess.get_file_as_bytes(f).size()
			if not named.has(f):
				out.append("audio file not in the manifest: %s" % f)
	if total > budget:
		out.append("audio total %d B > budget %d B" % [total, budget])
	for id in music:
		var p := String(music[id].path)
		if FileAccess.file_exists(p):
			var s := load(p) as AudioStream
			if s != null and s.get_length() > max_music_s:
				out.append("music %s is %.1f s > %.1f s" % [id, s.get_length(), max_music_s])
	return out

static func check_audio_location(root: String) -> Array[String]:
	var out: Array[String] = []
	var files: Array = []
	_files(root, files)
	for f in files:
		var rel := String(f).trim_prefix(root.trim_suffix("/") + "/")
		if rel.get_extension().to_lower() in AUDIO_EXT and not rel.begins_with("assets/") and not rel.begins_with(".godot/") and not rel.begins_with("build/"):
			out.append("audio outside assets/: %s" % f)
	return out

static func validate_project(host: Node = null) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	errors.append_array(check_licenses("res://assets", "res://docs/ASSET_LICENSES.md"))
	errors.append_array(check_palette(PackedStringArray(["res://art/palette/atlas", "res://art/icons"]), Palette.hex_set()))
	var enemy := enemy_hexes()
	errors.append_array(check_no_enemy_colors("res://art/palette/atlas", enemy))
	# The atlas holds the heart, so the R4 check skips it; the per-icon PNGs stay the checked source (Task 16b).
	errors.append_array(check_no_enemy_colors("res://art/icons", enemy, PackedStringArray(["heart.png", "atlas.png"])))
	errors.append_array(check_texture_sizes("res://art", 512))
	errors.append_array(check_texture_sizes("res://art/icons", 256, PackedStringArray(["atlas.png"])))
	errors.append_array(check_stray_models("res://", PackedStringArray(STRAY_ALLOWED)))
	errors.append_array(check_animations("res://art/characters/kaykit_anims.tres", KayKitClips.NAMES))
	errors.append_array(check_no_physics(PackedStringArray(["res://art", "res://assets"])))
	if host != null:
		var scenes: Array = []
		_files("res://art", scenes)
		errors.append_array(check_triangles(PackedStringArray(scenes.filter(func(p): return String(p).ends_with(".tscn"))), host))
	else:
		warnings.append("triangle budgets skipped: validate_project() called without a host node")
	errors.append_array(check_audio(AudioManifest.SFX, AudioManifest.MUSIC, "res://assets", AudioManifest.BUDGET_BYTES, AudioManifest.MAX_MUSIC_S))
	errors.append_array(check_audio_location("res://"))
	var ph := check_no_placeholders(PackedStringArray(["res://actors", "res://autoload", "res://components", "res://core", "res://world", "res://ui", "res://art"]))
	if PLACEHOLDERS_ARE_ERRORS:
		errors.append_array(ph)
	else:
		warnings.append_array(ph)
	return {"errors": errors, "warnings": warnings}
