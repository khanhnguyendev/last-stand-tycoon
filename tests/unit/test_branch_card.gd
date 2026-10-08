extends GutTest
## E6 Task 13 (spec 5.2, D-284, D-289): the branch card in the HUD. Every test names the wrong implementation it catches.
## Seed 1 pins the lane character: SIEGE east, HARE west; north and the south-west lane are neutral.

const ASPECTS := [9.0 / 21.0, 720.0 / 1280.0, 16.0 / 9.0]
const ASPECT_NAMES := ["9:21", "9:16", "16:9"]
const SIEGE := &"siege"
const HARE := &"hare"
const NONE := &""
## spot -> [[lane name, icon kind]], by the pinned seed.
const LANES := {
	"tower_nw": [["west road", HARE], ["north path", NONE]],
	"tower_ne": [["north path", NONE], ["east road", SIEGE]],
	"tower_w": [["west road", HARE]],
	"tower_e": [["east road", SIEGE]],
	"tower_sw": [["south road", NONE]],
	"fence_w": [["west road", HARE]],
	"fence_n": [["north path", NONE]],
	"fence_e": [["east road", SIEGE]],
	"fence_sw": [["south road", NONE]],
}
## branch -> [name, specialty, specialty icon]
const BRANCHES := {
	&"longbow": ["Longbow", "breaks brutes", SIEGE],
	&"volley": ["Volley", "hits 3 targets", HARE],
	&"stone": ["Stone wall", "holds brutes", SIEGE],
	&"spike": ["Spike fence", "hurts hares", HARE],
}
const VI := {
	"Longbow": "Cung tầm xa", "Volley": "Loạt tên", "Stone wall": "Tường đá", "Spike fence": "Hàng rào chông",
	"breaks brutes": "phá quái nặng", "holds brutes": "chặn quái nặng", "hits 3 targets": "bắn trúng 3 mục tiêu",
	"hurts hares": "làm đau thỏ", "west road": "đường phía tây", "north path": "đường phía bắc",
	"east road": "đường phía đông", "south road": "đường phía nam", "lost if broken": "mất nếu bị phá",
}

var main: Main
var pc: PhaseController
var card: BranchCard

func before_each() -> void:
	BranchPad.reset_focus()
	Balance.reset()
	Balance.data.tiers.retune_enabled = true
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)  # test-only: the build knows tier 3
	BranchCard.text_filter = Callable()
	SafeArea.override_for_tests = {}

func after_each() -> void:
	BranchCard.text_filter = Callable()
	SafeArea.override_for_tests = {}
	BranchPad.reset_focus()
	Balance.reset()
	GameState.new_game(1)

## A running game at tier 3 (or 2), day, seed 1, the hero under test control, flag on.
func _start(tier := 3) -> void:
	main = Main.create()
	add_child_autofree(main)
	pc = main.phase_controller
	main.hero.input.player_control = false
	pc.start_new_game(1)
	pc.debug_skip_to_day()
	await get_tree().physics_frame
	GameState.debug_set_tier(tier, GameState.day)
	GameState.gold = 0
	await get_tree().physics_frame
	card = main.hud.branch_card

func _max(id: String) -> void:
	GameState.gold = 100000
	while GameState.next_level_cost(id) >= 0:
		assert_gt(GameState.pay_into_spot(id, 100000), 0)
	GameState.gold = 0

func _max_all() -> void:
	for id in MapLayout.spots_for_tier(3):
		_max(id)
	await get_tree().physics_frame

func _pad_pos(id: String, i: int) -> Vector2:
	return (MapLayout.BRANCH_PADS[id] as Array)[i]

## Walks in from outside (armed), then lets the pad and the card update.
func _stand_on(id: String, i: int) -> void:
	await TestHelpers.walk_in(main.hero, _pad_pos(id, i))
	await _settle()

func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

func _texts() -> Array:
	var out: Array = []
	for l in card.all_labels():
		out.append(l.text)
	return out

func _same_image(a: Texture2D, b: Texture2D) -> bool:
	return a.get_image().get_data() == b.get_image().get_data()

# --- content -----------------------------------------------------------------------------------------

func test_the_pinned_seed_has_siege_east_and_hare_west() -> void:
	await _start()
	assert_eq(GameState.lane_character(), {"siege": "east", "hare": "west"}, "setup: the character this file's tables assume")

## Mutations: row 3 reading the wrong lane's character (a lane swapped), a missing neutral lane, row 5 on a tower, a wrong icon in row 2.
func test_every_branch_of_every_spot_shows_rows_one_to_five_as_specified() -> void:
	await _start()
	await _max_all()
	assert_eq(GameState.branch_cost("tower_e"), 500, "setup: a tower branch costs 500")
	var siege := LaneCharacterIcons.texture(SIEGE)
	var hare := LaneCharacterIcons.texture(HARE)
	assert_false(_same_image(siege, hare), "setup: the two icons differ")
	for id in MapLayout.spots_for_tier(3):
		var options := GameState.branch_options(id)
		for i in 2:
			var bid: StringName = options[i]
			var want: Array = BRANCHES[bid]
			await _stand_on(id, i)
			var tag := "%s pad %d (%s)" % [id, i, bid]
			assert_true(card.visible, "%s: the card shows" % tag)
			assert_eq(card.branch_id, bid, tag)
			# row 1
			assert_eq(card.name_label.text, want[0], "%s: name" % tag)
			assert_not_null(card.name_icon.texture, tag)
			assert_true(_same_image(card.name_icon.texture, BranchCard.branch_texture(bid)), tag)
			assert_gt(card.name_icon.texture.get_image().get_pixel(48, 48).a, 0.5, "%s: the branch icon is drawn" % tag)
			# row 2
			assert_eq(card.spec_label.text, want[1], "%s: specialty" % tag)
			assert_true(_same_image(card.spec_icon.texture, LaneCharacterIcons.texture(want[2])), "%s: the specialty's own character icon" % tag)
			assert_false(_same_image(card.spec_icon.texture, LaneCharacterIcons.texture(HARE if want[2] == SIEGE else SIEGE)), tag)
			# row 3
			var lanes: Array = LANES[id]
			assert_eq(card.lane_labels.size(), lanes.size(), "%s: one entry per guarded lane" % tag)
			for k in lanes.size():
				assert_eq(card.lane_labels[k].text, lanes[k][0], "%s: lane %d name" % [tag, k])
				var ic: TextureRect = card.lane_icons[k]
				if lanes[k][1] == NONE:
					assert_null(ic, "%s: %s is neutral, no icon" % [tag, lanes[k][0]])
				else:
					assert_not_null(ic, "%s: %s has an icon" % [tag, lanes[k][0]])
					var other := HARE if lanes[k][1] == SIEGE else SIEGE
					assert_true(_same_image(ic.texture, LaneCharacterIcons.texture(lanes[k][1])), "%s: %s shows %s" % [tag, lanes[k][0], lanes[k][1]])
					assert_false(_same_image(ic.texture, LaneCharacterIcons.texture(other)), "%s: not %s" % [tag, other])
			# row 4
			assert_eq(card.cost_label.text, str(GameState.branch_cost(id)), "%s: the remaining cost" % tag)
			assert_eq(card.bar_fill.size.x, 0.0, "%s: nothing paid" % tag)
			# row 5: fences only
			var fence := MapLayout.spot_kind(id) == "fence"
			assert_eq(card.warn_label != null, fence, "%s: the warning is a fence thing" % tag)
			assert_eq(card.warn_icon != null, fence, tag)
			if fence:
				assert_eq(card.warn_label.text, "lost if broken", tag)
				assert_true(_same_image(card.warn_icon.texture, BranchCard.branch_texture(&"broken")), "%s: the broken-fence icon" % tag)
			# every string is the tr() source
			var expect: Array = [want[0], want[1], str(GameState.branch_cost(id))]
			for l in lanes:
				expect.append(l[0])
			if fence:
				expect.append("lost if broken")
			var got := _texts()
			got.sort()
			expect.sort()
			assert_eq(got, expect, "%s: exactly these strings" % tag)

func test_the_four_branch_icons_are_four_different_pictures() -> void:
	for a in [&"longbow", &"volley", &"stone", &"spike", &"broken"]:
		for b in [&"longbow", &"volley", &"stone", &"spike", &"broken"]:
			if a != b:
				assert_false(_same_image(BranchCard.branch_texture(a), BranchCard.branch_texture(b)), "%s vs %s" % [a, b])

func test_the_volley_count_comes_from_balance() -> void:
	await _start()
	await _max_all()
	Balance.data.branches.tower(&"volley").count = 5
	await _stand_on("tower_e", 1)
	assert_eq(card.spec_label.text, "hits 5 targets", "built from the balance count, not a literal 3")

# --- behaviour ---------------------------------------------------------------------------------------

func test_the_card_exists_hidden_and_the_hud_owns_it() -> void:
	await _start()
	assert_not_null(card)
	assert_true(card is BranchCard)
	assert_false(card.visible)
	assert_eq(card.get_parent(), main.hud.root)

## Mutations: shown while the pad is unarmed (the hero was placed on it), at night, with the flag off, below tier 3.
func test_it_appears_only_on_an_armed_pad_by_day_at_tier_3_with_the_flag_on() -> void:
	await _start()
	await _max_all()
	# placed on a pad (teleport): the pad is not armed
	main.hero.teleport(_pad_pos("tower_e", 0))
	await _settle()
	assert_true(BranchPad.pad_hero_stands_on() != null, "setup: he stands inside the pad")
	assert_false(BranchPad.pad_hero_stands_on().zone.armed, "setup: but it is not armed")
	assert_false(card.visible, "an unarmed pad shows no card")
	# walks out and in: armed
	await _stand_on("tower_e", 0)
	assert_true(BranchPad.pad_hero_stands_on().zone.armed)
	assert_true(card.visible, "armed")
	# the flag off while standing
	Balance.data.tiers.retune_enabled = false
	await _settle()
	assert_false(card.visible, "flag off: nothing")
	Balance.data.tiers.retune_enabled = true
	await _settle()
	assert_true(card.visible, "flag on again")
	# night
	pc.debug_skip_to_night()
	await _settle()
	assert_false(card.visible, "no card at night")

func test_below_tier_3_with_the_flag_on_there_is_no_card() -> void:
	await _start(2)
	_max("tower_e")
	assert_true(GameState.lane_character().is_empty(), "setup: no lane character at tier 2")
	await _stand_on("tower_e", 0)
	assert_false(card.visible)

func test_with_the_flag_off_at_tier_3_there_is_no_card() -> void:
	Balance.data.tiers.retune_enabled = false
	await _start()
	await _max_all()
	await _stand_on("tower_e", 0)
	assert_true(BranchPad.pad_hero_stands_on() != null, "setup: the hero is on an armed pad")
	assert_true(BranchPad.pad_hero_stands_on().zone.armed)
	assert_false(card.visible)

## Mutation: the card staying after the branch is chosen.
func test_it_hides_when_the_hero_leaves_and_when_the_purchase_completes() -> void:
	await _start()
	await _max_all()
	await _stand_on("tower_e", 0)
	assert_true(card.visible)
	main.hero.teleport(_pad_pos("tower_e", 0) + Vector2(0, 4))
	await _settle()
	assert_false(card.visible, "left the pad")
	await _stand_on("tower_e", 1)
	assert_true(card.visible)
	GameState.gold = 500
	GameState.pay_into_branch("tower_e", &"volley", 500)
	assert_eq(GameState.branch_of("tower_e"), &"volley", "setup: chosen")
	await _settle()
	assert_false(card.visible, "the purchase completed")
	assert_eq(card.spot_id, "")

## Mutation: content fixed at the first pad (not rebuilt when the pad changes).
func test_walking_from_pad_a_to_pad_b_of_one_spot_switches_the_content() -> void:
	await _start()
	await _max_all()
	await _stand_on("fence_e", 0)
	assert_eq(card.name_label.text, "Stone wall")
	assert_eq(card.warn_label.text, "lost if broken")
	await _stand_on("fence_e", 1)
	assert_true(card.visible)
	assert_eq(card.name_label.text, "Spike fence")
	assert_eq(card.spec_label.text, "hurts hares")
	await _stand_on("tower_nw", 0)
	assert_eq(card.name_label.text, "Longbow")
	assert_null(card.warn_label, "a tower: no warning")

## Mutations: a bar that never moves, a number that shows the paid amount instead of what remains.
func test_the_bar_and_the_number_follow_the_payment() -> void:
	await _start()
	await _max_all()
	await _stand_on("tower_e", 1)
	assert_eq(card.cost_label.text, "500")
	var full := BranchCard.BAR_W - 6.0
	GameState.gold = 200
	assert_eq(GameState.pay_into_branch("tower_e", &"volley", 200), 200)
	GameState.gold = 0
	await _settle()
	assert_eq(GameState.branch_remaining("tower_e", &"volley"), 300, "setup")
	assert_eq(card.cost_label.text, "300", "the remaining cost")
	assert_almost_eq(card.bar_fill.size.x, full * 0.4, 0.01, "200 of 500 paid")
	GameState.gold = 150
	GameState.pay_into_branch("tower_e", &"volley", 150)
	GameState.gold = 0
	await _settle()
	assert_eq(card.cost_label.text, "150")
	assert_almost_eq(card.bar_fill.size.x, full * 0.7, 0.01, "350 of 500 paid")
	# the other pad of the spot has its own payment
	await _stand_on("tower_e", 0)
	assert_eq(card.cost_label.text, "500", "the Longbow pad has nothing paid")
	assert_almost_eq(card.bar_fill.size.x, 0.0, 0.01)
	# a fence costs 300
	await _stand_on("fence_n", 0)
	assert_eq(card.cost_label.text, "300")

# --- input -------------------------------------------------------------------------------------------

## Mutation: a card (or any child) with the stop filter.
func test_every_control_in_the_card_ignores_the_mouse() -> void:
	await _start()
	await _max_all()
	for spec in [["fence_e", 0], ["tower_nw", 1]]:
		await _stand_on(spec[0], spec[1])
		assert_true(card.visible)
		var controls := card.all_controls()
		assert_gt(controls.size(), 8, "setup: the card has children")
		for c in controls:
			assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % c.get_path())

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	main.get_viewport().push_input(e, true)

func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	main.get_viewport().push_input(e, true)

## The drag starts ON the card (its centre) and still moves the hero.
func test_a_drag_that_starts_on_the_card_moves_the_hero() -> void:
	await _start()
	await _max_all()
	await _stand_on("tower_e", 0)
	assert_true(card.visible)
	var start := card.get_global_rect().get_center()
	assert_true(card.get_global_rect().has_point(start), "setup: a point on the card")
	assert_true(Rect2(Vector2.ZERO, main.get_viewport().get_visible_rect().size).encloses(card.get_global_rect()), "setup: the card is on screen")
	var before := main.hero.xz()
	_touch(0, start, true)
	assert_true(main.joystick.is_active(), "the stick began under the card")
	_drag(0, start + Vector2(0, 90), Vector2(0, 90))
	await get_tree().physics_frame
	assert_gt(main.hero.input.get_move().length(), 0.5, "the hero's move input is non-zero")
	for i in 30:
		await get_tree().physics_frame
	assert_gt(main.hero.xz().distance_to(before), 0.5, "and he walked (down the screen)")
	_touch(0, start + Vector2(0, 90), false)
	assert_false(main.joystick.is_active())

# --- projection --------------------------------------------------------------------------------------

class View:
	var xf: Transform3D
	var proj: Projection
	var aspect: float
	func _init(focus: Vector2, p_aspect: float) -> void:
		xf = CameraMath.camera_transform(CameraMath.focus_for(focus), Balance.ui)
		proj = CameraMath.projection(Balance.ui, p_aspect)
		aspect = p_aspect
	## The base view (canvas_items, expand): 720 wide below 9:16, else 1280 high.
	func half_h() -> float:
		return 0.5 * maxf(1280.0, 720.0 / aspect)
	func half_w() -> float:
		return 0.5 * (720.0 if aspect < 720.0 / 1280.0 else 1280.0 * aspect)
	func pt(w: Vector3) -> Vector2:
		var n := CameraMath.to_ndc(w, xf, proj)
		return Vector2(half_w() + n.x * half_w(), half_h() - n.y * half_h())
	func box(b: AABB) -> Rect2:
		var r := Rect2(pt(b.position), Vector2.ZERO)
		for k in 8:
			r = r.expand(pt(b.position + Vector3(b.size.x * (k & 1), b.size.y * ((k >> 1) & 1), b.size.z * ((k >> 2) & 1))))
		return r
	func screen() -> Rect2:
		return Rect2(0, 0, half_w() * 2.0, half_h() * 2.0)

## The card's rect on a screen of `aspect` (base px, origin top-left) with a bottom safe inset.
func _card_rect(v: View, bottom_inset: float) -> Rect2:
	var bottom := v.half_h() * 2.0 - bottom_inset - BranchCard.BOTTOM_GAP
	return Rect2(v.half_w() - BranchCard.CARD_SIZE.x * 0.5, bottom - BranchCard.CARD_SIZE.y, BranchCard.CARD_SIZE.x, BranchCard.CARD_SIZE.y)

func _hero_rect(at: Vector2, v: View) -> Rect2:
	return v.box(AABB(Vector3(at.x - 0.4, 0.0, at.y - 0.05), Vector3(0.8, 1.8, 0.1)))

## The card's real rect (a live Hud) equals the one the projection tests use: the same constants, the safe inset honoured.
func test_the_live_card_sits_where_the_projection_tests_put_it() -> void:
	await _start()
	await _max_all()
	await _stand_on("tower_e", 0)
	for inset in [0.0, 34.0]:
		SafeArea.override_for_tests = {"top": 0.0, "bottom": inset, "left": 0.0, "right": 0.0}
		main.hud._apply_safe_area()
		await get_tree().process_frame
		var v := View.new(Vector2.ZERO, 720.0 / 1280.0)
		var want := _card_rect(v, inset)
		var got := card.get_global_rect()
		var vp_w := main.hud.root.get_viewport_rect().size.x  # the test window is wider than the base: centred in whatever it is
		assert_almost_eq(got.position.x, (vp_w - 640.0) * 0.5, 0.5, "inset %s: x (horizontally centred)" % inset)
		assert_almost_eq(got.end.y, main.hud.root.get_viewport_rect().size.y - inset - 24.0, 0.5, "inset %s: bottom (24 px above the inset)" % inset)
		assert_almost_eq(got.position.y, want.position.y, 0.5, "inset %s: y (24 px above the inset)" % inset)
		assert_almost_eq(got.size.x, 640.0, 0.5)
		assert_almost_eq(got.size.y, 170.0, 0.5)

## Mutation: a card that grows tall or sits low enough to cover a hero standing on a pad; or one off the screen or in the home indicator.
func test_the_card_never_covers_the_hero_on_any_of_the_18_pads_and_stays_in_the_safe_area() -> void:
	var worst := INF
	for spot in MapLayout.spots_for_tier(3):
		for i in 2:
			var at := _pad_pos(spot, i)
			for a in ASPECTS.size():
				var v := View.new(at, ASPECTS[a])
				var hero := _hero_rect(at, v)
				for inset in [0.0, 34.0]:
					var card_r := _card_rect(v, inset)
					var tag := "%s pad %d at %s, inset %s" % [spot, i, ASPECT_NAMES[a], inset]
					assert_false(card_r.intersects(hero), "%s: the card covers the hero %s vs %s" % [tag, card_r, hero])
					assert_true(v.screen().encloses(card_r), "%s: fully on screen" % tag)
					assert_lte(card_r.end.y, v.half_h() * 2.0 - inset - BranchCard.BOTTOM_GAP + 0.01, "%s: inside the safe area" % tag)
					worst = minf(worst, card_r.position.y - hero.end.y if card_r.position.y >= hero.end.y else INF)
	# the 9:19.5 phone with the home indicator
	var v2 := View.new(Vector2.ZERO, 9.0 / 19.5)
	var r2 := _card_rect(v2, 34.0)
	assert_true(v2.screen().encloses(r2), "9:19.5 with a 34 px home indicator: on screen")
	assert_almost_eq(v2.half_h() * 2.0 - r2.end.y, 34.0 + 24.0, 0.01, "58 px above the physical bottom")
	for spot in MapLayout.spots_for_tier(3):
		for i in 2:
			var at := _pad_pos(spot, i)
			var v := View.new(at, 9.0 / 19.5)
			for inset in [0.0, 34.0]:
				assert_false(_card_rect(v, inset).intersects(_hero_rect(at, v)), "%s pad %d at 9:19.5 inset %s" % [spot, i, inset])
	gut.p("smallest clear gap between the hero's feet-to-head box and the card top (base px, hero above the card): %s" % worst)

# --- text length -------------------------------------------------------------------------------------

## Pads a string to about 40% longer with characters of average width.
static func _longer(s: String) -> String:
	var out := s
	var pad := "ena"
	var extra := ceili(float(s.length()) * 0.4)
	for k in extra:
		out += pad[k % pad.length()]
	return out

static func _viet(s: String) -> String:
	return VI.get(s, s)

func _no_overlap_no_overflow(tag: String) -> void:
	assert_false(card.overflowing(), "%s: a label needs more width than it has" % tag)
	var inner := Rect2(BranchCard.MARGIN_X, 0.0, BranchCard.CARD_SIZE.x - 2.0 * BranchCard.MARGIN_X, BranchCard.CARD_SIZE.y)
	var items := card.item_rects()
	items.append(["BarBack", Rect2(card.bar_back.position, card.bar_back.size)])
	for it in items:
		var r: Rect2 = it[1]
		assert_true(inner.encloses(r), "%s: %s %s leaves the card's inner width %s" % [tag, it[0], r, inner])
		assert_lte(r.end.y, BranchCard.CARD_SIZE.y, "%s: %s below the card" % [tag, it[0]])
	for a in items.size():
		for b in range(a + 1, items.size()):
			assert_false((items[a][1] as Rect2).intersects(items[b][1]), "%s: %s %s overlaps %s %s" % [tag, items[a][0], items[a][1], items[b][0], items[b][1]])

func _sizes_ok(tag: String) -> void:
	assert_gte(card.name_label.get_theme_font_size(&"font_size"), 30, "%s: name >= 30 px" % tag)
	for l in card.all_labels():
		assert_gte(l.get_theme_font_size(&"font_size"), 24, "%s: %s >= 24 px" % [tag, l.name])
	for c in card.get_children():
		if c is TextureRect:
			assert_gte(c.size.x, 40.0, "%s: icon %s >= 40 px" % [tag, c.name])
			assert_gte(c.size.y, 40.0, "%s: icon %s >= 40 px" % [tag, c.name])

## Mutations: a fixed-width layout that lets a longer string run into its neighbour or off the card; a font below the floor.
func test_longer_strings_and_the_vietnamese_sample_fit_without_overlap() -> void:
	await _start()
	await _max_all()
	var modes := {"english": Callable(), "40% longer": _longer, "vietnamese": _viet}
	for mode in modes:
		BranchCard.text_filter = modes[mode]
		var smallest := {}
		var tightest := 0.0
		for spot in MapLayout.spots_for_tier(3):
			var options := GameState.branch_options(spot)
			for i in 2:
				await _stand_on(spot, i)
				card.rebuild()
				var tag := "%s %s pad %d" % [mode, spot, i]
				assert_true(card.visible, tag)
				if mode == "40% longer":
					assert_gt(card.name_label.text.length(), (BRANCHES[options[i]][0] as String).length(), "%s: setup, the name is longer" % tag)
				_no_overlap_no_overflow(tag)
				_sizes_ok(tag)
				for l in card.all_labels():
					var n := String(l.name).rstrip("0123456789")
					smallest[n] = mini(int(smallest.get(n, 999)), l.get_theme_font_size(&"font_size"))
					tightest = maxf(tightest, card.text_rect(l).size.x / l.size.x)
		gut.p("%s: smallest font per label %s, tightest text/label width %s" % [mode, smallest, tightest])
	BranchCard.text_filter = Callable()

func test_the_font_has_a_glyph_for_every_character_of_the_vietnamese_sample() -> void:
	await _start()
	var l := Label.new()
	l.theme_type_variation = &"BannerLabel"
	add_child_autofree(l)
	var font := l.get_theme_font(&"font")
	var seen := {}
	for k in VI:
		for ch in (VI[k] as String):
			seen[ch] = true
	for ch in "Tường đá chặn quái nặng đường phía tây mất nếu bị phá":
		seen[ch] = true
	for ch in seen:
		assert_true(font.has_char(ch.unicode_at(0)), "the font has '%s' (U+%04X)" % [ch, ch.unicode_at(0)])

func test_the_size_floors_hold_in_plain_english_too() -> void:
	await _start()
	await _max_all()
	for spec in [["fence_sw", 1], ["tower_nw", 1], ["fence_w", 0]]:
		await _stand_on(spec[0], spec[1])
		_sizes_ok("%s %d" % spec)
		_no_overlap_no_overflow("%s %d" % spec)
