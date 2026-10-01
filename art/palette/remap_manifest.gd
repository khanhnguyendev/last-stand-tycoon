class_name RemapManifest
extends RefCounted
## Which source atlas feeds which remapped atlas (D-188). overrides: lowercase source hex -> Palette name.
## tools/palette_remap.gd writes every `out`. Per-asset variants: the Barbarian apron (Task 7b); the guard swaps and the six
## muted traveler atlases (Task 8) are rule-based entries ("guard_swap", "tone"), expanded into hex overrides by `_build()`.

## The Barbarian atlas has two identical vertical blue gradients (x 0..127 = the torso, x 128..255 = the sleeves, rows
## 256..511), so no colour override can tell them apart. Both sets name the same 142 source hexes: the default atlas
## turns the gradient into cloth_blue (the sleeves), the apron variant into apron_white. hero_visual.tscn puts the apron
## material on Barbarian_Body only (S4 Task 7b, D-191).
const BARBARIAN_BLUE_TO_CLOTH := {
	"354e5a": "cloth_blue", "354e5b": "cloth_blue", "364f5b": "cloth_blue", "364f5c": "cloth_blue", "36505c": "cloth_blue",
	"37505d": "cloth_blue", "37515d": "cloth_blue", "37515e": "cloth_blue", "38515e": "cloth_blue", "38525f": "cloth_blue",
	"385260": "cloth_blue", "395260": "cloth_blue", "395360": "cloth_blue", "395361": "cloth_blue", "3a5462": "cloth_blue",
	"3a5463": "cloth_blue", "3a5563": "cloth_blue", "3b5564": "cloth_blue", "3b5664": "cloth_blue", "3b5665": "cloth_blue",
	"3c5665": "cloth_blue", "3c5766": "cloth_blue", "3d5767": "cloth_blue", "3d5867": "cloth_blue", "3d5868": "cloth_blue",
	"3d5968": "cloth_blue", "3e5969": "cloth_blue", "3e5a6a": "cloth_blue", "3f5a6a": "cloth_blue", "3f5a6b": "cloth_blue",
	"3f5b6b": "cloth_blue", "405b6c": "cloth_blue", "405c6c": "cloth_blue", "405c6d": "cloth_blue", "415d6e": "cloth_blue",
	"415d6f": "cloth_blue", "415e6f": "cloth_blue", "425e6f": "cloth_blue", "425e70": "cloth_blue", "425f71": "cloth_blue",
	"435f71": "cloth_blue", "435f72": "cloth_blue", "436072": "cloth_blue", "446073": "cloth_blue", "446173": "cloth_blue",
	"446174": "cloth_blue", "456274": "cloth_blue", "456275": "cloth_blue", "456276": "cloth_blue", "466376": "cloth_blue",
	"466377": "cloth_blue", "466477": "cloth_blue", "476478": "cloth_blue", "476578": "cloth_blue", "476579": "cloth_blue",
	"486579": "cloth_blue", "48667a": "cloth_blue", "48667b": "cloth_blue", "49667b": "cloth_blue", "49677b": "cloth_blue",
	"49677c": "cloth_blue", "4a687d": "cloth_blue", "4a687e": "cloth_blue", "4a697e": "cloth_blue", "4b697f": "cloth_blue",
	"4b6a7f": "cloth_blue", "4b6a80": "cloth_blue", "4c6a80": "cloth_blue", "4c6b81": "cloth_blue", "4d6b82": "cloth_blue",
	"4d6c82": "cloth_blue", "4d6c83": "cloth_blue", "4d6d83": "cloth_blue", "4e6d84": "cloth_blue", "4e6e85": "cloth_blue",
	"4f6e85": "cloth_blue", "4f6e86": "cloth_blue", "4f6f86": "cloth_blue", "506f87": "cloth_blue", "507087": "cloth_blue",
	"507088": "cloth_blue", "517189": "cloth_blue", "51718a": "cloth_blue", "51728a": "cloth_blue", "52728a": "cloth_blue",
	"52728b": "cloth_blue", "52738c": "cloth_blue", "53738c": "cloth_blue", "53738d": "cloth_blue", "53748d": "cloth_blue",
	"54748e": "cloth_blue", "54758e": "cloth_blue", "54758f": "cloth_blue", "55768f": "cloth_blue", "557690": "cloth_blue",
	"557691": "cloth_blue", "567791": "cloth_blue", "567792": "cloth_blue", "567892": "cloth_blue", "577893": "cloth_blue",
	"577993": "cloth_blue", "577994": "cloth_blue", "587994": "cloth_blue", "587a95": "cloth_blue", "587a96": "cloth_blue",
	"597a96": "cloth_blue", "597b96": "cloth_blue", "597b97": "cloth_blue", "5a7c98": "cloth_blue", "5a7c99": "cloth_blue",
	"5a7d99": "cloth_blue", "5b7d9a": "cloth_blue", "5b7e9a": "cloth_blue", "5b7e9b": "cloth_blue", "5c7e9b": "cloth_blue",
	"5c7f9c": "cloth_blue", "5d7f9d": "cloth_blue", "5d809d": "cloth_blue", "5d809e": "cloth_blue", "5d819e": "cloth_blue",
	"5e819f": "cloth_blue", "5e82a0": "cloth_blue", "5f82a0": "cloth_blue", "5f82a1": "cloth_blue", "5f83a1": "cloth_blue",
	"6083a2": "cloth_blue", "6084a2": "cloth_blue", "6084a3": "cloth_blue", "6185a4": "cloth_blue", "6185a5": "cloth_blue",
	"6186a5": "cloth_blue", "6286a5": "cloth_blue", "6286a6": "cloth_blue", "6287a7": "cloth_blue", "6387a7": "cloth_blue",
	"6387a8": "cloth_blue", "6388a8": "cloth_blue", "6488a9": "cloth_blue", "6489a9": "cloth_blue", "6489aa": "cloth_blue",
	"658aaa": "cloth_blue", "658aab": "cloth_blue",
}

const BARBARIAN_BLUE_TO_APRON := {
	"354e5a": "apron_white", "354e5b": "apron_white", "364f5b": "apron_white", "364f5c": "apron_white", "36505c": "apron_white",
	"37505d": "apron_white", "37515d": "apron_white", "37515e": "apron_white", "38515e": "apron_white", "38525f": "apron_white",
	"385260": "apron_white", "395260": "apron_white", "395360": "apron_white", "395361": "apron_white", "3a5462": "apron_white",
	"3a5463": "apron_white", "3a5563": "apron_white", "3b5564": "apron_white", "3b5664": "apron_white", "3b5665": "apron_white",
	"3c5665": "apron_white", "3c5766": "apron_white", "3d5767": "apron_white", "3d5867": "apron_white", "3d5868": "apron_white",
	"3d5968": "apron_white", "3e5969": "apron_white", "3e5a6a": "apron_white", "3f5a6a": "apron_white", "3f5a6b": "apron_white",
	"3f5b6b": "apron_white", "405b6c": "apron_white", "405c6c": "apron_white", "405c6d": "apron_white", "415d6e": "apron_white",
	"415d6f": "apron_white", "415e6f": "apron_white", "425e6f": "apron_white", "425e70": "apron_white", "425f71": "apron_white",
	"435f71": "apron_white", "435f72": "apron_white", "436072": "apron_white", "446073": "apron_white", "446173": "apron_white",
	"446174": "apron_white", "456274": "apron_white", "456275": "apron_white", "456276": "apron_white", "466376": "apron_white",
	"466377": "apron_white", "466477": "apron_white", "476478": "apron_white", "476578": "apron_white", "476579": "apron_white",
	"486579": "apron_white", "48667a": "apron_white", "48667b": "apron_white", "49667b": "apron_white", "49677b": "apron_white",
	"49677c": "apron_white", "4a687d": "apron_white", "4a687e": "apron_white", "4a697e": "apron_white", "4b697f": "apron_white",
	"4b6a7f": "apron_white", "4b6a80": "apron_white", "4c6a80": "apron_white", "4c6b81": "apron_white", "4d6b82": "apron_white",
	"4d6c82": "apron_white", "4d6c83": "apron_white", "4d6d83": "apron_white", "4e6d84": "apron_white", "4e6e85": "apron_white",
	"4f6e85": "apron_white", "4f6e86": "apron_white", "4f6f86": "apron_white", "506f87": "apron_white", "507087": "apron_white",
	"507088": "apron_white", "517189": "apron_white", "51718a": "apron_white", "51728a": "apron_white", "52728a": "apron_white",
	"52728b": "apron_white", "52738c": "apron_white", "53738c": "apron_white", "53738d": "apron_white", "53748d": "apron_white",
	"54748e": "apron_white", "54758e": "apron_white", "54758f": "apron_white", "55768f": "apron_white", "557690": "apron_white",
	"557691": "apron_white", "567791": "apron_white", "567792": "apron_white", "567892": "apron_white", "577893": "apron_white",
	"577993": "apron_white", "577994": "apron_white", "587994": "apron_white", "587a95": "apron_white", "587a96": "apron_white",
	"597a96": "apron_white", "597b96": "apron_white", "597b97": "apron_white", "5a7c98": "apron_white", "5a7c99": "apron_white",
	"5a7d99": "apron_white", "5b7d9a": "apron_white", "5b7e9a": "apron_white", "5b7e9b": "apron_white", "5c7e9b": "apron_white",
	"5c7f9c": "apron_white", "5d7f9d": "apron_white", "5d809d": "apron_white", "5d809e": "apron_white", "5d819e": "apron_white",
	"5e819f": "apron_white", "5e82a0": "apron_white", "5f82a0": "apron_white", "5f82a1": "apron_white", "5f83a1": "apron_white",
	"6083a2": "apron_white", "6084a2": "apron_white", "6084a3": "apron_white", "6185a4": "apron_white", "6185a5": "apron_white",
	"6186a5": "apron_white", "6286a5": "apron_white", "6286a6": "apron_white", "6287a7": "apron_white", "6387a7": "apron_white",
	"6387a8": "apron_white", "6388a8": "apron_white", "6488a9": "apron_white", "6489a9": "apron_white", "6489aa": "apron_white",
	"658aaa": "apron_white", "658aab": "apron_white",
}

const BASE_ENTRIES: Array[Dictionary] = [
	{"src": "res://assets/kenney-tower-defense/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-tower-defense__colormap.png", "overrides": {}},
	{"src": "res://assets/kenney-castle/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-castle__colormap.png", "overrides": {}},
	{"src": "res://assets/kenney-fantasy-town/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-fantasy-town__colormap.png", "overrides": {}},
	{"src": "res://assets/kenney-city-commercial/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-city-commercial__colormap.png", "overrides": {}},
	{"src": "res://assets/kenney-food/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-food__colormap.png", "overrides": {}},
	{"src": "res://assets/kenney-platformer/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-platformer__colormap.png", "overrides": {}},
	{"src": "res://assets/kaykit-adventurers/Textures/barbarian_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__barbarian_texture.png", "overrides": BARBARIAN_BLUE_TO_CLOTH},
	{"src": "res://assets/kaykit-adventurers/Textures/barbarian_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__barbarian_apron.png", "overrides": BARBARIAN_BLUE_TO_APRON},
	{"src": "res://assets/kaykit-adventurers/Textures/knight_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__knight_texture.png", "overrides": {}, "guard_swap": true},
	{"src": "res://assets/kaykit-adventurers/Textures/rogue_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__rogue_texture.png", "overrides": {}, "guard_swap": true},
	{"src": "res://assets/kaykit-adventurers/Textures/mage_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__mage_texture.png", "overrides": {}},
	{"src": "res://assets/kaykit-restaurant/Assets/gltf/restaurantbits_texture.png", "out": "res://art/palette/atlas/kaykit-restaurant__restaurantbits_texture.png", "overrides": {}},
	{"src": "res://assets/kaykit-adventurers/Textures/rogue_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__traveler_rogue_grey.png", "overrides": {}, "tone": "traveler_grey"},
	{"src": "res://assets/kaykit-adventurers/Textures/rogue_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__traveler_rogue_beige.png", "overrides": {}, "tone": "traveler_beige"},
	{"src": "res://assets/kaykit-adventurers/Textures/rogue_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__traveler_rogue_brown.png", "overrides": {}, "tone": "traveler_brown"},
	{"src": "res://assets/kaykit-adventurers/Textures/mage_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__traveler_mage_grey.png", "overrides": {}, "tone": "traveler_grey"},
	{"src": "res://assets/kaykit-adventurers/Textures/mage_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__traveler_mage_beige.png", "overrides": {}, "tone": "traveler_beige"},
	{"src": "res://assets/kaykit-adventurers/Textures/mage_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__traveler_mage_brown.png", "overrides": {}, "tone": "traveler_brown"},
]

## R2 / D-191: the hero and rewards own apron_white, warm_white, gold and gold_dark; travelers own traveler_*.
## A guard atlas moves every swatch whose nearest palette colour is a key here to the value.
const GUARD_SWAPS := {
	"apron_white": "steel", "warm_white": "steel", "gold": "steel_dark", "gold_dark": "steel_dark",
	"traveler_grey": "steel_dark", "traveler_beige": "steel", "traveler_brown": "wood_dark",
}
## Swatches a traveler keeps as skin. skin_dark is left out: on these atlases it is the gloves and boots (leather), not skin.
const SKIN_KEEP: Array[String] = ["skin_light", "skin_mid"]
const IMAGE_SIZE := 512  # tools/palette_remap.gd resizes the 1024 KayKit atlases to this

## Every entry with its hex overrides expanded. Built when this script loads (only tools/palette_remap.gd loads it).
static var _default_names := {}
static var ENTRIES: Array[Dictionary] = _build()

static func _build() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in BASE_ENTRIES:
		var d := e.duplicate()
		var ov: Dictionary = d.overrides.duplicate()
		if d.get("guard_swap", false):
			for hex in default_names(d.src):
				var n: String = default_names(d.src)[hex]
				if GUARD_SWAPS.has(n):
					ov[hex] = GUARD_SWAPS[n]
		elif d.has("tone"):
			# Every non-skin swatch goes to the one traveler colour; skin swatches keep their (nearest) skin tones.
			for hex in default_names(d.src):
				if not SKIN_KEEP.has(default_names(d.src)[hex]):
					ov[hex] = d.tone
		d.overrides = ov
		d.erase("guard_swap")
		d.erase("tone")
		out.append(d)
	return out

## The palette the tool maps atlases with (ART_BIBLE R4): enemy_* entries are replaced by a far-away sentinel, so
## nearest() never picks them. Shared by the tool and default_names() so they can't drift.
static func atlas_colors() -> PackedColorArray:
	var pal = load("res://art/palette/palette.gd")
	var colors: PackedColorArray = pal.colors()
	for n in pal.NAMES:
		if String(n).begins_with("enemy_"):
			colors[pal.index_of(n)] = Color(10, 10, 10)
	return colors

## lowercase source hex (after the tool's resize) -> the palette name the tool maps it to by default (no enemy_*, R4).
static func default_names(src: String) -> Dictionary:
	if _default_names.has(src):
		return _default_names[src]
	var pal = load("res://art/palette/palette.gd")
	var pm = load("res://core/palette_math.gd")
	var colors := atlas_colors()
	var img := Image.load_from_file(ProjectSettings.globalize_path(src))
	if img.get_width() > IMAGE_SIZE or img.get_height() > IMAGE_SIZE:
		img.resize(mini(img.get_width(), IMAGE_SIZE), mini(img.get_height(), IMAGE_SIZE), Image.INTERPOLATE_NEAREST)
	var names := {}
	for y in img.get_height():
		for x in img.get_width():
			var hex := img.get_pixel(x, y).to_html(false)
			if not names.has(hex):
				names[hex] = String(pal.NAMES[pm.nearest(Color(hex), colors)])
	_default_names[src] = names
	return names
