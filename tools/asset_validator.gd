class_name AssetValidator
extends RefCounted
## S4 asset rules (spec 5.4, D-187, D-188, D-196). Static; each check returns problem strings. Editor/test only:
## tools/ is excluded from every web export.
## Every check skips the `assets/_candidates` folder (local style-board sources, gitignored), so local runs match CI.
## PNGs are loaded through ProjectSettings.globalize_path: a plain res:// or user:// load raises an engine error.

const MODEL_EXT := ["glb", "gltf", "fbx", "obj", "png", "jpg", "jpeg"]
const STRAY_ALLOWED := ["assets", "art", "ui/fonts", "export", "docs", "addons", "tests", ".godot", "build"]
const PLACEHOLDER_RE := "Visuals\\s*\\.\\s*(box|capsule|cylinder|cone|plane)\\s*\\("
## Flipped to true in Task 13, once the last placeholder is gone.
const PLACEHOLDERS_ARE_ERRORS := false

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

## ART_BIBLE R4: no enemy_* colour in any remapped atlas.
static func check_no_enemy_colors(dir: String, enemy_hexes: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var files: Array = []
	_files(dir, files)
	for p in files:
		if not String(p).ends_with(".png"):
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

static func check_texture_sizes(dir: String, max_px: int) -> Array[String]:
	var out: Array[String] = []
	var files: Array = []
	_files(dir, files)
	for p in files:
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

static func validate_project() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	errors.append_array(check_licenses("res://assets", "res://docs/ASSET_LICENSES.md"))
	errors.append_array(check_palette(PackedStringArray(["res://art/palette/atlas", "res://art/icons"]), Palette.hex_set()))
	var enemy := {}
	for n in Palette.NAMES:
		if String(n).begins_with("enemy_"):
			enemy[Palette.HEX[Palette.index_of(n)]] = true
	errors.append_array(check_no_enemy_colors("res://art/palette/atlas", enemy))
	errors.append_array(check_texture_sizes("res://art", 512))
	errors.append_array(check_texture_sizes("res://art/icons", 256))
	errors.append_array(check_stray_models("res://", PackedStringArray(STRAY_ALLOWED)))
	var ph := check_no_placeholders(PackedStringArray(["res://actors", "res://autoload", "res://components", "res://core", "res://world", "res://ui", "res://art"]))
	if PLACEHOLDERS_ARE_ERRORS:
		errors.append_array(ph)
	else:
		warnings.append_array(ph)
	return {"errors": errors, "warnings": warnings}
