class_name ArtBudgets
extends RefCounted
## Triangle budgets (D-196). Keys are res:// path prefixes of scenes the validator instantiates.
## Characters: the KayKit bare body (head, torso, arms, legs; every hand and head prop hidden) measures 3921 to 4263,
## and role kits with hat/hood, cape and weapon measure ~4.8k-5.3k, so 5500 (D-198).
const TRIANGLES := {
	"res://art/characters/hero": 5500, "res://art/characters/archer": 5500, "res://art/characters/tank": 5500,
	"res://art/characters/traveler": 5500, "res://art/boar": 1500, "res://art/env/tower": 4000,
	"res://art/env/fence": 1500, "res://art/env/diner": 12000, "res://art/env/props": 1500,
	"res://art/pickups": 1500,
}

static func budget_for(path: String) -> int:
	var best := ""
	for k in TRIANGLES:
		if path.begins_with(k) and k.length() > best.length():
			best = k
	return TRIANGLES[best] if best != "" else -1
