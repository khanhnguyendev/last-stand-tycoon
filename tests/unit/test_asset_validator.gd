extends GutTest
## S4 spec 5.4: one bad fixture per rule. Fixtures are written under user:// at run time.

## Per process: worktrees and parallel runs share user://, and a sibling process deleting the fixture made this file flaky.
var ROOT := "user://av_fixture_%d" % OS.get_process_id()

func before_each() -> void:
	_rm(ROOT)
	DirAccess.make_dir_recursive_absolute(ROOT + "/assets/good-pack")
	_write(ROOT + "/assets/good-pack/LICENSE.txt", "License: (Creative Commons Zero, CC0)")
	_write(ROOT + "/assets/good-pack/a.txt", "x")

func after_all() -> void:
	_rm(ROOT)
	_rm(AROOT)

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

func test_count_triangles_visible_only() -> void:
	var root := Node3D.new()
	var a := MeshInstance3D.new()
	a.mesh = BoxMesh.new()  # 12 triangles
	root.add_child(a)
	var b := MeshInstance3D.new()
	b.mesh = BoxMesh.new()
	b.visible = false
	root.add_child(b)
	assert_eq(AssetValidator.count_triangles(root), 12)
	root.free()

func test_no_physics_rule() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "/scenes")
	var n := Node3D.new()
	var body := StaticBody3D.new()
	n.add_child(body)
	body.owner = n
	var ps := PackedScene.new()
	ps.pack(n)
	ResourceSaver.save(ps, ROOT + "/scenes/bad.tscn")
	n.free()
	assert_eq(AssetValidator.check_no_physics(PackedStringArray([ROOT + "/scenes"])).size(), 1)

func test_animation_rule() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"Idle", Animation.new())
	ResourceSaver.save(lib, ROOT + "/lib.tres")
	assert_eq(AssetValidator.check_animations(ROOT + "/lib.tres", PackedStringArray(["Idle"])), [])
	assert_eq(AssetValidator.check_animations(ROOT + "/lib.tres", PackedStringArray(["Idle", "Throw"])).size(), 1)

func test_count_triangles_hidden_parent_and_mesh_root() -> void:
	var root := Node3D.new()
	var hidden := Node3D.new()
	hidden.visible = false
	var m := MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	hidden.add_child(m)
	root.add_child(hidden)
	assert_eq(AssetValidator.count_triangles(hidden), 0, "hidden Node3D parent hides the subtree")
	assert_eq(AssetValidator.count_triangles(root), 0)
	root.free()
	var solo := MeshInstance3D.new()
	solo.mesh = BoxMesh.new()
	assert_eq(AssetValidator.count_triangles(solo), 12, "a MeshInstance3D root counts itself")
	solo.free()

func test_budget_for_longest_prefix() -> void:
	assert_eq(ArtBudgets.budget_for("res://art/characters/hero_visual.tscn"), 5500)
	assert_eq(ArtBudgets.budget_for("res://art/env/props/x.tscn"), 1500)
	assert_eq(ArtBudgets.budget_for("res://art/characters/kaykit_character.tscn"), -1)
	assert_eq(ArtBudgets.budget_for("res://world/x.tscn"), -1)

func _scene_with(child: Node, file: String) -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "/phys")
	var n := Node3D.new()
	if child != null:
		n.add_child(child)
		child.owner = n
	var ps := PackedScene.new()
	ps.pack(n)
	ResourceSaver.save(ps, ROOT + "/phys/" + file)
	n.free()

func test_no_physics_catches_shapes_and_passes_clean_scene() -> void:
	_scene_with(null, "clean.tscn")
	assert_eq(AssetValidator.check_no_physics(PackedStringArray([ROOT + "/phys"])).size(), 0, "clean Node3D")
	_scene_with(CollisionShape3D.new(), "shape.tscn")
	assert_eq(AssetValidator.check_no_physics(PackedStringArray([ROOT + "/phys"])).size(), 1, "bare CollisionShape3D")
	_scene_with(CollisionPolygon3D.new(), "poly.tscn")
	assert_eq(AssetValidator.check_no_physics(PackedStringArray([ROOT + "/phys"])).size(), 2, "CollisionPolygon3D")

# --- S5 audio rules (D-211) ---

var AROOT := "user://validator_audio_%d" % OS.get_process_id()

func _audio_fixture() -> Dictionary:
	_rm(AROOT)
	DirAccess.make_dir_recursive_absolute(AROOT + "/assets/pack")
	_write(AROOT + "/assets/pack/a.ogg", "0123456789")
	return {&"a": {"path": AROOT + "/assets/pack/a.ogg"}}

func test_audio_ok_and_missing_path() -> void:
	var sfx := _audio_fixture()
	assert_eq(AssetValidator.check_audio(sfx, {}, AROOT + "/assets", 1000, 60.0), [], "clean")
	sfx[&"b"] = {"path": AROOT + "/assets/pack/nope.ogg"}
	assert_eq(AssetValidator.check_audio(sfx, {}, AROOT + "/assets", 1000, 60.0).size(), 1, "missing path")
	_rm(AROOT)

func test_audio_reports_unnamed_file() -> void:
	var sfx := _audio_fixture()
	_write(AROOT + "/assets/pack/extra.ogg", "x")
	var e := AssetValidator.check_audio(sfx, {}, AROOT + "/assets", 1000, 60.0)
	assert_eq(e.size(), 1, "extra.ogg is not named by the manifest")
	_rm(AROOT)

func test_audio_reports_total_over_budget() -> void:
	var sfx := _audio_fixture()
	assert_eq(AssetValidator.check_audio(sfx, {}, AROOT + "/assets", 10, 60.0), [], "10 B fits budget 10")
	assert_eq(AssetValidator.check_audio(sfx, {}, AROOT + "/assets", 5, 60.0).size(), 1, "10 B over budget 5")
	_rm(AROOT)

func test_audio_reports_long_music() -> void:
	var track: Dictionary = AudioManifest.MUSIC[&"day"]
	var music := {&"day": {"path": track.path}}
	_rm(AROOT)
	DirAccess.make_dir_recursive_absolute(AROOT + "/assets")
	assert_eq(AssetValidator.check_audio({}, music, AROOT + "/assets", 1000, 0.1).size(), 1, "music longer than 0.1 s")
	assert_eq(AssetValidator.check_audio({}, music, AROOT + "/assets", 1000, 60.0), [], "music within 60 s")
	_rm(AROOT)

func test_audio_location() -> void:
	_rm(AROOT)
	DirAccess.make_dir_recursive_absolute(AROOT + "/ui")
	DirAccess.make_dir_recursive_absolute(AROOT + "/assets/p")
	DirAccess.make_dir_recursive_absolute(AROOT + "/build")
	_write(AROOT + "/ui/x.ogg", "x")
	_write(AROOT + "/build/z.ogg", "z")
	_write(AROOT + "/assets/p/y.ogg", "y")
	_write(AROOT + "/assets/p/y.ogg.import", "i")
	var e := AssetValidator.check_audio_location(AROOT)
	assert_eq(e.size(), 1, "only ui/x.ogg is outside assets/")
	assert_true(String(e[0]).contains("ui/x.ogg"))
	_rm(AROOT)

func test_audio_reports_orphan_import() -> void:
	var sfx := _audio_fixture()
	_write(AROOT + "/assets/pack/a.ogg.import", "i")
	assert_eq(AssetValidator.check_audio(sfx, {}, AROOT + "/assets", 1000, 60.0), [], "import with its source is fine")
	_write(AROOT + "/assets/pack/gone.ogg.import", "i")
	var e := AssetValidator.check_audio(sfx, {}, AROOT + "/assets", 1000, 60.0)
	assert_eq(e.size(), 1, "gone.ogg.import has no source")
	assert_true(String(e[0]).begins_with("orphan import:"))
	_rm(AROOT)
