extends GutTest
## D-188: 32 named colours; palette.png is the same list as a 32x1 strip.

func test_size_names_unique_hex_valid() -> void:
	assert_eq(Palette.NAMES.size(), 32)
	assert_eq(Palette.HEX.size(), 32)
	var seen := {}
	for n in Palette.NAMES:
		assert_false(seen.has(n), "duplicate name %s" % n)
		seen[n] = true
	for h in Palette.HEX:
		assert_true(h.is_valid_html_color() and h.length() == 6 and h == h.to_lower(), "bad hex %s" % h)
	assert_eq(Palette.hex_set().size(), 32, "hex values unique")

func test_lookup() -> void:
	assert_eq(Palette.color(&"ink").to_html(false), Palette.HEX[Palette.index_of(&"ink")])
	assert_eq(Palette.index_of(&"no_such"), -1)

func test_png_matches_constants() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/palette/palette.png"))
	assert_eq(img.get_size(), Vector2i(32, 1))
	for i in 32:
		assert_eq(img.get_pixel(i, 0).to_html(false), Palette.HEX[i])

func test_r3_traveler_colours_muted() -> void:
	for n in [&"traveler_grey", &"traveler_beige", &"traveler_brown"]:
		var c := Palette.color(n)
		assert_true(c.s <= 0.30, "%s saturation %.3f" % [n, c.s])
		assert_true(c.v <= 0.75, "%s value %.3f" % [n, c.v])
	assert_true(Palette.color(&"guard_green").s >= 0.50, "guard_green saturation")
