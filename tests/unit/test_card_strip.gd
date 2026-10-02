extends GutTest
## Task 15: the card strip shows one 56 px icon plus a level badge, drawn by one Control (16b) per owned card, in catalog order.

var main: Main
var strip: CardStrip

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(82)
	strip = main.hud.card_strip

func test_empty_at_start() -> void:
	assert_eq(strip.shown(), [])
	assert_eq(strip.size, Vector2.ZERO)
	assert_eq(strip.text, "")

func test_icons_and_levels_in_catalog_order() -> void:
	GameState.debug_grant_card(&"tank")
	GameState.debug_grant_card(&"hero_damage")
	GameState.debug_grant_card(&"tank")
	assert_eq(strip.shown(), [[&"hero_damage", 1], [&"tank", 2]])
	assert_eq(strip.text, "DM1  TK2", "glyph summary kept for debug")
	assert_eq(strip.get_child_count(), 0, "one custom-draw Control, no per-card nodes")
	assert_eq(strip.cell_rect(0), Rect2(0, 0, CardStrip.ICON_PX, CardStrip.ICON_PX))
	assert_eq(strip.cell_rect(1), Rect2(CardStrip.ICON_PX + CardStrip.GAP, 0, CardStrip.ICON_PX, CardStrip.ICON_PX))
	assert_eq(strip.size, Vector2(2.0 * CardStrip.ICON_PX + CardStrip.GAP, CardStrip.ICON_PX))
	assert_eq(strip.position, Vector2(24, 84), "same place as before")

func test_clears_on_new_game() -> void:
	GameState.debug_grant_card(&"archer")
	assert_eq(strip.shown().size(), 1)
	GameState.new_game(2)
	assert_eq(strip.shown(), [])
	assert_eq(strip.size, Vector2.ZERO)

func test_hud_icons_are_present() -> void:
	var hud := main.hud
	assert_not_null(hud.icons)
	assert_not_null(IconAtlas.texture())
	assert_eq(hud.icons.coin_rect().size, Vector2(Hud.ICON_PX, Hud.ICON_PX))
	assert_eq(hud.icons.heart_rect().size, Vector2(Hud.ICON_PX, Hud.ICON_PX))
	assert_lt(hud.icons.coin_rect().end.x, hud.gold_label.get_global_rect().position.x + 1.0, "the coin sits left of the gold label")
	assert_lt(hud.icons.heart_rect().end.x, hud.diner_bar.get_global_rect().position.x + 1.0, "the heart sits left of the bar")
	assert_eq(hud.moons.size(), GameState.lane_plan.size())

func test_strip_after_restore_with_cards() -> void:
	GameState.debug_grant_card(&"archer")
	GameState.debug_grant_card(&"hero_damage")
	GameState.debug_grant_card(&"hero_damage")
	var snap := GameState.to_dict()
	GameState.new_game(3)
	assert_eq(strip.shown(), [])
	GameState.from_dict(snap)
	assert_eq(strip.shown(), [[&"hero_damage", 2], [&"archer", 1]])

func test_every_card_has_an_atlas_cell() -> void:
	for id in CardCatalog.IDS:
		var r := IconAtlas.region(CardStrip._icon_name(id))
		assert_eq(r.size, Vector2(IconAtlas.CELL, IconAtlas.CELL))
