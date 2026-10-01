extends SceneTree
## Generates art/shared/blob_shadow.png: a 64x64 radial alpha blob in palette ink (S4 Task 6).
## "$GODOT" --headless --path . -s res://tools/make_blob.gd
## Pixels below alpha 255 are ignored by the validator's palette rule, so the soft edge is allowed.

const OUT := "res://art/shared/blob_shadow.png"
const SIZE := 64

func _init() -> void:
	var ink: Color = load("res://art/palette/palette.gd").color(&"ink")
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var half := SIZE * 0.5
	for y in SIZE:
		for x in SIZE:
			var r := Vector2(x + 0.5 - half, y + 0.5 - half).length()
			var a := 0.45 * pow(clampf(1.0 - r / half, 0.0, 1.0), 1.5)
			img.set_pixel(x, y, Color(ink.r, ink.g, ink.b, a))
	var path := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	if err != OK:
		push_error("blob save failed: %s" % error_string(err))
		quit(1)
		return
	print("saved ", OUT)
	quit(0)
