extends GutTest
## D-191: 6 muted looks; never brighter than any guard (R3).

const SCENE := "res://art/characters/traveler_visual.tscn"

func test_six_distinct_variants() -> void:
	var seen := {}
	for i in 6:
		var v: ActorVisual = load(SCENE).instantiate()
		add_child_autofree(v)
		TravelerVariants.apply(v, i)
		seen[TravelerVariants.signature(v)] = true
	assert_eq(seen.size(), 6)

func test_variants_are_muted() -> void:
	# ART_BIBLE R3: every traveler colour (skin excluded) has saturation <= 0.30 and value <= 0.75.
	for i in 6:
		for c in TravelerVariants.colors_of(i):
			assert_lte(c.s, 0.30, "variant %d saturation" % i)
			assert_lte(c.v, 0.75, "variant %d value" % i)

func test_travelers_never_brighter_than_the_guard_green() -> void:
	var guard := Palette.color(&"guard_green")
	for i in 6:
		for c in TravelerVariants.colors_of(i):
			assert_lt(c.s, guard.s, "variant %d is less saturated than guard_green" % i)

func test_variant_wraps_and_neighbours_differ() -> void:
	for i in 12:
		assert_eq(TravelerVariants.material_path(i), TravelerVariants.material_path(i + 6))
		assert_ne(TravelerVariants.material_path(i), TravelerVariants.material_path(i + 1))
		assert_ne(TravelerVariants.body_index(i), TravelerVariants.body_index(i + 1))

func test_every_variant_material_exists_and_uses_its_own_atlas() -> void:
	for i in 6:
		var m := load(TravelerVariants.material_path(i)) as StandardMaterial3D
		assert_not_null(m, "variant %d material" % i)
		assert_eq(m.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST)
		assert_eq(m.roughness, 1.0)
		var want := "traveler_%s_%s" % [TravelerVariants.BODIES[TravelerVariants.body_index(i)], TravelerVariants.TONES[TravelerVariants.tone_index(i)]]
		assert_true(m.albedo_texture.resource_path.ends_with("kaykit-adventurers__%s.png" % want), m.albedo_texture.resource_path)

func test_variant_atlases_are_skin_plus_one_muted_tone() -> void:
	var by_hex := {}
	for i in Palette.HEX.size():
		by_hex[Palette.HEX[i]] = Palette.NAMES[i]
	for i in 6:
		var m := load(TravelerVariants.material_path(i)) as StandardMaterial3D
		var img := Image.load_from_file(ProjectSettings.globalize_path(m.albedo_texture.resource_path))
		img.convert(Image.FORMAT_RGBA8)
		var tone := StringName("traveler_%s" % TravelerVariants.TONES[TravelerVariants.tone_index(i)])
		var counts := {}
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a < 1.0:
					continue
				var n: StringName = by_hex.get(c.to_html(false), &"?")
				counts[n] = int(counts.get(n, 0)) + 1
		for n in counts:
			assert_true(String(n).begins_with("skin_") or n == tone, "variant %d only has skin and %s, found %s" % [i, tone, n])
		assert_gt(int(counts.get(tone, 0)), 100000, "variant %d is mostly its tone" % i)
