extends GutTest
## Task 15: the rendered icons exist, are 256x256 and sit on the palette (ART_BIBLE R1, D-188).

const EXTRA := ["coin", "steak", "heart", "moon"]

func _image(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))  # a res:// load raises an engine error

func test_every_card_icon_exists_and_is_256() -> void:
	for id in CardCatalog.IDS:
		assert_true(CardCatalog.ICONS.has(id), "ICONS has %s" % id)
		var path: String = CardCatalog.ICONS[id]
		assert_true(FileAccess.file_exists(path), path)
		var img := _image(path)
		assert_not_null(img, path)
		if img != null:
			assert_eq(img.get_size(), Vector2i(256, 256), path)

func test_hud_icons_exist_and_are_256() -> void:
	for n in EXTRA:
		var path := "res://art/icons/%s.png" % n
		assert_true(FileAccess.file_exists(path), path)
		var img := _image(path)
		assert_not_null(img, path)
		if img != null:
			assert_eq(img.get_size(), Vector2i(256, 256), path)

func test_icons_are_loadable_textures() -> void:
	for n in EXTRA:
		assert_not_null(load("res://art/icons/%s.png" % n) as Texture2D, n)
	for id in CardCatalog.IDS:
		assert_not_null(load(CardCatalog.ICONS[id]) as Texture2D, String(id))

func test_icons_are_on_the_palette() -> void:
	assert_eq(AssetValidator.check_palette(PackedStringArray(["res://art/icons"]), Palette.hex_set()), [] as Array[String])

func test_only_the_heart_uses_enemy_colours() -> void:
	var errs := AssetValidator.check_no_enemy_colors("res://art/icons", AssetValidator.enemy_hexes(), PackedStringArray(["heart.png", "atlas.png"]))
	assert_eq(errs, [] as Array[String])
	var with_heart := AssetValidator.check_no_enemy_colors("res://art/icons", AssetValidator.enemy_hexes(), PackedStringArray(["atlas.png"]))
	assert_eq(with_heart.size(), 1, "the heart is the one exception, and it does use enemy_red (the atlas is checked per cell below)")

func test_every_icon_is_substantial() -> void:
	for f in DirAccess.get_files_at("res://art/icons"):
		if not f.ends_with(".png") or f == "atlas.png":
			continue
		var img := _image("res://art/icons/" + f)
		var opaque := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a8 == 255:
					opaque += 1
		assert_gt(opaque, 256 * 256 / 10, "%s has more than 10%% opaque pixels" % f)

func test_atlas_is_a_grid_of_every_icon() -> void:
	var img := _image(IconAtlas.PATH)
	assert_not_null(img)
	assert_eq(img.get_size(), Vector2i(IconAtlas.COLS * IconAtlas.CELL, IconAtlas.rows() * IconAtlas.CELL))
	assert_lte(maxi(img.get_width(), img.get_height()), 512, "the size rule allows the atlas up to 512")
	assert_not_null(IconAtlas.texture())
	assert_eq(IconAtlas.NAMES.size(), 11)
	var files := 0
	for f in DirAccess.get_files_at("res://art/icons"):
		if f.ends_with(".png") and f != "atlas.png":
			files += 1
			assert_true(IconAtlas.NAMES.has(StringName(f.get_basename())), "%s has an atlas cell" % f)
	assert_eq(files, IconAtlas.NAMES.size())
	for n in IconAtlas.NAMES:
		var r := IconAtlas.region(n)
		var opaque := 0
		for y in range(int(r.position.y), int(r.end.y)):
			for x in range(int(r.position.x), int(r.end.x)):
				if img.get_pixel(x, y).a8 == 255:
					opaque += 1
		assert_gt(opaque, IconAtlas.CELL * IconAtlas.CELL / 10, "%s cell is not blank" % n)

func test_atlas_cell_matches_its_icon_file() -> void:
	var atlas := _image(IconAtlas.PATH)
	for n in [&"coin", &"heart", &"card_tank"]:
		var src := _image("res://art/icons/%s.png" % n)
		src.convert(Image.FORMAT_RGBA8)
		src.resize(IconAtlas.CELL, IconAtlas.CELL, Image.INTERPOLATE_BILINEAR)
		var r := IconAtlas.region(n)
		var inter := 0
		var union := 0
		for y in IconAtlas.CELL:
			for x in IconAtlas.CELL:
				var a := atlas.get_pixel(int(r.position.x) + x, int(r.position.y) + y).a >= 0.5
				var b := src.get_pixel(x, y).a >= 0.5
				if a and b:
					inter += 1
				if a or b:
					union += 1
		assert_gt(float(inter) / float(maxi(union, 1)), 0.95, "%s: the cell's opaque shape matches its file" % n)

func test_atlas_only_uses_the_enemy_colours_in_the_heart_cell() -> void:
	var atlas := _image(IconAtlas.PATH)
	var enemy := AssetValidator.enemy_hexes()
	for n in IconAtlas.NAMES:
		var r := IconAtlas.region(n)
		var found := false
		for y in range(int(r.position.y), int(r.end.y)):
			for x in range(int(r.position.x), int(r.end.x)):
				var c := atlas.get_pixel(x, y)
				if c.a8 == 255 and enemy.has(c.to_html(false)):
					found = true
		assert_eq(found, n == &"heart", "%s: enemy colours only in the heart cell" % n)
