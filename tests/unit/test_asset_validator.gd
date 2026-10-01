extends GutTest
## S4 spec 5.4: one bad fixture per rule. Fixtures are written under user:// at run time.

const ROOT := "user://av_fixture"

func before_each() -> void:
	_rm(ROOT)
	DirAccess.make_dir_recursive_absolute(ROOT + "/assets/good-pack")
	_write(ROOT + "/assets/good-pack/LICENSE.txt", "License: (Creative Commons Zero, CC0)")
	_write(ROOT + "/assets/good-pack/a.txt", "x")

func after_all() -> void:
	_rm(ROOT)

func _write(p: String, s: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(s)
	f.close()

func _rm(p: String) -> void:
	var d := DirAccess.open(p)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_rm(p.path_join(sub))
	DirAccess.remove_absolute(p)

func _md(sha: String, n: int) -> String:
	return "| Good | assets/good-pack/ | x | CC0 1.0 | 2026-10-01 | %s | %d |\n" % [sha, n]

func test_licenses_ok() -> void:
	var sha := FileAccess.get_sha256(ROOT + "/assets/good-pack/LICENSE.txt")
	_write(ROOT + "/L.md", _md(sha, 2))
	assert_eq(AssetValidator.check_licenses(ROOT + "/assets", ROOT + "/L.md"), [])

func test_licenses_missing_file_row_count_sha_and_noncc0() -> void:
	_write(ROOT + "/L.md", "")
	assert_eq(AssetValidator.check_licenses(ROOT + "/assets", ROOT + "/L.md").size(), 1, "no row")
	var sha := FileAccess.get_sha256(ROOT + "/assets/good-pack/LICENSE.txt")
	_write(ROOT + "/L.md", _md(sha, 5))
	assert_eq(AssetValidator.check_licenses(ROOT + "/assets", ROOT + "/L.md").size(), 1, "count mismatch")
	_write(ROOT + "/L.md", _md("deadbeef", 2))
	assert_eq(AssetValidator.check_licenses(ROOT + "/assets", ROOT + "/L.md").size(), 1, "sha mismatch")
	_write(ROOT + "/assets/good-pack/LICENSE.txt", "CC-BY 4.0")
	var sha2 := FileAccess.get_sha256(ROOT + "/assets/good-pack/LICENSE.txt")
	_write(ROOT + "/L.md", _md(sha2, 2))
	assert_gt(AssetValidator.check_licenses(ROOT + "/assets", ROOT + "/L.md").size(), 0, "not CC0")
	DirAccess.make_dir_recursive_absolute(ROOT + "/assets/no-license")
	_write(ROOT + "/assets/no-license/b.txt", "x")
	assert_gt(AssetValidator.check_licenses(ROOT + "/assets", ROOT + "/L.md").size(), 1, "pack without LICENSE.txt")

func test_candidates_folder_is_skipped() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "/assets/_candidates/x")
	_write(ROOT + "/assets/_candidates/x/y.txt", "x")
	var sha := FileAccess.get_sha256(ROOT + "/assets/good-pack/LICENSE.txt")
	_write(ROOT + "/L.md", _md(sha, 2))
	assert_eq(AssetValidator.check_licenses(ROOT + "/assets", ROOT + "/L.md"), [])

func test_licenses_other_underscore_folder_and_loose_file_are_problems() -> void:
	var sha := FileAccess.get_sha256(ROOT + "/assets/good-pack/LICENSE.txt")
	_write(ROOT + "/L.md", _md(sha, 2))
	DirAccess.make_dir_recursive_absolute(ROOT + "/assets/_other")
	_write(ROOT + "/assets/_other/b.txt", "x")
	assert_eq(AssetValidator.check_licenses(ROOT + "/assets", ROOT + "/L.md").size(), 1, "_other without LICENSE.txt")
	_rm(ROOT + "/assets/_other")
	_write(ROOT + "/assets/loose.png", "x")
	assert_eq(AssetValidator.check_licenses(ROOT + "/assets", ROOT + "/L.md").size(), 1, "loose file")

func test_candidates_skipped_by_every_check() -> void:
	var cand := ROOT + "/c/assets/_candidates"
	DirAccess.make_dir_recursive_absolute(cand)
	var bad := Image.create_empty(1024, 8, false, Image.FORMAT_RGBA8)
	bad.fill(Color(0.123, 0.456, 0.789, 1.0))
	bad.save_png(ProjectSettings.globalize_path(cand + "/big.png"))
	var red := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	red.fill(Palette.color(&"enemy_red"))
	red.save_png(ProjectSettings.globalize_path(cand + "/red.png"))
	_write(cand + "/m.glb", "x")
	_write(cand + "/a.gd", "var m := Visuals.box(Vector3.ONE, Color.RED)\n")
	var enemy := {Palette.HEX[Palette.index_of(&"enemy_red")]: true}
	assert_eq(AssetValidator.check_palette(PackedStringArray([ROOT + "/c"]), Palette.hex_set()), [])
	assert_eq(AssetValidator.check_texture_sizes(ROOT + "/c", 512), [])
	assert_eq(AssetValidator.check_stray_models(ROOT + "/c", PackedStringArray(["art"])), [])
	assert_eq(AssetValidator.check_no_placeholders(PackedStringArray([ROOT + "/c"])), [])
	assert_eq(AssetValidator.check_no_enemy_colors(ROOT + "/c", enemy), [])

func test_palette_rule_checks_opaque_pixels_only() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "/pal")
	var img := Image.create_empty(2, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(Palette.HEX[0]))
	img.set_pixel(1, 0, Color(0.123, 0.456, 0.789, 0.5))  # off-palette but not opaque
	img.save_png(ProjectSettings.globalize_path(ROOT + "/pal/ok.png"))
	assert_eq(AssetValidator.check_palette(PackedStringArray([ROOT + "/pal"]), Palette.hex_set()), [])
	img.set_pixel(1, 0, Color(0.123, 0.456, 0.789, 1.0))
	img.save_png(ProjectSettings.globalize_path(ROOT + "/pal/bad.png"))
	assert_eq(AssetValidator.check_palette(PackedStringArray([ROOT + "/pal"]), Palette.hex_set()).size(), 1)

func test_texture_size_rule() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "/tex")
	Image.create_empty(512, 512, false, Image.FORMAT_RGBA8).save_png(ProjectSettings.globalize_path(ROOT + "/tex/ok.png"))
	assert_eq(AssetValidator.check_texture_sizes(ROOT + "/tex", 512), [])
	Image.create_empty(1024, 8, false, Image.FORMAT_RGBA8).save_png(ProjectSettings.globalize_path(ROOT + "/tex/big.png"))
	assert_eq(AssetValidator.check_texture_sizes(ROOT + "/tex", 512).size(), 1)

func test_stray_models_rule() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "/game/actors")
	_write(ROOT + "/game/actors/x.glb", "x")
	DirAccess.make_dir_recursive_absolute(ROOT + "/game/assets/p")
	_write(ROOT + "/game/assets/p/y.glb", "x")
	var r := AssetValidator.check_stray_models(ROOT + "/game", PackedStringArray(["assets", "art"]))
	assert_eq(r.size(), 1)
	assert_string_contains(r[0], "actors/x.glb")

func test_no_enemy_colors_rule() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "/atl")
	var img := Image.create_empty(2, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Palette.color(&"grass"))
	img.set_pixel(1, 0, Palette.color(&"grass"))
	img.save_png(ProjectSettings.globalize_path(ROOT + "/atl/ok.png"))
	var enemy := {Palette.HEX[Palette.index_of(&"enemy_red")]: true}
	assert_eq(AssetValidator.check_no_enemy_colors(ROOT + "/atl", enemy), [])
	img.set_pixel(1, 0, Palette.color(&"enemy_red"))
	img.save_png(ProjectSettings.globalize_path(ROOT + "/atl/bad.png"))
	assert_eq(AssetValidator.check_no_enemy_colors(ROOT + "/atl", enemy).size(), 1)

func test_placeholder_rule() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "/code")
	_write(ROOT + "/code/a.gd", "var m := Visuals.box(Vector3.ONE, Color.RED)\n")
	_write(ROOT + "/code/b.gd", "var c := Visuals.COLORS.boar\n")
	var r := AssetValidator.check_no_placeholders(PackedStringArray([ROOT + "/code"]))
	assert_eq(r.size(), 1)
	assert_string_contains(r[0], "a.gd")
