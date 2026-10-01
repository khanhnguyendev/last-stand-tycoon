class_name RemapManifest
extends RefCounted
## Which source atlas feeds which remapped atlas (D-188). overrides: lowercase source hex -> Palette name.
## tools/palette_remap.gd writes every `out`. Add per-asset variants (apron, muted travelers) in Tasks 7–8.

const ENTRIES: Array[Dictionary] = [
	{"src": "res://assets/kenney-tower-defense/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-tower-defense__colormap.png", "overrides": {}},
	{"src": "res://assets/kenney-castle/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-castle__colormap.png", "overrides": {}},
	{"src": "res://assets/kenney-fantasy-town/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-fantasy-town__colormap.png", "overrides": {}},
	{"src": "res://assets/kenney-city-commercial/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-city-commercial__colormap.png", "overrides": {}},
	{"src": "res://assets/kenney-food/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-food__colormap.png", "overrides": {}},
	{"src": "res://assets/kenney-platformer/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-platformer__colormap.png", "overrides": {}},
	{"src": "res://assets/kaykit-adventurers/Textures/barbarian_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__barbarian_texture.png", "overrides": {}},
	{"src": "res://assets/kaykit-adventurers/Textures/knight_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__knight_texture.png", "overrides": {}},
	{"src": "res://assets/kaykit-adventurers/Textures/rogue_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__rogue_texture.png", "overrides": {}},
	{"src": "res://assets/kaykit-adventurers/Textures/mage_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__mage_texture.png", "overrides": {}},
	{"src": "res://assets/kaykit-restaurant/Assets/gltf/restaurantbits_texture.png", "out": "res://art/palette/atlas/kaykit-restaurant__restaurantbits_texture.png", "overrides": {}},
]
