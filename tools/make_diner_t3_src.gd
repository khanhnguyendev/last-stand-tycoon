extends SceneTree
## Writes art/env/src/diner_t3_top.res (E5 tier-3 Task 19): what the tier-3 diner adds above the tier-1 roof, as ONE mesh on
## ONE surface of the shared atlas (every box is one palette texel). Colours follow docs/ART_BIBLE.md roles: diner_teal walls,
## wood roof cap and wood_dark trim, `diner_cream` as the lantern glass (the atlas has no `dirt` texel; no gold, no warm_white: those are the hero's).
## Tier 3 keeps tier 2's wood roof cap and replaces its chimney and sign board (they would stand inside the new storey) with a
## SET-BACK SECOND STOREY: walls x -2.5..1.0, z -0.5..3.0 (3.5 x 3.5 = 12.25 m2, inside |x|, |z| <= 3.0), diner_teal from 3.03 to
## 4.95, a wood_dark rim (4 strips, 0.15 wide) to 5.10 round a lighter diner_cream roof panel (top 5.05), so it reads as a second
## roof; four wood_dark window plates (north, east, west: the south wall carries the "DINER" label instead); and four lanterns: a
## tall lamp on the south-east roof corner (post to 5.7, glass 5.7 to 6.0, cap to 6.08: the diner's top, rule d), a short lantern on
## the south-west roof corner (top 5.38) and two wall-hung lanterns on the north corners.
## Why this rectangle, these heights and these lanterns: a scan over every storey rectangle, height and lantern corner (see the task
## report; focus grid, four aspects) showed that any roof overhang, a taller wall, or a roof lantern on a north corner newly hides a
## branch pad at the far north at a portrait aspect, or a pad within 10 m at a landscape one. The fix round trimmed the rim to 5.10
## and the short lantern to 5.38 (the first limits were about 5.178 and 5.544) so the proof holds between the sampled pad heights
## and with every box grown by 5 cm (tests/unit/test_diner_art.gd).
## Run: "$GODOT" --headless --path . -s res://tools/make_diner_t3_src.gd
const Base := preload("res://tools/make_diner_t2_roof_src.gd")
## [palette name, centre x, base y, centre z, size x, size y, size z]; the test reads these (24 vertices per box, in order).
const BOXES := [
	[&"wood", 0.0, 3.0, 0.0, 7.7, 0.03, 7.7],              # 0 roof cap (as tier 2)
	[&"diner_teal", -0.75, 3.03, 1.25, 3.5, 1.92, 3.5],    # 1 storey walls, 3.03 to 4.95
	[&"wood_dark", -0.75, 4.95, -0.425, 3.5, 0.15, 0.15],  # 2 rim, north strip, top 5.10
	[&"wood_dark", -0.75, 4.95, 2.925, 3.5, 0.15, 0.15],   # 3 rim, south strip
	[&"wood_dark", -2.425, 4.95, 1.25, 0.15, 0.15, 3.2],   # 4 rim, west strip
	[&"wood_dark", 0.925, 4.95, 1.25, 0.15, 0.15, 3.2],    # 5 rim, east strip
	[&"diner_cream", -0.75, 4.95, 1.25, 3.2, 0.1, 3.2],    # 6 roof panel inside the rim, top 5.05
	[&"wood_dark", -1.75, 3.9, -0.505, 0.5, 0.6, 0.01],    # 7 window, north face
	[&"wood_dark", -0.25, 3.9, -0.505, 0.5, 0.6, 0.01],    # 8 window, north face
	[&"wood_dark", 1.005, 3.9, 1.25, 0.01, 0.6, 0.5],      # 9 window, east face
	[&"wood_dark", -2.505, 3.9, 1.25, 0.01, 0.6, 0.5],     # 10 window, west face
	[&"wood_dark", 0.83, 5.1, 2.83, 0.1, 0.6, 0.1],        # 11 lamp post, south-east corner (the diner's top)
	[&"diner_cream", 0.83, 5.7, 2.83, 0.26, 0.3, 0.26],    # 12 lamp glass
	[&"wood_dark", 0.83, 6.0, 2.83, 0.34, 0.08, 0.34],     # 13 lamp cap, top at 6.08
	[&"diner_cream", -2.33, 5.1, 2.83, 0.24, 0.2, 0.24],   # 14 short lantern glass, south-west corner
	[&"wood_dark", -2.33, 5.3, 2.83, 0.3, 0.08, 0.3],      # 15 short lantern cap, top at 5.38
	[&"diner_cream", -2.5, 4.55, -0.5, 0.22, 0.3, 0.22],   # 16 wall lantern glass, north-west corner
	[&"wood_dark", -2.5, 4.85, -0.5, 0.24, 0.06, 0.24],    # 17 wall lantern cap
	[&"diner_cream", 1.0, 4.55, -0.5, 0.22, 0.3, 0.22],    # 18 wall lantern glass, north-east corner
	[&"wood_dark", 1.0, 4.85, -0.5, 0.24, 0.06, 0.24],     # 19 wall lantern cap
]

func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(Base.ATLAS))
	if img == null:
		push_error("cannot load " + Base.ATLAS)
		quit(1)
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for b in BOXES:
		var texel: Vector2i = Base._find_texel(img, Palette.color(b[0]))
		if texel.x < 0:
			push_error("%s not in the atlas" % b[0])
			quit(1)
			return
		var uv := (Vector2(texel) + Vector2(0.5, 0.5)) / Vector2(img.get_size())
		Base._box(verts, norms, uvs, idx, Vector3(b[1], b[2], b[3]), Vector3(b[4], b[5], b[6]), uv)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, load("res://art/materials/kenney-fantasy-town__colormap.tres"))
	var err := ResourceSaver.save(mesh, "res://art/env/src/diner_t3_top.res")
	if err != OK:
		push_error("cannot save diner_t3_top.res: %d" % err)
		quit(1)
		return
	quit(0)
