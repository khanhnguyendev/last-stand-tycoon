extends GutTest
## S4 spec 5.2, D-188.

func _pal() -> PackedColorArray:
	return PackedColorArray([Color("ff0000"), Color("00ff00"), Color("0000ff"), Color("ffffff")])

func test_oklab_white_and_black() -> void:
	var w := PaletteMath.to_oklab(Color.WHITE)
	assert_almost_eq(w.x, 1.0, 0.001)
	assert_almost_eq(w.y, 0.0, 0.001)
	assert_almost_eq(w.z, 0.0, 0.001)
	assert_almost_eq(PaletteMath.to_oklab(Color.BLACK).x, 0.0, 0.001)
	assert_almost_eq(PaletteMath.to_oklab(Color("ff0000")), Vector3(0.62796, 0.22486, 0.12585), Vector3.ONE * 0.001)
	assert_almost_eq(PaletteMath.to_oklab(Color(0.5, 0.5, 0.5)).x, 0.5982, 0.001)

func test_nearest_picks_closest_and_ties_lowest() -> void:
	assert_eq(PaletteMath.nearest(Color("f01010"), _pal()), 0)
	assert_eq(PaletteMath.nearest(Color("eeeeee"), _pal()), 3)
	var dup := PackedColorArray([Color("123456"), Color("123456")])
	assert_eq(PaletteMath.nearest(Color("123456"), dup), 0)

func test_remap_image_maps_every_pixel_and_keeps_alpha() -> void:
	var img := Image.create_empty(2, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0.9, 0.1, 0.1, 1.0))
	img.set_pixel(1, 0, Color(0.1, 0.1, 0.9, 0.5))
	var out := PaletteMath.remap_image(img, _pal(), {})
	assert_eq(out.get_format(), Image.FORMAT_RGBA8)
	assert_eq(out.get_pixel(0, 0).to_html(false), "ff0000")
	assert_eq(out.get_pixel(1, 0).to_html(false), "0000ff")
	assert_almost_eq(out.get_pixel(1, 0).a, 0.5, 0.01)

func test_override_retargets_a_swatch() -> void:
	var img := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color("f01010"))
	var key := img.get_pixel(0, 0).to_html(false)
	var out := PaletteMath.remap_image(img, _pal(), {key: 3})
	assert_eq(out.get_pixel(0, 0).to_html(false), "ffffff")

func test_remap_is_deterministic_and_does_not_mutate_input() -> void:
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.6, 0.2))
	var before := img.get_data()
	var a := PaletteMath.remap_image(img, _pal(), {})
	var b := PaletteMath.remap_image(img, _pal(), {})
	assert_eq(a.get_data(), b.get_data())
	assert_eq(img.get_data(), before)
	assert_eq(img.get_format(), Image.FORMAT_RGBA8)
