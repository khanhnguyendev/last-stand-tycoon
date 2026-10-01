class_name ArtBudgets
extends RefCounted
## Triangle budgets (D-196). Keys are res:// path prefixes of scenes the validator instantiates.
## Characters: the KayKit bare body (head, torso, arms, legs; every hand and head prop hidden) measures 3921 to 4263,
## so the 3000 plan figure is raised to 4500 (measured maximum rounded up to the next 500).
const TRIANGLES := {
	"res://art/characters/hero": 4500, "res://art/characters/archer": 4500, "res://art/characters/tank": 4500,
	"res://art/characters/traveler": 4500, "res://art/boar": 1500, "res://art/env/tower": 4000,
	"res://art/env/fence": 1500, "res://art/env/diner": 12000, "res://art/env/props": 1500,
	"res://art/pickups": 1500,
}

static func budget_for(path: String) -> int:
	var best := ""
	for k in TRIANGLES:
		if path.begins_with(k) and k.length() > best.length():
			best = k
	return TRIANGLES[best] if best != "" else -1
