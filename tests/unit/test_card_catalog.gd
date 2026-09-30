extends GutTest

func before_each() -> void:
	Balance.reset()

func test_ids_kinds_and_order() -> void:
	assert_eq(CardCatalog.IDS, [&"hero_damage", &"attack_speed", &"move_speed", &"carry_capacity",
		&"gold_per_steak", &"archer", &"tank"] as Array[StringName])
	assert_eq(CardCatalog.UPGRADES + CardCatalog.ADVENTURERS, CardCatalog.IDS)
	for id in CardCatalog.UPGRADES:
		assert_eq(CardCatalog.kind(id), &"upgrade")
	for id in CardCatalog.ADVENTURERS:
		assert_eq(CardCatalog.kind(id), &"adventurer")
	assert_eq(CardCatalog.max_level(Balance.data.cards), Balance.data.cards.max_level)

func test_every_card_has_text_and_glyph() -> void:
	var cb := Balance.data.cards
	for id in CardCatalog.IDS:
		assert_ne(CardCatalog.display_name(id), "", "name for %s" % id)
		assert_ne(CardCatalog.effect_text(id, cb), "", "effect for %s" % id)
		assert_eq(String(CardCatalog.GLYPHS[id]).length(), 2, "glyph for %s" % id)
	assert_eq(CardCatalog.effect_text(&"hero_damage", cb), "+%d%% hero damage" % roundi(cb.damage_step * 100.0))
	assert_eq(CardCatalog.effect_text(&"carry_capacity", cb), "+%d carry" % cb.carry_step)
	assert_eq(CardCatalog.effect_text(&"gold_per_steak", cb), "+%d gold per steak" % cb.gold_step)

func test_level_and_banner_text() -> void:
	assert_eq(CardCatalog.level_text(0), "NEW")
	assert_eq(CardCatalog.level_text(2), "Lv 2 » 3")
	assert_eq(CardCatalog.pick_banner(&"archer", 1), "The Archer joins!")
	assert_eq(CardCatalog.pick_banner(&"tank", 3), "Tank Lv 3")
	assert_eq(CardCatalog.pick_banner(&"move_speed", 2), "Running Shoes Lv 2")
