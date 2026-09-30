class_name CardCatalog
extends RefCounted
## The 7 hero-card types (S2 spec 4.1, D-166). IDS order is the tie-break order everywhere.

const IDS: Array[StringName] = [&"hero_damage", &"attack_speed", &"move_speed", &"carry_capacity",
	&"gold_per_steak", &"archer", &"tank"]
const UPGRADES: Array[StringName] = [&"hero_damage", &"attack_speed", &"move_speed", &"carry_capacity", &"gold_per_steak"]
const ADVENTURERS: Array[StringName] = [&"archer", &"tank"]
const NAMES := {
	&"hero_damage": "Sharp Cleaver", &"attack_speed": "Quick Hands", &"move_speed": "Running Shoes",
	&"carry_capacity": "Big Backpack", &"gold_per_steak": "Fancy Menu", &"archer": "Archer", &"tank": "Tank",
}
const GLYPHS := {
	&"hero_damage": "DM", &"attack_speed": "AS", &"move_speed": "MV", &"carry_capacity": "CA",
	&"gold_per_steak": "GO", &"archer": "AR", &"tank": "TK",
}

static func kind(id: StringName) -> StringName:
	assert(id in IDS, "unknown card %s" % id)
	return &"adventurer" if id in ADVENTURERS else &"upgrade"

static func max_level(cb: CardBalance) -> int:
	return cb.max_level

static func display_name(id: StringName) -> String:
	return TranslationServer.translate(NAMES.get(id, String(id)))

static func effect_text(id: StringName, cb: CardBalance) -> String:
	match id:
		&"hero_damage":
			return TranslationServer.translate("+%d%% hero damage") % roundi(cb.damage_step * 100.0)
		&"attack_speed":
			return TranslationServer.translate("+%d%% attack speed") % roundi(cb.attack_speed_step * 100.0)
		&"move_speed":
			return TranslationServer.translate("+%d%% move speed") % roundi(cb.move_step * 100.0)
		&"carry_capacity":
			return TranslationServer.translate("+%d carry") % cb.carry_step
		&"gold_per_steak":
			return TranslationServer.translate("+%d gold per steak") % cb.gold_step
		&"archer":
			return TranslationServer.translate("Shoots from the roof")
		&"tank":
			return TranslationServer.translate("Holds the west lane")
	assert(false, "unknown card %s" % id)
	return ""

## The level line on a card: NEW for an unowned card, otherwise "Lv n > n+1".
static func level_text(current_level: int) -> String:
	if current_level <= 0:
		return TranslationServer.translate("NEW")
	return TranslationServer.translate("Lv %d > %d") % [current_level, current_level + 1]

static func pick_banner(id: StringName, new_level: int) -> String:
	if kind(id) == &"adventurer" and new_level == 1:
		return TranslationServer.translate("The %s joins!") % display_name(id)
	return TranslationServer.translate("%s Lv %d") % [display_name(id), new_level]
