extends SceneTree
## Generates art/fx/fx_atlas.png: 256x64, four 64 px cells (puff, spark, star, dust) in palette apron_white with an alpha
## falloff (S5 Task 4, D-214). Colour comes per instance. Deterministic: no randomness.
## "$GODOT" --headless --path . -s res://tools/make_fx_atlas.gd
## The validator ignores pixels below alpha 255, so the soft edges are allowed; any fully opaque pixel is apron_white.

const OUT := "res://art/fx/fx_atlas.png"
const CELL := 64

func _init() -> void:
	var white: Color = load("res://art/palette/palette.gd").color(&"apron_white")
	var img := Image.create_empty(CELL * 4, CELL, false, Image.FORMAT_RGBA8)
	img.fill(Color(white.r, white.g, white.b, 0.0))
	var star := _star_points(5, 0.92, 0.40)
	for y in CELL:
		for x in CELL:
			# Cell-local coordinates in -1..1 (pixel centres).
			var p := Vector2((x + 0.5) / CELL * 2.0 - 1.0, (y + 0.5) / CELL * 2.0 - 1.0)
			var r2 := p.length_squared()
			var a_puff := clampf(1.0 - r2, 0.0, 1.0)
			# 4-point diamond: |x| + |y| <= 1 with a soft edge.
			var a_spark := clampf((1.0 - (absf(p.x) + absf(p.y))) * 3.0, 0.0, 1.0)
			var a_star := 1.0 if Geometry2D.is_point_in_polygon(p, star) else 0.0
			var q := p / 0.6
			var a_dust := clampf(1.0 - q.length_squared(), 0.0, 1.0)
			var alphas := [a_puff, a_spark, a_star, a_dust]
			for c in 4:
				img.set_pixel(c * CELL + x, y, Color(white.r, white.g, white.b, alphas[c]))
	var path := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	if err != OK:
		push_error("fx atlas save failed: %s" % error_string(err))
		quit(1)
		return
	print("saved ", OUT)
	quit(0)

## A star with `n` points, outer radius `ro`, inner radius `ri`, first point up.
static func _star_points(n: int, ro: float, ri: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var ang := -PI * 0.5 + PI * float(i) / n
		var r := ro if i % 2 == 0 else ri
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	return pts
