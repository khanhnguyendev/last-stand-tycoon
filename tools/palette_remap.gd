extends SceneTree
## Writes every RemapManifest entry's remapped atlas (D-188). Deterministic: same inputs, byte-identical PNGs.
## Run: "$GODOT" --headless --path . -s res://tools/palette_remap.gd

func _initialize() -> void:
	var manifest = load("res://art/palette/remap_manifest.gd")
	var pal = load("res://art/palette/palette.gd")
	var pm = load("res://core/palette_math.gd")
	var colors: PackedColorArray = pal.colors()
	# ART_BIBLE R4: atlases never map to enemy_* colours (enemy reds come only from code). Excluded indices are
	# replaced with a far-away sentinel, so nearest() never picks them; overrides may still name them (none should).
	var atlas_colors := colors.duplicate()
	for n in pal.NAMES:
		if String(n).begins_with("enemy_"):
			atlas_colors[pal.index_of(n)] = Color(10, 10, 10)
	var failed := false
	for e in manifest.ENTRIES:
		var src := Image.load_from_file(ProjectSettings.globalize_path(e.src))
		if src == null:
			push_error("missing %s" % e.src)
			failed = true
			continue
		if src.get_width() > 512 or src.get_height() > 512:  # KayKit atlases are 1024^2 (D-196: <= 512)
			src.resize(mini(src.get_width(), 512), mini(src.get_height(), 512), Image.INTERPOLATE_NEAREST)
		var ov := {}
		for hex in e.overrides:
			ov[String(hex).to_lower()] = pal.index_of(StringName(e.overrides[hex]))
		var out: Image = pm.remap_image(src, atlas_colors, ov)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(e.out).get_base_dir()))
		out.save_png(ProjectSettings.globalize_path(e.out))
		print("remapped ", e.out)
	quit(1 if failed else 0)
