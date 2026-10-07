class_name GroundArt
extends RefCounted
## The ground and the road (S4 Task 13, D-194, D-201). The ground is ONE subdivided mesh with a position-hash vertex
## colour variation (grass / grass_dark); the road is ONE flat mesh. Static builders, visual only: no Rng, no nodes.

const CELL := 2.0
const ROAD_Y := 0.02
## A yard is a hair above the grass and below the road and the lane strips (z-fight free).
const YARD_Y := 0.01

static var _material: StandardMaterial3D

## The shared vertex-colour material (palette colours are sRGB, D-188). Also used by LaneStrip.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.resource_name = "ground_vertex_colour"
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 1.0
	return _material

## A position hash in [0, 1): the same point always gives the same value (never Rng, spec 6.3).
static func hash01(x: float, z: float) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0)

## The grass colour at world (x, z): grass mixed toward grass_dark by the hash.
static func grass_at(x: float, z: float) -> Color:
	return Palette.color(&"grass").lerp(Palette.color(&"grass_dark"), hash01(x, z))

static var _cache := {}

## Vertex arrays {v, n, c, i} of a flat grid over `rect` (xz), `cell` metres per cell, at y = 0, coloured by `grass_at`.
static func ground_arrays(rect: Rect2, cell := CELL) -> Dictionary:
	var nx := ceili(rect.size.x / cell)
	var nz := ceili(rect.size.y / cell)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize((nx + 1) * (nz + 1))
	normals.resize(verts.size())
	colors.resize(verts.size())
	for j in nz + 1:
		for i in nx + 1:
			var x := minf(rect.position.x + i * cell, rect.end.x)
			var z := minf(rect.position.y + j * cell, rect.end.y)
			var k := j * (nx + 1) + i
			verts[k] = Vector3(x, 0.0, z)
			normals[k] = Vector3.UP
			colors[k] = grass_at(x, z)
	var idx := PackedInt32Array()
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])  # clockwise seen from above (+y): Godot's front face
	return {"v": verts, "n": normals, "c": colors, "i": idx}

## Vertex arrays of the road: one flat stone quad of `size` (x, z) centred on (0, `z`) at y = ROAD_Y.
static func road_arrays(size: Vector2, z: float) -> Dictionary:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var verts := PackedVector3Array([Vector3(-hx, ROAD_Y, z - hz), Vector3(hx, ROAD_Y, z - hz), Vector3(-hx, ROAD_Y, z + hz), Vector3(hx, ROAD_Y, z + hz)])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var c := Palette.color(&"stone")
	return {"v": verts, "n": normals, "c": PackedColorArray([c, c, c, c]), "i": PackedInt32Array([0, 1, 2, 1, 3, 2])}

## Appends the parts' arrays into one set (indices re-based).
static func merge_arrays(parts: Array) -> Dictionary:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	for p in parts:
		var base := v.size()
		v.append_array(p.v)
		n.append_array(p.n)
		c.append_array(p.c)
		for k in p.i:
			idx.append(k + base)
	return {"v": v, "n": n, "c": c, "i": idx}

static func mesh_from(a: Dictionary) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = a.v
	arrays[Mesh.ARRAY_NORMAL] = a.n
	arrays[Mesh.ARRAY_COLOR] = a.c
	arrays[Mesh.ARRAY_INDEX] = a.i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	return mesh

## The ground alone (cached per rect).
static func ground_mesh(rect: Rect2) -> ArrayMesh:
	var key := "g%s" % [rect]
	if not _cache.has(key):
		_cache[key] = mesh_from(ground_arrays(rect))
	return _cache[key]

## E5 tier 3 Task 2: owned land is paved: diner_cream hashed toward stone, clearly neither lane dirt nor grass.
static func paved_at(x: float, z: float) -> Color:
	return Palette.color(&"diner_cream").lerp(Palette.color(&"stone"), hash01(x, z) * 0.4)

## A yard is a paved patch in the merged ground (spec 7.3, tier 3 spec 5); its border is YardStones.
static func yard_arrays(rect: Rect2, cell := 1.0) -> Dictionary:
	var a := ground_arrays(rect, cell)
	var cols: PackedColorArray = a.c
	var verts: PackedVector3Array = a.v
	for i in verts.size():
		var v := verts[i]
		verts[i] = Vector3(v.x, YARD_Y, v.z)
		cols[i] = paved_at(v.x, v.z)
	a.v = verts
	a.c = cols
	return a

## `lanes` empty = the tier-1/2 lane set: those keys are exactly the pre-tier-3 ones.
static func _terrain_key(rect: Rect2, yards: Array, lanes: Array = []) -> String:
	var key := "t%s" % [rect] if yards.is_empty() else "t%s%s" % [rect, yards]
	return key if _is_default_lanes(lanes) else key + "L%s" % [lanes]

static func _is_default_lanes(lanes: Array) -> bool:
	return lanes.is_empty() or lanes == MapLayout.lanes_for_tier(1)

## True when terrain_mesh(rect, yards) is already built (the warm-up pre-builds the top tier's, E5 Task 12).
static func is_cached(rect: Rect2, yards: Array = [], lanes: Array = []) -> bool:
	return _cache.has(_terrain_key(rect, yards, lanes))

## ONE mesh, ONE surface, ONE draw for the ground, the road, the lane strips, the open yards and their small props (D-201). Cached per
## (rect, yards, lanes); `yards` are MapLayout yard ids, `lanes` MapLayout.lanes_for_tier(tier) (empty = the three tier-1/2 lanes). With no yards
## and no extra lane the mesh is exactly the S4 tier-1 terrain.
static func terrain_mesh(rect: Rect2, yards: Array = [], lanes: Array = []) -> ArrayMesh:
	var key := _terrain_key(rect, yards, lanes)
	if not _cache.has(key):
		var parts := [ground_arrays(rect), road_arrays(Vector2(MapLayout.BOUNDS_MAX.x - MapLayout.BOUNDS_MIN.x, 2.0), MapLayout.ROAD_Z)]
		for id in LaneStrip.draw_order(lanes):
			parts.append(LaneStrip.strip_arrays(MapLayout.lane_path(id), LaneStrip.WIDTH, LaneStrip.EDGE, LaneStrip.strip_y(id)))
		for y in yards:
			parts.append(yard_arrays(MapLayout.yard_rect(y)))
		var owned := PropsLayout.owned_for(yards)  # E5 tier 3 Task 2: small props on owned land, same mesh, no extra draw
		if not owned.is_empty():
			parts.append(Props.owned_arrays(owned))
		_cache[key] = mesh_from(merge_arrays(parts))
	return _cache[key]

## A MeshInstance3D for `mesh`, no shadows.
static func instance(mesh: Mesh, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
