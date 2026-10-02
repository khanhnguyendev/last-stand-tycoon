extends SceneTree
## The icon contact sheet (S4 Task 15): every art/icons/*.png on a neutral stone background, 4 per row, plus a 40% copy.
##   "$GODOT" --headless --path . -s res://tools/icon_sheet.gd -- --out=docs/review/media/s4/task15/icons_sheet.png
## Deterministic. Editor/test only (tools/ is excluded from every web export).

func _initialize() -> void:
	var out := "docs/review/media/s4/task15/icons_sheet.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://art/icons"):
		if f.ends_with(".png") and f != "atlas.png":
			files.append(f)
	files.sort()
	var cols := 4
	var cell := 256
	var rows := (files.size() + cols - 1) / cols
	var sheet := Image.create_empty(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Palette.color(&"stone"))
	for i in files.size():
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/icons/" + files[i]))
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(0, 0, cell, cell), Vector2i((i % cols) * cell, (i / cols) * cell))
	var path := out if out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	sheet.save_png(path)
	var small := sheet.duplicate() as Image
	small.resize(sheet.get_width() * 2 / 5, sheet.get_height() * 2 / 5, Image.INTERPOLATE_LANCZOS)
	small.save_png(path.get_basename() + "_40.png")
	print("saved ", out, " ", files.size(), " icons")
	quit(0)
