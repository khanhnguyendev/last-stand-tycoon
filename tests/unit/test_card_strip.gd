extends GutTest
## Task 15: the card strip shows one 56 px icon plus a level badge per owned card, in catalog order.

var main: Main
var strip: CardStrip

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(82)
	strip = main.hud.card_strip

func _wait_free() -> void:
	await get_tree().process_frame  # refresh() queue_frees the old entries

func test_empty_at_start() -> void:
	await _wait_free()
	assert_eq(strip.shown(), [])
	assert_eq(strip.get_child_count(), 0)
	assert_eq(strip.text, "")

func test_icons_and_levels_in_catalog_order() -> void:
	GameState.debug_grant_card(&"tank")
	GameState.debug_grant_card(&"hero_damage")
	GameState.debug_grant_card(&"tank")
	await _wait_free()
	assert_eq(strip.shown(), [[&"hero_damage", 1], [&"tank", 2]])
	assert_eq(strip.text, "DM1  TK2", "glyph summary kept for debug")
	assert_eq(strip.get_child_count(), 2)
	var first := strip.get_child(0)
	var second := strip.get_child(1)
	assert_eq(first.name, &"hero_damage")
	assert_eq(second.name, &"tank")
	assert_eq(first.get_node("Badge/Level").text, "1")
	assert_eq(second.get_node("Badge/Level").text, "2")
	var icon := second.get_node("Icon") as TextureRect
	assert_eq(icon.texture.resource_path, CardCatalog.ICONS[&"tank"])
	assert_eq(second.custom_minimum_size, Vector2(CardStrip.ICON_PX, CardStrip.ICON_PX))

func test_clears_on_new_game() -> void:
	GameState.debug_grant_card(&"archer")
	await _wait_free()
	assert_eq(strip.get_child_count(), 1)
	GameState.new_game(2)
	await _wait_free()
	assert_eq(strip.get_child_count(), 0)
	assert_eq(strip.shown(), [])

func test_hud_icons_are_present() -> void:
	var hud := main.hud
	assert_not_null(hud.gold_icon.texture)
	assert_not_null(hud.heart_icon.texture)
	assert_eq(hud.gold_icon.size, Vector2(Hud.ICON_PX, Hud.ICON_PX))
	assert_lt(hud.gold_icon.get_global_rect().end.x, hud.gold_label.get_global_rect().position.x + 1.0, "the coin sits left of the gold label")
	for m in hud.moons:
		assert_true(m is TextureRect)

func test_strip_after_restore_with_cards() -> void:
	GameState.debug_grant_card(&"archer")
	GameState.debug_grant_card(&"hero_damage")
	GameState.debug_grant_card(&"hero_damage")
	var snap := GameState.to_dict()
	GameState.new_game(3)
	await _wait_free()
	assert_eq(strip.get_child_count(), 0)
	GameState.from_dict(snap)
	await _wait_free()
	assert_eq(strip.get_child_count(), 2)
	assert_eq(strip.get_child(0).name, &"hero_damage")
	assert_eq(strip.get_child(0).get_node("Badge/Level").text, "2")
	assert_eq(strip.get_child(1).name, &"archer")
	assert_eq(strip.get_child(1).get_node("Badge/Level").text, "1")
	assert_eq(strip.shown(), [[&"hero_damage", 2], [&"archer", 1]])

func test_cells_have_a_cream_backing() -> void:
	GameState.debug_grant_card(&"tank")
	await _wait_free()
	assert_true(strip.get_child(0).has_node("Backing"))
