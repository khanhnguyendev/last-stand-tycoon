extends SceneTree
## Offline character bake (S4 Task 8b, D-201). Run:
##   "$GODOT" --headless --path . -s res://tools/bake_characters.gd
## Bakes each role into ONE skinned ArrayMesh with ONE surface (one draw call) plus its Skin, committed under
## art/characters/baked/. The mesh is the role's six skinned body parts followed by its props, each prop bound rigidly
## to the bone it is attached to:
##   v' = inverse(skin_bind(bone)) * attachment_offset * prop_local * v      (bones [b,0,0,0], weights [1,0,0,0])
## so that Godot's skinning (world = skeleton_pose(bone) * skin_bind(bone) * v') puts the prop exactly where the
## BoneAttachment3D put it. The attachment offset comes from the unbaked scene (build_reference).
## Prop UVs are retargeted onto the role's palette atlas: each vertex's colour (its texel on the prop's own atlas, or
## its vertex colour) maps to the centre of a texel of the same colour in the role's atlas. A colour missing from
## the role atlas fails the bake with a message naming the prop and the colour; the palette is never changed.
## Deterministic: same inputs, same bytes (run twice, git status stays clean). Editor/test only (tools/ is excluded
## from every web export).

const OUT_DIR := "res://art/characters/baked/"
const GLB := "res://assets/kaykit-adventurers/Characters/gltf/%s.glb"
const MATERIAL := "res://art/materials/%s.tres"
const SKELETON_PATH := "Rig/Skeleton3D"
const PAN_SCENE := preload("res://assets/kaykit-restaurant/Assets/gltf/pan_A.gltf")
## The cook's frying pan in the right hand's slot (skeleton units; the slot's +Y runs along the forearm), and the hat
## on the head bone (ChefHat).
const PAN_SCALE := 0.6
const PAN_ROTATION_DEG := Vector3(90, 0, 0)
const PAN_OFFSET := Vector3(0, 0.45, 0)

## role -> glb, the material (whose atlas the whole mesh uses), the props kept from the glb, the cook's own props.
const ROLES := {
	"hero": {"glb": "Barbarian", "material": "kaykit-adventurers__barbarian_apron", "keep": [], "cook": true},
	"archer": {"glb": "Rogue_Hooded", "material": "kaykit-adventurers__rogue_texture", "keep": ["2H_Crossbow"], "cook": false},
	"tank": {"glb": "Knight", "material": "kaykit-adventurers__knight_texture",
		"keep": ["1H_Sword", "Badge_Shield", "Knight_Helmet"], "cook": false},
	"traveler_rogue": {"glb": "Rogue", "material": "traveler_rogue_grey", "keep": [], "cook": false},
	"traveler_mage": {"glb": "Mage", "material": "traveler_mage_grey", "keep": [], "cook": false},
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var failed := false
	for role in ROLES:
		var r := bake_role(role)
		if not (r.errors as Array).is_empty():
			for e in r.errors:
				push_error("bake %s: %s" % [role, e])
			failed = true
			continue
		var mesh_path: String = OUT_DIR + "%s.res" % role
		var skin_path: String = OUT_DIR + "%s_skin.res" % role
		var e1 := ResourceSaver.save(r.mesh, mesh_path)
		var e2 := ResourceSaver.save(r.skin, skin_path)
		if e1 != OK or e2 != OK:
			push_error("bake %s: save failed (%s, %s)" % [role, error_string(e1), error_string(e2)])
			failed = true
			continue
		print("BAKED %s: %d vertices, %d triangles, props %s" % [role, r.vertices, r.triangles, r.mesh.get_meta("props")])
	quit(1 if failed else 0)

# --- the unbaked reference -------------------------------------------------------------------------------------

## The role's glb with only its kept props (each under its BoneAttachment3D, as KayKitVisual left them) and, for the
## hero, the cook's pan and hat attached the way Task 7b did. Not in the tree; free it.
static func build_reference(role: String) -> Node3D:
	var cfg: Dictionary = ROLES[role]
	var model: Node3D = load(GLB % cfg.glb).instantiate()
	var sk := model.get_node(SKELETON_PATH) as Skeleton3D
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		var att := mi.get_parent() as BoneAttachment3D
		if att != null and not (cfg.keep as Array).has(String(mi.name)):
			att.remove_child(mi)
			mi.free()
	for att in sk.find_children("*", "BoneAttachment3D", true, false):
		if att.find_children("*", "MeshInstance3D", true, false).is_empty():
			att.get_parent().remove_child(att)
			att.free()
	if cfg.cook:
		attach_cook_props(sk)
	return model

static func attach_cook_props(sk: Skeleton3D) -> void:
	var pan: Node3D = PAN_SCENE.instantiate()
	pan.scale = Vector3.ONE * PAN_SCALE
	pan.rotation_degrees = PAN_ROTATION_DEG
	pan.position = PAN_OFFSET
	_attach(sk, &"handslot.r", pan)
	_attach(sk, &"head", ChefHat.build())

static func _attach(sk: Skeleton3D, bone: StringName, node: Node3D) -> void:
	var att := BoneAttachment3D.new()
	att.name = "Cook_%s" % String(bone).replace(".", "_")
	att.bone_name = bone
	sk.add_child(att)
	att.add_child(node)

# --- the bake --------------------------------------------------------------------------------------------------

## -> {errors: Array[String], mesh: ArrayMesh, skin: Skin, vertices: int, triangles: int}
static func bake_role(role: String) -> Dictionary:
	var cfg: Dictionary = ROLES[role]
	var errors: Array[String] = []
	var model := build_reference(role)
	var sk := model.get_node(SKELETON_PATH) as Skeleton3D
	var mat := load(MATERIAL % cfg.material) as StandardMaterial3D
	var atlas_path := mat.albedo_texture.resource_path
	var texels: Dictionary = {}  # role atlas colour -> texel, built when the first prop needs it
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var props: Array = []
	var skin: Skin = null
	for c in sk.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.skin == null:
			continue
		if skin == null:
			skin = mi.skin
		elif mi.skin != skin:
			errors.append("%s: skin differs from the first part's" % mi.name)
		if not mi.transform.is_equal_approx(Transform3D.IDENTITY):
			errors.append("%s: non-identity transform on a skinned part" % mi.name)
		var arr := mi.mesh.surface_get_arrays(0)
		var base := verts.size()
		verts.append_array(arr[Mesh.ARRAY_VERTEX])
		normals.append_array(arr[Mesh.ARRAY_NORMAL])
		uvs.append_array(arr[Mesh.ARRAY_TEX_UV])
		bones.append_array(arr[Mesh.ARRAY_BONES])
		weights.append_array(arr[Mesh.ARRAY_WEIGHTS])
		_append_indices(indices, arr[Mesh.ARRAY_INDEX], base, false)
	if skin == null:
		errors.append("no skinned part found")
		return {"errors": errors}
	for att in sk.get_children():
		if not att is BoneAttachment3D:
			continue
		var bind := _bind_index(skin, (att as BoneAttachment3D).bone_name)
		if bind < 0:
			errors.append("%s: bone %s is not in the skin" % [att.name, att.bone_name])
			continue
		var inv_bind := skin.get_bind_pose(bind).affine_inverse()
		for pm in att.find_children("*", "MeshInstance3D", true, false):
			var xf: Transform3D = inv_bind * _relative(pm, att)
			var normal_basis := xf.basis.inverse().transposed()
			var arr := (pm as MeshInstance3D).mesh.surface_get_arrays(0)
			var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var pn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var base := verts.size()
			var uv_out := _prop_uvs(pm as MeshInstance3D, arr, atlas_path, texels, errors)
			for i in pv.size():
				verts.append(xf * pv[i])
				normals.append((normal_basis * pn[i]).normalized())
				uvs.append(uv_out[i])
				bones.append_array(PackedInt32Array([bind, 0, 0, 0]))
				weights.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			_append_indices(indices, arr[Mesh.ARRAY_INDEX], base, xf.basis.determinant() < 0.0)
			props.append({"name": String(pm.name), "bone": String((att as BoneAttachment3D).bone_name), "first": base, "count": pv.size()})
	if not errors.is_empty():
		return {"errors": errors}
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.resource_name = "baked_%s" % role
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	mesh.set_meta("props", props)
	var out_skin := Skin.new()
	out_skin.resource_name = "baked_%s_skin" % role
	for i in skin.get_bind_count():
		out_skin.add_named_bind(String(skin.get_bind_name(i)), skin.get_bind_pose(i))
	model.free()
	return {"errors": errors, "mesh": mesh, "skin": out_skin, "vertices": verts.size(), "triangles": indices.size() / 3}

static func _append_indices(out: PackedInt32Array, src: PackedInt32Array, base: int, flip: bool) -> void:
	for t in src.size() / 3:
		if flip:
			out.append_array(PackedInt32Array([base + src[t * 3], base + src[t * 3 + 2], base + src[t * 3 + 1]]))
		else:
			out.append_array(PackedInt32Array([base + src[t * 3], base + src[t * 3 + 1], base + src[t * 3 + 2]]))

static func _bind_index(skin: Skin, bone: StringName) -> int:
	for i in skin.get_bind_count():
		if skin.get_bind_name(i) == bone:
			return i
	return -1

## `n`'s transform relative to `ancestor` (the BoneAttachment3D): the offset the unbaked scene gives the prop.
static func _relative(n: Node3D, ancestor: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != ancestor:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

# --- UV retargeting --------------------------------------------------------------------------------------------

static func atlas_image(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img

static func color_key(c: Color) -> int:
	return (c.r8 << 16) | (c.g8 << 8) | c.b8

## colour key -> the centre-most texel of that colour: the first texel (row-major) whose 3x3 neighbourhood is all that
## colour, else the first texel of the colour. Only opaque texels.
static func texel_lookup(path: String) -> Dictionary:
	var img := atlas_image(path)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var interior := {}
	var any := {}
	for y in h:
		for x in w:
			var o := (y * w + x) * 4
			if data[o + 3] != 255:
				continue
			var key := (data[o] << 16) | (data[o + 1] << 8) | data[o + 2]
			if interior.has(key):
				continue
			if not any.has(key):
				any[key] = Vector2i(x, y)
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				continue
			var solid := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var p := ((y + dy) * w + x + dx) * 4
					if data[p + 3] != 255 or ((data[p] << 16) | (data[p + 1] << 8) | data[p + 2]) != key:
						solid = false
			if solid:
				interior[key] = Vector2i(x, y)
	for key in interior:
		any[key] = interior[key]
	return any

## The prop's colour at each vertex: its texel on its own atlas at the original UV, or its vertex colour.
static func prop_colors(mi: MeshInstance3D, arr: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var mat := mi.mesh.surface_get_material(0) as BaseMaterial3D
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	if mat != null and mat.albedo_texture != null and arr[Mesh.ARRAY_TEX_UV] != null:
		var img := atlas_image(mat.albedo_texture.resource_path)
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		for i in verts.size():
			var x := clampi(int(floor(uv[i].x * img.get_width())), 0, img.get_width() - 1)
			var y := clampi(int(floor(uv[i].y * img.get_height())), 0, img.get_height() - 1)
			out.append(color_key(img.get_pixel(x, y)))
	else:
		var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		for i in verts.size():
			out.append(color_key(col[i] if i < col.size() else Color.WHITE))
	return out

## UVs for the prop's vertices on the role atlas. A prop already on the role's atlas keeps its UVs.
static func _prop_uvs(mi: MeshInstance3D, arr: Array, atlas_path: String, texels: Dictionary, errors: Array[String]) -> PackedVector2Array:
	var mat := mi.mesh.surface_get_material(0) as BaseMaterial3D
	var uv: Variant = arr[Mesh.ARRAY_TEX_UV]
	if uv != null and mat != null and mat.albedo_texture != null and mat.albedo_texture.resource_path == atlas_path:
		return uv
	if texels.is_empty():
		texels.merge(texel_lookup(atlas_path))
	var size := float(atlas_image(atlas_path).get_width())
	var out := PackedVector2Array()
	var colors := prop_colors(mi, arr)
	var missing := {}
	for key in colors:
		if not texels.has(key):
			missing[key] = true
			out.append(Vector2.ZERO)
			continue
		var t: Vector2i = texels[key]
		out.append(Vector2(t.x + 0.5, t.y + 0.5) / size)
	for key in missing:
		errors.append("prop %s: colour #%06x is not in the role atlas %s" % [mi.name, key, atlas_path])
	return out
