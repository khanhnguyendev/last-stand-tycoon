class_name Palette
extends RefCounted
## The master palette (D-188, docs/ART_BIBLE.md §2). Fixed order; art/palette/palette.png is this list as 32x1.

const NAMES: Array[StringName] = [
	&"ink", &"ink_soft", &"apron_white", &"warm_white", &"gold", &"gold_dark",
	&"skin_light", &"skin_mid", &"skin_dark",
	&"guard_green", &"guard_green_dark", &"steel", &"steel_dark", &"cloth_blue",
	&"traveler_grey", &"traveler_beige", &"traveler_brown",
	&"enemy_red", &"enemy_maroon", &"enemy_snout",
	&"grass", &"grass_dark", &"dirt", &"dirt_dark", &"stone", &"wood", &"wood_dark",
	&"diner_teal", &"diner_cream", &"ice_blue", &"steak_brown", &"night_sky",
]
const HEX: PackedStringArray = [
	"2b2233", "4a3f55", "fbf7ee", "fff3c4", "f2c230", "c08a1e",
	"f4c9a0", "d99a6c", "8d5a3b",
	"3f9a4a", "2a6b35", "b8c2cc", "6e7a86", "4a78b5",
	"9a9488", "b8a98e", "7d6e5c",
	"c8402f", "7a2e22", "c97a6a",
	"7fbf5a", "5e9a45", "c9a06a", "a07a4a", "a3a3a8", "a8683c", "6e4527",
	"4fb3a9", "f3e3c3", "7cc6e0", "8a4a2b", "1f2a4a",
]

static func colors() -> PackedColorArray:
	var out := PackedColorArray()
	for h in HEX:
		out.append(Color(h))
	return out

static func index_of(name: StringName) -> int:
	return NAMES.find(name)

static func color(name: StringName) -> Color:
	var i := index_of(name)
	assert(i >= 0, "unknown palette colour %s" % name)
	return Color(HEX[i])

static func hex_set() -> Dictionary:
	var d := {}
	for h in HEX:
		d[h] = true
	return d
