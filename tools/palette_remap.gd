extends SceneTree
## Writes every RemapManifest entry's remapped atlas (D-188). Deterministic: same inputs, byte-identical PNGs.
## Run: "$GODOT" --headless --path . -s res://tools/palette_remap.gd

func _initialize() -> void:
	var manifest = load("res://art/palette/remap_manifest.gd")
	var pal = load("res://art/palette/palette.gd")
	var pm = load("res://core/palette_math.gd")
	# ART_BIBLE R4: atlases never map to enemy_* colours (enemy reds come only from code); the manifest's palette
	# replaces those entries with a far-away sentinel. Overrides may still name them (none should).
	var atlas_colors: PackedColorArray = manifest.atlas_colors()
	var failed := false
	for e in manifest.ENTRIES:
		var src := Image.load_from_file(ProjectSettings.globalize_path(e.src))
		if src == null:
			push_error("missing %s" % e.src)
			failed = true
			continue
		var cap: int = manifest.IMAGE_SIZE  # KayKit atlases are 1024^2 (D-196: <= 512)
		if src.get_width() > cap or src.get_height() > cap:
			src.resize(mini(src.get_width(), cap), mini(src.get_height(), cap), Image.INTERPOLATE_NEAREST)
		var ov := {}
		for hex in e.overrides:
			ov[String(hex).to_lower()] = pal.index_of(StringName(e.overrides[hex]))
		var out: Image = pm.remap_image(src, atlas_colors, ov)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(e.out).get_base_dir()))
		out.save_png(ProjectSettings.globalize_path(e.out))
		print("remapped ", e.out)
	quit(1 if failed else 0)
