class_name PaletteMath
extends RefCounted
## Nearest-colour palette remap in Oklab (S4 spec 5.2, D-188). Pure static; unit-tested.

static func to_oklab(c: Color) -> Vector3:
	var r := _lin(c.r)
	var g := _lin(c.g)
	var b := _lin(c.b)
	var l := _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
	var m := _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
	var s := _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)

static func _lin(x: float) -> float:
	return x / 12.92 if x <= 0.04045 else pow((x + 0.055) / 1.055, 2.4)

static func _cbrt(x: float) -> float:
	return signf(x) * pow(absf(x), 1.0 / 3.0)

## Index of the closest palette colour; ties go to the lowest index.
static func nearest(c: Color, palette: PackedColorArray) -> int:
	var p := to_oklab(c)
	var best := -1
	var best_d := INF
	for i in palette.size():
		var d := p.distance_squared_to(to_oklab(palette[i]))
		if d < best_d:
			best_d = d
			best = i
	return best

## Every pixel -> its palette colour (or the override's), alpha kept. Returns a new RGBA8 image.
static func remap_image(img: Image, palette: PackedColorArray, overrides: Dictionary) -> Image:
	var out: Image = img.duplicate()
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	var cache := {}
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			var key := c.to_html(false)
			var idx: int
			if overrides.has(key):
				idx = int(overrides[key])
				assert(idx >= 0 and idx < palette.size(), "bad override %s -> %d" % [key, idx])
			elif cache.has(key):
				idx = cache[key]
			else:
				idx = nearest(c, palette)
				cache[key] = idx
			var p := palette[idx]
			out.set_pixel(x, y, Color(p.r, p.g, p.b, c.a))
	return out
