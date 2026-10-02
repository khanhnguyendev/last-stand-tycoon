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

func test_only_the_heart_uses_enemy_red() -> void:
	var enemy := {}
	for n in ["enemy_red", "enemy_maroon", "enemy_snout"]:
		enemy[Palette.HEX[Palette.index_of(StringName(n))]] = true
	for f in DirAccess.get_files_at("res://art/icons"):
		if not f.ends_with(".png") or f == "heart.png":
			continue
		var img := _image("res://art/icons/" + f)
		var hit := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a8 == 255 and enemy.has(c.to_html(false)):
					hit += 1
		assert_eq(hit, 0, "%s has no enemy colours (R4)" % f)
