class_name LaneCharacterIcons
extends RefCounted
## E6 Task 10 (spec 5.1, D-282.5, D-289.2): the two lane-character icons, built in code from palette colours like LaneIcons and
## BranchIcons (no external art). SIEGE is a battering ram on two trestles: wide, low, angular (a blunt iron head on a log).
## HARE is a hare's head under two tall curved ears: narrow, tall, round. They differ by SILHOUETTE (wide-low against
## narrow-tall), not by colour: tests compare their alpha masks and their luminance at 64 x 64.
## Units: a glyph fits a 1 x 1 square centred on the origin, y up, outline included. No white and no gold anywhere.
## Three forms: `mesh(kind)` (a world billboard, with LaneIcons.material()), `image(kind, px)` and `texture(kind, px)` (the HUD
## card and the reveal banner; 128 px stays crisp at 64).

const SIEGE := &"siege"
const HARE := &"hare"
const KINDS: Array[StringName] = [SIEGE, HARE]
const LAYER_Z := 0.02
const OUTLINE := 0.07
const TEXTURE_PX := 128

static var _cache := {}
static var _tex := {}
static var _grown_cache := {}

## A pointed leaf along a quadratic curve from `base` through `ctrl` to `tip`, widest (`width`) in the middle.
static func _leaf(base: Vector2, ctrl: Vector2, tip: Vector2, width: float, steps := 8) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var p := base.lerp(ctrl, t).lerp(ctrl.lerp(tip, t), t)
		var d := ((ctrl - base).lerp(tip - ctrl, t)).normalized()
		var n := Vector2(-d.y, d.x)
		var w := width * 0.5 * pow(sin(PI * lerpf(0.04, 0.96, t)), 0.8)
		left.append(p + n * w)
		right.append(p - n * w)
	right.reverse()
	left.append_array(right)
	return left

static func _ellipse(c: Vector2, r: Vector2, steps := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var t := TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(t) * r.x, sin(t) * r.y))
	return pts

static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

## [polygon, palette colour name] layers, drawn first to last; each gets its own ink outline under all of them.
static func layers(kind: StringName) -> Array:
	match kind:
		SIEGE:  # a ram: two trestles, a thick log with two bands, a big blunt iron head with a cracked plate
			return [
				[PackedVector2Array([Vector2(-0.38, -0.08), Vector2(-0.20, -0.08), Vector2(-0.08, -0.36), Vector2(-0.26, -0.36)]), &"wood_dark"],
				[PackedVector2Array([Vector2(-0.06, -0.08), Vector2(0.12, -0.08), Vector2(0.24, -0.36), Vector2(0.06, -0.36)]), &"wood_dark"],
				[_rect(-0.43, -0.15, 0.10, 0.15), &"wood"],
				[_rect(-0.31, -0.15, -0.24, 0.15), &"wood_dark"],
				[_rect(-0.05, -0.15, 0.02, 0.15), &"wood_dark"],
				[PackedVector2Array([Vector2(0.02, 0.27), Vector2(0.28, 0.27), Vector2(0.43, 0.0), Vector2(0.28, -0.27), Vector2(0.02, -0.27)]), &"steel"],
				[PackedVector2Array([Vector2(0.17, 0.27), Vector2(0.26, 0.27), Vector2(0.21, 0.05), Vector2(0.30, 0.0), Vector2(0.20, -0.27), Vector2(0.14, -0.27), Vector2(0.17, -0.04), Vector2(0.10, 0.0)]), &"steel_dark"],
			]
		_:  # HARE: two tall curved ears with pink insides over a round head
			return [
				[_leaf(Vector2(-0.10, -0.04), Vector2(-0.34, 0.20), Vector2(-0.20, 0.41), 0.22), &"traveler_beige"],
				[_leaf(Vector2(0.10, -0.04), Vector2(0.12, 0.28), Vector2(0.31, 0.41), 0.22), &"traveler_beige"],
				[_leaf(Vector2(-0.11, 0.0), Vector2(-0.30, 0.20), Vector2(-0.20, 0.36), 0.09), &"enemy_snout"],
				[_leaf(Vector2(0.11, 0.0), Vector2(0.12, 0.26), Vector2(0.28, 0.36), 0.09), &"enemy_snout"],
				[_ellipse(Vector2(0.0, -0.20), Vector2(0.27, 0.22)), &"traveler_beige"],
				[_ellipse(Vector2(-0.09, -0.15), Vector2(0.035, 0.04), 10), &"ink"],
				[_ellipse(Vector2(0.09, -0.15), Vector2(0.035, 0.04), 10), &"ink"],
				[_ellipse(Vector2(0.0, -0.27), Vector2(0.06, 0.04), 12), &"enemy_red"],
			]

static func _grown(poly: PackedVector2Array) -> PackedVector2Array:
	var res := Geometry2D.offset_polygon(poly, OUTLINE, Geometry2D.JOIN_ROUND)
	var best := PackedVector2Array()
	for q in res:
		if q.size() > best.size():
			best = q
	return best

## Every layer's grown outline, built once per kind.
static func _outlines(kind: StringName) -> Array:
	if not _grown_cache.has(kind):
		var out: Array = []
		for l in layers(kind):
			out.append(_grown(l[0]))
		_grown_cache[kind] = out
	return _grown_cache[kind]

static func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r

## The glyph's colour at p (glyph units), alpha 0 outside: the topmost fill, else the ink outline.
static func sample(kind: StringName, p: Vector2) -> Color:
	var ls := layers(kind)
	for i in range(ls.size() - 1, -1, -1):
		var poly: PackedVector2Array = ls[i][0]
		if _bounds(poly).has_point(p) and Geometry2D.is_point_in_polygon(p, poly):
			return Palette.color(ls[i][1])
	for g in _outlines(kind):
		if _bounds(g).has_point(p) and Geometry2D.is_point_in_polygon(p, g):
			return Palette.color(&"ink")
	return Color(0, 0, 0, 0)

## The glyph rasterized to px x px (RGBA8, one sample per pixel at its centre). Cached per size by `texture`.
static func image(kind: StringName, px := TEXTURE_PX) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var ls := layers(kind)
	var cols: Array[Color] = []
	var boxes: Array[Rect2] = []
	for l in ls:
		cols.append(Palette.color(l[1]))
		boxes.append(_bounds(l[0]))
	var outs := _outlines(kind)
	var out_boxes: Array[Rect2] = []
	for g in outs:
		out_boxes.append(_bounds(g))
	var ink := Palette.color(&"ink")
	for y in px:
		for x in px:
			var p := Vector2((float(x) + 0.5) / float(px) - 0.5, 0.5 - (float(y) + 0.5) / float(px))
			var c := Color(0, 0, 0, 0)
			var hit := false
			for i in range(ls.size() - 1, -1, -1):
				if boxes[i].has_point(p) and Geometry2D.is_point_in_polygon(p, ls[i][0]):
					c = cols[i]
					hit = true
					break
			if not hit:
				for i in outs.size():
					if out_boxes[i].has_point(p) and Geometry2D.is_point_in_polygon(p, outs[i]):
						c = ink
						break
			img.set_pixel(x, y, c)
	return img

## The glyph as a texture with mipmaps (cached per kind and size): the HUD card and the reveal banner use this.
static func texture(kind: StringName, px := TEXTURE_PX) -> ImageTexture:
	var key := "%s_%d" % [kind, px]
	if not _tex.has(key):
		var img := image(kind, px)
		img.generate_mipmaps()
		_tex[key] = ImageTexture.create_from_image(img)
	return _tex[key]

## Number of vertices the mesh of `kind` must have (every layer twice: its outline, then its fill).
static func expected_vertices(kind: StringName) -> int:
	var n := 0
	var outs := _outlines(kind)
	var ls := layers(kind)
	for i in ls.size():
		n += 3 * (ls[i][0].size() - 2) + 3 * (outs[i].size() - 2)
	return n

## The glyph as one unshaded vertex-coloured mesh (cached). Use it with `material()`.
static func mesh(kind: StringName) -> ArrayMesh:
	if _cache.has(kind):
		return _cache[kind]
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var ink := Palette.color(&"ink")
	var ls := layers(kind)
	var outs := _outlines(kind)
	var layer := 0
	for g in outs:
		layer += 1
		_add(verts, cols, g, ink, LAYER_Z * layer)
	for l in ls:
		layer += 1
		_add(verts, cols, l[0], Palette.color(l[1]), LAYER_Z * layer)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	assert(verts.size() == expected_vertices(kind), "a %s layer did not triangulate" % kind)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[kind] = m
	return m

## The billboard material: the lane glyphs' (unshaded, vertex colours, keeps the node's scale, no depth test).
static func material() -> StandardMaterial3D:
	return LaneIcons.material()

static func _add(verts: PackedVector3Array, cols: PackedColorArray, poly: PackedVector2Array, col: Color, z: float) -> void:
	for i in Geometry2D.triangulate_polygon(poly):
		verts.append(Vector3(poly[i].x, poly[i].y, z))
		cols.append(col)
